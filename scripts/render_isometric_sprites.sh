#!/usr/bin/env bash
set -euo pipefail

# The renderer is a temporary autoload, matching tools/generate_gloot.gd's
# one-way generator convention. Normal generation needs a real display because
# headless Godot cannot rasterize the SubViewport. Drift checks do not render.
# SOUL_METER_REUSE_EXISTING_RENDERS=1 verifies/reuses the committed display
# renders and CPU-rasterizes only Mini Characters, so it is also headless-safe.
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

godot_args=(--path . --quit-after 72000)
if [[ "${SOUL_METER_DRIFT_CHECK:-0}" == "1" || "${SOUL_METER_REUSE_EXISTING_RENDERS:-0}" == "1" ]]; then
	godot_args=(--headless "${godot_args[@]}")
	"$godot_bin" "${godot_args[@]}" 2>&1 | tee "$log_file"
else
	DISPLAY="$display" "$godot_bin" "${godot_args[@]}" 2>&1 | tee "$log_file"
fi

expected_message='ISO-SPRITE-GEN: complete\.'
if [[ "${SOUL_METER_DRIFT_CHECK:-0}" == "1" ]]; then
	expected_message='ISO-SPRITE-GEN: no drift\.'
fi
if ! grep -Eq "$expected_message" "$log_file"; then
	echo "Isometric sprite generation did not complete successfully." >&2
	exit 1
fi
