# Field density F review — 2026-11-01

**Partial delivery: Part 2 is implemented; Part 1 is blocked by missing item inventory values and icons.** Branch: `codex/roadmap-p1-2f-items-tables`, on the supplied slice-E baseline. No network, branch changes, art changes, vendor-addon changes, owner-decision edits, or roadmap edits.

## What now works

`Ashlaren/WarehouseChallenge` adds an optional Bellow object check beside the existing yard brazier, directed at the existing warehouse watch. It uses `SMInteractable`, the existing **0.0** lock modifier, the existing single-attempt flags, ordinary feedback, and save serialization. Passing records `chapter_ashlaren_watch_challenged`; failure records the existing lock-failure flag. The outcome survives save/load and cannot be rerolled. It grants no access, loot, progression, reputation change, or combat modifier.

The actual field audit improves **Bellow 0 → 1**, **distinct skills 15 → 16**, **object locks 23 → 24**, and **Ashlaren locks 4 → 5**. Every previously passing primary density measurement still passes. **Items remain 22/40; tables remain 2/8. Slice F is not complete.**

## Part 1: accepted content and the precise blocker

The dispatch explicitly records owner item 30a, **accept all, 2026-11-01**, for [the 18-item / six-table packet](item-loot-draft-packet-2026-10-31.md). That approval is accepted here despite the packet's older DRAFT heading. The packet was not changed.

**A documented headless Pandora write path exists. This is not an editor-only/API blocker.** [DEPENDENCIES.md](../../DEPENDENCIES.md), [the regeneration workflow](../skills/pandora-gloot-regeneration.md), [scripts/seed_town_npcs.sh](../../scripts/seed_town_npcs.sh), and the tools menu in [addons/soul_meter_tools/plugin.gd](../../addons/soul_meter_tools/plugin.gd) establish the supported pipeline:

- [tools/seed_pandora.gd](../../tools/seed_pandora.gd) supplies six base items; [tools/seed_quest_content.gd](../../tools/seed_quest_content.gd) adds Loamroot Sprig; [tools/seed_town_vendors.gd](../../tools/seed_town_vendors.gd) adds 15 authored economy items, yielding 22. These migrations use `Pandora.create_entity()`, authored values through `get_entity_property().set_default_value()`, and `Pandora.save_data()`; the vendor migration upserts existing named entities.
- [tools/generate_gloot.gd](../../tools/generate_gloot.gd) reads Pandora and emits the GLoot prototypes, typed item IDs, `items.pot`, and merged `locale/es.po`. [ItemLocalization](../../globals/item_localization.gd) supplies the existing translated-name/description path and English fallback.
- [LootTableRegistry](../../globals/loot_table_registry.gd) owns the two authored runtime tables because no ratified Pandora loot-table entity contract exists. Extending that registry is the existing supported table path; introducing a new Pandora table schema is unnecessary.

Two concrete constraints prevent a valid implementation without an additional owner decision:

1. **The accepted packet specifies neither Grid Size nor Max Stack Size for any new item.** The current Pandora Items schema defaults are `Grid Size = (0,0)` and `Max Stack Size = 0`. The generator emits both explicitly. GLoot therefore receives zero-sized items and zero stack capacity, rather than its absent-property defaults. Its stack setter rejects a stack of one against a maximum of zero. Copying another item's values or changing the generator to substitute values would choose unapproved inventory/economy behavior under this dispatch's “Do not decide: any value not in the accepted packet.”
2. **All 18 mandatory item icons are missing.** The generator unconditionally emits `res://assets/generated/sprites/items/<slug>--icon.png`. The existing generated-data test requires each exact, distinct path to load a transparent 256×256 image. This handoff forbids art. Creating icons, borrowing another item's icon, or weakening that contract is outside the authorization.

References: generator lines 149–163; `test/unit/test_generated_data.gd:63`; `addons/gloot/core/constraints/grid_constraint.gd:168`; `addons/gloot/core/stack_manager.gd:25`. These vendor files were only read.

Read-only preflight output:

```text
Packet item rows: 18; missing mandatory icons: 18
Pandora inherited inventory defaults: [('Max Stack Size', 0), ('Grid Size', '(0,0)')]
```

**No new item or loot-table data was inserted.** `data.pandora`, `globals/loot_table_registry.gd`, all generated artifacts, localization files, and the existing icon test remain unchanged. Adding tables that name absent items or switching containers to absent tables would create broken loot, so neither was done. The missing decisions are reported here, not added to the forbidden owner-decision file.

### Container switches by node path

**Actual switches: none.** Each of these 18 accepted assignments still points to `road-cache` pending the blocked item implementation.

| Scene | Node paths, including root | Accepted destination, not applied |
|---|---|---|
| `world/interiors/item_shop.tscn` | `ItemShopInterior/LatchCrate` | `dom-workshop-stores` |
| `world/interiors/cask_warehouse.tscn` | `CaskWarehouseInterior/LockedStockCrate` | `dom-workshop-stores` |
| `world/interiors/equipment_forge.tscn` | `EquipmentForgeInterior/BracedStockCrate` | `dom-workshop-stores` |
| `world/interiors/iron_companies.tscn` | `IronCompaniesInterior/LockedSupplyCrate` | `dom-workshop-stores` |
| `world/interiors/ashlaren_millhouse.tscn` | `AshlarenMillhouseInterior/LockedSupplyCrate`, `AshlarenMillhouseInterior/BracedSupplyCrate` | `ashlaren-mill-stores` |
| `world/interiors/ashlaren_weighing_hall.tscn` | `AshlarenWeighingHallInterior/LockedSupplyCrate`, `AshlarenWeighingHallInterior/BracedSupplyCrate` | `ashlaren-mill-stores` |
| `world/interiors/kesselford_chandlery.tscn` | `KesselfordChandleryInterior/LockedSupplyCrate`, `KesselfordChandleryInterior/BracedSupplyCrate` | `kesselford-ferry-stores` |
| `world/interiors/kesselford_wayhouse.tscn` | `KesselfordWayhouseInterior/LockedSupplyCrate`, `KesselfordWayhouseInterior/BracedSupplyCrate` | `kesselford-ferry-stores` |
| `world/long_verge.tscn` | `LongVerge/WestCache`, `LongVerge/CampCache` | `verge-march-kit` |
| `world/hollowmere.tscn` | `Hollowmere/TrackCache`, `Hollowmere/LandingCache` | `hollowmere-reed-kit` |
| `world/test_room.tscn` | `TestRoom/WestCache`, `TestRoom/GladeCache` | `wilds-repair-cache` |

The eight additional slice-E containers in Long Verge and Hollowmere are not named in the packet and remain on `road-cache`. Fixed-loot containers are untouched.

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

Durable technical IDs: `ashlaren-warehouse-challenge`, `lock_picked_ashlaren-warehouse-challenge`, `lock_failed_ashlaren-warehouse-challenge`, `chapter_ashlaren_watch_challenged`. There are no new translated item strings because Part 1 was not applied.

## Commands and checks

All commands ran from the repository root with `~/.local/bin/godot` (reported **4.7.1.stable.official.a13da4feb**). Each independent run received a fresh temporary user-data directory. Full raw logs are in `/tmp/soul-meter-f-*.log` for this worker session; excerpts below preserve engine/test output text, with terminal color escapes removed.

### Regeneration, followed by the required drift guard

No import command was run and no Pandora write occurred. To regenerate the existing data through the documented temporary-autoload mechanism, the native patch tool temporarily added this line immediately after `Pandora=...` in `project.godot`:

```ini
SliceFGenerator="*res://tools/generate_gloot.gd"
```

Exact engine command:

```bash
XDG_DATA_HOME="$(mktemp -d /tmp/soul-meter-f-regenerate.XXXXXX)" LP_NUM_THREADS=1 timeout 120 "$HOME/.local/bin/godot" --headless --path . --quit-after 30 > /tmp/soul-meter-f-regenerate.log 2>&1
```

The native patch tool then removed that temporary line. `project.godot` and all generated files have zero net diff. Exit **0**, verbatim:

```text
DATA-GEN: wrote 22 item prototypes, 14 vendors, 12 encounters, and 60 Dom NPCs.
```

```bash
GODOT_BIN="$HOME/.local/bin/godot" LP_NUM_THREADS=1 timeout 240 bash scripts/check_generated_data.sh > /tmp/soul-meter-f-drift.log 2>&1
```

Exit **0**, verbatim:

```text
GLOOT-GEN: no drift.
CANON-SEED: no drift.
LOCATIONS-GEN: no drift.
ISO-SPRITE-GEN: no drift. 598 sprites verified.
```

The regeneration/drift processes also print resource-at-exit warnings (13 or 15 resources); no drift or parse failure is hidden by those summaries.

### Xvfb attempt and headless fallback

```bash
GODOT_BIN="$HOME/.local/bin/godot" LP_NUM_THREADS=1 SOUL_METER_TEST_DATA_DIR="$(mktemp -d /tmp/soul-meter-f-bellow-xvfb.XXXXXX)" timeout 180 bash scripts/test.sh -a test/integration/test_ashlaren_bellow.gd > /tmp/soul-meter-f-bellow-xvfb.log 2>&1
```

Exit **1**, before test execution. Verbatim failure lines:

```text
ERROR: X11 Display is not available
ERROR: Can't connect to a Wayland display.
ERROR: Could not initialize the Wayland thread.
ERROR: Can't create the Wayland display server.
ERROR: Unable to create DisplayServer, all display drivers failed.
```

The remaining tests use the explicitly authorized CI-equivalent fallback: `SOUL_METER_HEADLESS=1`, which makes `scripts/test.sh` pass `--ignoreHeadlessMode` to gdUnit4. **Rendered correctness and transported keyboard input remain unverified.** The new runtime test exercises the existing interaction handler directly after real scene loading, navigation lookup, physics range entry, and prompt checks.

### Bellow runtime suite

```bash
GODOT_BIN="$HOME/.local/bin/godot" LP_NUM_THREADS=1 SOUL_METER_HEADLESS=1 SOUL_METER_TEST_DATA_DIR="$(mktemp -d /tmp/soul-meter-f-bellow-headless.XXXXXX)" timeout 240 bash scripts/test.sh -a test/integration/test_ashlaren_bellow.gd > /tmp/soul-meter-f-bellow-headless.log 2>&1
```

Exit **0**, verbatim:

```text
Overall Summary: 2 test cases | 0 errors | 0 failures | 0 flaky | 0 skipped | 0 orphans |
Executed test suites: (1/1)
Executed test cases : (2/2)
Total execution time: 593ms
Exit code: 0
```

Coverage: a real path from the player to the challenge; physics range/prompt activation; separation from the guard's talk radius; Bellow/modifier/check-ID recording; one attempt; save/load persistence; restored success and failure prompts. The first test run waited only five frames after teleporting the test player and failed its range assertions. Waiting twenty frames, as the existing Ashlaren prompt test does, fixes the fixture; the scene needed no change. Existing empty Blocking-layer and resource-at-exit warnings remain.

### Required unit, E2E, and vendor/inventory/loot suites

Full unit command:

```bash
GODOT_BIN="$HOME/.local/bin/godot" LP_NUM_THREADS=1 SOUL_METER_HEADLESS=1 SOUL_METER_TEST_DATA_DIR="$(mktemp -d /tmp/soul-meter-f-unit.XXXXXX)" timeout 5400 bash scripts/test.sh -a test/unit > /tmp/soul-meter-f-unit.log 2>&1
```

Exit **0**, verbatim:

```text
Overall Summary: 1987 test cases | 0 errors | 0 failures | 0 flaky | 0 skipped | 0 orphans |
Executed test suites: (194/194)
Executed test cases : (1987/1987)
Total execution time: 3min 15s 948ms
Exit code: 0
```

The unit process also reports these shutdown diagnostics after its successful test summary:

```text
WARNING: 388132 ObjectDB instances were leaked at exit (run with `--verbose` for details).
ERROR: 74 resources still in use at exit (run with --verbose for details).
```

E2E command:

```bash
GODOT_BIN="$HOME/.local/bin/godot" LP_NUM_THREADS=1 SOUL_METER_HEADLESS=1 SOUL_METER_TEST_DATA_DIR="$(mktemp -d /tmp/soul-meter-f-e2e.XXXXXX)" timeout 1800 bash scripts/test.sh -a test/e2e > /tmp/soul-meter-f-e2e.log 2>&1
```

Exit **0**, verbatim:

```text
Overall Summary: 21 test cases | 0 errors | 0 failures | 0 flaky | 0 skipped | 0 orphans |
Executed test suites: (2/2)
Executed test cases : (21/21)
Total execution time: 4s 60ms
Exit code: 0
```

The E2E process reports 8305 ObjectDB leaks, 56 resources still in use, and 3 dummy-renderer texture RID leaks on shutdown after the successful summary.

Explicit vendor/inventory/loot unit command:

```bash
GODOT_BIN="$HOME/.local/bin/godot" LP_NUM_THREADS=1 SOUL_METER_HEADLESS=1 SOUL_METER_TEST_DATA_DIR="$(mktemp -d /tmp/soul-meter-f-economy.XXXXXX)" timeout 600 bash scripts/test.sh -a test/unit/test_vendors.gd -a test/unit/test_vendor_pricing.gd -a test/unit/test_inventory.gd -a test/unit/test_game_state_inventory.gd -a test/unit/test_loot_tables.gd -a test/unit/test_loot_container.gd > /tmp/soul-meter-f-economy.log 2>&1
```

Exit **0**, verbatim:

```text
Overall Summary: 51 test cases | 0 errors | 0 failures | 0 flaky | 0 skipped | 0 orphans |
Executed test suites: (6/6)
Executed test cases : (51/51)
Total execution time: 621ms
Exit code: 0
```

The focused economy process reports the same 5067 ObjectDB / 15 resource shutdown warnings as the Bellow runtime run. `git diff --check` passed. A read-only check confirmed all 18 packet container paths still have `road-cache`, all relative links in this review resolve, and the world scenes contain exactly one authored Bellow lock.

### Field audit commands

```bash
XDG_DATA_HOME="$(mktemp -d /tmp/soul-meter-f-audit-before.XXXXXX)" LP_NUM_THREADS=1 timeout 60 "$HOME/.local/bin/godot" --headless --path . --script res://tools/audit_field_coverage.gd > /tmp/soul-meter-f-audit-before.log 2>&1
XDG_DATA_HOME="$(mktemp -d /tmp/soul-meter-f-audit-after.XXXXXX)" LP_NUM_THREADS=1 timeout 60 "$HOME/.local/bin/godot" --headless --path . --script res://tools/audit_field_coverage.gd > /tmp/soul-meter-f-audit-after.log 2>&1
```

Exit **0 both**. The printed audit is authoritative: Part 1 fails its two targets. Both standalone audit runs also report the same main-menu shutdown errors after printing the report; the initial run already had them before the change. Those are separate from the successful Bellow scene-runtime test. Verbatim error lines from both logs:

```text
SCRIPT ERROR: Parse Error: Could not resolve external class member "LOAD_GAME".
SCRIPT ERROR: Parse Error: Could not resolve external class member "SETTINGS".
ERROR: Failed to load script "res://ui/screens/main_menu.gd" with error "Parse error".
ERROR: res://ui/screens/main_menu.tscn:7 - Parse Error: .
ERROR: Failed loading resource: res://ui/screens/main_menu.tscn.
ERROR: 13 resources still in use at exit (run with --verbose for details).
```

## Audit before (verbatim)

```text
Field coverage audit — P1.2 slice A
Judge the printed report, never the exit code.
PROVISIONAL targets: brief citing owner-decisions R7 / item 11c; not ratified here.
Shipped registry world scenes: 33 (templates and test fixtures excluded).

PROVISIONAL density measurements
Measurement | Count | Target | Result
Distinct field skills / 22 | 15 | >= 15 | PASS
Bellow checks | 0 | >= 1 | FAIL
Verb: lockpick | 23 | >= 5 | PASS
Verb: pickpocket/steal | 41 | >= 5 | PASS
Verb: loot container | 38 | >= 5 | PASS
Verb: cache | 18 | >= 5 | PASS
Verb: barter | 16 | >= 5 | PASS
Verb (info): talk | 88 | — | INFO
Verb (info): pickup | 5 | — | INFO
Verb (info): switch | 1 | — | INFO
Verb (info): inspect/interact | 9 | — | INFO
Verb (info): save | 1 | — | INFO
Verb (info): travel | 67 | — | INFO
Verb (info): party selection | 1 | — | INFO
Verb (info): damage structure | 0 | — | INFO
Hub dom: locks | 4 | >= 4 | PASS
Hub dom: pockets | 3 | >= 3 | PASS
Hub dom: loot-table containers | 4 | >= 4 | PASS
Hub ashlaren: locks | 4 | >= 4 | PASS
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
Bellow | 0 | >= 1 | FAIL
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
Bellow | 0 | >= 3 | FAIL
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
```

## Audit after (verbatim)

```text
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
```

The per-skill zero-count rows and the explicitly SUPERSEDED comparison are diagnostic output, not requirements to populate every skill. The primary density measurements have only the two remaining item/table failures. The audit's PROVISIONAL/source-discrepancy notes are reproduced unchanged; this task does not alter the audit's target provenance.

## Changed files and commits

| File | Change |
|---|---|
| `world/ashlaren.tscn` | One optional Bellow interaction; existing node paths and UIDs preserved. |
| `test/integration/test_ashlaren_bellow.gd` | Runtime navigation, range, attempt persistence, and restored-prompt checks. |
| `docs/qa/field-density-f-review-2026-11-01.md` | This blocker/evidence handoff. |

Implementation commit: **`2c55b849568dc3dc3bddc30578266c2d06e265c5`** — `feat(field): add optional warehouse watch Bellow challenge`. The documentation commit hash is supplied in the final handoff.

Six untracked UID files existed before work and remain untouched: `test/integration/test_loom_field_verbs.gd.uid`, `test/unit/test_audit_field_coverage.gd.uid`, `test/unit/test_encounter_verb_audit.gd.uid`, `test/unit/test_soul_lowest.gd.uid`, `tools/audit_encounter_verbs.gd.uid`, `tools/audit_field_coverage.gd.uid`.

## Risks

Part 1 is not implemented; accepting this change does not satisfy the item/table density target. The five Bellow strings need owner review. Xvfb is unavailable in this sandbox, so placement/readability and real keyboard dispatch have no rendered acceptance evidence. Existing audit shutdown and test-run resource warnings are disclosed above.

## Open decisions

Supply the 18 items' approved grid sizes and stack limits, and authorize/provide their required icons (or explicitly approve a different icon contract). Review the five DRAFT Bellow strings.

## Handoff back

What now works: one natural intimidation check at Ashlaren's warehouse watch, persisted through the existing lock mechanism.
Changed files: the three files listed above.
Checks with results: unit 1987/1987, E2E 21/21, vendor/inventory/loot 51/51, Bellow runtime 2/2; all four drift stages report no drift; commands and verbatim summaries above; Xvfb failed before tests and the authorized headless fallback was used.
Audit before/after: Bellow 0→1, distinct skills 15→16, items 22→22, tables 2→2; every other primary target passes.
New strings: the five DRAFT strings above; no item strings added.
Risks: Part 1 blocked; rendered validation unavailable; existing runtime shutdown warnings.
Open decisions: approve missing inventory values and the icon path forward; review Bellow wording.
Commits: implementation hash above; documentation hash in the final handoff.
