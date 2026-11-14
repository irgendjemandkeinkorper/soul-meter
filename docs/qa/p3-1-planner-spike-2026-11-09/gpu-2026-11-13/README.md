# P3.1 planner spike on the GPU (2026-11-13)

Claude's follow-up to PR #640. It uses the same benchmark, fixture, variants and gate as the parent
README and changes only the renderer. The 2026-11-09 runs used `xvfb-run` and single-thread
llvmpipe (software rendering). These use the real GPU on the same machine:

- WSLg display (`DISPLAY=:0`) and Mesa's D3D12 driver (`GALLIUM_DRIVER=d3d12`). Godot reports
  `Using Device: Microsoft - D3D12 (Radeon RX 580 Series)`; `environment.video_adapter` in every report says the same.
- `--disable-vsync`, so 60 Hz vsync cannot pin frame p95 at 16.67 ms.
- One Godot at a time, isolated user data per run, 3500 MB cap: [`gpu_bench.py`](gpu_bench.py).
  Table: [`gpu_summary.py`](gpu_summary.py). Planner commit `52c74f19`, Godot 4.7.1, i5-13400F.

This is still not the official FR-904 gate. That stays Phase 6, on Windows reference hardware.
WSLg adds a GL→D3D12 translation layer and a compositor, so absolute numbers here are pessimistic
against native Windows. The comparison against the control holds.

## Result: still FAIL under #603's unchanged rules. The planner is not the cause.

| Run | Variant | Frame p50 / p95 / p99 (ms) | Frame p95 − control | Transition (ms) | Transition − control | Planner refresh p95 (ms) | Budget |
|---|---|---|---|---|---|---|---|
| 1 | none (control) | 27.12 / 195.35 / 388.74 | — | 914 | — | 1.17 | FAIL |
| 1 | cached | 38.63 / 191.94 / 539.88 | −3.41 | 1104 | +190 | 12.11 | FAIL |
| 1 | fallback24 | 149.87 / 338.69 / 700.52 | +143.34 | 1065 | +151 | 135.38 | FAIL |
| 1 | full | 735.45 / 901.22 / 1073.13 | +705.87 | 1553 | +639 | 755.64 | FAIL |
| 2 | none (control) | 38.27 / 188.84 / 523.38 | — | 918 | — | 1.05 | FAIL |
| 2 | cached | 38.50 / 192.66 / 517.67 | +3.83 | 907 | −11 | 13.17 | FAIL |
| 2 | fallback24 | 149.56 / 293.80 / 548.91 | +104.97 | 1021 | +102 | 127.02 | FAIL |
| 2 | full | 737.61 / 921.62 / 1258.87 | +732.78 | 1595 | +677 | 755.35 | FAIL |

1. **The control fails on the GPU too.** With no planner, frame p95 is 189–195 ms. The GPU cut
   llvmpipe's 356–377 ms roughly in half, and the budget is still 11× away.
2. **Cached is free.** Its overhead against the control is −3.4 / +3.8 ms p95, within run-to-run noise.
   Its own refresh work, 12–13 ms p95, fits one frame.
3. **Full uncapped is CPU-bound and out on any hardware.** Its refresh takes 755 ms p95, and a
   faster GPU does not touch that.
4. fallback24 costs +105 to +143 ms (comparison only, as before).
5. Every transition is under 2 s.

## Where the control's time goes

The control's slow frames line up with the ally's turns. In run 1 the 9 frames that carry an ally
action take 138 ms to 1.8 s. The last of them, frame 32, is the turn in which the whole crowd acts
(about 1.8–1.9 s in every variant). The other frames have a median of 26.8 ms and a p95 of 32.6 ms.
Because 9 of 120 frames is more than 5 %, p95 lands on the action spikes.

The default FR-904 mode with `--attribute-listeners --raw-samples`, GPU, no planner
([`fr904-attribution.json`](fr904-attribution.json)):

| Window | Frame interval p50 / p95 (ms) | CPU `TIME_PROCESS` p50 / p95 (ms) | Draw calls |
|---|---|---|---|
| Populated field, no fight | 15.5 / 21.4 | 18.3 / 31.9 | 139 |
| Fight, all admitted, nobody acting | 24.5 / 30.6 | 28.0 / 44.7 | 537 |

| Cost | Measured | Budget |
|---|---|---|
| Ally turn with zero enemy decisions (6 turns) | 148 ms mean, 119–198 ms | none stated; it lands inside one frame |
| Ally turn in which 101 enemies act | 1,561 ms | none stated; it lands inside one frame |
| One enemy decision (104 samples) | 14.9 ms mean, 13.8 p50 | D9: 2 ms, advisory |
| All signal listeners, 130 events | 135 ms in total; `battle_interface.consume_event` 93 ms, `battle._on_combat_event` 39 ms | — |

The listeners are not the hotspot. The time sits inside the combat controller's own turn work:
roughly 150 ms per ally turn even when no enemy acts, plus ~15 ms per enemy decision. With 100
hostiles in the fight, idle frames also cost ~28 ms of CPU. In the attribution run 1 of 100
hostiles was refused admission (`That cell is occupied.`); all 8 planner runs admitted 100.

## Question returned to the owner (#603's rule)

No owner-permitted uncapped candidate meets the budget, so the measured question returns to the
owner. The GPU data narrows it: the 100-hostile field fails with no planner at all, and the cached
planner adds nothing measurable. Not decided here: whether to profile and cut the controller's
per-turn and per-decision cost first, to change how the gate counts planner cost, or to revisit
capacity (ruling 6). Legibility stays 2/3 until #639 (Guard) lands.

Found on the way: 18 engine errors per run from `FieldMap` theming freed world labels. They don't
move the timings; fixed in PR #641.
