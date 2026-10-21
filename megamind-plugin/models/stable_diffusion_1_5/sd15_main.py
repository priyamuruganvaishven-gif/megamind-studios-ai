# Stable Diffusion 1.5 inference core for the WanGP model plugin.
# Adapted from DeepBeepMeep's reference template
# https://github.com/deepbeepmeep/wan2gp-stable-diffusion-1-4
# with an added safety checker (loaded lazily, kept on CPU).
import json
import os

import torch
from diffusers import DDIMScheduler, EulerDiscreteScheduler
from diffusers.models import AutoencoderKL, UNet2DConditionModel
from mmgp import offload
from shared.utils import files_locator as fl
from tqdm import tqdm
from transformers import CLIPTextModel, CLIPTokenizer

from .sd15_handler import (
    FEATURE_EXTRACTOR_FOLDER,
    REPO_ID,
    SAFETY_CHECKER_FOLDER,
    SCHEDULER_FOLDER,
    TEXT_ENCODER_FOLDER,
    TOKENIZER_FOLDER,
    UNET_FOLDER,
    VAE_FOLDER,
)


def _quantized_filename(filename, dtype):
    name = os.path.basename(filename)
    if dtype == torch.bfloat16:
        name = name.replace("fp16", "bf16").replace("FP16", "bf16")
    elif dtype == torch.float16:
        name = name.replace("bf16", "fp16").replace("BF16", "fp16")
    for dtype_tag in ("mfp16", "fp16", "mbf16", "bf16"):
        if f"_{dtype_tag}" in name:
            return name.replace(f"_{dtype_tag}", f"_quanto_{dtype_tag}_int8")
    stem, ext = os.path.splitext(name)
    return f"{stem}_quanto_int8{ext}"


def _save_quantized_component(model, source_filename, dtype, config_path):
    if "quanto" in os.path.basename(source_filename):
        return
    output_name = _quantized_filename(source_filename, dtype)
    if fl.locate_file(output_name, error_if_none=False) is not None:
        print(f"Quantized Stable Diffusion 1.5 component '{output_name}' already exists.")
        return
    output_path = os.path.join(fl.get_download_location(), output_name)
    offload.save_model(model, output_path, do_quantize=True, config_file_path=config_path)
    print(f"New quantized Stable Diffusion 1.5 component '{output_name}' has been created.")


def _first_file(model_filename):
    return model_filename[0] if isinstance(model_filename, (list, tuple)) else model_filename


def _load_json(path):
    with open(path, "r", encoding="utf-8") as reader:
        return json.load(reader)


def _strip_text_model_prefix(state_dict, quantization_map=None, tied_weights_map=None):
    prefix = "text_model."

    def strip_mapping(mapping):
        if mapping is None:
            return None
        return {key[len(prefix):] if key.startswith(prefix) else key: value for key, value in mapping.items()}

    return strip_mapping(state_dict), strip_mapping(quantization_map), strip_mapping(tied_weights_map)


class model_factory:
    def __init__(
        self,
        model_filename=None,
        model_type=None,
        base_model_type=None,
        model_def=None,
        text_encoder_filename=None,
        quantizeTransformer=False,
        dtype=torch.bfloat16,
        VAE_dtype=torch.float32,
        save_quantized=False,
        **kwargs,
    ):
        if model_def is None:
            raise ValueError("Stable Diffusion 1.5 requires a model definition.")
        unet_filename = _first_file(model_filename)
        if unet_filename is None:
            raise ValueError("No UNet checkpoint was provided for Stable Diffusion 1.5.")
        if text_encoder_filename is None:
            raise ValueError("No CLIP text encoder checkpoint was provided for Stable Diffusion 1.5.")

        self.model_type = model_type
        self.base_model_type = base_model_type
        self.model_def = model_def
        self.dtype = dtype
        self.vae_dtype = VAE_dtype
        self._abort = False
        self._safety_checker = None
        self._feature_extractor = None

        unet_config = fl.locate_file(os.path.join(UNET_FOLDER, "config.json"))
        self.unet = offload.fast_load_transformers_model(
            unet_filename,
            writable_tensors=False,
            modelClass=UNet2DConditionModel,
            defaultConfigPath=unet_config,
            default_dtype=dtype,
            do_quantize=quantizeTransformer and not save_quantized,
        )
        self.transformer = self.unet

        if save_quantized:
            _save_quantized_component(self.unet, unet_filename, dtype, unet_config)

        text_config = fl.locate_file(os.path.join(TEXT_ENCODER_FOLDER, "config.json"))
        self.text_encoder = offload.fast_load_transformers_model(
            text_encoder_filename,
            writable_tensors=False,
            modelClass=CLIPTextModel,
            defaultConfigPath=text_config,
            default_dtype=dtype,
            preprocess_sd=_strip_text_model_prefix if "quanto" in os.path.basename(text_encoder_filename) else None,
        )
        tokenizer_path = os.path.dirname(fl.locate_file(os.path.join(TOKENIZER_FOLDER, "tokenizer_config.json")))
        self.tokenizer = CLIPTokenizer.from_pretrained(tokenizer_path)

        vae_config = fl.locate_file(os.path.join(VAE_FOLDER, "config.json"))
        vae_filename = fl.locate_file(os.path.join(VAE_FOLDER, "diffusion_pytorch_model.fp16.safetensors"))
        self.vae = offload.fast_load_transformers_model(
            vae_filename,
            writable_tensors=False,
            modelClass=AutoencoderKL,
            defaultConfigPath=vae_config,
            default_dtype=VAE_dtype,
        )

        self.scheduler_config = _load_json(fl.locate_file(os.path.join(SCHEDULER_FOLDER, "scheduler_config.json")))
        self.scheduler = self._make_scheduler("euler")

    def _get_safety_checker(self):
        # Lazily loaded once and kept on CPU: the check runs per generated
        # image and must not compete with the GPU models for VRAM.
        if self._safety_checker is None:
            from diffusers.pipelines.stable_diffusion.safety_checker import StableDiffusionSafetyChecker
            from transformers import CLIPImageProcessor

            checker_dir = os.path.dirname(fl.locate_file(os.path.join(SAFETY_CHECKER_FOLDER, "config.json")))
            extractor_dir = os.path.dirname(fl.locate_file(os.path.join(FEATURE_EXTRACTOR_FOLDER, "preprocessor_config.json")))
            self._safety_checker = StableDiffusionSafetyChecker.from_pretrained(
                checker_dir, variant="fp16", torch_dtype=torch.float32, use_safetensors=True, local_files_only=True
            )
            self._safety_checker.eval().to("cpu")
            self._feature_extractor = CLIPImageProcessor.from_pretrained(extractor_dir, local_files_only=True)
        return self._safety_checker, self._feature_extractor

    def _apply_safety_checker(self, images):
        # images: BHWC float tensor in [-1, 1] on CPU. Flagged images become black.
        try:
            checker, extractor = self._get_safety_checker()
        except Exception as exc:
            print(f"Stable Diffusion 1.5 safety checker unavailable ({exc}); returning images unchecked.")
            return images
        np_images = [((img + 1.0) / 2.0).clamp(0, 1).numpy() for img in images]
        inputs = extractor(np_images, return_tensors="pt")
        pixel_values = inputs["pixel_values"].to(dtype=next(checker.parameters()).dtype)
        with torch.inference_mode():
            _, has_nsfw = checker(pixel_values, np_images)
        for index, flagged in enumerate(has_nsfw):
            if flagged:
                images[index] = -1.0
                print(f"Stable Diffusion 1.5 safety checker blacked out image {index + 1}.")
        return images

    def _make_scheduler(self, sample_solver):
        config = dict(self.scheduler_config)
        with torch.device("cpu"):
            scheduler = DDIMScheduler.from_config(config) if sample_solver == "ddim" else EulerDiscreteScheduler.from_config(config)
        for name in ("alphas", "alphas_cumprod", "betas", "final_alpha_cumprod", "sigmas", "timesteps"):
            value = getattr(scheduler, name, None)
            if torch.is_tensor(value):
                setattr(scheduler, name, value.cpu())
        return scheduler

    def _encode_prompt(self, prompt, negative_prompt, batch_size, guide_scale, device):
        max_length = self.tokenizer.model_max_length
        prompt_inputs = self.tokenizer(prompt, padding="max_length", max_length=max_length, truncation=True, return_tensors="pt")
        prompt_embeds = self.text_encoder(prompt_inputs.input_ids.to(device))[0].to(dtype=self.dtype)
        prompt_embeds = prompt_embeds.repeat_interleave(batch_size, dim=0)

        if guide_scale <= 1:
            return prompt_embeds

        negative_inputs = self.tokenizer(negative_prompt or "", padding="max_length", max_length=max_length, truncation=True, return_tensors="pt")
        negative_embeds = self.text_encoder(negative_inputs.input_ids.to(device))[0].to(dtype=self.dtype)
        negative_embeds = negative_embeds.repeat_interleave(batch_size, dim=0)
        return torch.cat([negative_embeds, prompt_embeds], dim=0)

    def _set_vae_tiling(self, VAE_tile_size):
        enabled = False
        if isinstance(VAE_tile_size, int):
            enabled = VAE_tile_size > 0
        elif isinstance(VAE_tile_size, (list, tuple)) and len(VAE_tile_size) > 0:
            enabled = bool(VAE_tile_size[0])
        if enabled and hasattr(self.vae, "enable_tiling"):
            self.vae.enable_tiling()
        elif hasattr(self.vae, "disable_tiling"):
            self.vae.disable_tiling()

    def _decode_latents(self, latents):
        scale = getattr(self.vae.config, "scaling_factor", 0.18215)
        vae_dtype = next(self.vae.parameters()).dtype
        image = self.vae.decode((latents / scale).to(dtype=vae_dtype)).sample
        return image.clamp(-1, 1).detach().float().cpu().movedim(0, 1)

    def generate(
        self,
        input_prompt="",
        n_prompt="",
        batch_size=1,
        height=512,
        width=512,
        sampling_steps=20,
        sample_solver="euler",
        guide_scale=7.5,
        seed=None,
        callback=None,
        VAE_tile_size=None,
        set_progress_status=None,
        **kwargs,
    ):
        if height % 8 != 0 or width % 8 != 0:
            raise ValueError(f"Stable Diffusion 1.5 requires width and height to be multiples of 8, got {width}x{height}.")

        self._abort = False
        batch_size = max(1, int(batch_size))
        sampling_steps = max(1, int(sampling_steps))
        guide_scale = float(guide_scale)
        device = torch.device("cuda" if torch.cuda.is_available() else "cpu")
        generator = torch.Generator(device=device)
        generator.manual_seed(int(torch.seed() % (2**31 - 1)) if seed is None or int(seed) < 0 else int(seed))

        with torch.inference_mode():
            if callable(set_progress_status):
                set_progress_status("Encoding Prompt")
            prompt_embeds = self._encode_prompt(input_prompt or "", n_prompt or "", batch_size, guide_scale, device)

            self.scheduler = self._make_scheduler(sample_solver)
            self.scheduler.set_timesteps(sampling_steps, device=torch.device("cpu"))
            timesteps = self.scheduler.timesteps
            latents = torch.randn((batch_size, self.unet.config.in_channels, height // 8, width // 8), generator=generator, device=device, dtype=self.dtype)
            latents = latents * self.scheduler.init_noise_sigma

            if callback is not None:
                callback(-1, None, True, override_num_inference_steps=len(timesteps))
            if callable(set_progress_status):
                set_progress_status("Denoising")

            for step_idx, timestep in enumerate(tqdm(timesteps, desc="Stable Diffusion 1.5", leave=False)):
                if self._abort:
                    return None
                latent_input = torch.cat([latents, latents], dim=0) if guide_scale > 1 else latents
                latent_input = self.scheduler.scale_model_input(latent_input, timestep)
                noise_pred = self.unet(latent_input, timestep, encoder_hidden_states=prompt_embeds).sample
                if guide_scale > 1:
                    noise_uncond, noise_text = noise_pred.chunk(2)
                    noise_pred = noise_uncond + guide_scale * (noise_text - noise_uncond)
                latents = self.scheduler.step(noise_pred, timestep, latents, return_dict=False)[0]
                if callback is not None:
                    callback(step_idx, None, False)

            if self._abort:
                return None
            if callable(set_progress_status):
                set_progress_status("Decoding Image")
            self._set_vae_tiling(VAE_tile_size)
            images = self._decode_latents(latents)
            return self._apply_safety_checker(images)

    @property
    def _interrupt(self):
        return self._abort

    @_interrupt.setter
    def _interrupt(self, value):
        self._abort = bool(value)
