#Requires -RunAsAdministrator

<#
.SYNOPSIS
    A dedicated update script for the ComfyUI installation.
.DESCRIPTION
    This script performs a 'git pull' on the main ComfyUI repository,
    all custom nodes, and the workflow repository. It then updates all
    Python dependencies from any found 'requirements.txt' files.
    It is designed to be run from a subfolder.
#>

#===========================================================================
# SECTION 1: SCRIPT CONFIGURATION & HELPER FUNCTIONS
#===========================================================================

# === CORRECTION : Le script s'exécute depuis un sous-dossier, on cible donc le dossier parent ===
$InstallPath = (Split-Path -Path $PSScriptRoot -Parent)

$comfyPath = Join-Path $InstallPath "ComfyUI"
$customNodesPath = Join-Path $comfyPath "custom_nodes"
$workflowPath = Join-Path $comfyPath "user\default\workflows\UmeAiRT-Workflow"
$venvPython = Join-Path $comfyPath "venv\Scripts\python.exe"
$logPath = Join-Path $InstallPath "logs"
$logFile = Join-Path $logPath "update_log.txt"

if (-not (Test-Path $logPath)) { New-Item -ItemType Directory -Force -Path $logPath | Out-Null }

function Write-Log {
    param([string]$Message, [string]$Color = "White")
    $timestamp = Get-Date -Format "yyyy-MM-dd HH:mm:ss"
    $formattedMessage = "[$timestamp] $Message"
    Write-Host $Message -ForegroundColor $Color
    Add-Content -Path $logFile -Value $formattedMessage
}

function Invoke-Git-Pull {
    param([string]$DirectoryPath)
    if (Test-Path (Join-Path $DirectoryPath ".git")) {
        # On utilise cmd.exe pour lancer git pull et rediriger la sortie vers le log
        $commandToRun = "git -C `"$DirectoryPath`" pull"
        $cmdArguments = "/C `"$commandToRun >> `"`"$logFile`"`" 2>&1`""
        try {
            Start-Process -FilePath "cmd.exe" -ArgumentList $cmdArguments -Wait -WindowStyle Hidden
        } catch {
            Write-Log "  - FAILED to run git pull in '$DirectoryPath'" -Color Red
        }
    } else {
        Write-Log "  - Skipping: Not a git repository." -Color Gray
    }
}

function Invoke-Pip-Install {
    param([string]$RequirementsPath)
    if (Test-Path $RequirementsPath) {
        Write-Log "  - Found requirements: $RequirementsPath. Updating..." -Color Cyan
        $tempLogFile = Join-Path $env:TEMP ([System.Guid]::NewGuid().ToString() + ".tmp")
        try {
            $commandToRun = "`"$venvPython`" -m pip install -r `"$RequirementsPath`""
            $cmdArguments = "/C `"$commandToRun > `"`"$tempLogFile`"`" 2>&1`""
            Start-Process -FilePath "cmd.exe" -ArgumentList $cmdArguments -Wait -WindowStyle Hidden
            if (Test-Path $tempLogFile) { $output = Get-Content $tempLogFile; if($output){ Add-Content -Path $logFile -Value $output } }
        } finally {
            if (Test-Path $tempLogFile) { Remove-Item $tempLogFile }
        }
    }
}

#===========================================================================
# SECTION 2: UPDATE PROCESS
#===========================================================================
Clear-Host
Write-Log "==============================================================================="
Write-Log "             Starting UmeAiRT ComfyUI Update Process" -Color Yellow
Write-Log "==============================================================================="

# --- 1. Update ComfyUI Core ---
Write-Log "`n[1/4] Updating ComfyUI Core..." -Color Green
Invoke-Git-Pull -DirectoryPath $comfyPath

# --- 2. Update and Install Custom Nodes ---
Write-Log "`n[2/4] Updating and Installing Custom Nodes..." -Color Green

$csvUrl = "https://huggingface.co/UmeAiRT/ComfyUI-Auto_installer/resolve/main/scripts/Nodes_installer/custom_nodes.csv"
$scriptsFolder = Join-Path $InstallPath "scripts"
$csvPath = Join-Path $scriptsFolder "custom_nodes.csv"

# Télécharge la dernière liste de custom nodes
try {
    Invoke-WebRequest -Uri $csvUrl -OutFile $csvPath
} catch {
    Write-Log "  - ERREUR: Impossible de télécharger la liste des custom nodes. Mise à jour des nodes ignorée." -Color Red
    return
}

$customNodesList = Import-Csv -Path $csvPath
$existingNodeDirs = Get-ChildItem -Path $customNodesPath -Directory

# D'abord, on met à jour les nodes existants
Write-Log "  - Updating existing nodes..."
foreach ($dir in $existingNodeDirs) {
    Write-Log "    - Checking node: $($dir.Name)"
    Invoke-Git-Pull -DirectoryPath $dir.FullName
}

# Ensuite, on vérifie s'il y a de nouveaux nodes à installer
Write-Log "  - Checking for new nodes to install..."
foreach ($node in $customNodesList) {
    $nodeName = $node.Name
    $nodePath = if ($node.Subfolder) { Join-Path $customNodesPath $node.Subfolder } else { Join-Path $customNodesPath $nodeName }

    if (-not (Test-Path $nodePath)) {
        Write-Log "    - New node found: $nodeName. Installing..." -Color Yellow
        
        $repoUrl = $node.RepoUrl
        $cloneTargetPath = if ($node.Subfolder) { (Split-Path $nodePath -Parent) } else { $nodePath }
        if ($nodeName -eq 'ComfyUI-Impact-Subpack') { $clonePath = Join-Path $cloneTargetPath "impact_subpack" } else { $clonePath = $cloneTargetPath }
        
        $tempLogFile = Join-Path $env:TEMP ([System.Guid]::NewGuid().ToString() + ".tmp")
        try {
            $commandToRun = "git clone $repoUrl `"$clonePath`""
            $cmdArguments = "/C `"$commandToRun > `"`"$tempLogFile`"`" 2>&1`""
            Start-Process -FilePath "cmd.exe" -ArgumentList $cmdArguments -Wait -WindowStyle Hidden
            if (Test-Path $tempLogFile) { Add-Content -Path $logFile -Value (Get-Content $tempLogFile) }
        } finally {
            if (Test-Path $tempLogFile) { Remove-Item $tempLogFile }
        }
    }
}


# --- 3. Update Workflows ---
Write-Log "`n[3/4] Updating UmeAiRT Workflows..." -Color Green
if (Test-Path $workflowPath) {
    Invoke-Git-Pull -DirectoryPath $workflowPath
} else {
    Write-Log "  - Workflow directory not found, skipping." -Color Gray
}

# --- 4. Update Python Dependencies ---
Write-Log "`n[4/4] Updating all Python dependencies..." -Color Green
Write-Log "  - Checking main ComfyUI requirements..."
Invoke-Pip-Install -RequirementsPath (Join-Path $comfyPath "requirements.txt")

Write-Log "  - Checking custom node requirements..."
if (Test-Path $customNodesPath) {
    foreach ($dir in (Get-ChildItem -Path $customNodesPath -Directory)) {
        Invoke-Pip-Install -RequirementsPath (Join-Path $dir.FullName "requirements.txt")
    }
}

Write-Log "==============================================================================="
Write-Log "Update process complete!" -Color Yellow
Write-Log "==============================================================================="
Read-Host "Press Enter to exit."
