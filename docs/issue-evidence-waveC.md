# Wave C issue evidence — tactical gate proofs

All verification on this branch (base f54b6a0), suite:
`Overall Summary: 722 test cases | 1 errors | 4 failures` — failures confined to the
known baseline suites (test_actor_presentation, test_y_sort, test_click_to_move_input).
**Zero new failures.** Gate tests live in `test/integration/test_wavec_tactical_gates.gd`.

## #176 — Gate T-10, AP migration completeness
- `rg -n "action_points|ap_cost" globals/ ui/` → **0 hits** (was 14 in combat_controller.gd).
- Compatibility paths characterized in
  `test_gate_t10_ap_compatibility_paths_are_characterized_and_documented`.
- Verdict: SATISFIED.

## #200 — _force_pass loop guard
- `scheduler.force_advance(actor)` gives the refusal path a bounded, zero-refund exit;
  proven by `test_force_pass_has_a_bounded_zero_refund_exit_when_action_gates_are_closed`.
- Verdict: SATISFIED.

## #171 — Gate T-4, queue integrity
- `test_gate_t4_queue_integrity_across_three_large_battles`: 8+ combatants across 3
  battles — no starvation, no duplicate turns, no dropped interrupts, no deadlock,
  deterministic ties, waits at the cap boundary, mid-battle removals.
- Verdict: SATISFIED.

## #170 — Gate T-3, three orphaned P0s
- `test_gate_t3_defining_strike_weather_bias_and_mid_queue_speech_victory`:
  CT-priced Defining Strike (quoted price charged exactly), Balance-driven weather bias
  (order charges faster than chaos over a full measure), safe mid-queue speech victory.
- Verdict: SATISFIED.

## #172 — Gate T-5, speech-interrupt determinism
- Same test: speech victory with banked enemy CT (genuinely mid-queue) reaches FINISHED,
  enemy HP untouched (zero partial effects), no `action_resolved` events after
  `battle_finished` (zero queued actions), and the final snapshot+event log is
  byte-round-trip identical.
- Verdict: SATISFIED.

## #173 — Gate T-7, determinism
- `test_gate_t7_resolution_and_tactical_round_trip_are_byte_deterministic` +
  `test_gate_t7_whole_encounter_and_equal_cost_path_are_repeatable`: same-seed equality,
  forecast == resolution, equal-cost paths resolve to the lowest cell index.
- Verdict: SATISFIED.

## #174 — Gate T-8, tactical save round trip
- Model level (this wave): grid position/facing/elevation, CT incl. overflow and
  consecutive-wait counters, tile charge/residue, weather phase/tick, expert rerolls —
  all round-trip byte-identical.
- Save level (schema 6, merged in wave A/#141 work): the `tactical` UnitRoster envelope
  persists through SaveGame with corruption rejection (test_save_game.gd,
  test_save_migrations.gd). No schema bump needed.
- Note: mid-battle saving is not a Chapter-1 behavior (battle is an overlay; saves occur
  in the field), so in-battle tile/weather state lives in the battle snapshot, proven
  reload-identical under #172.
- Verdict: SATISFIED.
