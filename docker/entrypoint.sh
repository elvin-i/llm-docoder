#!/usr/bin/env bash
set -euo pipefail

mkdir -p /root/.llm

# 所有交互式 shell 自动加载 credentials.env（docker exec 也生效）
cat >/etc/profile.d/llm-credentials.sh <<'SH'
if [ -f /root/.llm/credentials.env ]; then
  set -a
  . /root/.llm/credentials.env
  set +a
fi
SH
chmod +x /etc/profile.d/llm-credentials.sh

grep -q "llm-credentials.sh" /root/.bashrc 2>/dev/null || \
  echo '[ -f /etc/profile.d/llm-credentials.sh ] && . /etc/profile.d/llm-credentials.sh' >> /root/.bashrc

# entrypoint 本次也加载一次
if [ -f /root/.llm/credentials.env ]; then
  set -a
  source /root/.llm/credentials.env
  set +a
fi

# 固定 Claude 配置目录（容器里更稳）
export CLAUDE_CONFIG_DIR=/root/.claude
mkdir -p "$CLAUDE_CONFIG_DIR"

# 强制 Claude Code 使用 apiKeyHelper（避免网页登录/OAuth）
cat > "$CLAUDE_CONFIG_DIR/settings.json" <<'JSON'
{
  "apiKeyHelper": "/usr/local/bin/claude-api-key-helper",
  "apiKeyHelperTtlMs": 3600000
}
JSON

git config --global --add safe.directory /workspace || true

if [ ! -f /root/.llm/credentials.env ]; then
  echo "⚠️ 尚未配置 API Key，请运行 llm-setup"
else
  grep -q 'OPENAI_API_KEY' /root/.llm/credentials.env || echo "⚠️ OpenAI API Key 未配置"
  (grep -q 'QWEN_API_KEY' /root/.llm/credentials.env || grep -q 'DASHSCOPE_API_KEY' /root/.llm/credentials.env) || echo "⚠️ Qwen/DashScope API Key 未配置"
  grep -q 'ANTHROPIC_API_KEY' /root/.llm/credentials.env || echo "⚠️ Claude API Key 未配置"
fi

echo "🧠 LLM Dev Container Ready"
echo "👉 First time: run llm-setup to configure API keys (can skip any key)"
echo "👉 Claude Code CLI: claude (no web login; uses apiKeyHelper)"
echo "👉 OpenCode default: opencode-gpt"
echo "👉 OpenCode gpt-4o:  opencode-gpt4o"
echo "👉 OpenCode qwen:    opencode-qwen"

exec bash
