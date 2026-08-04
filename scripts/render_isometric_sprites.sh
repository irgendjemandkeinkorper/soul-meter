#!/usr/bin/env bash
set -euo pipefail

# The renderer is a temporary autoload, matching tools/generate_gloot.gd's
# one-way generator convention. A real display is required: headless Godot
# cannot rasterize the SubViewport.
cd "$(dirname "$0")/.."

project_file="project.godot"
godot_bin="${GODOT_BIN:-godot}"
display="${DISPLAY:-:0}"
project_backup="$(mktemp)"
log_file="$(mktemp)"

cleanup() {
	cp "$project_backup" "$project_file"
	rm -f "$project_backup" "$log_file"
}
trap cleanup EXIT

cp "$project_file" "$project_backup"
if ! grep -Eq '^Pandora=' "$project_file"; then
	echo "Pandora autoload is missing from $project_file." >&2
	exit 1
fi
sed -i '/^Pandora=/a IsometricSpriteGenerator="*res://tools/render_isometric_sprites.gd"' "$project_file"

DISPLAY="$display" "$godot_bin" --path . --quit-after 72000 2>&1 | tee "$log_file"

if ! grep -Eq 'ISO-SPRITE-GEN: complete\.' "$log_file"; then
	echo "Isometric sprite generation did not complete successfully." >&2
	exit 1
fi
