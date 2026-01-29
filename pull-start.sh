#!/bin/sh
set -eu

IMAGE_NAME="llm-docoder:latest"
REMOTE_IMAGE="registry.cn-beijing.aliyuncs.com/buukle-library/${IMAGE_NAME}"
CONTAINER_PREFIX="llm-docoder"

echo "📦 拉取镜像: ${REMOTE_IMAGE}"
docker pull "${REMOTE_IMAGE}"

#######################################
# 1. 检查 Docker Desktop 是否存在（macOS）
#######################################
if [ ! -d "/Applications/Docker.app" ]; then
  echo "❌ 未检测到 Docker Desktop（/Applications/Docker.app）"
  echo "请先安装 Docker Desktop 后再运行本脚本"
  exit 1
fi

#######################################
# 2. 检查 Docker 是否启动
#######################################
if ! docker info >/dev/null 2>&1; then
  echo "🐳 Docker Desktop 未启动，正在启动..."
  open -a Docker

  printf "⏳ 等待 Docker Desktop 启动"
  while ! docker info >/dev/null 2>&1; do
    printf "..."
    sleep 2
  done
  echo ""
  echo "✅ Docker Desktop 已启动"
else
  echo "✅ Docker Desktop 已就绪"
fi

#######################################
# 3. 查找基于同一镜像的容器（sh 无数组方案）
#######################################
EXISTING_CONTAINERS="$(docker ps -a \
  --filter "ancestor=${IMAGE_NAME}" \
  --format "{{.Names}}" || true)"

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
# 4. 新建容器流程
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
# 5. 启动新容器
#######################################
echo ""
echo "🚀 启动新容器:"
echo "  容器名: ${CONTAINER_NAME}"
echo "  挂载: ${HOST_WORKSPACE} -> /workspace"
echo ""

exec docker run -it \
  --name "${CONTAINER_NAME}" \
  -v "${HOST_WORKSPACE}:/workspace" \
  "${REMOTE_IMAGE}"
