#!/usr/bin/env bash
set -euo pipefail

# The Weftlumin `pr` verb's overlap scan, runnable on its own (#352): refuses (exit 3) when a file
# the package would bake is also changed by an open PR. A dry run: no worktree, push or PR.
# usage: scripts/weftlumin_overlap_check.sh [package_dir]   (needs an authenticated `gh`)
godot_bin="${GODOT_BIN:-godot}"
package="${1:-test/fixtures/weftlumin/dom_scene_bake}"
work_dir="$(mktemp -d)"
trap 'rm -rf "$work_dir"' EXIT

gh pr list --state open --limit 200 --json number,title,headRefName,files > "$work_dir/open_prs.json"
XDG_DATA_HOME="$work_dir/xdg" "$godot_bin" --headless --path . \
	--script addons/weftlumin/tools/weftlumin.gd -- pr "$package" \
	--open-prs "$work_dir/open_prs.json" > "$work_dir/pr.log" 2>&1 || true
result="$(grep -E '^WEFTLUMIN: ' "$work_dir/pr.log" | tail -1 || true)"
echo "${result:-WEFTLUMIN: pr <no result line>}"
case "$result" in
	"WEFTLUMIN: pr ok exit=0") exit 0 ;;
	"WEFTLUMIN: pr refused_overlap exit=3")
		grep -E '^WEFTLUMIN-REPORT ' "$work_dir/pr.log" | sed 's/^WEFTLUMIN-REPORT //' \
			| python3 -c 'import json,sys; [print("overlap:", o) for o in json.load(sys.stdin).get("refused_overlap", [])]'
		exit 3 ;;
	*) cat "$work_dir/pr.log" >&2; exit 1 ;;
esac
