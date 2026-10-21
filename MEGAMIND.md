# Megamind Studios - modification notice

Megamind Studios is a copy of WanGP (https://github.com/deepbeepmeep/Wan2GP)
by DeepBeepMeep, extended under the WanGP Community License 2.0 (see LICENSE.txt,
unmodified). All upstream copyright, attribution and license notices are preserved,
and the About tab credits are retained. No upstream source file is modified: all
changes are add-on files plus a WanGP plugin.

Additions (first applied 2026-10-21, plugin conversion 2026-10-21):

1. Branding plugin (plugins/megamind, installed by setup_megamind_windows.bat from
   the megamind-plugin folder in the Megamind Studios repo): browser title reads
   "Megamind Studios", the header shows the Megamind Studios logo, buttons and
   inputs are rounded, and a Light/Dark toggle sits at the top-right (dark mode
   follows the toggle, not the OS setting). Tabs are shown as clear pill
   navigation with an obvious active state. The plugin uses WanGP's own plugin
   API (custom JS/CSS); it changes appearance only and does not alter generation,
   models or settings.
2. Model selection: the displayed model list is curated to Wan 2.1 T2V-1.3B
   (video), FLUX.2 Klein 4B (image), Chatterbox (speech) and ACE-Step 1.5
   (music) - the smallest WanGP option in each category - using
   WanGP's own finetunes/*.json visibility mechanism (megamind/curate_models.py),
   plus a first-run configuration seed and existing-install migration
   (megamind/wgp_config.template.json, megamind/ensure_config.py). The migration
   also enables the megamind plugin and resets a stale "megamind" UI theme value
   to "default" for installs that used the earlier theme-patch build.
3. run_megamind_windows.bat launcher and megamind/ support folder, added alongside
   upstream files.

Hardware configuration: GTX 1060 6GB (Pascal)

The seeded configuration (megamind/wgp_config.template.json) targets GTX 10xx:

- Quantization: Scaled Int8 for transformer and text encoder - WanGP's own
  default and recommendation, and the Pascal-compatible path. FP8 is not
  offered for these models and needs newer GPUs (sm_89+).
- Data type: WanGP automatically switches to FP16 on GPUs with compute
  capability below 8.0 (bfloat16_supported check in wgp.py). The startup
  console line "GPU architecture doesn't support optimed BF16 Kernels" is
  this normal fallback, not an error.
- Attention: auto, which resolves to sdpa on Pascal (flash/sage need newer
  GPUs).
- Memory profile: 4 (LowRAM_LowVRAM, upstream "Recommended") for video and
  image, 3 (LowRAM_HighVRAM, upstream-recommended for audio) for audio.

Per-model checkpoint actually downloaded with Int8 (verified against the
pinned upstream defaults/*.json):

- Wan 2.1 T2V-1.3B: wan2.1_text2video_1.3B_mbf16.safetensors - 1.3B is small
  enough to run unquantized (WanGP auto-switches compute to FP16 on Pascal);
  no int8 variant exists for it. Shares the umt5-xxl int8 text encoder
  (6.73 GB) with the other Wan video models (DeepBeepMeep/Wan2.1).
- FLUX.2 Klein 4B: flux-2-klein-4b_quanto_bf16_int8.safetensors plus its
  qwen3_quanto_bf16_int8.safetensors text encoder (DeepBeepMeep/Flux2,
  DeepBeepMeep/Z-Image). Distilled: 4 inference steps by default.
- ACE-Step 1.5 Turbo 2B: ace_step_v1_5_transformer_quanto_bf16_int8.safetensors
  (DiT-only build, no LM stage)
- Chatterbox: t3_mtl23ls_v2.safetensors (small single file, no quant needed)

PyTorch for GTX 10xx: 2.7.1 from the cu128 TEST index
(download.pytorch.org/whl/test/cu128) - the stable cu128 wheels dropped the
Pascal (sm_61) kernels. setup_megamind_windows.bat checks
torch.cuda.get_arch_list() for sm_61 and force-reinstalls from the right
index when missing. If generation still fails with "no kernel image is
available for execution on the device", install the same pins from
https://download.pytorch.org/whl/cu126 instead.

Expectations on 6GB (30-minute per-generation target): the four curated
models are the smallest WanGP options in their category. Generation speed
and memory fit were NOT tested on the target GPU (no GPU in the build
environment) - treat the first run of each model as a timed test and abort
any run that passes 30 minutes. For Wan 2.1 1.3B video, WanGP's docs
recommend 832x480, 49 frames, 20 steps as first settings; if that is too
slow on this card, drop to 33 frames / 15 steps before dropping resolution.
Wan 2.1 1.3B is text-to-video only. The earlier defaults (Wan 2.2 TI2V-5B,
Qwen Image 20B) are hidden by the curation update but never deleted:
already-downloaded checkpoints stay on disk and the models can be re-added
by removing their finetunes/*.json hiding stubs.

Intended use: internal studio/client content production tool. Not for resale,
white-labeling, hosted/paid access or redistribution as a product - those remain
restricted by the WanGP Community License 2.0. "Made with WanGP" credit is required
for Direct Output Sales (license section 6).
