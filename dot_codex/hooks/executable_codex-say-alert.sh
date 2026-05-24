#!/bin/bash
set -u

mode_arg="${1:-}"
payload="$(cat 2>/dev/null || true)"

phrase="$(HOOK_JSON="$payload" MODE_ARG="$mode_arg" /usr/bin/python3 - <<'PY' 2>/dev/null
import json
import os
import time
from pathlib import Path

LABEL_WORDS = {
    1: "one",
    2: "two",
    3: "three",
    4: "four",
    5: "five",
    6: "six",
    7: "seven",
    8: "eight",
    9: "nine",
}
DEFAULT_TTL_SECONDS = 8 * 60 * 60


def load_payload():
    raw = os.environ.get("HOOK_JSON") or ""
    if not raw.strip():
        return {}
    try:
        data = json.loads(raw)
    except Exception:
        return {}
    return data if isinstance(data, dict) else {}


def classify(data):
    mode_arg = (os.environ.get("MODE_ARG") or "").strip()
    explicit_modes = {
        "agent-ready": "ready",
        "ready": "ready",
        "turn-ended": "ready",
        "Stop": "ready",
        "question": "question",
        "approval": "approval",
    }
    if mode_arg in explicit_modes:
        return explicit_modes[mode_arg]

    event = data.get("hook_event_name") or ""
    if event == "Notification":
        return "question"
    if event != "Stop":
        return ""

    message = str(data.get("last_assistant_message") or "").strip().lower()
    if any(word in message for word in ("approve", "approval", "permission")):
        return "approval"
    if "?" in message or any(
        phrase in message
        for phrase in (
            "do you want",
            "would you like",
            "should i",
            "can i",
            "shall i",
            "let me know",
        )
    ):
        return "question"
    return "ready"


def cwd_parts(data):
    cwd = str(data.get("cwd") or os.getcwd())
    normalized = os.path.abspath(os.path.normpath(cwd))
    name = os.path.basename(normalized) or normalized.strip(os.sep) or "codex"
    return normalized, name


def session_id(data, cwd_key):
    raw = data.get("session_id") or data.get("thread_id") or ""
    if raw:
        return str(raw)
    return f"default:{cwd_key}"


def label_word(label):
    return LABEL_WORDS.get(label, str(label))


def state_path():
    override = os.environ.get("CODEX_SAY_ALERT_STATE_FILE")
    if override:
        return Path(override).expanduser()
    return Path.home() / ".codex" / "hooks" / "codex-say-alert-state.json"


def ttl_seconds():
    raw = os.environ.get("CODEX_SAY_ALERT_TTL_SECONDS")
    if not raw:
        return DEFAULT_TTL_SECONDS
    try:
        return max(60, int(raw))
    except ValueError:
        return DEFAULT_TTL_SECONDS


def read_state(path):
    if not path.exists():
        return {"directories": {}}
    try:
        data = json.loads(path.read_text())
    except Exception:
        return {"directories": {}}
    return data if isinstance(data, dict) else {"directories": {}}


def write_state(path, state):
    path.parent.mkdir(parents=True, exist_ok=True)
    tmp = path.with_suffix(path.suffix + ".tmp")
    tmp.write_text(json.dumps(state, sort_keys=True) + "\n")
    tmp.replace(path)


def prune_state(state, now, ttl):
    directories = state.setdefault("directories", {})
    for cwd_key in list(directories):
        directory = directories.get(cwd_key)
        if not isinstance(directory, dict):
            directories.pop(cwd_key, None)
            continue
        sessions = directory.setdefault("sessions", {})
        for sid in list(sessions):
            item = sessions.get(sid) or {}
            last_seen = float(item.get("last_seen") or 0)
            if now - last_seen > ttl:
                sessions.pop(sid, None)
        if not sessions:
            directories.pop(cwd_key, None)


def assign_label(data):
    cwd_key, cwd_name = cwd_parts(data)
    sid = session_id(data, cwd_key)
    now = time.time()
    path = state_path()
    lock_path = path.with_suffix(path.suffix + ".lock")

    try:
        import fcntl

        path.parent.mkdir(parents=True, exist_ok=True)
        with lock_path.open("a+") as lock:
            fcntl.flock(lock, fcntl.LOCK_EX)
            state = read_state(path)
            prune_state(state, now, ttl_seconds())
            directories = state.setdefault("directories", {})
            directory = directories.setdefault(cwd_key, {"sessions": {}, "next_label": 1})
            sessions = directory.setdefault("sessions", {})
            item = sessions.get(sid)
            if not isinstance(item, dict):
                label = int(directory.get("next_label") or 1)
                directory["next_label"] = label + 1
                item = {"label": label}
                sessions[sid] = item
            item["last_seen"] = now
            label = int(item.get("label") or 1)
            active_count = len(sessions)
            write_state(path, state)
    except Exception:
        label = 1
        active_count = 1

    if active_count <= 1:
        return cwd_name
    return f"{cwd_name} {label_word(label)}"


data = load_payload()
status = classify(data)
if not status:
    print("")
else:
    print(f"{assign_label(data)} {status}")
PY
)"

if [ -z "$phrase" ]; then
  exit 0
fi

say_text() {
  if [ "${CODEX_SAY_ALERT_DRY_RUN:-}" = "1" ]; then
    printf '%s\n' "$1"
  else
    /usr/bin/say "$1" >/dev/null 2>&1 &
  fi
}

say_text "$phrase"

exit 0
