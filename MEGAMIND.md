# Megamind Studios - modification notice

Megamind Studios is a modified copy of WanGP (https://github.com/deepbeepmeep/Wan2GP)
by DeepBeepMeep, under the WanGP Community License 2.0 (see LICENSE.txt, unmodified).
All upstream copyright, attribution and license notices are preserved, and the About
tab credits are retained.

Modifications (first applied 2026-10-21):

1. Branding: browser title and main header read "Megamind Studios" (wgp.py).
2. Theme: added a "megamind" UI theme (white background, orange accents, black text)
   via shared/gradio/ui_studio.py and shared/gradio/ui_studio_megamind.css, set as
   the default UI theme.
3. Model selection: the displayed model list is curated to Wan 2.2 TI2V-5B (video),
   Qwen Image 20B (image), Chatterbox (speech) and ACE-Step 1.5 (music) using
   WanGP's own finetunes/*.json visibility mechanism (megamind/curate_models.py),
   plus a first-run configuration seed (megamind/wgp_config.template.json).

Intended use: internal studio/client content production tool. Not for resale,
white-labeling, hosted/paid access or redistribution as a product - those remain
restricted by the WanGP Community License 2.0. "Made with WanGP" credit is required
for Direct Output Sales (license section 6).
