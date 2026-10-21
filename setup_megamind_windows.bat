@echo off
REM ============================================================
REM  Megamind Studios - one-step Windows setup
REM  Downloads WanGP (pinned, verified commit), applies the
REM  Megamind patch, installs the GTX 10xx build, curates the
REM  model list. Needs ~25 GB free disk for the app; models
REM  download separately on first use.
REM ============================================================
cd /d %~dp0
set WAN2GP_DIR=%~dp0Wan2GP
set PINNED=fdc63bd

where git >nul 2>&1
if errorlevel 1 (
    echo [Megamind] Git not found.
    echo [Megamind] Install Git from https://git-scm.com/download/win then rerun this file.
    pause
    exit /b 1
)
py -3.10 --version >nul 2>&1
if errorlevel 1 (
    python --version 2>nul | findstr /R "^Python 3\.10\." >nul
    if errorlevel 1 (
        echo [Megamind] Python 3.10 not found.
        echo [Megamind] Install Python 3.10.9 from https://www.python.org/downloads/release/python-3109/
        echo [Megamind] During install tick "Add python.exe to PATH", then rerun this file.
        pause
        exit /b 1
    )
    set PYLAUNCH=python
) else (
    set PYLAUNCH=py -3.10
)

if not exist "%WAN2GP_DIR%\.git" (
    echo [Megamind] Downloading WanGP...
    git clone https://github.com/deepbeepmeep/Wan2GP "%WAN2GP_DIR%"
    if errorlevel 1 ( echo [Megamind] Download failed. Check your internet connection and rerun. & pause & exit /b 1 )
)
cd /d "%WAN2GP_DIR%"

echo [Megamind] Checking out the verified WanGP version...
git checkout %PINNED%
if errorlevel 1 ( echo [Megamind] Could not check out %PINNED%. Report this to Megamind support. & pause & exit /b 1 )

echo [Megamind] Applying the Megamind patch...
git apply --check "%~dp0megamind-v1.patch" 2>nul
if errorlevel 1 (
    echo [Megamind] Patch already applied or workspace changed - skipping apply.
) else (
    git apply "%~dp0megamind-v1.patch"
    if errorlevel 1 ( echo [Megamind] Patch failed. Report this to Megamind support. & pause & exit /b 1 )
)

if not exist venv (
    echo [Megamind] Creating virtual environment...
    %PYLAUNCH% -m venv venv
)
call venv\Scripts\activate.bat

echo [Megamind] Installing PyTorch 2.7.1 cu128 ^(GTX 10xx build^)...
pip install torch==2.7.1 torchvision==0.22.1 torchaudio==2.7.1 --index-url https://download.pytorch.org/whl/cu128
if errorlevel 1 ( echo [Megamind] PyTorch install failed. Check your internet connection and rerun. & pause & exit /b 1 )

echo [Megamind] Installing WanGP requirements...
pip install -r requirements.txt
if errorlevel 1 ( echo [Megamind] Requirements install failed. Rerun this file to retry. & pause & exit /b 1 )

echo [Megamind] Pinning torchcodec 0.5.0 ^(official match for torch 2.7^)...
pip install torchcodec==0.5.0
if errorlevel 1 ( echo [Megamind] torchcodec pin failed. Rerun this file to retry. & pause & exit /b 1 )

echo [Megamind] Applying Megamind model selection...
python megamind\curate_models.py

if not exist wgp_config.json copy megamind\wgp_config.template.json wgp_config.json >nul

if not exist "%WAN2GP_DIR%\run_megamind_windows.bat" ( echo [Megamind] Launcher missing - patch did not apply fully. Rerun this file. & pause & exit /b 1 )
powershell -NoProfile -Command "$p='%WAN2GP_DIR%\run_megamind_windows.bat'; (Get-Content $p) -join [char]13+[char]10 | Set-Content $p -NoNewline" >nul 2>&1

echo.
echo [Megamind] Setup complete. Start the studio with: %WAN2GP_DIR%\run_megamind_windows.bat
echo [Megamind] First generation downloads the chosen model - keep several GB free.
pause
