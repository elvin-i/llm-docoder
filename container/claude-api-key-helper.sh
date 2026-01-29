#!/bin/sh
set -eu

ENV_FILE="/root/.config/llm-docoder/env.sh"

if [ -f "$ENV_FILE" ]; then
  # shellcheck disable=SC1090
  . "$ENV_FILE"
fi

# Only print the token/key. Claude Code will send it as headers.
if [ -n "${ANTHROPIC_API_KEY:-}" ]; then
  printf "%s" "$ANTHROPIC_API_KEY"
else
  printf "%s" ""
fi
