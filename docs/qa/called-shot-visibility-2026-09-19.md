# Physical visibility — 2026-09-19

Task 6 in [the combat expansion checklist](../../tasks/called-shots-and-injuries.md) is implemented: one authored physical visibility condition (clear, dim, obscured) changes a ranged shot's chance, and forecasts refresh when it changes.

## Behavior verified

- **Producer.** `GridBattlefieldModel.set_visibility(cell, level)` (or Terrain custom data `visibility = "dim" | "obscured"`) authors per-cell physical visibility. Unknown levels are refused. The zone model is always clear.
- **Composition.** `visibility_between(actor, target)` composes the attacker's and target's cells as the worst level with a `causes` list. Overlapping causes never sum, so the same loss of sight is never counted twice. Cover, elevation, and cells between the two are not visibility causes.
- **Applicability.** The controller marks the term applicable only for ranged, non-spell attacks. Melee swings and direct spells record the level but pay nothing until an explicit profile says otherwise.
- **Magnitudes (PROVISIONAL).** `Resolution.PROVISIONAL_TO_HIT`: dim −10 pp, obscured −25 pp, shown as `Visibility: dim` in the accuracy breakdown. These are placeholders for tuning, not ratified values.
- **Blinded reconciliation.** A Blinded attacker keeps the accepted runtime facing restriction and gets no visibility term; the context records `blinded_facing_restriction` as the reason. One behavior, tested, no accumulation.
- **Separation.** Elemental Weather changes leave the visibility term untouched. Witness Light and Shroud never write visibility; no adapter exists.
- **Live refresh.** `CombatController.configure_visibility()` emits `visibility_changed` carrying a fresh forecast context; the battle interface's forecast panel re-quotes from that event.
- **Lab.** Setup key `visibility_fixture` (UI picker: Clear/Dim/Obscured visibility) authors every enemy cell; the session markdown records it.

## Automated evidence

Godot 4.7.1, `scripts/test.sh` under Xvfb, `LP_NUM_THREADS=1`, disposable `SOUL_METER_TEST_DATA_DIR`.

| Suites | Result |
|---|---|
| Grid model (+1), resolution (+1), called shots (+2, both schedulers), battle interface (refresh check), combat lab (+1) | 90 passed after fixes; see below |
| Called shots, combat lab, controller, session, forecast regions, stage, battle, battlefield authoring, both rendered captures | 147 passed; 0 failed |

The first run of the new suites had one ordering fault in a new test (the enemy round after a commit moves the target) and one typed-array call in a new lab test; both were test-side and fixed. Final combined state: 0 failures.

## Not covered

No rendered capture: the term renders through the same accuracy line already inspected for tasks 2 and 4. No production terrain authors `visibility` yet (task 11). Obscured is a heavy penalty, not an "unlocatable" refusal; a target that cannot be located at all is out of scope.
