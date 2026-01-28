#!/usr/bin/env bash
set -euo pipefail

DIR=/root/.llm
FILE=$DIR/credentials.env
mkdir -p "$DIR"

echo "🔐 Configure API Keys (press Enter to skip any key):"
read -r -s -p "OpenAI API Key: " OPENAI_KEY || true
echo
read -r -s -p "Qwen/DashScope API Key: " QWEN_KEY || true
echo
read -r -s -p "Claude API Key: " CLAUDE_KEY || true
echo

{
  [ -n "${OPENAI_KEY:-}" ] && printf 'export OPENAI_API_KEY=%q\n' "$OPENAI_KEY"
  [ -n "${QWEN_KEY:-}" ]   && printf 'export QWEN_API_KEY=%q\n' "$QWEN_KEY"
  [ -n "${QWEN_KEY:-}" ]   && printf 'export DASHSCOPE_API_KEY=%q\n' "$QWEN_KEY"
  [ -n "${CLAUDE_KEY:-}" ] && printf 'export ANTHROPIC_API_KEY=%q\n' "$CLAUDE_KEY"
} > "$FILE"

chmod 600 "$FILE"

set -a
source "$FILE"
set +a

echo "✅ API Keys saved and environment updated."
echo "Now you can run: claude / opencode-gpt / opencode-gpt4o / opencode-qwen"
