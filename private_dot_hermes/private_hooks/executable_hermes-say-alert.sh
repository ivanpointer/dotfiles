#!/bin/bash
# Hermes turn-end alert -> the shared completion-alert pipeline.
#
# Hermes has no Stop event. on_session_end fires once per turn and carries its
# outcome under extra, so translate successful CLI turns into the payload the
# shared script parses. Hermes retains the common repo label, voice slot, and
# serialized playback instead of implementing another TTS path.
set -u

ALERT_SCRIPT="${HOME}/.local/bin/agent-completion-alert"
LOG="${HOME}/.hermes/hooks/hermes-say-alert.log"

payload="$(cat 2>/dev/null || true)"

log_decision() {
  printf '%s %s\n' "$(date '+%Y-%m-%dT%H:%M:%S')" "$1" >>"$LOG" 2>/dev/null || true
}

if [ ! -x "$ALERT_SCRIPT" ]; then
  log_decision "skipped reason=alert-script-missing"
  exit 0
fi

translated="$(HOOK_JSON="$payload" /usr/bin/python3 - <<'PY' 2>/dev/null
import json
import os

try:
    data = json.loads(os.environ.get("HOOK_JSON") or "")
except Exception:
    raise SystemExit(0)
if not isinstance(data, dict):
    raise SystemExit(0)

extra = data.get("extra")
extra = extra if isinstance(extra, dict) else {}

# Gateway turns would speak into an empty room. An unset platform is treated as
# CLI so a future platform rename silences alerts rather than creating noise.
platform = str(extra.get("platform") or "").strip().lower()
if platform not in ("", "cli"):
    print("drop platform=%s" % platform)
    raise SystemExit(0)
if extra.get("interrupted"):
    print("drop interrupted")
    raise SystemExit(0)
if extra.get("completed") is False:
    print("drop incomplete")
    raise SystemExit(0)

print("forward")
print(json.dumps({
    "hook_event_name": "Stop",
    "session_id": data.get("session_id") or "",
    "cwd": data.get("cwd") or "",
}))
PY
)"

decision="$(printf '%s' "$translated" | sed -n '1p')"
forwarded="$(printf '%s' "$translated" | sed -n '2p')"

if [ "$decision" != "forward" ] || [ -z "$forwarded" ]; then
  log_decision "${decision:-drop reason=unparsable-payload}"
  exit 0
fi

# Hermes treats stdout as a directive. Never leak the child's output into it.
log_decision "forward"
printf '%s' "$forwarded" | SAY_ALERT_SESSION_PREFIX=hermes "$ALERT_SCRIPT" >/dev/null 2>&1

exit 0
