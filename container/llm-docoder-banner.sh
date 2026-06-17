#!/usr/bin/env bash
# Print system info banner (called by entrypoint.sh and /root/.bashrc)
set -e

export PATH="/usr/local/bin:${PATH}"

ENV_FILE="/root/.config/llm-docoder/env.sh"
if [[ -f "$ENV_FILE" ]]; then
  set -a
  # shellcheck disable=SC1090
  source "$ENV_FILE"
  set +a
fi

echo ""
echo "============================================================"
echo " Welcome to llm-docoder container"
echo ""

. /etc/os-release 2>/dev/null && echo " OS: $PRETTY_NAME" || true

opencode_ver=$(opencode --version 2>/dev/null || echo "not found")
claude_ver=$(claude --version 2>/dev/null || echo "not found")
java_ver=$(java -version 2>&1 | head -1 || echo "not found")
python_ver=$(python3 --version 2>/dev/null || echo "not found")
maven_ver=$(mvn --version 2>&1 | head -1 || echo "not found")
node_ver=$(node --version 2>/dev/null || echo "not found")
npm_ver=$(npm --version 2>/dev/null || echo "not found")

nvm_ver="not found"
if [[ -s "${NVM_DIR:-/root/.nvm}/nvm.sh" ]]; then
  # shellcheck disable=SC1091
  . "${NVM_DIR:-/root/.nvm}/nvm.sh" && nvm_ver=$(nvm --version 2>/dev/null || echo "$nvm_ver")
fi

echo " OpenCode:  $opencode_ver"
echo " Claude:    $claude_ver"
echo " Java:      $java_ver"
echo " Python:    $python_ver"
echo " Maven:     $maven_ver"
echo " Node:      $node_ver"
echo " npm:       $npm_ver"
echo " nvm:       $nvm_ver"

echo ""
echo " Commands:  opencode | claude | llm-docoder-setup"
echo " Cache:     rm -rf ~/.cache/opencode (if odd behavior)"
echo "============================================================"
echo ""
