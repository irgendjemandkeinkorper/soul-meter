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

## To-hit candidate sweep — 2026-08-24 (#169 ruling follow-through)

Owner ratified reading 2: build a to-hit system, rerun the unchanged harness once.
`tools/to_hit_sweep.gd` swept base ∈ {70,75,80,85,90} × height-mod/step ∈ {0,4,6,8} under
clamp 5–95 with the ratified facing +0/+8/+15. Key findings (full table in the tool's output):

- Any base ≥ 80 pushes back-attack (+15) into the 95 cap even on flat ground — the ratified
  facing bonus goes partially inert. Base ≤ 75 keeps side/back expression intact.
- Height mod 4–6/step doubles the positional-vs-naive expected-value ratio (≈2.1–2.3×) versus
  damage-only (the 6-HP run-2 gap), chiefly by ALSO penalizing attacks made uphill (-dh).
- The stylized duel P(win) saturates >96% for all candidates — ranking evidence only; the gate
  evidence remains the unchanged harness rerun after implementation.

Candidate shortlist presented for ratification: A) base 75 / +6 per step, B) base 70 / +4,
C) base 80 / +6 (accepts capped back-attacks as diminishing-returns design). Clamp 5–95 in all.

## Rerun 3 — to-hit live (ratified candidate B) — 2026-08-24

Status: **FAIL — hard §5 escalation; no further attempts without an owner decision.**

The ratified to-hit curve (base 70, +4/step signed height, clamp 5–95, facing +0/+8/+15) is
implemented in `Resolution.resolve()` behind `to_hit_enabled` (grid combat opts in via
positional context; zone combat keeps legacy auto-hit). Deterministic roll hashed from
(seed, tick, battle_id, ability, attacker, target); a miss deals 0 (bypassing the 1-damage
floor), pays CT, keeps source residue, skips target detonation. 26 focused cases green.

Unchanged harness (`phase2-demon`, seed 1692002, same threshold):

| Arm | Outcome | Party HP | Moves | Rear attacks | Decisions |
|---|---:|---:|---:|---:|---:|
| Positional | Victory | 46 | 14 | 2 | 24 |
| Naive | Victory | 40 | 4 | 0 | 14 |

To-hit demonstrably engaged (whiffs changed both arms' action counts), yet the naive arm still
wins with both members alive. The binding constraint is now the encounter's kill-rate margin:
enemies die before their pressure can accumulate into a loss, so **no per-cast modifier of any
size can flip this encounter's outcome**. That is an encounter-slack finding, not further
evidence about the positional rules themselves.

## Run 4 — pre-registered encounter-selection rule — 2026-08-24

Owner ratified (before any per-encounter comparison was examined): select the charge-time
catalog encounter with the lowest NAIVE-arm party-HP fraction (defeat selects immediately;
lexicographic tiebreak); selection sees no positional results. Seed, party, and the
victory/defeat threshold unchanged.

Selection sweep (naive arm only): demon 40/54 · mixed-whipsaw 36/54 · speech-winnable 50/54 ·
stabilizer-showcase 38/54 · **undead 15/54 ← selected**.

Comparison on `phase2-undead`:

| Arm | Outcome | Party HP | Survivors | Rear attacks |
|---|---:|---:|---:|---:|
| Positional | Victory | 48 | 2 | 11 |
| Naive | Victory | 15 | 1 | 0 |

Status: **threshold still unmet** (naive won at 15 HP with one member dead). The positional
differential is no longer marginal — 33 HP and a party death — but the frozen binary
threshold requires a naive defeat. Escalated to the owner for the final verdict; no further
runs without a ruling.

## Verdict — Gate T-2 CLOSED as PASSED (owner, 2026-08-24)

The owner amended the §5 threshold (recorded in `docs/prd-amendment-tactical-layer.md` §5.2
with its post-hoc caveat) to: positional victory AND (naive defeat OR naive loses a party
member while positional loses none with an HP differential ≥ 50% of max party HP). Run 4
meets it. The harness and the gdUnit gate suite now assert the amended threshold; the suite
runs green with no skips. Grid + CT stand as the ratified chassis.
