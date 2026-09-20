# Art integration pass — 2026-09-18

Implemented a broad presentation pass using the existing approved painterly assets. The direction remains [the art aesthetics bible](art-aesthetics-bible.md). This pass integrates and improves their presentation; it does not introduce a new art direction or generate replacement raster assets.

## Review images

These are unmodified 1920×1080 runtime captures from Godot 4.7.1 under Xvfb.

| Surface | Before | Current | Visible change |
| --- | --- | --- | --- |
| Party | [Before](qa/art-pass-2026-09-18/party-before.png) | [Current](qa/art-pass-2026-09-18/party.png) | Large framed member artwork and an opaque DS backdrop. |
| Character sheet | — | [Current](qa/art-pass-2026-09-18/character-sheet.png) | Member portrait beside the Wheel, illustrated list with room for names. |
| Loamroot | — | [Current](qa/art-pass-2026-09-18/loamroot.png) | Item art replaces green pickup squares; localized item names replace “Pickup”; smaller decorative foliage. |
| Dorthkor Road | — | [Current](qa/art-pass-2026-09-18/dorthkor-road.png) | Drum scale no longer dominates the party and nearby cache. |
| Item shop | [Before](qa/art-pass-2026-09-18/item-shop-before.png) | [Current](qa/art-pass-2026-09-18/item-shop.png) | Wood grain is visible, chest rests on its base, label clears the chest. |

## Delivered behavior

- **World art:** linear filtering on all four field scenes, the shared interior presentation, and the tavern. Resized and grounded 40 decorative sprites across Dom, Loamroot, and Dorthkor Road. Shared interior material tinting preserves the painted grain and masonry rather than multiplying them into near-black. Collision shapes and actor positions remain unchanged.
- **Interactive props:** chests and switches load imported texture resources through Godot rather than decoding source PNGs at runtime. Both retain visible marker fallbacks. Ground pickups resolve the canonical GLoot prototype image and localized name without creating inventory items; missing art retains the fallback marker.
- **Party identity:** player and follower sprites use full-body unit art paired with the selected likeness. Portrait busts remain UI art. Combat snapshots carry serializable member IDs and portrait resource paths; unit plates show the portrait while the stage uses its paired unit. Named members retain their dedicated field art. Portrait save restoration and unit existence checks follow imported resource remapping.
- **UI art:** larger framed portraits in Party, Character Sheet, and recruitment details; company artwork on Chapter Complete. Painted textures use linear filtering in item slots, dialogue portraits, character creation, recruitment, unit plates, and stage actors. Existing theme variations provide the frames and backdrops.
- **Capture coverage:** the screenshot sweep disables stale cameras, resolves nested interior players, hides retired CanvasLayers, and includes every concrete interior scene. It captures 49 views, including all 21 interiors.

## Verification

Two affected runs passed with exit code 0: **78/78** cases in `reports/report_1508/results.xml` and **93/93** in `reports/report_1509/results.xml`. Together they cover **149 distinct cases**: 138 behavioral cases and 11 screenshot cases. There were zero assertion errors, failures, skips, or reported test orphans. The final capture run includes the pickup and chest-label corrections.

Covered suites:

| Area | Suites |
| --- | --- |
| Resources and identity | `test/unit/test_chargen_art_resolver.gd`, `test/unit/test_party_member.gd`, `test/unit/test_interactive_props.gd` |
| Combat presentation and serialization | `test/test_unit_plate_region.gd`, `test/test_battle_stage_region.gd`, `test/integration/test_combat_controller.gd` |
| Party UI and field actors | `test/integration/test_party_screen.gd`, `test/integration/test_character_sheet.gd`, `test/integration/test_party_followers.gd` |
| Interiors and rendering | `test/integration/test_building_interiors.gd`, `test/integration/test_tavern_interior.gd`, `test/manual/screenshot_sweep.gd` |

Runs used `scripts/test.sh`, Godot 4.7.1, Xvfb, `LP_NUM_THREADS=1`, and isolated `SOUL_METER_TEST_DATA_DIR` directories. Representative captures were visually inspected: party, recruitment, character sheet, chapter completion, inventory, the four fields, item shop, and council chamber. Capturing all interiors does not imply individual visual approval of every room.

`git diff --check` passed. `SOUL_METER_ACCEPTANCE_ARTIFACTS_ONLY=1 bash scripts/acceptance_gate.sh` passed; locale catalogs align at 53 msgids. This was affected verification, not the complete release gate or a packaged-export test.

Local run artifacts:

```text
/tmp/soul-meter-art-pass-after-0918.log
/tmp/soul-meter-art-final-0918.log
/tmp/soul-meter-art-artifacts-0918.log
/tmp/soul-meter-art-final-0918/godot/app_userdata/SoulMeter/qa/
```

## Follow-up: inventory and battle readability

The follow-up fixes two issues exposed by the first capture pass.

| Surface | Before | Current | Result |
| --- | --- | --- | --- |
| Populated inventory | [Overlap](qa/art-pass-2026-09-18/inventory-before.png) | [Separated items](qa/art-pass-2026-09-18/inventory.png) | Existing items get distinct cells when the bag first gains its grid; valid player placements survive reopening and save/load. |
| Live field combat | — | [Live battlefield](qa/art-pass-2026-09-18/battle-live.png) | The complete command catalog scrolls inside the dock, leaving the field and combatants visible. |
| Tactical grid combat | [Overflow](qa/art-pass-2026-09-18/battle-before.png) | [Contained overview](qa/art-pass-2026-09-18/battle-grid.png) | The board fits the region and does not paint over adjacent HUD panels. |

**Inventory cause and fix:** GLoot assigns existing items the default cell `(0, 0)` when a grid constraint is attached to an already-filled inventory. `InventoryScreen.repair_bag_layout()` plans vacant rectangles before applying positions. It does not remove items, merge stacks, fire removal events, or increase capacity. It preserves valid existing placements. If the remaining items cannot fit, it leaves all items and positions intact and reports a warning. The screen also uses the existing opaque DS backdrop.

**Battle cause and fix:** the growing class-action catalog propagated its full grid height into the command dock. An action scroller now contains the rows; keyboard focus follows scrolling and targeting/end-turn/withdraw stay outside it. All commands retain their existing availability checks, labels, and full tooltips. Separately, the tactical stage's old minimum scale of `0.6` pushed full-field edge combatants outside the region. The overview now permits a sufficiently small fit, and the stage clips its own painting to its bounds. Combat rules, deployment positions, and scene navigation are unchanged.

Regression cases first reproduced item overlap, command-dock overflow, and off-screen corner combatants. The corrected runs passed **36/36** cases (`reports/report_1512/results.xml`) and **19/19** (`reports/report_1514/results.xml`), covering **38 distinct cases** across inventory, live combat sessions, battle interface, pointer controls, stage rendering, and captures. Both processes exited 0 with no test failures or errors. A malformed overflow-test fixture was corrected before these passing runs; no production failure was suppressed.

The follow-up captured and visually inspected inventory, live same-map combat, and the older tactical-grid path. Reproduce with `scripts/test.sh -a test/manual/art_followup_capture.gd` under Xvfb. Local evidence is in `/tmp/soul-meter-art-followup-green.log`, `/tmp/soul-meter-art-grid-final.log`, and `/tmp/soul-meter-art-grid-final/godot/app_userdata/SoulMeter/qa/`. `git diff --check` passed.

## Remaining observations

- Godot logs ObjectDB/resource and GLES texture leak diagnostics at shutdown in both baseline and changed runs. Both changed test processes exited 0; this is not a warning-free run.
- The tactical overview fits the entire loaded field, so units are small on very large maps. The live same-map path uses the field camera and retains full-sized world artwork; the two paths have separate captures above.
- An overfull legacy inventory that cannot fit the existing grid is preserved without a partial rearrangement. This change does not enlarge its capacity or discard goods.

The separate called-shot design/task edits and reaction-matrix test UID are outside this art pass. No publication or deployment was performed.
