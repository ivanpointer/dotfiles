#!/usr/bin/env python3
"""Speak a short completion alert without making the caller wait for audio."""

import argparse
import fcntl
import hashlib
import json
import os
import re
import subprocess
import sys
import tempfile
import time
import urllib.error
import urllib.request


MODEL = "deepgram/flux-tts:free"
SPEECH_SPEED = 1.25
SPEECH_URL = "https://openrouter.ai/api/v1/audio/speech"
DEFAULT_STATE_DIR = os.path.join(os.path.expanduser("~"), ".local", "state", "speak")


def resolve_state_dir():
    """Choose a private writable state directory, including in sandboxes.

    The normal XDG-style location preserves logs across ordinary shells. Sandboxed
    callers can read it but may not write it, so use their writable temporary
    directory for the lock and diagnostic log instead of dropping the alert.
    """
    preferred = os.path.expanduser(os.environ.get("SPEAK_STATE_DIR") or DEFAULT_STATE_DIR)
    fallback = os.path.join(tempfile.gettempdir(), "speak")
    candidates = (preferred,) if preferred == fallback else (preferred, fallback)
    for path in candidates:
        try:
            os.makedirs(path, mode=0o700, exist_ok=True)
            descriptor, probe = tempfile.mkstemp(prefix=".speak-write-", dir=path)
            os.close(descriptor)
            os.unlink(probe)
            return path
        except OSError:
            continue
    return preferred


STATE_DIR = resolve_state_dir()
PLAYBACK_LOCK_PATH = os.path.join(STATE_DIR, "playback.lock")
LOG_PATH = os.path.join(STATE_DIR, "speak.log")
LOG_LOCK_PATH = os.path.join(STATE_DIR, "speak.log.lock")


MAX_CLIP_AGE_SECONDS = 120
MAX_LOG_BYTES = 1024 * 1024

# Adjacent slots deliberately alternate gender and accent.
VOICES = [
    ("flux-alexis-en", "Samantha"),
    ("flux-colin-en", "Daniel"),
    ("flux-maeve-en", "Moira"),
    ("flux-cliff-en", "Ralph"),
    ("flux-sharon-en", "Karen"),
    ("flux-naveen-en", "Rishi"),
    ("flux-gemma-en", "Tessa"),
    ("flux-wes-en", "Fred"),
    ("flux-meena-en", "Tara"),
    ("flux-kai-en", "Aman"),
    ("flux-brooke-en", "Kathy"),
    ("flux-tanner-en", "Reed (English (US))"),
]
VOICE_RE = re.compile(r"^flux-[a-z]+-en$")


def ensure_state_dir():
    os.makedirs(STATE_DIR, mode=0o700, exist_ok=True)


def resolve_session(explicit_session):
    if explicit_session:
        return explicit_session
    for name in ("SPEAK_SESSION_ID", "CLAUDE_CODE_SESSION_ID", "CODEX_SESSION_ID"):
        value = os.environ.get(name)
        if value:
            return value
    pane = os.environ.get("TMUX_PANE")
    if pane:
        return "pane:" + pane
    return "ppid:" + str(os.getppid())


def main_worktree(dotgit):
    """Resolve a linked worktree's `.git` file back to the main working tree."""
    try:
        with open(dotgit) as fh:
            pointer = fh.read().strip()
    except Exception:
        return None
    if not pointer.startswith("gitdir:"):
        return None
    gitdir = pointer[len("gitdir:"):].strip()
    if not os.path.isabs(gitdir):
        gitdir = os.path.join(os.path.dirname(dotgit), gitdir)
    parts = os.path.normpath(gitdir).split(os.sep)
    # <main>/.git/worktrees/<name> is the only shape git writes here.
    if "worktrees" in parts:
        cut = parts.index("worktrees")
        if cut >= 2 and parts[cut - 1] == ".git":
            return os.sep.join(parts[: cut - 1]) or os.sep
    return None


def repo_root(start):
    """Walk up to the enclosing repository, normalizing a linked worktree onto its
    main working tree so every worktree of one project keeps the same voice."""
    path = start
    while True:
        marker = os.path.join(path, ".git")
        if os.path.isdir(marker):
            return path
        if os.path.isfile(marker):
            return main_worktree(marker) or path
        parent = os.path.dirname(path)
        if parent == path:
            return None
        path = parent


def resolve_project(explicit):
    """Name the project that owns the voice.  Hooks run from their own directory, so
    an explicit path or the harness's project variable wins over cwd.  A repository
    is keyed on its root's basename, not its path, so a clone landing elsewhere
    keeps its voice; two repositories sharing a name then share a voice.  Realpath
    matters: /tmp and /private/tmp hash apart and macOS hands out both."""
    start = None
    for candidate in (
        explicit,
        os.environ.get("SPEAK_PROJECT_DIR"),
        os.environ.get("CLAUDE_PROJECT_DIR"),
    ):
        if candidate and candidate.strip():
            start = os.path.realpath(os.path.expanduser(candidate.strip()))
            break
    if start is None:
        try:
            start = os.path.realpath(os.getcwd())
        except OSError:
            return "unknown"
    root = repo_root(start)
    if root:
        return os.path.basename(root) or root
    return start


def assign_slot(project):
    """Return this project's 1-based slot from a hash of its key.  Stateless on
    purpose: the voice is identical in every session and on every machine, with
    nothing to persist or expire.  The cost is collisions - two unrelated projects
    can draw the same voice, and only widening VOICES lowers those odds."""
    digest = hashlib.sha256(project.encode("utf-8", "replace")).digest()
    return (int.from_bytes(digest[:8], "big") % len(VOICES)) + 1


def slot_voice(slot):
    return VOICES[(slot - 1) % len(VOICES)]


def log_call(session_id, project, slot, engine, voice, http_status, synthesis_ms,
             lock_wait_ms, clip_age_ms, outcome, text):
    ensure_state_dir()
    safe_text = " ".join(text.split())[:80].replace('"', "'")
    line = (
        "timestamp={:.3f} session={} project={} slot={} engine={} voice={} http={} "
        "synthesis_ms={} lock_wait_ms={} clip_age_ms={} outcome={} text=\"{}\"\n"
    ).format(time.time(), session_id.replace(" ", "_"), json.dumps(project), slot, engine, voice,
             http_status, synthesis_ms, lock_wait_ms, clip_age_ms, outcome,
             safe_text)
    with open(LOG_LOCK_PATH, "a+", encoding="utf-8") as lock:
        fcntl.flock(lock.fileno(), fcntl.LOCK_EX)
        try:
            current_size = os.path.getsize(LOG_PATH) if os.path.exists(LOG_PATH) else 0
            if current_size + len(line.encode("utf-8")) > MAX_LOG_BYTES:
                with open(LOG_PATH, "rb") as old_log:
                    old_log.seek(-MAX_LOG_BYTES // 2, os.SEEK_END)
                    retained = old_log.read()
                newline = retained.find(b"\n")
                retained = retained[newline + 1:] if newline >= 0 else retained
                with open(LOG_PATH, "wb") as new_log:
                    new_log.write(retained)
            with open(LOG_PATH, "a", encoding="utf-8") as log:
                log.write(line)
        finally:
            fcntl.flock(lock.fileno(), fcntl.LOCK_UN)


def available_say_voice(desired):
    try:
        probe = subprocess.run(["say", "-v", "?"], stdout=subprocess.PIPE,
                               stderr=subprocess.DEVNULL, text=True, check=False)
    except OSError:
        return None
    prefix = desired + " "
    for line in probe.stdout.splitlines():
        if line == desired or line.startswith(prefix):
            return desired
    return None


def play_fallback(text, fallback_voice):
    if not os.path.exists("/usr/bin/say"):
        return "none", "no-player"
    command = ["say"]
    voice = available_say_voice(fallback_voice)
    if voice:
        command.extend(["-v", voice])
    command.append(text)
    try:
        result = subprocess.run(command, stdout=subprocess.DEVNULL,
                                stderr=subprocess.DEVNULL, check=False)
        return "say", "played" if result.returncode == 0 else "player-failed"
    except OSError:
        return "none", "no-player"


def synthesize(text, voice):
    key = os.environ.get("OPENROUTER_API_KEY")
    if not key:
        return None, "none", 0
    spoken_text = text if text.rstrip().endswith((".", "!", "?")) else text + "."
    body = json.dumps({"model": MODEL, "input": spoken_text, "voice": voice,
                       "response_format": "mp3", "speed": SPEECH_SPEED}).encode("utf-8")
    request = urllib.request.Request(
        SPEECH_URL, data=body,
        headers={"Authorization": "Bearer " + key, "Content-Type": "application/json"},
        method="POST",
    )
    started = time.monotonic()
    path = None
    status = "0"
    try:
        with urllib.request.urlopen(request, timeout=60) as response:
            status = str(response.getcode())
            audio = response.read()
        if status.startswith("2") and audio:
            with tempfile.NamedTemporaryFile(prefix="speak-", suffix=".mp3", delete=False) as clip:
                clip.write(audio)
                path = clip.name
    except urllib.error.HTTPError as error:
        status = str(error.code)
    except (OSError, urllib.error.URLError, ValueError):
        status = "0"
    return path, status, int((time.monotonic() - started) * 1000)


def play_clip(path):
    if not os.path.exists("/usr/bin/afplay"):
        return "none", "no-player"
    try:
        result = subprocess.run(["afplay", path], stdout=subprocess.DEVNULL,
                                stderr=subprocess.DEVNULL, check=False)
        return "afplay", "played" if result.returncode == 0 else "player-failed"
    except OSError:
        return "none", "no-player"


def deliver(session_id, project, slot, voice, fallback_voice, text, queued_at):
    clip, http_status, synthesis_ms = synthesize(text, voice)
    engine = "flux" if clip else "none"
    outcome = "failed"
    lock_started = time.monotonic()
    ensure_state_dir()
    with open(PLAYBACK_LOCK_PATH, "a+") as playback_lock:
        fcntl.flock(playback_lock.fileno(), fcntl.LOCK_EX)
        lock_wait_ms = int((time.monotonic() - lock_started) * 1000)
        clip_age_ms = int((time.time() - queued_at) * 1000)
        if clip_age_ms > MAX_CLIP_AGE_SECONDS * 1000:
            outcome = "dropped-old"
        elif clip:
            _, outcome = play_clip(clip)
        else:
            engine, outcome = play_fallback(text, fallback_voice)
        if outcome != "dropped-old":
            time.sleep(0.25)
        fcntl.flock(playback_lock.fileno(), fcntl.LOCK_UN)
    if clip:
        try:
            os.unlink(clip)
        except OSError:
            pass
    log_call(session_id, project, slot, engine, voice, http_status, synthesis_ms,
             lock_wait_ms, clip_age_ms, outcome, text)


def detach_and_deliver(*args):
    try:
        first_pid = os.fork()
    except OSError:
        return False
    if first_pid:
        return True
    try:
        os.setsid()
        second_pid = os.fork()
        if second_pid:
            os._exit(0)
        null = os.open(os.devnull, os.O_RDWR)
        for descriptor in (0, 1, 2):
            os.dup2(null, descriptor)
        if null > 2:
            os.close(null)
        deliver(*args)
    finally:
        os._exit(0)


def parse_args(argv):
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("--session")
    parser.add_argument("--project")
    parser.add_argument("--voice")
    parser.add_argument("--dry-run", action="store_true")
    parser.add_argument("text", nargs="+")
    return parser.parse_args(argv)


def main(argv):
    args = parse_args(argv)
    text = " ".join(args.text)
    session_arg = args.session
    project_arg = args.project
    session = resolve_session(session_arg)
    project = resolve_project(project_arg)
    slot = assign_slot(project)
    default_voice, fallback_voice = slot_voice(slot)
    voice = args.voice if args.voice and VOICE_RE.fullmatch(args.voice) else default_voice
    if args.dry_run:
        print("session={} project={} slot={} voice={}".format(session, project, slot, voice))
        log_call(session, project, slot, "none", voice, "-", 0, 0, 0, "dry-run", text)
        return 0
    queued_at = time.time()
    if detach_and_deliver(session, project, slot, voice, fallback_voice, text, queued_at):
        return 0
    # A fork failure is rare, but preserve the alert instead of dropping it.
    deliver(session, project, slot, voice, fallback_voice, text, queued_at)
    return 0


if __name__ == "__main__":
    sys.exit(main(sys.argv[1:]))
