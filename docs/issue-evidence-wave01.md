# Wave 0 + Wave 1 verification evidence

Verified on 2026-08-15 with Godot 4.7.1. The CI container has no display server, so gdUnit was
invoked with `--headless --ignoreHeadlessMode`; the requested command without those flags cannot
initialize X11 or Wayland in this environment.

## #129 — Register of Persons

- Acceptance criterion: character creation writes the lead identity, while recruit creation writes
  the custom roster without replacing the player.
- Verification command: `GODOT_BIN=~/.local/bin/godot bash addons/gdUnit4/runtest.sh --headless --ignoreHeadlessMode -a test/integration/test_character_creation.gd`
- Observed output:
  `Statistics: 2 test cases | 0 errors | 0 failures | 0 flaky | 0 skipped | 0 orphans | PASSED 186ms`
  `Overall Summary: 2 test cases | 0 errors | 0 failures | 0 flaky | 0 skipped | 0 orphans |`
- Verdict: **SATISFIED**.

## #139 — Tile state

- Acceptance criterion: clash detonation deals 18 at charge two, residue caps at three, Hush
  suppresses residue/detonation, and state round-trips losslessly.
- Verification command: `GODOT_BIN=~/.local/bin/godot bash addons/gdUnit4/runtest.sh --headless --ignoreHeadlessMode -a test/unit/test_tile_state.gd`
- Observed output:
  `Statistics: 11 test cases | 0 errors | 0 failures | 0 flaky | 0 skipped | 0 orphans | PASSED 80ms`
  `Overall Summary: 11 test cases | 0 errors | 0 failures | 0 flaky | 0 skipped | 0 orphans |`
  The passing cases include `test_clash_strike_on_charge_two_tile_deals_eighteen_and_zeroes`,
  `test_residue_accumulates_and_caps_at_three`, `test_hush_suppresses_residue_and_detonation`,
  and `test_to_dict_from_dict_round_trip_is_lossless`.
- Verdict: **SATISFIED**.

## #140 — Weather cadence and Hush

- Acceptance criterion: weather applies once per 16 ticks and Hush blocks charge movement without
  losing cadence.
- Verification command: `GODOT_BIN=~/.local/bin/godot bash addons/gdUnit4/runtest.sh --headless --ignoreHeadlessMode -a test/unit/test_weather.gd`
- Observed output:
  `Statistics: 15 test cases | 0 errors | 0 failures | 0 flaky | 0 skipped | 0 orphans | PASSED 115ms`
  `Overall Summary: 15 test cases | 0 errors | 0 failures | 0 flaky | 0 skipped | 0 orphans |`
  The passing cases include `test_sixteen_ticks_produce_exactly_one_application` and
  `test_weather_hush_blocks_charge_movement_without_blocking_tick_counter`.
- Verdict: **SATISFIED**.

## #142 — Pure combat resolution

- Acceptance criterion: forecast and resolution share one deterministic code path and resolution
  does not mutate input dictionaries.
- Verification command: `GODOT_BIN=~/.local/bin/godot bash addons/gdUnit4/runtest.sh --headless --ignoreHeadlessMode -a test/combat_resolution/test_resolution.gd`
- Observed output:
  `Statistics: 6 test cases | 0 errors | 0 failures | 0 flaky | 0 skipped | 0 orphans | PASSED 59ms`
  `Overall Summary: 6 test cases | 0 errors | 0 failures | 0 flaky | 0 skipped | 0 orphans |`
  The passing cases include `test_forecast_and_resolution_modes_are_the_same_code_path` and
  `test_resolution_does_not_mutate_any_input_dictionary`.
- Verdict: **SATISFIED**.

## #103 — Six companion quests

- Acceptance criterion: `QuestRegistry.COMPANION_QUESTS` contains all six companion quests and
  each has registered quest/dialogue behavior.
- Verification commands:
  - `rg -n -A 7 'const COMPANION_QUESTS' globals/quest_registry.gd`
  - `GODOT_BIN=~/.local/bin/godot bash addons/gdUnit4/runtest.sh --headless --ignoreHeadlessMode -a test/unit/test_companion_quest.gd`
- Observed output: the registry contains six entries: Serai, Wyneth, Grumbrand, Ressa, Korrath,
  and Maura.
  `Statistics: 8 test cases | 0 errors | 0 failures | 0 flaky | 0 skipped | 0 orphans | PASSED 85ms`
  `Overall Summary: 8 test cases | 0 errors | 0 failures | 0 flaky | 0 skipped | 0 orphans |`
- Verdict: **SATISFIED**.

## #105 — Mirror Shop and NG+ carry-over

- Acceptance criterion: a Mirror Shop exists through `ui/screens/shop.tscn`, and purchased
  carry-overs survive the NG+ transform.
- Verification commands:
  - `GODOT_BIN=~/.local/bin/godot bash addons/gdUnit4/runtest.sh --headless --ignoreHeadlessMode -a test/integration/test_interior_population.gd`
  - `GODOT_BIN=~/.local/bin/godot bash addons/gdUnit4/runtest.sh --headless --ignoreHeadlessMode -a test/unit/test_vendors.gd`
  - `GODOT_BIN=~/.local/bin/godot bash addons/gdUnit4/runtest.sh --headless --ignoreHeadlessMode -a test/unit/test_save_game.gd`
  - `rg -n -i 'mirror shop|mirror_shop|purchased_carry_overs' globals ui test`
- Observed output:
  - Shop UI round-trip: `Overall Summary: 5 test cases | 0 errors | 0 failures | 0 flaky | 0 skipped | 0 orphans |`
  - Vendor behavior: `Overall Summary: 11 test cases | 0 errors | 0 failures | 0 flaky | 0 skipped | 0 orphans |`
  - Save/NG+ behavior: `Overall Summary: 26 test cases | 0 errors | 0 failures | 0 flaky | 0 skipped | 0 orphans |`
  - `ui/screens/shop.tscn` exists and generic shop/NG+ carry-over tests pass, but there is no
    Mirror Shop-specific implementation or test. `globals/ng_plus.gd` explicitly says the
    Mirror Shop is outside that module.
- Verdict: **NOT-SATISFIED** — generic shop and carry-over infrastructure exists, but the required
  Mirror Shop-specific feature and coverage are missing.

## #161 — Blocking TileMapLayer

- Acceptance criterion: the blocking `TileMapLayer` is the obstacle source for both navigation
  and physics.
- Verification command: `GODOT_BIN=~/.local/bin/godot bash addons/gdUnit4/runtest.sh --headless --ignoreHeadlessMode -a test/integration/test_blocking_layer.gd`
- Observed output:
  `Statistics: 2 test cases | 0 errors | 0 failures | 0 flaky | 0 skipped | 0 orphans | PASSED 1s 180ms`
  `Overall Summary: 2 test cases | 0 errors | 0 failures | 0 flaky | 0 skipped | 0 orphans |`
  Both `test_pathfinding_cannot_cross_a_blocking_cell` and
  `test_physics_body_cannot_enter_a_blocking_cell` passed.
- Verdict: **SATISFIED**.

## #162 — Click-to-move refusal

- Acceptance criterion: click-to-move routes reachable clicks and emits a structured, distinct
  refusal for unreachable clicks.
- Verification commands:
  - `GODOT_BIN=~/.local/bin/godot bash addons/gdUnit4/runtest.sh --headless --ignoreHeadlessMode -a test/integration/test_click_to_move.gd`
  - `GODOT_BIN=~/.local/bin/godot bash addons/gdUnit4/runtest.sh --headless --ignoreHeadlessMode -a test/nav_acceptance/test_click_to_move_input.gd`
- Observed output:
  - Controller/integration seam: `Overall Summary: 8 test cases | 0 errors | 0 failures | 0 flaky | 0 skipped | 0 orphans |`
  - Viewport input acceptance: `Overall Summary: 1 test cases | 0 errors | 3 failures | 0 flaky | 0 skipped | 0 orphans |`
  - The required unreachable-refusal cases pass in the integration suite. The known headless input
    suite still reports its baseline viewport mismatch: target outside the 1152x648 viewport,
    `blocked_by_obstacle` expected but `blocked_by_unreachable` observed, and path size 5
    expected but 0 observed.
- Verdict: **SATISFIED** for the controller/refusal contract; the pre-existing headless viewport
  acceptance failure remains documented and unchanged.

## #165 — FR-105 seam / section 8.1 stop-loss

- Acceptance criterion: the battlefield interface is executable, the feature flag selects grid
  or zone implementations, and switching the flag off restores the zone model.
- Verification command: `GODOT_BIN=~/.local/bin/godot bash addons/gdUnit4/runtest.sh --headless --ignoreHeadlessMode -a test/unit/test_battlefield_model_interface.gd`
- Observed output:
  `Statistics: 12 test cases | 0 errors | 0 failures | 0 flaky | 0 skipped | 0 orphans | PASSED 125ms`
  `Overall Summary: 12 test cases | 0 errors | 0 failures | 0 flaky | 0 skipped | 0 orphans |`
  The passing cases include `test_create_default_returns_zone_model_when_flag_is_false` and
  `test_the_flag_selects_the_grid_model_and_false_selects_the_zone_model`.
- Verdict: **SATISFIED**.

## Full-suite verification

- Import command: `~/.local/bin/godot --headless --path . --import`
  - Exit status 0. Known plugin shutdown/leak diagnostics were emitted; no script parse failure.
- Full-suite command: `GODOT_BIN=~/.local/bin/godot bash addons/gdUnit4/runtest.sh --headless --ignoreHeadlessMode -a test`
- Observed output:
  `Overall Summary: 685 test cases | 1 errors | 4 failures | 0 flaky | 0 skipped | 0 orphans |`
- Baseline comparison: **ZERO NEW FAILURES**. The observed failures remain in the named baseline
  suites: `test_actor_presentation` (1 runtime error), `test_y_sort` (1 assertion failure), and
  `test_click_to_move_input` (3 assertion failures). The previously named
  `test_click_to_move` suite passed 8/8 in this run.

## Correction-round controller regression

- Verification command: `GODOT_BIN=~/.local/bin/godot bash addons/gdUnit4/runtest.sh --headless --ignoreHeadlessMode -a test/integration/test_combat_controller.gd`
- Observed output:
  `Overall Summary: 12 test cases | 0 errors | 0 failures | 0 flaky | 0 skipped | 0 orphans |`
- The passing regression proves a third charge-time wait is surfaced as
  `consecutive_wait_cap` before `turn_ended` or scheduler advancement.
