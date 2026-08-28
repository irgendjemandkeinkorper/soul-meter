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
	"data/generated/items.pot"
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

echo "ACCEPTANCE: checking locale msgid drift"
python3 - <<'PY'
import ast
import os
from pathlib import Path


def msgids(path: str) -> set[str]:
    entries: set[str] = set()
    current: list[str] | None = None

    for line in Path(path).read_text(encoding="utf-8").splitlines():
        if line.startswith("msgid "):
            if current and "".join(current):
                entries.add("".join(current))
            current = [ast.literal_eval(line[6:])]
        elif line.startswith("msgid_plural "):
            if current and "".join(current):
                entries.add("".join(current))
            current = None
        elif line.startswith("msgstr"):
            if current and "".join(current):
                entries.add("".join(current))
            current = None
        elif current is not None and line.startswith('"'):
            current.append(ast.literal_eval(line))
        elif not line.strip():
            if current and "".join(current):
                entries.add("".join(current))
            current = None

    if current and "".join(current):
        entries.add("".join(current))
    return entries


source_ids = msgids("locale/project.pot") | msgids("data/generated/items.pot")
translation_ids = msgids("locale/es.po")
missing = sorted(source_ids - translation_ids)
extra = sorted(translation_ids - source_ids)

if not missing and not extra:
    print(f"LOCALE: catalogs aligned ({len(source_ids)} msgids)")
    raise SystemExit(0)

print(f"LOCALE: drift detected ({len(missing)} missing, {len(extra)} extra)")
for msgid in missing:
    print(f"LOCALE: missing in locale/es.po: {msgid!r}")
for msgid in extra:
    print(f"LOCALE: extra in locale/es.po: {msgid!r}")

if os.environ.get("SOUL_METER_LOCALE_STRICT") == "1":
    print("LOCALE: strict mode rejects catalog drift")
    raise SystemExit(1)
print("LOCALE: reporting only; set SOUL_METER_LOCALE_STRICT=1 to enforce")
PY

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
