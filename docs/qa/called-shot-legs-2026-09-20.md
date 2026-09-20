# Called shots: legs content slice — 2026-09-20

Task 11, legs slice, of [the combat expansion checklist](../../tasks/called-shots-and-injuries.md). Design frame: a leg injury impairs movement, expressed through the active scheduler, never immobility.

## What landed

- `CombatInjury.EFFECT_MOVE_COST_PERCENT` (`move_cost_percent`): a percent added to the priced path cost of every move. `move_cost_modifiers` names the term (`Injury: Leg (movement)`); `move_cost_multiplier` folds the bounded one-record-per-location rule into a single multiplier, so a refreshed leg never compounds.
- `CombatController._injured_move_ct` raises the battlefield's path CT before either scheduler prices it: `_priced_move_action` (player moves) derives AP units from the raised CT, and `_resolve_enemy_move` prices the enemy's grid move the same way. Reachable budgets (`_movement_snapshot`, `_best_enemy_position`) shrink by the same multiplier so no offered or chosen cell is unaffordable. Move queries carry `move_modifiers` for consumers.
- Canon anatomy: `leg` on bog-wight, cleaned-jawbrace-guard, gnaal-rift-scavenger, mustered-bloodbellow (Leg), and gnaal-breach-hound (Foreleg), all cover-hidden. The loam-maddened boar remains flank only. Seeded, exported, and drift-clean.
- PROVISIONAL `leg` aim profile on `strike` and `enemy-strike`: +1 AP / +10 CT, −15 pp, injury `leg-hobbled` 40% on hit, minor, `move_cost_percent` 50.

## Evidence

- `test/integration/test_production_aim.gd` (+3): leg quoted on humanoids and the hound (display name Foreleg) and refused on the boar; an aimed leg hit under both schedulers applies `leg-hobbled`, raises a 20-CT step to 30, leaves attack accuracy alone, and ends with the fight; a hobbled ally pays 1.5× CT and 2× AP for the same one-cell step and the query names the leg term.
- `test/unit/test_encounter_catalog.gd`: wight anatomy now includes `leg`.
- Rendered (`test/manual/leg_aim_capture.gd`, 1920×1080, inspected): [leg aim armed](called-shot-legs-2026-09-20/leg-aim-1920.png) shows the LEG chip selected, `Aim: Leg −15 pp`, `AIM LEG · COST 3 AP · INJURY 40% ON HIT · 23% OVERALL`; [hobbled move hover](called-shot-legs-2026-09-20/leg-move-1920.png) shows `2 AP` on the tile and `MOVE 2 AP` in the readout for a one-cell step.
- Suites: production aim, enemy called shots, injuries, called shots, encounter catalog, canon reader, lab, battle interface, pointer controls, Wave C gates, combat session: green.

## Open

- The HUD's move readout shows the priced cost but not the injury term by name; `move_modifiers` is available if a labeled line is wanted.
- Serious leg injuries (persistent) and the head/eyes slice.
- Balance pass on the provisional leg numbers and the enemy AI's flat injury value, which values a hobble the same as any other minor injury.
