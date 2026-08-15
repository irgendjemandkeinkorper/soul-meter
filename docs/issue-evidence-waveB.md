# Wave B Issue Evidence

## Issue #199 — Dom tavern interior transition

- Implementation: the existing town `TavernDoor` now requests
  `GameFlow.travel(GameFlow.TAVERN_SCENE, &"entry")`; the dedicated
  `world/interiors/dom_tavern.tscn` contains the player, bounded room,
  taverner counter interaction, existing tavern picker overlay, and walk-out
  return to `SpawnFromTavern` in Dom. No `LocationRegistry` entry or
  fast-travel hub was added.
- Save/load: unregistered, allowlisted gameplay interiors retain their exact
  scene path through `LoadDestination`; the integration test restores both the
  tavern scene and the saved player position.
- Focused command:
  `XDG_DATA_HOME=/tmp/soul-meter-godot-data XDG_CONFIG_HOME=/tmp/soul-meter-godot-config ~/.local/bin/godot --headless --path . -s res://addons/gdUnit4/bin/GdUnitCmdTool.gd --ignoreHeadlessMode -a test/integration/test_tavern_interior.gd`
- Focused observed summary:
  `Overall Summary: 2 test cases | 0 errors | 0 failures | 0 flaky | 0 skipped | 0 orphans |`
- Adjacent regression command:
  `XDG_DATA_HOME=/tmp/soul-meter-godot-data XDG_CONFIG_HOME=/tmp/soul-meter-godot-config ~/.local/bin/godot --headless --path . -s res://addons/gdUnit4/bin/GdUnitCmdTool.gd --ignoreHeadlessMode -a test/unit/test_save_game.gd -a test/integration/test_building_interiors.gd -a test/integration/test_starting_town.gd -a test/integration/test_tavern_interior.gd`
- Adjacent observed summary:
  `Overall Summary: 56 test cases | 0 errors | 0 failures | 0 flaky | 0 skipped | 0 orphans |`
- Runner note: the repository wrapper currently passes
  `--remote-debug tcp://127.0.0.1:0`; Godot 4.7.1 rejects port 0 and aborts
  before discovery. The direct gdUnit4 command above omits that invalid option
  and is otherwise the same test entry point. Full-suite evidence remains for
  the Wave B integration pass.

## Issue #80 — Pandora stability assessment

- Artifact: `docs/pandora-stability-assessment.md` records the installed
  `d78b99e` pin, the pre-1.0 risk surface, the upgrade policy, and the drift
  checks that currently protect generated and canonical data.
- Inspection command:
  `grep -E '^## (Decision|Current risk surface|Upgrade policy|Existing drift-check coverage)$|d78b99e|pre-1.0' docs/pandora-stability-assessment.md`
- Observed result: all four required sections and the documented pin/risk
  markers are present.

## Issue #82 — Vendored addon pin verification

- Artifact: `scripts/verify_addon_pins.sh` compares the twelve addon pins in
  `DEPENDENCIES.md` with the committed vendored snapshots. Its header documents
  the archive-provenance limitation and the check remains reporting-only.
- Commands:
  `bash -n scripts/verify_addon_pins.sh`
  and `bash scripts/verify_addon_pins.sh`
- Observed result: both commands exited 0; the verifier reported
  `ADDON-PINS: 12 documented pins match clean committed vendored snapshots`.

## Issue #191 — Headless click-input translation

- Implementation: `ClickMoveController.translate_pointer_event()` provides a
  statically typed event-to-world-position boundary used by production
  `_unhandled_input()`. Navigation dispatch and accepted-input behavior remain
  in the production handler.
- Coverage: `test/unit/test_click_move_input_translation.gd` exercises accepted
  pressed-left-click translation plus released-left, other-button, and
  non-mouse rejection without requiring a viewport.
- Residual check: `test/manual/click_to_move_viewport_check.md` documents the
  real-viewport camera/CanvasTransform verification that headless gdUnit4
  cannot establish.
- Focused command:
  `GODOT_BIN=~/.local/bin/godot bash scripts/test.sh -a test/unit/test_click_move_input_translation.gd`
- Focused observed summary:
  `Overall Summary: 4 test cases | 0 errors | 0 failures | 0 flaky | 0 skipped | 0 orphans |`
- Runner note: the command exited 0. ALSA fell back to Godot's dummy audio
  driver and Godot reported resources still in use at process exit; neither
  affected the gdUnit4 result.

## Issues #72/#73 — Value-object test coverage

- Added dedicated gdUnit4 suites for `BattleActor`, `BattleResult`,
  `ReputationEvent`, and `RenownEvent`. The suites cover construction and
  defaults, field integrity, identity-based equality, instance isolation, and
  supported dictionary serialization round trips and snapshot isolation.
- Command:
  `XDG_DATA_HOME=/tmp/soul-meter-waveb-data XDG_CONFIG_HOME=/tmp/soul-meter-waveb-config ~/.local/bin/godot --headless --path . -s res://addons/gdUnit4/bin/GdUnitCmdTool.gd --ignoreHeadlessMode -a test/unit/test_battle_actor.gd -a test/unit/test_battle_result.gd -a test/unit/test_reputation_event.gd -a test/unit/test_renown_event.gd`
- Observed summary:
  `Overall Summary: 22 test cases | 0 errors | 0 failures | 0 flaky | 0 skipped | 0 orphans |`
- Production implementations were not modified for this coverage work. The
  event objects expose public fields, so immutability remains convention-based;
  the suites verify the enforceable serialization snapshot and instance
  isolation guarantees.

## Issue #80 — Pandora stability assessment

- Artifact: `docs/pandora-stability-assessment.md` records the `d78b99e` pin,
  pre-1.0 risk surface, controlled upgrade and rollback policy, existing drift
  coverage, and the checks' explicit limitations.
- Review command:
  `grep -E 'd78b99e|pre-1.0|Upgrade policy|Existing drift-check coverage' docs/pandora-stability-assessment.md`
- Observed: all required assessment topics are present.

## Issue #82 — Vendored addon pin verification

- Artifact: `scripts/verify_addon_pins.sh` compares every vendored dependency
  recorded in `DEPENDENCIES.md` with its expected pin and committed working-tree
  snapshot. It is reporting-only and documents that archive provenance and
  upstream state cannot be proven from the vendored directories.
- Command: `bash scripts/verify_addon_pins.sh`
- Expected clean-tree summary:
  `ADDON-PINS: 12 documented pins match clean committed vendored snapshots`

## Correction round (architect)
- Wave regression found and fixed: tavern travel broke `test_first_chapter_journey.gd`
  (door press now travels instead of opening the picker) and `test_location_registry.gd`
  (unregistered gameplay scene, then a duplicate entry). Fixes: registered
  `world/locations/interiors/dom_tavern.tres` as an interior of Dom;
  `GameFlow._gameplay_scenes()` now sources ONLY from `LocationRegistry.gameplay_scenes()`;
  e2e recruit step follows the new door->interior->counter flow.
- Final full suite: `Overall Summary: 716 test cases | 1 errors | 4 failures` — all in the
  known baseline suites (actor_presentation, y_sort, click_to_move_input). ZERO new failures.
