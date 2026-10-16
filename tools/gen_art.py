#!/usr/bin/env python3
"""Generate issue #298's seven review assets; never installs art into the game.

Requires Python 3 and Pillow. GEMINI_API_KEY is read only for a live request and
sent in an HTTPS header, never in URLs, manifests, or diagnostic output.
See docs/art-generation/issue-298.md for provenance and review instructions.
"""

import argparse
import base64
import hashlib
import io
import json
import os
from pathlib import Path
import re
import sys
import urllib.error
import urllib.request

from PIL import Image, ImageChops, ImageDraw, ImageFont, ImageOps

ROOT = Path(__file__).resolve().parents[1]
MODEL = "gemini-nano-banana-2.1"
MODEL_DOC = "https://ai.google.dev/gemini-api/docs/models/gemini-nano-banana-2.1"
MANIFEST = "manifest.json"
UNIT_MANIFEST = "assets/generated/sprites/manifests/units.json"
REFERENCE = "design/reference/tactical-ui-style-board.png"
DS_PATH = "ui/theme/ds.gd"


class ArtError(Exception):
    """Safe, locally authored diagnostic; never contains an API response."""


def sha256(path):
    return hashlib.sha256(Path(path).read_bytes()).hexdigest()


def section(text, heading, next_heading):
    try:
        return text.split(heading, 1)[1].split(next_heading, 1)[0].strip()
    except IndexError:
        raise ArtError(f"Required source heading missing: {heading}") from None


def quoted(text):
    return " ".join(line[2:].strip() for line in text.splitlines() if line.startswith("> "))


def read_palette(root=ROOT):
    text = (root / DS_PATH).read_text()
    tokens = dict(re.findall(r'const (\w+)\s*:?=\s*Color\("(#[0-9A-Fa-f]{6})"\)', text))
    wheel = [dict(zip(("id", "color", "glow"), match)) for match in re.findall(
        r'\{"id":\s*"(\w+)"[^\n]+?"color": Color\("(#[0-9A-Fa-f]{6})"\), '
        r'"glow": Color\("(#[0-9A-Fa-f]{6})"\)', text)]
    colors = list(dict.fromkeys(re.findall(r'Color\("(#[0-9A-Fa-f]{6})"\)', text)))
    if not colors or len(wheel) != 10 or not {"PARCHMENT", "VOID_0", "STONE_1"} <= tokens.keys():
        raise ArtError("Cannot parse the required palette and Wheel of Ten from ds.gd")
    return tokens, wheel, colors


def provenance(root, path, role):
    if not (root / path).is_file():
        raise ArtError(f"Required input missing: {path}")
    return {"path": path, "sha256": sha256(root / path), "role": role}


def build_plan(seed=298000, model=MODEL, root=ROOT):
    bible = "docs/asset-style-bible.md"
    if not (root / bible).is_file():
        bible = "docs/art-aesthetics-bible.md"
    style = (root / bible).read_text()
    brief = (root / "art-request.md").read_text()
    tokens, wheel, colors = read_palette(root)
    roster = section((root / "globals/game_state.gd").read_text(),
                     "func recruitable_candidates()", "func protagonist()")
    ids = re.findall(r'_make_member\(\s*"([a-z-]+)"', roster)
    units = {row["presentation_id"]: row for row in json.loads((root / UNIT_MANIFEST).read_text())["assets"]}
    if len(ids) != 6 or len(set(ids)) != 6 or any(key not in units for key in ids):
        raise ArtError("First batch requires exactly the six existing companions in the unit manifest")
    portrait_template = quoted(section(style, "**Portrait**", "**Steam capsule**"))
    capsule_template = quoted(section(style, "**Steam capsule**", "### Acceptance"))
    lighting = section(style, "**Lighting:**", "**Palette**")
    palette_prose = section(style, "**Palette**", "**Character design language**")
    # Keep the Bible's lighting and palette prose intact; DS supplies every hex.
    preamble = ("Gothic mythopunk. Semi-realistic painterly digital illustration. "
                "Lighting: " + lighting + "\nPalette " + palette_prose)
    shared = ("\nUse only these DS palette colors: " + ", ".join(colors) + ". "
              "Image 1 is a material and lighting reference only, never a layout or subject reference. "
              "Do not copy any text, obsolete element labels, controller glyphs, or UI from it. "
              "No emoji, text, watermark, frame, or UI. No cartoon proportions, black sticker outlines, "
              "neon, glossy plastic, or steampunk gears.")
    board = provenance(root, REFERENCE, "material and lighting style; no layout")
    files = []
    for index, key in enumerate(ids):
        unit = units[key]
        subject_brief = section(brief, "### " + unit["display_name"], "\n##")
        # Part III explicitly takes precedence over the older character brief.
        corrections = ""
        for marker, heading in [("Kes'reth", "### Kes'reth"), ("Kaan", "### Kaan"),
                                ("Orthos", "### Orthos"), ("Vael", "### Vael")]:
            if marker in subject_brief:
                corrections = "\nAuthor's later race direction (overrides older brief and reference anatomy): " + section(style, heading, "\n### ")
        prompt = portrait_template.replace("{Part I unit preamble}", preamble).replace(
            "{SUBJECT}", unit["display_name"] + ". Existing character brief: " + subject_brief + corrections)
        prompt += shared + (" Image 2 shows this exact existing companion, not a new character. "
                            "Retain recognizable costume and identity, subject to the later race direction. "
                            "Head and shoulders only, keep the whole head within the canvas with a small margin. "
                            "For image transport only: if real alpha is unavailable, use a perfectly uniform "
                            + wheel[9]["glow"] + " matte background for removal; never draw a checkerboard.")
        files.append({"path": f"portraits/{key}.png", "asset_class": "portraits", "subject_id": key,
                      "subject": unit["display_name"], "prompt": prompt, "seed": seed + index,
                      "model": model, "size": [512, 512], "aspect_ratio": "1:1", "image_size": "1K",
                      "matte": wheel[9]["glow"], "references": [board, provenance(
                          root, unit["output_paths"][0], "existing companion identity")], "status": "planned"})
    scene = quoted(section((root / "docs/steam-store-page.md").read_text(), "## 7. Capsule brief", "\n---"))
    if not scene:
        raise ArtError("Steam capsule scene brief is missing")
    prompt = capsule_template.replace("{Part I unit preamble}", preamble).replace("{SCENE}", scene).replace(
        "{upper third | left third}", "upper third") + shared
    files.append({"path": "steam-capsule/soul-meter.png", "asset_class": "steam-capsule",
                  "subject": "Soul Meter capsule background", "prompt": prompt, "seed": seed + 6,
                  "model": model, "size": [1920, 620], "aspect_ratio": "21:9", "image_size": "2K",
                  "references": [board], "status": "planned"})
    sources = [provenance(root, path, "prompt/palette/subject source") for path in
               [bible, DS_PATH, UNIT_MANIFEST, "art-request.md", "globals/game_state.gd", "docs/steam-store-page.md"]]
    return {"schema_version": 1, "batch": "298-first-batch", "approval": "pending_owner_review",
            "usage": "Review only. Owner approval required before merge or game use.",
            "style_bible": bible, "model_documentation": MODEL_DOC, "model_verified_on": "2026-10-09",
            "seed_note": "Seed is sent as generationConfig.seed; remote outputs are not guaranteed byte-identical.",
            "palette_source": DS_PATH, "palette": colors, "sources": sources,
            "api_calls": 0, "files": files}


def make_request(asset, root=ROOT):
    parts = [{"text": asset["prompt"]}]
    for ref in asset["references"]:
        parts.append({"inlineData": {"mimeType": "image/png", "data": base64.b64encode(
            (root / ref["path"]).read_bytes()).decode("ascii")}})
    return {"contents": [{"role": "user", "parts": parts}], "generationConfig": {
        "seed": asset["seed"], "responseModalities": ["IMAGE"],
        "imageConfig": {"aspectRatio": asset["aspect_ratio"], "imageSize": asset["image_size"]}}}


class NoRedirect(urllib.request.HTTPRedirectHandler):
    def redirect_request(self, req, fp, code, msg, headers, newurl):
        raise ArtError("Gemini returned a redirect; credentials were not forwarded")


def generate(asset, api_key, timeout, root=ROOT):
    request = urllib.request.Request(
        f"https://generativelanguage.googleapis.com/v1beta/models/{asset['model']}:generateContent",
        data=json.dumps(make_request(asset, root)).encode(),
        headers={"Content-Type": "application/json", "x-goog-api-key": api_key}, method="POST")
    try:
        with urllib.request.build_opener(NoRedirect).open(request, timeout=timeout) as response:
            result = json.load(response)
    except urllib.error.HTTPError as error:
        raise ArtError(f"Gemini HTTP {error.code}; no automatic retry; response body withheld") from None
    except (OSError, ValueError):
        raise ArtError("Gemini transport/JSON failure; no automatic retry; remote details withheld") from None
    return decode_image(result)


def decode_image(result):
    images = []
    for candidate in result.get("candidates", []):
        for part in candidate.get("content", {}).get("parts", []):
            inline = part.get("inlineData", {})
            if not part.get("thought") and inline.get("mimeType", "").startswith("image/"):
                images.append(inline.get("data", ""))
    if len(images) != 1:
        raise ArtError("Gemini did not return exactly one final image; response text withheld")
    try:
        data = base64.b64decode(images[0], validate=True)
        with Image.open(io.BytesIO(data)) as picture:
            picture.verify()
        return data
    except (ValueError, OSError):
        raise ArtError("Gemini returned invalid image data") from None


def remove_matte(image, matte):
    image = image.convert("RGBA")
    if image.getchannel("A").getextrema()[0] < 255:
        return image, "native alpha"
    # Flood only edge-connected matte; internal eyes/jewelry retain their color.
    rgb = tuple(bytes.fromhex(matte[1:]))
    difference = ImageChops.difference(image.convert("RGB"), Image.new("RGB", image.size, rgb))
    channels = difference.split()
    distance = ImageChops.lighter(ImageChops.lighter(channels[0], channels[1]), channels[2])
    mask = distance.point(lambda value: 255 if value > 48 else 0)
    padded = ImageOps.expand(mask, 1, fill=0)
    ImageDraw.floodfill(padded, (0, 0), 128)
    background = padded.crop((1, 1, image.width + 1, image.height + 1))
    alpha = background.point(lambda value: 0 if value == 128 else 255)
    if alpha.getextrema() != (0, 255):
        raise ArtError("Portrait has no usable alpha or edge-connected matte; inspect source before retrying")
    image.putalpha(alpha)
    return image, "edge-connected DS matte removed (RGB tolerance 48)"


def clamp_palette(image, colors):
    palette = Image.new("P", (1, 1))
    values = [channel for color in colors for channel in bytes.fromhex(color[1:])]
    values += values[:3] * (256 - len(colors))
    palette.putpalette(values)
    output = image.convert("RGB").quantize(palette=palette, dither=Image.Dither.NONE).convert("RGBA")
    output.putalpha(image.getchannel("A"))
    return output


def process_image(data, asset, colors):
    with Image.open(io.BytesIO(data)) as original:
        image = ImageOps.exif_transpose(original).convert("RGBA")
    metadata = {"source_size": list(image.size), "palette_clamp": "ds.gd RGB, no dithering, after resize"}
    if asset["asset_class"] == "portraits":
        image, metadata["alpha"] = remove_matte(image, asset["matte"])
        box = image.getchannel("A").getbbox()
        if box is None:
            raise ArtError("Portrait is empty")
        metadata["crop_box"] = list(box)
        image = image.crop(box)
        image.thumbnail((asset["size"][0] - 32, asset["size"][1] - 32), Image.Resampling.LANCZOS)
        canvas = Image.new("RGBA", asset["size"], (0, 0, 0, 0))
        canvas.paste(image, ((canvas.width - image.width) // 2, canvas.height - image.height))
        image = canvas
    else:
        # Widest Steam hero crop; retain the upper-third wordmark space.
        target_ratio = asset["size"][0] / asset["size"][1]
        width, height = image.size
        crop_w, crop_h = min(width, round(height * target_ratio)), min(height, round(width / target_ratio))
        box = ((width - crop_w) // 2, 0, (width + crop_w) // 2, crop_h)
        metadata["crop_box"] = list(box)
        image = image.crop(box).resize(asset["size"], Image.Resampling.LANCZOS)
    return clamp_palette(image, colors), metadata


def write_manifest(output, manifest):
    temporary = output / (MANIFEST + ".tmp")
    temporary.write_text(json.dumps(manifest, indent=2, ensure_ascii=False) + "\n")
    temporary.replace(output / MANIFEST)


def contact_sheet(output, manifest):
    tokens, _, _ = read_palette()
    sheet = Image.new("RGB", (1056, 1070), tokens["VOID_0"])
    draw = ImageDraw.Draw(sheet)
    font = ImageFont.truetype(str(ROOT / "assets/fonts/soul-meter/Cinzel-Regular.ttf"), 17) if (
        ROOT / "assets/fonts/soul-meter/Cinzel-Regular.ttf").is_file() else ImageFont.load_default(size=17)
    draw.text((18, 12), "BATCH 298 / OWNER REVIEW PENDING", font=font, fill=tokens["PARCHMENT"])
    for index, asset in enumerate(manifest["files"]):
        if asset["status"] != "generated":
            continue
        with Image.open(output / asset["path"]) as image:
            if index < 6:
                x, y = 16 + (index % 3) * 348, 48 + (index // 3) * 356
                draw.rectangle((x, y, x + 332, y + 320), fill=tokens["STONE_1"])
                preview = ImageOps.contain(image, (320, 320), Image.Resampling.LANCZOS)
                sheet.paste(preview, (x + (332 - preview.width) // 2, y), preview)
                draw.text((x + 4, y + 326), asset["subject"], font=font, fill=tokens["PARCHMENT"])
            else:
                preview = ImageOps.contain(image, (1024, 290), Image.Resampling.LANCZOS)
                sheet.paste(preview, ((sheet.width - preview.width) // 2, 764), preview)
                draw.text((18, 1045), "STEAM CAPSULE / TITLE COMPOSITING DEFERRED", font=font, fill=tokens["PARCHMENT"])
    sheet.save(output / "contact-sheet.png")


def run(args):
    if not re.fullmatch(r"[a-z0-9][a-z0-9.-]+", args.model):
        raise ArtError("Invalid model id")
    if not 0 <= args.seed <= 2147483641 or args.timeout <= 0:
        raise ArtError("Seed must be 0..2147483641 and timeout must be positive")
    plan = build_plan(args.seed, args.model)
    output = args.output_dir.resolve()
    manifest_path = output / MANIFEST
    if args.dry_run:
        output.mkdir(parents=True, exist_ok=True)
        (output / "manifest.dry-run.json").write_text(json.dumps(plan, indent=2, ensure_ascii=False) + "\n")
        print(f"Dry run: 7 planned images, 0 API calls. {output / 'manifest.dry-run.json'}")
        return
    if manifest_path.exists():
        if not args.resume:
            raise ArtError("Batch exists; use --resume to keep finished files, or a new --output-dir")
        manifest = json.loads(manifest_path.read_text())
        if manifest["sources"] != plan["sources"] or manifest["palette"] != plan["palette"]:
            raise ArtError("Batch inputs changed; use a new --output-dir")
        for previous, current in zip(manifest["files"], plan["files"], strict=True):
            if any(previous.get(key) != current.get(key) for key in
                   ["path", "prompt", "seed", "model", "references", "size", "aspect_ratio", "image_size"]):
                raise ArtError("Batch configuration changed; use a new --output-dir")
    else:
        if output.exists() and any(path.name != "manifest.dry-run.json" for path in output.iterdir()):
            raise ArtError("Output directory contains untracked art; choose a new --output-dir")
        manifest = plan
        output.mkdir(parents=True, exist_ok=True)
    (output / ".gdignore").write_text("Review-only art; owner approval required before game integration.\n")
    write_manifest(output, manifest)
    calls_before = manifest["api_calls"]
    try:
        for asset in manifest["files"]:
            target = output / asset["path"]
            if asset["status"] == "generated":
                if not target.is_file() or sha256(target) != asset["sha256"]:
                    raise ArtError("Finished asset changed; refusing to overwrite or spend another API call")
                continue
            source_path = output / ".sources" / asset["path"]
            if source_path.exists():
                if sha256(source_path) != asset.get("source_sha256"):
                    raise ArtError("Saved source hash mismatch; refusing to reuse it")
                data = source_path.read_bytes()
            else:
                key = os.environ.get("GEMINI_API_KEY")
                if not key:
                    raise ArtError("GEMINI_API_KEY is not available; configure it in the launching environment")
                asset["status"] = "requesting"
                manifest["api_calls"] += 1
                write_manifest(output, manifest)
                print(f"Generating {asset['path']}", flush=True)
                data = generate(asset, key, args.timeout)
                source_path.parent.mkdir(parents=True, exist_ok=True)
                source_path.write_bytes(data)
                asset["source_path"] = source_path.relative_to(output).as_posix()
                asset["source_sha256"] = sha256(source_path)
                asset["status"] = "received"
                write_manifest(output, manifest)
            image, metadata = process_image(data, asset, manifest["palette"])
            target.parent.mkdir(parents=True, exist_ok=True)
            image.save(target)
            asset.update(status="generated", sha256=sha256(target), postprocess=metadata)
            asset.pop("error", None)
            write_manifest(output, manifest)
        contact_sheet(output, manifest)
        manifest["contact_sheet"] = "contact-sheet.png"
        write_manifest(output, manifest)
    except ArtError as error:
        asset["error"] = str(error)
        write_manifest(output, manifest)
        raise
    finally:
        print(f"API calls this run: {manifest['api_calls'] - calls_before}; batch total: {manifest['api_calls']}")
    print(f"Seven assets ready for owner review: {output / 'contact-sheet.png'}")


def main():
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("--dry-run", action="store_true", help="Write manifest.dry-run.json; never call the API")
    parser.add_argument("--resume", action="store_true", help="Skip verified finished images; reuse saved sources")
    parser.add_argument("--output-dir", type=Path, default=ROOT / "assets/generated-art")
    parser.add_argument("--seed", type=int, default=298000)
    parser.add_argument("--model", default=MODEL)
    parser.add_argument("--timeout", type=int, default=180)
    args = parser.parse_args()
    try:
        run(args)
    except (ArtError, OSError, ValueError) as error:
        # Only our diagnostics may be printed. OS/remote exception strings can contain secrets.
        print(f"gen_art: {error if isinstance(error, ArtError) else 'Local file/configuration failure'}", file=sys.stderr)
        return 1
    return 0


if __name__ == "__main__":
    sys.exit(main())
