# Wave 2 acceptance evidence — world-map travel loop (+ thin loot beat)

**Date:** 2026-08-29 · **Contract:** `docs/fallout2-adoption-spec.md` Wave 2 acceptance
criteria. Commits under evidence: `71b77c0` (subtask 1 — travel data + systems),
`08440f3` (subtask 2 — journey lifecycle + persistence), `6e4968b` (subtask 3 —
geographic world-map UI + discovery), `e1bcb56` (screenshot evidence), `a68d475`
(subtask 4 — spoils).

## What shipped, per layer

- **Data:** `globals/travel/world_map_registry.gd` — 4 macro locations with normalized
  map coordinates; 3 route rows from Dom with steps, `phases_cost` (the per-route time
  formula recorded in data), `risk_tier`/`risk_modifier`, weighted encounter tables and
  min/max cadence bounds.
- **Systems:** `travel_plan.gd` (serializable journey state, clamped `from_dict`),
  `encounter_director.gd` (seeded deterministic schedule; avoidance = best party
  Survival preview, 95-cap semantics via `SkillCheckService.MAX_EFFECTIVE_PERCENT`,
  minus route risk), `spoils_table.gd` (per-encounter tables over existing GLoot ids;
  stream = `rng_seed + slot_index + 5_000_003`, disjoint from the avoidance stream
  `rng_seed + slot_index`).
- **Flow:** `GameFlow.start_journey/advance_journey/resolve_encounter_prompt/
  cancel_journey`; multi-step advances clamp at the first unresolved encounter
  boundary; battle interruption reuses `Battle.start()` + the `enter_battle` event;
  victory resolves the slot and grants spoils exactly once (`spoils_granted`), defeat/
  flee returns to the prompt. Persistence rides `GameState.travel_plan` additively
  (the `equipped_slots` pattern — **no schema bump**). World-map discovery is
  flag-backed (`GameState.discover_world_location`), set on genuine arrival, with a
  legacy fast-travel-hub bridge.
- **Presentation:** `RegionMapScreen` rebuilt as a geographic map — markers at
  normalized coordinates, route lines, party marker walking committed routes on a step
  timer, Survival avoidance prompt, journey continue/cancel, live-plan restore on
  reopen. Theme type variations only (scan-enforced).

## Acceptance items

| Criterion | Evidence |
|---|---|
| Travel round-trip playable | `test_region_map.gd` commits a plan from the screen through `GameFlow.start_journey`; `test_travel_flow.gd` arrival routes through the production `GameFlow.travel()` path and advances WorldClock by exactly the route's `phases_cost`; screenshot `docs/qa/wave2-world-map.png` |
| Save/reload at journey states resumes correctly | `test_travel_flow.gd::test_mid_journey_save_reload_preserves_plan_and_avoidance_stream` (en-route + prompt; the reloaded avoidance roll reproduces the pre-save result); post-battle reload covered by the spoils reload test. Mid-battle save is not a Ch1 behavior (Wave-C T-8 ruling) — model-level serialization covers it |
| Avoidance respects skill and caps | `test_encounter_director.gd` (95-cap minus risk modifier, floor 0); avoidance stream seeded per slot (`rng_seed + slot_index`) so reload never rerolls |
| Risk display derives from the real table | Region-map route panel reads `risk_tier` from the registry row; `test_region_map.gd` asserts the MODERATE tier word renders and **no numeric chance appears** (owner ruling: tagged, no numbers) |
| Spoils exactly-once under reload | `test_travel_flow.gd::test_battle_victory_grants_spoils_exactly_once_across_duplicate_events_and_reload` (duplicate `battle_ended` emissions + save/clear/reload + re-emission → counts unchanged); `test_spoils_table.gd` asserts prototype-id round-trip for every rolled id |
| Suite green | Full gdUnit4 run post-`a68d475`: **915 test cases / 0 errors / 0 failures / 0 flaky** |
| Quest audit | Production run at `a68d475`: **0 errors**; 12 warnings in the two pre-accepted classes (`outcome_count` 7, `orphaned_flags` 5) + 7 `readbacks` info notes |

## Deliberately not decided / residuals

- Encounter tables and spoils quantities are PROVISIONAL balance surfaces (owner
  balance decision), same class as `EncounterCatalog._WEATHER_DEFAULTS`.
- The GP-toll fast-travel path is superseded on this screen for the 4 macro locations
  (spec: FR-503 REPLACE, ratified); `FastTravelRegistry` itself remains for legacy
  discovery bridging and is untouched elsewhere.
- Cosmetic: the current-location (DOM) marker renders faint against the map ground —
  follow-up polish candidate.
- Day/night arrival pass-through is the existing `WorldClock.advance` behavior;
  arrival advances exactly `phases_cost` phases (asserted).
