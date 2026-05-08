#!/usr/bin/env python3
"""Generate pixel-art sprites via the ComfyUI sandbox and drop them into godot/assets/sprites/.

Pipeline per sprite:
1. Build an SDXL + Pixel Art XL LoRA workflow with the spec's prompt.
2. POST /prompt to ComfyUI, poll /history/<id> until complete.
3. Read the generated PNG from the sandbox output dir.
4. Post-process: trim transparent border, nearest-neighbor downscale to target size,
   quantize to a fixed palette of at most N colors with optional alpha cutoff.
5. Write to godot/assets/sprites/<category>/<name>.png.

ComfyUI sandbox: http://127.0.0.1:8190 (NOT localhost — IPv6 ::1 times out).
Output dir on Windows: F:\\render-pipeline\\sandbox\\output\\.
"""

from __future__ import annotations

import argparse
import json
import shutil
import sys
import time
import urllib.error
import urllib.parse
import urllib.request
import uuid
from dataclasses import dataclass
from pathlib import Path

from PIL import Image

COMFY_URL = "http://127.0.0.1:8190"
SANDBOX_OUTPUT = Path(r"F:/render-pipeline/sandbox/output")
REPO_ROOT = Path(__file__).resolve().parent.parent
SPRITES_ROOT = REPO_ROOT / "godot" / "assets" / "sprites"

CHECKPOINT = "sd_xl_base_1.0.safetensors"
LORA = "pixel-art-xl.safetensors"
NEGATIVE = "3d, blurry, photorealistic, gradient, bokeh, smooth shading, anti-aliased, jpeg artifacts, watermark, signature, text, sprite sheet, multiple variants, grid, collage, contact sheet, many copies, duplicates"


@dataclass
class SpriteSpec:
    name: str
    category: str
    prompt: str
    target_size: int = 128  # final pixel-art resolution
    palette_size: int = 32   # colors after quantization
    seed: int = 0            # 0 = pick a fresh seed each run


def workflow(spec: SpriteSpec) -> dict:
    seed = spec.seed if spec.seed else int(time.time() * 1000) & 0xFFFFFFFF
    full_prompt = (
        f"pixel art, {spec.prompt}, centered, simple background, "
        "white background, crisp pixels, limited palette, game sprite, top-down or 3/4 view"
    )
    return {
        "1": {"class_type": "CheckpointLoaderSimple", "inputs": {"ckpt_name": CHECKPOINT}},
        "2": {
            "class_type": "LoraLoader",
            "inputs": {"model": ["1", 0], "clip": ["1", 1], "lora_name": LORA, "strength_model": 1.0, "strength_clip": 1.0},
        },
        "3": {"class_type": "CLIPTextEncode", "inputs": {"clip": ["2", 1], "text": full_prompt}},
        "4": {"class_type": "CLIPTextEncode", "inputs": {"clip": ["2", 1], "text": NEGATIVE}},
        "5": {"class_type": "EmptyLatentImage", "inputs": {"width": 1024, "height": 1024, "batch_size": 1}},
        "6": {
            "class_type": "KSampler",
            "inputs": {
                "model": ["2", 0],
                "positive": ["3", 0],
                "negative": ["4", 0],
                "latent_image": ["5", 0],
                "seed": seed,
                "steps": 25,
                "cfg": 8.0,
                "sampler_name": "euler",
                "scheduler": "normal",
                "denoise": 1.0,
            },
        },
        "7": {"class_type": "VAEDecode", "inputs": {"samples": ["6", 0], "vae": ["1", 2]}},
        "8": {
            "class_type": "SaveImage",
            "inputs": {"images": ["7", 0], "filename_prefix": f"homebrewer/{spec.name}"},
        },
    }


def submit(prompt: dict) -> str:
    client_id = str(uuid.uuid4())
    body = json.dumps({"prompt": prompt, "client_id": client_id}).encode()
    req = urllib.request.Request(f"{COMFY_URL}/prompt", data=body, headers={"Content-Type": "application/json"})
    with urllib.request.urlopen(req, timeout=30) as r:
        return json.loads(r.read())["prompt_id"]


def wait_for(prompt_id: str, timeout_s: int = 600) -> list[Path]:
    """Poll /history/<id> until the prompt finishes; return paths to its output PNGs."""
    deadline = time.time() + timeout_s
    while time.time() < deadline:
        time.sleep(2)
        try:
            with urllib.request.urlopen(f"{COMFY_URL}/history/{prompt_id}", timeout=15) as r:
                hist = json.loads(r.read())
        except urllib.error.URLError:
            continue
        if not hist or prompt_id not in hist:
            continue
        entry = hist[prompt_id]
        status = entry.get("status", {})
        if not status.get("completed"):
            if status.get("status_str") == "error":
                raise RuntimeError(f"ComfyUI error for {prompt_id}: {entry.get('status')}")
            continue
        outputs = entry.get("outputs", {})
        paths: list[Path] = []
        for node_out in outputs.values():
            for img in node_out.get("images", []):
                subfolder = img.get("subfolder", "")
                paths.append(SANDBOX_OUTPUT / subfolder / img["filename"])
        if paths:
            return paths
    raise TimeoutError(f"Prompt {prompt_id} did not complete within {timeout_s}s")


def post_process(src: Path, dest: Path, target_size: int, palette_size: int) -> None:
    img = Image.open(src).convert("RGBA")
    # Trim near-white background to alpha so the sprite has a clean edge.
    img = _whiteish_to_alpha(img, threshold=240)
    img = _trim_transparent(img)
    # Pad to square so aspect ratio survives the resize.
    img = _pad_square(img)
    img = img.resize((target_size, target_size), Image.NEAREST)
    img = _quantize_rgba(img, palette_size)
    dest.parent.mkdir(parents=True, exist_ok=True)
    img.save(dest, "PNG", optimize=True)


def _whiteish_to_alpha(img: Image.Image, threshold: int = 240) -> Image.Image:
    px = img.load()
    w, h = img.size
    for y in range(h):
        for x in range(w):
            r, g, b, a = px[x, y]
            if r >= threshold and g >= threshold and b >= threshold:
                px[x, y] = (r, g, b, 0)
    return img


def _trim_transparent(img: Image.Image) -> Image.Image:
    bbox = img.getchannel("A").getbbox()
    return img.crop(bbox) if bbox else img


def _pad_square(img: Image.Image) -> Image.Image:
    w, h = img.size
    side = max(w, h)
    out = Image.new("RGBA", (side, side), (0, 0, 0, 0))
    out.paste(img, ((side - w) // 2, (side - h) // 2))
    return out


def _quantize_rgba(img: Image.Image, n: int) -> Image.Image:
    # Pillow's quantize doesn't preserve alpha in one shot; quantize RGB and reattach alpha.
    alpha = img.getchannel("A")
    rgb = img.convert("RGB").quantize(colors=n, method=Image.Quantize.MEDIANCUT, dither=Image.Dither.NONE).convert("RGB")
    out = rgb.convert("RGBA")
    out.putalpha(alpha)
    # Make any pixel whose alpha is below 32 fully transparent — crisp edges.
    px = out.load()
    w, h = out.size
    for y in range(h):
        for x in range(w):
            r, g, b, a = px[x, y]
            if a < 32:
                px[x, y] = (0, 0, 0, 0)
            elif a < 255:
                px[x, y] = (r, g, b, 255)
    return out


def gen(spec: SpriteSpec) -> Path:
    print(f"[gen] {spec.category}/{spec.name} — \"{spec.prompt[:60]}...\"")
    prompt_id = submit(workflow(spec))
    print(f"  prompt_id={prompt_id}, waiting...")
    out_paths = wait_for(prompt_id)
    src = out_paths[0]
    print(f"  comfy out: {src}")
    dest = SPRITES_ROOT / spec.category / f"{spec.name}.png"
    post_process(src, dest, spec.target_size, spec.palette_size)
    print(f"  -> {dest.relative_to(REPO_ROOT)}")
    return dest


def main() -> int:
    ap = argparse.ArgumentParser()
    ap.add_argument("--specs", type=Path, default=REPO_ROOT / "scripts" / "sprite_specs.json")
    ap.add_argument("--only", nargs="*", help="Limit to these sprite names")
    args = ap.parse_args()

    specs_data = json.loads(args.specs.read_text())
    specs = [SpriteSpec(**s) for s in specs_data]
    if args.only:
        specs = [s for s in specs if s.name in set(args.only)]
    if not specs:
        print("no specs to run", file=sys.stderr)
        return 1

    for s in specs:
        try:
            gen(s)
        except Exception as e:
            print(f"  FAILED: {e}", file=sys.stderr)
            return 2
    return 0


if __name__ == "__main__":
    sys.exit(main())
