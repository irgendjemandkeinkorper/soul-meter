#!/usr/bin/env bash
set -euo pipefail

usage() {
	echo "Usage: scripts/build_playtest.sh [--target linux|windows] [--allow-dirty] [--skip-acceptance] [--output-dir PATH]"
	echo "Builds and smoke-checks a Gate T playtest artifact (Linux by default)."
	echo "  --target windows   Windows x64 export, shipped as SoulMeter-windows-x86_64.zip"
	echo "  --allow-dirty      build from a dirty worktree (manifest marks it invalid for Gate T)"
	echo "  --skip-acceptance  skip the strict acceptance gate (manifest marks it invalid for Gate T)"
}

script_dir="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
repo_root="$(cd "$script_dir/.." && pwd)"
godot_bin="${GODOT_BIN:-godot}"
target="linux"
output_dir="${SOUL_METER_PLAYTEST_DIR:-}"
smoke_seconds="${SOUL_METER_PLAYTEST_SMOKE_SECONDS:-8}"
allow_dirty=0
skip_acceptance=0

while [[ $# -gt 0 ]]; do
	case "$1" in
		--target)
			if [[ $# -lt 2 ]]; then
				echo "PLAYTEST BUILD: --target requires linux or windows" >&2
				exit 2
			fi
			target="$2"
			shift 2
			;;
		--allow-dirty)
			allow_dirty=1
			shift
			;;
		--skip-acceptance)
			skip_acceptance=1
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

case "$target" in
	linux)
		preset="Linux/X11"
		executable_name="SoulMeter.x86_64"
		;;
	windows)
		preset="Windows Desktop"
		executable_name="SoulMeter.exe"
		;;
	*)
		echo "PLAYTEST BUILD: unknown target: $target (linux or windows)" >&2
		exit 2
		;;
esac

if [[ -z "$output_dir" ]]; then
	output_dir="$repo_root/build/playtest/$target"
fi
if [[ "$output_dir" != /* ]]; then
	output_dir="$repo_root/$output_dir"
fi
# Linux keeps its flat layout (logs beside the game). Windows ships one folder, zipped, so the
# logs stay outside what a tester receives.
game_dir="$output_dir"
if [[ "$target" == "windows" ]]; then
	game_dir="$output_dir/SoulMeter"
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

mkdir -p "$output_dir" "$game_dir"
acceptance_log="$output_dir/acceptance.log"
export_log="$output_dir/export.log"
probe_log="$output_dir/pack-probe.log"
smoke_log="$output_dir/smoke.log"
executable="$game_dir/$executable_name"
pck="$game_dir/SoulMeter.pck"
for stale in "$executable" "$pck" "$game_dir/SHA256SUMS" "$game_dir/BUILD-MANIFEST.txt" \
	"$game_dir/BUILD-DIRTY-STATUS.txt" "$game_dir/DEPENDENCIES.md"; do
	rm -f "$stale"
done

acceptance="strict"
if [[ "$skip_acceptance" -eq 1 ]]; then
	acceptance="skipped"
	echo "PLAYTEST BUILD: acceptance skipped (local verification only)"
else
	echo "PLAYTEST BUILD: strict acceptance"
	SOUL_METER_LOCALE_STRICT=1 GODOT_BIN="$godot_bin" \
		bash scripts/acceptance_gate.sh | tee "$acceptance_log"
fi

# Never add --recovery-mode here: it disables editor plugins, so the Dialogue Manager importer
# never runs and the pack ships without a single .dialogue resource (the CI Windows artifact did,
# until 2026-11-20). The pack probe below fails such a build.
echo "PLAYTEST BUILD: $preset release export"
if ! "$godot_bin" --headless --path . --export-release "$preset" "$executable" \
	> "$export_log" 2>&1; then
	echo "PLAYTEST BUILD: export failed; tail follows" >&2
	tail -n 80 "$export_log" >&2
	exit 1
fi
if [[ ! -s "$executable" || ! -s "$pck" ]]; then
	echo "PLAYTEST BUILD: export did not produce both executable and pack" >&2
	exit 1
fi
cp DEPENDENCIES.md "$game_dir/"

scratch_dir="$(mktemp -d /tmp/soul-meter-playtest.XXXXXX)"
trap 'rm -rf "$scratch_dir"' EXIT

echo "PLAYTEST BUILD: pack probe (every shipped dialogue loads from the pack)"
probe_list="$scratch_dir/expected-resources.txt"
find dialogue -name '*.dialogue' | sort > "$probe_list"
mkdir -p "$scratch_dir/probe-cwd" "$scratch_dir/probe-data"
# An empty working directory: with project.godot in reach, res:// would resolve to the repo.
set +e
(
	cd "$scratch_dir/probe-cwd"
	env SOUL_METER_PACK_PROBE_LIST="$probe_list" XDG_DATA_HOME="$scratch_dir/probe-data" \
		timeout 120s "$godot_bin" --headless --main-pack "$pck" \
		-s "$repo_root/tools/playtest_pack_probe.gd"
) > "$probe_log" 2>&1
probe_status=$?
set -e
pack_probe="$(grep -m 1 '^PACK PROBE: [0-9]' "$probe_log" | sed 's/^PACK PROBE: //' || true)"
if [[ "$probe_status" -ne 0 ]]; then
	echo "PLAYTEST BUILD: pack probe failed (status $probe_status)" >&2
	grep '^PACK PROBE' "$probe_log" >&2 || tail -n 40 "$probe_log" >&2
	exit 1
fi
echo "PLAYTEST BUILD: pack probe: $pack_probe"

echo "PLAYTEST BUILD: smoke boot"
mkdir -p "$scratch_dir/smoke-data"
set +e
if [[ "$target" == "linux" ]]; then
	smoke="exported binary, headless"
	env XDG_DATA_HOME="$scratch_dir/smoke-data" timeout "${smoke_seconds}s" \
		"$executable" --headless > "$smoke_log" 2>&1
else
	# The Windows executable cannot run here; boot its pack in this host's engine instead.
	smoke="exported pack in host engine, headless"
	mkdir -p "$scratch_dir/smoke-cwd"
	(
		cd "$scratch_dir/smoke-cwd"
		env XDG_DATA_HOME="$scratch_dir/smoke-data" timeout "${smoke_seconds}s" \
			"$godot_bin" --headless --main-pack "$pck"
	) > "$smoke_log" 2>&1
fi
smoke_status=$?
set -e
if [[ "$smoke_status" -ne 124 ]]; then
	echo "PLAYTEST BUILD: game exited during the smoke window (status $smoke_status)" >&2
	tail -n 80 "$smoke_log" >&2
	exit 1
fi
# grep, not rg: ripgrep is not installed everywhere this runs, and a missing command here
# reads as "no errors found".
if grep -nE "SCRIPT ERROR|^ERROR:" "$smoke_log"; then
	echo "PLAYTEST BUILD: game emitted runtime errors" >&2
	exit 1
fi

commit_sha="$(git rev-parse HEAD)"
godot_version="$($godot_bin --version | head -n 1)"
created_utc="$(date -u +%Y-%m-%dT%H:%M:%SZ)"
acceptance_report="none"
if [[ "$acceptance" == "strict" ]]; then
	acceptance_report="$(ls -dt reports/report_* 2>/dev/null | head -n 1)/results.xml"
fi
gate_t_valid="yes"
if [[ "$tree_state" != "clean" ]]; then
	gate_t_valid="no — local verification build only"
	printf '%s\n' "$workspace_state" > "$game_dir/BUILD-DIRTY-STATUS.txt"
elif [[ "$acceptance" != "strict" ]]; then
	gate_t_valid="no — acceptance skipped, local verification build only"
fi

(
	cd "$game_dir"
	find . -maxdepth 1 -type f ! -name '*.log' ! -name SHA256SUMS ! -name BUILD-MANIFEST.txt \
		-printf '%f\n' | sort | xargs sha256sum > SHA256SUMS
)

{
	echo "Soul Meter Gate T playtest build"
	echo "created_utc=$created_utc"
	echo "commit_sha=$commit_sha"
	echo "worktree=$tree_state"
	echo "valid_for_gate_t=$gate_t_valid"
	echo "godot=$godot_version"
	echo "target=$target"
	echo "preset=$preset"
	echo "acceptance=$acceptance"
	echo "acceptance_report=$acceptance_report"
	echo "pack_probe=$pack_probe"
	echo "smoke=$smoke"
	echo "smoke_seconds=$smoke_seconds"
	echo "verification=sha256sum -c SHA256SUMS"
} > "$game_dir/BUILD-MANIFEST.txt"

if [[ "$target" == "windows" ]]; then
	zip_name="SoulMeter-windows-x86_64.zip"
	echo "PLAYTEST BUILD: packing $zip_name"
	python3 - "$output_dir" "$zip_name" <<'PY'
import os
import sys
import zipfile

output_dir, zip_name = sys.argv[1], sys.argv[2]
zip_path = os.path.join(output_dir, zip_name)
with zipfile.ZipFile(zip_path, "w", zipfile.ZIP_DEFLATED) as archive:
    for name in sorted(os.listdir(os.path.join(output_dir, "SoulMeter"))):
        archive.write(os.path.join(output_dir, "SoulMeter", name), os.path.join("SoulMeter", name))
PY
	(
		cd "$output_dir"
		sha256sum "$zip_name" > "$zip_name.sha256"
	)
	echo "PLAYTEST BUILD: zip: $output_dir/$zip_name"
	echo "PLAYTEST BUILD: zip sha256: $(cut -d ' ' -f 1 "$output_dir/$zip_name.sha256")"
fi

echo "PLAYTEST BUILD: complete"
echo "PLAYTEST BUILD: artifact directory: $game_dir"
echo "PLAYTEST BUILD: Gate T valid: $gate_t_valid"
