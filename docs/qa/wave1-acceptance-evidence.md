# Wave 1 acceptance evidence — AP combat rhythm

**Date:** 2026-08-28 · **Contract:** `docs/fallout2-adoption-spec.md` Wave 1 acceptance
criteria. Commits under evidence: `2f9762d` (implementation), `41675c1` (merge),
`c9bb675` (completion fixes), plus the develop→deliver REVISE-response commit that
carries this file.

## Suite

- Full gdUnit4 run: `GODOT_BIN=~/.local/bin/godot bash addons/gdUnit4/runtest.sh -a test`
  → **885 / 0** post-`c9bb675` (report `reports/report_658`), and **887 test cases /
  0 errors / 0 failures / 0 flaky** after the REVISE-response changes recorded below
  (the +2 are the two new regression cases).

## Quest audit (production run, not the unit suite)

- Command: `godot --headless --path . --script res://tools/quest_audit.gd`
- Result: **0 errors** across all six categories; 12 warnings, all in the two
  pre-accepted classes (`outcome_count` 7 — same class as the accepted
  Serai/Wyneth/Grumbrand quests; `orphaned_flags` 5 — `flag_written_never_read`).

## Screenshot (post-Wave-1)

- `docs/qa/wave1-battle-screen.png` — captured via
  `xvfb-run -a -s "-screen 0 1920x1080x24" bash addons/gdUnit4/runtest.sh -a test/manual/screenshot_battle_screen.gd`
  at HEAD. Visible: AP cost on every command label (STRIKE · 2 AP … DEFINING
  STRIKE · 3 AP), the END TURN button in the command dock, Region E rendering the
  complete AP round order with per-actor state and AP pips
  (ACTIVE ●●●● / PENDING ●●●●●●). Known cosmetic follow-up: the active-unit
  plate's third line still reads "CT n" under the AP scheduler (test-pinned plate
  contract; relabel is a separate additive change).

## combat_number_sweep byte identity

- Command (both runs): `godot --headless --path . --script res://tools/combat_number_sweep.gd`
- Baseline: commit `4ad15c8` (pre-Wave-1) in a clean worktree.
- HEAD sha256: `cef47446daba8733d3a633850d6e533f1a8807b99949b87457766e4a71f2da4b` (69 lines)
- Baseline sha256: `cef47446daba8733d3a633850d6e533f1a8807b99949b87457766e4a71f2da4b` —
  **BYTE-IDENTICAL** (`diff` empty). Wave 1 does not move a single resolution number
  on untouched paths; the weakness context is additive and absent from the sweep.

## Six-region contract review (additive-only)

Reviewed surfaces, Wave 1 diff vs `4ad15c8`:

- `BattleInterface` public contract (`consume_event`, `tile_selected`,
  `rendered_tile_count`, `select_tile`, `tile_hovered`): **unchanged**.
- Snapshot payload: **added keys only** — top-level `scheduler_mode`, `turn_order`;
  per-actor `unused_ap_defense_bonus`; per-`turn_order`-row `scheduler_mode`,
  `ap_remaining`, `max_ap`, `acted`, `pending`, `active`, `actor_id`,
  `display_name`. No key removed or retyped; CT rendering in Region E preserved
  (branch on `scheduler_mode == &"ap_round"`, legacy path intact).
- Region node topology: unchanged (six regions; `CTTimelineRegion` node kept, now
  rendering AP rounds when the payload says so).
- `turn_ended` event payload: added `forfeited_ap`, `unused_ap_defense_bonus`.

## Develop→deliver gate REVISE response (this change)

1. **Region E completeness:** `ApRoundScheduler.round_overview()` returns every
   living participant in seat order (acted included, no depth cap);
   `CombatController._turn_order_snapshot()` uses it. Production-snapshot
   regression: `test_combat_controller.gd::test_snapshot_turn_order_keeps_spent_actors_visible`.
2. **Forecast coherence:** `forecast_defining_strike()` no longer mutates the pure
   Resolution result — the landed (post-mitigation) figure is the top-level
   `damage` key, computed through the same `calculate_damage` pipeline resolution
   uses; the nested `resolution` dict stays the pure pre-mitigation contract.
   Parity assertions strengthened in
   `test_defining_strike_requires_selection_and_forecast_matches_resolution_context`.
3. **Zero-cost enemy guard regression test:**
   `test_ap_round_scheduler.gd::test_a_zero_cost_enemy_action_under_full_ap_still_ends_its_turn`.
4. **Stale AP-retirement comments** in `ap_round_scheduler.gd` / `battle_actor.gd`
   updated to the ratified CT→AP promotion (Gate T-10 amendment).
