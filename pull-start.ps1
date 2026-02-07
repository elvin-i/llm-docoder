#Requires -Version 5.1
$ErrorActionPreference = "Stop"

$IMAGE_NAME = "llm-docoder:latest"
$REMOTE_IMAGE = "registry.cn-beijing.aliyuncs.com/buukle-library/$IMAGE_NAME"
$CONTAINER_PREFIX = "llm-docoder"
$MANAGED_LABEL = "llm-docoder.managed=1"

function Need-Command {
    param([Parameter(Mandatory = $true)][string]$Name)
    if (-not (Get-Command $Name -ErrorAction SilentlyContinue)) {
        Write-Error "❌ 未找到命令: $Name"
        exit 1
    }
}

function Get-DockerDesktopExe {
    $candidates = @(
        "$Env:ProgramFiles\Docker\Docker\Docker Desktop.exe",
        "$Env:ProgramFiles(x86)\Docker\Docker\Docker Desktop.exe"
    )

    foreach ($p in $candidates) {
        if ($p -and (Test-Path $p)) {
            return $p
        }
    }
    return $null
}

function Ensure-DockerReady {
    param([int]$TimeoutSeconds = 180)

    function Test-DockerReady {
        & docker info 1>$null 2>$null
        return ($LASTEXITCODE -eq 0)
    }

    if (Test-DockerReady) {
        Write-Host "✅ Docker 已就绪"
        return
    }

    $dockerDesktopExe = Get-DockerDesktopExe
    if ($dockerDesktopExe) {
        Write-Host "🐳 Docker Desktop 未启动，正在启动..."
        Start-Process -FilePath $dockerDesktopExe | Out-Null
    }
    else {
        Write-Host "❌ Docker 未就绪（docker info 失败），且未检测到 Docker Desktop。"
        Write-Host "请先启动 Docker Engine/Docker Desktop 后重试。"
        exit 1
    }

    $deadline = (Get-Date).AddSeconds($TimeoutSeconds)
    Write-Host -NoNewline "⏳ 等待 Docker Desktop 启动"

    while ($true) {
        if ((Get-Date) -ge $deadline) {
            Write-Host ""
            Write-Error "❌ 等待超时（${TimeoutSeconds}s）。请手动确认 Docker Desktop 已启动后重试。"
            exit 1
        }

        if (Test-DockerReady) {
            break
        }

        Write-Host -NoNewline "."
        Start-Sleep -Seconds 2
    }

    Write-Host ""
    Write-Host "✅ Docker Desktop 已启动"
}

Need-Command docker
$timeoutSeconds = 180
if ($Env:DOCKER_START_TIMEOUT_SECONDS -match '^\d+$') {
    $timeoutSeconds = [int]$Env:DOCKER_START_TIMEOUT_SECONDS
}
Ensure-DockerReady -TimeoutSeconds $timeoutSeconds

Write-Host "📦 拉取镜像: $REMOTE_IMAGE"
docker pull $REMOTE_IMAGE

#######################################
# 3. 查找已有容器
#######################################
$existing = @(
    @(docker ps -a --filter "label=$MANAGED_LABEL" --format "{{.Names}}" 2>$null)
    @(docker ps -a --filter "ancestor=$REMOTE_IMAGE" --format "{{.Names}}" 2>$null)
    @(docker ps -a --filter "ancestor=$IMAGE_NAME" --format "{{.Names}}" 2>$null)
) | ForEach-Object { $_ } | ForEach-Object { $_.Trim() } | Where-Object { $_ } | Sort-Object -Unique

if ($existing) {
    Write-Host ""
    Write-Host "🔍 检测到以下已有容器（来自镜像 $IMAGE_NAME）："

    $containers = @($existing)
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
# 5. api-key 持久化目录
#######################################
$defaultKeyDir = Join-Path $HOME ".llm-docoder"
$hostKeyDir = Read-Host "请输入 api-key 持久化目录 [默认: $defaultKeyDir]"
if (-not $hostKeyDir) {
    $hostKeyDir = $defaultKeyDir
}

if (-not (Test-Path $hostKeyDir)) {
    Write-Host "📁 api-key 目录不存在，创建目录: $hostKeyDir"
    New-Item -ItemType Directory -Path $hostKeyDir -Force | Out-Null
}

#######################################
# 6. 启动容器
#######################################
Write-Host ""
Write-Host "🚀 启动新容器:"
Write-Host "  容器名: $containerName"
Write-Host "  挂载: $hostWorkspace -> /workspace"
Write-Host "  挂载: $hostKeyDir -> /root/.config/llm-docoder (env.sh)"
Write-Host ""

docker run -it `
  --name $containerName `
  --label $MANAGED_LABEL `
  -v "${hostWorkspace}:/workspace" `
  -v "${hostKeyDir}:/root/.config/llm-docoder" `
  $REMOTE_IMAGE
