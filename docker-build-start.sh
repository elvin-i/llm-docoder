#!/usr/bin/env bash
DOCKER_BUILDKIT=1 docker build -t llm-docoder:latest docker

set -euo pipefail

IMAGE="llm-docoder:latest"

echo "🐳 检查当前运行的 $IMAGE 容器..."

CONTAINERS=$(docker ps --filter "ancestor=$IMAGE" --format "{{.Names}} {{.Mounts}}")
CONTAINER_NAMES=()
i=1

if [ -n "$CONTAINERS" ]; then
  echo "当前运行的容器："
  while read -r line; do
    NAME=$(echo "$line" | awk '{print $1}')
    MOUNTS=$(echo "$line" | cut -d' ' -f2-)
    echo "  [$i] $NAME (挂载: $MOUNTS)"
    CONTAINER_NAMES[$i]="$NAME"
    ((i++))
  done <<< "$CONTAINERS"
  echo "  [n] 启动新容器"
fi

read -r -p "请选择容器编号或 n 新建容器: " choice

if [[ "$choice" != "n" && -n "${CONTAINER_NAMES[$choice]:-}" ]]; then
  docker exec -it "${CONTAINER_NAMES[$choice]}" bash
  exit 0
fi

read -r -p "请输入新容器名称: " CONTAINER_NAME
read -r -p "请输入本地 workspace 目录（绝对路径）: " LOCAL_WORKSPACE

EXISTING=$(docker ps --filter "ancestor=$IMAGE" --format "{{.Names}} {{.Mounts}}" | grep -F "$LOCAL_WORKSPACE" | awk '{print $1}' || true)
if [ -n "$EXISTING" ]; then
  echo "⚠️ 注意: 该目录已被容器 $EXISTING 挂载"
  read -r -p "是否直接进入该容器？(y/n): " enter_existing
  if [[ "$enter_existing" == "y" ]]; then
    docker exec -it "$EXISTING" bash
    exit 0
  fi
fi

if [ ! -d "$LOCAL_WORKSPACE" ]; then
  echo "目录不存在，正在创建..."
  mkdir -p "$LOCAL_WORKSPACE"
fi

echo "🚀 启动容器 $CONTAINER_NAME ..."
docker run -it --rm \
  --name "$CONTAINER_NAME" \
  -v "$LOCAL_WORKSPACE:/workspace" \
  -v llm-docoder-data:/root/.llm \
  $IMAGE
