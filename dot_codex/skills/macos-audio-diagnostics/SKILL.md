---
name: macos-audio-diagnostics
description: Troubleshoot audible pops, crackles, and dropouts on macOS by comparing the same recording across outputs and audio formats, correlating playback with CoreAudio logs, and checking hardware-fault evidence. Use for suspected Mac audio failures, including audio that sounds clean on another device.
---

# macOS audio diagnostics

Distinguish defects in the recording, decoding/resampling, audio routing, and
device playback. Use controlled comparisons and the listener's observations;
logs alone cannot establish that playback sounds clean or hardware is healthy.

## Establish the baseline

- Obtain the exact affected file and app. Ask whether pops recur at the same
  positions, which outputs are affected, and whether the problem follows boot,
  wake, a call, or a device change. Continue independent checks while waiting.
- Record current default media output, system-alert output, sample rates,
  volume, and any aggregate/virtual devices before changing them. Media and
  system-alert outputs can differ.
- Note local wall-clock time, time zone, and boot time. Separate events before
  a reboot or driver change from the current configuration.
- Inspect live audio devices and system load:

```sh
sw_vers
sysctl kern.boottime
system_profiler SPAudioDataType
ps -axo pid,pcpu,pmem,comm -r | head -20
vm_stat
sysctl vm.swapusage
pmset -g therm
ls -la /Library/Audio/Plug-Ins/HAL
```

Sandboxed `system_profiler` can return an empty device list, while `ps`,
thermal queries, and unified logs can fail. These are access limitations,
not hardware-failure evidence. Request the harness execution permission needed
for the same bounded diagnostic command; do not weaken privacy controls.
Identify plug-in provenance before blaming a driver: an unfamiliar name can
belong to Apple. Installed virtual devices do not prove active routing.

## Make the comparison assets

Use the user's original file unchanged. `ffmpeg` and `ffprobe` are optional
dependencies for producing comparison assets; use an existing installation or
an equivalent available decoder. Installing software needs its own authority
and the host's established management route.

```sh
audio_input='/absolute/path/to/test.mp3'
audio_workdir=$(mktemp -d /private/tmp/macos-audio-check.XXXXXX)
ffprobe -v error -show_entries format=duration,format_name:stream=codec_name,sample_rate,channels,bit_rate -of json "$audio_input"
ffmpeg -hide_banner -loglevel warning -i "$audio_input" -ar 48000 -ac 2 -c:a pcm_s16le "$audio_workdir/message-48k.wav"
ffmpeg -hide_banner -loglevel error -f lavfi -i 'sine=frequency=440:sample_rate=48000:duration=12' -af 'volume=0.4,afade=t=in:d=0.3,afade=t=out:st=11.7:d=0.3' -c:a pcm_s16le "$audio_workdir/tone-48k.wav"
```

The sine generator's default amplitude plus the volume multiplier makes a
quiet reference tone. Playback level still depends on device volume; start
conservatively. Tell the listener when the tone will play. It tests the output
path without speech decoding and has intentionally faded boundaries.

If each tool call starts a fresh shell, retain the returned temporary directory
and use its explicit path in later calls. Never recreate an asset over the
original recording. The comparison WAV changes codec, rate, and channel count;
it is an initial discriminator, not a test that isolates one of those variables.

## Run the listening comparisons

On each relevant output, play the tone, original file, and decoded WAV
separately. Start with the current settings. Use Audio MIDI Setup or the host's
existing device-control tool to select and verify the output. Native UI actions
must use the available computer-use interface. A successful click is not proof
that the output changed: read back the selected/default device.

Use macOS's native player to bypass the original app:

```sh
audio_start=$(date '+%Y-%m-%d %H:%M:%S')
/usr/bin/afplay "$audio_input"
audio_play_status=$?
audio_end=$(date '+%Y-%m-%d %H:%M:%S')
printf 'Start: %s\nEnd: %s\nPlayer exit: %s\n' "$audio_start" "$audio_end" "$audio_play_status"
```

Repeat with the tone and WAV paths, retaining a separate interval for each
playback. Announce the order and ask the listener which plays have artifacts.
For two outputs this produces six observations:

| Output | Asset | Heard pops? | Player exit | Overload events |
| --- | --- | --- | --- | --- |
| Built-in speakers | Tone / original / WAV (separate rows) | Listener's report | Observed | Observed |
| External output | Tone / original / WAV (separate rows) | Listener's report | Observed | Observed |

Record missing listening feedback as unknown. Avoid repeated playback without
purpose. Preserve authorizations already granted for output/settings changes;
this skill itself grants no new authority.

## Correlate logs with the playback intervals

Use narrowly bounded queries; broad CoreAudio searches can emit enormous logs.
These commands use the Mac's local timestamps captured above:

```sh
/usr/bin/log show --start "$audio_start" --end "$audio_end" --style compact --predicate 'process == "coreaudiod" AND eventMessage CONTAINS "Audio IO Overload thread:"'
```

Count actual event rows, excluding the header. A completed query containing
only the header means zero matching events for that interval. A denied,
interrupted, failed, or truncated query does not establish zero events.

For an interval with overloads, inspect a small sample of neighboring messages
using predicates for `safety_violation`, `HAL client proc exceeding io cycle
budget`, `Failed to send io sender`, and `Sending message.`. Relevant fields
include output-device UID, buffer size, sample rate, client IO duration, and
`safety_violation_time_gap` (seconds; multiply by 1000 for milliseconds).
An overload means the audio path missed timing requirements; the log's proposed
cause is not a proven root cause. Apple may redact or truncate client identity.
Use a narrow `--info` query around device start and PID attribution if needed.

Check recent hardware-fault signatures independently:

```sh
/usr/bin/log show --last 24h --style compact --predicate 'process == "kernel" AND (eventMessage CONTAINS[c] "panic(cpu" OR eventMessage CONTAINS[c] "I/O error" OR eventMessage CONTAINS[c] "machine check" OR eventMessage CONTAINS[c] "uncorrectable")'
```

Inspect recent relevant panic/crash reports in `/Library/Logs/DiagnosticReports`
and the user's `Library/Logs/DiagnosticReports`. A resource-usage report, routine
display-link start/stop, sandbox denial, or old unrelated panic is not evidence
of failing audio hardware. Bound output and report actual search coverage.

## When tool playback differs from manual playback

If a speech tool glitches while manual playback is clean, inspect its actual
host player, invocation, and launch context before blaming the synthesizer.
Determine whether it plays a complete local file or streams chunks. A returned
queue job ID proves acceptance, not playback completion or clean sound. Retain
the exact generated file before any automatic cleanup when possible; generating
the same text again may produce different audio.

Compare the same file and player under the tool's launch classification and
under ordinary application scheduling. On macOS, a LaunchAgent's
`ProcessType=Background` imposes resource limits; `Interactive` uses application
resource limits. Inspect the exact plist and `ps` priority. Consult the installed
`man launchd.plist` and `man taskpolicy` for the current platform. A simple
`taskpolicy -b` test is not necessarily equivalent to launchd's Background
classification; different policy mechanisms can affect scheduling differently.

Use authorized, temporary one-shot launch jobs for an exact classification
comparison if needed. Give them unique labels, record each interval, verify the
observed process priority, and unload only those exact diagnostic jobs afterward.
Keep changes to the actual service separate from this experiment. If results
justify a durable fix, update the declared source and preserve pending queued
messages before restarting a service. Avoid exposing credentials from process
environments, launch configuration, or service logs.

## Interpret and finish

- Pops at the same file positions across independent devices/decoders favor a
  source defect. Clean playback on another device weakens that hypothesis.
- Original MP3 bad and WAV clean favors a decoding/conversion-path issue.
  Follow up with a WAV at the original rate and channel count, then change
  rate or channel count separately to isolate the responsible variable.
- Artifacts across built-in and external outputs favor a shared playback,
  routing, or scheduling issue over a fault confined to one speaker assembly.
- Clean tone and file comparisons after an earlier overload burst support an
  intermittent timing issue. Startup CPU/disk activity is a hypothesis unless
  measured at the affected interval; present-day load cannot prove past cause.
- No overload events does not exclude audible distortion. No hardware-fault
  signatures does not certify hardware health. Require listening feedback and
  preserve uncertainty about intermittent failures.

When symptoms persist, change one relevant setting at a time and compare again.
Sample rate is adjustable in Audio MIDI Setup. Restarting CoreAudio interrupts
audio; driver disabling/removal and reboot have broader effects. Use these only
when justified by evidence and within existing permission, explaining the
expected interruption. Stop changing settings when playback is clear and the
available evidence no longer supports a useful intervention.

Restore temporary routing and format changes to the recorded baseline unless
the user chooses a verified improvement. Report actual changes, tested outputs,
audible results, log counts, and what remains unproven. Keep generated files in
temporary storage; retain only the compact operational outcome, not raw logs,
hardware identifiers, private speech, or audio recordings in a skill/repository.

For persistent hardware suspicion, offer Apple Diagnostics. It requires a
shutdown/startup workflow and user participation; do not claim to have run it
from a log inspection. Check Apple's current instructions before guiding it.

Authoritative references:

- [Audio MIDI Setup device configuration](https://support.apple.com/guide/audio-midi-setup/set-up-audio-devices-ams59f301fda/mac)
- [Apple Diagnostics](https://support.apple.com/en-us/102550)
