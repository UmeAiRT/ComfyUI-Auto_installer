#!/bin/bash

# Exit immediately if a command exits with a non-zero status.
set -e

# --- Configuration ---
INSTALL_PATH=$(pwd)
COMFY_PATH="$INSTALL_PATH/ComfyUI"
VENV_PATH="$COMFY_PATH/venv"
VENV_PYTHON="$VENV_PATH/bin/python"
DEPS_FILE="$INSTALL_PATH/scripts/dependencies_linux.json"
LOG_DIR="$INSTALL_PATH/logs"
LOG_FILE="$LOG_DIR/install_log.txt"

# --- Colors for logging ---
C_RESET='\033[0m'
C_RED='\033[0;31m'
C_GREEN='\033[0;32m'
C_YELLOW='\033[0;33m'
C_CYAN='\033[0;36m'

# --- Logging functions ---
log_message() {
    local message="$1"
    local level="$2"
    local color="$3"
    local timestamp=$(date +"%Y-%m-%d %H:%M:%S")

    # Default color is reset
    if [ -z "$color" ]; then
        color="$C_RESET"
    fi

    # Log to file
    echo "[$timestamp] $message" >> "$LOG_FILE"

    # Log to console
    case "$level" in
        0)
            echo -e "${color}===================================================================${C_RESET}"
            echo -e "${color}| $message |${C_RESET}"
            echo -e "${color}===================================================================${C_RESET}"
            ;;
        1)
            echo -e "${color}- $message${C_RESET}"
            ;;
        2)
            echo -e "${color}  -> $message${C_RESET}"
            ;;
        3)
            echo -e "${color}    [INFO] $message${C_RESET}"
            ;;
        *)
            echo -e "${color}$message${C_RESET}"
            ;;
    esac
}

# Function to check for required commands
check_dependencies() {
    log_message "Checking for required system dependencies..." 1 "$C_CYAN"
    local missing_deps=()
    local required_commands=("git" "python3" "aria2c" "jq" "g++")

    for cmd in "${required_commands[@]}"; do
        if ! command -v "$cmd" &> /dev/null; then
            missing_deps+=("$cmd")
        fi
    done

    if [ ${#missing_deps[@]} -ne 0 ]; then
        log_message "The following required dependencies are not installed: ${missing_deps[*]}" 0 "$C_RED"
        log_message "Please install them using your system's package manager." 2 "$C_YELLOW"
        log_message "For Debian/Ubuntu: sudo apt-get update && sudo apt-get install ${missing_deps[*]}" 3
        log_message "For Arch Linux: sudo pacman -Syu ${missing_deps[*]}" 3
        log_message "For Fedora: sudo dnf install ${missing_deps[*]}" 3
        exit 1
    else
        log_message "All system dependencies are met." 1 "$C_GREEN"
    fi
}

# --- Main Script ---

# Create log directory
mkdir -p "$LOG_DIR"

# Clear log file
> "$LOG_FILE"

# --- Banner ---
cat << "EOF"
                      __  __               ___    _ ____  ______
                     / / / /___ ___  ___  /   |  (_) __ \/_  __/
                    / / / / __ `__ \/ _ \/ /| | / / /_/ / / /
                   / /_/ / / / / / /  __/ ___ |/ / _, _/ / /
                   \____/_/ /_/ /_/\___/_/  |_/_/_/ |_| /_/
                           ComfyUI - Auto-Installer (Linux)
-------------------------------------------------------------------------------
EOF

# --- Start Installation ---
check_dependencies

# --- Step 1: Clone ComfyUI & Create Venv ---
log_message "Cloning ComfyUI & Creating Virtual Environment" 0 "$C_YELLOW"
if [ ! -d "$COMFY_PATH" ]; then
    COMFY_URL=$(jq -r '.repositories.comfyui.url' "$DEPS_FILE")
    log_message "Cloning ComfyUI from $COMFY_URL..." 1
    git clone "$COMFY_URL" "$COMFY_PATH" >> "$LOG_FILE" 2>&1
    log_message "ComfyUI cloned successfully." 2 "$C_GREEN"
else
    log_message "ComfyUI directory already exists. Skipping clone." 1 "$C_GREEN"
fi

if [ ! -d "$VENV_PATH" ]; then
    log_message "Creating Python virtual environment..." 1
    python3 -m venv "$VENV_PATH" >> "$LOG_FILE" 2>&1
    log_message "Virtual environment created successfully." 2 "$C_GREEN"
else
    log_message "Virtual environment already exists. Skipping creation." 1 "$C_GREEN"
fi

# --- Step 2: Install Core Dependencies ---
log_message "Installing Core Dependencies" 0 "$C_YELLOW"
log_message "Activating virtual environment..." 3
source "$VENV_PATH/bin/activate"

log_message "Upgrading pip and wheel..." 1
PIP_UPGRADE_PACKAGES=$(jq -r '.pip_packages.upgrade | join(" ")' "$DEPS_FILE")
"$VENV_PYTHON" -m pip install --upgrade $PIP_UPGRADE_PACKAGES >> "$LOG_FILE" 2>&1

log_message "Installing torch packages..." 1
TORCH_PACKAGES=$(jq -r '.pip_packages.torch.packages' "$DEPS_FILE")
TORCH_INDEX_URL=$(jq -r '.pip_packages.torch.index_url' "$DEPS_FILE")
"$VENV_PYTHON" -m pip install --pre $TORCH_PACKAGES --index-url "$TORCH_INDEX_URL" >> "$LOG_FILE" 2>&1

log_message "Installing ComfyUI requirements..." 1
COMFY_REQS_FILE=$(jq -r '.pip_packages.comfyui_requirements' "$DEPS_FILE")
"$VENV_PYTHON" -m pip install -r "$COMFY_PATH/$COMFY_REQS_FILE" >> "$LOG_FILE" 2>&1

# --- Step 3: Install Custom Nodes ---
log_message "Installing Custom Nodes" 0 "$C_YELLOW"
CUSTOM_NODES_CSV_URL=$(jq -r '.files.custom_nodes_csv.url' "$DEPS_FILE")
CUSTOM_NODES_CSV_DEST="$INSTALL_PATH/$(jq -r '.files.custom_nodes_csv.destination' "$DEPS_FILE")"
CUSTOM_NODES_PATH="$COMFY_PATH/custom_nodes"

mkdir -p "$(dirname "$CUSTOM_NODES_CSV_DEST")"
# Using curl to download the CSV
curl -L "$CUSTOM_NODES_CSV_URL" -o "$CUSTOM_NODES_CSV_DEST"

# Read CSV and clone repos
tail -n +2 "$CUSTOM_NODES_CSV_DEST" | while IFS=, read -r name repo_url subfolder reqs_file; do
    # Trim whitespace and carriage returns
    repo_url=$(echo "$repo_url" | tr -d '[:space:]')
    name=$(echo "$name" | tr -d '[:space:]')
    subfolder=$(echo "$subfolder" | tr -d '[:space:]')
    reqs_file=$(echo "$reqs_file" | tr -d '[:space:]')

    NODE_PATH="$CUSTOM_NODES_PATH/$name"
    if [ -n "$subfolder" ]; then
        NODE_PATH="$CUSTOM_NODES_PATH/$subfolder"
    fi

    if [ ! -d "$NODE_PATH" ]; then
        log_message "Installing custom node: $name" 1
        git clone "$repo_url" "$NODE_PATH" >> "$LOG_FILE" 2>&1
        if [ -n "$reqs_file" ] && [ -f "$NODE_PATH/$reqs_file" ]; then
            log_message "Installing requirements for $name" 2
            "$VENV_PYTHON" -m pip install -r "$NODE_PATH/$reqs_file" >> "$LOG_FILE" 2>&1
        fi
    else
        log_message "Custom node $name already exists. Skipping." 1 "$C_GREEN"
    fi
done

# --- Step 4: Install Final Python Dependencies ---
log_message "Installing Final Python Dependencies" 0 "$C_YELLOW"

log_message "Installing standard packages..." 1
STANDARD_PACKAGES=$(jq -r '.pip_packages.standard | join(" ")' "$DEPS_FILE")
"$VENV_PYTHON" -m pip install $STANDARD_PACKAGES >> "$LOG_FILE" 2>&1

log_message "Installing pinned packages..." 1
PINNED_PACKAGES=$(jq -r '.pip_packages.pinned | join(" ")' "$DEPS_FILE")
"$VENV_PYTHON" -m pip install $PINNED_PACKAGES >> "$LOG_FILE" 2>&1

log_message "Installing packages from git repositories..." 1
jq -c '.pip_packages.git_repos[]' "$DEPS_FILE" | while read -r repo; do
    name=$(jq -r '.name' <<< "$repo")
    url=$(jq -r '.url' <<< "$repo")
    commit=$(jq -r '.commit' <<< "$repo")
    install_options=$(jq -r '.install_options' <<< "$repo")

    log_message "Installing $name..." 2

    export CXX="g++"

    if [ "$name" == "xformers" ]; then
        export FORCE_CUDA="1"
        "$VENV_PYTHON" -m pip install --no-build-isolation --verbose "git+$url@$commit" >> "$LOG_FILE" 2>&1
        unset FORCE_CUDA
    elif [ "$name" == "apex" ]; then
         "$VENV_PYTHON" -m pip install $install_options "git+$url@$commit" >> "$LOG_FILE" 2>&1
    else
        "$VENV_PYTHON" -m pip install "git+$url@$commit" >> "$LOG_FILE" 2>&1
    fi
done

# --- Step 5: Download Workflows & Settings ---
log_message "Downloading Workflows & Settings" 0 "$C_YELLOW"
SETTINGS_URL=$(jq -r '.files.comfy_settings.url' "$DEPS_FILE")
SETTINGS_DEST="$COMFY_PATH/$(jq -r '.files.comfy_settings.destination' "$DEPS_FILE")"
mkdir -p "$(dirname "$SETTINGS_DEST")"
log_message "Downloading settings file..." 1
curl -L "$SETTINGS_URL" -o "$SETTINGS_DEST" >> "$LOG_FILE" 2>&1

WORKFLOW_URL=$(jq -r '.repositories.workflows.url' "$DEPS_FILE")
WORKFLOW_DEST="$COMFY_PATH/user/default/workflows/UmeAiRT-Workflow"
if [ ! -d "$WORKFLOW_DEST" ]; then
    log_message "Cloning workflows..." 1
    git clone "$WORKFLOW_URL" "$WORKFLOW_DEST" >> "$LOG_FILE" 2>&1
else
    log_message "Workflows directory already exists. Skipping." 1 "$C_GREEN"
fi

# --- Step 6: Finalize Permissions ---
log_message "Finalizing Permissions" 0 "$C_YELLOW"
log_message "Applying executable permissions to .sh files..." 1
find . -name "*.sh" -exec chmod +x {} \;

# --- Step 7: Optional Model Pack Downloads ---
log_message "Optional Model Pack Downloads" 0 "$C_YELLOW"
log_message "To download the models, run './download_models.sh' after this installation is complete." 1 "$C_CYAN"

# --- Finalization ---
log_message "Installation Complete!" 0 "$C_GREEN"
log_message "You can now run './start.sh' to launch ComfyUI." 1

# Deactivate venv if it was activated
if declare -f deactivate > /dev/null; then
  deactivate
fi
