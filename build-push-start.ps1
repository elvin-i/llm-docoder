#Requires -Version 5.1
$ErrorActionPreference = "Stop"

$IMAGE_NAME = "llm-docoder:latest"
$REMOTE_IMAGE = "registry.cn-beijing.aliyuncs.com/buukle-library/$IMAGE_NAME"

#######################################
# 1. build & tag
#######################################
Write-Host "🔨 构建镜像: $IMAGE_NAME"
docker build -t $IMAGE_NAME .

Write-Host "🏷️  打 tag: $REMOTE_IMAGE"
docker tag $IMAGE_NAME $REMOTE_IMAGE

# 如需 push，取消下面注释
# docker push $REMOTE_IMAGE

#######################################
# 2. 容器名称
#######################################
$containerName = Read-Host "请输入容器名称"
if (-not $containerName) {
    Write-Error "容器名称不能为空"
    exit 1
}

#######################################
# 3. workspace
#######################################
$hostWorkspace = Read-Host "请输入 workspace 挂载的宿主机路径 (例如 C:\workspace)"
if (-not $hostWorkspace) {
    Write-Error "workspace 路径不能为空"
    exit 1
}

if (-not (Test-Path $hostWorkspace)) {
    Write-Host "📁 路径不存在，创建目录: $hostWorkspace"
    New-Item -ItemType Directory -Path $hostWorkspace -Force | Out-Null
}

#######################################
# 4. 检查容器是否存在
#######################################
if (docker ps -a --format "{{.Names}}" | Where-Object { $_ -eq $containerName }) {
    Write-Error "已存在同名容器: $containerName"
    Write-Error "请先删除或换个名字：docker rm -f $containerName"
    exit 1
}

#######################################
# 5. 启动容器
#######################################
Write-Host ""
Write-Host "🚀 启动容器: $containerName"
Write-Host "📂 挂载: $hostWorkspace -> /workspace"
Write-Host ""

docker run -it `
  --name $containerName `
  -v "${hostWorkspace}:/workspace" `
  $IMAGE_NAME
