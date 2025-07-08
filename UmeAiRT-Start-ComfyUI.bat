@echo off
echo Activating ComfyUI virtual environment...

REM Activates the virtual environment.
call "%~dp0ComfyUI\venv\Scripts\activate.bat"

echo Starting ComfyUI with custom arguments...

REM Places itself in the ComfyUI folder.
cd "%~dp0ComfyUI"

REM We prepare the base path, making sure there is no trailing backslash to avoid problems interpreting quotes.
set "BASE_DIR=%~dp0ComfyUI"
if "%BASE_DIR:~-1%"=="\" set "BASE_DIR=%BASE_DIR:~0,-1%"
set "TMP_DIR=%BASE_DIR%\ComfyUI\temp"

REM We run the script using the cleaned path variable.
python main.py --use-sage-attention --disable-smart-memory --base-directory "%BASE_DIR%" --auto-launch --temp-directory "%TMP_DIR%"

pause
