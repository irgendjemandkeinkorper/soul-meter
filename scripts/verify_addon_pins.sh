#!/usr/bin/env bash
set -euo pipefail

# Reporting-only vendored-addon check. DEPENDENCIES.md records upstream pins, but
# downloaded archives contain no trustworthy commit metadata. This script can
# therefore verify only that each expected pin is documented and that the
# corresponding vendored directory matches the repository's committed snapshot.
# It does not contact upstream, authenticate archive provenance, or validate
# project-owned addons/soul_meter_tools. Findings never change the exit status.

cd "$(dirname "$0")/.."

declare -a addon_records=(
	"Maaack's Game Template|93e66a0|addons/maaacks_game_template"
	"Godot State Charts|76d226a|addons/godot_state_charts"
	"Pandora|d78b99e|addons/pandora"
	"Dialogue Manager|09b82d6|addons/dialogue_manager"
	"QuestSystem|853276e|addons/quest_system"
	"GLoot|6b09b87|addons/gloot"
	"Phantom Camera|dbf15ee|addons/phantom_camera"
	"Anima|f28a1be|addons/anima"
	"Juicee|eb66d35|addons/juicee"
	"SmartShape2D|b52ea53|addons/rmsmartshape"
	"PixelPen|v1.1.4|addons/net.yarvis.pixel_pen"
	"gdUnit4|v6.1.3|addons/gdUnit4"
)

finding_count=0

if ! git rev-parse --is-inside-work-tree >/dev/null 2>&1; then
	echo "ADDON-PINS: unable to compare vendored snapshots outside a Git working tree"
	echo "ADDON-PINS: report complete (1 finding; reporting only)"
	exit 0
fi

for record in "${addon_records[@]}"; do
	IFS='|' read -r addon_name pin addon_path <<<"$record"
	documented_row="$(grep -F "| $addon_name |" DEPENDENCIES.md || true)"

	if [[ "$documented_row" != *"$pin"* ]]; then
		echo "ADDON-PINS: undocumented or changed pin: $addon_name expected $pin"
		finding_count=$((finding_count + 1))
	fi

	if [[ ! -d "$addon_path" ]]; then
		echo "ADDON-PINS: missing vendored directory: $addon_path ($addon_name at $pin)"
		finding_count=$((finding_count + 1))
		continue
	fi

	if ! git diff --quiet HEAD -- "$addon_path"; then
		echo "ADDON-PINS: tracked drift: $addon_path ($addon_name at documented pin $pin)"
		finding_count=$((finding_count + 1))
	fi

	if [[ -n "$(git ls-files --others --exclude-standard -- "$addon_path")" ]]; then
		echo "ADDON-PINS: untracked files: $addon_path ($addon_name at documented pin $pin)"
		finding_count=$((finding_count + 1))
	fi
done

if ((finding_count == 0)); then
	echo "ADDON-PINS: 12 documented pins match clean committed vendored snapshots"
else
	echo "ADDON-PINS: report complete ($finding_count findings; reporting only)"
fi
