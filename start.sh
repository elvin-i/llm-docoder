#!/usr/bin/env bash
set -euo pipefail

IMAGE_NAME="llm-docoder:latest"

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
  -v "${HOST_WORKSPACE}:/workspace" \
  "${IMAGE_NAME}"
