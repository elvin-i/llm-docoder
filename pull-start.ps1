#Requires -Version 5.1
$ErrorActionPreference = "Stop"

$IMAGE_NAME = "llm-docoder:latest"
$REMOTE_IMAGE = "registry.cn-beijing.aliyuncs.com/buukle-library/$IMAGE_NAME"
$CONTAINER_PREFIX = "llm-docoder"
$MANAGED_LABEL = "llm-docoder.managed=1"

function Resolve-HostPath {
    param([Parameter(Mandatory = $true)][string]$Path)

    $p = [Environment]::ExpandEnvironmentVariables($Path).Trim()

    # Expand leading ~ to home (important for docker -v)
    if ($p -match '^~([\\/].*)?$') {
        $rest = $Matches[1]
        if (-not $rest) { $rest = "" }
        $rest = $rest -replace '^[\\/]', ''
        $p = if ($rest) { Join-Path $HOME $rest } else { $HOME }
    }

    try {
        return [System.IO.Path]::GetFullPath($p)
    }
    catch {
        return $p
    }
}

function Assert-LastExitCode {
    param([Parameter(Mandatory = $true)][string]$CommandLine)
    if ($LASTEXITCODE -ne 0) {
        Write-Error "❌ 命令失败 (exit $LASTEXITCODE): $CommandLine"
        exit $LASTEXITCODE
    }
}

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

function Get-DockerServiceName {
    $candidates = @(
        "com.docker.service", # Docker Desktop
        "docker"              # Docker Engine (Windows Server)
    )

    foreach ($n in $candidates) {
        $svc = Get-Service -Name $n -ErrorAction SilentlyContinue
        if ($null -ne $svc) {
            return $n
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

    $hasSupport = $false

    $dockerDesktopExe = Get-DockerDesktopExe
    if ($dockerDesktopExe) {
        $hasSupport = $true
        Write-Host "🐳 Docker Desktop 未启动，正在启动..."
        try {
            Start-Process -FilePath $dockerDesktopExe | Out-Null
        }
        catch {
            Write-Host "⚠️ 启动 Docker Desktop 失败：$($_.Exception.Message)"
        }
    }

    $svcName = Get-DockerServiceName
    if ($svcName) {
        $hasSupport = $true
        try {
            $svc = Get-Service -Name $svcName
            if ($svc.Status -ne 'Running') {
                Write-Host "🐳 Docker 服务未运行，正在启动... ($svcName)"
                Start-Service -Name $svcName
            }
        }
        catch {
            Write-Host "⚠️ 无法启动 Docker 服务 $svcName：$($_.Exception.Message)"
            Write-Host "   你可能需要以管理员身份运行 PowerShell，或手动启动该服务。"
        }
    }

    if (-not $hasSupport) {
        Write-Host "❌ Docker 未就绪（docker info 失败），且未能自动启动 Docker Desktop/服务。"
        Write-Host "请先启动 Docker Engine/Docker Desktop 后重试。"
        exit 1
    }

    $deadline = (Get-Date).AddSeconds($TimeoutSeconds)
    Write-Host -NoNewline "⏳ 等待 Docker 启动"

    while ($true) {
        if ((Get-Date) -ge $deadline) {
            Write-Host ""
            Write-Error "❌ 等待超时（${TimeoutSeconds}s）。请手动确认 Docker 已启动后重试。"
            exit 1
        }

        if (Test-DockerReady) {
            break
        }

        Write-Host -NoNewline "."
        Start-Sleep -Seconds 2
    }

    Write-Host ""
    Write-Host "✅ Docker 已启动"
}

Need-Command docker
$timeoutSeconds = 180
if ($null -ne $Env:DOCKER_START_TIMEOUT_SECONDS -and $Env:DOCKER_START_TIMEOUT_SECONDS -ne "") {
    if ($Env:DOCKER_START_TIMEOUT_SECONDS -notmatch '^\d+$') {
        Write-Error "DOCKER_START_TIMEOUT_SECONDS 必须是数字（秒），当前: $Env:DOCKER_START_TIMEOUT_SECONDS"
        exit 1
    }
    $timeoutSeconds = [int]$Env:DOCKER_START_TIMEOUT_SECONDS
}
Ensure-DockerReady -TimeoutSeconds $timeoutSeconds

Write-Host "📦 拉取镜像: $REMOTE_IMAGE"
docker pull $REMOTE_IMAGE
Assert-LastExitCode "docker pull $REMOTE_IMAGE"

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

        # 不使用 attach：避免在容器内 exit 时让主进程结束导致容器停止
        $running = ""
        try {
            $running = (docker inspect -f '{{.State.Running}}' $target 2>$null).Trim()
        }
        catch {
            $running = ""
        }

        if ($running -ne "true") {
            docker start $target | Out-Null
            Assert-LastExitCode "docker start $target"
        }

        $runningAfter = ""
        try {
            $runningAfter = (docker inspect -f '{{.State.Running}}' $target 2>$null).Trim()
        }
        catch {
            $runningAfter = ""
        }

        if ($runningAfter -ne "true") {
            Write-Error "❌ 容器启动后立即退出（主进程未保持运行）。建议新建容器（会以 -d 后台模式启动）。"
            exit 1
        }

        docker exec -it $target bash
        exit $LASTEXITCODE
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

$existingNames = docker ps -a --format "{{.Names}}"
Assert-LastExitCode "docker ps -a --format {{.Names}}"

if ($existingNames | Where-Object { $_ -eq $containerName }) {
    Write-Error "❌ 已存在同名容器: $containerName"
    exit 1
}

$hostWorkspace = Read-Host "请输入 workspace 挂载的宿主机路径 (例如 C:\workspace)"
if (-not $hostWorkspace) {
    Write-Error "❌ workspace 路径不能为空"
    exit 1
}

$hostWorkspace = Resolve-HostPath $hostWorkspace

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

$hostKeyDir = Resolve-HostPath $hostKeyDir

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

docker run -dit `
  --name $containerName `
  --label $MANAGED_LABEL `
  -v "${hostWorkspace}:/workspace" `
  -v "${hostKeyDir}:/root/.config/llm-docoder" `
  $REMOTE_IMAGE | Out-Null
Assert-LastExitCode "docker run -dit --name $containerName ..."

docker exec -it $containerName bash
exit $LASTEXITCODE
