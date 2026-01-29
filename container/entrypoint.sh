#!/usr/bin/env bash
set -e

# Make sure our wrappers stay first even if installer modifies PATH
export PATH="/usr/local/bin:${PATH}"

# Auto-load env for the default shell in the container
ENV_FILE="/root/.config/llm-docoder/env.sh"
if [[ -f "$ENV_FILE" ]]; then
  # shellcheck disable=SC1090
  source "$ENV_FILE"
fi

cat <<'EOF'

============================================================
Welcome to llm-docoder container

1) First-time setup (API keys / model config):
   llm-docoder-setup

2) Claude Code:
   claude

3) OpenCode:
   opencode

If OpenCode behaves oddly after config changes:
  rm -rf ~/.cache/opencode
============================================================

EOF

exec "$@"
