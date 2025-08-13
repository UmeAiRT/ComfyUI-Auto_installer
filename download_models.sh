#!/bin/bash
set -e

# --- Configuration ---
INSTALL_PATH=$(pwd)
# Correctly set MODELS_PATH to be inside the ComfyUI directory
MODELS_PATH="$INSTALL_PATH/ComfyUI/models"
LOG_DIR="$INSTALL_PATH/logs"
LOG_FILE="$LOG_DIR/install_log.txt"

# --- Colors for logging ---
C_RESET='\033[0m'
C_RED='\033[0;31m'
C_GREEN='\033[0;32m'
C_YELLOW='\033[0;33m'
C_CYAN='\033[0;36m'
C_GRAY='\033[0;90m'

# --- Logging function ---
log_message() {
    local message="$1"
    local color="$2"
    echo -e "${color}${message}${C_RESET}"
    echo "[$(date +"%Y-%m-%d %H:%M:%S")] [ModelDownloader] $message" >> "$LOG_FILE"
}

# --- Download function ---
download_file() {
    local uri="$1"
    local outfile="$2"
    local filename=$(basename "$outfile")

    if [ -f "$outfile" ]; {
        log_message "Skipping: $filename (already exists)." "$C_GRAY"
        return
    }

    log_message "Downloading: $filename" "$C_CYAN"
    # Ensure the directory exists
    mkdir -p "$(dirname "$outfile")"

    if command -v aria2c &> /dev/null; then
        aria2c --disable-ipv6 -c -x 16 -s 16 -k 1M --dir="$(dirname "$outfile")" --out="$filename" "$uri" >> "$LOG_FILE" 2>&1
    else
        log_message "aria2c not found, using curl..." "$C_YELLOW"
        curl -L -o "$outfile" "$uri" >> "$LOG_FILE" 2>&1
    fi
}

# --- Question function ---
ask_question() {
    local prompt="$1"
    shift
    local choices=("$@")

    echo -e "${C_YELLOW}${prompt}${C_RESET}"
    for choice in "${choices[@]}"; do
        echo -e "  ${C_GREEN}${choice}${C_RESET}"
    done

    local answer
    read -p "Enter your choice (e.g., A) and press Enter: " answer
    echo "$answer" | tr '[:lower:]' '[:upper:]'
}

# --- Main Script ---
mkdir -p "$MODELS_PATH"
mkdir -p "$LOG_DIR"

log_message "===============================================" "$C_GREEN"
log_message "          Model Downloader Script" "$C_GREEN"
log_message "===============================================" "$C_GREEN"

# --- GPU Detection ---
log_message "-------------------------------------------------------------------------------" "$C_CYAN"
log_message "Checking for NVIDIA GPU to provide model recommendations..." "$C_YELLOW"
if command -v nvidia-smi &> /dev/null; then
    gpu_mem_gib=$(nvidia-smi --query-gpu=memory.total --format=csv,noheader,nounits | head -n 1 | awk '{printf "%.0f\n", $1/1024}')
    log_message "Detected VRAM: ${gpu_mem_gib} GB" "$C_GREEN"
    if [ "$gpu_mem_gib" -ge 30 ]; then log_message "Recommendation: fp16" "$C_CYAN";
    elif [ "$gpu_mem_gib" -ge 18 ]; then log_message "Recommendation: fp8 or GGUF Q8" "$C_CYAN";
    elif [ "$gpu_mem_gib" -ge 16 ]; then log_message "Recommendation: GGUF Q6" "$C_CYAN";
    elif [ "$gpu_mem_gib" -ge 14 ]; then log_message "Recommendation: GGUF Q5" "$C_CYAN";
    elif [ "$gpu_mem_gib" -ge 12 ]; then log_message "Recommendation: GGUF Q4" "$C_CYAN";
    elif [ "$gpu_mem_gib" -ge 8 ]; then log_message "Recommendation: GGUF Q3" "$C_CYAN";
    else log_message "Recommendation: GGUF Q2" "$C_CYAN"; fi
else
    log_message "nvidia-smi not found. Cannot provide VRAM-based recommendations." "$C_GRAY"
fi
log_message "-------------------------------------------------------------------------------" "$C_CYAN"

# --- FLUX Models ---
flux_choice=$(ask_question "Download FLUX base models?" "A) fp16" "B) fp8" "C) All" "D) No")

BASE_URL="https://huggingface.co/UmeAiRT/ComfyUI-Auto_installer/resolve/main/models"
FLUX_DIR="$MODELS_PATH/diffusion_models/FLUX"
CLIP_DIR="$MODELS_PATH/clip"
VAE_DIR="$MODELS_PATH/vae"

# Common files needed for FLUX
if [[ "$flux_choice" != "D" ]]; then
    log_message "Downloading common support models for FLUX..." "$C_YELLOW"
    download_file "$BASE_URL/vae/ae.safetensors" "$VAE_DIR/ae.safetensors"
    download_file "$BASE_URL/clip/clip_l.safetensors" "$CLIP_DIR/clip_l.safetensors"
fi

# fp16 models
if [[ "$flux_choice" == "A" || "$flux_choice" == "C" ]]; then
    log_message "Downloading FLUX fp16 models..." "$C_YELLOW"
    download_file "$BASE_URL/diffusion_models/FLUX/flux1-dev-fp16.safetensors" "$FLUX_DIR/flux1-dev-fp16.safetensors"
    download_file "$BASE_URL/clip/t5xxl_fp16.safetensors" "$CLIP_DIR/t5xxl_fp16.safetensors"
fi

# fp8 models
if [[ "$flux_choice" == "B" || "$flux_choice" == "C" ]]; then
    log_message "Downloading FLUX fp8 models..." "$C_YELLOW"
    download_file "$BASE_URL/diffusion_models/FLUX/flux1-dev-fp8.safetensors" "$FLUX_DIR/flux1-dev-fp8..safetensors"
    download_file "$BASE_URL/clip/t5xxl_fp8_e4m3fn.safetensors" "$CLIP_DIR/t5xxl_fp8_e4m3fn.safetensors"
fi

log_message "-----------------------------------------------" "$C_GREEN"
log_message "This is a simplified script." "$C_YELLOW"
log_message "To download more models, edit this script or add more 'ask_question' and 'download_file' calls." "$C_YELLOW"
log_message "Model download script finished." "$C_GREEN"
