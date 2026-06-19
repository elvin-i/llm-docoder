ARG BASE_IMAGE=ubuntu:24.04
FROM ${BASE_IMAGE}

ENV DEBIAN_FRONTEND=noninteractive
ENV LANG=C.UTF-8
ENV LC_ALL=C.UTF-8

# Keep our wrappers first; also include opencode default install path
ENV PATH="/usr/local/bin:/root/.opencode/bin:/root/.local/bin:/usr/local/sbin:/usr/sbin:/usr/bin:/sbin:/bin"

# Disable opencode auto-update checks (keeps pinned version stable)
ENV OPENCODE_DISABLE_AUTOUPDATE=true

ENV NVM_DIR=/root/.nvm

# ── ① Stable base packages (rarely changes) ─────────────────
RUN apt-get update && apt-get install -y --no-install-recommends \
    bash ca-certificates curl git jq openssh-client \
    tzdata unzip xz-utils tar gzip \
    openjdk-21-jdk maven \
    python3 python3-pip python3-venv \
  && rm -rf /var/lib/apt/lists/* \
  && ln -sf /usr/bin/python3 /usr/bin/python

# ── ② Node.js 22 LTS (changes on version bump) ──────────────
RUN curl -fsSL https://raw.githubusercontent.com/nvm-sh/nvm/v0.40.1/install.sh | bash
RUN . $NVM_DIR/nvm.sh && nvm install 22 && nvm alias default 22
RUN . $NVM_DIR/nvm.sh && \
    ln -sf $(which node) /usr/local/bin/node && \
    ln -sf $(which npm) /usr/local/bin/npm && \
    ln -sf $(which npx) /usr/local/bin/npx

# ── ③ Pinned AI tools (invalidated by OPENCODE_VERSION / CLAUDE_VERSION) ──
ARG OPENCODE_VERSION=1.17.7
ARG CLAUDE_VERSION=2.1.23

RUN curl -fsSL https://claude.ai/install.sh | bash -s ${CLAUDE_VERSION}
RUN curl -fsSL https://opencode.ai/install | bash -s -- --version ${OPENCODE_VERSION}

# ── ④ Prewarm OpenCode cache (invalidated when provider deps change) ──────
RUN mkdir -p /root/.cache/opencode
COPY container/prewarm-opencode-cache.sh /usr/local/bin/prewarm-opencode-cache.sh
RUN chmod +x /usr/local/bin/prewarm-opencode-cache.sh && /usr/local/bin/prewarm-opencode-cache.sh

# ── ⑤ Frequently-added apt packages (add new tools here, cache preserved) ─
RUN apt-get update && apt-get install -y --no-install-recommends \
    tmux \
  && rm -rf /var/lib/apt/lists/*

# ── ⑥ Scripts, configs, wrappers (change banner/setup/wrappers here) ──────
COPY container/tmux.conf /root/.tmux.conf
RUN mkdir -p /workspace /root/.config/opencode /root/.config/llm-docoder

COPY container/entrypoint.sh /usr/local/bin/entrypoint.sh
COPY container/llm-docoder-setup /usr/local/bin/llm-docoder-setup
COPY container/claude-api-key-helper.sh /usr/local/bin/claude-api-key-helper.sh
COPY container/llm-docoder-banner.sh /usr/local/bin/llm-docoder-banner.sh
COPY container/wrappers/opencode /usr/local/bin/opencode
COPY container/wrappers/claude /usr/local/bin/claude

RUN chmod +x \
  /usr/local/bin/entrypoint.sh \
  /usr/local/bin/llm-docoder-setup \
  /usr/local/bin/claude-api-key-helper.sh \
  /usr/local/bin/llm-docoder-banner.sh \
  /usr/local/bin/opencode \
  /usr/local/bin/claude

RUN echo '. /usr/local/bin/llm-docoder-banner.sh' >> /root/.bashrc

WORKDIR /workspace
ENTRYPOINT ["/usr/local/bin/entrypoint.sh"]
CMD ["bash"]
