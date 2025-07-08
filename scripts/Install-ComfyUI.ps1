#Requires -RunAsAdministrator

# --- Paramètres du script ---
param(
    # Définit le chemin d'installation.
    # Si le script est lancé sans cet argument, il utilisera son propre dossier par défaut.
    [string]$InstallPath = $PSScriptRoot
)

<#
.SYNOPSIS
    A professional installer for ComfyUI using Git and a Python venv.
.DESCRIPTION
    This script provides a clean, modern installation of ComfyUI by:
    1. Checking for and installing Python 3.12 if needed.
    2. Cloning the official ComfyUI repository.
    3. Creating a dedicated Python virtual environment (venv).
    4. Installing all dependencies into the venv.
    5. Creating a launcher to run the application easily.
.NOTES
    Author: UmeAiRT
    Version: 3.0
#>

#===========================================================================
# SECTION 1: SCRIPT CONFIGURATION & HELPER FUNCTIONS
#===========================================================================

# --- Nettoyage et configuration des chemins ---
$InstallPath = $InstallPath.Trim('"')
[Net.ServicePointManager]::SecurityProtocol = [Net.SecurityProtocolType]::Tls12

# Le chemin de base est maintenant le dossier d'installation principal.
$comfyPath = Join-Path $InstallPath "ComfyUI"
$logPath = Join-Path $InstallPath "logs"
$logFile = Join-Path $logPath "install_log.txt"
$sevenZipPath = "C:\Program Files\7-Zip\7z.exe"

# Variable qui contiendra le chemin vers le python du venv
$venvPython = Join-Path $comfyPath "venv\Scripts\python.exe"

# --- Create Log Directory ---
if (-not (Test-Path $logPath)) {
    New-Item -ItemType Directory -Force -Path $logPath | Out-Null
}

# --- Helper functions ---
function Write-Log {
    param([string]$Message, [string]$Color = "White")
    $timestamp = Get-Date -Format "yyyy-MM-dd HH:mm:ss"
    $formattedMessage = "[$timestamp] $Message"
    Write-Host $Message -ForegroundColor $Color
    Add-Content -Path $logFile -Value $formattedMessage
}

function Invoke-AndLog {
    param(
        [string]$File,
        [string]$Arguments
    )
    
    # Chemin vers un fichier de log temporaire unique
    $tempLogFile = Join-Path $env:TEMP ([System.Guid]::NewGuid().ToString() + ".tmp")

    try {
        # Exécute la commande et redirige TOUTE sa sortie vers le fichier temporaire
        $commandToRun = "`"$File`" $Arguments"
        $cmdArguments = "/C `"$commandToRun > `"`"$tempLogFile`"`" 2>&1`""
        Start-Process -FilePath "cmd.exe" -ArgumentList $cmdArguments -Wait -WindowStyle Hidden
        
        # Une fois la commande terminée, on lit le fichier temporaire
        if (Test-Path $tempLogFile) {
            $output = Get-Content $tempLogFile
            # Et on l'ajoute au log principal en toute sécurité
            Add-Content -Path $logFile -Value $output
        }
    } catch {
        Write-Log "FATAL ERROR trying to execute command: $commandToRun" -Color Red
    } finally {
        # On s'assure que le fichier temporaire est toujours supprimé
        if (Test-Path $tempLogFile) {
            Remove-Item $tempLogFile
        }
    }
}

function Download-File {
    param([string]$Uri, [string]$OutFile)
    if (Test-Path $OutFile) {
        Write-Log "Skipping: $((Split-Path $OutFile -Leaf)) (already exists)." -Color Gray
    } else {
        $fileName = Split-Path -Path $Uri -Leaf
        if (Get-Command 'aria2c' -ErrorAction SilentlyContinue) {
            Write-Log "  - Downloading $fileName"
            $aria_args = "--disable-ipv6 -c -x 16 -s 16 -k 1M --dir=`"$((Split-Path $OutFile -Parent))`" --out=`"$((Split-Path $OutFile -Leaf))`" `"$Uri`""
            Invoke-AndLog "aria2c" $aria_args
        } else {
            Write-Log "Aria2 not found. Falling back to standard download: $fileName" -Color Yellow
            Invoke-WebRequest -Uri $Uri -OutFile $OutFile
        }
    }
}

function Install-Aria2-Binary {
    Write-Log "--- Starting Aria2 binary installation ---" -Color Magenta
    $destFolder = "C:\Tools\aria2"
    if (-not (Test-Path $destFolder)) { New-Item -ItemType Directory -Force -Path $destFolder | Out-Null }
    $aria2Url = "https://github.com/aria2/aria2/releases/download/release-1.36.0/aria2-1.36.0-win-64bit-build1.zip"
    $zipPath  = Join-Path $env:TEMP "aria2_temp.zip"
    Download-File -Uri $aria2Url -OutFile $zipPath
    Write-Log "Extracting zip file to $destFolder..."
    Expand-Archive -Path $zipPath -DestinationPath $destFolder -Force
    $extractedSubfolder = Join-Path $destFolder "aria2-1.36.0-win-64bit-build1"
    if (Test-Path $extractedSubfolder) {
        Move-Item -Path (Join-Path $extractedSubfolder "*") -Destination $destFolder -Force
        Remove-Item -Path $extractedSubfolder -Recurse -Force
    }
    $configFile = Join-Path $destFolder "aria2.conf"
    $configContent = "continue=true`nmax-connection-per-server=16`nsplit=16`nmin-split-size=1M`nfile-allocation=none"
    $configContent | Out-File $configFile -Encoding UTF8
    $envScope = "User"
    $oldPath = [System.Environment]::GetEnvironmentVariable("Path", $envScope)
    if ($oldPath -notlike "*$destFolder*") {
        Write-Log "Adding '$destFolder' to user PATH..."
        $newPath = $oldPath + ";$destFolder"
        [System.Environment]::SetEnvironmentVariable("Path", $newPath, $envScope)
        $env:Path = $newPath
        Write-Log "PATH updated. Aria2 will be available immediately."
    }
    Write-Log "--- Aria2 binary installation complete ---" -Color Magenta
}


#===========================================================================
# SECTION 2: MAIN SCRIPT EXECUTION
#===========================================================================

Clear-Host
# --- Bannière ---
Write-Log "-------------------------------------------------------------------------------"
$asciiBanner = @'
                      __  __               ___    _ ____  ______
                     / / / /___ ___  ___  /   |  (_) __ \/_  __/
                    / / / / __ `__ \/ _ \/ /| | / / /_/ / / / 
                   / /_/ / / / / / /  __/ ___ |/ / _, _/ / /
                   \____/_/ /_/ /_/\___/_/  |_/_/_/ |_| /_/
'@
Write-Host $asciiBanner -ForegroundColor Cyan
Write-Log "-------------------------------------------------------------------------------"
Write-Log "                           ComfyUI - Auto-Installer                            " -Color Yellow
Write-Log "                                  Version 3.0                                  " -Color White
Write-Log "-------------------------------------------------------------------------------"

# --- Étape 1: Vérification et Installation de Python ---
Write-Log "Step 1: Checking for Python 3.12..." -Color Yellow
$pythonExe = Get-Command python -ErrorAction SilentlyContinue
$pythonVersionOK = $false
if ($pythonExe) {
    # Capturer la sortie (va souvent sur le flux d'erreur)
    $versionString = (python --version 2>&1)
    Write-Log "  - Found Python: $versionString"
    if ($versionString -like "Python 3.12*") {
        Write-Log "  - Correct version already installed." -Color Green
        $pythonVersionOK = $true
    }
}

if (-not $pythonVersionOK) {
    Write-Log "  - Python 3.12 not found. Downloading and installing..." -Color Yellow
    $pythonInstallerPath = Join-Path $env:TEMP "python-3.12-installer.exe"
    Download-File -Uri "https://www.python.org/ftp/python/3.12.9/python-3.12.9-amd64.exe" -OutFile $pythonInstallerPath
    Write-Log "  - Running Python installer silently... (This may take a moment)"
    # Installation silencieuse, pour tous les utilisateurs, et ajout au PATH
    Start-Process -FilePath $pythonInstallerPath -ArgumentList "/quiet InstallAllUsers=1 PrependPath=1" -Wait
    Remove-Item $pythonInstallerPath
    Write-Log "  - Python 3.12 installation complete." -Color Green
}

# --- Étape 2: Installation des dépendances (Aria2, 7-Zip, Git) ---
Write-Log "`nStep 2: Checking for required tools..." -Color Yellow
if (-not (Get-Command 'aria2c' -ErrorAction SilentlyContinue)) { Install-Aria2-Binary } else { Write-Log "  - Aria2 is already installed." -Color Green }
if (-not (Test-Path $sevenZipPath)) {
    $sevenZipInstaller = Join-Path $env:TEMP "7z-installer.exe"; Download-File -Uri "https://www.7-zip.org/a/7z2201-x64.exe" -OutFile $sevenZipInstaller; Start-Process -FilePath $sevenZipInstaller -ArgumentList "/S" -Wait; Remove-Item $sevenZipInstaller
} else { Write-Log "  - 7-Zip is already installed." -Color Green }
if (-not (Get-Command git.exe -ErrorAction SilentlyContinue)) {
    $gitInstaller = Join-Path $env:TEMP "Git-Installer.exe"; Download-File -Uri "https://github.com/git-for-windows/git/releases/download/v2.41.0.windows.3/Git-2.41.0.3-64-bit.exe" -OutFile $gitInstaller; Start-Process -FilePath $gitInstaller -ArgumentList "/VERYSILENT" -Wait; Remove-Item $gitInstaller
}
Invoke-AndLog "git" "config --system core.longpaths true"
Write-Log "  - Git is ready." -Color Green


# --- Étape 3: Cloner ComfyUI et créer le Venv ---
Write-Log "`nStep 3: Cloning ComfyUI and creating Virtual Environment..." -Color Yellow
if (-not (Test-Path $comfyPath)) {
    Write-Log "  - Cloning ComfyUI repository..."
    Invoke-AndLog "git" "clone https://github.com/comfyanonymous/ComfyUI.git `"$comfyPath`""
} else {
    Write-Log "  - ComfyUI directory already exists. Skipping clone." -Color Green
}

if (-not (Test-Path (Join-Path $comfyPath "venv"))) {
    Write-Log "  - Creating Python virtual environment (venv)..."
    Push-Location $comfyPath
    Invoke-AndLog "python" "-m venv venv"
    Pop-Location
    Write-Log "  - Venv created successfully." -Color Green
} else {
    Write-Log "  - Venv already exists. Skipping creation." -Color Green
}

# --- Étape 4: Installation des dépendances dans le Venv ---
Write-Log "`nStep 4: Installing all Python dependencies into the venv..." -Color Yellow
Invoke-AndLog "$venvPython" "-m pip install --upgrade pip wheel"
Write-Log "  - Installing torch torchvision torchaudio for CUDA 12.8..."
Invoke-AndLog "$venvPython" "-m pip install torch torchvision torchaudio --index-url https://download.pytorch.org/whl/cu128"
Write-Log "  - Installing ComfyUI requirements..."
Invoke-AndLog "$venvPython" "-m pip install -r `"$comfyPath\requirements.txt`""

# --- Étape 5: Installation des Custom Nodes ---
Write-Log "`nStep 5: Installing custom nodes from CSV list..." -Color Yellow

$csvUrl = "https://github.com/UmeAiRT/ComfyUI-Auto_installer/raw/refs/heads/main/csv/custom_nodes.csv"
$scriptsFolder = Join-Path $InstallPath "scripts"
$csvPath = Join-Path $scriptsFolder "custom_nodes.csv"

# Télécharge la dernière liste de custom nodes
Download-File -Uri $csvUrl -OutFile $csvPath

if (-not (Test-Path $csvPath)) {
    Write-Log "  - ERREUR: Impossible de télécharger la liste des custom nodes. Étape ignorée." -Color Red
} else {
    $customNodes = Import-Csv -Path $csvPath
    $customNodesPath = Join-Path $comfyPath "custom_nodes"

    foreach ($node in $customNodes) {
        $nodeName = $node.Name
        $repoUrl = $node.RepoUrl
        
        # Détermine le chemin d'installation final
        $nodePath = if ($node.Subfolder) { Join-Path $customNodesPath $node.Subfolder } else { Join-Path $customNodesPath $nodeName }
        
        if (-not (Test-Path $nodePath)) {
            Write-Log "  - Installing $nodeName..."
            
            # Gère le cas spécial du subpack
            $cloneTargetPath = if ($node.Subfolder) { (Split-Path $nodePath -Parent) } else { $nodePath }
            if ($nodeName -eq 'ComfyUI-Impact-Subpack') { $clonePath = Join-Path $cloneTargetPath "impact_subpack" } else { $clonePath = $cloneTargetPath }
            
            Invoke-AndLog "git" "clone $repoUrl `"$clonePath`""
            
            # Installe les dépendances si un fichier est spécifié
            if ($node.RequirementsFile) {
                $reqPath = Join-Path $nodePath $node.RequirementsFile
                if (Test-Path $reqPath) { Invoke-AndLog "$venvPython" "-m pip install -r `"$reqPath`"" }
            }
        } else {
            Write-Log "  - $nodeName (already exists, skipping)" -Color Green
        }
    }
}

# --- Étape 6: Installation des modules Python supplémentaires ---
Write-Log "`nStep 6: Installing supplementary modules..." -Color Yellow

# VS Build Tools
Write-Log "  - Installing Visual Studio Build Tools..."
winget install --id Microsoft.VisualStudio.2022.BuildTools -e --source winget --override "--quiet --wait --norestart --add Microsoft.VisualStudio.Component.VC.Tools.x86.x64 --add Microsoft.VisualStudio.Component.Windows10SDK.20348"

# Triton
Write-Log "  - Installing Triton..."
$tritonWheel = Join-Path $InstallPath "triton-3.3.0-py3-none-any.whl"
Download-File -Uri "https://github.com/UmeAiRT/ComfyUI-Auto_installer/raw/refs/heads/main/whl/triton-3.3.0-py3-none-any.whl" -OutFile $tritonWheel
Invoke-AndLog "$venvPython" "-m pip install `"$tritonWheel`""
Invoke-AndLog "$venvPython" "-m pip install triton-windows"
Remove-Item $tritonWheel -ErrorAction SilentlyContinue

# xformers
Write-Log "  - Installing xformers..."
Invoke-AndLog "$venvPython" "-m pip install -U xformers --index-url https://download.pytorch.org/whl/cu128"
Write-Log "    - Applying xformers compatibility patch (renaming files)..."
$xformersBaseDir = Join-Path $comfyPath "venv\Lib\site-packages\xformers"
$dirsToProcess = @(
    $xformersBaseDir,
    (Join-Path $xformersBaseDir "flash_attn_3")
)
foreach ($dir in $dirsToProcess) {
    Write-Log "      - Checking directory: $dir"
    if (Test-Path $dir) {
        $exactFilePath = Join-Path $dir "pyd"
        if (Test-Path $exactFilePath) {
            Write-Log "        - Found file named 'pyd'. Renaming to '_C.pyd'..." -Color Yellow
            $newName = "_C.pyd"
            try {
                Rename-Item -Path $exactFilePath -NewName $newName -Force -ErrorAction Stop
                Write-Log "        - SUCCESS: Renamed 'pyd' to '$newName'" -Color Green
            } catch {
                Write-Log "        - FAILED to rename. Error: $($_.Exception.Message)" -Color Red
            }
        } else {
            $finalFilePath = Join-Path $dir "_C.pyd"
            if (Test-Path $finalFilePath) {
                Write-Log "        - File '_C.pyd' already exists. No action needed." -Color Green
            } else {
                Write-Log "        - No file named 'pyd' or '_C.pyd' found in this directory." -Color Gray
            }
        }
    } else {
        Write-Log "      - Directory not found. Skipping." -Color Gray
    }
}

# SageAttention
Write-Log "  - Installing SageAttention..."
$sageWheel = Join-Path $InstallPath "sageattention-2.1.1+cu128torch2.7.0-cp312-cp312-win_amd64.whl"
Download-File -Uri "https://github.com/UmeAiRT/ComfyUI-Auto_installer/raw/refs/heads/main/whl/sageattention-2.1.1+cu128torch2.7.0-cp312-cp312-win_amd64.whl" -OutFile $sageWheel
Invoke-AndLog "$venvPython" "-m pip install `"$sageWheel`""
Remove-Item $sageWheel -ErrorAction SilentlyContinue

# --- Étape 7: Téléchargement des Workflows et Settings ---
Write-Log "`nStep 7: Downloading Workflows & Settings..." -Color Yellow
$userDefaultPath = Join-Path $comfyPath "user\default"; New-Item -Path $userDefaultPath -ItemType Directory -Force | Out-Null
$workflowPath = Join-Path $userDefaultPath "workflows"; New-Item -Path $workflowPath -ItemType Directory -Force | Out-Null
$workflowCloneDest = Join-Path $workflowPath "UmeAiRT-Workflow"
$settingsFilePath = Join-Path $userDefaultPath "comfy.settings.json"
Download-File -Uri "https://huggingface.co/UmeAiRT/ComfyUI-Auto_installer/resolve/main/others/comfy.settings.json" -OutFile $settingsFilePath
if (-not (Test-Path $workflowCloneDest)) { Invoke-AndLog "git" "clone https://github.com/UmeAiRT/ComfyUI-Workflows `"$workflowCloneDest`"" }

# --- Étape 9: Téléchargement optionnel des packs de modèles ---
Write-Log "`nStep 9: Optional Model Pack Downloads..." -Color Yellow
$modelPacks = @(
    @{Name="FLUX"; ScriptName="Download-FLUX-Models.ps1"},
    @{Name="WAN"; ScriptName="Download-WAN-Models.ps1"},
    @{Name="HIDREAM"; ScriptName="Download-HIDREAM-Models.ps1"},
    @{Name="LTXV"; ScriptName="Download-LTXV-Models.ps1"}
)
$scriptsSubFolder = Join-Path $InstallPath "scripts"
foreach ($pack in $modelPacks) {
    $scriptPath = Join-Path $scriptsSubFolder $pack.ScriptName
    if (-not (Test-Path $scriptPath)) { Write-Log "Model downloader script not found: '$($pack.ScriptName)'. Skipping." -Color Red; continue }
    $validInput = $false
    while (-not $validInput) {
        Write-Host "`n[33mWould you like to download $($pack.Name) models? (Y/N)[0m"
        $choice = Read-Host
        if ($choice -eq 'Y' -or $choice -eq 'y') {
            Write-Log "  - Launching downloader for $($pack.Name) models..." -Color Green
            & $scriptPath -InstallPath $InstallPath
            $validInput = $true
        } elseif ($choice -eq 'N' -or $choice -eq 'n') {
            Write-Log "  - Skipping download for $($pack.Name) models." -Color Gray
            $validInput = $true
        } else { Write-Host "  [31mInvalid choice. Please enter Y or N.[0m" }
    }
}

#===========================================================================
# FINALIZATION
#===========================================================================
Write-Log "-------------------------------------------------------------------------------" -Color Green
Write-Log "Installation of ComfyUI and all nodes is complete!" -Color Green
Read-Host "Press Enter to close this window."
