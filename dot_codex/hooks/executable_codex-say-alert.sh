#!/bin/bash
set -u

mode_arg="${1:-}"
payload="$(cat 2>/dev/null || true)"

phrase="$(HOOK_JSON="$payload" MODE_ARG="$mode_arg" /usr/bin/python3 - <<'PY' 2>/dev/null
import json
import os
import re
import time
import urllib.request
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
TOPIC_SYSTEM_PROMPT = (
    "Generate a 2-3 word spoken label summarizing this coding task. "
    "Output ONLY the label in lowercase. No punctuation. It will be read aloud "
    "by macOS text-to-speech so use clear, speakable words. Examples: auth bug "
    "fix, metrics export, refactor tests, add dark mode, hook topic labels, "
    "update dependencies"
)


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


def text_from_content(value):
    if value is None:
        return ""
    if isinstance(value, str):
        return value
    if isinstance(value, list):
        return " ".join(part for item in value if (part := text_from_content(item))).strip()
    if isinstance(value, dict):
        parts = []
        for key in ("text", "content", "message", "prompt"):
            part = text_from_content(value.get(key))
            if part:
                parts.append(part)
        return " ".join(parts).strip()
    return ""


def find_first_user_message(node):
    if isinstance(node, dict):
        role = str(node.get("role") or "").lower()
        if role in ("user", "human"):
            text = text_from_content(node.get("content"))
            if not text:
                text = text_from_content(node.get("message"))
            if not text:
                text = text_from_content(node.get("text"))
            if text:
                return text.strip()
        for value in node.values():
            text = find_first_user_message(value)
            if text:
                return text
    elif isinstance(node, list):
        for item in node:
            text = find_first_user_message(item)
            if text:
                return text
    return ""


def first_user_message(data):
    text = text_from_content(data.get("first_user_message")).strip()
    if text:
        return text

    transcript_path = data.get("transcript_path")
    if not transcript_path:
        return ""
    try:
        raw = Path(str(transcript_path)).expanduser().read_text()
    except Exception:
        return ""

    try:
        parsed = json.loads(raw)
        return find_first_user_message(parsed)
    except Exception:
        pass

    for line in raw.splitlines():
        if not line.strip():
            continue
        try:
            parsed = json.loads(line)
        except Exception:
            continue
        text = find_first_user_message(parsed)
        if text:
            return text
    return ""


def sanitize_topic(value):
    text = re.sub(r"[^A-Za-z0-9 -]+", " ", str(value or ""))
    text = re.sub(r"\s+", " ", text).strip().lower()
    if not text:
        return None
    words = text.split(" ")[:5]
    text = " ".join(words).strip()
    return text or None


def post_json(url, headers, body):
    request = urllib.request.Request(
        url,
        data=json.dumps(body).encode("utf-8"),
        headers={**headers, "Content-Type": "application/json"},
        method="POST",
    )
    with urllib.request.urlopen(request, timeout=10) as response:
        return json.loads(response.read().decode("utf-8"))


def openai_topic(message):
    key = os.environ.get("OPENAI_API_KEY")
    if not key:
        return None
    response = post_json(
        "https://api.openai.com/v1/chat/completions",
        {"Authorization": f"Bearer {key}"},
        {
            "model": "gpt-4o-mini",
            "messages": [
                {"role": "system", "content": TOPIC_SYSTEM_PROMPT},
                {"role": "user", "content": message[:1000]},
            ],
            "max_tokens": 20,
            "temperature": 0,
        },
    )
    return sanitize_topic(
        (((response.get("choices") or [{}])[0].get("message") or {}).get("content"))
    )


def anthropic_topic(message):
    key = os.environ.get("ANTHROPIC_API_KEY")
    if not key:
        return None
    response = post_json(
        "https://api.anthropic.com/v1/messages",
        {
            "x-api-key": key,
            "anthropic-version": "2023-06-01",
        },
        {
            "model": "claude-3-5-haiku-latest",
            "system": TOPIC_SYSTEM_PROMPT,
            "messages": [{"role": "user", "content": message[:1000]}],
            "max_tokens": 20,
            "temperature": 0,
        },
    )
    parts = response.get("content") or []
    text = " ".join(
        item.get("text", "") for item in parts if isinstance(item, dict) and item.get("type") == "text"
    )
    return sanitize_topic(text)


def generate_topic(message):
    if not message:
        return None
    for generator in (openai_topic, anthropic_topic):
        try:
            topic = generator(message)
        except Exception:
            topic = None
        if topic:
            return topic
    return None


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


def assign_session(data):
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
            topic_cached = "topic" in item
            topic = sanitize_topic(item.get("topic"))
            active_count = len(sessions)
            write_state(path, state)
    except Exception:
        label = 1
        active_count = 1
        topic_cached = False
        topic = None

    return {
        "cwd_key": cwd_key,
        "cwd_name": cwd_name,
        "sid": sid,
        "label": label,
        "active_count": active_count,
        "topic_cached": topic_cached,
        "topic": topic,
        "path": path,
        "lock_path": lock_path,
    }


def cache_session_topic(session, topic):
    topic = sanitize_topic(topic)
    try:
        import fcntl

        path = session["path"]
        lock_path = session["lock_path"]
        with lock_path.open("a+") as lock:
            fcntl.flock(lock, fcntl.LOCK_EX)
            state = read_state(path)
            directory = (
                state.get("directories", {})
                .get(session["cwd_key"], {})
            )
            item = directory.get("sessions", {}).get(session["sid"])
            if not isinstance(item, dict):
                return topic
            if "topic" in item:
                return sanitize_topic(item.get("topic"))
            item["topic"] = topic or ""
            write_state(path, state)
    except Exception:
        pass
    return topic


def phrase_for(data, status):
    session = assign_session(data)
    topic = session["topic"]
    if not topic and not session["topic_cached"]:
        message = first_user_message(data)
        if message:
            topic = cache_session_topic(session, generate_topic(message))

    parts = [session["cwd_name"]]
    if topic:
        parts.append(topic)
    if session["active_count"] > 1:
        parts.append(label_word(session["label"]))
    parts.append(status)
    return " ".join(parts)


data = load_payload()
status = classify(data)
if not status:
    print("")
else:
    print(phrase_for(data, status))
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
