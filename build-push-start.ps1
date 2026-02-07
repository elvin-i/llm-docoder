#Requires -Version 5.1
$ErrorActionPreference = "Stop"

$IMAGE_NAME = "llm-docoder:latest"
$REMOTE_IMAGE = "registry.cn-beijing.aliyuncs.com/buukle-library/$IMAGE_NAME"
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
# 4. api-key 持久化目录
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
# 5. 检查容器是否存在
#######################################
if (docker ps -a --format "{{.Names}}" | Where-Object { $_ -eq $containerName }) {
    Write-Error "已存在同名容器: $containerName"
    Write-Error "请先删除或换个名字：docker rm -f $containerName"
    exit 1
}

#######################################
# 6. 启动容器
#######################################
Write-Host ""
Write-Host "🚀 启动容器: $containerName"
Write-Host "📂 挂载: $hostWorkspace -> /workspace"
Write-Host "📂 挂载: $hostKeyDir -> /root/.config/llm-docoder (env.sh)"
Write-Host ""

docker run -it `
  --name $containerName `
  --label $MANAGED_LABEL `
  -v "${hostWorkspace}:/workspace" `
  -v "${hostKeyDir}:/root/.config/llm-docoder" `
  $IMAGE_NAME
