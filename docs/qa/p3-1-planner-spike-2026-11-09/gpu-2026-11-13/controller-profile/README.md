# Combat controller profile (2026-11-13)

Owner ruling 44 (a), 2026-11-13: profile and cut the combat controller's turn and decision cost,
then rerun the #603 spike. This folder is the profile. The work to cut the cost is the issue
linked from #603.

## Method

- Same machine and renderer as the parent folder: WSLg, Mesa D3D12 on the Radeon RX 580,
  `--disable-vsync`, one Godot at a time, isolated user data. Runner:
  [`run_profile.py`](run_profile.py).
- The default FR-904 mode of `tools/populated_field_benchmark.gd`, with no planner. 100 hostiles
  were requested and 99 admitted. The 9 ally turns are the benchmark's decision window.
- [`instrumentation.patch`](instrumentation.patch) applies to commit `51b1fd30`. It adds wall-clock
  timers (`Time.get_ticks_usec`) around the controller's snapshot fields, event emission, drive
  loop and enemy resolution, and an `--ablate` pass for idle frames. The timers cost time of their
  own, so compare shares, not absolute totals, with the parent folder.
  Run 1 ([`run1-timers.json`](run1-timers.json)) timed the snapshot and the drive loop. Run 2
  ([`run2-timers.json`](run2-timers.json)) also timed the inside of each enemy decision.

## Result

Every one of the 104 enemy decisions in the window was a move toward the party; none struck.

| # | Where | Cost per call | Calls | Share |
|---|---|---|---|---|
| H1 | `snapshot()` → `_movement_snapshot()` → `_price_reachable()` | 54–60 ms | every event emitted while the state is `ALLY_TURN`: 2–3 per ally turn | ~110 ms of a ~130 ms ally turn with no enemy decision |
| H2 | `snapshot()` without movement: `_actor_snapshots(enemies)` 3.8–4.7 ms, `_tile_snapshots()` cache check 1.4–1.6 ms | ~6–7 ms | every event (130 in the window) | ~40 % of an enemy decision |
| H3 | `_best_enemy_position()` | 6.4 ms | each enemy move | ~40 % of an enemy decision |
| H4 | `_resolve_enemy_move()`: `path_query` 1.6 ms, `_apply_action` 1.6 ms | 3.2 ms | each enemy move | ~20 % of an enemy decision |
| — | `plan_enemy_turn()` | 0.08 ms | each enemy decision | — |

- An ally turn with no enemy decision took 118–206 ms (run 1). A yield emits `turn_ended` and the next
  `turn_started` while the state is `ALLY_TURN`; each prices the active ally's reach again (H1).
- An enemy decision took 13.6 ms (run 1) and 16.7 ms (run 2) on average, against D9's 2 ms.
- Listeners are small: `action_resolved` listeners take 0.3 ms per event and `turn_ended` 8 ms.
- `_price_reachable()` runs the full `query_action_for()` gate for every reachable stand, on a
  shared path memo (#282). `_best_enemy_position()` runs its own reach search, and then
  `path_query` searches again for the chosen cell (H4).

## Idle frames are not the controller

With 99 hostiles admitted and nobody acting, frames take about 21–24 ms. With processing
switched off for the whole scene (`PROCESS_MODE_DISABLED` on the current scene), they still take
20.7 ms ([`idle-frame-ablation.json`](idle-frame-ablation.json)). Switching off hostiles,
BattleInterface, the combat overlay, the field HUD or the party moves the frame by at most 1.4 ms,
within the run's drift between the before and after baselines (up to 2.1 ms). Physics takes
0.2–0.3 ms. The idle cost is outside scene processing, most likely rendering: draw calls rise
from 139 to 537 when the fight opens. WSLg adds a GL→D3D12 layer, so this machine cannot tell how
much of it remains on native Windows; that is the Phase 6 reference-hardware gate.
