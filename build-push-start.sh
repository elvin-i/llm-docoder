#!/usr/bin/env bash
set -euo pipefail

IMAGE_NAME="llm-docoder:latest"
REMOTE_IMAGE="registry.cn-beijing.aliyuncs.com/buukle-library/${IMAGE_NAME}"
MANAGED_LABEL="llm-docoder.managed=1"

DOCKER_START_TIMEOUT_SECONDS="${DOCKER_START_TIMEOUT_SECONDS:-180}"

need_cmd() {
  if ! command -v "$1" >/dev/null 2>&1; then
    echo "❌ 未找到命令: $1"
    exit 1
  fi
}

ensure_docker_ready() {
  if docker info >/dev/null 2>&1; then
    echo "✅ Docker 已就绪"
    return 0
  fi

  local os
  os="$(uname -s 2>/dev/null || echo unknown)"
  if [[ "${os}" == "Darwin" ]]; then
    if [[ ! -d "/Applications/Docker.app" ]]; then
      echo "❌ 未检测到 Docker Desktop（/Applications/Docker.app）"
      echo "请先安装 Docker Desktop 后再运行本脚本"
      exit 1
    fi

    echo "🐳 Docker Desktop 未启动，正在启动..."
    open -a Docker >/dev/null 2>&1 || true

    printf "⏳ 等待 Docker Desktop 启动"
    local i=0
    while ! docker info >/dev/null 2>&1; do
      i=$((i + 1))
      if (( i * 2 >= DOCKER_START_TIMEOUT_SECONDS )); then
        echo ""
        echo "❌ 等待超时（${DOCKER_START_TIMEOUT_SECONDS}s）。请手动启动 Docker Desktop 后重试。"
        exit 1
      fi
      printf "."
      sleep 2
    done
    echo ""
    echo "✅ Docker Desktop 已启动"
    return 0
  fi

  echo "❌ Docker 未就绪（docker info 失败）。"
  echo "请先启动 Docker daemon/Engine（例如 Docker Desktop 或 docker service）后重试。"
  exit 1
}

need_cmd docker
ensure_docker_ready

echo "🔨 构建镜像: ${IMAGE_NAME}"
docker build -t "${IMAGE_NAME}" .

echo "🏷️  打 tag: ${REMOTE_IMAGE}"
docker tag "${IMAGE_NAME}" "${REMOTE_IMAGE}"
# docker push "${REMOTE_IMAGE}"

read -r -p "请输入容器名称: " CONTAINER_NAME
if [[ -z "${CONTAINER_NAME}" ]]; then
  echo "容器名称不能为空"
  exit 1
fi

read -r -p "请输入 workspace 挂载的宿主机路径(例如 /Users/you/workspace): " HOST_WORKSPACE
if [[ -z "${HOST_WORKSPACE}" ]]; then
  echo "workspace 路径不能为空"
  exit 1
fi

HOST_WORKSPACE="${HOST_WORKSPACE/#\~/$HOME}"

if [[ ! -d "${HOST_WORKSPACE}" ]]; then
  echo "workspace 路径不存在，尝试创建: ${HOST_WORKSPACE}"
  mkdir -p "${HOST_WORKSPACE}"
fi

if docker ps -a --format '{{.Names}}' | grep -qx "${CONTAINER_NAME}"; then
  echo "已存在同名容器: ${CONTAINER_NAME}"
  echo "请先删除或换个名字：docker rm -f ${CONTAINER_NAME}"
  exit 1
fi

echo ""
echo "启动容器: ${CONTAINER_NAME}"
echo "挂载: ${HOST_WORKSPACE} -> /workspace"
echo ""

docker run -it \
  --name "${CONTAINER_NAME}" \
  --label "${MANAGED_LABEL}" \
  -v "${HOST_WORKSPACE}:/workspace" \
  "${IMAGE_NAME}"
