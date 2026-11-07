# Field density F review — 2026-11-01

**Part 1 is implemented and verified; Part 2 remains implemented in the prior commit.** Branch: `codex/roadmap-p1-2f-items-tables`. The owner accepted all of [the item/loot packet](item-loot-draft-packet-2026-10-31.md) on 2026-11-01 and then supplied the inventory rulings and one 18-icon generation authorization. Those instructions supersede the two blockers in this review's earlier version. The packet's historical DRAFT wording is retained as the original proposal.

## What now works

The catalogue contains **40 items (22 → 40)** and the registry contains **8 loot tables (2 → 8)**. Eighteen existing containers now draw from the six accepted regional tables. **All 29 primary field-density measurements pass**; every previously passing count is unchanged. Bellow remains 1, distinct field skills remain 16, object locks remain 24, and Ashlaren locks remain 5.

The new items comprise 10 materials, six tools and two consumables. Names, descriptions, prices, weights, loot rows and assignments match the accepted packet. All are `common`, following ordinary food, material and repair-tool peers. Consumables/materials are 1×1 and stack 10, except Forge Coal and Grain Meal stack 5. Tools are 1×1 and stack 1, except Tent Pegs stack 5 and Map Case is 1×2. Equipment slots are omitted in generated prototypes; flavour is the generator's empty string. These inventory goods introduce no use effects, equipment statistics or skill bonuses.

The original 22 prototypes and their icons, both original table definitions, vendor stock, and fixed loot are unchanged. The new tables retain two weighted draws without replacement plus one independent Sounding bonus at -10.0. Existing saved container contents retain the one-roll persistence contract; container IDs, ownership, locks and access gates are unchanged.

## Pandora data path and localization

[tools/seed_field_items.gd](../../tools/seed_field_items.gd) is an idempotent migration using the same Pandora API pattern as [tools/seed_town_vendors.gd](../../tools/seed_town_vendors.gd): `Pandora.create_entity()`, `get_entity_property().set_default_value()`, then `Pandora.save_data()`. It matches named entities within the existing categories and does not create a new data schema.

[scripts/seed_field_items.sh](../../scripts/seed_field_items.sh) uses the existing temporary-autoload approach. It restores `project.godot` on exit and runs these two tools in order:

| Temporary autoload | Tool |
|---|---|
| `FieldItemSeed` | `res://tools/seed_field_items.gd` |
| `FieldItemGenerator` | `res://tools/generate_gloot.gd` |

Exact command, exit **0**:

```bash
GODOT_BIN=/home/adamjroder/.local/bin/godot LP_NUM_THREADS=1 timeout 180 bash scripts/seed_field_items.sh > /tmp/soul-meter-f1-seed.log 2>&1
```

Verbatim success lines:

```text
FIELD-ITEM-SEED: 18 accepted field items present.
DATA-GEN: wrote 40 item prototypes, 14 vendors, 12 encounters, and 60 Dom NPCs.
```

A second invocation with output at `/tmp/soul-meter-f1-seed-repeat.log` also exited **0**. SHA-256 comparisons proved `data.pandora`, `gloot_prototree.json`, `item_ids.gd`, `items.pot`, `locale/es.po` and `project.godot` byte-identical before and after that second migration.

The canonical generator wrote all three changed `data/generated/*` files; none was hand-edited. It also merged **36 new name/description gettext keys** into `locale/es.po`, preserving existing translations. New Spanish entries are untranslated, matching the existing ordinary economy items; `ItemLocalization` uses the accepted English text as fallback. No Spanish prose was invented.

The runtime registry remains the existing authored table path; Pandora still has no ratified loot-table entity contract. Independent comparison against the packet verified every new prototype field and all six table definitions. All 22 old prototypes and both old tables compare equal to the supplied baseline `350a8013`.

## Container switches

Each row changes only `loot_table_id`, from `road-cache` to the listed table. Comparison against baseline `350a8013` confirms **18 changed properties across 11 scenes and no other scene-byte changes** in this part.

| Scene | Exact node path | New table |
|---|---|---|
| `world/interiors/item_shop.tscn` | `ItemShopInterior/LatchCrate` | `dom-workshop-stores` |
| `world/interiors/cask_warehouse.tscn` | `CaskWarehouseInterior/LockedStockCrate` | `dom-workshop-stores` |
| `world/interiors/equipment_forge.tscn` | `EquipmentForgeInterior/BracedStockCrate` | `dom-workshop-stores` |
| `world/interiors/iron_companies.tscn` | `IronCompaniesInterior/LockedSupplyCrate` | `dom-workshop-stores` |
| `world/interiors/ashlaren_millhouse.tscn` | `AshlarenMillhouseInterior/LockedSupplyCrate` | `ashlaren-mill-stores` |
| `world/interiors/ashlaren_millhouse.tscn` | `AshlarenMillhouseInterior/BracedSupplyCrate` | `ashlaren-mill-stores` |
| `world/interiors/ashlaren_weighing_hall.tscn` | `AshlarenWeighingHallInterior/LockedSupplyCrate` | `ashlaren-mill-stores` |
| `world/interiors/ashlaren_weighing_hall.tscn` | `AshlarenWeighingHallInterior/BracedSupplyCrate` | `ashlaren-mill-stores` |
| `world/interiors/kesselford_chandlery.tscn` | `KesselfordChandleryInterior/LockedSupplyCrate` | `kesselford-ferry-stores` |
| `world/interiors/kesselford_chandlery.tscn` | `KesselfordChandleryInterior/BracedSupplyCrate` | `kesselford-ferry-stores` |
| `world/interiors/kesselford_wayhouse.tscn` | `KesselfordWayhouseInterior/LockedSupplyCrate` | `kesselford-ferry-stores` |
| `world/interiors/kesselford_wayhouse.tscn` | `KesselfordWayhouseInterior/BracedSupplyCrate` | `kesselford-ferry-stores` |
| `world/long_verge.tscn` | `LongVerge/WestCache` | `verge-march-kit` |
| `world/long_verge.tscn` | `LongVerge/CampCache` | `verge-march-kit` |
| `world/hollowmere.tscn` | `Hollowmere/TrackCache` | `hollowmere-reed-kit` |
| `world/hollowmere.tscn` | `Hollowmere/LandingCache` | `hollowmere-reed-kit` |
| `world/test_room.tscn` | `TestRoom/WestCache` | `wilds-repair-cache` |
| `world/test_room.tscn` | `TestRoom/GladeCache` | `wilds-repair-cache` |

Dorthkor Road's roadside table, its fixed camp cache, Wound Lip's fixed caches, and every unlisted container retain their prior contents/assignments.

## Icon batch and provenance

[Contact sheet](item-icons-2026-11-01.png): all 18 new icons in a labelled grid beside four existing references. [Provenance](../../assets/generated/sprites/items/provenance-2026-11-01.json) records the generator, full prompt, original source path and SHA-256, final destination and SHA-256, attempts, source/output dimensions, alpha counts, normalization, review status and batch for each icon.

**18 generations used; one attempt per icon; no retries or discarded alternatives.** Every icon has generator `codex built-in image generation`, status `draft-for-owner-review`, and batch `owner 2026-11-01, 18 icons`.

Before generation, the existing Binding Thread, Hearthloaf, Field Needle and Lamp Oil icons were opened and inspected. Prompts explicitly described their warm upper-left directional key light, dark lower/right falloff, restrained cool edge reflections, dark brown/charcoal/iron palette, worn painterly surfaces, close three-quarter top-down framing and isolated transparent background. The Part I avoid-list was included: no black sticker outlines, flat/even lighting, cartoon/chibi proportions, bright generic fantasy, steampunk machinery, baked text or UI.

The service returned 1254×1254 RGBA sources with genuine alpha. [tools/prepare_field_item_icons.py](../../tools/prepare_field_item_icons.py) only resamples them to 256×256 with Lanczos, records their provenance and composes the requested QA sheet. It does not repaint or remove backgrounds. Original sources remain at the recorded built-in generator paths.

Exact packaging command, exit **0**:

```bash
/usr/bin/python3 tools/prepare_field_item_icons.py /tmp/soul-meter-f1-icon-records.json
```

```text
ICON-BATCH: 18 RGBA PNGs, 256x256, real transparent alpha; provenance and contact sheet written.
ICON-BATCH: 18 generations used.
```

The initial `python3` invocation selected Homebrew Python 3.14, which lacks Pillow. Using the already installed `/usr/bin/python3` with Pillow resolved packaging without installation or downloads. The committed provenance can also serve as the manifest on this machine while its recorded original sources remain available:

```bash
/usr/bin/python3 tools/prepare_field_item_icons.py assets/generated/sprites/items/provenance-2026-11-01.json
```

All final PNGs were checked for RGBA mode, 256×256 size, alpha extrema 0/255 and matching hashes. The game contract test loaded all 40 icons successfully. The contact sheet was visually inspected; silhouettes, materials and style read coherently beside the references. **No particular icon requires a retry or has an unresolved identified defect.** All remain drafts for owner review. No other art was generated.

| Item id | PNG | Attempts |
|---|---|---:|
| `materials/forge_coal` | `assets/generated/sprites/items/forge_coal--icon.png` | 1 |
| `materials/leather_offcuts` | `assets/generated/sprites/items/leather_offcuts--icon.png` | 1 |
| `tools/rivet_punch` | `assets/generated/sprites/items/rivet_punch--icon.png` | 1 |
| `materials/grain_meal` | `assets/generated/sprites/items/grain_meal--icon.png` | 1 |
| `materials/sackcloth` | `assets/generated/sprites/items/sackcloth--icon.png` | 1 |
| `tools/grain_scoop` | `assets/generated/sprites/items/grain_scoop--icon.png` | 1 |
| `materials/ferry_line` | `assets/generated/sprites/items/ferry_line--icon.png` | 1 |
| `materials/lamp_wicks` | `assets/generated/sprites/items/lamp_wicks--icon.png` | 1 |
| `materials/stopper_wax` | `assets/generated/sprites/items/stopper_wax--icon.png` | 1 |
| `consumables/road_crusts` | `assets/generated/sprites/items/road_crusts--icon.png` | 1 |
| `tools/tent_pegs` | `assets/generated/sprites/items/tent_pegs--icon.png` | 1 |
| `tools/map_case` | `assets/generated/sprites/items/map_case--icon.png` | 1 |
| `materials/cut_reeds` | `assets/generated/sprites/items/cut_reeds--icon.png` | 1 |
| `materials/net_cord` | `assets/generated/sprites/items/net_cord--icon.png` | 1 |
| `tools/netting_needle` | `assets/generated/sprites/items/netting_needle--icon.png` | 1 |
| `consumables/cloth_bandage` | `assets/generated/sprites/items/cloth_bandage--icon.png` | 1 |
| `materials/repair_splints` | `assets/generated/sprites/items/repair_splints--icon.png` | 1 |
| `tools/stitching_thimble` | `assets/generated/sprites/items/stitching_thimble--icon.png` | 1 |

Godot-generated import sidecars accompany the PNGs, following the 22 existing item icons and existing QA images. Their metadata was generated by the editor, not hand-authored.

## Commands and checks

Engine: `Godot Engine v4.7.1.stable.official.a13da4feb`. Runtime data directories were isolated with `mktemp`. No branch change, push, PR, `gh` command, vendor-addon edit, owner-decision edit or roadmap edit occurred.

### Import and display limitation

After packaging, the assets were imported using:

```bash
LP_NUM_THREADS=1 XDG_DATA_HOME=$(mktemp -d /tmp/soul-meter-f1-import.XXXXXX) timeout 180 /home/adamjroder/.local/bin/godot --headless --editor --import --path . --quit > /tmp/soul-meter-f1-import.log 2>&1
```

Exit **0**, and the subsequent 40-icon load/size/alpha test passes. The editor emitted socket-creation restrictions, PhantomCamera/Pandora shutdown messages, an existing fixture UID duplicate, inability to save global editor settings outside this sandbox, and shutdown resource diagnostics. These are not presented as a clean rendered run.

The economy suite first attempted the default Xvfb path:

```bash
GODOT_BIN=/home/adamjroder/.local/bin/godot LP_NUM_THREADS=1 SOUL_METER_TEST_DATA_DIR=$(mktemp -d /tmp/soul-meter-f1-economy-xvfb.XXXXXX) timeout 600 bash scripts/test.sh -a test/unit/test_vendors.gd -a test/unit/test_vendor_pricing.gd -a test/unit/test_inventory.gd -a test/unit/test_game_state_inventory.gd -a test/unit/test_loot_tables.gd -a test/unit/test_loot_container.gd > /tmp/soul-meter-f1-economy-xvfb.log 2>&1
```

Exit **1** before test execution. Verbatim display errors:

```text
ERROR: X11 Display is not available
WARNING: Display driver x11 failed, falling back to wayland.
ERROR: Can't connect to a Wayland display.
ERROR: Could not initialize the Wayland thread.
ERROR: Can't create the Wayland display server.
ERROR: Unable to create DisplayServer, all display drivers failed.
```

The authorized **headless fallback** was used for all successful suites below. The inspected contact sheet is art evidence; no rendered inventory-screen or pointer-input acceptance is claimed.

### Required unit suite

```bash
GODOT_BIN=/home/adamjroder/.local/bin/godot LP_NUM_THREADS=1 SOUL_METER_HEADLESS=1 SOUL_METER_TEST_DATA_DIR=$(mktemp -d /tmp/soul-meter-f1-unit.XXXXXX) timeout 5400 bash scripts/test.sh -a test/unit > /tmp/soul-meter-f1-unit.log 2>&1
```

Exit **0**, verbatim:

```text
Overall Summary: 1987 test cases | 0 errors | 0 failures | 0 flaky | 0 skipped | 0 orphans |
Executed test suites: (194/194)
Executed test cases : (1987/1987)
Total execution time: 2min 44s 746ms
Exit code: 0
```

The only test-source change updates the catalogue count from 22 to 40 in both assertions of `test_generated_data.gd`; all existing icon-load, exact-path, dimension and alpha checks remain intact. The icon contract test passed for all 40 entries.

Shutdown diagnostics, verbatim:

```text
WARNING: 400174 ObjectDB instances were leaked at exit (run with `--verbose` for details).
ERROR: 74 resources still in use at exit (run with --verbose for details).
```

### Required E2E suite

```bash
GODOT_BIN=/home/adamjroder/.local/bin/godot LP_NUM_THREADS=1 SOUL_METER_HEADLESS=1 SOUL_METER_TEST_DATA_DIR=$(mktemp -d /tmp/soul-meter-f1-e2e.XXXXXX) timeout 1800 bash scripts/test.sh -a test/e2e > /tmp/soul-meter-f1-e2e.log 2>&1
```

Exit **0**, verbatim:

```text
Overall Summary: 21 test cases | 0 errors | 0 failures | 0 flaky | 0 skipped | 0 orphans |
Executed test suites: (2/2)
Executed test cases : (21/21)
Total execution time: 4s 518ms
Exit code: 0
```

Shutdown diagnostics, verbatim:

```text
WARNING: 8485 ObjectDB instances were leaked at exit (run with `--verbose` for details).
ERROR: 56 resources still in use at exit (run with --verbose for details).
ERROR: 3 RID allocations of type 'PN13RendererDummy14TextureStorage12DummyTextureE' were leaked at exit.
```

The E2E log includes 74 `ERROR: Parameter "data.tree" is null.` messages; the prior run's `/tmp/soul-meter-f-e2e.log` contains the same 74. Unit logs likewise contain 86 in both prior/current runs. These runtime diagnostics persist despite passing suite assertions and are disclosed rather than counted as newly passing behavior.

### Vendor/inventory/loot suites

```bash
GODOT_BIN=/home/adamjroder/.local/bin/godot LP_NUM_THREADS=1 SOUL_METER_HEADLESS=1 SOUL_METER_TEST_DATA_DIR=$(mktemp -d /tmp/soul-meter-f1-economy.XXXXXX) timeout 600 bash scripts/test.sh -a test/unit/test_vendors.gd -a test/unit/test_vendor_pricing.gd -a test/unit/test_inventory.gd -a test/unit/test_game_state_inventory.gd -a test/unit/test_loot_tables.gd -a test/unit/test_loot_container.gd > /tmp/soul-meter-f1-economy.log 2>&1
```

Exit **0**, verbatim:

```text
Overall Summary: 51 test cases | 0 errors | 0 failures | 0 flaky | 0 skipped | 0 orphans |
Executed test suites: (6/6)
Executed test cases : (51/51)
Total execution time: 590ms
Exit code: 0
```

Shutdown diagnostics, verbatim:

```text
WARNING: 5243 ObjectDB instances were leaked at exit (run with `--verbose` for details).
ERROR: 13 resources still in use at exit (run with --verbose for details).
```

### Required generated-data drift guard

```bash
GODOT_BIN=/home/adamjroder/.local/bin/godot LP_NUM_THREADS=1 timeout 600 bash scripts/check_generated_data.sh > /tmp/soul-meter-f1-drift.log 2>&1
```

Exit **0**, verbatim success lines:

```text
GLOOT-GEN: no drift.
CANON-SEED: no drift.
LOCATIONS-GEN: no drift.
ISO-SPRITE-GEN: no drift. 598 sprites verified.
```

The four processes also report ObjectDB/resource-at-exit diagnostics (respectively 5539/15, 5595/15, 5245/15 and 5241/13). No drift stage failed. `project.godot` was restored exactly.

`gdlint tools/seed_field_items.gd` reports `Success: no problems found`. `bash -n scripts/seed_field_items.sh` and `git diff --check` pass.

### Field audit commands and before/after

Before command, exit **0**:

```bash
LP_NUM_THREADS=1 XDG_DATA_HOME=$(mktemp -d /tmp/soul-meter-f1-audit-before.XXXXXX) timeout 60 /home/adamjroder/.local/bin/godot --headless --path . --script res://tools/audit_field_coverage.gd > /tmp/soul-meter-f1-audit-before.log 2>&1
```

After command, exit **0**:

```bash
LP_NUM_THREADS=1 XDG_DATA_HOME=$(mktemp -d /tmp/soul-meter-f1-audit-after.XXXXXX) timeout 60 /home/adamjroder/.local/bin/godot --headless --path . --script res://tools/audit_field_coverage.gd > /tmp/soul-meter-f1-audit-after.log 2>&1
```

The final after audit was rerun after importing assets because the earlier run also emitted a shader-preload cache error. That additional error is absent from the final run. The audit's existing main-menu class-resolution diagnostics remain in both baseline and final logs below.

**Primary audit: 27/29 → 29/29 PASS.** Only Items (22 → 40) and Loot tables (2 → 8) change; all other primary counts, per-skill diagnostic rows and source/classification notes are unchanged. The zero-count skill rows and SUPERSEDED comparison are diagnostics, not requirements to fill every skill. The provisional target/source notes remain as printed; this task does not ratify global density targets.

#### Audit before (verbatim)

```text
Godot Engine v4.7.1.stable.official.a13da4feb - https://godotengine.org

Field coverage audit — P1.2 slice A
Judge the printed report, never the exit code.
PROVISIONAL targets: brief citing owner-decisions R7 / item 11c; not ratified here.
Shipped registry world scenes: 33 (templates and test fixtures excluded).

PROVISIONAL density measurements
Measurement | Count | Target | Result
Distinct field skills / 22 | 16 | >= 15 | PASS
Bellow checks | 1 | >= 1 | PASS
Verb: lockpick | 24 | >= 5 | PASS
Verb: pickpocket/steal | 41 | >= 5 | PASS
Verb: loot container | 38 | >= 5 | PASS
Verb: cache | 18 | >= 5 | PASS
Verb: barter | 16 | >= 5 | PASS
Verb (info): talk | 88 | — | INFO
Verb (info): pickup | 5 | — | INFO
Verb (info): switch | 1 | — | INFO
Verb (info): inspect/interact | 10 | — | INFO
Verb (info): save | 1 | — | INFO
Verb (info): travel | 67 | — | INFO
Verb (info): party selection | 1 | — | INFO
Verb (info): damage structure | 0 | — | INFO
Hub dom: locks | 4 | >= 4 | PASS
Hub dom: pockets | 3 | >= 3 | PASS
Hub dom: loot-table containers | 4 | >= 4 | PASS
Hub ashlaren: locks | 5 | >= 4 | PASS
Hub ashlaren: pockets | 3 | >= 3 | PASS
Hub ashlaren: loot-table containers | 4 | >= 4 | PASS
Hub kesselford: locks | 4 | >= 4 | PASS
Hub kesselford: pockets | 3 | >= 3 | PASS
Hub kesselford: loot-table containers | 4 | >= 4 | PASS
Hub long_verge: locks | 5 | >= 4 | PASS
Hub long_verge: pockets | 3 | >= 3 | PASS
Hub long_verge: loot-table containers | 6 | >= 4 | PASS
Hub hollowmere: locks | 5 | >= 4 | PASS
Hub hollowmere: pockets | 3 | >= 3 | PASS
Hub hollowmere: loot-table containers | 6 | >= 4 | PASS
Wild dorthkor_road: caches | 2 | >= 2 | PASS
Wild hollowmere: caches | 6 | >= 2 | PASS
Wild long_verge: caches | 6 | >= 2 | PASS
Wild wilds: caches | 2 | >= 2 | PASS
Wild wound_lip: caches | 2 | >= 2 | PASS
Loot tables | 2 | >= 8 | FAIL
Items | 22 | >= 40 | FAIL

Field skill occurrences (>= 1 contributes to the 15/22 target; no quota for every skill)
Skill | Checks | Presence contribution | Result
Strain | 9 | >= 1 | PASS
Lilt | 0 | >= 1 | FAIL
Slip | 27 | >= 1 | PASS
Tread | 1 | >= 1 | PASS
Beastbond | 1 | >= 1 | PASS
Varlore | 0 | >= 1 | FAIL
Unweave | 2 | >= 1 | PASS
Recall | 1 | >= 1 | PASS
Wildlore | 1 | >= 1 | PASS
Devotion | 1 | >= 1 | PASS
Undertone | 3 | >= 1 | PASS
Mending | 0 | >= 1 | FAIL
Ear | 1 | >= 1 | PASS
Wayfinding | 1 | >= 1 | PASS
Sounding | 29 | >= 1 | PASS
Falsetto | 0 | >= 1 | FAIL
Bellow | 1 | >= 1 | PASS
Vārum | 1 | >= 1 | PASS
Sway | 2 | >= 1 | PASS
Downbeat | 0 | >= 1 | FAIL
Brace | 0 | >= 1 | FAIL
Vantage | 1 | >= 1 | PASS

SUPERSEDED comparison only: >= 12/22 skills, each checked >= 3 times
Skills with >= 3 checks / 22 | 4 | >= 12 | FAIL
Strain | 9 | >= 3 | PASS
Lilt | 0 | >= 3 | FAIL
Slip | 27 | >= 3 | PASS
Tread | 1 | >= 3 | FAIL
Beastbond | 1 | >= 3 | FAIL
Varlore | 0 | >= 3 | FAIL
Unweave | 2 | >= 3 | FAIL
Recall | 1 | >= 3 | FAIL
Wildlore | 1 | >= 3 | FAIL
Devotion | 1 | >= 3 | FAIL
Undertone | 3 | >= 3 | PASS
Mending | 0 | >= 3 | FAIL
Ear | 1 | >= 3 | FAIL
Wayfinding | 1 | >= 3 | FAIL
Sounding | 29 | >= 3 | PASS
Falsetto | 0 | >= 3 | FAIL
Bellow | 1 | >= 3 | FAIL
Vārum | 1 | >= 3 | FAIL
Sway | 2 | >= 3 | FAIL
Downbeat | 0 | >= 3 | FAIL
Brace | 0 | >= 3 | FAIL
Vantage | 1 | >= 3 | FAIL

Counting rules: skill locks include force/strain; flag-only gates are not locks.
Caches are Chest instances in wild scenes; hub containers require a live loot table (authored loot overrides it).
Hub counts include recursively linked interiors. Pockets are NPC pockets; steal also includes owned loot/pickups.
Barter counts placed vendor/shop access points; passive Sway pricing is not a rolled skill check.
Loot searches count each distinct table skill once per placed container; unused tables add no checks.
Dialogue counts executable check calls once per source site, not tags, prose, retries, or runtime reachability.
Other verbs are explicit actor interactions; combat, automatic events, and UI-only actions are excluded.
NOTE: Classification discrepancy: brief hub hollowmere has no fast-travel facet (retained in both applicable views).
NOTE: Classification discrepancy: brief hub long_verge has no fast-travel facet (retained in both applicable views).
NOTE: Source discrepancy: roadmap-2026-10-30.md is absent; targets are from the slice-A brief.
NOTE: Source discrepancy: R7/11c answered density entries are absent; targets remain PROVISIONAL.
SCRIPT ERROR: Parse Error: Could not resolve external class member "LOAD_GAME".
   at: GDScript::reload (res://ui/screens/main_menu.gd:69)
SCRIPT ERROR: Parse Error: Could not resolve external class member "SETTINGS".
   at: GDScript::reload (res://ui/screens/main_menu.gd:74)
ERROR: Failed to load script "res://ui/screens/main_menu.gd" with error "Parse error".
   at: load (modules/gdscript/gdscript_resource_format.cpp:46)
ERROR: res://ui/screens/main_menu.tscn:7 - Parse Error: .
   at: _printerr (scene/resources/resource_format_text.cpp:41)
ERROR: Failed loading resource: res://ui/screens/main_menu.tscn.
   at: _load (core/io/resource_loader.cpp:317)
WARNING: 5065 ObjectDB instances were leaked at exit (run with `--verbose` for details).
   at: cleanup (core/object/object.cpp:2536)
ERROR: 13 resources still in use at exit (run with --verbose for details).
   at: clear (core/io/resource.cpp:822)
```

#### Audit after (verbatim)

```text
Godot Engine v4.7.1.stable.official.a13da4feb - https://godotengine.org

Field coverage audit — P1.2 slice A
Judge the printed report, never the exit code.
PROVISIONAL targets: brief citing owner-decisions R7 / item 11c; not ratified here.
Shipped registry world scenes: 33 (templates and test fixtures excluded).

PROVISIONAL density measurements
Measurement | Count | Target | Result
Distinct field skills / 22 | 16 | >= 15 | PASS
Bellow checks | 1 | >= 1 | PASS
Verb: lockpick | 24 | >= 5 | PASS
Verb: pickpocket/steal | 41 | >= 5 | PASS
Verb: loot container | 38 | >= 5 | PASS
Verb: cache | 18 | >= 5 | PASS
Verb: barter | 16 | >= 5 | PASS
Verb (info): talk | 88 | — | INFO
Verb (info): pickup | 5 | — | INFO
Verb (info): switch | 1 | — | INFO
Verb (info): inspect/interact | 10 | — | INFO
Verb (info): save | 1 | — | INFO
Verb (info): travel | 67 | — | INFO
Verb (info): party selection | 1 | — | INFO
Verb (info): damage structure | 0 | — | INFO
Hub dom: locks | 4 | >= 4 | PASS
Hub dom: pockets | 3 | >= 3 | PASS
Hub dom: loot-table containers | 4 | >= 4 | PASS
Hub ashlaren: locks | 5 | >= 4 | PASS
Hub ashlaren: pockets | 3 | >= 3 | PASS
Hub ashlaren: loot-table containers | 4 | >= 4 | PASS
Hub kesselford: locks | 4 | >= 4 | PASS
Hub kesselford: pockets | 3 | >= 3 | PASS
Hub kesselford: loot-table containers | 4 | >= 4 | PASS
Hub long_verge: locks | 5 | >= 4 | PASS
Hub long_verge: pockets | 3 | >= 3 | PASS
Hub long_verge: loot-table containers | 6 | >= 4 | PASS
Hub hollowmere: locks | 5 | >= 4 | PASS
Hub hollowmere: pockets | 3 | >= 3 | PASS
Hub hollowmere: loot-table containers | 6 | >= 4 | PASS
Wild dorthkor_road: caches | 2 | >= 2 | PASS
Wild hollowmere: caches | 6 | >= 2 | PASS
Wild long_verge: caches | 6 | >= 2 | PASS
Wild wilds: caches | 2 | >= 2 | PASS
Wild wound_lip: caches | 2 | >= 2 | PASS
Loot tables | 8 | >= 8 | PASS
Items | 40 | >= 40 | PASS

Field skill occurrences (>= 1 contributes to the 15/22 target; no quota for every skill)
Skill | Checks | Presence contribution | Result
Strain | 9 | >= 1 | PASS
Lilt | 0 | >= 1 | FAIL
Slip | 27 | >= 1 | PASS
Tread | 1 | >= 1 | PASS
Beastbond | 1 | >= 1 | PASS
Varlore | 0 | >= 1 | FAIL
Unweave | 2 | >= 1 | PASS
Recall | 1 | >= 1 | PASS
Wildlore | 1 | >= 1 | PASS
Devotion | 1 | >= 1 | PASS
Undertone | 3 | >= 1 | PASS
Mending | 0 | >= 1 | FAIL
Ear | 1 | >= 1 | PASS
Wayfinding | 1 | >= 1 | PASS
Sounding | 29 | >= 1 | PASS
Falsetto | 0 | >= 1 | FAIL
Bellow | 1 | >= 1 | PASS
Vārum | 1 | >= 1 | PASS
Sway | 2 | >= 1 | PASS
Downbeat | 0 | >= 1 | FAIL
Brace | 0 | >= 1 | FAIL
Vantage | 1 | >= 1 | PASS

SUPERSEDED comparison only: >= 12/22 skills, each checked >= 3 times
Skills with >= 3 checks / 22 | 4 | >= 12 | FAIL
Strain | 9 | >= 3 | PASS
Lilt | 0 | >= 3 | FAIL
Slip | 27 | >= 3 | PASS
Tread | 1 | >= 3 | FAIL
Beastbond | 1 | >= 3 | FAIL
Varlore | 0 | >= 3 | FAIL
Unweave | 2 | >= 3 | FAIL
Recall | 1 | >= 3 | FAIL
Wildlore | 1 | >= 3 | FAIL
Devotion | 1 | >= 3 | FAIL
Undertone | 3 | >= 3 | PASS
Mending | 0 | >= 3 | FAIL
Ear | 1 | >= 3 | FAIL
Wayfinding | 1 | >= 3 | FAIL
Sounding | 29 | >= 3 | PASS
Falsetto | 0 | >= 3 | FAIL
Bellow | 1 | >= 3 | FAIL
Vārum | 1 | >= 3 | FAIL
Sway | 2 | >= 3 | FAIL
Downbeat | 0 | >= 3 | FAIL
Brace | 0 | >= 3 | FAIL
Vantage | 1 | >= 3 | FAIL

Counting rules: skill locks include force/strain; flag-only gates are not locks.
Caches are Chest instances in wild scenes; hub containers require a live loot table (authored loot overrides it).
Hub counts include recursively linked interiors. Pockets are NPC pockets; steal also includes owned loot/pickups.
Barter counts placed vendor/shop access points; passive Sway pricing is not a rolled skill check.
Loot searches count each distinct table skill once per placed container; unused tables add no checks.
Dialogue counts executable check calls once per source site, not tags, prose, retries, or runtime reachability.
Other verbs are explicit actor interactions; combat, automatic events, and UI-only actions are excluded.
NOTE: Classification discrepancy: brief hub hollowmere has no fast-travel facet (retained in both applicable views).
NOTE: Classification discrepancy: brief hub long_verge has no fast-travel facet (retained in both applicable views).
NOTE: Source discrepancy: roadmap-2026-10-30.md is absent; targets are from the slice-A brief.
NOTE: Source discrepancy: R7/11c answered density entries are absent; targets remain PROVISIONAL.
SCRIPT ERROR: Parse Error: Could not resolve external class member "LOAD_GAME".
   at: GDScript::reload (res://ui/screens/main_menu.gd:69)
SCRIPT ERROR: Parse Error: Could not resolve external class member "SETTINGS".
   at: GDScript::reload (res://ui/screens/main_menu.gd:74)
ERROR: Failed to load script "res://ui/screens/main_menu.gd" with error "Parse error".
   at: load (modules/gdscript/gdscript_resource_format.cpp:46)
ERROR: res://ui/screens/main_menu.tscn:7 - Parse Error: .
   at: _printerr (scene/resources/resource_format_text.cpp:41)
ERROR: Failed loading resource: res://ui/screens/main_menu.tscn.
   at: _load (core/io/resource_loader.cpp:317)
WARNING: 5245 ObjectDB instances were leaked at exit (run with `--verbose` for details).
   at: cleanup (core/object/object.cpp:2536)
ERROR: 13 resources still in use at exit (run with --verbose for details).
   at: clear (core/io/resource.cpp:822)
```

## Part 2: Bellow grounding and DRAFT strings

[DRAMGID brief, SKILL.BELLOW, line 57](../briefs/dramgid-brief.md) defines Bellow as **“Intimidation; receives the negative-Karma tier bonus and is not Loom-sensitive.”** This is a challenge meant to make a guard flinch, not loudness or force applied to an object.

The existing [warehouse-watch record](../../canon/ashlaren/characters/ashlaren-warehouse-watch.json) establishes Pell Haskard as a phase-agnostic guard who stays in the warehouse yard. His existing [placement](../../data/generated/ashlaren_npc_placements.json) uses `SealedSackCrates`. The optional challenge is at `Ashlaren/WarehouseChallenge`, **(2300, 1380)**, south of `AshlarenDressing/SolidProps/YardBrazier` at (2300, 1300). It leaves the guard's dialogue, the sealed sack, all building gates, and the unresolved sack mystery unchanged. No lore source was edited.

Minimal new player-facing string set — **DRAFT for owner review**, all passed through the existing `SMInteractable.tr()` path:

| Property | DRAFT text |
|---|---|
| `display_name` | WAREHOUSE WATCH |
| `prompt_text` | CHALLENGE THE WATCH |
| `interaction_text` | The watch breaks eye contact. |
| `locked_message` | Make the warehouse watch flinch. |
| `lock_failed_message` | The watch holds your gaze. |

Durable technical IDs: `ashlaren-warehouse-challenge`, `lock_picked_ashlaren-warehouse-challenge`, `lock_failed_ashlaren-warehouse-challenge`, `chapter_ashlaren_watch_challenged`. Part 1 now adds 36 gettext keys for its accepted names and descriptions; these five Bellow strings retain their earlier draft status.

The prior Bellow runtime suite passed 2/2 in commit `2c55b849568dc3dc3bddc30578266c2d06e265c5`; it was not rerun for this data/art-only part. Current field audit still counts the Bellow opportunity and all preceding density gains.

## Changed files

| Area | Files |
|---|---|
| Authored migration and data | `tools/seed_field_items.gd`, its generated UID, `scripts/seed_field_items.sh`, `data.pandora` |
| Canonical generator outputs | `data/generated/gloot_prototree.json`, `data/generated/item_ids.gd`, `data/generated/items.pot`, `locale/es.po` |
| Runtime tables and contract | `globals/loot_table_registry.gd`, `test/unit/test_generated_data.gd` |
| Scene assignments | The 11 scene files listed in Container switches |
| Art and review | 18 PNGs and generated import sidecars listed above; `assets/generated/sprites/items/provenance-2026-11-01.json`; `tools/prepare_field_item_icons.py`; `docs/qa/item-icons-2026-11-01.png` and its generated import sidecar; this review |

The six pre-existing untracked UID files remain untouched: `test/integration/test_loom_field_verbs.gd.uid`, `test/unit/test_audit_field_coverage.gd.uid`, `test/unit/test_encounter_verb_audit.gd.uid`, `test/unit/test_soul_lowest.gd.uid`, `tools/audit_encounter_verbs.gd.uid`, `tools/audit_field_coverage.gd.uid`.

## Risks and open decisions

The 18 icons await owner aesthetic review under their required draft status. The five prior Bellow strings retain their earlier draft status. Neither is a missing implementation value. There are no remaining Part 1 inventory/icon-generation blockers.

Xvfb/display startup is unavailable; live rendered UI acceptance remains unverified. Existing main-menu audit teardown, null-tree, editor-plugin and resource-shutdown diagnostics are recorded above. The prototype/PNG contracts and all requested headless test assertions pass. New Spanish keys use English fallback until translated.

The packet approval does not settle the audit's global provisional-density source discrepancy. No owner-decision entry was edited or silently resolved.

## Commits

Earlier Slice F commits, unchanged:

- `2c55b849568dc3dc3bddc30578266c2d06e265c5` — optional warehouse-watch Bellow challenge.
- `350a801356e1ba43b53ac345fb2941f0a25d37b4` — earlier Slice F blocker/review record.

Part 1 implementation/art commit: `eb27c3f9516f1170d48bb71bd86e94680b48c878` — `feat(field): implement accepted item and loot packet` (61 files). Git metadata remained writable; the local commit succeeded. This review's documentation commit hash is supplied in the final handoff.

## Handoff back

What now works: the accepted 18-item/six-table packet, all 18 container switches, generated gettext keys, and the approved 18-icon draft batch; catalogue 40, tables 8, all 29 primary density checks passing.

Changed files: the scoped data, migration, registry, 11 scenes, contract-count update, icons/provenance/contact sheet and review listed above.

Checks with results: unit 1987/1987; E2E 21/21; vendor/inventory/loot 51/51; all four drift stages pass. Exact commands, verbatim summaries, runtime diagnostics and complete audit logs are above. All successful test runs used the headless fallback after Xvfb failed.

Audit before/after: items 22→40, tables 2→8; Bellow 1→1, distinct field skills 16→16; every other primary measurement unchanged and passing.

Icon batch: 18 generations, one per icon, no retries; all 256×256 RGBA with genuine alpha. No identified icon requiring a retry; all remain draft-for-owner-review.

Risks: rendered in-game UI acceptance unavailable; existing runtime/editor diagnostics persist; Spanish entries use English fallback.

Open decisions: owner review of the draft icon batch and previously drafted Bellow strings; global density target provenance remains provisional.

Commits: Part 1 `eb27c3f9516f1170d48bb71bd86e94680b48c878`; earlier Part 2 `2c55b849568dc3dc3bddc30578266c2d06e265c5`; earlier review `350a801356e1ba43b53ac345fb2941f0a25d37b4`. This review's documentation commit hash is supplied in the final handoff.
