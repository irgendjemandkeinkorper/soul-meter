# #649 region-map journeys from the pause menu — 2026-11-19

Issue #649 (owner item 46, approved 2026-11-19). It fixes the gaps that the P1.5 verification
found (`docs/qa/p1-5-region-map-journey-2026-11-19.md`, PR #650).

**Verdict: PASS.** Both directions of the chapter road now finish the way a player plays them:
Esc → REGION MAP → marker → BEGIN JOURNEY → AVOID → fight → CONTINUE → arrival. In each, the
destination scene loads, the plan reads ARRIVED, and the clock moves by the route's 3 phases.

| Route | Ambushes | Fights | Result |
|---|---|---|---|
| Dom → Dorthkor Road | steps 5 and 7 (dorthkor-vanguard, loam-boar) | both VICTORY | `JOURNEY-CAPTURE: ok` |
| Dorthkor Road → Dom | step 6 (dorthkor-vanguard) | VICTORY | `JOURNEY-CAPTURE: ok` |

Frames and logs: `649-journey-flow-fix-2026-11-19/<route>/`. Only the key frames are kept.

## What changed

1. **The paused game can start fights and load scenes.** `ui/flow/game_flow.tscn` adds
   `Paused —enter_battle→ Battle` and `Paused —travel→ Loading`. Both guards add
   `not resume_to_battle` to Active's guards. Leaving Paused closes the menu stack and unpauses
   the tree, as resuming does. `travel()` and `load_destination()` check the guard of the state
   that is active.
2. **A fight paused under the menu refuses journeys.** `GameFlow.journey_refusal()` returns
   `FINISH THE FIGHT BEFORE TRAVELLING` while Battle is active or paused. `start_journey`,
   `advance_journey` and `resolve_encounter_prompt` all honour it, and the map shows it as its
   status line. Without it, an ambush opened from the map would replace the paused fight's
   session.
3. **A refused ambush no longer strands the plan.** When `Battle.start_set_piece` refuses
   (seating, open ground), the plan goes back to AVOID_PROMPT and is saved. The map shows
   `NO GROUND TO MEET THE AMBUSH HERE · CANCEL TO TURN BACK`, and CANCEL works.
4. **Dom's spawns stand on its walking grid.** `IsometricBlockout` gains `cell_origin`.
   `SolidFootprints` reads the ground's real cell rect. Dom's `IsometricGround` now spans
   `cell_origin (-7, -59)`, `map_size (134, 133)`: the camera rect, inside which the player can
   already walk. Its position and scale are unchanged.

## Evidence

- `07-ambush-opened.jpg` (both routes): the chart is in Battle, and the field HUD's combat bar is
  open where the party stands. There is no BACK + Esc detour. The tree is unpaused.
- `10-combat-continue.jpg` → `11-spoils.jpg` → `12-after-fight-field.jpg`: CONTINUE, then spoils
  and TAKE ALL. The chart returns to Active and the plan to EN_ROUTE.
- `15-continue-offered.jpg` → `*-arrived.jpg`: the reopened map offers CONTINUE, and arrival
  loads the destination (`dorthkor_road.tscn` / `starting_town.tscn`). Journey phases are 3,
  the route's 3.
- Party cells: Dom spawn (14, 111) and Dorthkor Road spawn (-94, 121), both inside the walking
  grid and not blocked.

## Tests

- New `test/integration/test_journey_from_pause.gd`, 4 cases: a failed avoid enters Battle, and
  arrival enters Loading for the destination, both from Paused. A paused fight refuses
  journeys. An unseatable ambush returns the prompt, and CANCEL loads the origin. It is green
  on the fix and red on the old code (2 errors, 8 failures).
- New `test/integration/test_field_spawns_on_grid.gd`: every `Spawn*` marker in the eight field
  scenes stands on a walkable cell. It is green on the fix and red on the old Dom ground, where
  13 markers were off the grid. Five markers that stand on blocked cells are listed as known
  exceptions (below). If one starts passing, the test fails, so the list cannot go stale.
- Affected batch, 64 cases green: the new suite (4), region map (10), travel flow (20), fast
  travel (9), Weftlumin shell (17), and reputation area access (4).
- Full tree: see the PR.

## Not fixed here (outside the approved scope)

These five spawn markers stand inside their grid on blocked cells. They are listed in the guard
test, not moved:

- Dom `SpawnFromRiverShrine`, 20 px south of the shrine door on the shrine's rock. Before #649
  it was off the grid entirely. The walkable ground is north of the door. Moving it is a level
  edit for the owner to approve.
- Dorthkor Road `SpawnFromHollowmere`, a walk-in arrival spawn.
- Ashlaren `SpawnSlotFieldMargin`, Long Verge `SpawnSlotGraveMound` and Hollowmere
  `SpawnSlotReedShallows`. These are Weftlumin spawn-table anchors for NPCs and hostiles, not
  party spawns.

## Behaviour changes to know

- **CANCEL from the map now travels to the origin.** Before, the `travel` event was dropped in
  Paused. The plan was cleared and the clock advanced, but the party stayed put.
- **Dom's grid build cost grows.** Headless, it went from 168 ms to 915 ms, against Kesselford's
  512 ms. The hex graph covers every hex in the region rect, so cost scales with area.
  Narrowing it to the walkable footprint is a separate optimisation.
- **Multi-wave fights were not exercised.** In one earlier run, Dorthkor Road's own Gnaal joined
  after the vanguard fell. The capture now plays every wave until CONTINUE, but neither passing
  run drew that case.

## How it was run

`test/manual/region_map_journey_capture.gd`, a temporary autoload under Xvfb at 1280×720 with
isolated user data (Godot 4.7.1). Run it with `SOUL_METER_JOURNEY_ROUTE=dom:dorthkor_road` and
then `dorthkor_road:dom`. The recipe is in the script's header. KitAI autoplay plays the party.
Like the P1.5 run, the destination is marked discovered.

Headless and Xvfb runs prove the flow and its state. They do not prove visual polish on real
hardware.
