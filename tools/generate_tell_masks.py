#!/usr/bin/env python3
"""Regenerate #445 idle/SE tell masks. Requires Python 3 and Pillow.

Run from any directory: python3 tools/generate_tell_masks.py [--check]
Optional: --preview PATH writes a CPU reference sheet, not rendered QA evidence.
Coordinates trace the existing 256px rasters, in their unchanged canvas space.
Only visible eyes and claws (or tusks/maw teeth) are selected. Armor, weapons,
horns, decorative skulls, body glow and background are deliberately excluded.
The guard exposes only its eye slit; do not invent claws on its gauntlets.

These definitions cover idle/SE/frame 0 only. A changed source or another frame
needs a fresh trace; source hashes prevent silently applying stale coordinates.
No source sprite, import setting, tint color, shader or pivot is changed.
"""

import argparse
import hashlib
import re
from pathlib import Path

from PIL import Image, ImageChops, ImageDraw, ImageFont

ROOT = Path(__file__).resolve().parents[1]
SPRITES = ROOT / "assets/generated/sprites/units"

# Polygon vertices are source-pixel coordinates; group names document anatomy.
TRACES = {
    "bog-wight": {
        "source_sha256": "a24e3064ebaa35fa4babf19f66c46b001e2779ccc40a0caa7ca17a138661585b",
        "parts": {
            "eyes": [
                [(150, 37), (153, 37), (153, 39), (151, 40), (150, 39)],
                [(161, 36), (162, 36), (162, 39), (161, 40)],
            ],
            "hand claw tips": [
                [(87, 152), (89, 153), (90, 158), (89, 160), (88, 155)],
                [(80, 162), (82, 163), (84, 166), (88, 168), (86, 169), (82, 167)],
                [(75, 164), (77, 165), (79, 169), (83, 172), (81, 173), (77, 170)],
                [(177, 141), (178, 142), (177, 146), (174, 149), (174, 147)],
                [(179, 143), (181, 143), (180, 149), (177, 153), (176, 154), (178, 149)],
                [(173, 143), (174, 144), (173, 147), (171, 149), (172, 145)],
            ],
        },
    },
    "loam-maddened-boar": {
        "source_sha256": "f29663e911fa275457a9fa18640a2561934e91a4545a8ad5d798f67a6aadbb0d",
        "parts": {
            "visible eye": [[(179, 147), (181, 147), (183, 149), (182, 151), (180, 150)]],
            "tusks": [
                [(182, 166), (180, 173), (179, 180), (180, 187), (185, 195),
                 (184, 200), (180, 199), (176, 193), (175, 183), (176, 177), (180, 168)],
                [(193, 180), (194, 181), (194, 189), (192, 195), (188, 197),
                 (187, 194), (190, 191), (192, 186)],
                [(238, 155), (241, 161), (243, 168), (243, 177), (241, 185),
                 (237, 190), (232, 190), (228, 188), (233, 183), (237, 176),
                 (239, 169), (240, 164)],
                [(226, 172), (226, 180), (229, 188), (226, 190), (223, 183), (224, 177)],
                [(233, 193), (238, 194), (242, 192), (245, 189), (243, 194),
                 (240, 197), (236, 198), (233, 197)],
            ],
        },
    },
    "gnaal-breach-hound": {
        "source_sha256": "734aa4d61efdb3f9cfffa9262f09310939b9b78688e6013fed71018e26f55781",
        "parts": {
            "visible eye": [[(187, 132), (189, 132), (190, 133), (190, 134), (187, 134)]],
            "paw claw tips": [
                [(146, 226), (148, 227), (149, 233), (147, 232)],
                [(150, 228), (153, 229), (154, 238), (152, 235)],
                [(156, 228), (159, 229), (161, 239), (158, 235)],
                [(163, 225), (165, 226), (168, 232), (166, 231)],
                [(178, 203), (180, 203), (183, 210), (180, 208)],
                [(184, 204), (186, 204), (190, 214), (187, 210)],
                [(190, 201), (193, 201), (198, 209), (195, 208)],
                [(49, 191), (51, 191), (52, 199), (50, 196)],
                [(54, 190), (56, 190), (58, 196), (56, 195)],
                [(59, 188), (61, 189), (64, 194), (61, 193)],
                [(99, 171), (101, 172), (103, 179), (101, 177)],
                [(104, 172), (106, 173), (108, 180), (105, 177)],
                [(109, 171), (111, 171), (115, 176), (112, 175)],
            ],
            "maw teeth": [
                [(188, 148), (189, 148), (189, 152)],
                [(190, 152), (192, 153), (192, 157)],
                [(197, 159), (199, 159), (198, 165), (197, 167), (197, 163)],
            ],
        },
    },
    "gnaal-rift-scavenger": {
        "source_sha256": "c3bf20ac9838ad692622d205f79947c18e326baef3bfe25afd1cb0b81f3b0354",
        "parts": {
            "visible eye": [[(170, 67), (173, 67), (175, 68), (174, 70), (170, 70)]],
            "hand claws": [
                [(39, 177), (43, 179), (44, 193), (47, 202), (52, 208),
                 (49, 207), (44, 203), (41, 196), (39, 187)],
                [(47, 178), (49, 180), (49, 188), (53, 193), (61, 198),
                 (60, 199), (54, 196), (49, 192), (46, 186)],
                [(65, 170), (68, 170), (68, 177), (65, 182), (62, 184), (65, 179)],
                [(202, 161), (206, 162), (207, 171), (207, 180), (205, 187),
                 (202, 191), (199, 193), (200, 190), (203, 185), (204, 178), (204, 170)],
                [(193, 162), (197, 162), (198, 169), (198, 179), (195, 186),
                 (191, 190), (187, 190), (190, 187), (194, 180), (194, 172)],
                [(183, 162), (186, 162), (184, 168), (183, 172), (184, 175),
                 (186, 177), (182, 176), (180, 174), (180, 168)],
            ],
            "foot claw tips": [
                [(70, 239), (73, 237), (75, 238), (72, 242), (69, 244)],
                [(81, 238), (84, 239), (85, 246), (82, 243)],
                [(88, 237), (91, 237), (94, 242), (91, 241)],
                [(161, 227), (164, 227), (168, 232), (164, 231)],
                [(169, 226), (172, 226), (177, 230), (173, 229)],
                [(176, 224), (179, 225), (182, 228), (178, 227)],
            ],
        },
    },
    "mustered-bloodbellow": {
        "source_sha256": "1804a48b31a4e5e7001b4771ba3d236685e219fbd8c17bd702dd3f94fd0fe586",
        "parts": {
            "eyes beneath the brow": [
                [(153, 121), (155, 120), (157, 120), (156, 123), (154, 123)],
                [(177, 120), (179, 118), (180, 118), (179, 121), (177, 122)],
            ],
            "maw teeth": [
                [(156, 139), (158, 139), (159, 141), (158, 142), (156, 141)],
                [(160, 142), (162, 142), (162, 144), (160, 143)],
                [(173, 142), (175, 141), (175, 143), (173, 144)],
            ],
        },
    },
    "cleaned-jawbrace-guard": {
        "source_sha256": "3a5850967e64654f782adc51bae85ae53aa32698c46a5d41b1311ae92839e4cd",
        "parts": {
            "eyes through visor slit": [
                [(108, 25), (110, 25), (113, 26), (113, 27), (110, 27), (108, 26)],
                [(117, 26), (119, 26), (121, 27), (124, 26), (124, 27), (121, 28), (118, 28)],
            ],
        },
    },
}


def source_path(archetype):
    return SPRITES / archetype / f"{archetype}--idle--se--f00.png"


def build_mask(archetype, trace):
    path = source_path(archetype)
    if hashlib.sha256(path.read_bytes()).hexdigest() != trace["source_sha256"]:
        raise ValueError(f"{path}: source changed; review and retrace before updating its hash")
    with Image.open(path) as source:
        if source.size != (256, 256) or source.mode != "RGBA":
            raise ValueError(f"{path}: expected a 256x256 RGBA sprite")
        alpha = source.getchannel("A")
        coverage = Image.new("L", source.size, 0)
        draw = ImageDraw.Draw(coverage)
        for polygons in trace["parts"].values():
            for polygon in polygons:
                draw.polygon(polygon, fill=255)
        # RGB is black even in fully transparent pixels. Alpha stays byte-exact;
        # do not multiply coverage by alpha here (the live shader already does).
        coverage = ImageChops.multiply(coverage, alpha.point(lambda a: 255 if a else 0))
        return Image.merge("RGBA", (coverage, coverage, coverage, alpha))


def write_preview(path, masks):
    """Illustrate the shader's RGB mix; GPU/color-space verification stays in Godot."""
    hostile = (ROOT / "actors/hostile/hostile.gd").read_text()
    shader = (ROOT / "actors/hostile/variation_tell.gdshader").read_text()
    strength = float(re.search(r"uniform float tell_strength[^;]*=\s*([\d.]+);", shader)[1])
    colors = {}
    for tier in ("STRONG", "WEAK"):
        components = re.search(rf"EnemyDerived\.Tier\.{tier}: Color\(([^)]+)\)", hostile)[1]
        colors[tier] = [float(value) * 255 for value in components.split(",")]
    sheet = Image.new("RGB", (1600, 1080), "#20252b")
    draw = ImageDraw.Draw(sheet)
    font_path = ROOT / "assets/fonts/soul-meter/FiraCode.ttf"
    font = ImageFont.truetype(str(font_path), 17)
    title_font = ImageFont.truetype(str(font_path), 23)
    draw.text((24, 12), "#445 TELL MASKS | CPU REFERENCE | GODOT CAPTURE PENDING", font=title_font, fill="white")
    draw.text((24, 48), "Existing Hostile colors + shader strength; 256px source frames. Xvfb unavailable in this sandbox.", font=font, fill="#d8dee6")
    for index, (name, mask) in enumerate(masks):
        source = Image.open(source_path(name)).convert("RGBA")
        images = [source]
        for color in colors.values():
            tinted = source.copy()
            src = source.load()
            dst = tinted.load()
            coverage = mask.load()
            for y in range(source.height):
                for x in range(source.width):
                    factor = coverage[x, y][0] / 255 * coverage[x, y][3] / 255 * strength
                    rgb = [round(src[x, y][c] * (1 - factor) + color[c] * factor) for c in range(3)]
                    dst[x, y] = (*rgb, src[x, y][3])
            images.append(tinted)
        origin = (24 + index % 2 * 792, 96 + index // 2 * 316)
        draw.text(origin, name, font=font, fill="white")
        for column, (label, sprite) in enumerate(zip(("TYPICAL / reference", "STRONG / ember", "WEAK / pale"), images)):
            x, y = origin[0] + column * 256, origin[1]
            draw.text((x, y + 25), label, font=font, fill="#d8dee6")
            sheet.paste(sprite, (x, y + 50), sprite)
    draw.text((24, 1050), "Preview only: texture filtering, color-space conversion and in-world readability require the Xvfb capture.", font=font, fill="#d8dee6")
    path.parent.mkdir(parents=True, exist_ok=True)
    sheet.save(path)
    print(f"WROTE CPU reference (not rendered acceptance): {path}")


def main():
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("--check", action="store_true", help="verify masks without rewriting them")
    parser.add_argument("--preview", type=Path, help="write a clearly labeled CPU tint reference PNG")
    args = parser.parse_args()
    # Validate every source before writing any output.
    masks = [(name, build_mask(name, trace)) for name, trace in TRACES.items()]
    failures = []
    for name, mask in masks:
        out = source_path(name).with_name(f"{name}--idle--se--f00--tellmask.png")
        if args.check:
            if not out.is_file():
                failures.append(f"{name}: mask missing")
                continue
            with Image.open(out) as actual:
                if actual.mode != mask.mode or actual.size != mask.size or actual.tobytes() != mask.tobytes():
                    failures.append(f"{name}: mask differs; regenerate")
                    continue
        else:
            mask.save(out)
        count = mask.getchannel("R").histogram()[255]
        print(f"{'OK' if args.check else 'WROTE'} {out.relative_to(ROOT)} ({count} white pixels)")
    if failures:
        raise SystemExit("\n".join(failures))
    if args.preview:
        write_preview(args.preview, masks)


if __name__ == "__main__":
    main()
