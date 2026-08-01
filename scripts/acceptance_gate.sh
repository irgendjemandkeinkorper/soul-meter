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

echo "ACCEPTANCE: checking Pandora/generated-data drift"
GODOT_BIN="$godot_bin" bash scripts/check_generated_data.sh

echo "ACCEPTANCE: running deterministic headless suite"
SOUL_METER_HEADLESS=1 GODOT_BIN="$godot_bin" bash scripts/test.sh -a test

echo "ACCEPTANCE: art-free first-chapter gate passed"
