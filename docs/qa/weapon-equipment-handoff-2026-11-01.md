# P1.4 equipment-to-combat handoff — 2026-11-01

Issue #533, step 2. Implemented the owner's 2026-11-01 PROVISIONAL ruling on
`codex/roadmap-p1-4-weapon-stat-packet`, continuing from packet commit
`d53f7041417a906482a78e516c9df7ec70019e98`. No branch switch, network operation,
push, PR, roadmap edit, or owner-decisions edit was performed.

## What now works and how to see it

| Equipped weapon | Attack bonus | Defense bonus |
|---|---:|---:|
| Forge Hammer | +2 | 0 |
| Roadwarden Spear | +1 | +1 |
| Taubstummer Axe | +3 | -1 |

`PartyMember.equipped_slots` persists slot names and prototype ids.
`PartyMember.equipment_bonus()` is the only bonus reader; `BattleActor.from_party_member()`
adds its result at construction. Saved base attack/defense, ARMS training, action
costs, accuracy, targeting, and reach are unchanged. Reconstructing an actor does
not compound a bonus; unequipping removes it from the next actor.

The inventory rail has a party-member picker. Its slot inventories contain display
references; physical items remain in `GameState.inventory` even while the screen is
open. GameState owns equip/unequip and emits equipment/party notifications. A bag
item cannot be reserved by two members. Separate physical copies of the same
prototype can be equipped separately, including after save/load. Removing an
equipped physical item clears its owner's slot.

Schema 11 migrates the old **flat** GameState slot record to the protagonist by
identity, independently of party order, then removes the flat record. Existing
member slots take precedence. Unrelated nested legacy payloads and flat records
with no protagonist remain opaque and survive re-saving. Older members without
the additive key load with `{}`.

For Claude's assigned rendered capture:

1. Open Inventory with two party members and the existing weapons in the bag.
2. Pick a member, select a weapon, and press EQUIP or drag it onto MAIN. Check the
   slot label, signed bonus display, and unchanged bag count/weight.
3. Switch members. The first member's physical item is unavailable with its owner
   named; another item, including another copy, can be equipped. Select the rail
   item and use UNEQUIP, or drag its reference back to the bag.
4. Close/reopen and save/load. Each member retains their own slot; one bag item
   remains one item. Capture both supported display sizes using the existing
   rendered menu fixture as appropriate.

## Data provenance

The documented headless Pandora path worked; no fallback stat constant table was
needed. The axe is authored in `canon/dom/items/taubstummer-axe.json`, applied by
`tools/seed_pandora.gd`. The existing vendor-item seeder authors the hammer and
spear. Both add integer Pandora properties, with neutral defaults for absent
values. The generator emits optional `attack_bonus` / `defense_bonus` only when
nonzero; exactly the three ruled prototypes have bonuses.

Pandora was seeded through its documented temporary-autoload entrypoint, followed
by `scripts/seed_town_npcs.sh` and `tools/generate_gloot.gd`. `data.pandora` and
`data/generated/gloot_prototree.json` are tool outputs; neither was hand-edited.
No vendor addon was edited.

## Changed files

| Area | Files |
|---|---|
| Data | `canon/dom/items/taubstummer-axe.json`; `tools/seed_pandora.gd`; `tools/seed_town_vendors.gd`; `tools/generate_gloot.gd`; `data.pandora`; `data/generated/gloot_prototree.json` |
| Systems/save/combat | `globals/party_member.gd`; `globals/game_state.gd`; `globals/battle_actor.gd`; `globals/save_migrations.gd` |
| Inventory | `ui/screens/inventory.gd` |
| Automated fixtures | `test/unit/test_equipment.gd` and its `.uid`; `test/unit/test_save_equipment.gd` and its `.uid`; `test/unit/test_save_schema_six.gd`; `test/unit/test_save_migrations.gd`; `test/unit/test_save_migration_sweep.gd`; `test/integration/test_equipment_combat.gd` and its `.uid`; `test/integration/test_inventory_screen.gd` |
| Capture fixtures/handoff | `test/manual/art_followup_capture.gd`; `test/manual/ledger_menu_capture.gd`; this document |

`globals/save_game.gd` already derives its version from SaveMigrations and required
no edit. Existing scene/node paths and existing UID references were preserved.

## Checks with results

Godot: `4.7.1.stable.official.a13da4feb`. All final commands below exited **0**.
Test output summaries are verbatim with ANSI color escapes removed.

Xvfb was attempted first and exited **1**: `ERROR: X11 Display is not available`
and `ERROR: Unable to create DisplayServer, all display drivers failed.`
The authorized headless fallback was used for the test runs. Each run had its own
`SOUL_METER_TEST_DATA_DIR`. This is automated state/action evidence, not rendered
or pointer-input proof. The drift script itself always runs headlessly.

```text
env GODOT_BIN=/home/adamjroder/.local/bin/godot LP_NUM_THREADS=1 SOUL_METER_HEADLESS=1 SOUL_METER_TEST_DATA_DIR=/tmp/soul-meter-p14-final-unit bash scripts/test.sh -a test/unit
Overall Summary: 1976 test cases | 0 errors | 0 failures | 0 flaky | 0 skipped | 0 orphans |
Total execution time: 3min 21s 478ms
Exit code: 0

env GODOT_BIN=/home/adamjroder/.local/bin/godot LP_NUM_THREADS=1 SOUL_METER_HEADLESS=1 SOUL_METER_TEST_DATA_DIR=/tmp/soul-meter-p14-final-e2e bash scripts/test.sh -a test/e2e
Overall Summary: 21 test cases | 0 errors | 0 failures | 0 flaky | 0 skipped | 0 orphans |
Total execution time: 3s 963ms
Exit code: 0

env GODOT_BIN=/home/adamjroder/.local/bin/godot LP_NUM_THREADS=1 SOUL_METER_HEADLESS=1 SOUL_METER_TEST_DATA_DIR=/tmp/soul-meter-p14-final-saves bash scripts/test.sh -a test/unit/test_save_game.gd -a test/unit/test_save_schema_six.gd -a test/unit/test_save_migration_dramgid.gd -a test/unit/test_save_migration_sweep.gd -a test/unit/test_save_equipment.gd -a test/unit/test_save_migrations.gd
Overall Summary: 94 test cases | 0 errors | 0 failures | 0 flaky | 0 skipped | 0 orphans |
Total execution time: 1s 188ms
Exit code: 0

env GODOT_BIN=/home/adamjroder/.local/bin/godot LP_NUM_THREADS=1 SOUL_METER_HEADLESS=1 SOUL_METER_TEST_DATA_DIR=/tmp/soul-meter-p14-final-integrations bash scripts/test.sh -a test/integration/test_inventory_screen.gd -a test/integration/test_equipment_combat.gd -a test/integration/test_combat_controller.gd
Overall Summary: 82 test cases | 0 errors | 0 failures | 0 flaky | 0 skipped | 0 orphans |
Total execution time: 2s 116ms
Exit code: 0

env GODOT_BIN=/home/adamjroder/.local/bin/godot LP_NUM_THREADS=1 bash scripts/check_generated_data.sh
GLOOT-GEN: no drift.
CANON-SEED: no drift.
LOCATIONS-GEN: no drift.
ISO-SPRITE-GEN: no drift. 598 sprites verified.
```

Logs: `reports/p14/final-unit.log`, `final-e2e.log`, `final-saves.log`,
`final-integrations.log`, `final-generated-data.log` (same directory).
The required save suites are also included in the full unit total; these are
separate executions, not additional distinct tests.

The effects fixture submits real Strike actions against a fixed defender:
hammer damage increases by exactly 2, forecast equals execution, a miss still
does zero damage, costs/accuracy are unchanged, and range 2 remains illegal.
Inventory fixtures cover replacement, unequip, member selection, physical-copy
ownership, close/reopen, and saving while the rail is open. Save fixtures include
an actual schema-10 binary file loaded and re-saved at schema 11.

Editor import also exited 0. A fresh isolated editor configuration exposed the
vendored Dialogue Manager's old `interface/editor/code_font_size` lookup. Only
the disposable `/tmp/soul-meter-p14-editor-config/godot/editor_settings-4.7.tres`
was given that compatibility key, matching the engine's font-size default (14).
The rerun in `reports/p14/verified-import.log` has no script/parse errors or
blocked settings writes. Socket, editor-plugin teardown, and resource/RID leak
diagnostics remain in engine output; successful test totals do not claim those
diagnostics are absent. No engine crash occurred.

`git diff --check` passed. Four pre-existing untracked UID files were preserved:
`test/integration/test_loom_field_verbs.gd.uid`,
`test/unit/test_encounter_verb_audit.gd.uid`,
`test/unit/test_soul_lowest.gd.uid`, and `tools/audit_encounter_verbs.gd.uid`.

## New strings — DRAFT, owner review required

- `PARTY MEMBER`
- `UNEQUIP`
- `EQUIPPED BY %s — UNEQUIP THERE FIRST`
- `ATTACK BONUS  %+d`
- `DEFENSE BONUS  %+d`

All are marked DRAFT in the inventory source and passed through gettext `tr()`.

## Risks

Rendered inventory layout and real pointer dragging remain unverified here;
Claude owns the requested capture. Headless tests exercise the corresponding
selection/equip/drop handlers.

The requested save format records prototype ids, so equivalent physical copies
are rebound deterministically on load. Runtime ownership preserves actual item
references across bag/party reordering; no per-instance combat modifiers were added.

The engine/editor diagnostics above are environmental/vendor limitations, kept
visible in the logs. Required automated checks all completed successfully.

## Open decisions

Owner approval of the five DRAFT strings; no additional weapon effects or balance
decisions were made.

## Implementation commits

- `9ff193c4683584b492733380f441f83677bac669` — Pandora-authored provisional bonuses.
- `4728799f83d222852b9ba10d73dac85b51a56c76` — per-member combat stats and schema 11.
- `717ef75b7926b8fbdccdadf12d8bdeac9dd818dd` — member picker and physical-item ownership.

The separate documentation commit containing this handoff is identified in the
final dispatch response.
