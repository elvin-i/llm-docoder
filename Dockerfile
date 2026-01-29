ARG BASE_IMAGE=ubuntu:24.04
FROM ${BASE_IMAGE}

ENV DEBIAN_FRONTEND=noninteractive
ENV LANG=C.UTF-8
ENV LC_ALL=C.UTF-8

# Keep our wrappers first; also include opencode default install path
ENV PATH="/usr/local/bin:/root/.opencode/bin:/root/.local/bin:/usr/local/sbin:/usr/sbin:/usr/bin:/sbin:/bin"

# Disable opencode auto-update checks (keeps pinned version stable)
ENV OPENCODE_DISABLE_AUTOUPDATE=true

RUN apt-get update && apt-get install -y --no-install-recommends \
    bash ca-certificates curl git jq openssh-client \
    tzdata unzip xz-utils tar gzip \
  && rm -rf /var/lib/apt/lists/*

# ---- Pin versions ----
ARG OPENCODE_VERSION=1.1.42
ARG CLAUDE_VERSION=2.1.23

# Install Claude Code (pinned): installer accepts a specific version argument
RUN curl -fsSL https://claude.ai/install.sh | bash -s ${CLAUDE_VERSION}

# Install OpenCode (pinned): install script supports --version <ver>
RUN curl -fsSL https://opencode.ai/install | bash -s -- --version ${OPENCODE_VERSION}

# ---- Prewarm OpenCode cache (providers) at build time ----
RUN mkdir -p /root/.cache/opencode
COPY container/prewarm-opencode-cache.sh /usr/local/bin/prewarm-opencode-cache.sh
RUN chmod +x /usr/local/bin/prewarm-opencode-cache.sh && /usr/local/bin/prewarm-opencode-cache.sh

# Workspace & configs
RUN mkdir -p /workspace \
 && mkdir -p /root/.config/opencode \
 && mkdir -p /root/.config/llm-docoder \
 && mkdir -p /usr/local/bin

COPY container/entrypoint.sh /usr/local/bin/entrypoint.sh
COPY container/llm-docoder-setup /usr/local/bin/llm-docoder-setup
COPY container/claude-api-key-helper.sh /usr/local/bin/claude-api-key-helper.sh
RUN chmod +x /usr/local/bin/claude-api-key-helper.sh

COPY container/wrappers/opencode /usr/local/bin/opencode
COPY container/wrappers/claude /usr/local/bin/claude


RUN chmod +x \
  /usr/local/bin/entrypoint.sh \
  /usr/local/bin/llm-docoder-setup \
  /usr/local/bin/opencode \
  /usr/local/bin/claude

WORKDIR /workspace
ENTRYPOINT ["/usr/local/bin/entrypoint.sh"]
CMD ["bash"]
