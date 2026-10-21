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
   (video), Wan 2.2 TI2V-5B (image, in image mode), Chatterbox (speech) and
   ACE-Step 1.5 (music) - the smallest WanGP option in each category that
   computes in FP16 - using WanGP's own finetunes/*.json visibility mechanism
   (megamind/curate_models.py), plus a first-run configuration seed and
   existing-install migration (megamind/wgp_config.template.json,
   megamind/ensure_config.py). The migration also enables the megamind plugin
   and resets a stale "megamind" UI theme value to "default" for installs that
   used the earlier theme-patch build. FLUX.2 Klein 4B was evaluated for image
   and rejected: its Flux2 loader pipeline is bf16-only (hardcoded in
   models/flux/util.py, ignoring WanGP's Pascal FP16 fallback) and bf16 models
   do not run on pre-Ampere GPUs (Wan2GP issue #225).
3. run_megamind_windows.bat launcher and megamind/ support folder, added alongside
   upstream files.

Hardware configuration: GTX 1060 6GB (Pascal)

The seeded configuration (megamind/wgp_config.template.json) targets GTX 10xx:

- Quantization: 16-bit (no quantization) for the transformer, Scaled Int8 for
  the text encoder. This is the Pascal requirement, not a quality choice:
  every int8 quanto checkpoint offered for the curated models is bf16-named,
  and WanGP forces the compute dtype to bfloat16 for bf16-named quanto files
  (wgp.py:4229-4231) regardless of the FP16 fallback - and bf16 does not run
  on pre-Ampere GPUs (Wan2GP issue #225, confirmed on RTX 2060). The
  unquantized checkpoints carry no forcing, so the fallback below applies.
  The trade is RAM (the 64 GB target machine absorbs it), not quality.
  FP8 needs newer GPUs (sm_89+) and is not offered.
- Data type: WanGP automatically switches to FP16 on GPUs with compute
  capability below 8.0 (bfloat16_supported check in wgp.py) when the loaded
  checkpoint is not bf16-forced - which the configuration above guarantees.
  The startup console line "GPU architecture doesn't support optimed BF16
  Kernels" is this normal fallback, not an error. The shared umt5-xxl int8
  text encoder (bf16-named, 6.73 GB) is bf16-typed but too large for 6 GB
  VRAM, so it runs CPU-offloaded under memory profile 4 - bf16 on CPU is
  fine; this is the same path every Wan-on-GTX-10xx install uses.
- Attention: auto, which resolves to sdpa on Pascal (flash/sage need newer
  GPUs).
- Memory profile: 4 (LowRAM_LowVRAM, upstream "Recommended") for video and
  image, 3 (LowRAM_HighVRAM, upstream-recommended for audio) for audio.

Per-model checkpoint actually downloaded (verified against the pinned
upstream defaults/*.json and the DeepBeepMeep HF repos):

- Wan 2.1 T2V-1.3B (video): wan2.1_text2video_1.3B_mbf16.safetensors (2.87 GB,
  the only variant; loads FP16 on Pascal via the fallback). Shares the
  umt5-xxl int8 text encoder (6.73 GB, CPU-offloaded) with the other Wan
  models (DeepBeepMeep/Wan2.1).
- Wan 2.2 TI2V-5B (image): wan2.2_text2video_5B_mbf16.safetensors (~10.5 GB
  unquantized; the Wan loader honors the FP16 fallback). Use it in image mode
  (single frame) - the int8 variant is bf16-forced and cannot run on Pascal.
  Shares the same umt5-xxl encoder. 720p or better only (upstream warns
  lower resolutions give poor results on this model).
- ACE-Step 1.5 Turbo 2B (music): ace_step_v1_5_transformer_bf16.safetensors
  (~4.8 GB unquantized; its pipeline threads the FP16 dtype through the DiT,
  audio VAE and text encoder). DiT-only build, no LM stage.
- Chatterbox (speech): t3_mtl23ls_v2.safetensors (2.14 GB, fp32 on disk,
  converted to FP16 at load on Pascal).

PyTorch for GTX 10xx (Windows): torch 2.7.1 + cu128 from the standard
index. The actual Windows cu128 wheel was binary-verified to contain
Pascal (sm_61) SASS - full GTX 10xx support - and the cu128 test-index URL
in upstream's GTX 10xx docs serves the identical Windows wheel (sha256
match). Note the LINUX cu128 wheel did drop Pascal (pytorch/pytorch#157517);
irrelevant to this Windows-only build.

Expectations on 6GB (30-minute per-generation target): the four curated
models are the smallest WanGP options in their category whose compute dtype
falls back to FP16 on Pascal. Generation speed and memory fit were NOT
tested on the target GPU (no GPU in the build environment) - treat the
first run of each model as a timed test and abort any run that passes 30
minutes. For Wan 2.1 1.3B video, WanGP's docs recommend 832x480, 49 frames,
20 steps as first settings; if that is too slow on this card, drop to 33
frames / 15 steps before dropping resolution. Wan 2.1 1.3B is text-to-video
only. For Wan 2.2 5B images, start with a single 720p image before longer
jobs. FLUX.2 Klein 4B, Qwen Image 20B and the other upstream defaults are
hidden by the curation but never deleted: already-downloaded checkpoints
stay on disk and the models can be re-added by removing their
finetunes/*.json hiding stubs.

Intended use: internal studio/client content production tool. Not for resale,
white-labeling, hosted/paid access or redistribution as a product - those remain
restricted by the WanGP Community License 2.0. "Made with WanGP" credit is required
for Direct Output Sales (license section 6).
