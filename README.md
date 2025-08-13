# UmeAiRT's ComfyUI Auto-Installer

![PowerShell / Bash](https://img.shields.io/badge/Shell-PowerShell%20%7C%20Bash-blue.svg)
![Platform](https://img.shields.io/badge/Platform-Windows%20%7C%20Linux-lightgrey.svg)
![License](https://img.shields.io/badge/License-MIT-green.svg)

This project provides a suite of scripts to fully automate the installation and configuration of ComfyUI on Windows and Linux. The approach uses a clean installation based on `git` and a Python virtual environment (`venv`), ensuring an isolated, easy-to-update, and maintainable setup.

## Features

- **Clean Installation:** Clones the latest version of ComfyUI from the official repository and installs it in a dedicated Python virtual environment (`venv`).
- **Dependency Management:** Automatically checks for and installs necessary tools:
    - Python 3.12 (if not present on the system)
    - Git
    - 7-Zip
    - Aria2 (for accelerated downloads)
- **CSV-Managed Custom Nodes:** Installs a comprehensive list of custom nodes defined in an external `custom_nodes.csv` file, making it simple to add new nodes.
- **Interactive Model Downloaders:** Dedicated scripts guide you with menus to download the model packs you want (FLUX, WAN, HIDREAM, LTXV), with recommendations based on your graphics card's VRAM.
- **Dedicated Update Script:** A specific `UmeAiRT-Updater.ps1` script allows you to update ComfyUI, all custom nodes, and workflows with a single command.
- **Automated Launchers:** The project generates `.bat` files to run the installation, updates, and the final application, automatically handling administrator rights and PowerShell execution policies.
- **Supplementary modules:** The script also installs some complex modules such as: Sageattention, Triton, Visual Studio Build Tools, ...
- **Workflow included:** A large amount of workflows are pre-installed for each model.

## Prerequisites

**For Windows:**
- Windows 10 or Windows 11 (64-bit).
- An active internet connection.
- An NVIDIA GPU is strongly recommended to use the models.

**For Linux:**
- A modern Linux distribution (e.g., Ubuntu 22.04, Arch Linux).
- An active internet connection.
- An NVIDIA GPU is strongly recommended to use the models.
- The `install.sh` script will check for the following required packages: `git`, `python3`, `aria2c`, `jq`, `g++`. You must install them using your system's package manager if they are not present.
  - For Debian/Ubuntu: `sudo apt-get update && sudo apt-get install git python3 python3-venv aria2 jq g++`
  - For Arch Linux: `sudo pacman -Syu git python python-venv aria2 jq gcc`

## Installation for Linux

1.  **Download the Project:**
    ```bash
    git clone https://github.com/UmeAiRT/ComfyUI-Auto_installer.git
    cd ComfyUI-Auto_installer
    ```

2.  **Run the Installer:**
    - Make the script executable:
      ```bash
      chmod +x install.sh
      ```
    - Run the installer:
      ```bash
      ./install.sh
      ```
    - The script will guide you through the process, cloning ComfyUI, setting up a virtual environment, and installing all dependencies.

3.  **Download Models (Optional):**
    - After the main installation, you can run the model downloader script:
      ```bash
      ./download_models.sh
      ```

## Post-Installation Usage (Linux)

- **To start ComfyUI:** `./start.sh`
- **To update ComfyUI and custom nodes:** `./update.sh`
- **To download more models:** `./download_models.sh`

---

## Installation for Windows

The entire process is designed to be as simple as possible.

1.  **Download the Project:** Download this repository as a ZIP file from GitHub and extract it to a folder of your choice (e.g., `C:\UmeAiRT-Installer`).

2.  **Run the Installer:**
    - In the folder, find and run the file `UmeAiRT-Install-ComfyUI.bat`.
    - It will ask for administrator privileges. Please accept.
    - The script will first download the latest versions of all installation scripts from the repository to ensure you are using the most recent version.

3.  **Follow the Instructions:**
    - The main installation script will then launch. It will install Python (if necessary), Git, 7-Zip, Aria2, and then ComfyUI.
    - Next, it will install all custom nodes and their Python dependencies into the virtual environment.
    - Finally, it will ask you a series of questions about which model packs you wish to download. Simply answer `Y` (yes) or `N` (no) to each question.

At the end of the process, your ComfyUI installation will be complete and ready to use.

## Post-Installation Usage (Windows)

Three main `.bat` files will be available in your folder to manage the application:

- **`UmeAiRT-Start-ComfyUI.bat`**
    - This is the file you will use to **launch ComfyUI**. It activates the virtual environment and starts the server.

- **`UmeAiRT-Download_models.bat`**
    - Run this script if you want to **add more model packs** later without reinstalling everything. It will present you with the same selection menu as the initial installation.

- **`UmeAiRT-Update-ComfyUI.bat`**
    - Execute this script to **update your entire installation**. It will update the code for ComfyUI, all custom nodes, and your workflows, and it will install any new Python dependencies if required.

## File Structure

- **`/` (your root folder)**
    - `UmeAiRT-Installer-Updater.bat` (Main launcher that updates and installs)
    - `UmeAiRT-Start-ComfyUI.bat` (Created after installation to launch ComfyUI)
    - `UmeAiRT-Update-ComfyUI.bat` (Launcher for the update script)
    - `UmeAiRT-Download_models.bat` (Menu to download more models later)
    - **`scripts/`** (Contains all PowerShell scripts)
        - `Install-ComfyUI.ps1`
        - `UmeAiRT-Updater.ps1`
        - `Download-FLUX-Models.ps1` (and other model downloaders)
        - `custom_nodes.csv` (The list of all custom nodes to install)
    - **`ComfyUI/`** (Created after installation, contains the application)
    - **`logs/`** (Created, contains installation/update logs)

## Contributing

Suggestions and contributions are welcome. If you find a bug or have an idea for an improvement to the scripts, feel free to open an "Issue" on this GitHub repository.

## License

This project is under the MIT License. See the `LICENSE` file for more details.

## Acknowledgements

- To **Comfyanonymous** for creating the incredible ComfyUI.
- To the authors of all the **custom nodes** that enrich the ecosystem.
