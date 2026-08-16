# Gate T-2 positional-depth evidence

Status: **FAIL — escalate; do not activate grid content production.**

## Pre-registered comparison

- Encounter: existing catalog entry `phase2-demon`
- Seed: `1692002`
- Party: identical two-member probe party in both arms
- Positional arm: shared policy scores reachable elevation, facing, and rear access
- Naive arm: the same policy with those positional score terms ablated
- Enemy AI: the same production grid-aware height/facing policy in both arms
- Pass threshold: positional victory **and** naive defeat; no fallback threshold

## Results

| Arm | Outcome | Party HP | Survivors | Moves | Highest elevation | Rear attacks |
|---|---:|---:|---:|---:|---:|---:|
| Positional | Victory | 46 | 2 | 10 | 2 | 0 |
| Naive | Victory | 42 | 2 | 4 | 0 | 0 |

The positional arm preserved four more HP, but the naive arm also won with both party members
alive. This does not meet the frozen victory/defeat threshold and is not a materially worse
outcome. The grid therefore did not demonstrate the required positional-depth tradeoff.

Two independent headless harness runs emitted byte-identical JSON. The gdUnit determinism test
also passed. The differential assertion remains failing so the gate cannot be reported green.

## Interpretation

The positional policy demonstrably used elevation, but neither arm produced a rear attack. Live
combat currently leaves `Resolution` facing context neutral in `CombatController.calculate_damage()`
and applies no ratified height-damage multiplier. The implementation was not changed to add those
numbers or alter `Resolution.resolve()` semantics, because the delegation explicitly forbids
tuning combat rules to force a pass.

Canonical harness command:

```bash
SOUL_METER_HEADLESS=1 ~/.local/bin/godot --headless --path . \
  --script res://tools/gate_t2_positional_depth.gd
```

The harness exits `2` when the frozen threshold fails and prints the complete JSON result.

## Rerun after FR-105a live wiring — 2026-08-16

Status: **FAIL — escalate; do not activate grid content production.**

Commit `c8c9fb3` wires the ratified FR-105a rules into live grid combat without changing this
harness, its seed, its encounter, or its victory/defeat threshold. `Resolution` now applies the
provisional +10% damage per favorable elevation step and FRONT/SIDE/BACK damage table, exposes
the +0/+8/+15 hit bonus, and receives real battlefield context from `CombatController`.
`GridBattlefieldModel` also refuses melee when `|Δh| > jump` and routes ranged arcs through its
existing line-of-sight clearance query.

The unchanged comparison produced:

| Arm | Outcome | Party HP | Survivors | Moves | Highest elevation | Rear attacks |
|---|---:|---:|---:|---:|---:|---:|
| Positional | Victory | 46 | 2 | 15 | 2 | 1 |
| Naive | Victory | 40 | 2 | 4 | 0 | 0 |

The positional arm now reaches a rear attack and preserves six more HP, but the naive arm still
wins with both party members alive. The frozen threshold requires positional victory **and** naive
defeat, so `passed=false` and both direct harness processes exited `2`. Their JSON outputs were
byte-identical. The focused gdUnit gate suite independently passed its determinism test and kept
the natural differential assertion red (`2 test cases | 0 errors | 2 failures | 0 orphans`, exit
100): naive was `victory`, not `defeat`.

Focused FR-105a verification passed:

- `test/combat_resolution/test_resolution.gd`: `8 test cases | 0 errors | 0 failures`.
- `test/unit/test_grid_battlefield_model.gd`: `9 test cases | 0 errors | 0 failures`.
- `test/integration/test_combat_controller.gd`: `13 test cases | 0 errors | 0 failures`.

The required headless-safe full run,
`SOUL_METER_HEADLESS=1 GODOT_BIN=~/.local/bin/godot bash scripts/test.sh`, reported
`745 test cases | 1 errors | 6 failures | 0 orphans` (exit 100). The first run reported
`740 | 1 | 6`; the five new FR-105a tests increased only the case count. The two Gate T-2
differential assertions and the four pre-existing presentation/input failures in
`test_actor_presentation`, `test_y_sort`, and `test_click_to_move_input` account for the same
unchanged failure/error baseline.

Per the stop rule, no further tuning or iteration was attempted after this second failure.
