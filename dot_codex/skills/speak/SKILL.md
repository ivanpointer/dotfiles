---
name: speak
description: Deliver a short audible completion alert reliably.
---

# Speak

Use `speak "short summary"` at the end of a top-level agent turn. The command
assigns a stable voice to the project and serializes playback across the machine.
It sends the alert to the user's audio broker, which performs playback outside
the caller's sandbox. Always use the standard `speak "summary"` command: no
execution permission, flags, or sandbox-specific workaround is needed. Do not
select voices in the call; use `--session` only from a harness hook that has its
own durable session identifier.

The project key resolves in this order: `--project DIR`, `$SPEAK_PROJECT_DIR`,
`$CLAUDE_PROJECT_DIR`, then the current directory. The selected directory is
resolved and walked upward to its repository root; linked worktrees normalize to
their main working tree. A repository's key is its root basename, so clones in
different locations share a voice; a non-repository directory is keyed by its
resolved path.

The slot is stateless: `sha256(project) % 12` (using the first eight digest bytes
as a big-endian integer) plus one. There is no registry, state file, or expiry.
With 12 voices and no collision avoidance, unrelated projects can draw the same
voice by chance, and repositories sharing a basename always will. That is
accepted, not a bug; widening `VOICES` is the only lever.
