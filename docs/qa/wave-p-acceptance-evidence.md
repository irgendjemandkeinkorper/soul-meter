# Wave P acceptance evidence — square-grid tactics (positioning, LOS, cover, flanking)

Owner-ratified scope (`docs/fallout2-adoption-spec.md`, "Wave P" amendment): all four
tactical rules on the CURRENT square grid (hex deferred to the FR-105 battlefield-model
seam), shipped across three subtasks — P1 model/controller core (merge `3ca7512`),
P2 click-to-move battle UI (merge `96fb25d`), P3 enemy positional AI (this branch).

## The four ratified rules and their proofs

| Rule | Model/controller proof | UI/AI proof |
|---|---|---|
| Click-to-move, AP-costed | `test_combat_controller.gd::test_player_move_spends_path_ap_and_updates_snapshot_position`, `::test_player_move_refuses_occupied_destination_without_spending_ap`, `::test_snapshot_exposes_move_range_and_path_costs_additively` | `test_battle_pointer_controls.gd::test_hover_quote_click_move_and_snapshot_refresh_use_controller_events` (hover shows `move_query`'s exact AP quote; click commits and AP drops by it) |
| LOS gates ranged actions | `test_combat_controller.gd::test_ranged_los_refusal_matches_at_forecast_and_commit` (FR-606 taxonomy preserved, forecast==commit); `test_grid_battlefield_model.gd::test_line_of_sight_from_high_ground_sees_over_low_cover` | `test_battle_pointer_controls.gd::test_blocked_los_enemy_click_does_not_submit` (refusal message rendered, no AP spent); `test_combat_controller.gd::test_melee_enemy_routes_around_an_occupied_elevated_line`, `::test_unreachable_enemy_emits_the_model_los_refusal_taxonomy` |
| Real cover | `test_grid_battlefield_model.gd::test_cover_bonus_applies_when_target_hugs_cover_toward_the_shooter`, `::test_cover_beside_the_attacker_grants_the_defender_nothing` (defender-anchored, directional), `::test_cover_bonus_is_zero_when_shot_line_has_no_cover`; `test_combat_controller.gd::test_grid_cover_changes_forecast_and_resolution_by_the_same_amount` | Cover glyphs on covered tiles (stage procedural draw, asserted via `cover_marker_count`); `test_combat_controller.gd::test_enemy_prefers_cover_over_an_equal_distance_open_cell` |
| Flanking / facing bonus | `test_grid_battlefield_model.gd::test_flank_bonus_applies_from_back_and_side_but_not_front`; ratified facing multipliers (×1.10 side / ×1.25 back) ride the positional context — flat `flank_bonus` zeroed whenever positional context is non-empty (no double dip) | Region D names flank terms in the forecast copy; `test_combat_controller.gd::test_enemy_prefers_rear_flank_over_cover_when_both_are_reachable` (weight ordering pinned) |

Zone battles bypass all of it: `test_combat_controller.gd::test_zone_model_owns_legality_cover_flank_and_aoe_shapes`,
`::test_enemy_position_scoring_bypasses_cellless_zone_battlefields`. Determinism:
`::test_enemy_position_choice_is_deterministic_across_identical_runs`.

## Sweep byte-identity (encounters without cover/flank terrain unchanged)

- Command (both trees): `godot --headless --path . --script res://tools/combat_number_sweep.gd`
- Run 2026-08-29 against this branch and against `main@0add5a4`; outputs
  **byte-identical** after stripping engine teardown warnings (`diff` clean).
  Wave P's positional terms only enter when cover/flank/LOS geometry exists;
  authored encounters carry none yet, so today's numbers are untouched.

## PROVISIONAL balance values (owner pass pending, with the rest of the flagged pile)

- Cover defense bonus magnitude (`GridBattlefieldModel.cover_bonus`) — P1.
- Move AP pricing: per-cell rate × path cost units from `ct_cost` — P1.
- Enemy AI position weights (`combat_controller.gd`): elevation ×1000,
  adjacency +500, **cover +750 (`_ENEMY_COVER_POSITION_SCORE`, new in P3)**,
  rear-flank +1000. Ordering rationale: cover matters, flanking matters more
  (pinned by `test_enemy_prefers_rear_flank_over_cover_when_both_are_reachable`).

## Suite evidence

- P3 branch full suite: see delivery log entry (run after this file's commit).
- Main at P2 merge + Wave O revisions: 988 cases / 0 failures (solo run, `0add5a4`).
