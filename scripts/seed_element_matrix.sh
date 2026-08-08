#!/usr/bin/env bash
set -euo pipefail

# Applies the idempotent element-relation migration (#136), then regenerates
# every Pandora-derived artifact through the project's canonical generator.
# Mirrors scripts/seed_town_npcs.sh.
project_file="project.godot"
godot_bin="${GODOT_BIN:-godot}"
project_backup="$(mktemp)"
run_data_dir="$(mktemp -d)"

cleanup() {
	cp "$project_backup" "$project_file"
	rm -f "$project_backup"
	rm -rf "$run_data_dir"
}
trap cleanup EXIT

cp "$project_file" "$project_backup"
if ! grep -Eq '^Pandora=' "$project_file"; then
	echo "Pandora autoload is missing from $project_file." >&2
	exit 1
fi

run_tool() {
	local autoload_name="$1"
	local script_path="$2"
	local success_pattern="$3"
	local log_file="$run_data_dir/$autoload_name.log"

	cp "$project_backup" "$project_file"
	sed -i "/^Pandora=/a $autoload_name=\"*$script_path\"" "$project_file"
	XDG_DATA_HOME="$run_data_dir/$autoload_name" "$godot_bin" \
		--headless --path . --quit-after 30 2>&1 | tee "$log_file"
	if ! grep -Eq "$success_pattern" "$log_file"; then
		echo "$autoload_name did not complete successfully." >&2
		exit 1
	fi
}

run_tool \
	"ElementMatrixSeed" \
	"res://tools/seed_element_matrix.gd" \
	"ELEMENT-MATRIX-SEED: [0-9]+ element relation rows present\."
run_tool \
	"ElementMatrixGenerator" \
	"res://tools/generate_gloot.gd" \
	"DATA-GEN: wrote [0-9]+ item prototypes, [0-9]+ vendors, [0-9]+ encounters, and [0-9]+ Dom NPCs\."
