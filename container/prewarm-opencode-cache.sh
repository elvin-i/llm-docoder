#!/usr/bin/env bash
set -euo pipefail

CACHE_DIR="/root/.cache/opencode"
mkdir -p "$CACHE_DIR"

# Find bun (opencode installs a bundled bun in many builds)
BUN=""
if [[ -x "/root/.opencode/bin/bun" ]]; then
  BUN="/root/.opencode/bin/bun"
elif command -v bun >/dev/null 2>&1; then
  BUN="$(command -v bun)"
fi

if [[ -z "$BUN" ]]; then
  echo "[prewarm] bun not found; skipping cache prewarm."
  exit 0
fi

echo "[prewarm] Using bun: $BUN"
echo "[prewarm] Prewarming OpenCode cache in: $CACHE_DIR"

# Pre-install provider packages that opencode will otherwise download on first run
"$BUN" add --cwd "$CACHE_DIR" --force --exact \
  @ai-sdk/openai \
  @ai-sdk/openai-compatible

echo "[prewarm] Done."
