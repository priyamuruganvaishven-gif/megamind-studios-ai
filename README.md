# Megamind Studios

A local AI generation studio for Windows: video, images, speech and music in one
interface - WanGP's proven engine with the Megamind name, a white/orange/black
theme and a curated model selection (Wan 2.2 TI2V-5B, Qwen Image 20B, Chatterbox,
ACE-Step 1.5).

## Requirements
- Windows 10/11, NVIDIA GTX 1060 6 GB or better
- Git (https://git-scm.com/download/win)
- Python 3.10.9 (https://www.python.org/downloads/release/python-3109/) - tick "Add python.exe to PATH"
- ~25 GB free disk for the app; each model downloads separately on first use

## Setup (once)
1. Download this repository (Code -> Download ZIP) and unzip it.
2. Double-click `setup_megamind_windows.bat`. It downloads WanGP at a pinned,
   verified commit, applies the Megamind patch and installs everything.
3. Start the studio any time with `Wan2GP\run_megamind_windows.bat`.

## Notes
- Built on WanGP by DeepBeepMeep under the WanGP Community License 2.0 - see
  MEGAMIND.md for the modification notice and what the license allows. Upstream
  credits remain in the app's About tab and LICENSE.txt.
- "Made with WanGP" credit is required if you directly sell generated outputs.
- MiniMax H3 is intentionally excluded for now (license territory limits).
- Not for resale, white-labeling or hosted/paid access.
