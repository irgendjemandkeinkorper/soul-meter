#!/usr/bin/env bash
set -euo pipefail

usage() {
	echo "Usage: scripts/build_playtest.sh [--allow-dirty] [--output-dir PATH]"
	echo "Builds and smoke-checks the Linux Gate T playtest artifact."
}

script_dir="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
repo_root="$(cd "$script_dir/.." && pwd)"
godot_bin="${GODOT_BIN:-godot}"
output_dir="${SOUL_METER_PLAYTEST_DIR:-$repo_root/build/playtest/linux}"
smoke_seconds="${SOUL_METER_PLAYTEST_SMOKE_SECONDS:-8}"
allow_dirty=0

while [[ $# -gt 0 ]]; do
	case "$1" in
		--allow-dirty)
			allow_dirty=1
			shift
			;;
		--output-dir)
			if [[ $# -lt 2 ]]; then
				echo "PLAYTEST BUILD: --output-dir requires a path" >&2
				exit 2
			fi
			output_dir="$2"
			shift 2
			;;
		-h|--help)
			usage
			exit 0
			;;
		*)
			echo "PLAYTEST BUILD: unknown argument: $1" >&2
			usage >&2
			exit 2
			;;
	esac
done

if [[ "$output_dir" != /* ]]; then
	output_dir="$repo_root/$output_dir"
fi

cd "$repo_root"
workspace_state="$(git status --porcelain --untracked-files=normal)"
tree_state="clean"
if [[ -n "$workspace_state" ]]; then
	tree_state="dirty"
	if [[ "$allow_dirty" -ne 1 ]]; then
		echo "PLAYTEST BUILD: refusing a dirty official artifact." >&2
		echo "Commit/stash the worktree, or use --allow-dirty for local verification only." >&2
		exit 1
	fi
fi

mkdir -p "$output_dir"
acceptance_log="$output_dir/acceptance.log"
export_log="$output_dir/export.log"
smoke_log="$output_dir/smoke.log"
executable="$output_dir/SoulMeter.x86_64"
pck="$output_dir/SoulMeter.pck"

echo "PLAYTEST BUILD: strict acceptance"
SOUL_METER_LOCALE_STRICT=1 GODOT_BIN="$godot_bin" \
	bash scripts/acceptance_gate.sh | tee "$acceptance_log"

echo "PLAYTEST BUILD: Linux release export"
if ! "$godot_bin" --headless --path . --export-release "Linux/X11" "$executable" \
	> "$export_log" 2>&1; then
	echo "PLAYTEST BUILD: export failed; tail follows" >&2
	tail -n 80 "$export_log" >&2
	exit 1
fi
if [[ ! -x "$executable" || ! -s "$pck" ]]; then
	echo "PLAYTEST BUILD: export did not produce both executable and pack" >&2
	exit 1
fi

echo "PLAYTEST BUILD: exported-binary smoke boot"
smoke_data_dir="$(mktemp -d /tmp/soul-meter-playtest-smoke.XXXXXX)"
trap 'rm -rf "$smoke_data_dir"' EXIT
set +e
env XDG_DATA_HOME="$smoke_data_dir" timeout "${smoke_seconds}s" \
	"$executable" --headless > "$smoke_log" 2>&1
smoke_status=$?
set -e
if [[ "$smoke_status" -ne 124 ]]; then
	echo "PLAYTEST BUILD: executable exited during the smoke window (status $smoke_status)" >&2
	tail -n 80 "$smoke_log" >&2
	exit 1
fi
if rg -n "SCRIPT ERROR|^ERROR:" "$smoke_log"; then
	echo "PLAYTEST BUILD: executable emitted runtime errors" >&2
	exit 1
fi

commit_sha="$(git rev-parse HEAD)"
godot_version="$($godot_bin --version | head -n 1)"
created_utc="$(date -u +%Y-%m-%dT%H:%M:%SZ)"
acceptance_report="$(ls -dt reports/report_* 2>/dev/null | head -n 1)/results.xml"
gate_t_valid="yes"
if [[ "$tree_state" != "clean" ]]; then
	gate_t_valid="no — local verification build only"
	printf '%s\n' "$workspace_state" > "$output_dir/BUILD-DIRTY-STATUS.txt"
fi

(
	cd "$output_dir"
	sha256sum SoulMeter.x86_64 SoulMeter.pck > SHA256SUMS
)

{
	echo "Soul Meter Gate T playtest build"
	echo "created_utc=$created_utc"
	echo "commit_sha=$commit_sha"
	echo "worktree=$tree_state"
	echo "valid_for_gate_t=$gate_t_valid"
	echo "godot=$godot_version"
	echo "preset=Linux/X11"
	echo "acceptance_report=$acceptance_report"
	echo "smoke_seconds=$smoke_seconds"
	echo "verification=sha256sum -c SHA256SUMS"
} > "$output_dir/BUILD-MANIFEST.txt"

echo "PLAYTEST BUILD: complete"
echo "PLAYTEST BUILD: artifact directory: $output_dir"
echo "PLAYTEST BUILD: Gate T valid: $gate_t_valid"
