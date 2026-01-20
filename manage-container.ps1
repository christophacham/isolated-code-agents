<#
.SYNOPSIS
    AI CLI Docker Container Manager
    Manages Docker container with Claude Code, Qwen Code, Gemini CLI, Ollama, and PAL MCP

.DESCRIPTION
    Features:
    - Build the Docker image
    - Start container with code folder + persistent model storage
    - Stop/delete container (models survive!)
    - Download models for RTX 5090
    - Attach to running container

.NOTES
    Requires: Docker Desktop with WSL2 backend and NVIDIA Container Toolkit
    Models: Stored in Docker volume, persist across container restarts
#>

param(
    [string]$Action = "",
    [string]$CodePath = ""
)

$ErrorActionPreference = "Stop"
$ContainerName = "ai-cli-container"
$ImageName = "ai-cli-docker"
$ImageTag = "latest"
$VolumeName = "ai-cli-ollama-models"

# Colors
function Write-Color {
    param([string]$Message, [string]$Color = "White")
    Write-Host $Message -ForegroundColor $Color
}

function Show-Banner {
    Clear-Host
    Write-Color "==================================================" "Cyan"
    Write-Color "   AI CLI Docker Container Manager" "Yellow"
    Write-Color "   Claude Code | Qwen Code | Gemini CLI | Ollama" "Yellow"
    Write-Color "   with PAL MCP + RTX 5090 Optimizations" "Yellow"
    Write-Color "==================================================" "Cyan"
    Write-Host ""
}

function Test-DockerRunning {
    try { $null = docker info 2>&1; return $true }
    catch { return $false }
}

function Test-ContainerExists {
    $result = docker ps -a --filter "name=$ContainerName" --format "{{.Names}}" 2>$null
    return ($result -eq $ContainerName)
}

function Test-ContainerRunning {
    $result = docker ps --filter "name=$ContainerName" --filter "status=running" --format "{{.Names}}" 2>$null
    return ($result -eq $ContainerName)
}

function Test-ImageExists {
    $result = docker images --filter "reference=${ImageName}:${ImageTag}" --format "{{.Repository}}" 2>$null
    return ($result -eq $ImageName)
}

function Test-VolumeExists {
    $result = docker volume ls --filter "name=$VolumeName" --format "{{.Name}}" 2>$null
    return ($result -eq $VolumeName)
}

function Test-NvidiaGPU {
    try { $null = nvidia-smi 2>&1; return $true }
    catch { return $false }
}

function Get-VolumeSize {
    if (Test-VolumeExists) {
        try {
            # Get volume mount point and check size
            $inspect = docker volume inspect $VolumeName 2>$null | ConvertFrom-Json
            if ($inspect) {
                # Run a quick container to check size
                $size = docker run --rm -v "${VolumeName}:/data" alpine sh -c "du -sh /data 2>/dev/null | cut -f1" 2>$null
                if ($size) { return $size.Trim() }
            }
        } catch { }
        return "unknown"
    }
    return "not created"
}

function Build-Image {
    param([switch]$NoCache)

    Show-Banner
    if ($NoCache) {
        Write-Color "🔨 Rebuilding Docker Image (no cache)..." "Yellow"
    } else {
        Write-Color "🔨 Building Docker Image..." "Yellow"
    }
    Write-Host ""

    $scriptDir = Split-Path -Parent $MyInvocation.PSCommandPath
    if (-not $scriptDir) { $scriptDir = Get-Location }

    Write-Color "   Build context: $scriptDir" "Gray"
    Write-Host ""

    try {
        if ($NoCache) {
            docker build --no-cache -t "${ImageName}:${ImageTag}" $scriptDir
        } else {
            docker build -t "${ImageName}:${ImageTag}" $scriptDir
        }
        Write-Host ""
        Write-Color "✅ Image built successfully!" "Green"
        return $true
    }
    catch {
        Write-Color "❌ Failed to build image: $_" "Red"
        return $false
    }
}

function Start-Container {
    param([string]$MountPath)
    
    Show-Banner
    
    # Check if container is already running
    if (Test-ContainerRunning) {
        Write-Color "⚠️  Container '$ContainerName' is already running!" "Yellow"
        Write-Host ""
        $choice = Read-Host "Attach to it? (Y/n)"
        if ($choice -ne "n" -and $choice -ne "N") {
            Attach-Container
        }
        return
    }
    
    # Check if container exists but stopped
    if (Test-ContainerExists) {
        Write-Color "⚠️  Container '$ContainerName' exists but is stopped." "Yellow"
        Write-Host ""
        $choice = Read-Host "(R)estart, (D)elete and create new, or (C)ancel? [R/d/c]"
        
        switch ($choice.ToLower()) {
            "d" {
                Write-Color "🗑️  Removing existing container..." "Yellow"
                docker rm $ContainerName | Out-Null
            }
            "c" { return }
            default {
                Write-Color "🔄 Restarting existing container..." "Yellow"
                docker start $ContainerName | Out-Null
                Write-Color "✅ Container restarted!" "Green"
                
                # Wait for Ollama
                Write-Host "   Waiting for Ollama to start..."
                Start-Sleep -Seconds 5
                
                $choice = Read-Host "Attach to it? (Y/n)"
                if ($choice -ne "n" -and $choice -ne "N") {
                    Attach-Container
                }
                return
            }
        }
    }
    
    # Check if image exists
    if (-not (Test-ImageExists)) {
        Write-Color "⚠️  Docker image not found. Building..." "Yellow"
        if (-not (Build-Image)) { return }
    }
    
    # Get mount path
    if (-not $MountPath) {
        Write-Host ""
        Write-Color "📁 Enter the path to your code folder:" "Cyan"
        Write-Color "   Example: F:\source or C:\Projects\myapp" "Gray"
        Write-Host ""
        $MountPath = Read-Host "Path"
    }
    
    # Validate path
    if (-not (Test-Path $MountPath)) {
        Write-Color "❌ Path does not exist: $MountPath" "Red"
        return
    }
    
    # Convert to Docker-compatible path
    $DockerPath = $MountPath -replace '\\', '/'
    if ($DockerPath -match '^([A-Z]):') {
        $DriveLetter = $Matches[1].ToLower()
        $DockerPath = $DockerPath -replace '^[A-Z]:', "/$DriveLetter"
    }
    
    Write-Host ""
    Write-Color "🚀 Starting container..." "Yellow"
    Write-Color "   Workspace: $MountPath -> /workspace" "Gray"
    Write-Color "   Models: Docker volume '$VolumeName' -> /ollama-models" "Gray"
    
    # Build docker run command (no port exposure - Ollama only accessible within container)
    $dockerArgs = @(
        "run", "-it",
        "--name", $ContainerName,
        "-v", "${DockerPath}:/workspace",
        "-v", "${VolumeName}:/ollama-models",
        "-w", "/workspace",
        "-e", "NVIDIA_VISIBLE_DEVICES=all",
        "-e", "NVIDIA_DRIVER_CAPABILITIES=compute,utility",
        "-e", "OLLAMA_FLASH_ATTENTION=1",
        "-e", "OLLAMA_NUM_GPU=999",
        "-e", "OLLAMA_HOST=127.0.0.1:11434",
        "-e", "OLLAMA_MODELS=/ollama-models"
    )
    
    # Add GPU support if available
    if (Test-NvidiaGPU) {
        Write-Color "   GPU: NVIDIA GPU detected, enabling GPU support" "Green"
        $dockerArgs += "--gpus", "all"
    }
    else {
        Write-Color "   GPU: No NVIDIA GPU detected (CPU mode)" "Yellow"
    }
    
    $dockerArgs += "${ImageName}:${ImageTag}"
    
    Write-Host ""
    
    try {
        & docker @dockerArgs
    }
    catch {
        Write-Color "❌ Failed to start container: $_" "Red"
    }
}

function Stop-Container {
    Show-Banner
    
    if (-not (Test-ContainerRunning)) {
        Write-Color "ℹ️  No running container found." "Yellow"
        
        if (Test-ContainerExists) {
            Write-Host ""
            $choice = Read-Host "Container exists but stopped. Delete it? (y/N)"
            if ($choice -eq "y" -or $choice -eq "Y") {
                docker rm $ContainerName | Out-Null
                Write-Color "✅ Container deleted." "Green"
            }
        }
        return
    }
    
    Write-Color "🛑 Stopping container '$ContainerName'..." "Yellow"
    docker stop $ContainerName | Out-Null
    Write-Color "✅ Container stopped." "Green"
    Write-Color "💾 Models in volume '$VolumeName' are preserved." "Cyan"
    
    Write-Host ""
    $choice = Read-Host "Delete the container? (y/N)"
    if ($choice -eq "y" -or $choice -eq "Y") {
        docker rm $ContainerName | Out-Null
        Write-Color "✅ Container deleted (models still preserved)." "Green"
    }
}

function Attach-Container {
    Show-Banner

    if (-not (Test-ContainerRunning)) {
        Write-Color "❌ Container is not running." "Red"
        return
    }

    Write-Color "📎 Attaching to container '$ContainerName'..." "Yellow"
    Write-Color "   (Use Ctrl+P, Ctrl+Q to detach without stopping)" "Gray"
    Write-Host ""

    docker attach $ContainerName
}

function Open-NewShell {
    Show-Banner

    if (-not (Test-ContainerRunning)) {
        Write-Color "❌ Container is not running." "Red"
        return
    }

    Write-Color "🖥️  Opening new shell in container..." "Yellow"
    Write-Host ""

    docker exec -it -w /workspace $ContainerName bash
}

function Show-Logs {
    Show-Banner
    
    if (-not (Test-ContainerExists)) {
        Write-Color "❌ Container does not exist." "Red"
        return
    }
    
    Write-Color "📜 Container logs (last 50 lines):" "Yellow"
    Write-Host ""
    docker logs $ContainerName --tail 50
}

function Download-Models {
    Show-Banner
    
    if (-not (Test-ContainerRunning)) {
        Write-Color "❌ Container is not running. Start it first." "Red"
        return
    }
    
    Write-Color "📥 Downloading recommended models..." "Yellow"
    Write-Host ""
    
    $choice = Read-Host "Download mode: (M)inimal, (D)efault, (A)ll? [D]"
    
    $args = switch ($choice.ToLower()) {
        "m" { "--minimal" }
        "a" { "--all" }
        default { "" }
    }
    
    docker exec -it $ContainerName /home/aiuser/download-models.sh $args
}


function Manage-Volume {
    Show-Banner
    
    Write-Color "💾 Model Volume Management" "Cyan"
    Write-Host ""
    
    $volSize = Get-VolumeSize
    if (Test-VolumeExists) {
        Write-Color "   Volume: $VolumeName" "White"
        Write-Color "   Size: $volSize" "White"
    } else {
        Write-Color "   Volume not created yet (will be created on first run)" "Yellow"
    }
    
    Write-Host ""
    Write-Color "Options:" "Cyan"
    Write-Host "   [1] Keep volume (models persist)"
    Write-Host "   [2] Delete volume (removes all downloaded models)"
    Write-Host "   [3] Cancel"
    Write-Host ""
    
    $choice = Read-Host "Select"
    
    if ($choice -eq "2") {
        Write-Host ""
        $confirm = Read-Host "Are you sure? This deletes ALL downloaded models (y/N)"
        if ($confirm -eq "y" -or $confirm -eq "Y") {
            docker volume rm $VolumeName 2>$null
            Write-Color "✅ Volume deleted." "Green"
        }
    }
}

function Show-Status {
    Show-Banner
    
    Write-Color "📊 Status:" "Cyan"
    Write-Host ""
    
    # Docker
    if (Test-DockerRunning) {
        Write-Color "   Docker:    ✅ Running" "Green"
    } else {
        Write-Color "   Docker:    ❌ Not running" "Red"
        return
    }
    
    # GPU
    if (Test-NvidiaGPU) {
        $gpu = nvidia-smi --query-gpu=name,memory.total --format=csv,noheader 2>$null
        Write-Color "   GPU:       ✅ $gpu" "Green"
    } else {
        Write-Color "   GPU:       ⚠️  No NVIDIA GPU (CPU mode)" "Yellow"
    }
    
    # Image
    if (Test-ImageExists) {
        Write-Color "   Image:     ✅ Built" "Green"
    } else {
        Write-Color "   Image:     ⚠️  Not built" "Yellow"
    }
    
    # Container
    if (Test-ContainerRunning) {
        Write-Color "   Container: ✅ Running" "Green"
    } elseif (Test-ContainerExists) {
        Write-Color "   Container: ⚠️  Stopped" "Yellow"
    } else {
        Write-Color "   Container: ℹ️  Not created" "Gray"
    }
    
    # Volume
    $volSize = Get-VolumeSize
    if (Test-VolumeExists) {
        Write-Color "   Models:    💾 $volSize (persistent volume)" "Cyan"
    } else {
        Write-Color "   Models:    ℹ️  Volume not created" "Gray"
    }
}

function Show-Menu {
    Show-Banner
    Show-Status
    Write-Host ""
    Write-Color "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━" "Gray"
    Write-Host ""
    Write-Color "   [1] Build Docker Image" "White"
    Write-Color "   [2] Rebuild Image (no cache)" "White"
    Write-Color "   [3] Start Container (with code folder)" "White"
    Write-Color "   [4] Stop Container" "White"
    Write-Color "   [5] Attach to Main Shell" "White"
    Write-Color "   [6] Open New Shell" "White"
    Write-Color "   [7] View Logs" "White"
    Write-Host ""
    Write-Color "   [8] Download Models (inside container)" "Yellow"
    Write-Color "   [9] Manage Model Volume" "Yellow"
    Write-Host ""
    Write-Color "   [R] Refresh Status" "Gray"
    Write-Color "   [Q] Quit" "Gray"
    Write-Host ""
    Write-Color "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━" "Gray"
    Write-Host ""
}

# Main
function Main {
    if (-not (Test-DockerRunning)) {
        Write-Color "❌ Docker is not running. Please start Docker Desktop." "Red"
        exit 1
    }
    
    # Handle CLI arguments
    if ($Action) {
        switch ($Action.ToLower()) {
            "build" { Build-Image; return }
            "rebuild" { Build-Image -NoCache; return }
            "start" { Start-Container -MountPath $CodePath; return }
            "stop" { Stop-Container; return }
            "attach" { Attach-Container; return }
            "logs" { Show-Logs; return }
            "download" { Download-Models; return }
            "status" { Show-Status; return }
            default { Write-Color "Unknown action: $Action" "Red"; return }
        }
    }
    
    # Interactive menu
    while ($true) {
        Show-Menu
        $choice = Read-Host "Select"

        switch ($choice) {
            "1" { Build-Image; Read-Host "Press Enter" }
            "2" { Build-Image -NoCache; Read-Host "Press Enter" }
            "3" { Start-Container }
            "4" { Stop-Container; Read-Host "Press Enter" }
            "5" { Attach-Container }
            "6" { Open-NewShell }
            "7" { Show-Logs; Read-Host "Press Enter" }
            "8" { Download-Models; Read-Host "Press Enter" }
            "9" { Manage-Volume; Read-Host "Press Enter" }
            "r" { continue }
            "R" { continue }
            "q" { Write-Color "Goodbye!" "Cyan"; exit 0 }
            "Q" { Write-Color "Goodbye!" "Cyan"; exit 0 }
            default { Write-Color "Invalid option." "Yellow"; Start-Sleep 1 }
        }
    }
}

Main
