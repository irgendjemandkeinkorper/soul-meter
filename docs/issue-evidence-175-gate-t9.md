# Gate T-9 populated-grid benchmark handoff

## Status

The planner-approved steady-state measurement ruling is implemented. Three fresh headless runs
now gate frame sampling behind an explicit settle point and report setup separately. The planner's
rendered attribution profile is preserved and confirms a 6.859 ms settled p95, but all WSLg
reports remain provisional WSLg/WSL2 evidence, not the reference-hardware acceptance set required
by `docs/fr-904-runbook.md`. This handoff makes no Gate T-9 pass/fail determination and selects no
optimization.

## What the scenario measures

- Production battle screen and `BattleInterface`, including the visible CT timeline.
- Full three-person deployment: Vex plus two existing recruit candidates.
- Existing `dorthkor-vanguard` encounter composition: two enemies from generated encounter data.
- Production `GridBattlefieldModel` on a deterministic 8×4 benchmark grid.
- Production charge-time scheduler.
- Production per-tile charge renderer with all 32 tiles carrying a deterministic benchmark
  charge fixture.
- The existing FR-904 metrics and JSON format: `frame_time_ms` p50/p95/p99, draw calls, node
  count, battle-entry span, environment, warm-up count, and sample count.
- An additive setup phase: battle-event-to-HUD-interactive duration plus the setup-window
  `TIME_PROCESS` percentiles from the battle event through the settle gate.

The tile layout is benchmark-only input because production encounter-authored tile-charge state
does not yet exist. It exercises the real renderer without inventing encounter balance data.

## Exact commands

Headless settled runs:

```bash
GODOT_BIN=~/.local/bin/godot bash scripts/benchmark_performance.sh --scenario populated-grid --display-mode headless --settle-ms 2000 -o reports/fr904-provisional/2026-08-16-wslg-wsl2/headless-settled/run-1.json
GODOT_BIN=~/.local/bin/godot bash scripts/benchmark_performance.sh --scenario populated-grid --display-mode headless --settle-ms 2000 -o reports/fr904-provisional/2026-08-16-wslg-wsl2/headless-settled/run-2.json
GODOT_BIN=~/.local/bin/godot bash scripts/benchmark_performance.sh --scenario populated-grid --display-mode headless --settle-ms 2000 -o reports/fr904-provisional/2026-08-16-wslg-wsl2/headless-settled/run-3.json
```

Exact rendered WSLg settled commands for the planner:

```bash
DISPLAY=:0 GODOT_BIN=~/.local/bin/godot bash scripts/benchmark_performance.sh --scenario populated-grid --display-mode rendered --settle-ms 2000 -o reports/fr904-provisional/2026-08-16-wslg-wsl2/wslg-settled/run-1.json
DISPLAY=:0 GODOT_BIN=~/.local/bin/godot bash scripts/benchmark_performance.sh --scenario populated-grid --display-mode rendered --settle-ms 2000 -o reports/fr904-provisional/2026-08-16-wslg-wsl2/wslg-settled/run-2.json
DISPLAY=:0 GODOT_BIN=~/.local/bin/godot bash scripts/benchmark_performance.sh --scenario populated-grid --display-mode rendered --settle-ms 2000 -o reports/fr904-provisional/2026-08-16-wslg-wsl2/wslg-settled/run-3.json
```

Rendered attribution profile for the planner (one line; one run, allow several minutes):

```bash
DISPLAY=:0 GODOT_BIN=~/.local/bin/godot bash scripts/benchmark_performance.sh --scenario populated-grid --display-mode rendered --settle-ms 2000 --profile -o reports/fr904-provisional/2026-08-16-wslg-wsl2/wslg-settled/profile.json
```

## Provisional measurements

FR-904's floor is the median of three valid rendered run-level `frame_time_ms.p95` values at or
below **16.67 ms**. Headless values cannot satisfy that floor.

The original three-run rows below are retained as **pre-settle-gate window** evidence. They do not
represent the ruled steady-state floor window.

| Metric | Pre-settle headless median | Settled headless median | Pre-settle WSLg median | FR-904 floor |
|---|---:|---:|---:|---:|
| Frame time p50 | 0.135 ms | **0.130 ms** | 55.702 ms | record only |
| **Frame time p95** | **44.992 ms** | **0.165 ms** | **161.169 ms (~161.2)** | **≤16.67 ms rendered** |
| Frame time p99 | 44.992 ms | **0.165 ms** | 161.169 ms | record only |
| Battle event → HUD interactive | 102.297 ms | **105.347 ms** | 330.299 ms | <2000 ms |
| Setup-window p95 | not recorded separately | **50.825 ms** | not recorded separately | record separately |
| Draw calls p95 | 0 | **0** | 323 | >0 for rendered evidence |
| Node count p95 | 374 | **374** | 376 | record only |

The settled headless p95 median is 0.165 ms, 16.505 ms below the 16.67 ms floor. This is a
headless regression signal only and cannot satisfy the rendered acceptance requirement. The
planner-run rendered attribution profile's repeated full-UI settled window was 6.859 ms p95,
9.811 ms below the floor, but it is one provisional profiling window rather than the required
three settled rendered runs.

## Settle mechanism and additive schema

After the battle HUD becomes interactive, the populated-grid harness discards a fixed 2,000 ms,
then retains the existing 120-frame warm-up, and only then opens the 600-frame steady-state sample
window. A time gate was chosen because the uncapped headless and rendered frame rates differ; the
gate does not select frames according to the 16.67 ms result threshold.

The original report fields remain in place. New `setup_phase.duration_ms` records battle event →
HUD interactive, `setup_phase.frame_time_ms` summarizes the separate battle-event-to-settle-gate
window, and `measurement.settle_gate` records the method, start point, target/actual duration, and
discarded frame count.

Headless reports:

- `reports/fr904-provisional/2026-08-16-wslg-wsl2/headless/run-1.json`
- `reports/fr904-provisional/2026-08-16-wslg-wsl2/headless/run-2.json`
- `reports/fr904-provisional/2026-08-16-wslg-wsl2/headless/run-3.json`

Headless settled reports:

- `reports/fr904-provisional/2026-08-16-wslg-wsl2/headless-settled/run-1.json`
- `reports/fr904-provisional/2026-08-16-wslg-wsl2/headless-settled/run-2.json`
- `reports/fr904-provisional/2026-08-16-wslg-wsl2/headless-settled/run-3.json`

Rendered reports:

- `reports/fr904-provisional/2026-08-16-wslg-wsl2/wslg/run-1.json`
- `reports/fr904-provisional/2026-08-16-wslg-wsl2/wslg/run-2.json`
- `reports/fr904-provisional/2026-08-16-wslg-wsl2/wslg/run-3.json`

Preserved failed attempts:

- `reports/fr904-provisional/2026-08-16-wslg-wsl2/wslg/run-1.failure.log`
- `reports/fr904-provisional/2026-08-16-wslg-wsl2/wslg/run-2.failure.log`
- `reports/fr904-provisional/2026-08-16-wslg-wsl2/wslg/run-3.failure.log`

Those earlier attempts failed with `ERROR: X11 Display is not available` before a JSON report
could be emitted. The failure logs remain as sandbox-limit evidence and were not replaced or
treated as measurements.

The rendered JSON reports contain the two metrics that appeared null to the planner. The exact
paths are `monitors.draw_calls.{p50,p95,p99}` and
`spans.battle_entry.battle_event_to_hud_interactive`; this was a consumer-path mismatch, not a
report-schema gap, so the report writer was not changed to duplicate them.

## Verification

- Fresh-worktree import: exit 0; existing editor/plugin teardown warnings remained.
- Focused benchmark integration suite: 2/2 passed, including the attribution and additive
  setup/settle report contracts.
- Populated-grid wrapper smoke: valid `status: "ok"` JSON with 3 allies, 2 enemies, 32/32
  charged tiles, grid battlefield active, charge-time active, battle HUD visible, and CT timeline
  visible.
- Three fresh headless settled reports: 3/3 `status: "ok"`, 600 steady-state samples each, fixed
  2,000 ms gate recorded, setup window recorded separately, and no report errors.
- Headless attribution wrapper: valid `status: "ok"` JSON with six 600-sample / 120-warm-up
  windows and a named top cost.
- Existing field wrapper smoke: completed and emitted its existing JSON shape; its report carried
  `status: "error"` because its pre-existing battle-entry probe does not traverse the newer four
  deployment states. This scenario was not changed as part of T-9.
- Full fallback suite: 743/743 passed headlessly with 0 errors, failures, flaky, skipped, or
  orphaned cases.
- Required full command `DISPLAY=:0 GODOT_BIN=~/.local/bin/godot bash scripts/test.sh`: blocked
  before test discovery by the same unavailable WSLg display.

## Hot path

Both attribution profiles name **pre-sample setup carryover** as the top measured cost. Each runs
a full window before and after four controlled visibility ablations; the repeated full window is
the settled baseline. Deltas are directional and non-additive.

| Attribution bucket | `TIME_PROCESS` p95 window | Attributed p95 | Frame-interval p95 |
|---|---:|---:|---:|
| **Pre-sample setup carryover** | initial full 47.579 → settled full 0.651 ms | **46.928 ms** | 7.010 → 6.993 ms |
| Charged-tile stage | stage hidden: 0.132 ms | 0.519 ms | 7.002 ms |
| CT timeline | timeline hidden: 0.314 ms | 0.337 ms | 7.011 ms |
| Other battle HUD | other HUD hidden: 0.761 ms | 0.000 ms | 6.989 ms |
| Engine/background floor | whole interface hidden: 0.187 ms | 0.187 ms residual | 7.004 ms |

The initial `Performance.TIME_PROCESS` tail disappears when the identical fully visible grid is
sampled again after the ablations, while the independent frame interval stays near 7 ms in every
window. Settled physics and navigation p95 are 0.039 ms and 0.016 ms. This attributes the shared
headless miss to battle/HUD setup retained by the coarse process-time monitor, not to a sustained
per-frame physics loop. The scenario contains zero battle actor `Sprite2D` or `AnimatedSprite2D`
nodes, so no actor-sprite timing bucket exists.

The planner-run rendered profile confirms the same defect: the repeated full window is **6.859 ms
p95**, while the initial full window's setup carryover is **139.867 ms**. Its independent settled
frame-interval p95 is 3.978 ms. These numbers justify the measurement-window correction; they are
not a three-run reference-hardware acceptance result.

## Risks and open questions

- Three settled rendered WSLg runs are still outstanding; the planner should run the three exact
  commands above and preserve all JSON reports.
- The fixed 2,000 ms gate is deliberately independent of the result threshold, but monitor refresh
  cadence remains an environment risk. Each report records actual discard duration/frame count
  and the separate setup-window tail so a failed settle remains visible.
- Visibility-ablation p95 deltas are controlled directional evidence, not additive accounting;
  run order, monitor refresh cadence, compositor behavior, and thermal drift remain risks.
- The final reference-hardware acceptance run remains a separate human step under
  `docs/fr-904-runbook.md`.
- The benchmark fixture proves current rendering load, not production encounter-authored grid or
  tile-charge content. Reviewers should preserve that distinction.
- The existing field scenario's deployment-transition gap is outside this handoff but should be
  scheduled separately if field benchmark `status: "ok"` is required again.

## Recommended next action

Run the three rendered settled commands above outside this restricted worker environment. Confirm
each report is `status: "ok"`, has nonzero draw calls, records both setup phases, and contains 600
post-gate samples; then compute the median run-level `frame_time_ms.p95`. Preserve the raw JSON and
do not change the budget, propose an optimization, or decide T-9 from this provisional evidence.
