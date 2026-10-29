#!/usr/bin/env bash
set -euo pipefail

# Weftlumin CLI checks for CI (#352). Godot can abort at teardown, so every verb is judged by its
# `WEFTLUMIN: <verb> <status> exit=<n>` line (docs/weftlumin.md), never the process exit code.
#   lint    validate + lint the committed fixture package (every PR)
#   replay  apply the fixture log into scratch and bake --write it into res://; the two replay
#           paths must produce byte-identical scenes, then the tree is restored (nightly)
godot_bin="${GODOT_BIN:-godot}"
package="${WEFTLUMIN_PACKAGE:-test/fixtures/weftlumin/dom_scene_bake}"
work_dir="$(mktemp -d)"
trap 'rm -rf "$work_dir"' EXIT

weftlumin() {
	local verb="$1"
	shift
	local log_file="$work_dir/$verb.log"
	XDG_DATA_HOME="$work_dir/xdg" "$godot_bin" --headless --path . \
		--script addons/weftlumin/tools/weftlumin.gd -- "$verb" "$@" > "$log_file" 2>&1 || true
	local result
	result="$(grep -E '^WEFTLUMIN: ' "$log_file" | tail -1 || true)"
	echo "${result:-WEFTLUMIN: $verb <no result line>}"
	if [[ "$result" != "WEFTLUMIN: $verb ok exit=0" ]]; then
		cat "$log_file" >&2
		return 1
	fi
}

case "${1:-}" in
	lint)
		weftlumin validate "$package"
		weftlumin lint "$package"
		;;
	replay)
		scratch="$work_dir/package"
		mkdir -p "$scratch"
		weftlumin apply "$scratch" "$package/commands.jsonl"
		mapfile -t scenes < <(cd "$scratch/scratch" && find . -name '*.tscn' | sed 's|^\./||' | sort)
		if [[ "${#scenes[@]}" -eq 0 ]]; then
			echo "apply wrote no scenes into scratch." >&2
			exit 1
		fi
		restore() { git checkout -q -- "${scenes[@]}"; }
		trap 'restore; rm -rf "$work_dir"' EXIT
		weftlumin bake "$package" --write
		for scene in "${scenes[@]}"; do
			if ! cmp -s "$scratch/scratch/$scene" "$scene"; then
				echo "Replay mismatch: apply and bake --write disagree on $scene." >&2
				diff "$scratch/scratch/$scene" "$scene" >&2 || true
				exit 1
			fi
			echo "Replay match: $scene"
		done
		;;
	*)
		echo "usage: $0 lint|replay" >&2
		exit 2
		;;
esac
