# Field density B1 review — 2026-10-31

P1.2 / #531 slice B1, on `codex/roadmap-p1-2b-dom-density`, starting at
`9f3824ae`. The handoff's **PROVISIONAL** targets pass: Dom has **4 locks,
3 pockets, and 4 loot-table containers**; Wilds, Long Verge, and Hollowmere
each have **2 caches**. Distinct field skills rise **10 → 13**, including
**Bellow 0 → 1**. The chapter-wide 15-skill target remains open.

There are ten new Chest instances and pocket properties on two existing NPCs.
Existing node paths, positions, UID references, dialogue, and travel contracts
are preserved. No item prototypes, loot tables, Pandora data, generated data,
art, vendor code, owner decisions, or roadmaps were edited. The data check
performed comparison only; nothing needed regeneration.

## What now works and how to see it

All node paths below include the scene root. The positions are authored scene
coordinates. Chests use the existing `actors/chest/chest.tscn` / `Chest` /
`SMInteractable` implementation, as in Dorthkor Road and Wound Lip.
The new NPC pockets use the existing `NPC` implementation.

| Scene | Node path | Position | Addition |
|---|---|---|---|
| `world/starting_town.tscn` | `StartingTown/HadrikVale` | (700, 535), existing | Bellow pocket; `hadrik-vale-purse`; 9 GP; faction `rennen` |
| `world/starting_town.tscn` | `StartingTown/SellaVarn` | (2820, 1525), existing | Tread pocket; `sella-varn-purse`; 9 GP; faction `trial-council` |
| `world/interiors/item_shop.tscn` | `ItemShopInterior/LatchCrate` | (1450, 1000) | Ear lock; `item-shop-latch-crate` |
| `world/interiors/cask_warehouse.tscn` | `CaskWarehouseInterior/LockedStockCrate` | (1450, 1000) | Slip lock; `cask-warehouse-locked-stock-crate` |
| `world/interiors/equipment_forge.tscn` | `EquipmentForgeInterior/BracedStockCrate` | (1450, 1000) | Strain lock; `equipment-forge-braced-stock-crate` |
| `world/interiors/iron_companies.tscn` | `IronCompaniesInterior/LockedSupplyCrate` | (1450, 1000) | Slip lock; `iron-companies-locked-supply-crate` |
| `world/test_room.tscn` (Wilds) | `TestRoom/WestCache` | (420, 560) | `wilds-west-cache` |
| `world/test_room.tscn` (Wilds) | `TestRoom/GladeCache` | (1560, 740) | `wilds-glade-cache` |
| `world/long_verge.tscn` | `LongVerge/WestCache` | (650, 730) | `long-verge-west-cache` |
| `world/long_verge.tscn` | `LongVerge/CampCache` | (2370, 1000) | `long-verge-camp-cache` |
| `world/hollowmere.tscn` | `Hollowmere/TrackCache` | (740, 800) | `hollowmere-track-cache` |
| `world/hollowmere.tscn` | `Hollowmere/LandingCache` | (1780, 1250) | `hollowmere-landing-cache` |

Every new chest uses the existing `road-cache` table, with no fixed `loot`
override. Thus all ten also offer the table's existing Sounding search.
The four Dom chests copy their scene's existing
`owned_by_faction = "iron-companies"` pattern. Wild caches are unowned,
matching Dorthkor Road's table-backed cache.

All four lock modifiers are **0.0**, matching Dorthkor Road's CampCache;
pocket modifiers retain the existing **0.0** default, and both rewards copy
Toma Reedhand's **9 GP**. No new difficulty, reward, quantity, or table-weight
values were introduced. Pocket factions come from the existing NPC roster.

Skill choices follow `docs/briefs/dramgid-brief.md`: Bellow is intimidation
at Hadrik's existing stealing opportunity, Tread is a stealth approach to
Sella's pocket, and Ear is perception of the latch. These reuse the current
one-attempt outcomes; they add no new interaction system. Strain and Slip
keep the established force/lockpick uses.

Use a protagonist-bearing new game/save to exercise skill outcomes; a bare
direct scene launch has no protagonist and therefore zero effective check
chance. Hadrik and Sella retain their existing routines and are absent at
night. The Cask Warehouse still requires `dom_dishonest_casks_traced`;
the audit correctly includes it through Item Shop's recursive interior link.

## Placement evidence

A disposable typed GDScript probe loaded all eight changed scenes with the
existing `capture-scene` switch. It checked the whole 40×40 chest footprint
with Godot's physics shape query, sampled its center and four corners against
the ground tiles and `IsoGrid` where available, and checked four approach
points 64 pixels away with a 16-pixel clearance shape. All ten had four
clear approaches. Outdoor approaches also had paths in the player's actual
`ClickMoveController` grid.

Interiors have empty `FieldGround` / `FieldBlocking` layers and use free
placement. Their checks therefore used `Room/Floor`'s polygon and live
wall/furniture/NPC physics. All four new interior chests are below the
counter, outside the central exit aisle and clear of the eastern stock props.
Each is 529.245 pixels from the nearest door. The closest ambient route
is the Iron Companies dockworker's route, 141.322 pixels away.

Long Verge and Hollowmere also have empty authored `Blocking` layers;
their StaticBody2D dressing was included in the physics checks. The empty
layer warnings are present in the unchanged scenes too. Grid path existence
alone was not treated as proof of physical clearance.

| Outdoor chest | Ground cell | Clear approaches | Nearest exit (px) | Nearest NPC (px) | Nearest ambient route bounds (px) |
|---|---|---:|---:|---:|---:|
| Wilds / WestCache | (24, 43) | 4 | 352.278 | 934.777 | 817.298 |
| Wilds / GladeCache | (47, 31) | 4 | 1496.563 | 326.754 | 543.065 |
| Long Verge / WestCache | (33, 60) | 4 | 614.003 | 489.939 | none |
| Long Verge / CampCache | (68, 42) | 4 | 578.705 | 245.381 | none |
| Hollowmere / TrackCache | (36, 61) | 4 | 687.314 | 155.795 | none |
| Hollowmere / LandingCache | (67, 59) | 4 | 1755.249 | 402.318 | none |

Pockets add no bodies or NPC routes. Their authored positions are unchanged;
the existing morning grid snap produced (708, 532) for Hadrik and (2820, 1524)
for Sella. Runtime checks confirmed both success rewards exactly once,
failure with no reward, the existing infamy/faction penalties, and the
one-attempt lock/table-search state on the new chests.

The probe and logs are retained locally under
`reports/field-density-b1/` (ignored, not shipped). Rendered inspection is
assigned to Claude by the handoff; this report does not certify visual quality.

## Owner review: new strings (drafts)

**None.** No new prompt, description, NPC name, failure message, or other
player-facing string was authored. There are no new msgids to add to the
existing PO/gettext path.

The four interior chests reuse `"Supply Crate"` and `"Open"` from their
existing scene containers; the six wild caches reuse `"SUPPLY CRATE"` and
the Chest template's `"OPEN"`. Locks and pockets retain the existing generic
feedback. New container/pocket IDs, node names, and source comments are not
player-facing prose.

Bellow therefore still uses the existing generic `F — Steal` prompt and
pickpocket receipts. This is a presentation limitation for Claude's review,
not new intimidation-specific dialogue or canon.

## Checks with results (verbatim)

All commands ran from this worktree with Godot
`4.7.1.stable.official.a13da4feb`, no network, and disposable user data.
Terminal color escapes are removed from test summaries below.

### Audit before and after

Run once before editing and once after all scene additions:

```bash
XDG_DATA_HOME="$(mktemp -d /tmp/soul-meter-b1-audit-before.XXXXXX)" LP_NUM_THREADS=1 timeout 60 "$HOME/.local/bin/godot" --headless --path . --script res://tools/audit_field_coverage.gd
XDG_DATA_HOME="$(mktemp -d /tmp/soul-meter-b1-audit-after.XXXXXX)" LP_NUM_THREADS=1 timeout 60 "$HOME/.local/bin/godot" --headless --path . --script res://tools/audit_field_coverage.gd
```

Process exit status: **0 for each**. Both density and skill tables are pasted
verbatim below. The audit's existing source/classification discrepancy notes
remain: Long Verge/Hollowmere are retained in both applicable views, and the
R7/11c ratification sources are missing from this checkout.

Both standalone audit runs also emitted main-menu preload diagnostics during
shutdown, including:

```text
SCRIPT ERROR: Parse Error: Could not preload resource file "res://ui/screens/main_menu_reflection.gdshader".
ERROR: Failed loading resource: res://ui/screens/main_menu.tscn.
```

The completed audit tables, rather than exit status, establish these counts.

### Unit suite

Requested Xvfb command:

```bash
GODOT_BIN="$HOME/.local/bin/godot" LP_NUM_THREADS=1 SOUL_METER_TEST_DATA_DIR="$(mktemp -d /tmp/soul-meter-b1-unit-xvfb.XXXXXX)" timeout 5400 bash scripts/test.sh -a test/unit
```

Process exit status: **1**. Display failures, verbatim:

```text
ERROR: X11 Display is not available
ERROR: Can't connect to a Wayland display.
ERROR: Could not initialize the Wayland thread.
ERROR: Can't create the Wayland display server.
ERROR: Unable to create DisplayServer, all display drivers failed.
```

CI-equivalent headless fallback:

```bash
GODOT_BIN="$HOME/.local/bin/godot" LP_NUM_THREADS=1 SOUL_METER_HEADLESS=1 SOUL_METER_TEST_DATA_DIR="$(mktemp -d /tmp/soul-meter-b1-unit-headless.XXXXXX)" timeout 5400 bash scripts/test.sh -a test/unit
```

Process exit status: **0**. Verbatim result:

```text
Overall Summary: 1982 test cases | 0 errors | 0 failures | 0 flaky | 0 skipped | 0 orphans |
Executed test suites: (194/194)
Executed test cases : (1982/1982)
Exit code: 0
```

### E2E suite

Requested Xvfb command:

```bash
GODOT_BIN="$HOME/.local/bin/godot" LP_NUM_THREADS=1 SOUL_METER_TEST_DATA_DIR="$(mktemp -d /tmp/soul-meter-b1-e2e-xvfb.XXXXXX)" timeout 5400 bash scripts/test.sh -a test/e2e
```

Process exit status: **1**, with the same five display errors quoted above.

CI-equivalent headless fallback:

```bash
GODOT_BIN="$HOME/.local/bin/godot" LP_NUM_THREADS=1 SOUL_METER_HEADLESS=1 SOUL_METER_TEST_DATA_DIR="$(mktemp -d /tmp/soul-meter-b1-e2e-headless.XXXXXX)" timeout 5400 bash scripts/test.sh -a test/e2e
```

Process exit status: **0**. Verbatim result:

```text
Overall Summary: 21 test cases | 0 errors | 0 failures | 0 flaky | 0 skipped | 0 orphans |
Executed test suites: (2/2)
Executed test cases : (21/21)
Exit code: 0
```

The passing summaries do not mean stderr was empty. Unit negative fixtures
emit expected validation errors. E2E also emitted 74 occurrences of
`ERROR: Parameter "data.tree" is null.`; the first trace is
`Battle._agreement_integrity()` / `Battle._weather_for_start()` on a
detached Battle created by `test_field_debt_journey.gd:57`. These are not
resolved by this scene-authoring slice. Teardown diagnostics included:

```text
ERROR: 74 resources still in use at exit (run with --verbose for details).
ERROR: 60 resources still in use at exit (run with --verbose for details).
ERROR: 3 RID allocations of type 'PN13RendererDummy14TextureStorage12DummyTextureE' were leaked at exit.
```

The 74-resource line is from the unit run; the following two are from E2E.

### Generated-data check

```bash
GODOT_BIN="$HOME/.local/bin/godot" LP_NUM_THREADS=1 timeout 600 bash scripts/check_generated_data.sh
```

Process exit status: **0**. Verbatim completion markers:

```text
GLOOT-GEN: no drift.
CANON-SEED: no drift.
LOCATIONS-GEN: no drift.
ISO-SPRITE-GEN: no drift. 598 sprites verified.
```

### Headless loading of every changed scene

For each scene in the object table, using the repository's supported flag
that suppresses GameFlow's automatic title-screen replacement:

```bash
XDG_DATA_HOME="$(mktemp -d /tmp/soul-meter-b1-capture-load.XXXXXX)" LP_NUM_THREADS=1 timeout 60 "$HOME/.local/bin/godot" --headless --path . "$b1_scene" --quit-after 30 -- capture-scene
```

Verbatim loop results:

```text
world/starting_town.tscn exit=0
world/interiors/item_shop.tscn exit=0
world/interiors/cask_warehouse.tscn exit=0
world/interiors/equipment_forge.tscn exit=0
world/interiors/iron_companies.tscn exit=0
world/test_room.tscn exit=0
world/long_verge.tscn exit=0
world/hollowmere.tscn exit=0
```

All eight instantiated and ran without scene parse or gameplay errors.
**The literal zero-error-log criterion is not met:** every process still
reports this existing shutdown diagnostic:

```text
ERROR: 13 resources still in use at exit (run with --verbose for details).
```

The same diagnostic was reproduced by loading the eight unchanged scene
snapshots from starting commit `9f3824ae` in the same runtime harness.
Long Verge and Hollowmere additionally retain their empty-Blocking warning.

Initial loads without `capture-scene` let GameFlow replace the scenes during
initialization and emitted generated-NPC interaction-area errors; the final
supported-mode loads do not emit those errors. No runtime source was changed
to suppress them.

Final geometry/interaction probe:

```bash
XDG_DATA_HOME="$(mktemp -d /tmp/soul-meter-b1-runtime-final.XXXXXX)" LP_NUM_THREADS=1 timeout 180 "$HOME/.local/bin/godot" --headless --path . res://reports/field-density-b1/verify_scenes.tscn -- capture-scene
```

Process exit status: **0**. Verbatim result:

```text
B1_RUNTIME: PASS failures=0
```

The probe uses an isolated protagonist fixture, matching the existing pocket
unit-test setup. Early probe failures from a missing protagonist were corrected
in that disposable fixture; no gameplay change was needed.

`git diff --check` passed. A serialized-node comparison against the starting
scenes found ten added nodes, zero removed nodes, and no changed existing
node properties except the two requested NPC pocket configurations.

## Audit before

```text
PROVISIONAL density measurements
Measurement | Count | Target | Result
Distinct field skills / 22 | 10 | >= 15 | FAIL
Bellow checks | 0 | >= 1 | FAIL
Verb: lockpick | 1 | >= 5 | FAIL
Verb: pickpocket/steal | 7 | >= 5 | PASS
Verb: loot container | 12 | >= 5 | PASS
Verb: cache | 4 | >= 5 | FAIL
Verb: barter | 16 | >= 5 | PASS
Verb (info): talk | 88 | — | INFO
Verb (info): pickup | 5 | — | INFO
Verb (info): switch | 1 | — | INFO
Verb (info): inspect/interact | 7 | — | INFO
Verb (info): save | 1 | — | INFO
Verb (info): travel | 67 | — | INFO
Verb (info): party selection | 1 | — | INFO
Verb (info): damage structure | 0 | — | INFO
Hub dom: locks | 0 | >= 4 | FAIL
Hub dom: pockets | 1 | >= 3 | FAIL
Hub dom: loot-table containers | 0 | >= 4 | FAIL
Hub ashlaren: locks | 0 | >= 4 | FAIL
Hub ashlaren: pockets | 0 | >= 3 | FAIL
Hub ashlaren: loot-table containers | 0 | >= 4 | FAIL
Hub kesselford: locks | 0 | >= 4 | FAIL
Hub kesselford: pockets | 0 | >= 3 | FAIL
Hub kesselford: loot-table containers | 0 | >= 4 | FAIL
Hub long_verge: locks | 0 | >= 4 | FAIL
Hub long_verge: pockets | 0 | >= 3 | FAIL
Hub long_verge: loot-table containers | 0 | >= 4 | FAIL
Hub hollowmere: locks | 0 | >= 4 | FAIL
Hub hollowmere: pockets | 0 | >= 3 | FAIL
Hub hollowmere: loot-table containers | 0 | >= 4 | FAIL
Wild dorthkor_road: caches | 2 | >= 2 | PASS
Wild hollowmere: caches | 0 | >= 2 | FAIL
Wild long_verge: caches | 0 | >= 2 | FAIL
Wild wilds: caches | 0 | >= 2 | FAIL
Wild wound_lip: caches | 2 | >= 2 | PASS
Loot tables | 2 | >= 8 | FAIL
Items | 22 | >= 40 | FAIL

Field skill occurrences (>= 1 contributes to the 15/22 target; no quota for every skill)
Skill | Checks | Presence contribution | Result
Strain | 2 | >= 1 | PASS
Lilt | 0 | >= 1 | FAIL
Slip | 3 | >= 1 | PASS
Tread | 0 | >= 1 | FAIL
Beastbond | 1 | >= 1 | PASS
Varlore | 0 | >= 1 | FAIL
Unweave | 2 | >= 1 | PASS
Recall | 1 | >= 1 | PASS
Wildlore | 0 | >= 1 | FAIL
Devotion | 0 | >= 1 | FAIL
Undertone | 3 | >= 1 | PASS
Mending | 0 | >= 1 | FAIL
Ear | 0 | >= 1 | FAIL
Wayfinding | 1 | >= 1 | PASS
Sounding | 3 | >= 1 | PASS
Falsetto | 0 | >= 1 | FAIL
Bellow | 0 | >= 1 | FAIL
Vārum | 1 | >= 1 | PASS
Sway | 2 | >= 1 | PASS
Downbeat | 0 | >= 1 | FAIL
Brace | 0 | >= 1 | FAIL
Vantage | 0 | >= 1 | FAIL
```

## Audit after

```text
PROVISIONAL density measurements
Measurement | Count | Target | Result
Distinct field skills / 22 | 13 | >= 15 | FAIL
Bellow checks | 1 | >= 1 | PASS
Verb: lockpick | 5 | >= 5 | PASS
Verb: pickpocket/steal | 13 | >= 5 | PASS
Verb: loot container | 22 | >= 5 | PASS
Verb: cache | 10 | >= 5 | PASS
Verb: barter | 16 | >= 5 | PASS
Verb (info): talk | 88 | — | INFO
Verb (info): pickup | 5 | — | INFO
Verb (info): switch | 1 | — | INFO
Verb (info): inspect/interact | 7 | — | INFO
Verb (info): save | 1 | — | INFO
Verb (info): travel | 67 | — | INFO
Verb (info): party selection | 1 | — | INFO
Verb (info): damage structure | 0 | — | INFO
Hub dom: locks | 4 | >= 4 | PASS
Hub dom: pockets | 3 | >= 3 | PASS
Hub dom: loot-table containers | 4 | >= 4 | PASS
Hub ashlaren: locks | 0 | >= 4 | FAIL
Hub ashlaren: pockets | 0 | >= 3 | FAIL
Hub ashlaren: loot-table containers | 0 | >= 4 | FAIL
Hub kesselford: locks | 0 | >= 4 | FAIL
Hub kesselford: pockets | 0 | >= 3 | FAIL
Hub kesselford: loot-table containers | 0 | >= 4 | FAIL
Hub long_verge: locks | 0 | >= 4 | FAIL
Hub long_verge: pockets | 0 | >= 3 | FAIL
Hub long_verge: loot-table containers | 2 | >= 4 | FAIL
Hub hollowmere: locks | 0 | >= 4 | FAIL
Hub hollowmere: pockets | 0 | >= 3 | FAIL
Hub hollowmere: loot-table containers | 2 | >= 4 | FAIL
Wild dorthkor_road: caches | 2 | >= 2 | PASS
Wild hollowmere: caches | 2 | >= 2 | PASS
Wild long_verge: caches | 2 | >= 2 | PASS
Wild wilds: caches | 2 | >= 2 | PASS
Wild wound_lip: caches | 2 | >= 2 | PASS
Loot tables | 2 | >= 8 | FAIL
Items | 22 | >= 40 | FAIL

Field skill occurrences (>= 1 contributes to the 15/22 target; no quota for every skill)
Skill | Checks | Presence contribution | Result
Strain | 3 | >= 1 | PASS
Lilt | 0 | >= 1 | FAIL
Slip | 5 | >= 1 | PASS
Tread | 1 | >= 1 | PASS
Beastbond | 1 | >= 1 | PASS
Varlore | 0 | >= 1 | FAIL
Unweave | 2 | >= 1 | PASS
Recall | 1 | >= 1 | PASS
Wildlore | 0 | >= 1 | FAIL
Devotion | 0 | >= 1 | FAIL
Undertone | 3 | >= 1 | PASS
Mending | 0 | >= 1 | FAIL
Ear | 1 | >= 1 | PASS
Wayfinding | 1 | >= 1 | PASS
Sounding | 13 | >= 1 | PASS
Falsetto | 0 | >= 1 | FAIL
Bellow | 1 | >= 1 | PASS
Vārum | 1 | >= 1 | PASS
Sway | 2 | >= 1 | PASS
Downbeat | 0 | >= 1 | FAIL
Brace | 0 | >= 1 | FAIL
Vantage | 0 | >= 1 | FAIL
```

## Changed files

| File | Change |
|---|---|
| `world/starting_town.tscn` | Pocket properties on Hadrik and Sella |
| `world/interiors/item_shop.tscn` | One owned table-backed Ear lock |
| `world/interiors/cask_warehouse.tscn` | One owned table-backed Slip lock |
| `world/interiors/equipment_forge.tscn` | One owned table-backed Strain lock |
| `world/interiors/iron_companies.tscn` | One owned table-backed Slip lock |
| `world/test_room.tscn` | Two Wilds caches |
| `world/long_verge.tscn` | Two Long Verge caches |
| `world/hollowmere.tscn` | Two Hollowmere caches |
| `docs/qa/field-density-b1-review-2026-10-31.md` | This review and verification evidence |

The six untracked `.gd.uid` files present at entry were preserved and excluded
from commits. Runtime probes, baseline snapshots, and raw logs remain in the
ignored `reports/field-density-b1/` directory.

## Commits

- `07cf4f39f33a26ea79154a01aa0f955f24c073a4` — Dom locks and pockets.
- `3e81c3c566295baba8e4df8af4083fe4f949d4b0` — Wilds, Long Verge, and Hollowmere caches.
- The documentation commit containing this report is listed in the final handoff.

## Risks

- Rendered placement, sprite overlap, and prompt readability await Claude's requested captures.
- Existing shutdown resource diagnostics prevent claiming completely error-free Godot logs; E2E's detached-Battle diagnostics also remain.
- The Cask Warehouse lock is quest-gated and the two NPCs follow existing day/night availability; audit counts are authored opportunities.
- Bellow uses the existing generic stealing feedback, with no new authored dialogue.
- Targets remain provisional; the total skill count is 13/15, tables 2/8, and items 22/40.

## Open decisions

None introduced by B1; existing target-ratification discrepancies remain unchanged.

## Next slice

Continue the separately assigned P1.2 hub-density work in Ashlaren and
Kesselford, then the remaining Long Verge/Hollowmere hub rows. Two additional
distinct skills are still needed for the global provisional target. Item and
loot-table expansion belongs to a separately authorized slice.

Claude's next action for B1: capture the scene/node placements in the object
table, including the existing Bellow stealing feedback.

