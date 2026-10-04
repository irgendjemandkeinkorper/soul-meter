# Called shots: qualified field treatment (task 10C) — 2026-09-19

Task 10C in [the combat expansion checklist](../../tasks/called-shots-and-injuries.md): a qualified party practitioner cures one serious injury outside combat from the character sheet, through the same `InjuryTreatment` quote/commit path the shop uses.

## Content as built

| Card | Practitioner | Supply | Cures | Notes |
|---|---|---|---|---|
| `field-mending` "Field mending" | Conscious party member with Trained Mending and no serious arm injury | 1 × Bitterleaf Poultice (`consumables/bitterleaf_poultice`) | arm, throat | Guaranteed; no `SkillCheck.resolve()`, no Expert reroll, no HP change |

The supply is PROVISIONAL: Bitterleaf is the existing field-wound consumable and is used as-is (not renamed, no new generated item). The Pandora resupply pass may swap it. The Trained threshold and one-unit quantity are the proposed rules from the design doc, not ratified balance.

## Interaction

`ui/screens/character_sheet.gd` adds an Injuries section to the selected member's sheet. Each serious injury shows location, severity, what it restricts, and recovery state, then a practitioner pick and a button `Field mending • 1 × Bitterleaf Poultice (carry N)`. The pick defaults to the first party member not refused for a practitioner reason, and an explicit choice survives the rebuild it triggers. A refused button prints the exact reason and the alternatives (Root & Reed for a fee, Shrine succor once). Pressing quotes, commits with `expected_cost`, and prints a receipt or the refusal in the status line. Only the selected injury is removed; other injuries, HP, GP, and Soul are untouched.

## Evidence

- `test/integration/test_character_sheet.gd` (+2 rendered-tree tests): missing supply reported as such with the qualified practitioner picked; switching to the untrained patient shows `Vex lacks Trained Mending.`; last supply unit consumed; throat cured, arm kept, HP/GP/Soul unchanged, receipt shown; an arm-injured practitioner is refused while a throat-injured one is allowed; combat beginning between quote and press refuses with `combat active` and keeps the supply.
- Rendered: `called-shot-field-treatment-2026-09-19/field-treatment-1920.png` from `test/manual/field_treatment_capture.gd` at 1920×1080 (scrolled to the section); inspected.
- Regression suites green: character sheet, injury treatment, treatment shop, dev console, injuries, battle, save game, advancement. 103 tests, 0 failures, across two runs.

## Recovery checkpoint

- A party without Mending completes the loop through Root & Reed or the shrine (10B tests); a party with Mending completes it in the field (10C tests).
- Transaction, save, and rendered checks pass; failure and duplicate submission never lose resources (10A/10B/10C suites).
- Guaranteed treatment consumes no SkillCheck RNG: `InjuryTreatment` never calls `SkillCheck.resolve()`.

## Not covered / open

- Cancel/reopen of the sheet was not driven with real input events; state is read fresh on every rebuild, so nothing is cached between opens.
- Elemental impositions and ultimate flags are not touched by the coordinator (it only erases the injury record); no separate assertion was added for them.
