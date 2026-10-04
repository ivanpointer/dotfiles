---
name: speak
description: Deliver concise audible completion and intervention alerts through the installed local MOSS-TTS service.
---

# Speak

Use `speak "short summary"` at the end of a top-level agent turn. The command
submits one request to the loopback MOSS-TTS service, which owns the saved
reference, rendering, FIFO ordering, and host playback. Always use the standard
command: no execution permission, flags, or sandbox-specific workaround is
needed. The default is a machine-local preference scoped to the current
repository root (or the current directory outside Git). When the user
explicitly says to persistently use a saved voice, run
`speak --set-voice VOICE` from that project; ordinary `speak "summary"` calls
there then use it automatically. A named agent may instead use
`speak --agent AGENT_ID --set-voice VOICE`; its explicit identity takes
priority when its MCP configuration sets `MOSS_TTS_AGENT_ID=AGENT_ID`. The
MCP bridge derives the same project scope automatically when it is launched
from the project. Use `--voice` only for an explicitly requested one-off
override.

For a voice with a non-empty saved character style, write the final text in
that character yourself while you still have the task context; the service
renders exactly what it receives. Persist a project authoring override with
`speak --set-style on` or `speak --set-style off`; append `--global-style` to
set the machine-wide default instead. A blank voice style uses clear natural
text. The ordinary spoken command and the MCP tool remain unchanged.

Set authoring strength with `speak --set-style-strength light|medium|strong`
in the project, or append `--global-style` for the machine default. `medium` is
the balanced default. Preserve facts, actions, targets, qualifiers, and user
intent; styled text may add no more than one word per seven source words and
must lead with the outcome or action without padding.
Tone words describe the style rather than the spoken content: never add words
such as `calmly` or `dramatically`; show character through word choice and
punctuation instead.

When characterization is enabled, privately list the source facts, action,
target, qualifier, uncertainty, and request. Make a real but compact
voice-appropriate wording/rhythm change, then verify every proposition is
still explicit. Do not add, remove, imply, soften, or strengthen a proposition.
Use unchanged wording only when it is materially necessary; do not default to
generic unchanged text merely because it is easier.

## What to speak

Use one designated top-level speaker for a delegated tree; children send findings to their parent. Preserve applicable end-of-turn requirements. Speech remains optional for other adopters and works without project state, orchestration or a communication policy.

Lead with project/task, then useful outcome or consequence and any needed response. Keep it to one or two short sentences. Do not read cue icons, paths, links, tables or the written response aloud. Keep essential questions available in text. Exclude secrets and sensitive details, respect configured audio/provider/privacy settings, and never treat playback as user consent.

Write each spoken message as complete sentence(s) and end the final sentence
with terminal punctuation (`.`, `!`, or `?`). Do not send a clipped fragment,
heading, or dangling parenthetical: a clear ending gives the renderer a natural
cadence boundary instead of letting the voice trail off.

Speak new consequential risks, actionable blockers or corrections when they earn interruption. Do not repeat an unchanged alert or routine child lifecycle event. Combine overlapping progress/completion. Optional long-running progress is eligible after a configured quiet interval only when something meaningful changed; do not manufacture a heartbeat from elapsed time. Five minutes is a provisional tuning suggestion, not an enabled timer or universal default. Check at natural work boundaries; a prompt cannot guarantee an alert while a tool blocks.

Client success means queued, not played or heard. The renderer waits for host
playback to finish before advancing its FIFO queue. Multi-sentence calls render
as sentence chunks, but playback holds the full logical message together so no
other alert can cut into it. The current native runtime
is Apple Silicon macOS with MLX/Metal; core toolkit support for Linux and
Windows does not imply that this optional renderer is available there. Do not
claim a service is running merely because this skill is installed.
