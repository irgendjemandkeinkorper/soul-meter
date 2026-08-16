# Gate T-9 populated-grid benchmark handoff

## Status

Scenario engineering is implemented and the headless provisional sample is complete. The
requested WSLg sample is blocked by this worker environment's inability to connect to
`DISPLAY=:0`; three rendered attempts failed before Godot loaded the project. Gate T-9 is **not
passed**, and this handoff is **not** reference-hardware acceptance evidence.

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

The tile layout is benchmark-only input because production encounter-authored tile-charge state
does not yet exist. It exercises the real renderer without inventing encounter balance data.

## Exact commands

Headless:

```bash
GODOT_BIN=~/.local/bin/godot bash scripts/benchmark_performance.sh \
  --scenario populated-grid --display-mode headless \
  -o reports/fr904-provisional/2026-08-16-wslg-wsl2/headless/run-1.json
```

Rendered WSLg (repeat for `run-1.json` through `run-3.json`):

```bash
DISPLAY=:0 GODOT_BIN=~/.local/bin/godot bash scripts/benchmark_performance.sh \
  --scenario populated-grid --display-mode rendered \
  -o reports/fr904-provisional/2026-08-16-wslg-wsl2/wslg/run-1.json
```

## Provisional measurements

FR-904's floor is the median of three valid rendered run-level `frame_time_ms.p95` values at or
below **16.67 ms**. Headless values cannot satisfy that floor.

| Metric | Headless median | WSLg median | FR-904 floor |
|---|---:|---:|---:|
| Frame time p50 | 0.135 ms | unavailable | record only |
| **Frame time p95** | **44.992 ms** | **unavailable** | **≤16.67 ms rendered** |
| Frame time p99 | 44.992 ms | unavailable | record only |
| Battle event → HUD interactive | 102.297 ms | unavailable | <2000 ms |
| Draw calls p50 | 0 | unavailable | >0 for rendered evidence |
| Node count p50 | 374 | unavailable | record only |

Headless reports:

- `reports/fr904-provisional/2026-08-16-wslg-wsl2/headless/run-1.json`
- `reports/fr904-provisional/2026-08-16-wslg-wsl2/headless/run-2.json`
- `reports/fr904-provisional/2026-08-16-wslg-wsl2/headless/run-3.json`

Rendered attempts:

- `reports/fr904-provisional/2026-08-16-wslg-wsl2/wslg/run-1.failure.log`
- `reports/fr904-provisional/2026-08-16-wslg-wsl2/wslg/run-2.failure.log`
- `reports/fr904-provisional/2026-08-16-wslg-wsl2/wslg/run-3.failure.log`

Each rendered attempt failed with `ERROR: X11 Display is not available` before a JSON report
could be emitted. These logs are failure evidence, not benchmark reports.

## Verification

- Fresh-worktree import: exit 0; existing editor/plugin teardown warnings remained.
- Focused benchmark integration suite: 2/2 passed.
- Populated-grid wrapper smoke: valid `status: "ok"` JSON with 3 allies, 2 enemies, 32/32
  charged tiles, grid battlefield active, charge-time active, battle HUD visible, and CT timeline
  visible.
- Existing field wrapper smoke: completed and emitted its existing JSON shape; its report carried
  `status: "error"` because its pre-existing battle-entry probe does not traverse the newer four
  deployment states. This scenario was not changed as part of T-9.
- Full fallback suite: 743/743 passed headlessly with 0 errors, failures, flaky, skipped, or
  orphaned cases.
- Required full command `DISPLAY=:0 GODOT_BIN=~/.local/bin/godot bash scripts/test.sh`: blocked
  before test discovery by the same unavailable WSLg display.

## Hot path

None named. The brief calls for profiling only if valid WSLg numbers catastrophically miss the
floor; no WSLg measurement was obtained. The high headless p95 is non-authoritative and does not
justify profiling or optimization. `world/town_npc_spawner.gd` was not touched.

## Risks and open questions

- Three valid WSLg JSON reports and their median remain outstanding. Run the rendered command in
  a session that can access WSLg, then replace the failure logs with JSON and update the dated
  documentation section.
- The final reference-hardware acceptance run remains a separate human step under
  `docs/fr-904-runbook.md`.
- The benchmark fixture proves current rendering load, not production encounter-authored grid or
  tile-charge content. Reviewers should preserve that distinction.
- The existing field scenario's deployment-transition gap is outside this handoff but should be
  scheduled separately if field benchmark `status: "ok"` is required again.

## Recommended next action

Run the three WSLg captures outside this restricted worker environment, verify `status: "ok"`
and draw calls greater than zero, compute medians without discarding slow valid runs, and keep the
result labeled provisional. Do not decide T-9 until the human reference-hardware run is complete.
