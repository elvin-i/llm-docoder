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

# Print welcome banner
/usr/local/bin/llm-docoder-banner.sh

exec "$@"
