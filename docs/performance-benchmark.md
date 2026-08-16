# FR-904 performance benchmark

Measurement harness for the PRD's performance floor: **60fps in field scenes with the full HUD**
and **battle transitions under 2 seconds**. Before this existed the repo had zero instrumentation,
so both numbers were assertions rather than evidence.

This harness measures. It does not optimize, and it does not fail a build on a slow number.

Use the [`FR-904 reference-hardware runbook`](fr-904-runbook.md) for the rendered, three-run
acceptance procedure. The related comprehension gate is executed with the
[`Phase 1.5 playtest packet`](playtest-packet.md).

## Running it

```bash
GODOT_BIN=~/.local/bin/godot bash scripts/benchmark_performance.sh
GODOT_BIN=~/.local/bin/godot bash scripts/benchmark_performance.sh -o reports/fr904.json

# Gate T-9 populated-grid battle (headless regression signal)
GODOT_BIN=~/.local/bin/godot bash scripts/benchmark_performance.sh \
  --scenario populated-grid --display-mode headless -o reports/fr904-grid-headless.json

# Gate T-9 populated-grid battle (rendered; requires an available display)
DISPLAY=:0 GODOT_BIN=~/.local/bin/godot bash scripts/benchmark_performance.sh \
  --scenario populated-grid --display-mode rendered -o reports/fr904-grid-rendered.json
```

Or invoke the harness directly:

```bash
godot --headless --path . --script res://tools/performance_benchmark.gd
```

## What it measures

| Group | Contents |
|---|---|
| `frame_time_ms` | p50 / p95 / p99 of `Performance.TIME_PROCESS` |
| `monitors` | `RENDER_TOTAL_DRAW_CALLS_IN_FRAME`, `OBJECT_NODE_COUNT` (same percentiles) |
| `setup_phase` | Battle setup duration plus p50 / p95 / p99 for the battle-event-to-settle-gate setup window |
| `measurement.settle_gate` | Settle method, target/actual discard duration, and discarded frame count |
| `spans.travel_transition` | Six ordered spans from `GameFlow.travel` to first interactive frame |
| `spans.battle_entry` | Battle event → BattleHUD visible and accepting input |
| `town_npc_spawner` | Idle sprite count, per-sprite per-frame work, whether viewport culling exists |
| `scene_baseline` | Authored node/Sprite2D counts for the target scene |
| `environment` | OS, CPU, renderer, Godot build — runs are only comparable within one environment |

Percentiles rather than a mean: a mean hides the stutter a player actually notices. The p95/p99
tail is the number that matters.

## Reproducibility

- The populated-grid scenario first discards a fixed **2,000 ms after the battle HUD becomes
  interactive**. This time-based settle gate is consistent across different headless/rendered
  frame rates and does not select samples by whether they satisfy the frame-time floor.
- **120 warmup frames** are then discarded, preserving the original shader/pipeline warm-up.
- **600 measured samples**, one `TIME_PROCESS` reading per `process_frame`.
- Target scene fixed at `world/starting_town.tscn`.
- `--scenario populated-grid` instead targets the production battle screen with three existing
  party members, the existing two-enemy `dorthkor-vanguard` composition, an 8×4 grid, the
  charge-time scheduler, and a deterministic charged-tile rendering fixture on all 32 tiles.
- Report carries `schema_version` so downstream diffing can detect format changes.

Two runs are comparable only when `environment` matches. Comparing a laptop on battery to CI
tells you nothing.

## ⚠ What these numbers do NOT prove

**Headless CI cannot validate the 60fps requirement.** Read this before quoting a frame time
at anyone.

In headless mode the renderer does no real work — `draw_calls` reads **0**, and the reported
frame time reflects script and node processing only, not GPU cost, shader complexity, overdraw,
or texture bandwidth. A headless frame time therefore has no defensible relationship to what a
player sees.

What headless runs are good for:
- **Regression detection.** A p95 that doubles between commits is a real signal worth chasing.
- **Verifying the instrumentation itself** still works.
- **Transition spans**, which are dominated by loading and node construction rather than
  rasterization, so they carry more meaning headlessly than frame time does.

Validating the actual 60fps floor requires a real display on the reference machine. Until that
run happens, FR-904 is **instrumented but not satisfied**, and should be reported that way.

## Baseline as of 2026-08-04

First recorded baseline, headless, `gl_compatibility`, Intel i5-13400F / 16 threads:

| Measurement | Run 1 | Run 2 | Against target |
|---|---|---|---|
| Frame time p50 | 0.126 ms | 0.228 ms | — |
| Frame time p95 / p99 | 31.301 ms | 48.166 ms | over the 16.67 ms budget, but **headless — not authoritative** |
| Travel request → first interactive frame | 88.9 ms | 119.8 ms | well under 2 s ✓ |
| Battle event → HUD interactive | 31.4 ms | 31.7 ms | well under 2 s ✓ |
| Node count p50 | 637 | 637 | authored scene declares 269 |
| Draw calls | 0 | 0 | headless; confirms the caveat above |

Run 1 travel span breakdown: request → loading visible 1.8 ms, → resource ready 53.7 ms,
→ scene attached 1.8 ms, → NPC population complete 29.2 ms, → first interactive frame 2.4 ms.

### ⚠ Run-to-run variance is large — treat single runs with suspicion

Two consecutive runs on the same machine, same commit, produced a **54% swing in frame-time p95**
(31.3 → 48.2 ms) and a **35% swing in travel time** (88.9 → 119.8 ms).

A follow-up three-run set on the same commit confirmed and widened the picture:

| Metric | Run A | Run B | Run C | Verdict |
|---|---|---|---|---|
| frame time p95/p99 | 30.1 | 35.7 | 29.5 ms | unstable (~20%) |
| travel → first interactive frame | 86.8 | 100.3 | 86.0 ms | unstable (~16%) |
| battle event → HUD interactive | 30.0 | **61.6** | 30.3 ms | **unstable — 2× outlier** |
| node count p50 | 637 | 637 | 637 | stable |
| draw calls | 0 | 0 | 0 | stable |

`battle_entry` was initially believed stable on a two-run sample; the three-run set disproves that
— it doubled on one run. **Do not treat any single timing run as a baseline.** Only `node_count`
and `draw_calls` have so far been reproducible.

So the current sampling is not yet tight enough to call a single run a "baseline" for the noisy
metrics. Before treating any frame-time or travel regression as real:

1. Run at least 3 times and compare medians, not one run against one run.
2. Expect roughly ±50% noise on frame-time p95 headless until this is investigated.
3. Trust `battle_entry` and `node_count` more — they were reproducible.

Likely contributors: p95/p99 collapsing to the same value suggests the tail is a handful of
outlier frames (probably load-related), so a single stall dominates the statistic. Raising the
sample count or reporting a trimmed tail would firm this up. Recorded as a known limitation
rather than silently averaged away.

### ⚠ Godot headless teardown aborts intermittently — affects CI wiring

Any `godot --headless --script` invocation in this project exits with **134 (SIGABRT, core
dumped)** roughly 20–30% of the time, during engine shutdown *after* the script has completed
and printed its output. This was reproduced with a three-line script that only prints and quits,
so it is **not** caused by this harness, by `quest_audit.gd`, or by any Wave 1 change — it is
pre-existing Godot 4.7.1 behaviour here, related to the "N resources still in use at exit" and
"ObjectDB instances were leaked" warnings the engine already emits.

Consequence: **do not gate CI on the raw exit code of a tool script.** A passing run and an
aborted-at-teardown run are indistinguishable by exit status. `scripts/benchmark_performance.sh`
already guards against this by judging success on whether a well-formed JSON report was produced
rather than on Godot's exit code. Anything else wired into CI needs the same treatment, or CI
will fail spuriously about a quarter of the time.

### Observations worth acting on later

- **The <2s transition targets are met with large headroom** (89 ms and 31 ms). This part of
  FR-904 looks genuinely healthy.
- **Runtime node count is 637 against 269 authored** — NPC spawning more than doubles the scene.
  Any future node-count budget must be stated in runtime terms.
- **`world/town_npc_spawner.gd` reports `viewport_culling_present: false`** with 30 idle sprites,
  each taking a `sin()` plus a position and rotation write every frame. This is the suspected hot
  path. It was deliberately **not** modified — the point of this harness is to measure it first.
  Decide with a real-hardware number, not this headless one.
- Resource-ready is the largest travel span (53.7 ms of 88.9 ms), so if transition time ever
  becomes a problem, that is where to look.

## 2026-08-16 — populated-grid battle — provisional — WSLg/WSL2, NOT reference-hardware acceptance evidence

This section records scenario-engineering measurements only. It does **not** establish Gate T-9
or FR-904 acceptance. The runbook still requires three valid rendered runs on declared reference
hardware with a real display, and the acceptance floor remains a three-run median of run-level
`frame_time_ms.p95` values at or below **16.67 ms**.

The scenario opens the production battle screen after all four deployment states, deploys Vex
plus two existing recruit candidates, loads the existing `dorthkor-vanguard` encounter (two
enemies), installs the production `GridBattlefieldModel` and charge-time scheduler, and renders a
deterministic benchmark fixture of 32 charged tiles through the production `BattleInterface`.
Every valid headless report confirms the grid model, CT scheduler, battle HUD, CT timeline, and
32/32 charged tiles were active. The fixture measures rendering load; it does not add encounter
balance data or claim that production encounter-authored tile-charge state exists.

Reports and failed rendered-attempt logs are under
`reports/fr904-provisional/2026-08-16-wslg-wsl2/`.

### Measurement-window defect and ruling

The original populated-grid window opened after only the 120-frame warm-up. At the scenario's
uncapped headless and WSLg frame rates, that did not reliably outlast the coarse
`Performance.TIME_PROCESS` monitor's setup carryover. Setup frames therefore dominated the tail:
the three rendered run-level p95 values were near 161 ms even though the planner-run attribution
profile's repeated, settled full-UI window measured **6.859 ms p95**. Its initial-versus-settled
delta attributed **139.867 ms** to setup carryover.

The planner-approved ruling is that the FR-904 frame-time floor measures steady-state play. The
populated-grid harness now opens its 600-sample frame window only after HUD interactivity, a fixed
2,000 ms discard, and the existing 120-frame warm-up. It also records the discarded phase so no
cost is hidden:

- `setup_phase.duration_ms` keeps the battle event → HUD interactive setup duration.
- `setup_phase.frame_time_ms.{p50,p95,p99,sample_count}` summarizes the separate setup window from
  the battle event through the settle gate.
- `measurement.settle_gate` records `method: "fixed_post_setup_warmup"`, the target and actual
  duration, the start point, and discarded frame count.
- Existing fields were not renamed or reused for setup data; `frame_time_ms` remains the FR-904
  play-window metric and now samples after the explicit settle point.

| Mode / metric | Run 1 | Run 2 | Run 3 | Median | FR-904 floor |
|---|---:|---:|---:|---:|---:|
| Headless **pre-settle-gate window** frame p50 (ms) | 0.117 | 0.145 | 0.135 | 0.135 | record only |
| **Headless pre-settle-gate window frame p95 (ms)** | 44.468 | 47.766 | 44.992 | **44.992** | ≤16.67 ms, but headless is non-authoritative |
| Headless pre-settle-gate window frame p99 (ms) | 44.468 | 47.766 | 44.992 | 44.992 | record only |
| Headless pre-settle-gate battle event → HUD interactive (ms) | 99.577 | 104.219 | 102.297 | 102.297 | <2000 ms transition target |
| Headless pre-settle-gate draw calls p50 | 0 | 0 | 0 | 0 | expected in headless mode |
| Headless pre-settle-gate node count p50 | 374 | 374 | 374 | 374 | record only |
| WSLg rendered **pre-settle-gate window** frame p50 (ms) | 77.506 | 55.702 | 50.943 | 55.702 | record only |
| **WSLg rendered pre-settle-gate window frame p95 (ms)** | **161.169** | **159.993** | **169.197** | **161.169 (~161.2)** | **≤16.67 ms** |
| WSLg rendered pre-settle-gate window frame p99 (ms) | 161.169 | 159.993 | 169.197 | 161.169 | record only |
| WSLg pre-settle-gate battle event → HUD interactive (ms) | 328.392 | 330.299 | 352.031 | 330.299 | <2000 ms transition target |
| WSLg pre-settle-gate draw calls p50 / p95 / p99 | 323 / 323 / 323 | 323 / 323 / 323 | 323 / 323 / 323 | 323 / 323 / 323 | >0 for rendered evidence |
| WSLg pre-settle-gate node count p50 / p95 / p99 | 374 / 376 / 376 | 374 / 376 / 376 | 374 / 376 / 376 | 374 / 376 / 376 | record only |
| Headless **settled steady-state** frame p50 (ms) | 0.104 | 0.130 | 0.135 | **0.130** | record only |
| **Headless settled steady-state frame p95 (ms)** | **0.114** | **0.285** | **0.165** | **0.165** | **≤16.67 ms, but headless is non-authoritative** |
| Headless settled steady-state frame p99 (ms) | 0.153 | 0.285 | 0.165 | 0.165 | record only |
| Headless settled setup duration (ms) | 121.835 | 105.128 | 105.347 | **105.347** | <2000 ms transition target |
| Headless settled setup-window p95 (ms) | 58.602 | 47.914 | 50.825 | **50.825** | reported separately; not the steady-state floor |
| Headless settled draw calls p95 | 0 | 0 | 0 | 0 | expected in headless mode |
| Headless settled node count p95 | 374 | 374 | 374 | 374 | record only |

All six pre-settle-gate benchmark JSON reports and all three new settled headless reports are well
formed with `status: "ok"`. The new reports are
`headless-settled/run-1.json` through `run-3.json`; each records 600 steady-state samples after the
2,000 ms settle discard and 120 warm-up frames, plus the separate setup-phase fields. Every report
confirms 3 allies, 2 enemies, 32/32 charged tiles, the grid battlefield, charge-time scheduler,
battle HUD, and CT timeline. The original three
`*.failure.log` files remain beside the rendered JSON reports because they document this worker's
inability to open WSLg; they are not measurements and were not substituted for the planner's
successful runs.

The rendered reports do contain the metrics that appeared as null to the planner. Their nested
schema paths are `monitors.draw_calls.{p50,p95,p99}` and
`spans.battle_entry.battle_event_to_hud_interactive`, so no report-writer schema change was
needed.

### Headless attribution profile

The committed headless profile is
`reports/fr904-provisional/2026-08-16-wslg-wsl2/headless/profile.json`. It uses 600 samples and
120 warm-up frames in each of six windows: full UI before and after the experiment, then the tile
stage, CT timeline, remaining HUD, and whole `BattleInterface` hidden one at a time. This is a
controlled visibility ablation, not an optimization. Its p95 deltas are directional and are not
additive.

| Attribution bucket | `TIME_PROCESS` p95 window (ms) | Attributed p95 (ms) | Frame-interval p95 (ms) | Finding |
|---|---:|---:|---:|---|
| **Pre-sample setup carryover** | initial full 47.579 → settled full 0.651 | **46.928** | 7.010 initial; 6.993 settled | **Top measured cost** |
| Charged-tile stage | stage hidden: 0.132 | 0.519 | 7.002 | Small settled-state delta |
| CT timeline | timeline hidden: 0.314 | 0.337 | 7.011 | Small settled-state delta |
| Other battle HUD | unit/weather/forecast/cursor/action hotbar/soul gauge hidden: 0.761 | 0.000 | 6.989 | No positive p95 delta in this run |
| Engine/background floor | whole interface hidden: 0.187 | 0.187 residual | 7.004 | Sub-millisecond `TIME_PROCESS` floor |

The top cost in the headless profile is therefore the initial battle/HUD setup sample retained in
the coarse `Performance.TIME_PROCESS` signal: the same fully visible populated grid falls from
47.579 ms p95 in the initial window to 0.651 ms in the repeated settled window. The independent
wall-clock frame-interval p95 stays near 7 ms across every window, while settled baseline physics
and navigation p95 are 0.039 ms and 0.016 ms respectively. No battle actor `Sprite2D` or
`AnimatedSprite2D` nodes exist in this scenario, so there is no actor-sprite bucket to time.

The planner subsequently ran the same attribution profile rendered. Its repeated fully visible
settled baseline measured **6.859 ms p95**, while the initial full window carried a 139.867 ms
setup delta. That confirms the rendered tail has the same window defect. This remains one
provisional WSLg/WSL2 profiling run, not the required three-run reference-hardware acceptance set;
do not infer a budget change or Gate T-9 decision from it.
