#!/bin/sh
# agent-policy managed MCP reconciliation
set -eu
policy_home="${AGENT_POLICY_HOME:-$HOME/.local/share/agent-policy}"
exec "${AGENT_POLICY_HOME:-$HOME/.local/share/agent-policy}/agent-policy" register-mcp --all-installed --profile "default" --method "link" --from-chezmoi --mcp-server openrouter-fish-tts --mcp-server document-service --mcp-server agent-policy-tooling --tooling-approval-mode "approve"
