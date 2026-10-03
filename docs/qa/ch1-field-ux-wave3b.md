# Wave 3b — Dom kit cleanup and battle scenery audit

Date: 2026-09-13. Branch: `feat/ch1-facade-occlusion`. Engine:
`4.7.1.stable.official.a13da4feb`. Git metadata is read-only; changes are unstaged.
Issue #305 was reachable with `gh issue view 305`; its body says “see PR”.

## Scope discrepancy requiring direction

The original town scene has 17 kit texture resources used by **143 sprites**:
52 hidden children of the 12 building roots, plus **91 visible outdoor sprites**.
The headless runtime confirmed these visibility counts before modification.
Part A's premise that all 17 references are confined to hidden assemblies is false.

The authorized building cleanup deletes those 52 children and 10 resources that
become unused. All retained node blocks, including their positions, textures,
collision/door children and `uid://` references, are unchanged. The obsolete
hide loop is removed; facade occluder creation is untouched.

Seven resource paths remain pending direction about the live outdoor scope:

| Resource | Live uses |
| --- | ---: |
| `castle-kit/gate.png` | 1 |
| `castle-kit/wall.png` | 74 |
| `fantasy-town-kit/banner-green.png` | 1 |
| `fantasy-town-kit/banner-red.png` | 2 |
| `fantasy-town-kit/lantern.png` | 10 |
| `fantasy-town-kit/cart-high.png` | 2 |
| `fantasy-town-kit/stall-bench.png` | 1 |

These include `TrialHallDoorSprite`, `BorderDressing/Wall*`, street lanterns,
two carts, banners and `ItemShopBench`. Deleting these would visibly change Dom.

## Part B finding: instantiated but fully covered in production

Each standalone `BattleStage` was instantiated headlessly and switched to its
environment using an enemy snapshot. All five props per environment were created
and `is_visible_in_tree()` returned true. Paths below are relative to
`BattleStage/BattleArt/EnvironmentSprites/`:

| Environment | Original prop nodes |
| --- | --- |
| nature | `TreePineTallADetailed`, `TreeOakDark`, `TentDetailedOpen`, `RockLargeE`, `PlantBushLarge` |
| fantasy-town | `WallWoodDoor`, `WallBroken`, `StallGreen`, `FountainRoundDetail`, `TreeHighRound` |
| castle | `TowerSquare`, `WallHalf`, `Gate`, `FlagBannerLong`, `RocksLarge` |

In the instantiated production battle screen, the relevant paths are:

- `Battle/<MarginContainer>/<VBoxContainer>/BattlefieldViewport/BattleStage/BattleArt`:
  z=-1000; global rectangle `(32,24; 1856x687)`.
- `Battle/Backdrop`: visible opaque ColorRect, alpha=1, z=0; global rectangle
  `(0,0; 1920x1080)`. This covers the entire legacy art layer. Container names
  are generated at runtime; the named suffixes above are stable.
- `Battle/.../BattlefieldViewport/BattleInterface/SafeFrame/Rows/Middle/Stage/EnvironmentBackdrop`:
  the separate painted TextureRect, alpha modulation 0.72, within the interface
  at z=4. It is not itself an opaque full-screen cover.

All five painted backdrops resolved and became visible when the region was
switched through encounter prefixes: `bog-wight`, `dorthkor-vanguard`,
`jawbrace-empty-post`, `trial-warden`, and `phase2-demon`. Assets are at
`assets/generated/backgrounds/combat/{bog-marsh,dorthkor-road,jawbrace-ledge,trial-hall,wound-touched-field}-battlefield-v1.png`.
Ambient sessions do not instantiate the legacy BattleStage at all
(`ui/screens/battle.gd`, `if not Battle.session_active`).

Removed the 15-entry table, creation/loading loop, prop layout loop, sprite
array, scenery layer and obsolete count accessor. Existing zone/combatant/cue
presentation remains. No art swaps or generation in Part B. A standalone legacy
stage preview loses its scenery; the production battle screen is unchanged by
the deletion according to runtime geometry and drawing order. Rendered parity
is not claimed because the display backend was unavailable.

## Verification

Headless pre-edit audit (script and output retained in `/tmp`):

```bash
XDG_DATA_HOME="$(mktemp -d /tmp/soul-meter-audit.XXXXXX)" LP_NUM_THREADS=1 "$HOME/.local/bin/godot" --headless --path . -s /tmp/wave3b_audit.gd > /tmp/wave3b-audit.log 2>&1
```

Focused tests: **33 cases passed, 0 errors, 0 failures, 0 skipped**, exit 0.
The town tests run the scene and check all `BUILDING_NAMES`, facade presence,
town entrance transition anchors, generated town NPC anchors, and the existing
interaction/node contracts. The new battle unit test cycles all three environments
and checks instantiated sprite textures (including ground atlas backing paths).

```bash
GODOT_BIN="$HOME/.local/bin/godot" LP_NUM_THREADS=1 SOUL_METER_HEADLESS=1 SOUL_METER_TEST_DATA_DIR="$(mktemp -d /tmp/soul-meter-test.XXXXXX)" bash scripts/test.sh -a test/unit/test_battle_stage.gd -a test/integration/test_starting_town.gd -a test/integration/test_battle_stage.gd > /tmp/wave3b-focused-headless.log 2>&1
```

Both the focused and required commands were first attempted without
`SOUL_METER_HEADLESS=1`. They exited 1 before any cases: Xvfb's X11 display was
unavailable; Wayland fallback also failed. The authorized headless fallback is
being used. The standalone probe and focused test process reported resource
leaks at engine shutdown despite exit 0; these are not rendered verification.

Required run: **1,928 cases executed across 226 suites in 3m35s; 1,924 passed,
4 cases failed**. gdUnit reports 1 runtime error and 10 failed assertions; exit 100.

```bash
GODOT_BIN="$HOME/.local/bin/godot" LP_NUM_THREADS=1 SOUL_METER_TEST_DATA_DIR="$(mktemp -d /tmp/soul-meter-test.XXXXXX)" bash scripts/test.sh -a test/integration/test_starting_town.gd -a test/nav_acceptance -a test/unit -a test/integration > /tmp/wave3b-required-rendered.log 2>&1
GODOT_BIN="$HOME/.local/bin/godot" LP_NUM_THREADS=1 SOUL_METER_HEADLESS=1 SOUL_METER_TEST_DATA_DIR="$(mktemp -d /tmp/soul-meter-test.XXXXXX)" bash scripts/test.sh -a test/integration/test_starting_town.gd -a test/nav_acceptance -a test/unit -a test/integration > /tmp/wave3b-required-headless.log 2>&1
```

Failure triage:

| Check | Finding and disposition |
| --- | --- |
| `test_y_sort.gd::test_building_group_and_its_door_prop_can_occlude_the_player` | Referenced the deleted hidden `RegistryArchive/ArchiveDoor`. Updated to `test_building_facade_shares_the_player_y_sort_band`, checking the retained facade's z=0, relative z and shared building origin. Rerun passes. |
| `test_town_townsfolk.gd::test_thirty_outdoor_townsfolk_spawn_from_generated_placements` | Expected base roster dialogue, received reactive Zhavar dialogue for Kessa and Tern. Fresh isolated rerun passes with no changes to NPC code/tests. |
| `test_interior_population.gd::test_all_thirty_indoor_npcs_use_generated_positions_and_dialogue_titles` | Expected base roster dialogue, received Nalla's reactive Zhavar dialogue. Fresh isolated rerun passes with no changes to interior code/tests. |
| `test_field_room.gd::test_holding_sprint_moves_the_player_materially_faster` | Expected distance >51.999939, observed 26. Fresh isolated rerun passes with no changes to player code/tests. Input/timing confidence remains limited by headless execution. |

The isolated rerun executed **29/29 cases across all four affected suites**,
0 errors, 0 failures, 0 skipped, exit 0, in 25 seconds. This validates the
y-sort correction and clears all three other failures in a fresh fixture. It
does not establish that the broad run is green; order/state sensitivity remains
unresolved. Shutdown leak warnings also remain in the rerun.

```bash
GODOT_BIN="$HOME/.local/bin/godot" LP_NUM_THREADS=1 SOUL_METER_HEADLESS=1 SOUL_METER_TEST_DATA_DIR="$(mktemp -d /tmp/soul-meter-test.XXXXXX)" bash scripts/test.sh -a test/integration/test_y_sort.gd -a test/integration/test_town_townsfolk.gd -a test/integration/test_interior_population.gd -a test/integration/test_field_room.gd > /tmp/wave3b-rerun.log 2>&1
```

XML results: `reports/report_1440/results.xml` (focused),
`reports/report_1441/results.xml` (required), and
`reports/report_1442/results.xml` (isolated rerun).

`git diff --check` passed. The requested kit-reference scan currently returns
seven hits (grep exit 0), all the live outdoor resources listed above:

```bash
grep -rnE 'castle-kit|fantasy-town-kit|nature-kit|kenney3d' world/ actors/ ui/screens/battle_stage.gd
```

The reviewer's rendered
`test/manual/screenshot_sweep.gd` remains the visual acceptance check.

## Changed files

| File | Change |
| --- | --- |
| `world/starting_town.tscn` | Delete 52 hidden sprites, 10 unused texture resources; correct load_steps. |
| `world/starting_town.gd` | Remove obsolete sprite-hiding loop; preserve FacadeOccluder wiring. |
| `ui/screens/battle_stage.gd` | Delete 15 scenery entries and all prop consumers (63 lines). |
| `test/integration/test_starting_town.gd` | Add two building/texture and transition/NPC anchor regressions. |
| `test/integration/test_battle_stage.gd` | Replace five-prop expectation with absence of the removed scenery layer. |
| `test/unit/test_battle_stage.gd` | Add three-environment runtime texture-path audit. |
| `test/integration/test_y_sort.gd` | Point obsolete hidden-door assertion at the surviving painted facade. |
| `docs/qa/ch1-field-ux-wave3b.md` | Record scope discrepancy, audit evidence, commands and results. |

## Rendered verification (Fable, Xvfb, 2026-09-13)
- `test_starting_town`, `test_y_sort`, `test_battle_stage` (unit+integration), `test_facade_occluder`,
  `nav_acceptance`, `screenshot_sweep`: 62 cases, 0 failures.
- `docs/qa/wave3b/town_after_kit_removal.png` — Dom reads identically to the Wave 1 capture; nothing lost.
- Decision on the 91 live outdoor kit sprites (walls, lanterns, banners, carts, door dressing): **kept
  for now**. They are visible dressing with no painted equivalents yet; swapping them is a new art batch
  (#305 stays open for it), not a deletion. Zero-grep in `world/` is therefore deferred to that batch.
