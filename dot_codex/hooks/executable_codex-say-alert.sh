#!/bin/bash
# Shared completion-alert adapter for Codex, OpenCode, Pi, and Hermes.
#
# Every harness sends a Claude-Code-shaped Stop payload here.  This script owns
# the short, repo-labelled completion phrase; speak owns the stable voice slot,
# serialized playback, and TTS fallback.
set -u

payload="$(cat 2>/dev/null || true)"

alert="$(HOOK_JSON="$payload" /usr/bin/python3 - <<'PY' 2>/dev/null
import json
import os
from pathlib import Path

try:
    data = json.loads(os.environ.get("HOOK_JSON") or "")
except Exception:
    raise SystemExit(0)
if not isinstance(data, dict):
    raise SystemExit(0)

event = str(data.get("hook_event_name") or "").strip()
if event and event != "Stop":
    raise SystemExit(0)

cwd = str(data.get("cwd") or os.getcwd())
try:
    repo = Path(cwd).expanduser().resolve().name
except Exception:
    repo = ""
repo = repo or "agent"

session = str(data.get("session_id") or data.get("thread_id") or "")
if not session:
    session = "cwd:" + cwd

print(session)
print(f"{repo} ready")
PY
)"

session_id="$(printf '%s\n' "$alert" | sed -n '1p')"
phrase="$(printf '%s\n' "$alert" | sed -n '2p')"
[ -n "$session_id" ] && [ -n "$phrase" ] || exit 0

# Prefixes prevent different harnesses from sharing a voice when their native
# session identifiers happen to collide.  Codex remains the compatibility
# default for its existing hook entry.
prefix="${SAY_ALERT_SESSION_PREFIX:-codex}"
"${HOME}/.local/bin/speak" --session "${prefix}:${session_id}" "$phrase" >/dev/null 2>&1

exit 0
