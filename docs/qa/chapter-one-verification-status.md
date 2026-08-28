# Chapter One verification status

**Updated:** 2026-08-28  
**Scope:** current local worktree, including Claude's inherited presentation changes and
the subsequent combat, portrait, dialogue, interior, quest-reward, and release-readiness QA slices.

This is an evidence ledger, not a claim that Chapter One has passed its human ship gate.
The automated checks below are reproducible. The outside-player obligations in
`docs/playtest-protocol.md` must not be replaced with agent simulation.

## Automated evidence

| Requirement surface | Evidence | Current result |
|---|---|---|
| Full deterministic suite | `SOUL_METER_LOCALE_STRICT=1 bash scripts/acceptance_gate.sh` | 862 tests, 0 errors, 0 failures (`reports/report_631/results.xml`) |
| Canonical/generated data | `bash scripts/check_generated_data.sh` | Pandora and 598 isometric sprites report no drift |
| Localization catalogs | strict acceptance artifact check | 53 msgids aligned across `locale/project.pot`, `data/generated/items.pot`, and `locale/es.po` |
| Critical-path state journey | `bash scripts/test.sh -a test/e2e/test_first_chapter_journey.gd` | 10 tests pass |
| Gate T machine-verifiable criteria | Gate-focused suites and save-envelope tests | Criteria 1–5, 7–8, and 10 pass; see `docs/qa/gate-t-current-evidence.md` |
| Combat presentation/runtime | `test/integration/test_battle_interface.gd`, `test/integration/test_combat_controller.gd` | Encounter-aware Dorthkor battlefield and combat state tests pass |
| Named conversation portraits | `test/integration/test_dialogue_balloon_portraits.gd`, `test/unit/test_dom_npc_roster.gd` | Marshal, Iris, Sella, Hadrik, and Toma resolve authored art |
| Interior presentation | `test/integration/test_building_interiors.gd` | Full-HD backdrop coverage and all registered round trips pass |
| Wilds presentation/depth | `test/integration/test_wilds_presentation.gd`, `test/integration/test_y_sort.gd` | Authored terrain coverage passes; fixed backdrop layers preserve actor y-sort |
| Quest reward presentation | `test/unit/test_quest_registry.gd`, `test/integration/test_reward_reveal.gd` | Atomic reward summaries, queued modal delivery, standard/reduced motion, focus, and dismissal pass |
| Exported playtest runtime | `scripts/build_playtest.sh --allow-dirty --output-dir /tmp/soul-meter-playtest-build` plus a TCP-only Xvfb launch | Linux release export, eight-second headless boot, and rendered 1280×720 main-menu launch pass; hashes verify; manifest correctly marks the dirty worktree build as local-only |
| Visual capture sweep | `bash scripts/test.sh -a test/manual/screenshot_sweep.gd` | 9 capture tests pass at 1920×1080 |

The critical-path journey covers boot, recruitment, commission, a side thread,
encounters, an atomic Dom ruling, all three ending outcomes, extreme Soul values,
defeat/retreat retry routes, checkpoint reconstruction, and milestone advancement.
It proves state-machine reachability; it does not prove player comprehension,
playtime, readability, or narrative coherence.

## Visual evidence

Godot writes the current captures below
`user://qa` (the headless test environment resolves this to
`/tmp/soul-meter-godot-data/godot/app_userdata/SoulMeter/qa`):

- `16_marshal_conversation.png`
- `17_iris_conversation.png`
- `18_sella_conversation.png`
- `19_hadrik_conversation.png`
- `19_toma_conversation.png`
- `20_town.png`, `21_wilds.png`, and `22_dorthkor_road.png`
- `30_tavern_interior.png` through `33_river_shrine_interior.png`

The separate battle capture is
`/tmp/soul-meter-godot-data/godot/app_userdata/SoulMeter/battle_screen_qa.png`.
The quest-reward capture is
`/tmp/soul-meter-godot-data/godot/app_userdata/SoulMeter/reward_reveal_qa.png`.
The rendered exported-build capture is
`/tmp/soul-meter-exported-main-menu-window.png`.

## External Gate T evidence still required

These remain **not run / not proven**:

1. Gate T criterion 6: an unaided 45–90 minute session with each of 3–5 outside
   players. Record each player's answers to all four comprehension questions in
   `test/manual/gate-t/`; a majority must answer each question correctly.
2. Gate T criterion 9 / FR-904: three valid rendered runs on declared reference
   hardware, using the populated-grid scenario. The preserved Xvfb run is
   provisional evidence only and cannot satisfy this criterion.

All other Gate T criteria currently have machine evidence. The exact commands,
results, and limitations are recorded in `docs/qa/gate-t-current-evidence.md`.

## Later human ship evidence still required

These obligations remain after Gate T:

1. Four complete archetype playthroughs: martial, caster, talker, and
   balanced/refusal.
2. Manual confirmation that the critical path is completable without debug tools.
3. The 8–12 dense-hour playtime floor.
4. FR-906 narrative-coherence review against the world-state matrix.
5. A dedicated accessibility pass. The comprehension protocol explicitly does not
   certify accessibility.

Use `docs/playtest-protocol.md` verbatim for the outside-player sessions. Record
each tester separately and apply the per-question majority rule.

## Current visual review risks

- Shared interiors now cover the full-HD viewport without gray clear-color bands,
  but their environmental dressing remains deliberately dark and sparse.
- The Wilds now uses an authored 2000×1200 Loamroot terrain plate instead of the
  repeated 64×32 blockout tile. Its navigation and content layout are unchanged;
  final human review should still judge encounter readability while moving.
- The worktree is intentionally uncommitted and contains interleaved inherited
  Claude changes. Split/review ownership before creating commits.
