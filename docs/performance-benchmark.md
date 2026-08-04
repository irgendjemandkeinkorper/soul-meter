# FR-904 performance benchmark

Measurement harness for the PRD's performance floor: **60fps in field scenes with the full HUD**
and **battle transitions under 2 seconds**. Before this existed the repo had zero instrumentation,
so both numbers were assertions rather than evidence.

This harness measures. It does not optimize, and it does not fail a build on a slow number.

## Running it

```bash
GODOT_BIN=~/.local/bin/godot bash scripts/benchmark_performance.sh
GODOT_BIN=~/.local/bin/godot bash scripts/benchmark_performance.sh -o reports/fr904.json
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
| `spans.travel_transition` | Six ordered spans from `GameFlow.travel` to first interactive frame |
| `spans.battle_entry` | Battle event → BattleHUD visible and accepting input |
| `town_npc_spawner` | Idle sprite count, per-sprite per-frame work, whether viewport culling exists |
| `scene_baseline` | Authored node/Sprite2D counts for the target scene |
| `environment` | OS, CPU, renderer, Godot build — runs are only comparable within one environment |

Percentiles rather than a mean: a mean hides the stutter a player actually notices. The p95/p99
tail is the number that matters.

## Reproducibility

- **120 warmup frames**, discarded, so shader/pipeline compilation doesn't pollute the sample.
- **600 measured samples**, one `TIME_PROCESS` reading per `process_frame`.
- Target scene fixed at `world/starting_town.tscn`.
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
