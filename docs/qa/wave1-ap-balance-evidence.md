# Wave 1 AP balance-pass evidence — five ex-CT encounters

**Date:** 2026-08-28 · **Contract:** `docs/fallout2-adoption-spec.md` Wave 1 item 6 —
the five `EncounterCatalog._CHARGE_TIME_ENCOUNTERS` overrides may only be removed
"together with a balance-pass evidence note comparing those encounters under AP."

## Method

`tools/wave1_ap_balance_pass.gd` (headless, deterministic scripted policy: two plain
reference allies strike the first living enemy until out of AP / once per CT ready;
enemies use the controller's live AI). Each encounter simulated under both schedulers
by flipping `use_charge_time` on a duplicated `combat_rules.tres`. Enemy full-AP flag
was OFF (shipped default) in both runs, per the Wave 0 ruling.

## Results (run 2026-08-28, post-merge `41675c1`)

| Encounter | AP rounds / outcome / ally HP left | CT rounds / outcome / ally HP left |
|---|---|---|
| phase2-demon | 2 / VICTORY / 63 | 2 / VICTORY / 59 |
| phase2-undead | 4 / VICTORY / 57 | 3 / VICTORY / 52 |
| phase2-mixed-whipsaw | 3 / VICTORY / 57 | 3 / VICTORY / 56 |
| phase2-speech-winnable | 2 / VICTORY / 63 | 2 / VICTORY / 62 |
| phase2-stabilizer-showcase | 3 / VICTORY / 59 | 3 / VICTORY / 56 |

Zero ally KOs in any run; all enemies cleared in every run.

## Reading

- Outcome parity is exact (5/5 VICTORY both schedulers); round counts match in 4/5 and
  differ by one in `phase2-undead` (AP one round slower — mildly safer for the player).
- Ally HP retained under AP is equal or slightly higher (+1 to +5) across all five —
  consistent with AP's yield-with-remainder rhythm, not a difficulty collapse in either
  direction.
- Conclusion: removing the CT overrides does not destabilize these encounters at the
  reference-party level. This clears Wave 1 item 6's evidence requirement. It does NOT
  authorize flipping `enemy_full_ap_turns` on — that needs its own pass with the flag
  raised (Wave 0 ruling 1).

## Limitations

- Scripted strike-only policy; no Defining Strikes, context actions, movement, or
  weather. This measures scheduler cadence, not full tactical breadth.
- Reference allies, not authored party builds.
- `combat_number_sweep` multiplier stack unaffected by this change (resolution math
  untouched; weakness context is additive and absent in these runs).
