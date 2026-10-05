---
name: speak
description: Deliver concise audible completion and intervention alerts through the installed local OpenRouter Fish Audio service.
---

# Speak

At the end of a top-level agent turn, call the `speak` MCP tool when your
harness exposes it (Codex does, as `openrouter-fish-tts`); use the shell command
`speak "short summary"` otherwise. Both submit one request to the loopback
OpenRouter Fish Audio service, which owns voice selection, rendering, FIFO
ordering, and host playback. A sandboxed shell, as in Codex, can block the
command's loopback connection (`Operation not permitted`); the MCP tool runs
outside that sandbox, and the installer also adds an allow rule for the
command. Do not retry a blocked command with flags or alternate transports.
The default is a machine-local preference scoped to the current
repository root (or the current directory outside Git). When the user
explicitly says to persistently use a saved voice, run
`speak --set-voice VOICE` from that project; ordinary `speak "summary"` calls
there then use it automatically. A named agent may instead use
`speak --agent AGENT_ID --set-voice VOICE`; its explicit identity takes
priority when its MCP configuration sets `OPENROUTER_FISH_TTS_AGENT_ID=AGENT_ID`. The
MCP bridge derives the same project scope automatically when it is launched
from the project. Use `--voice` only for an explicitly requested one-off
override.

Submit plain factual text; do not author the character yourself or create Fish
tags. The service applies the saved style through a small OpenRouter model in
its background FIFO worker. It authors character wording and context-sensitive
delivery cues, then checks facts and attention/action meaning separately. Keep
enough concrete information for the listener to decide whether to switch tasks,
take a mental note or continue: outcome, reason/scope/consequence,
blocker/urgency, uncertainty and any required action. Only incidental detail or
repetition may be trimmed. Quoted style examples are inspiration, not compulsory
catchphrases.

Persist a project override with `speak --set-style on|off`, or append
`--global-style` for the machine default. Set strength with
`speak --set-style-strength light|medium|strong`; `medium` is the default.
Off disables automatic character additions; saved voice delivery modifiers
still apply. Blank styles, long or already-tagged input remain literal.
Authoring and its separate factual/attention check share a bounded worker
deadline, with original-text fallback on timeout, error, failed checks or doubt.
Checks reduce risk but do not prove semantic or acoustic equivalence. Queue
acceptance stays immediate; authoring adds latency before audio starts. The
ordinary command and MCP signature are unchanged. Raw `/render` downloads and
console voice tests remain literal; they do not demonstrate automatic character
performance.

## Playback controls

When the user asks to mute or disable speech, run `speak --mute`; when they
ask to resume, run `speak --unmute`. Both apply to all agents on this host and
persist across service restarts. Check `speak --playback-status` to confirm.
A suppressed receipt is successful silence, not failed playback; do not retry
or bypass it using another player. Keep the written response available.

Automatic Zoom protection defaults on. Toggle it with
`speak --auto-mute-zoom on|off` or the voice console's playback controls.
On supported macOS versions, local CoreAudio metadata detects Zoom's active
input or output streams, including calls with the microphone muted. It is an
audio-activity proxy, not exact meeting status: previews may mute too, and
calls without active audio or browser Zoom sessions can be missed. Detection
failures/unsupported hosts are reported; use manual mute in those cases.
Muted requests are discarded before rendering, queued alerts are cleared,
and an existing player is stopped within the polling interval (normally
250 ms). Unmuting resumes only new alerts; it never replays the backlog.
The separate `/render` download API does not play audio and is unchanged.

## What to speak

Use one designated top-level speaker for a delegated tree; children send findings to their parent. Preserve applicable end-of-turn requirements. Speech remains optional for other adopters and works without project state, orchestration or a communication policy.

Lead with the useful outcome or consequence and any needed response. Do not put the project or repo name in the text: pass it only as the MCP tool's `project_label` argument, and the service speaks it only when the user has turned the spoken prefix on (off by default). Keep it to one or two short sentences. Do not read cue icons, paths, links, tables or the written response aloud. Keep essential questions available in text. Exclude secrets and sensitive details, respect configured audio/provider/privacy settings, and never treat playback as user consent.

Write each spoken message as complete sentence(s) and end the final sentence
with terminal punctuation (`.`, `!`, or `?`). Do not send a clipped fragment,
heading, or dangling parenthetical: a clear ending gives the renderer a natural
cadence boundary instead of letting the voice trail off.

Speak new consequential risks, actionable blockers or corrections when they earn interruption. Do not repeat an unchanged alert or routine child lifecycle event. Combine overlapping progress/completion. Optional long-running progress is eligible after a configured quiet interval only when something meaningful changed; do not manufacture a heartbeat from elapsed time. Five minutes is a provisional tuning suggestion, not an enabled timer or universal default. Check at natural work boundaries; a prompt cannot guarantee an alert while a tool blocks.

Client success means queued, not played or heard. The renderer waits for host
playback to finish before advancing its FIFO queue. Multi-sentence calls render
as complete messages, but playback holds the full logical message together so no
other alert can cut into it. The current native runtime is a macOS loopback
service that calls OpenRouter's Fish Audio API; core toolkit support for Linux
and Windows does not imply that this optional renderer is available there. Do not
claim a service is running merely because this skill is installed.
