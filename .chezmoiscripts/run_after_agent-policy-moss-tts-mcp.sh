#!/bin/sh
set -eu
exec "${AGENT_POLICY_HOME:-$HOME/.local/share/agent-policy}/agent-policy" register-mcp --all-installed --profile "dogfood" --method "link" --from-chezmoi --mcp-server "moss-tts" --mcp-server "document-service"
