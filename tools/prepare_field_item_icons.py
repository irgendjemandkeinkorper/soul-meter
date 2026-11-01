#!/usr/bin/env python3
"""Package the approved generated icons; resize only, then record provenance and QA."""

import argparse
import hashlib
import json
from pathlib import Path
import re

from PIL import Image, ImageDraw, ImageFont


ROOT = Path(__file__).resolve().parents[1]
ICON_DIR = Path("assets/generated/sprites/items")
PROVENANCE = ICON_DIR / "provenance-2026-11-01.json"
CONTACT_SHEET = Path("docs/qa/item-icons-2026-11-01.png")
REFERENCES = [
    "materials/binding_thread",
    "consumables/hearthloaf",
    "tools/field_needle",
    "materials/lamp_oil",
]


def sha256(path):
    return hashlib.sha256(path.read_bytes()).hexdigest()


def icon_path(item_id):
    return ICON_DIR / (item_id.split("/")[1] + "--icon.png")


def main():
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("manifest", type=Path, help="Built-in generator prompts and source paths")
    args = parser.parse_args()
    manifest = json.loads(args.manifest.read_text())
    records = manifest["icons"] if isinstance(manifest, dict) else manifest
    packet = (ROOT / "docs/qa/item-loot-draft-packet-2026-10-31.md").read_text()
    ids = re.findall(r"^\| `([^`]+/[^`]+)` \| [A-Z]", packet, re.MULTILINE)
    assert len(ids) == 18
    by_id = {record["id"]: record for record in records}
    assert len(records) == len(by_id) == 18 and set(by_id) == set(ids)
    icons = []
    # Preflight every source before writing any destination.
    for item_id in ids:
        record = by_id[item_id]
        assert 1 <= record["attempts_used"] <= 2
        source = Path(record["source_path"])
        with Image.open(source) as original:
            assert original.mode == "RGBA", (item_id, original.mode)
            assert original.getchannel("A").getextrema() == (0, 255), item_id
            result = original.resize((256, 256), Image.Resampling.LANCZOS)
            icons.append((record, result, list(original.size)))
    provenance = []
    for record, result, source_size in icons:
        relative = icon_path(record["id"])
        target = ROOT / relative
        result.save(target, format="PNG")
        histogram = result.getchannel("A").histogram()
        assert histogram[0] > 0 and histogram[255] > 0, record["id"]
        provenance.append({
            **record,
            "generator": "codex built-in image generation",
            "path": relative.as_posix(),
            "sha256": sha256(target),
            "source_sha256": sha256(Path(record["source_path"])),
            "source_size": source_size,
            "size": [256, 256],
            "mode": "RGBA",
            "transparent_pixels": histogram[0],
            "opaque_pixels": histogram[255],
            "normalization": "RGBA Lanczos resize to 256x256; no repainting or background removal",
            "status": "draft-for-owner-review",
            "batch": "owner 2026-11-01, 18 icons",
        })
    metadata = {
        "icons": provenance,
        "references": [
            {"id": item_id, "path": icon_path(item_id).as_posix(),
             "sha256": sha256(ROOT / icon_path(item_id))}
            for item_id in REFERENCES
        ],
        "contact_sheet": CONTACT_SHEET.as_posix(),
        "generations_used": sum(record["attempts_used"] for record in records),
    }
    (ROOT / PROVENANCE).write_text(json.dumps(metadata, indent=2, ensure_ascii=False) + "\n")
    contact_sheet(ids)
    print("ICON-BATCH: 18 RGBA PNGs, 256x256, real transparent alpha; provenance and contact sheet written.")
    print("ICON-BATCH: %d generations used." % metadata["generations_used"])


def contact_sheet(ids):
    # The labelled QA sheet is the only composition; game icons remain unlabelled.
    cell_w, cell_h, margin, header = 224, 276, 24, 94
    reference_x = margin + 6 * cell_w + 24
    sheet = Image.new("RGB", (reference_x + 2 * cell_w + margin, header + 3 * cell_h + margin),
                      "#202126")
    draw = ImageDraw.Draw(sheet)
    font_path = "/usr/share/fonts/truetype/dejavu/DejaVuSans.ttf"
    title_font = ImageFont.truetype(font_path, 25)
    label_font = ImageFont.truetype(font_path, 14)
    draw.text((margin, 18), "Soul Meter | approved generation batch | 2026-11-01",
              font=title_font, fill="#eee3cd")
    draw.text((margin, 58), "18 NEW ICONS - DRAFT FOR OWNER REVIEW", font=label_font, fill="#d4b88b")
    draw.text((reference_x, 58), "4 EXISTING STYLE REFERENCES", font=label_font, fill="#d4b88b")
    draw.line((reference_x - 12, 56, reference_x - 12, sheet.height - margin), fill="#68605a")
    for index, item_id in enumerate(ids + REFERENCES):
        new = index < len(ids)
        ordinal = index if new else index - len(ids)
        columns = 6 if new else 2
        x = (margin if new else reference_x) + (ordinal % columns) * cell_w
        y = header + (ordinal // columns) * cell_h
        # A visible checkerboard demonstrates the alpha without altering source icons.
        for tile_y in range(0, 208, 16):
            for tile_x in range(0, 208, 16):
                color = "#35373d" if (tile_x // 16 + tile_y // 16) % 2 else "#292b31"
                draw.rectangle((x + tile_x, y + tile_y, x + tile_x + 15, y + tile_y + 15),
                               fill=color)
        with Image.open(ROOT / icon_path(item_id)) as source:
            icon = source.convert("RGBA").resize((200, 200), Image.Resampling.LANCZOS)
            sheet.paste(icon, (x + 4, y + 4), icon)
        category, slug = item_id.split("/")
        draw.text((x + 4, y + 216), category + "/", font=label_font, fill="#b9b7b3")
        draw.text((x + 4, y + 236), slug, font=label_font, fill="#eee3cd")
    sheet.save(ROOT / CONTACT_SHEET)


if __name__ == "__main__":
    main()
