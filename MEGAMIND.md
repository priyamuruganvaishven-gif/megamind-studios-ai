# Megamind Studios - modification notice

Megamind Studios is a modified copy of WanGP (https://github.com/deepbeepmeep/Wan2GP)
by DeepBeepMeep, under the WanGP Community License 2.0 (see LICENSE.txt, unmodified).
All upstream copyright, attribution and license notices are preserved, and the About
tab credits are retained.

Modifications (first applied 2026-10-21, updated 2026-10-21):

1. Branding: browser title reads "Megamind Studios" and the main header shows the
   Megamind Studios logo image (wgp.py). The theme is locked to the light
   white/orange/black design even when Windows/browser dark mode is on
   (shared/gradio/ui_studio.py, shared/gradio/ui_studio_megamind.css).
2. Theme: added a "megamind" UI theme (white background, orange accents, black text)
   via shared/gradio/ui_studio.py and shared/gradio/ui_studio_megamind.css, set as
   the default UI theme.
3. Model selection: the displayed model list is curated to Wan 2.2 TI2V-5B (video),
   Qwen Image 20B (image), Chatterbox (speech) and ACE-Step 1.5 (music) using
   WanGP's own finetunes/*.json visibility mechanism (megamind/curate_models.py),
   plus a first-run configuration seed and existing-install migration
   (megamind/wgp_config.template.json, megamind/ensure_config.py).


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

- Wan 2.2 TI2V-5B: wan2.2_text2video_5B_quanto_mbf16_int8.safetensors
  (DeepBeepMeep/Wan2.2)
- Qwen Image 20B: qwen_image_20B_quanto_bf16_int8.safetensors
  (DeepBeepMeep/Qwen_image)
- ACE-Step 1.5 Turbo 2B: ace_step_v1_5_transformer_quanto_bf16_int8.safetensors
  (DiT-only build, no LM stage)
- Chatterbox: t3_mtl23ls_v2.safetensors (small single file, no quant needed)

Expectations on 6GB: Wan 2.2 TI2V-5B is the comfortable model (WanGP's
low-VRAM flagship). Qwen Image 20B runs through WanGP's layer streaming but
is slow on 6GB; lower the resolution if VRAM runs out. Generation speed was
not tested on the target GPU (no GPU in the build environment).

Intended use: internal studio/client content production tool. Not for resale,
white-labeling, hosted/paid access or redistribution as a product - those remain
restricted by the WanGP Community License 2.0. "Made with WanGP" credit is required
for Direct Output Sales (license section 6).
