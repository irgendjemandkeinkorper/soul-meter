#!/usr/bin/env bash
set -euo pipefail

# The generator is an autoload tool, so run it in a temporary project
# configuration. This keeps the checked-in project free of editor-only hooks
# while allowing CI and local pre-commit checks to use the same entrypoint.
project_file="project.godot"
godot_bin="${GODOT_BIN:-godot}"
project_backup="$(mktemp)"
data_dir="$(mktemp -d)"

cleanup() {
	cp "$project_backup" "$project_file"
	rm -f "$project_backup"
	rm -rf "$data_dir"
}
trap cleanup EXIT

cp "$project_file" "$project_backup"
if ! grep -Eq '^Pandora=' "$project_file"; then
	echo "Pandora autoload is missing from $project_file." >&2
	exit 1
fi

run_drift_check() {
	local autoload_name="$1"
	local generator_path="$2"
	local success_pattern="$3"
	local log_file="$data_dir/$autoload_name.log"

	cp "$project_backup" "$project_file"
	sed -i "/^Pandora=/a $autoload_name=\"*$generator_path\"" "$project_file"
	XDG_DATA_HOME="$data_dir/$autoload_name" SOUL_METER_DRIFT_CHECK=1 "$godot_bin" \
		--headless --path . --quit-after 30 2>&1 | tee "$log_file"
	if ! grep -Eq "$success_pattern" "$log_file"; then
		echo "$autoload_name drift check did not complete successfully." >&2
		exit 1
	fi
}

run_drift_check \
	"GeneratorDriftCheck" \
	"res://tools/generate_gloot.gd" \
	"GLOOT-GEN: no drift\."
run_drift_check \
	"CanonSeedDriftCheck" \
	"res://tools/seed_pandora.gd" \
	"^CANON-SEED: no drift\.$"
run_drift_check \
	"IsometricSpriteDriftCheck" \
	"res://tools/render_isometric_sprites.gd" \
	"ISO-SPRITE-GEN: no drift\."
