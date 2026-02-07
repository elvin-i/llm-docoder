#!/bin/sh
set -eu

IMAGE_NAME="llm-docoder:latest"
REMOTE_IMAGE="registry.cn-beijing.aliyuncs.com/buukle-library/${IMAGE_NAME}"
CONTAINER_PREFIX="llm-docoder"
MANAGED_LABEL="llm-docoder.managed=1"

DOCKER_START_TIMEOUT_SECONDS="${DOCKER_START_TIMEOUT_SECONDS:-180}"

need_cmd() {
  if ! command -v "$1" >/dev/null 2>&1; then
    echo "❌ 未找到命令: $1"
    exit 1
  fi
}

ensure_docker_ready() {
  # Fast path
  if docker info >/dev/null 2>&1; then
    echo "✅ Docker 已就绪"
    return 0
  fi

  OS="$(uname -s 2>/dev/null || echo unknown)"

  if [ "${OS}" = "Darwin" ]; then
    if [ ! -d "/Applications/Docker.app" ]; then
      echo "❌ 未检测到 Docker Desktop（/Applications/Docker.app）"
      echo "请先安装 Docker Desktop 后再运行本脚本"
      exit 1
    fi

    echo "🐳 Docker Desktop 未启动，正在启动..."
    # macOS only
    open -a Docker >/dev/null 2>&1 || true

    printf "⏳ 等待 Docker Desktop 启动"
    i=0
    while ! docker info >/dev/null 2>&1; do
      i=$((i + 1))
      if [ $((i * 2)) -ge "${DOCKER_START_TIMEOUT_SECONDS}" ]; then
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

echo "📦 拉取镜像: ${REMOTE_IMAGE}"
docker pull "${REMOTE_IMAGE}"

#######################################
# 1. 查找已创建的容器（兼容旧版本）
#######################################
EXISTING_CONTAINERS="$({
  docker ps -a --filter "label=${MANAGED_LABEL}" --format "{{.Names}}" 2>/dev/null || true
  docker ps -a --filter "ancestor=${REMOTE_IMAGE}" --format "{{.Names}}" 2>/dev/null || true
  docker ps -a --filter "ancestor=${IMAGE_NAME}" --format "{{.Names}}" 2>/dev/null || true
} | sed '/^$/d' | sort -u)"

if [ -n "${EXISTING_CONTAINERS}" ]; then
  echo ""
  echo "🔍 检测到以下已有容器（来自镜像 ${IMAGE_NAME}）："

  i=1
  echo "${EXISTING_CONTAINERS}" | while IFS= read -r c; do
    echo "  [$i] $c"
    i=$((i + 1))
  done

  echo "  [N] 新建容器"
  echo ""

  printf "请选择要进入的容器编号，或输入 N 新建容器: "
  read CHOICE

  case "${CHOICE}" in
    [Nn])
      echo "➡️ 选择新建容器"
      ;;
    ''|*[!0-9]*)
      echo "❌ 无效选择，退出"
      exit 1
      ;;
    *)
      TARGET_CONTAINER="$(echo "${EXISTING_CONTAINERS}" | sed -n "${CHOICE}p")"
      if [ -z "${TARGET_CONTAINER}" ]; then
        echo "❌ 无效编号，退出"
        exit 1
      fi
      echo "➡️ 进入已有容器: ${TARGET_CONTAINER}"
      exec docker start -ai "${TARGET_CONTAINER}"
      ;;
  esac
else
  echo "ℹ️ 未发现已有容器，将直接创建新容器"
fi

#######################################
# 2. 新建容器流程
#######################################
DEFAULT_CONTAINER_NAME="${CONTAINER_PREFIX}-$(date +%Y%m%d%H%M%S)"
printf "请输入容器名称 [默认: %s]: " "${DEFAULT_CONTAINER_NAME}"
read CONTAINER_NAME

if [ -z "${CONTAINER_NAME}" ]; then
  CONTAINER_NAME="${DEFAULT_CONTAINER_NAME}"
fi

if docker ps -a --format '{{.Names}}' | grep -qx "${CONTAINER_NAME}"; then
  echo "❌ 已存在同名容器: ${CONTAINER_NAME}"
  exit 1
fi

printf "请输入 workspace 挂载的宿主机路径 (例如 ~/workspace): "
read HOST_WORKSPACE

if [ -z "${HOST_WORKSPACE}" ]; then
  echo "❌ workspace 路径不能为空"
  exit 1
fi

# 处理 ~
case "${HOST_WORKSPACE}" in
  "~"|"~/"*)
    HOST_WORKSPACE="${HOME}${HOST_WORKSPACE#\~}"
    ;;
esac

if [ ! -d "${HOST_WORKSPACE}" ]; then
  echo "📁 workspace 路径不存在，尝试创建: ${HOST_WORKSPACE}"
  mkdir -p "${HOST_WORKSPACE}"
fi

#######################################
# 3. 启动新容器
#######################################
echo ""
echo "🚀 启动新容器:"
echo "  容器名: ${CONTAINER_NAME}"
echo "  挂载: ${HOST_WORKSPACE} -> /workspace"
echo ""

exec docker run -it \
  --name "${CONTAINER_NAME}" \
  --label "${MANAGED_LABEL}" \
  -v "${HOST_WORKSPACE}:/workspace" \
  "${REMOTE_IMAGE}"
