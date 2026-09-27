---
name: speak
description: Deliver a short audible completion alert without blocking the calling agent.
---

# Speak

Use `speak "short summary"` at the end of a top-level agent turn. The command
assigns a stable voice to the current session and serializes playback across the
machine. Do not select voices in the call; use `--session` only from a harness
hook that has its own durable session identifier.
