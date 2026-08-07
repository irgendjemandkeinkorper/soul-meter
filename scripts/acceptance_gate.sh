#!/usr/bin/env bash
set -euo pipefail

# Art-free release gate for the first playable chapter. This deliberately
# checks contracts and generated data, not the presence of future art packs.
godot_bin="${GODOT_BIN:-godot}"

required_paths=(
	"project.godot"
	"data.pandora"
	"data/generated/encounters.json"
	"data/generated/gloot_prototree.json"
	"locale/project.pot"
	"locale/es.po"
	"test/manual/prototype_acceptance.md"
)

for path in "${required_paths[@]}"; do
	if [[ ! -e "$path" ]]; then
		echo "ACCEPTANCE: missing required artifact: $path" >&2
		exit 1
	fi
done

# CI runs the runtime checks as named steps so gdUnit4 reports can be uploaded
# even when the suite fails. Keep the local gate's combined behavior unchanged.
if [[ "${SOUL_METER_ACCEPTANCE_ARTIFACTS_ONLY:-0}" = "1" ]]; then
	echo "ACCEPTANCE: required artifacts present"
	exit 0
fi

echo "ACCEPTANCE: checking Pandora/generated-data drift"
GODOT_BIN="$godot_bin" bash scripts/check_generated_data.sh

echo "ACCEPTANCE: checking PixelPen Linux parking guard"
bash scripts/check_pixelpen_linux_guard.sh

echo "ACCEPTANCE: running deterministic headless suite"
SOUL_METER_HEADLESS=1 GODOT_BIN="$godot_bin" bash scripts/test.sh -a test

echo "ACCEPTANCE: art-free first-chapter gate passed"
