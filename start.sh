#!/bin/bash

# --- Configuration ---
INSTALL_PATH=$(pwd)
COMFY_PATH="$INSTALL_PATH/ComfyUI"
VENV_PATH="$COMFY_PATH/venv"

# --- Activate venv and run ---
echo "Activating virtual environment..."
source "$VENV_PATH/bin/activate"

echo "Changing to ComfyUI directory..."
cd "$COMFY_PATH"

echo "Launching ComfyUI..."
python main.py
