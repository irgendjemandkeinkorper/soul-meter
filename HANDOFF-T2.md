# Gate T-2 implementation handoff

## Status

**Gate failed deterministically. Do not merge as proof that Gate T-2 passed.** The branch contains
the requested harness, a differential assertion that stays red, production enemy positioning
competence, and the recorded failure evidence.

## Changed files

- `globals/combat/combat_controller.gd` — enemy grid AI seeks reachable height/rear access and
  faces its party target through `BattlefieldModel` capabilities.
- `test/integration/test_enemy_grid_ai.gd` (+ `.uid`) — verifies enemy height/facing competence.
- `tools/gate_t2_positional_depth.gd` (+ `.uid`) — deterministic two-arm AI-vs-AI harness with
  its threshold frozen in the header.
- `test/integration/test_gate_t2_positional_depth.gd` (+ `.uid`) — asserts byte determinism and
  the required positional-victory/naive-defeat differential.
- `docs/gate-t2-evidence.md` — seed, threshold, arm results, and failure interpretation.
- `HANDOFF-T2.md` — this compact handoff.

No files under `addons/` were edited. `Resolution.resolve()` and combat balance values were not
changed. The encounter catalog and generated encounter data were not edited.

## Test output

- Enemy AI focused suite: `1 test cases | 0 errors | 0 failures | 0 orphans` (exit 0).
- Gate T-2 focused suite: determinism passed; differential failed because naive was `victory`,
  not `defeat` (`2 test cases | 0 errors | 2 failures | 0 orphans`, exit 100).
- Direct harness rerun: two byte-identical JSON outputs; both processes exited 2 because
  `passed=false`.
- Full repository run through the headless-safe `scripts/test.sh`: `740 test cases | 1 errors |
  6 failures | 0 orphans` (exit 100). Two failures are the intentional Gate T-2 differential
  assertions. Four out-of-scope presentation/input failures reproduced in isolation:
  `test_actor_presentation`, `test_y_sort`, and `test_click_to_move_input`.
- Required raw command
  `SOUL_METER_HEADLESS=1 GODOT_BIN=~/.local/bin/godot bash addons/gdUnit4/runtest.sh -a test`
  could not start gdUnit (exit 1): that wrapper passes invalid remote-debug port `0` and omits
  `--headless`. `scripts/test.sh` documents and bypasses this repository-known wrapper defect.

Observed arm results:

| Arm | Outcome | Party HP | Elevation | Rear attacks |
|---|---:|---:|---:|---:|
| Positional | Victory | 46 | 2 | 0 |
| Naive | Victory | 42 | 0 | 0 |

## Risks

- The requested falsifiable threshold is not met; the branch is intentionally not green.
- Ratified height damage and FRONT/SIDE/BACK multipliers are not wired into live controller
  resolution. Adding them was outside the allowed “do not tune to pass” boundary.
- `CombatController` now exceeds 1,000 lines; a later approved refactor should extract enemy
  policy rather than growing the coordinator further.
- The live catalog is `globals/encounter_catalog.gd` and has no terrain/elevation schema, while
  the delegation allowed edits only under `globals/combat/`; the probe layout therefore lives in
  the harness and reuses catalog combatants unchanged.

## Open questions / recommended next action

1. Claude/human owner should treat this as the Gate T-2 escalation the amendment requires.
2. Decide separately whether to authorize wiring the already-ratified positional multipliers and
   melee height legality into live combat, then rerun this unchanged threshold.
3. Decide whether encounter data needs an approved grid terrain/elevation schema before another
   probe is attempted.
