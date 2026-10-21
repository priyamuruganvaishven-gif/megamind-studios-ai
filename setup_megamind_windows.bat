@echo off
REM ============================================================
REM  Megamind Studios - one-step Windows setup
REM  Downloads WanGP (pinned, verified commit), applies the
REM  Megamind add-on files and branding plugin, installs
REM  model list. Needs ~25 GB free disk for the app; models
REM  download separately on first use.
REM  Line-ending safe: single-line conditionals only, no labels.
REM  torchcodec deviation: WanGP at this commit never imports
REM  torchcodec (media IO uses imageio/ffmpeg/av/opencv/decord/
REM  soundfile); its pinned torchcodec 0.10.0 targets torch 2.9+
REM  and no Windows wheel exists for the torch 2.7 GTX 10xx
REM  build, so it is excluded from this profile's install.
REM ============================================================
cd /d %~dp0
set WAN2GP_DIR=%~dp0Wan2GP
set PINNED=fdc63bd

where git >nul 2>&1
if errorlevel 1 ( echo [Megamind] Git not found. Install Git from https://git-scm.com/download/win then rerun this file. & pause & exit /b 1 )

set PYLAUNCH=py -3.10
py -3.10 --version >nul 2>&1
if errorlevel 1 set PYLAUNCH=python
%PYLAUNCH% --version 2>nul | findstr /R "^Python 3\.10\." >nul
if errorlevel 1 ( echo [Megamind] Python 3.10 not found. Install Python 3.10.9 from https://www.python.org/downloads/release/python-3109/ with "Add python.exe to PATH" ticked, then rerun this file. & pause & exit /b 1 )

if not exist "%WAN2GP_DIR%\.git" git clone https://github.com/deepbeepmeep/Wan2GP "%WAN2GP_DIR%"
if errorlevel 1 ( echo [Megamind] Download failed. Check your internet connection and rerun. & pause & exit /b 1 )
cd /d "%WAN2GP_DIR%"

echo [Megamind] Checking out the verified WanGP version...
git checkout %PINNED% >nul 2>&1
if errorlevel 1 ( echo [Megamind] Could not check out %PINNED%. Report this to Megamind support. & pause & exit /b 1 )

echo [Megamind] Applying the Megamind add-on files...
set MM_SKIP=0
if exist megamind\ensure_config.py if exist plugins\megamind\plugin.py findstr /C:"Megamind Studios" wgp.py >nul 2>&1 || set MM_SKIP=1
if %MM_SKIP%==1 echo [Megamind] Latest Megamind setup already applied - skipping.
if %MM_SKIP%==0 ( del /q shared\gradio\ui_studio_megamind.css 2>nul & rmdir /s /q megamind 2>nul & rmdir /s /q plugins\megamind 2>nul & del /q run_megamind_windows.bat 2>nul & git reset --hard %PINNED% >nul 2>&1 & git apply "%~dp0megamind-v1.patch" )
if not exist megamind\ensure_config.py ( echo [Megamind] Patch update failed. Report this to Megamind support. & pause & exit /b 1 )
echo [Megamind] Installing the Megamind plugin ^(branding, rounded buttons, light/dark toggle^)...
xcopy /E /I /Y "%~dp0megamind-plugin" "%WAN2GP_DIR%\plugins\megamind" >nul
if not exist plugins\megamind\plugin.py ( echo [Megamind] Plugin install failed. Report this to Megamind support. & pause & exit /b 1 )

if not exist venv %PYLAUNCH% -m venv venv
call venv\Scripts\activate.bat
python -m pip install --upgrade pip
pip install "typing-extensions>=4.10"
REM typing-extensions preinstalled from PyPI: the cu128 index carries it as
REM sdist-only and lacks its build backend, which breaks the torch install.
echo [Megamind] Installing PyTorch 2.7.1 cu128 ^(GTX 10xx build^)...
REM Stable cu128 wheels dropped Pascal (sm_61) kernels; WanGP's documented
REM GTX 10xx path uses the cu128 TEST index. The arch check below catches
REM an existing wrong-index torch (pip would skip it as already installed)
REM and force-reinstalls a build that actually has sm_61 kernels.
python -c "import torch,sys; sys.exit(0 if 'sm_61' in torch.cuda.get_arch_list() else 1)" 2>nul
if errorlevel 1 ( pip install --force-reinstall torch==2.7.1 torchvision==0.22.1 torchaudio==2.7.1 --index-url https://download.pytorch.org/whl/test/cu128 ) else ( echo [Megamind] PyTorch 2.7.1 with Pascal support already present - skipping. )
if errorlevel 1 ( echo [Megamind] PyTorch install failed. Check your internet connection and rerun. & pause & exit /b 1 )

echo [Megamind] Installing WanGP requirements ^(excluding unused torchcodec - see header^)...
findstr /V /I /C:"torchcodec" requirements.txt > requirements_megamind.txt
pip install -r requirements_megamind.txt
if errorlevel 1 ( echo [Megamind] Requirements install failed. Rerun this file to retry. & pause & exit /b 1 )

echo [Megamind] Applying Megamind model selection...
python megamind\curate_models.py

python megamind\ensure_config.py
if errorlevel 1 ( echo [Megamind] Config update failed. Report this to Megamind support. & pause & exit /b 1 )

if not exist "%WAN2GP_DIR%\run_megamind_windows.bat" ( echo [Megamind] Launcher missing - patch did not apply fully. Rerun this file. & pause & exit /b 1 )

echo.
echo [Megamind] Setup complete. Start the studio with: %WAN2GP_DIR%\run_megamind_windows.bat
echo [Megamind] First generation downloads the chosen model - keep several GB free.
pause
