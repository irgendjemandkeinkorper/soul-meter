#!/usr/bin/env bash
set -euo pipefail

# gdUnit4's convenience wrapper passes tcp://127.0.0.1:0 to Godot, which is
# rejected by Godot 4.7. Use the command tool directly so local runs match CI.
godot_bin="${GODOT_BIN:-godot}"
test_data_dir="${SOUL_METER_TEST_DATA_DIR:-/tmp/soul-meter-godot-data}"
mkdir -p "$test_data_dir"
export XDG_DATA_HOME="$test_data_dir"

# Some display backends emit errors before gdUnit4 starts when XDG_RUNTIME_DIR is
# absent. Give test runs a private, permission-correct runtime directory while
# respecting an explicit caller-provided location.
if [ -z "${XDG_RUNTIME_DIR:-}" ]; then
	export XDG_RUNTIME_DIR="$test_data_dir/runtime"
	mkdir -p "$XDG_RUNTIME_DIR"
	chmod 700 "$XDG_RUNTIME_DIR"
fi

# The headless DisplayServer opens a 64x64 window, and Maaack's AppSettings
# applies whatever resolution player_config.cfg stores — on a fresh data dir
# (every CI run) that persists 64x64, crushing GUI layout and silently breaking
# pointer-position tests (red "Godot tests" since Wave R). Seed the design
# resolution so a fresh run lays out like a real windowed session; never
# clobber an existing config.
player_config_dir="$test_data_dir/godot/app_userdata/SoulMeter"
mkdir -p "$player_config_dir"
if [ ! -f "$player_config_dir/player_config.cfg" ]; then
	printf '[VideoSettings]\n\nScreenResolution=Vector2i(1920, 1080)\n' \
		> "$player_config_dir/player_config.cfg"
fi

test_args=("$@")
if [ "${#test_args[@]}" -eq 0 ]; then
	test_args=("-a" "test")
fi

# Visual QA suites wait for rendered frames and require Xvfb. Keep them out of
# whole-tree headless runs, but allow an explicit test/manual path to run.
manual_suite_requested=0
whole_test_tree_requested=0
for ((index = 0; index < ${#test_args[@]}; index++)); do
	if [[ "${test_args[$index]}" == test/manual* ]]; then
		manual_suite_requested=1
	fi
	if [ "${test_args[$index]}" = "-a" ] && [ "$((index + 1))" -lt "${#test_args[@]}" ]; then
		if [ "${test_args[$((index + 1))]}" = "test" ]; then
			whole_test_tree_requested=1
		fi
	fi
done
if [ "$whole_test_tree_requested" -eq 1 ] && [ "$manual_suite_requested" -eq 0 ]; then
	test_args+=("-i" "test/manual")
fi

godot_args=()
if [ "${SOUL_METER_HEADLESS:-0}" = "1" ]; then
	godot_args+=("--headless")
	test_args+=("--ignoreHeadlessMode")
	exec "$godot_bin" "${godot_args[@]}" --path . \
		-s res://addons/gdUnit4/bin/GdUnitCmdTool.gd "${test_args[@]}"
fi

exec xvfb-run -a "$godot_bin" "${godot_args[@]}" --path . \
	-s res://addons/gdUnit4/bin/GdUnitCmdTool.gd "${test_args[@]}"
