# Called shots: bounded location injury (task 7) — 2026-09-19

Task 7 in [the combat expansion checklist](../../tasks/called-shots-and-injuries.md) is implemented as a combat-local slice: an aimed hit can leave one bounded injury record on the target, the record modifies later eligible attacks, and every quote shows the chance before it is rolled.

## Contract as built

- `globals/combat/injury.gd` (`CombatInjury`) owns records in `BattleActor.injuries`, keyed by location. A second qualifying hit refreshes the same record (`applications` + 1, `refreshed_at_tick`) and never escalates severity or stacks the effect. A commit replayed with the same provenance key (`battle|tick|actor|ability`) is a no-op.
- Aim profiles author the injury (`id`, `chance_on_hit`, `min_damage`, `severity`, `effects`); `CalledShot.query` validates the shape. Lab profiles: arm `arm-strained` (50 % on hit, −10 pp attack accuracy), throat `throat-bruised` (35 % on hit, no effect yet; task 8 owns the vocal rule), torso none.
- `Resolution` rolls the injury on its own deterministic channel (`injury|seed|tick|battle|ability|unit|target`) and quotes `injury_chance = {hit, on_hit, overall}`. The roll is never consulted unless the attack hit; `CombatController._finalize_resolution_damage` then requires landed damage ≥ `min_damage` after mitigation before it appends the `injury` write.
- Injury accuracy modifiers apply to ATTACK-kind non-spell actions only, labelled `Injury: <Location>`, and leave the attacker's Alacrity attribute untouched.
- Forecast payload carries `injury_forecast` (`hit_chance`, `chance_on_hit`, `overall_chance`, `eligible`, `min_damage`); the HUD aim line reads `INJURY 35% ON HIT · 17% OVERALL`, `INJURY NEEDS N DAMAGE` when the quoted damage cannot reach the threshold, or `NO INJURY EFFECT` when the location authors none.

## Evidence

- `test/integration/test_injuries.gd` (4 tests): miss never injures; a rolled hit applies once and the cached commit replays as a no-op; a second hit refreshes without escalating; arm injury shifts hit chance by −10 pp on attacks but not spells with Alacrity unchanged; forecast is pure and reports the three chances, torso quotes nothing, and an unreachable `min_damage` is ineligible with 0 % overall.
- Regression suites green: called shots (13), battle interface (6), resolution (19), combat lab (16), combat controller (61), combat session (8), battle HUD/stage/pointer, battle actor, battle, save game. 208 tests, 0 failures, across two runs.
- Rendered: `aim-row-1920.png` recaptured at 1920×1080 through `test/manual/aim_row_capture.gd`; the forecast panel shows `AIM THROAT · COST 2 AP · INJURY 35% ON HIT · 17% OVERALL`.

## Not covered

Injuries do not yet persist past the battle (task 9), have no treatment path (task 10), and the throat record has no gameplay effect until task 8. Balance values are provisional. The record's `recovery: "untreated"` field is reserved for task 10.
