# Wave 2 — interior presentation

Implemented on `feat/ch1-facade-occlusion`, Godot `4.7.1.stable.official.a13da4feb`. No commit: `.git` is not writable. No staging, push, or PR; unrelated changes preserved.

Changed files (six):
- `world/interiors/building_interior.gd` and `world/interiors/building_interior.tscn`
- `world/interiors/dom_tavern.gd` and `world/interiors/dom_tavern.tscn`
- `ui/theme/ds.gd`
- `test/integration/test_building_interiors.gd`

Every room below receives a full-screen, mouse-ignoring `Surround` CanvasLayer at -1; brick walls at z -1, 96 px top / 48 px other sides; camera limits derived from global Floor bounds plus those thicknesses. The authored 960×640 Floor produces limits left -48, top -96, right 1008, bottom 688. Walls extend outward from the Floor; collision shapes and all furniture remain unchanged. Existing backdrop matches the surround ink. `INK_0` aliases `VOID_0`; `WOOD_0` names the existing tavern brown.

| Interior (.tscn) | Change |
|---|---|
| bell_house | Surround, walls, camera via Room |
| bell_loft | Surround, walls, camera via Room |
| cask_warehouse | Surround, walls, camera via Room |
| chefs_house | Surround, walls, camera via Room |
| chefs_pantry | Surround, walls, camera via Room |
| council_chamber | Surround, walls, camera via Room |
| equipment_forge | Surround, walls, camera via Room |
| equipment_shop | Surround, walls, camera via Room |
| garrison_yard | Surround, walls, camera via Room |
| iron_companies | Surround, walls, camera via Room |
| item_shop | Surround, walls, camera via Room |
| lower_trial_hall | Surround, walls, camera via embedded Room; no duplicate layer |
| players_house | Surround, walls, camera via Room |
| players_loft | Surround, walls, camera via Room |
| registry_archive | Surround, walls, camera via Room |
| registry_stacks | Surround, walls, camera via Room |
| river_shrine | Surround, walls, camera via Room |
| shrine_undercroft | Surround, walls, camera via Room |
| town_hall | Surround, walls, camera via Room |
| trial_hall | Surround, walls, camera via Room |
| dom_tavern | Same presentation added directly; BackWall path preserved; Counter gets brick texture and DS.WOOD_0 |

Exact commands, run from the repository root:
```bash
GODOT_BIN="$HOME/.local/bin/godot" LP_NUM_THREADS=1 SOUL_METER_TEST_DATA_DIR="$(mktemp -d /tmp/soul-meter-test.XXXXXX)" bash scripts/test.sh -a test/integration/test_building_interiors.gd -a test/integration/test_starting_town.gd -a test/unit/test_interior_population.gd > /tmp/ch1-wave2-red.log 2>&1
SOUL_METER_HEADLESS=1 GODOT_BIN="$HOME/.local/bin/godot" LP_NUM_THREADS=1 SOUL_METER_TEST_DATA_DIR="$(mktemp -d /tmp/soul-meter-test.XXXXXX)" bash scripts/test.sh -a test/integration/test_building_interiors.gd -a test/integration/test_starting_town.gd -a test/unit/test_interior_population.gd > /tmp/ch1-wave2-red-headless.log 2>&1
SOUL_METER_HEADLESS=1 GODOT_BIN="$HOME/.local/bin/godot" LP_NUM_THREADS=1 SOUL_METER_TEST_DATA_DIR="$(mktemp -d /tmp/soul-meter-test.XXXXXX)" bash scripts/test.sh -a test/integration/test_building_interiors.gd -a test/integration/test_starting_town.gd -a test/integration/test_interior_population.gd > /tmp/ch1-wave2-red-corrected.log 2>&1
SOUL_METER_HEADLESS=1 GODOT_BIN="$HOME/.local/bin/godot" LP_NUM_THREADS=1 SOUL_METER_TEST_DATA_DIR="$(mktemp -d /tmp/soul-meter-test.XXXXXX)" bash scripts/test.sh -a test/integration/test_building_interiors.gd -a test/integration/test_starting_town.gd -a test/integration/test_interior_population.gd > /tmp/ch1-wave2-green.log 2>&1
git diff --check
```

Results: rendered attempt failed before tests (display initialization, exit 1). Initial headless baseline: 19 passed / 1 failed case, 14 assertion failures; population path missing. Corrected baseline: 24 passed / 1 failed case, 14 assertion failures (exit 100). Final: **45 passed / 0 failed**, 0 errors/skips/flaky/orphans (exit 0, 18.085 seconds): interiors 21, town 19, population 5. Population suite actually lives under `test/integration/`. Diff check passes. XML: `reports/report_1427/results.xml`.

Tests were written before implementation. They check the shared base, every registered interior, and standalone tavern; full-screen ink surround; wall area, thickness, texture and ordering; camera limits, including a translated room with different Floor bounds; and counter texture/tint. Existing dressing, scale, spawn, collision, population and round-trip tests pass.

Risks: rendered appearance remains unverified because Xvfb cannot initialize X11/Wayland here. Larger viewports retain dark padding around these unchanged room sizes. Reviewer owns rendered screenshot_sweep shots 30–33. Engine shutdown reports ObjectDB/resource cleanup warnings (also present in the baseline), despite gdUnit reporting zero errors/orphans. No release sweep was run.

Open questions: none for implementation. Next: reviewer captures and inspects shots 30–33 on a working display.

## Rendered verification (Fable, host Xvfb, 2026-09-13)

- Suites `test_building_interiors` / `test_starting_town` / `test_interior_population` + `screenshot_sweep`: 56 cases, 0 failures (rendered).
- `test/manual/ch1_field_ux_wave2_probe.gd` (isolated interior captures, boot scene hidden):
  `docs/qa/wave2/tavern_interior.png`, `docs/qa/wave2/item_shop_interior.png` — dark surround,
  four brick walls with thickness, camera bounded to the room. Accepted.
- Harness note: under gdUnit the MainMenu boot scene sits after the runner scene in the root and
  draws over it; `screenshot_sweep._shoot` hides it, the probe does too. Not a game bug.
- Still visible and expected until #309: Kenney light-wood tables/stools/benches, the orange
  accent rug, the flat counter.
