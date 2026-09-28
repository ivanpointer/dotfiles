#!/bin/sh
# Compatibility path for older hook registrations; new configs call the shared
# harness-neutral adapter directly.
exec "${HOME}/.local/bin/agent-completion-alert" "$@"
