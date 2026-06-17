# llm-docoder — AGENTS.md

Single-`Dockerfile` project that bundles pinned versions of **OpenCode** and **Claude Code** with auth isolation wrappers. No tests, no CI, no lint/typecheck.

## Repo layout

```
Dockerfile                    # pinned versions via ARG OPENCODE_VERSION / CLAUDE_VERSION
container/
  entrypoint.sh               # sources /root/.config/llm-docoder/env.sh, then exec CMD
  llm-docoder-setup           # interactive setup: writes env.sh + opencode.json + settings.json
  llm-docoder-banner.sh       # prints OS + tool version banner on container start and docker exec
  claude-api-key-helper.sh    # prints ANTHROPIC_API_KEY from env.sh (for Claude Code)
  prewarm-opencode-cache.sh   # bun add @ai-sdk/openai @ai-sdk/openai-compatible at build time
  wrappers/
    opencode                  # sources env.sh, unsets ANTHROPIC_*, execs real opencode
    claude                    # sources env.sh, unsets ANTHROPIC_API_KEY, execs real claude
pull-start.sh / .ps1          # docker pull + create/enter container (detached + exec)
build-push-start.sh / .ps1    # docker build + same container flow
```

## Key commands (host side)

| Action | Command |
|--------|---------|
| Pull & run | `./pull-start.sh` |
| Build & run (multi-arch) | `./build-push-start.sh` |
| Build only (current arch) | `docker build --build-arg OPENCODE_VERSION=1.15.12 --build-arg CLAUDE_VERSION=2.1.23 -t llm-docoder .` |
| Build multi-arch manually | `docker buildx build --platform linux/amd64,linux/arm64 -t your-registry/llm-docoder:latest --push .` |

## Key commands (container side)

| Action | Command |
|--------|---------|
| First-time setup | `llm-docoder-setup` |
| Run OpenCode | `opencode` (wrapper; unsets Anthropic vars) |
| Run Claude Code | `claude` (wrapper; apiKeyHelper-only auth) |
| Clear OpenCode cache | `rm -rf ~/.cache/opencode` |

## Auth isolation

- `opencode` wrapper unsets `ANTHROPIC_API_KEY`, `ANTHROPIC_AUTH_TOKEN`, `CLAUDE_CODE_API_KEY_HELPER_TTL_MS` before exec
- `claude` wrapper unsets `ANTHROPIC_API_KEY`; Claude reads key via `claude-api-key-helper.sh` which prints `$ANTHROPIC_API_KEY` from `env.sh` only

## Container startup quirk

Container runs in **detached** mode (`docker run -d`), then `docker exec -it ... bash` to enter. This prevents `exit` from stopping the container.

## OpenCode config

Auto-generated at `/root/.config/opencode/opencode.json` with providers:
- `openai` (official, `@ai-sdk/openai`)
- `dashscope` (OpenAI-compatible, `@ai-sdk/openai-compatible`)

Default model priority: `OPENAI_API_KEY` set → `openai/gpt-5.2`, else `dashscope/qwen3-coder-plus`.

## Build-time caching

`prewarm-opencode-cache.sh` uses OpenCode's bundled `bun` to pre-install `@ai-sdk/openai` and `@ai-sdk/openai-compatible` into `~/.cache/opencode` so first launch has no download delay.

## Key env vars

Written to `/root/.config/llm-docoder/env.sh` by setup: `OPENAI_API_KEY`, `DASHSCOPE_API_KEY`, `ANTHROPIC_API_KEY`; also `CLAUDE_CODE_API_KEY_HELPER_TTL_MS=3600000`.
