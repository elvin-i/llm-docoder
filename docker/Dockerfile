FROM python:3.11-slim

ARG NPM_REGISTRY=https://registry.npmjs.org/
ARG USE_ALIYUN_MIRROR=0

# APT 源：根据当前 Debian codename 自动配置
RUN set -eux; \
  . /etc/os-release; \
  CODENAME="${VERSION_CODENAME:-}"; \
  if [ -z "$CODENAME" ]; then \
    CODENAME="$(awk -F= '/VERSION_CODENAME/{print $2}' /etc/os-release | tr -d '"')"; \
  fi; \
  echo "Detected Debian codename: $CODENAME"; \
  if [ "$USE_ALIYUN_MIRROR" = "1" ]; then \
    echo "deb http://mirrors.aliyun.com/debian/ ${CODENAME} main contrib non-free non-free-firmware" > /etc/apt/sources.list; \
    echo "deb http://mirrors.aliyun.com/debian/ ${CODENAME}-updates main contrib non-free non-free-firmware" >> /etc/apt/sources.list; \
    echo "deb http://mirrors.aliyun.com/debian-security/ ${CODENAME}-security main contrib non-free non-free-firmware" >> /etc/apt/sources.list; \
  else \
    echo "deb http://deb.debian.org/debian ${CODENAME} main contrib non-free non-free-firmware" > /etc/apt/sources.list; \
    echo "deb http://deb.debian.org/debian ${CODENAME}-updates main contrib non-free non-free-firmware" >> /etc/apt/sources.list; \
    echo "deb http://deb.debian.org/debian-security ${CODENAME}-security main contrib non-free non-free-firmware" >> /etc/apt/sources.list; \
  fi

RUN apt-get update \
 && apt-get install -y --no-install-recommends \
    git curl vim tree fd-find ca-certificates bash build-essential xz-utils \
    ripgrep fzf \
 && rm -rf /var/lib/apt/lists/*

# Node.js 20.x tarball 安装
ENV NODE_VERSION=20.6.1
RUN curl -fsSL --http1.1 --retry 5 --retry-delay 2 \
      https://nodejs.org/dist/v$NODE_VERSION/node-v$NODE_VERSION-linux-x64.tar.xz -o node.tar.xz \
 && tar -xJf node.tar.xz -C /usr/local --strip-components=1 \
 && rm node.tar.xz \
 && node -v && npm -v

ENV PATH="/usr/local/bin:$PATH"
RUN npm config set registry ${NPM_REGISTRY}

# LiteLLM
RUN pip install --no-cache-dir "litellm[proxy]" fastapi uvicorn

# OpenCode CLI
RUN curl -fsSL --http1.1 --retry 5 --retry-delay 2 \
      https://raw.githubusercontent.com/opencode-ai/opencode/refs/heads/main/install | bash

# Claude Code CLI
RUN npm install -g @anthropic-ai/claude-code \
 && command -v claude \
 && (claude --version || true)

WORKDIR /workspace

# scripts
COPY entrypoint.sh /entrypoint.sh
COPY llm-setup.sh /usr/local/bin/llm-setup

COPY claude-api-key-helper /usr/local/bin/claude-api-key-helper

COPY opencode-gpt /usr/local/bin/opencode-gpt
COPY opencode-gpt4o /usr/local/bin/opencode-gpt4o
COPY opencode-qwen /usr/local/bin/opencode-qwen

COPY litellm.yaml /litellm.yaml

RUN chmod +x /entrypoint.sh /usr/local/bin/llm-setup \
    /usr/local/bin/claude-api-key-helper \
    /usr/local/bin/opencode-gpt /usr/local/bin/opencode-gpt4o /usr/local/bin/opencode-qwen

EXPOSE 4000
ENTRYPOINT ["/entrypoint.sh"]
