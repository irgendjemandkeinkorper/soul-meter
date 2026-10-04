# Called shots: production content, enemy AI, and Checkpoint D — 2026-09-20

Tasks 11 (torso/arm/throat slice) and 12 of [the combat expansion checklist](../../tasks/called-shots-and-injuries.md), plus the automated half of Checkpoint D.

## Task 11A: anatomy through the authoring pipeline

Canon → seeder → Pandora → generator → catalog → actor, with no hand-edited artifact:

| Archetype | Anatomy |
|---|---|
| bog-wight, gnaal-rift-scavenger, mustered-bloodbellow | torso (hidden by low cover), arm, throat |
| cleaned-jawbrace-guard | torso, arm, throat authored as "Gorget", not exposed |
| gnaal-breach-hound | flank (torso), throat; no arm |
| loam-maddened-boar | flank (torso) only |

- `tools/seed_pandora.gd`: archetype contract gains optional `anatomy`; `_valid_anatomy` refuses non-object values, non-snake ids, missing display names, and non-boolean flags. Seeded as a JSON string column `Anatomy` with sorted keys.
- `tools/generate_gloot.gd` exports `anatomy` per combatant; `EncounterCatalog._actor_from_row` copies it onto the actor. A row without one has no aimable locations.
- Regenerated `data.pandora` and `data/generated/encounters.json`; `scripts/check_generated_data.sh` reports no drift for all three generators.

## Task 11B: production aim profiles

`strike` (CT 30) and `enemy-strike` (CT 45) author torso (+1 AP, +5 CT, −5 pp), arm (+1 AP, +10 CT, −15 pp, `arm-strained` 50 % on hit, −10 pp to attacks), throat (+1 AP, +15 CT, −25 pp, `throat-bruised` 35 % on hit, −10 pp to vocal actions). All numbers are PROVISIONAL and mirror the lab fixture. Only minor injuries ship; serious production injuries wait on the balance pass now that treatment exists.

## Task 12: enemy called shots

`CombatController.choose_enemy_aim` compares the ordinary strike with each authored aim: value = hit chance × damage on hit + overall injury chance × `PROVISIONAL_AI_INJURY_VALUE` (6). Candidates are bounded to authored profiles, legal through `_query_aim` (exposure, cover, visibility), payable by scheduler quote, on observable anatomy; an already-injured location and a floor-clamped shot are skipped. Only `Resolution.accuracy_breakdown` and `preview_on_hit` are read; the committed roll never is. The enemy round commits the priced aimed action and reports `aim_location` and the surcharged AP.

## Evidence

- `test/unit/test_canon_reader.gd` (+1), `test/unit/test_encounter_catalog.gd` (+1): validation and built-actor anatomy with absent and covered parts.
- `test/integration/test_production_aim.gd` (3): quotes for all three regions under AP and CT, absent/covered refusals on real archetypes, an aimed arm hit through submit whose minor injury ends with the fight.
- `test/integration/test_enemy_called_shots.gd` (5): arm preferred when ordinary damage is small; ordinary kept when damage is large; injured limb and hidden/absent parts skipped; floor-clamped shots never aimed; the enemy round commits the aim with its surcharge; choice is identical across RNG positions and advances nothing.
- Checkpoint D suites: all of `test/unit` and `test/combat_resolution`, plus controller, battle, session, called shots, injuries, HUD, lab, deployment, and flow transitions. Both schedulers covered by the production-aim suite; save compatibility by the task 9 suites; replay by the injuries suite.
- Full-directory runs: `test/unit` + `test/combat_resolution` 1640 cases, 0 failures. `test/integration` 448 cases: one real failure (the Wave C AP-compatibility gate flagged the new `ap_surcharge` line in `called_shot.gd` and the lab's AP quote; both now carry the documented AP-compatibility marker and the gate is green). Four other suites (starting town, interior population, battle pointer controls, layout editor input) failed only in the whole-directory run with corrupted typed strings, and pass together in isolation (33 cases, 0 failures); they are order-dependent input bleed, not caused by this branch.
- Cost: `test/manual/aim_query_cost_probe.gd`, 100 enemies vs 100 allies on a 20×20 grid, i5-13400F, xvfb headless: ordinary forecast 44.7 ms total, aim choice 245.8 ms total, 2.46 ms per enemy decision (all 100 chose an aim against low-defense targets).

## Open

- Legs and head/eyes content slices (task 11 later slices).
- Human tactical judgment and readability check on the rendered encounter (Checkpoint D, third item).
- Balance pass for aim costs, injury chances, and the AI injury value.
