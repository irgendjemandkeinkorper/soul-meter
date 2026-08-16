#!/usr/bin/env bash
set -euo pipefail

# FR-904 performance instrumentation entrypoint.
#
# Measurement only — this script never optimizes and never fails on a slow
# number. It emits a JSON report on stdout so CI can diff runs and a human can
# read one. See docs/performance-benchmark.md for the report schema and, more
# importantly, for what these numbers do and do not prove.
#
# Usage:
#   GODOT_BIN=~/.local/bin/godot bash scripts/benchmark_performance.sh
#   GODOT_BIN=~/.local/bin/godot bash scripts/benchmark_performance.sh \
#     --scenario populated-grid --display-mode rendered -o report.json
#   GODOT_BIN=~/.local/bin/godot bash scripts/benchmark_performance.sh \
#     --scenario populated-grid --display-mode headless --profile -o profile.json

godot_bin="${GODOT_BIN:-godot}"
output_path=""
scenario="field"
display_mode="headless"
profile_mode=0
benchmark_data_dir="${SOUL_METER_BENCHMARK_DATA_DIR:-/tmp/soul-meter-godot-benchmark-data}"
mkdir -p "$benchmark_data_dir"
export XDG_DATA_HOME="$benchmark_data_dir"

while [[ $# -gt 0 ]]; do
	case "$1" in
		-o|--output)
			output_path="${2:-}"
			if [[ -z "$output_path" ]]; then
				echo "--output requires a path" >&2
				exit 2
			fi
			shift 2
			;;
		--scenario)
			scenario="${2:-}"
			shift 2
			;;
		--display-mode)
			display_mode="${2:-}"
			shift 2
			;;
		--profile)
			profile_mode=1
			shift
			;;
		-h|--help)
			sed -n '3,16p' "$0"
			exit 0
			;;
		*)
			echo "Unknown argument: $1" >&2
			exit 2
			;;
	esac
done

if ! command -v "$godot_bin" >/dev/null 2>&1 && [[ ! -x "$godot_bin" ]]; then
	echo "Godot binary not found: $godot_bin (set GODOT_BIN)" >&2
	exit 1
fi

case "$scenario" in
	field)
		tool_script="res://tools/performance_benchmark.gd"
		;;
	populated-grid)
		tool_script="res://tools/populated_grid_benchmark.gd"
		;;
	*)
		echo "Unknown benchmark scenario: $scenario" >&2
		exit 2
		;;
esac

if [[ "$profile_mode" -eq 1 && "$scenario" != "populated-grid" ]]; then
	echo "--profile is only available for --scenario populated-grid" >&2
	exit 2
fi

godot_args=()
case "$display_mode" in
	headless)
		godot_args+=("--headless")
		;;
	rendered)
		;;
	*)
		echo "Unknown display mode: $display_mode" >&2
		exit 2
		;;
esac

raw="$(mktemp)"
cleanup() { rm -f "$raw"; }
trap cleanup EXIT

# The harness is a SceneTree script; Godot prints engine banners and shutdown
# warnings around the payload. Godot also exits non-zero on cosmetic teardown
# noise ("N resources still in use at exit"), so the presence of a well-formed
# report — not the exit status — decides success here.
set +e
profile_args=()
if [[ "$profile_mode" -eq 1 ]]; then
	profile_args+=("--" "--profile")
fi
"$godot_bin" "${godot_args[@]}" --path . --script "$tool_script" \
	"${profile_args[@]}" >"$raw" 2>&1
godot_status=$?
set -e

if grep -qE 'SCRIPT ERROR|Parse Error' "$raw"; then
	echo "Benchmark harness reported a script error:" >&2
	grep -E 'SCRIPT ERROR|Parse Error' "$raw" >&2
	exit 1
fi

report="$(grep -m1 -o '{.*}' "$raw" || true)"

if [[ -z "$report" ]]; then
	echo "Benchmark produced no JSON report (godot exit $godot_status). Raw output:" >&2
	cat "$raw" >&2
	exit 1
fi

if [[ -n "$output_path" ]]; then
	printf '%s\n' "$report" >"$output_path"
	echo "Wrote FR-904 report to $output_path" >&2
else
	printf '%s\n' "$report"
fi
