# P1.5 region-map journey, end to end — 2026-11-19

Issue #534 (Roadmap P1.5), verification only. No production file changed.

**Verdict: FAIL.** A journey started from the region map never reaches its destination: the
plan says ARRIVED and the clock is spent, but the party stays on the origin field. A journey
ambush never enters the battle state, so it has no battle HUD. From Dom's new-game spawn, the
ambush on the chapter road cannot seat and strands the plan. The gaps are filed for a separately
approved implementation issue: **#649** (owner-decisions item 46).

## How it was run

`test/manual/region_map_journey_capture.gd`, a temporary autoload driven under Xvfb at 1280×720
with isolated user data (Godot 4.7.1). Start a new game, then press Esc → REGION MAP → the
destination marker → BEGIN JOURNEY. The map's own 0.5 s step timer carries the journey. Each
prompt gets AVOID. A won fight is followed by Esc → REGION MAP → CONTINUE. KitAI autoplay plays
the party's turns. Pass means the destination scene loads, the plan reads ARRIVED, and the clock
moved by the route's phases.

Setup, not under test: the destination is marked discovered (standing in for one earlier walk
there). For the Dorthkor Road origin, the party is placed there with `GameFlow.travel`, the call
an exit makes. The recipe is in the script's header.

## What works

- **Selection and feedback.** The Dorthkor Road marker is pressable once discovered. The panel
  shows `ROUTE · 12 STEPS`, `TRAVEL TIME · 3 PHASES` and `ENCOUNTER RISK · MODERATE`, matching
  registry route `dom-dorthkor_road`. BEGIN JOURNEY is enabled.
- **Start and travel.** BEGIN JOURNEY calls `GameFlow.start_journey()` and leaves an EN_ROUTE plan
  with 1–2 scheduled ambushes; the schedule differs per new game. The step timer advances the
  party marker and stops at each scheduled step with the ambush prompt (risk tier, no
  percentage).
- **AVOID.** AVOID rolls the per-slot avoidance. All seven attempts across six runs failed. The
  success branch is covered by `test_avoid_and_stand_ground_buttons_call_game_flow`.
- **Fight and CONTINUE.** On Dorthkor Road the ambush seats and KitAI wins it (VICTORY, 6–19
  steps). The plan returns to EN_ROUTE. Reopening the map offers CONTINUE, and CONTINUE resumes
  the timer.
- **Existing suites pass:** 39 cases, 0 failures (`test_region_map.gd` 10,
  `test_travel_flow.gd` 20, `test_fast_travel.gd` 9).

## Gaps (all in #649)

The only player route to the region map is the pause menu, so every journey runs with the
`GameFlow` chart in `Playing/Paused`. That state has `resume` and `to_main_menu` transitions only.

1. **Arrival is dropped.** At step 12/12, `advance_journey()` marks the plan ARRIVED and spends
   the route's phases. `travel()` returns true but its `travel` event is ignored in `Paused`. The
   map closes onto the pause menu, and after resume the party is still on Dorthkor Road. Frames
   [14](p1-5-region-map-journey-2026-11-19/dorthkor_road-to-dom/14-plan-arrived.jpg) and
   [15](p1-5-region-map-journey-2026-11-19/dorthkor_road-to-dom/15-resumed-after-arrival.jpg).
2. **The ambush never enters `Battle`.** `enter_battle` is ignored in `Paused`. The fight opens
   behind the map
   ([07](p1-5-region-map-journey-2026-11-19/dorthkor_road-to-dom/07-ambush-opened.jpg)).
   After BACK and resume, the chart goes to `Active`, so the fight sits on the field under the
   exploration HUD with no battle bar
   ([08](p1-5-region-map-journey-2026-11-19/dorthkor_road-to-dom/08-ambush-fight.jpg)).
   Only autoplay could finish it.
3. **A refused ambush strands the plan.** `resolve_encounter_prompt()` sets IN_BATTLE before
   `Battle.start_set_piece()` and ignores its refusal. The prompt hides. CANCEL is shown but
   `cancel_journey()` refuses IN_BATTLE. A reopened map offers neither CONTINUE nor CANCEL
   ([07](p1-5-region-map-journey-2026-11-19/dom-to-dorthkor_road/07-stranded-map.jpg),
   [10](p1-5-region-map-journey-2026-11-19/dom-to-dorthkor_road/10-region-map.jpg)).
   By code reading, only a reload clears it: `TravelPlan.reconcile()` demotes the plan to
   AVOID_PROMPT.
4. **Dom's walking grid misses the town.** This is what triggers (3) on the chapter road. The
   new-game spawn is cell (14, 111), outside the grid. Seating refuses with "The party cannot
   enter combat from this hex", and click-to-move from there answers "There is no route to that
   spot." A grid probe found 13 of Dom's 17 `Spawn*` markers off the grid, including
   `SpawnNewGame`, `SpawnDefault` and `SpawnFromDorthkor`. Every other field puts the arriving
   party on the grid. In `world/starting_town.tscn`, `IsometricGround` is 54×69 at scale 1 while
   `Blocking` is scaled 2.2; both date from 5c1d3491 (2026-08-10).

## Why the suites stay green

They call `GameFlow` directly with the chart in `Active`. They assert staged state:
`_target_scene` and `Battle.encounter_id`. None of them opens the map from the pause menu,
checks the chart's state after `enter_battle` or `travel`, or waits for a scene change.

## Not verified

- A lost ambush.
- A human taking turns in gap (2).
- Reload out of the stranded state (code reading only).
- Whether the other fields' off-grid `SpawnSlot*` and `SpawnFromHollowmere` markers are outside
  the grid or on a blocked cell (the probe did not tell these apart).
- The legacy coin-cost `GameFlow.fast_travel()` (FR-503). It has no production caller, so the
  region-map journey is the only player path.

## Files

- Dom → Dorthkor Road: [`dom-to-dorthkor_road/`](p1-5-region-map-journey-2026-11-19/dom-to-dorthkor_road/),
  10 frames and `journey.log`.
- Dorthkor Road → Dom: [`dorthkor_road-to-dom/`](p1-5-region-map-journey-2026-11-19/dorthkor_road-to-dom/),
  15 frames and `journey.log`.
