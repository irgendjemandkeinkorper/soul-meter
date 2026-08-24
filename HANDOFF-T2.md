# Gate T-2 follow-up handoff

## Status

**FR-105a is wired and unit-verified; Gate T-2 still fails deterministically.** Do not merge this
branch as proof that the gate passed, and do not activate grid content production. The unchanged
seed/threshold comparison still gives both arms a victory, so the planner-approved stop rule was
honored after the second run.

## Commits

- `08998a1` — enemy grid AI seeks height and facing.
- `bf3607f` — frozen Gate T-2 harness, assertion, and first failed-run evidence.
- `c8c9fb3` — live FR-105a resolution, legality, and focused regression tests.
- Current documentation commit — second failed-run evidence and this compact handoff.

## Changed files

- `globals/combat/resolution.gd` — one clearly marked provisional FR-105a table: +10% damage per
  favorable elevation step; FRONT/SIDE/BACK x1.00/x1.10/x1.25; hit +0/+8/+15.
- `globals/combat/combat_controller.gd` — derives grid height/facing context, routes it through
  live `Resolution`, records positional hit-bonus metadata, and preserves zone flank behavior.
- `globals/combat/grid_battlefield_model.gd` — enforces `|Δh| <= jump` for melee and line-of-sight
  clearance for ranged arcs.
- `test/combat_resolution/test_resolution.gd` — exact height, facing-damage, and hit-bonus tests.
- `test/unit/test_grid_battlefield_model.gd` — melee jump refusal and ranged-clearance tests.
- `test/integration/test_combat_controller.gd` — real grid/controller HP-loss proof for all three
  facings and favorable height.
- `globals/combat/combat_controller.gd`, `test/integration/test_enemy_grid_ai.gd` — earlier enemy
  positional-policy implementation and coverage.
- `tools/gate_t2_positional_depth.gd`, `test/integration/test_gate_t2_positional_depth.gd` — frozen
  harness and natural differential assertion; byte-unchanged in this follow-up.
- `docs/gate-t2-evidence.md` — retains the first failure and appends the dated second failure.

No files under `addons/`, encounter-catalog data, harness inputs, seed, or gate threshold changed.
No push, GitHub operation, or merge was performed.

## Test output and gate verdict

- Resolution unit suite: `8 cases | 0 errors | 0 failures` (exit 0).
- Grid battlefield unit suite: `9 cases | 0 errors | 0 failures` (exit 0).
- Combat controller integration suite: `13 cases | 0 errors | 0 failures` (exit 0).
- Direct frozen harness, twice: byte-identical JSON; both exited 2 with `passed=false`.
- Gate suite: determinism passed; differential remained red because naive was `victory`, not
  `defeat` (`2 cases | 0 errors | 2 failures | 0 orphans`, exit 100).
- Required full suite via `scripts/test.sh`: `745 cases | 1 error | 6 failures | 0 orphans`
  (exit 100). The prior run was `740 | 1 | 6`; five new passing tests changed only the case count.
  The two gate assertions plus the same four pre-existing presentation/input failures in
  `test_actor_presentation`, `test_y_sort`, and `test_click_to_move_input` remain.

Second-run arms:

| Arm | Outcome | Party HP | Survivors | Moves | Elevation | Rear attacks |
|---|---:|---:|---:|---:|---:|---:|
| Positional | Victory | 46 | 2 | 15 | 2 | 1 |
| Naive | Victory | 40 | 2 | 4 | 0 | 0 |

**Verdict: FAIL.** The positional policy is measurably better but does not produce the required
positional-victory/naive-defeat differential.

## Risks

- FR-105a hit bonuses are calculated and carried in resolution/action metadata, but the combat
  chassis has no hit/miss roll to consume them; no new accuracy mechanic was invented.
- Runtime melee legality reads jump from `BattleActor.attributes[&"jump"]`. Actors without an
  authored runtime value conservatively have jump 0; `UnitDefinition.jump` is not yet projected
  into `BattleActor` by the current runtime path.
- `CombatController` remains above 1,000 lines. Extracting enemy/positional policy is a separate
  refactor and was not mixed into this gate change.
- The encounter catalog still has no ratified terrain/elevation schema; the frozen probe owns its
  synthetic grid while reusing catalog combatants unchanged.

## Open questions / recommended next action

1. Escalate the second deterministic Gate T-2 failure to the human owner; do not tune further on
   this branch.
2. The owner/planner must decide whether the gate encounter/threshold should remain as written or
   whether a separately ratified terrain/elevation content schema is required before another run.
3. If hit chance becomes a real mechanic, define how the already-exposed +0/+8/+15 bonus enters
   that roll; this handoff deliberately does not invent that contract.
