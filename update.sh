#!/bin/bash
set -e

# --- Configuration ---
INSTALL_PATH=$(pwd)
COMFY_PATH="$INSTALL_PATH/ComfyUI"
VENV_PYTHON="$COMFY_PATH/venv/bin/python"
CUSTOM_NODES_PATH="$COMFY_PATH/custom_nodes"

echo "--- Starting Update Process ---"

# --- Update ComfyUI ---
echo "[1/3] Updating ComfyUI repository..."
cd "$COMFY_PATH"
git pull
echo "ComfyUI updated."

# --- Update Custom Nodes ---
echo "[2/3] Updating custom nodes..."
# Loop through each directory in custom_nodes
for dir in "$CUSTOM_NODES_PATH"/*/; do
    # Check if it's a git repository
    if [ -d "$dir/.git" ]; then
        echo "  - Updating $(basename "$dir")"
        cd "$dir"
        git pull
    fi
done
echo "Custom nodes updated."

# --- Re-install requirements ---
echo "[3/3] Checking for new Python dependencies..."
cd "$COMFY_PATH"
"$VENV_PYTHON" -m pip install -r requirements.txt
echo "Dependencies checked."

echo "--- Update Complete! ---"
cd "$INSTALL_PATH"
