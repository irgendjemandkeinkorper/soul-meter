#!/usr/bin/env bash
set -euo pipefail

# The generator is an autoload tool, so run it in a temporary project
# configuration. This keeps the checked-in project free of editor-only hooks
# while allowing CI and local pre-commit checks to use the same entrypoint.
project_file="project.godot"
godot_bin="${GODOT_BIN:-godot}"
project_backup="$(mktemp)"
data_dir="$(mktemp -d)"
log_file="$data_dir/drift-check.log"

cleanup() {
	cp "$project_backup" "$project_file"
	rm -f "$project_backup"
	rm -rf "$data_dir"
}
trap cleanup EXIT

cp "$project_file" "$project_backup"
if ! rg -q '^Pandora=' "$project_file"; then
	echo "Pandora autoload is missing from $project_file." >&2
	exit 1
fi
sed -i '/^Pandora=/a GeneratorDriftCheck="*res://tools/generate_gloot.gd"' "$project_file"

XDG_DATA_HOME="$data_dir" SOUL_METER_DRIFT_CHECK=1 "$godot_bin" \
	--headless --path . --quit-after 30 2>&1 | tee "$log_file"

if ! rg -q 'GLOOT-GEN: no drift\.' "$log_file"; then
	echo "Generator drift check did not complete successfully." >&2
	exit 1
fi
