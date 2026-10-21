# Megamind Studios - modification notice

Megamind Studios is a copy of WanGP (https://github.com/deepbeepmeep/Wan2GP)
by DeepBeepMeep, extended under the WanGP Community License 2.0 (see LICENSE.txt,
unmodified). All upstream copyright, attribution and license notices are preserved,
and the About tab credits are retained. No upstream source file is modified: all
changes are add-on files plus a WanGP plugin.

Additions (first applied 2026-10-21, image model added 2026-10-21):

1. Branding plugin (plugins/megamind, installed by setup_megamind_windows.bat from
   the megamind-plugin folder in the Megamind Studios repo): browser title reads
   "Megamind Studios", the header shows the Megamind Studios logo, buttons and
   inputs are rounded, and a Light/Dark toggle sits at the top-right (dark mode
   follows the toggle, not the OS setting). Tabs are shown as clear pill
   navigation with an obvious active state. The plugin uses WanGP's own plugin
   API (custom JS/CSS); it changes appearance only and does not alter generation,
   models or settings.
2. Image generation inside the Media Generator: the same plugin registers
   Stable Diffusion 1.5 as a native model through WanGP's plugin model API
   (plugin_info.json model_handlers/defaults/profiles, the mechanism documented
   by the official WanGP SD 1.4 reference plugin,
   https://github.com/deepbeepmeep/wan2gp-stable-diffusion-1-4). It appears in
   the normal model selector as "Stable Diffusion > 1.5" next to the video,
   speech and music models - no separate software. The checkpoint comes from the
   official repo https://huggingface.co/stable-diffusion-v1-5/stable-diffusion-v1-5
   (CreativeML OpenRAIL-M license, attribution retained in the plugin), in FP16,
   including its safety checker. See the tutorial below.
3. Model selection: the displayed model list is curated to Wan 2.1 T2V-1.3B
   (video), Chatterbox (speech) and ACE-Step 1.5 (music), plus Stable Diffusion
   1.5 (image) from the plugin - the smallest practical option in each category
   that computes in FP16 - using WanGP's own finetunes/*.json visibility
   mechanism (megamind/curate_models.py), plus a first-run configuration seed
   and existing-install migration (megamind/wgp_config.template.json,
   megamind/ensure_config.py). The migration also enables the megamind plugin
   and resets a stale "megamind" UI theme value to "default" for installs that
   used the earlier theme-patch build. FLUX.2 Klein 4B was evaluated for image
   and rejected: its Flux2 loader pipeline is bf16-only (hardcoded in
   models/flux/util.py, ignoring WanGP's Pascal FP16 fallback) and bf16 models
   do not run on pre-Ampere GPUs (Wan2GP issue #225). Wan 2.2 TI2V-5B was also
   evaluated and dropped: ~10.5 GB on disk and 720p-only guidance is a poor fit
   for 6 GB VRAM and a 30-minute-per-generation target; SD 1.5 is far lighter.
4. run_megamind_windows.bat launcher and megamind/ support folder, added alongside
   upstream files.

## Tutorial: your first image

1. Run setup_megamind_windows.bat again (it updates the plugin and migrates
   your settings; your downloads and loras are kept).
2. Start the app with run_megamind_windows.bat and open the Media Generator
   tab (it opens by default).
3. In the model family dropdown (top-left), pick "Stable Diffusion", then
   model "1.5". The page switches to image mode.
4. The first time, set the resolution yourself: open the resolution budget
   dropdown (it may still show "480p" from the video model), pick "384p",
   then open the resolution dropdown next to it and pick "512x512 (1:1)".
   512x512 is SD 1.5's native size and the fastest option. The app remembers
   your choice afterwards.
5. Leave Inference Steps at 20 (the default) and the solver at Euler.
6. Type a prompt and press Generate.
7. First use downloads about 2.7 GB of model files (UNet, VAE, text encoder
   and safety checker, all FP16) from Hugging Face; later runs start
   straight away.
8. Not yet verified: generation speed on your GTX 1060 6 GB. Treat the first
   image as a timed test - if a single 512x512 / 20-step image takes too
   long, tell us the time before trying bigger sizes. The 30-minute
   per-generation limit has NOT been confirmed for image generation yet.

## Tutorial: video, speech and music (unchanged)

- Video: pick Wan 2.1 > T2V-1.3B. First settings: 832x480, 49 frames, 20
  steps (WanGP's own recommendation). If too slow, drop to 33 frames / 15
  steps before dropping resolution. This model is text-to-video only.
- Speech: pick Chatterbox, type or paste the text, Generate.
- Music: pick ACE-Step 1.5, describe the track, Generate.

Hardware configuration: GTX 1060 6GB (Pascal)

The seeded configuration (megamind/wgp_config.template.json) targets GTX 10xx:

- Quantization: 16-bit (no quantization) for the transformer, Scaled Int8 for
  the text encoder. This is the Pascal requirement, not a quality choice:
  every int8 quanto checkpoint offered for the curated Wan models is
  bf16-named, and WanGP forces the compute dtype to bfloat16 for bf16-named
  quanto files (wgp.py:4229-4231) regardless of the FP16 fallback - and bf16
  does not run on pre-Ampere GPUs (Wan2GP issue #225, confirmed on RTX 2060).
  The unquantized checkpoints carry no forcing, so the fallback below
  applies. The trade is RAM (the 64 GB target machine absorbs it), not
  quality. FP8 needs newer GPUs (sm_89+) and is not offered. SD 1.5 is FP16
  by design (its model definition sets dtype FP16), independent of this.
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
upstream defaults/*.json, the DeepBeepMeep HF repos, and the official
Stable Diffusion 1.5 HF repo):

- Wan 2.1 T2V-1.3B (video): wan2.1_text2video_1.3B_mbf16.safetensors (2.87 GB,
  the only variant; loads FP16 on Pascal via the fallback). Shares the
  umt5-xxl int8 text encoder (6.73 GB, CPU-offloaded) with the other Wan
  models (DeepBeepMeep/Wan2.1).
- Stable Diffusion 1.5 (image, plugin): unet, VAE, text encoder and safety
  checker, all official FP16 safetensors from
  stable-diffusion-v1-5/stable-diffusion-v1-5 (about 2.7 GB total). Loads in
  FP16 as its model definition declares; verified Pascal-safe by the same
  dtype trace (fp16-named, non-quanto files carry no bf16 forcing).
  CreativeML OpenRAIL-M license.
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

Expectations on 6GB (30-minute per-generation target): the curated models
are the smallest practical options whose compute dtype falls back to FP16 on
Pascal. Generation speed and memory fit were NOT tested on the target GPU
(no GPU in the build environment) - treat the first run of each model as a
timed test and abort any run that passes 30 minutes. Wan 2.1 1.3B is
text-to-video only. The other upstream default models (FLUX.2 Klein 4B,
Qwen Image 20B, Wan 2.2 TI2V-5B and the rest) are hidden by the curation but
never deleted: already-downloaded checkpoints stay on disk and the models
can be re-added by removing their finetunes/*.json hiding stubs.

Intended use: internal studio/client content production tool. Not for resale,
white-labeling, hosted/paid access or redistribution as a product - those remain
restricted by the WanGP Community License 2.0. "Made with WanGP" credit is required
for Direct Output Sales (license section 6).
