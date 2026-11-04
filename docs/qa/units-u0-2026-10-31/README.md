# Unit art U0 verification — 2026-10-31

Milestone U0 of `docs/handoff-art-units-codex.md` (issue #536): manifest-driven unit frames,
player ancestry/class resolution, shared actor facing, per-hub crowd race mix. No art, data or
Pandora content changed. Reviewer: Claude; implementer: Codex (`2e089e86`, `ebbae615`);
review fix on top (legacy unit folders without a manifest row).

Before source: `56907748`. Engine: Godot 4.7.1.stable.official. Host: WSL2, Xvfb 1920×1080,
`scripts/test.sh` (which wraps `xvfb-run -a`), after `godot --headless --import --quit` twice
(the CI recipe) in each fresh worktree.

## Automated checks (final tree)

```text
bash scripts/test.sh -a test/unit
Overall Summary: 1965 test cases | 0 errors | 0 failures | 0 flaky | 0 skipped | 0 orphans |

bash scripts/check_generated_data.sh
GLOOT-GEN: no drift. / CANON-SEED: no drift. / LOCATIONS-GEN: no drift. / ISO-SPRITE-GEN: no drift. 598 sprites verified.
```

Focused suites (`test_unit_frames`, `test_unit_art_height`, `test_chargen_art_resolver`,
`test_town_npc_race_mix`): 31 cases, 0 failures.

## Review finding fixed before the PR

`assets/generated/sprites/units/trial-keeper` and `trial-warden` ship art without a manifest row
(`d10f4506`). Codex's manifest-only lookup returned an empty path for both, so `UnitArt.has_unit`
went false and combat would have drawn the two trial enemies with a crowd fallback. Fix:
`UnitFrames._index_legacy_folders` indexes any unit folder that lacks a row as an se-only idle
frame at load; `test_unit_art_without_a_manifest_row_keeps_the_legacy_single_frame_contract`
pins it. The field capture of the lower trial hall does not exercise this path (the hall's NPCs use
other art); the regression was found by diffing unit folders against manifest rows.

## Rendered comparison

`bash scripts/test.sh -a test/manual/screenshot_sweep.gd` produces 53 captures. Byte-identical
output is not achievable: two runs of the **unchanged baseline** already differ in 27 of 53
captures (idle bob phase, HUD fade-in timing, typewriter text, main-menu shader noise). The
comparison therefore reports, per capture, the percentage of pixels that differ at all, the
percentage differing by ≥32 on any channel, and the maximum channel delta, for the control pair
(baseline vs baseline) next to the U0 pair (baseline vs U0 final tree). A capture is flagged when
the U0 "big" fraction exceeds twice the control's plus 0.01 (or 0.05 %). **No capture is flagged.**

Earlier U0 sweeps showed two larger, non-sprite differences that the rerun did not reproduce:
the lower trial hall caught the HUD and interaction labels in one frame and not the other, and one
player's-house capture fired before the scene transition finished. Both are capture-timing
artefacts of the sweep; the pixel diffs showed no replaced sprite anywhere (replaced art would
show as a solid blob, not an outline).

Columns: `changed % / ≥32 % / max delta`.

| Capture | baseline vs baseline (control) | baseline vs U0 |
|---|---|---|
| `01_main_menu.png` | 8.96 / 0.000 / 1 | 7.30 / 0.000 / 1 |
| `02_chargen.png` | 0.00 / 0.000 / 0 | 0.00 / 0.000 / 0 |
| `02a_chargen_ancestry.png` | 0.00 / 0.000 / 0 | 0.00 / 0.000 / 0 |
| `02b_chargen_attributes.png` | 0.00 / 0.000 / 0 | 0.00 / 0.000 / 0 |
| `02c_chargen_identity.png` | 0.00 / 0.000 / 0 | 0.00 / 0.000 / 0 |
| `03_tavern_picker.png` | 0.00 / 0.000 / 0 | 0.00 / 0.000 / 0 |
| `04_inventory.png` | 0.00 / 0.000 / 0 | 0.00 / 0.000 / 0 |
| `05_party.png` | 0.00 / 0.000 / 0 | 0.00 / 0.000 / 0 |
| `06_journal.png` | 0.00 / 0.000 / 0 | 0.00 / 0.000 / 0 |
| `07_standing.png` | 0.00 / 0.000 / 0 | 0.00 / 0.000 / 0 |
| `08_character_sheet.png` | 0.00 / 0.000 / 0 | 0.00 / 0.000 / 0 |
| `09_region_map.png` | 0.00 / 0.000 / 0 | 0.00 / 0.000 / 0 |
| `10_settings.png` | 0.00 / 0.000 / 0 | 0.00 / 0.000 / 0 |
| `11_load_game.png` | 0.00 / 0.000 / 0 | 0.00 / 0.000 / 0 |
| `12_pause_menu.png` | 0.00 / 0.000 / 0 | 0.00 / 0.000 / 0 |
| `13_chapter_complete.png` | 0.00 / 0.000 / 0 | 0.00 / 0.000 / 0 |
| `14_debug_menu.png` | 0.00 / 0.000 / 0 | 0.00 / 0.000 / 0 |
| `15_shop.png` | 0.00 / 0.000 / 0 | 0.00 / 0.000 / 0 |
| `16_marshal_conversation.png` | 5.52 / 0.000 / 4 | 28.97 / 0.000 / 29 |
| `17_iris_conversation.png` | 0.17 / 0.000 / 7 | 0.07 / 0.000 / 5 |
| `18_sella_conversation.png` | 0.04 / 0.000 / 4 | 0.06 / 0.000 / 6 |
| `19_hadrik_conversation.png` | 0.00 / 0.000 / 98 | 0.01 / 0.001 / 98 |
| `19_toma_conversation.png` | 0.00 / 0.000 / 25 | 0.00 / 0.000 / 42 |
| `20_town.png` | 1.86 / 0.009 / 73 | 2.23 / 0.029 / 126 |
| `21_wilds.png` | 0.63 / 0.004 / 98 | 0.62 / 0.004 / 97 |
| `22_dorthkor_road.png` | 0.26 / 0.003 / 149 | 0.29 / 0.002 / 142 |
| `23_battle_grid.png` | 0.00 / 0.000 / 0 | 0.00 / 0.000 / 0 |
| `24_wound_lip.png` | 0.36 / 0.036 / 183 | 0.43 / 0.043 / 201 |
| `30_tavern_interior.png` | 0.16 / 0.000 / 4 | 0.16 / 0.000 / 4 |
| `31_item_shop_interior.png` | 0.06 / 0.001 / 58 | 0.06 / 0.001 / 60 |
| `32_trial_hall_interior.png` | 0.13 / 0.001 / 47 | 0.03 / 0.000 / 2 |
| `33_river_shrine_interior.png` | 0.00 / 0.000 / 156 | 0.00 / 0.000 / 25 |
| `interior_ashlaren_millhouse.png` | 0.02 / 0.003 / 168 | 0.03 / 0.024 / 254 |
| `interior_ashlaren_weighing_hall.png` | 0.00 / 0.000 / 83 | 0.03 / 0.023 / 254 |
| `interior_bell_house.png` | 0.00 / 0.001 / 83 | 0.00 / 0.001 / 83 |
| `interior_bell_loft.png` | 0.01 / 0.001 / 150 | 0.03 / 0.024 / 254 |
| `interior_cask_warehouse.png` | 0.04 / 0.000 / 15 | 0.06 / 0.023 / 254 |
| `interior_chefs_house.png` | 0.01 / 0.002 / 155 | 0.01 / 0.002 / 155 |
| `interior_chefs_pantry.png` | 0.00 / 0.000 / 62 | 0.00 / 0.001 / 74 |
| `interior_council_chamber.png` | 0.00 / 0.000 / 15 | 0.00 / 0.000 / 17 |
| `interior_equipment_forge.png` | 0.03 / 0.000 / 21 | 0.01 / 0.000 / 25 |
| `interior_equipment_shop.png` | 0.01 / 0.001 / 98 | 0.01 / 0.001 / 107 |
| `interior_garrison_yard.png` | 0.03 / 0.000 / 23 | 0.02 / 0.000 / 13 |
| `interior_iron_companies.png` | 0.03 / 0.006 / 225 | 0.02 / 0.005 / 225 |
| `interior_kesselford_chandlery.png` | 0.01 / 0.003 / 168 | 0.01 / 0.003 / 168 |
| `interior_kesselford_wayhouse.png` | 0.00 / 0.001 / 168 | 0.01 / 0.001 / 168 |
| `interior_lower_trial_hall.png` | 0.72 / 0.184 / 232 | 0.74 / 0.188 / 230 |
| `interior_players_house.png` | 0.02 / 0.015 / 245 | 0.00 / 0.000 / 96 |
| `interior_players_loft.png` | 0.04 / 0.026 / 254 | 0.01 / 0.004 / 174 |
| `interior_registry_archive.png` | 0.02 / 0.015 / 245 | 0.04 / 0.020 / 245 |
| `interior_registry_stacks.png` | 0.06 / 0.023 / 254 | 0.04 / 0.001 / 57 |
| `interior_shrine_undercroft.png` | 0.04 / 0.000 / 11 | 0.06 / 0.000 / 27 |
| `interior_town_hall.png` | 0.02 / 0.000 / 24 | 0.09 / 0.017 / 245 |

## Captures in this folder (half size)

`20_town`, `23_battle_grid`, `24_wound_lip`, `interior_lower_trial_hall`, `interior_players_house`,
each as `--before` (baseline `56907748`) and `--after` (U0 final tree, third sweep). Full-size
originals and the amplified diff images are reproducible with the commands above.

## Not verified here

Combat-time rendering of `trial-keeper` / `trial-warden` (the fixed regression) is covered by the
unit test, not by a rendered capture; the sweep has no trial-hall combat scene. Multi-direction sets
do not exist yet, so the 8-way lookup is exercised only by `test_unit_frames.gd` fixtures.
