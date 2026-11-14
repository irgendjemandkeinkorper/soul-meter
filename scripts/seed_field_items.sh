#!/usr/bin/env bash
set -euo pipefail

# Same temporary-autoload path as seed_town_npcs.sh, scoped to the accepted
# field-item packet. Always restore project.godot, including on failure.
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

run_tool "FieldItemSeed" "res://tools/seed_field_items.gd" \
	"FIELD-ITEM-SEED: 18 accepted field items present\\."
run_tool "FieldItemGenerator" "res://tools/generate_gloot.gd" \
	"DATA-GEN: wrote 40 item prototypes, [0-9]+ vendors, [0-9]+ encounters, and [0-9]+ Dom NPCs\\."
