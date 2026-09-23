# Wave 1 handoff — facade occlusion, entry placement, Waterline

Branch: `feat/ch1-facade-occlusion`, branched from the supplied HEAD of `feat/persistent-world-structures`. **Commit blocked:** `git add` cannot create `.git/index.lock` on the read-only filesystem. No commit hash, staging, push, or PR. Unrelated work preserved.

Facades now tween to `DS.FACADE_OCCLUDED_ALPHA` (0.35) over 0.15 seconds when a visible town actor's feet overlap alpha > 0.1 behind a building origin, and restore to 1.0 after clearance. Each building caches its texture image once. Actor visibility, modulation, z-index, y-sort, and serialized state are untouched by the occluder.

Changed/added files:
- Added `world/facade_occluder.gd` and `.gd.uid`; modified `world/starting_town.gd`, `world/starting_town.tscn`, `actors/player/player.gd`, `ui/theme/ds.gd`.
- Modified scenes: `world/interiors/building_interior.tscn`, `world/interiors/dom_tavern.tscn` (positions only).
- Added `test/unit/test_facade_occluder.gd` and `.gd.uid`; extended `test/integration/test_building_interiors.gd` and `test/integration/test_starting_town.gd`.
- Updated `actors/building_door/transitions/<stem>_enter.tres` for all 20 stems below: only `destination_spawn_position.y`, 400 → 498.6, preserving the existing marker/registry consistency contract.
- Added this handoff: `docs/qa/ch1-field-ux-wave1.md`.

SpawnEntry changes (all paths under `world/interiors/`):
| Scene(s) | Old → new y | Authored Player |
|---|---|---|
| `building_interior.tscn` (shared base) | 400 → 498.6 (= door sprite 442.6 + 56) | 400 → 498.6 |
| `dom_tavern.tscn` | 510 → 538.6 (= ExitDoorSprite 482.6 + 56) | 510 → 538.6 |
| `bell_house`, `bell_loft`, `cask_warehouse`, `chefs_house`, `chefs_pantry` (`.tscn`) | 400 → 498.6, inherited | 400 → 498.6, inherited |
| `council_chamber`, `equipment_forge`, `equipment_shop`, `garrison_yard`, `iron_companies` (`.tscn`) | 400 → 498.6, inherited | 400 → 498.6, inherited |
| `item_shop`, `players_house`, `players_loft`, `registry_archive`, `registry_stacks` (`.tscn`) | 400 → 498.6, inherited | 400 → 498.6, inherited |
| `river_shrine`, `shrine_undercroft`, `town_hall`, `trial_hall` (`.tscn`) | 400 → 498.6, inherited | 400 → 498.6, inherited |
| `lower_trial_hall.tscn` | 400 → 498.6, inherited | Existing override 540 already clears door art |

Verification uses Godot `4.7.1.stable.official.a13da4feb`. The two requested interior/town suites are actually under `test/integration/`; no duplicate unit suites were created. The existing follower group is singular `party_follower`; both singular and requested plural are supported.

Exact commands (run from repository root; outputs in `/tmp/ch1-wave1-*.log`):
```bash
GODOT_BIN="$HOME/.local/bin/godot" LP_NUM_THREADS=1 SOUL_METER_TEST_DATA_DIR="$(mktemp -d /tmp/soul-meter-test.XXXXXX)" bash scripts/test.sh -a test/unit/test_facade_occluder.gd -a test/integration/test_building_interiors.gd -a test/integration/test_starting_town.gd > /tmp/ch1-wave1-red.log 2>&1
SOUL_METER_HEADLESS=1 GODOT_BIN="$HOME/.local/bin/godot" LP_NUM_THREADS=1 SOUL_METER_TEST_DATA_DIR="$(mktemp -d /tmp/soul-meter-test.XXXXXX)" bash scripts/test.sh -a test/unit/test_facade_occluder.gd -a test/integration/test_building_interiors.gd -a test/integration/test_starting_town.gd > /tmp/ch1-wave1-red-headless.log 2>&1
SOUL_METER_HEADLESS=1 GODOT_BIN="$HOME/.local/bin/godot" LP_NUM_THREADS=1 SOUL_METER_TEST_DATA_DIR="$(mktemp -d /tmp/soul-meter-test.XXXXXX)" bash scripts/test.sh -a test/unit/test_facade_occluder.gd -a test/integration/test_building_interiors.gd -a test/integration/test_starting_town.gd -a test/unit/test_dom_npc_roster.gd -a test/nav_acceptance > /tmp/ch1-wave1-green.log 2>&1
SOUL_METER_HEADLESS=1 GODOT_BIN="$HOME/.local/bin/godot" LP_NUM_THREADS=1 SOUL_METER_TEST_DATA_DIR="$(mktemp -d /tmp/soul-meter-test.XXXXXX)" bash scripts/test.sh -a test/unit/test_facade_occluder.gd -a test/integration/test_building_interiors.gd -a test/integration/test_starting_town.gd -a test/unit/test_dom_npc_roster.gd -a test/nav_acceptance -a test/unit/test_building_transition_registry.gd -a test/integration/test_y_sort.gd > /tmp/ch1-wave1-verified.log 2>&1
XDG_DATA_HOME="$(mktemp -d /tmp/soul-meter-import.XXXXXX)" LP_NUM_THREADS=1 "$HOME/.local/bin/godot" --headless --editor --path . --import --quit > /tmp/ch1-wave1-import.log 2>&1
SOUL_METER_HEADLESS=1 GODOT_BIN="$HOME/.local/bin/godot" LP_NUM_THREADS=1 SOUL_METER_TEST_DATA_DIR="$(mktemp -d /tmp/soul-meter-test.XXXXXX)" bash scripts/test.sh -a test/integration/test_starting_town.gd > /tmp/ch1-wave1-town-final.log 2>&1
grep -rn Waterline actors world globals ui test --include='*.gd'
git diff --check
```

Results:
- Rendered attempt: exit 1 before tests; Xvfb runner could not provide X11/Wayland. Explicitly fell back to `SOUL_METER_HEADLESS=1`.
- Tests written first: red run 2 passed / 3 failed cases (23 assertion failures, exit 100); each of facade fade, interior placement, and Waterline removal failed before implementation.
- Initial implementation: 50 passed / 1 failed (test waited on a startup timer before fade completion). Replaced that wait with 20 physics frames.
- Final combined run: **72 passed / 0 failed**, 0 errors/skips/flaky/orphans, exit 0, 24.281 seconds. Facade 10; interiors 19; town 19; NPC roster 12; nav acceptance 1; transition registry 4; y-sort 7. Report: `reports/report_1422/results.xml`.
- Final town rerun after removing a redundant test helper: **19 passed / 0 failed**. `git diff --check` passes. Waterline search has no production-script references; only the new absence assertion and existing optional y-sort expectation remain.

Risks/limitations: Rendered visibility and interior appearance remain unverified here; the reviewer owns the rendered check per handoff. The import exited 0 with no script parse/compile errors, but editor plugins, socket restrictions, and an unwritable external editor-settings path emitted errors. Import-created unrelated artifacts were removed. Test shutdown still reports ObjectDB/resource cleanup warnings despite gdUnit reporting 0 errors/orphans. No full release sweep was run.

Open questions: none for implementation. Rendered review still needs the tavern facade with the player at building origin + (0, -136), then tavern entry at (480, 538.6).

Next action: run these commands from a session where this repository's `.git` is writable (the `git add` below is the exact command blocked here):
```bash
git add -- world/facade_occluder.gd world/facade_occluder.gd.uid world/starting_town.gd world/starting_town.tscn actors/player/player.gd ui/theme/ds.gd world/interiors/building_interior.tscn world/interiors/dom_tavern.tscn test/unit/test_facade_occluder.gd test/unit/test_facade_occluder.gd.uid test/integration/test_building_interiors.gd test/integration/test_starting_town.gd actors/building_door/transitions/*_enter.tres docs/qa/ch1-field-ux-wave1.md
git commit -m "fix(world): fade occluding facades and clear interior entries"
```

## Rendered verification (Fable, host Xvfb, 2026-09-13)

`scripts/test.sh -a test/unit/test_facade_occluder.gd -a test/integration/test_building_interiors.gd -a test/integration/test_starting_town.gd -a test/unit/test_dom_npc_roster.gd -a test/nav_acceptance -a test/manual/ch1_field_ux_wave0.gd` → 62 cases, 0 failures (rendered).
- `docs/qa/wave1/town_four_arms_tavern_front_120_faded.png`: tavern facade at 0.35 alpha, Vex readable behind it; Waterline gone.
- `docs/qa/wave1/interior_dom_tavern_entry_front_of_door.png`: player spawns in front of the exit door, not inside the arch.
- Owner tuning surface: `DS.FACADE_OCCLUDED_ALPHA` (0.35) reads slightly ghostly; 0.45 may be the better default.
