# Stable Diffusion 1.5 model plugin for WanGP (Megamind Studios build).
# Adapted from DeepBeepMeep's official reference template
# https://github.com/deepbeepmeep/wan2gp-stable-diffusion-1-4
# Model weights: https://huggingface.co/stable-diffusion-v1-5/stable-diffusion-v1-5
# licensed under CreativeML OpenRAIL-M (CompVis / Stability AI / Runway).
import os

import torch
from shared.utils.hf import build_hf_url


REPO_ID = "stable-diffusion-v1-5/stable-diffusion-v1-5"
MODEL_TYPE = "stable_diffusion_1_5"
TEXT_ENCODER_FOLDER = "text_encoder"
TOKENIZER_FOLDER = "tokenizer"
UNET_FOLDER = "unet"
VAE_FOLDER = "vae"
SCHEDULER_FOLDER = "scheduler"
SAFETY_CHECKER_FOLDER = "safety_checker"
FEATURE_EXTRACTOR_FOLDER = "feature_extractor"


SD15_INFOS = """
# Stable Diffusion 1.5

Classic open image generator (CompVis / Stability AI / Runway), built into Megamind's Media Generator. Type a description, press Generate, and the image appears in the gallery like any other model's output.

- First use downloads about 2.7 GB of model files from Hugging Face; later runs start immediately.
- 512 x 512 is its native size and the fastest option. Larger sizes are slower and need more memory.
- 20 Euler steps is the recommended default; more steps give diminishing returns.
- A built-in safety checker screens outputs and blacks out images flagged as unsafe.

Model: https://huggingface.co/stable-diffusion-v1-5/stable-diffusion-v1-5
License: CreativeML OpenRAIL-M - https://huggingface.co/stable-diffusion-v1-5/stable-diffusion-v1-5/blob/main/LICENSE
Plugin adapted from DeepBeepMeep's WanGP Stable Diffusion model-plugin template.
"""


SD15_PROMPT_INFOS = """
# Stable Diffusion 1.5 Prompt Notes

Stable Diffusion 1.5 responds best to concise, concrete image descriptions. Put the subject first, then add style, composition, lighting, and quality cues.

## Useful Prompt Shape

```text
subject, setting, style or medium, camera/framing, lighting, color palette, detail level
```

## Negative Prompt

Use the negative prompt to remove common artifacts such as blur, distorted anatomy, duplicate limbs, text, watermark, or low quality output.
"""


class family_handler:
    @staticmethod
    def query_supported_types():
        return [MODEL_TYPE]

    @staticmethod
    def query_family_infos():
        return {"stable_diffusion": (190, "Stable Diffusion")}

    @staticmethod
    def query_family_maps():
        return {}, {}

    @staticmethod
    def query_model_family():
        return "stable_diffusion"

    @staticmethod
    def query_model_def(base_model_type, model_def):
        # Model plugins use the same model-def keys as native models. WanGP has
        # already prepended this plugin's profiles root before it reaches here.
        return {
            "image_outputs": True,
            "profile_type": "image",
            "guidance_max_phases": 1,
            "sample_solvers": [("Euler", "euler"), ("DDIM", "ddim")],
            "preset_profiles_dir": [MODEL_TYPE],
            "profiles_dir": [],
            "infos": model_def.get("infos", SD15_INFOS),
            "prompt_infos": model_def.get("prompt_infos", SD15_PROMPT_INFOS),
            "text_encoder_folder": TEXT_ENCODER_FOLDER,
            "text_encoder_URLs": [
                build_hf_url(REPO_ID, TEXT_ENCODER_FOLDER, "model.fp16.safetensors"),
            ],
            "resolutions": [
                ("512 x 512", "512x512"),
                ("768 x 512", "768x512"),
                ("512 x 768", "512x768"),
            ],
            "no_background_removal": True,
        }

    @staticmethod
    def query_model_files(computeList, base_model_type, model_def=None):
        # Main UNet weights stay in model.URLs. Everything else the model needs
        # is listed here so WanGP downloads it before load_model(...). Folder
        # names mirror the official Stable Diffusion 1.5 repo layout.
        return [
            {
                "repoId": REPO_ID,
                "sourceFolderList": [
                    TEXT_ENCODER_FOLDER,
                    TOKENIZER_FOLDER,
                    UNET_FOLDER,
                    VAE_FOLDER,
                    SCHEDULER_FOLDER,
                    SAFETY_CHECKER_FOLDER,
                    FEATURE_EXTRACTOR_FOLDER,
                ],
                "fileList": [
                    ["config.json"],
                    ["merges.txt", "special_tokens_map.json", "tokenizer_config.json", "vocab.json"],
                    ["config.json"],
                    ["config.json", "diffusion_pytorch_model.fp16.safetensors"],
                    ["scheduler_config.json"],
                    ["config.json", "model.fp16.safetensors"],
                    ["preprocessor_config.json"],
                ],
            }
        ]

    @staticmethod
    def register_lora_cli_args(parser, lora_root):
        parser.add_argument(
            "--lora-dir-stable-diffusion-1-5",
            type=str,
            default=None,
            help=f"Path to a directory that contains Stable Diffusion 1.5 LoRAs (default: {os.path.join(lora_root, MODEL_TYPE)})",
        )

    @staticmethod
    def get_lora_dir(base_model_type, args, lora_root):
        lora_dir = getattr(args, "lora_dir_stable_diffusion_1_5", None) or os.path.join(lora_root, MODEL_TYPE)
        try:
            os.makedirs(lora_dir, exist_ok=True)
        except OSError:
            return None
        return lora_dir

    @staticmethod
    def load_model(
        model_filename,
        model_type=None,
        base_model_type=None,
        model_def=None,
        quantizeTransformer=False,
        text_encoder_quantization=None,
        dtype=torch.bfloat16,
        VAE_dtype=torch.float32,
        mixed_precision_transformer=False,
        save_quantized=False,
        submodel_no_list=None,
        text_encoder_filename=None,
        **kwargs,
    ):
        from .sd15_main import model_factory

        pipe_processor = model_factory(
            model_filename=model_filename,
            model_type=model_type,
            base_model_type=base_model_type,
            model_def=model_def,
            text_encoder_filename=text_encoder_filename,
            quantizeTransformer=quantizeTransformer,
            dtype=dtype,
            VAE_dtype=VAE_dtype,
            save_quantized=save_quantized,
        )
        return pipe_processor, {
            "transformer": pipe_processor.unet,
            "text_encoder": pipe_processor.text_encoder,
            "vae": pipe_processor.vae,
        }

    @staticmethod
    def update_default_settings(base_model_type, model_def, ui_defaults):
        ui_defaults.update({
            "image_mode": 1,
            "resolution": "512x512",
            "num_inference_steps": 20,
            "guidance_scale": 7.5,
            "sample_solver": "euler",
        })

    @staticmethod
    def fix_settings(base_model_type, settings_version, model_def, ui_defaults):
        pass
