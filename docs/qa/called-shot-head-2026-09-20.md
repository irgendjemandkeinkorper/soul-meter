# Called shots: head/eyes content slice — 2026-09-20

Task 11, head/eyes slice, of [the combat expansion checklist](../../tasks/called-shots-and-injuries.md). Design frame: difficult disruption or impaired sight; no automatic stun lock; severe outcomes wait for their own rarity/resistance tuning.

## What landed

- `CombatInjury.EFFECT_SIGHT_ACCURACY` (`sight_accuracy_pp`): percentage points paid by sight-dependent shots. `sight_accuracy_modifiers` names the term `Injury: Head (sight)`.
- Applicability in `CombatController.forecast_context`: ranged non-spell attacks (the same predicate as physical visibility) and any called shot, since aiming needs sight. A plain melee swing at the body pays nothing. The term is a separate physical cause: Blinded keeps its facing restriction and physical visibility keeps its cell term; neither is charged twice.
- Canon anatomy `head`: Head on bog-wight, gnaal-rift-scavenger, mustered-bloodbellow; Muzzle on gnaal-breach-hound; Helm (not exposed) on cleaned-jawbrace-guard so the armored guard refuses head shots with `aim_exposure`. Boar unchanged. Seeded, exported, drift-clean.
- PROVISIONAL `head` aim profile on `strike` and `enemy-strike`: +1 AP / +15 CT, −30 pp, injury `sight-blurred` 30% on hit, minor, `sight_accuracy_pp` −15. No stun, no disable.

## Evidence

- `test/integration/test_production_aim.gd` (+2): head quoted on wight and hound (Muzzle), refused on the guard's helm and absent on the boar; an aimed head hit under both schedulers applies `sight-blurred`, which then taxes a ranged shot and an aimed torso strike by name but not an unaimed melee strike, and reaches the accuracy breakdown of the real forecast.
- `test/unit/test_encounter_catalog.gd`: wight anatomy includes `head`.
- Rendered (`test/manual/head_aim_capture.gd`, 1920×1080, inspected): [head aim with blurred sight](called-shot-head-2026-09-20/head-aim-1920.png) shows six aim chips fitting the panel, `Aim: Head −30 pp · Injury: Head (sight) −15 pp`, `HIT 29%`, `AIM HEAD · COST 3 AP · INJURY 30% ON HIT · 8% OVERALL`.
- Suites: production aim, enemy called shots, injuries, called shots, visibility, encounter catalog, canon reader, lab, battle interface, pointer controls, Wave C gates, combat session, controller, battle, combat_resolution: 210 cases, 0 failures.

## Open

- Serious head/eye outcomes (blindness, disruption) need the rarity/resistance tuning the design calls for; only the minor sight term ships.
- Whether the sight term should also apply to observation (locating a target) rather than only to the shot.
- Balance pass on all provisional aim numbers; the enemy AI still values every minor injury equally.
