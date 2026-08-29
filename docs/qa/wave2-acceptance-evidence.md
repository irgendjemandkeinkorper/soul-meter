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
| Save/reload at journey states resumes correctly | Envelope round-trip tests per state in `test_travel_flow.gd`: AVOID_PROMPT (`test_mid_journey_save_reload_preserves_plan_and_avoidance_stream` — the reloaded avoidance roll reproduces the pre-save result), IN_BATTLE (`test_in_battle_save_reloads_to_a_resumable_avoid_prompt` — battle runtime never rides the envelope, so restore demotes to a resumable prompt via `TravelPlan.reconcile()`), stale prompt (`test_prompt_state_with_no_reached_slot_reloads_to_en_route`), out-of-bounds slot (`test_out_of_bounds_slot_is_clamped_on_reload_and_blocks_arrival`), finished states clear to no plan (`test_finished_journey_states_reload_to_no_plan`); post-battle reload covered by the spoils reload test; cancel is tested from both EN_ROUTE and AVOID_PROMPT |
| Avoidance respects skill and caps | `test_encounter_director.gd` (95-cap minus risk modifier, floor 0); avoidance stream seeded per slot (`rng_seed + slot_index`) so reload never rerolls |
| Risk display derives from the real table | Region-map route panel reads `risk_tier` from the registry row; `test_region_map.gd` asserts the MODERATE tier word renders and **no numeric chance appears** (owner ruling: tagged, no numbers) |
| Spoils exactly-once under reload | `test_travel_flow.gd::test_battle_victory_grants_spoils_exactly_once_across_duplicate_events_and_reload` (duplicate `battle_ended` emissions + save/clear/reload + re-emission → counts unchanged); `test_spoils_table.gd` asserts prototype-id round-trip for every rolled id |
| Suite green | Full gdUnit4 run (`runtest.sh -a test`, includes `test/manual` harnesses) post-`a68d475`: **915 / 0**; post-REVISE-response run below. The CI-style `scripts/test.sh` count is 12 lower (manual screenshot harnesses excluded) |
| Quest audit | Production run at `a68d475`: **0 errors**; 12 warnings in the two pre-accepted classes (`outcome_count` 7, `orphaned_flags` 5) + 7 `readbacks` info notes |

## Gate REVISE response (2026-08-29)

The manual codex gate (`embrace-gate-wave2-manual-*.md`) returned REVISE with two
blockers; both are addressed in the follow-up commit carrying this section:

1. **Restore invariants:** `TravelPlan.reconcile()` (called by
   `GameFlow._restore_travel_plan()` on every restore) demotes IN_BATTLE to a
   resumable AVOID_PROMPT, demotes a prompt with no reached unresolved slot to
   EN_ROUTE, clamps slot `at_step` into `[0, total_steps]` so arrival can never
   skip an unresolved slot, and clears ARRIVED/CANCELLED plans to none.
   `GameFlow._next_reached_slot_index()` now delegates to the model's
   `next_unresolved_reached_index()` (single source of truth).
2. **Test honesty:** per-state envelope regression tests added (see the
   save/reload row above); this document's claims were corrected to cite them.

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
