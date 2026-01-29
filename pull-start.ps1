#Requires -Version 5.1
$ErrorActionPreference = "Stop"

$IMAGE_NAME = "llm-docoder:latest"
$REMOTE_IMAGE = "registry.cn-beijing.aliyuncs.com/buukle-library/$IMAGE_NAME"
$CONTAINER_PREFIX = "llm-docoder"

Write-Host "📦 拉取镜像: $REMOTE_IMAGE"
docker pull $REMOTE_IMAGE

#######################################
# 1. 检查 Docker Desktop 是否安装
#######################################
$dockerExe = "$Env:ProgramFiles\Docker\Docker\Docker Desktop.exe"
if (-not (Test-Path $dockerExe)) {
    Write-Error "❌ 未检测到 Docker Desktop，请先安装 Docker Desktop"
    exit 1
}

#######################################
# 2. 检查 Docker 是否启动
#######################################
try {
    docker info | Out-Null
    Write-Host "✅ Docker Desktop 已就绪"
}
catch {
    Write-Host "🐳 Docker Desktop 未启动，正在启动..."
    Start-Process $dockerExe

    Write-Host -NoNewline "⏳ 等待 Docker Desktop 启动"
    while ($true) {
        try {
            docker info | Out-Null
            break
        }
        catch {
            Write-Host -NoNewline "..."
            Start-Sleep -Seconds 2
        }
    }
    Write-Host ""
    Write-Host "✅ Docker Desktop 已启动"
}

#######################################
# 3. 查找已有容器
#######################################
$existing = docker ps -a `
    --filter "ancestor=$IMAGE_NAME" `
    --format "{{.Names}}" 2>$null

if ($existing) {
    Write-Host ""
    Write-Host "🔍 检测到以下已有容器（来自镜像 $IMAGE_NAME）："

    $containers = $existing -split "`n"
    for ($i = 0; $i -lt $containers.Count; $i++) {
        Write-Host "  [$($i + 1)] $($containers[$i])"
    }
    Write-Host "  [N] 新建容器"
    Write-Host ""

    $choice = Read-Host "请选择要进入的容器编号，或输入 N 新建容器"

    if ($choice -match '^[Nn]$') {
        Write-Host "➡️ 选择新建容器"
    }
    elseif ($choice -match '^\d+$' -and
            [int]$choice -ge 1 -and
            [int]$choice -le $containers.Count) {

        $target = $containers[[int]$choice - 1]
        Write-Host "➡️ 进入已有容器: $target"
        docker start -ai $target
        exit 0
    }
    else {
        Write-Error "❌ 无效选择"
        exit 1
    }
}
else {
    Write-Host "ℹ️ 未发现已有容器，将直接创建新容器"
}

#######################################
# 4. 新建容器
#######################################
$defaultName = "$CONTAINER_PREFIX-$(Get-Date -Format yyyyMMddHHmmss)"
$containerName = Read-Host "请输入容器名称 [默认: $defaultName]"
if (-not $containerName) {
    $containerName = $defaultName
}

if (docker ps -a --format "{{.Names}}" | Where-Object { $_ -eq $containerName }) {
    Write-Error "❌ 已存在同名容器: $containerName"
    exit 1
}

$hostWorkspace = Read-Host "请输入 workspace 挂载的宿主机路径 (例如 C:\workspace)"
if (-not $hostWorkspace) {
    Write-Error "❌ workspace 路径不能为空"
    exit 1
}

if (-not (Test-Path $hostWorkspace)) {
    Write-Host "📁 路径不存在，创建目录: $hostWorkspace"
    New-Item -ItemType Directory -Path $hostWorkspace -Force | Out-Null
}

#######################################
# 5. 启动容器
#######################################
Write-Host ""
Write-Host "🚀 启动新容器:"
Write-Host "  容器名: $containerName"
Write-Host "  挂载: $hostWorkspace -> /workspace"
Write-Host ""

docker run -it `
  --name $containerName `
  -v "${hostWorkspace}:/workspace" `
  $REMOTE_IMAGE
