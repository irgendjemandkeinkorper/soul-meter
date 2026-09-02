# A2/A3 handoff — issues #216 and #217

## Status

Issues #216 and #217 are implemented in order on `feat/a2-a3-breath-integrity`.
Nothing was pushed.

## Commits

- `307b7690` — `feat(casting): persist per-scene Breath pools`
- `63b0e9f2` — `feat(hud): show Breath on field and battle plates`
- `a644479f` — `feat(casting): feed location integrity into fizzle`

## Changed files

| Slice | Files |
|---|---|
| #216 Breath lifecycle/save | `globals/battle.gd`, `globals/game_state.gd`, `globals/party_member.gd`, `globals/save_migrations.gd`, `test/fixtures/save_game_schema_6.json`, `test/fixtures/save_game_schema_7.json`, `test/unit/test_battle.gd`, `test/unit/test_game_state_party.gd`, `test/unit/test_party_member.gd`, `test/unit/test_save_migrations.gd` |
| #216 HUD | `ui/hud/field_hud.gd`, `ui/hud/regions/unit_plate/unit_plate_region.gd`, `ui/hud/regions/unit_plate/unit_plate_region.tscn`, `test/test_field_hud_breath.gd`, `test/test_field_hud_breath.gd.uid`, `test/test_unit_plate_region.gd` |
| #217 integrity/fizzle | `globals/battle.gd`, `globals/combat/combat_controller.gd`, `globals/encounter_catalog.gd`, `globals/location_definition.gd`, `ui/hud/regions/forecast_panel/forecast_panel_region.gd`, `test/integration/test_combat_controller.gd`, `test/test_weather_forecast_regions.gd`, `test/unit/test_battle.gd`, `test/unit/test_encounter_catalog.gd`, `test/unit/test_location_definition.gd` |

## What now works

- Every `PartyMember` persists `breath` and `breath_max`; legacy rows default to the provisional base-tier full pool of 15 from `docs/casting-economy.md`.
- Only the GameFlow `Loading/ToActive` transition refills active-party Breath. Battle and pause returns to Active do not refill it.
- Battle actors copy current Breath from their party member at start and write the remaining amount back on every battle end path.
- Runtime casting abilities use the provisional magnitude costs from `docs/casting-economy.md`: Note 3, Phrase 6, Song 12, Refrain 24.
- Field and battle HUDs expose Breath. Location/thinning integrity and encounter overrides now feed the one fizzle context shared by forecast and commit; the forecast panel shows its resolved fizzle percentage.

## Test evidence

Command:

```bash
GODOT_BIN=~/.local/bin/godot xvfb-run -a bash addons/gdUnit4/runtest.sh -a test
```

Final result:

```text
Overall Summary: 1263 test cases | 0 errors | 0 failures | 0 flaky | 0 skipped | 0 orphans |
```

`test/unit/test_manual_slots.gd` and all `test_save_*` suites are included in that green run. Quest/dialogue files were not touched, so `tools/quest_audit.gd` was not applicable.

## Risks

- `main` already used schema 7 for `world_clock`; this work extends the existing 6→7 migration instead of introducing schema 8. Pre-existing schema-7 saves without Breath still load full through `PartyMember.from_dict()` and gain explicit fields on their next save.
- Generated Note rows still contain legacy `mp_cost = 1`. `Battle` clones abilities and applies the documented provisional magnitude costs at runtime because generated files were out of scope.
- The forecast region now shows fizzle itself while `battle_interface.gd` also appends its existing Breath/Soul/Fizzle detail line, so cast forecasts repeat the percentage once.
- `combat_lab_recorder/` and `dev-console-recorder/` remain untracked and untouched, as noted in `HANDOFF-A1.md`.

## Open questions

- Should a follow-up reserve schema 8 for Breath so schema-7 saves written before this slice can be distinguished from schema-7 saves written after it?
- Should C21 author final `LocationDefinition.integrity` values and retire the existing `thinning_tier` adjustment, or is `integrity` the base value that thinning continues to modify?
- Should the tactical data generator be updated in its own allowed scope so generated `mp_cost`/`breath_cost` values match the runtime magnitude table?
