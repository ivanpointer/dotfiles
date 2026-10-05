#!/usr/bin/env python3
"""Queue a concise completion alert through the local OpenRouter Fish Audio service.

This compatibility command preserves the established ``speak "summary"``
interface. It does not render or play audio itself: the loopback service owns
the reference voice, FIFO queue, renderer, and host audio player.
"""

from __future__ import annotations

import argparse
import json
import os
from pathlib import Path
import subprocess
import sys
import urllib.error
import urllib.request


def scope_identity(directory: Path | None = None) -> str:
    """Use the repository root, or the current directory outside a repository."""
    directory = (directory or Path.cwd()).resolve()
    try:
        result = subprocess.run(
            ["git", "-C", str(directory), "rev-parse", "--show-toplevel"],
            capture_output=True,
            text=True,
        )
        if result.returncode == 0 and result.stdout.strip():
            directory = Path(result.stdout.strip()).resolve()
    except OSError:
        pass
    return "scope:" + str(directory)


def main(argv: list[str]) -> int:
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("--voice", default=os.environ.get("OPENROUTER_FISH_TTS_DEFAULT_VOICE", "auto"))
    parser.add_argument("--agent", default=os.environ.get("OPENROUTER_FISH_TTS_AGENT_ID") or scope_identity())
    parser.add_argument("--set-voice", metavar="VOICE")
    parser.add_argument("--set-style", choices=("on", "off"), metavar="ON_OR_OFF")
    parser.add_argument("--set-style-strength", choices=("light", "medium", "strong"), metavar="STRENGTH")
    parser.add_argument("--global-style", action="store_true", help="apply --set-style to the machine default")
    playback = parser.add_mutually_exclusive_group()
    playback.add_argument("--mute", action="store_true", help="mute speech on this host until explicitly unmuted")
    playback.add_argument("--unmute", action="store_true", help="clear manual mute; Zoom protection still applies")
    playback.add_argument("--auto-mute-zoom", choices=("on", "off"), help="suppress speech during Zoom audio activity (macOS)")
    playback.add_argument("--playback-status", action="store_true", help="show manual mute and Zoom detection status")
    parser.add_argument("--url", default=os.environ.get("OPENROUTER_FISH_TTS_SPEAK_URL", "http://127.0.0.1:8766/api/speak"))
    parser.add_argument("--dry-run", action="store_true")
    parser.add_argument("text", nargs="*")
    args = parser.parse_args(argv)
    playback_control = args.mute or args.unmute or args.auto_mute_zoom or args.playback_status
    if playback_control:
        if args.text or args.set_voice or args.set_style or args.set_style_strength:
            parser.error("choose playback control or speech/voice settings, not both")
        payload = ({"muted": args.mute} if args.mute or args.unmute else
                   {"auto_mute_zoom": args.auto_mute_zoom == "on"} if args.auto_mute_zoom else None)
        endpoint = args.url.rsplit("/api/speak", 1)[0] + "/api/settings/playback"
        if args.dry_run:
            print(json.dumps({"status": "would-read" if payload is None else "would-update", "url": endpoint, "settings": payload}))
            return 0
        request = urllib.request.Request(endpoint, data=json.dumps(payload).encode() if payload else None,
                                         headers={"Content-Type": "application/json"}, method="PUT" if payload else "GET")
        try:
            with urllib.request.urlopen(request, timeout=30) as response:
                print(response.read().decode())
            return 0
        except (urllib.error.URLError, OSError) as error:
            print("openrouter-fish-tts playback control failed: " + str(error), file=sys.stderr)
            return 2
    if args.set_voice or args.set_style or args.set_style_strength:
        if args.text:
            parser.error("text is not accepted with a persistent setting")
        if sum(value is not None for value in (args.set_voice, args.set_style, args.set_style_strength)) > 1:
            parser.error("choose one persistent setting at a time")
        if args.set_voice:
            payload = {"voice": args.set_voice}
            endpoint = args.url.rsplit("/api/speak", 1)[0] + "/api/settings/voice"
        else:
            payload = ({"enabled": args.set_style == "on"} if args.set_style
                       else {"strength": args.set_style_strength})
            endpoint = args.url.rsplit("/api/speak", 1)[0] + "/api/settings/style"
        if args.agent and not args.global_style:
            payload["agent_id"] = args.agent
        request = urllib.request.Request(endpoint, data=json.dumps(payload).encode(),
                                         headers={"Content-Type": "application/json"}, method="PUT")
        try:
            with urllib.request.urlopen(request, timeout=30) as response:
                print(response.read().decode())
            return 0
        except (urllib.error.URLError, OSError) as error:
            print("openrouter-fish-tts voice preference failed: " + str(error), file=sys.stderr)
            return 2
    if not args.text:
        parser.error("text is required unless --set-voice is used")
    payload = {"voice": args.voice, "text": " ".join(args.text)}
    if args.agent:
        payload["agent_id"] = args.agent
    if args.dry_run:
        print(json.dumps({"status": "would-queue", **payload}))
        return 0
    request = urllib.request.Request(args.url, data=json.dumps(payload).encode(),
                                     headers={"Content-Type": "application/json"}, method="POST")
    try:
        with urllib.request.urlopen(request, timeout=30) as response:
            print(response.read().decode())
        return 0
    except urllib.error.HTTPError as error:
        print(f"openrouter-fish-tts speak request rejected ({error.code}): " + error.read().decode(errors="replace"),
              file=sys.stderr)
        return 2
    except (urllib.error.URLError, OSError) as error:
        print("openrouter-fish-tts speak request failed: " + str(error), file=sys.stderr)
        return 2


if __name__ == "__main__":
    raise SystemExit(main(sys.argv[1:]))
