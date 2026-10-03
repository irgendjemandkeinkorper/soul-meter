#!/usr/bin/env python3
"""One-shot Wave 3c migration; run from any directory with --apply.

Only authored layout fields change. Instanced asset internals, sprite offsets,
scales, and DoorSprite overrides stay intact. Wall polygons are rebuilt around
the enlarged floor with their original 48/96 pixel thickness. Refuses a second
application. NPC data is regenerated separately by generate_gloot.gd.
"""

import argparse
from pathlib import Path
import re

ROOT = Path(__file__).resolve().parents[1]
NUMBER = r"-?\d+(?:\.\d+)?(?:[eE][+-]?\d+)?"
SECTIONS = re.compile(r"(?=^\[)", re.MULTILINE)


def doubled(value: str) -> str:
    return re.sub(NUMBER, lambda match: format(float(match[0]) * 2, ".12g"), value)


def scale_field(line: str) -> str:
    key, separator, value = line.partition(" = ")
    if not separator:
        return line
    if key in ("position", "size", "camera_bounds", "polygon", "points", "local_waypoints"):
        # Only numbers inside constructors, never the 2 in Vector2/Rect2i.
        return key + separator + re.sub(r"\(([^()]*)\)", lambda m: "(" + doubled(m[1]) + ")", value)
    if key.startswith("offset_") or key in ("limit_left", "limit_top", "limit_right", "limit_bottom"):
        return key + separator + doubled(value)
    return line


def scale_scene(source: str) -> str:
    sections = SECTIONS.split(source)
    floor_bounds = None
    for section in sections:
        if section.startswith('[node name="Floor"'):
            match = re.search(r"^polygon = PackedVector2Array\((.*?)\)", section, re.MULTILINE)
            values = [float(n) * 2 for n in match[1].split(",")]
            floor_bounds = (min(values[::2]), min(values[1::2]), max(values[::2]), max(values[1::2]))
    result = []
    for section in sections:
        header = section.split("\n", 1)[0]
        if header.startswith('[node name="DoorSprite"'):
            result.append(section)
            continue
        lines = section.splitlines(keepends=True)
        is_node = header.startswith("[node ")
        is_rectangle = header.startswith('[sub_resource type="RectangleShape2D"')
        if is_node or is_rectangle:
            lines = [scale_field(line) if is_node or line.startswith("size = ") else line for line in lines]
        section = "".join(lines)
        name = re.search(r'^\[node name="([^"]+)"', header)
        if name and name[1] in ("WallTop", "BackWall", "WallBottom", "WallLeft", "WallRight"):
            if floor_bounds is None:
                raise ValueError("Wall override without authored Floor requires explicit bounds")
            left, top, right, bottom = floor_bounds
            rectangles = {
                "WallTop": (left - 48, top - 96, right + 48, top),
                "BackWall": (left - 48, top - 96, right + 48, top),
                "WallBottom": (left - 48, bottom, right + 48, bottom + 48),
                "WallLeft": (left - 48, top, left, bottom),
                "WallRight": (right, top, right + 48, bottom),
            }
            x0, y0, x1, y1 = rectangles[name[1]]
            polygon = ", ".join(format(n, ".12g") for n in (x0, y0, x1, y0, x1, y1, x0, y1))
            section = re.sub(r"^polygon = .*", "polygon = PackedVector2Array(" + polygon + ")", section, flags=re.MULTILINE)
        result.append(section)
    return "".join(result)


def migration() -> dict[Path, str]:
    base = ROOT / "world/interiors/building_interior.tscn"
    if "polygon = PackedVector2Array(0, 0, 960, 0, 960, 640, 0, 640)" not in base.read_text():
        raise ValueError("Expected pre-Wave-3c floor; refusing to scale twice")
    changes = {path: scale_scene(path.read_text()) for path in sorted(base.parent.glob("*.tscn"))}
    for path in sorted((ROOT / "actors/building_door/transitions").glob("*_enter.tres")):
        source = path.read_text()
        if 'destination_scene = "res://world/interiors/' in source:
            changes[path] = re.sub(
                r"^(destination_spawn_position = Vector2)\((.*?)\)",
                lambda match: match[1] + "(" + doubled(match[2]) + ")", source, flags=re.MULTILINE,
            )
    return changes


def main() -> None:
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("--apply", action="store_true", help="write migration (default: list files only)")
    args = parser.parse_args()
    changes = migration()
    for path, source in changes.items():
        if source != path.read_text():
            if args.apply:
                path.write_text(source)
            print(path.relative_to(ROOT))


if __name__ == "__main__":
    main()
