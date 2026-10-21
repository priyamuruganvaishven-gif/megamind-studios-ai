# Megamind Studios

A local AI generation studio for Windows: video, images, speech and music in one
interface - WanGP's proven engine with the Megamind name and logo, rounded
buttons, a light/dark mode toggle, easy pill navigation and a curated model
selection (Wan 2.2 TI2V-5B, Qwen Image 20B, Chatterbox, ACE-Step 1.5).

## Requirements
- Windows 10/11, NVIDIA GTX 1060 6 GB or better
- Git (https://git-scm.com/download/win)
- Python 3.10.9 (https://www.python.org/downloads/release/python-3109/) - tick "Add python.exe to PATH"
- ~25 GB free disk for the app; each model downloads separately on first use

## Setup (once)
1. Download this repository (Code -> Download ZIP) and unzip it.
2. Double-click `setup_megamind_windows.bat`. It downloads WanGP at a pinned,
   verified commit, adds the Megamind files and branding plugin, and installs
   everything.
3. Start the studio any time with `Wan2GP\run_megamind_windows.bat`.

## Notes
- Built on WanGP by DeepBeepMeep under the WanGP Community License 2.0 - see
  MEGAMIND.md for the modification notice and what the license allows. Upstream
  credits remain in the app's About tab and LICENSE.txt. No upstream source
  file is modified: branding ships as a standard WanGP plugin.
- "Made with WanGP" credit is required if you directly sell generated outputs.
- MiniMax H3 is intentionally excluded for now (license territory limits).
- torchcodec is intentionally excluded from the install: WanGP at the pinned
  commit never imports it (media IO uses imageio/ffmpeg/av/opencv/decord/
  soundfile), its pinned torchcodec 0.10.0 targets torch 2.9+ per the official
  compatibility table, and no Windows wheel exists for the torch 2.7 GTX 10xx
  build. setup_megamind_windows.bat filters it out before pip install.
- Not for resale, white-labeling or hosted/paid access.
- An NVIDIA GPU + driver is required even to LAUNCH the interface: upstream
  WanGP's shared/attention.py (line 17) queries the CUDA device at import and
  there is no CPU-only mode. The Windows install is CI-validated up to that
  hardware boundary (GPU-less runner, 2026-10-21); UI launch and generation on
  your GTX 1060 are NOT yet verified - driver and runtime path untested.
