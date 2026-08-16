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
