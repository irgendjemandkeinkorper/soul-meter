# P3.1 planner spike: GPU rerun on the controller cut (2026-11-20)

#603, after owner item 49 (a): the remaining ally-turn cost was accepted on 2026-11-20, and this
is the 8-run rerun on the GPU with #647's controller cut (#642). Method, fixture and variants are
the same as [`../gpu-2026-11-13/`](../gpu-2026-11-13/README.md):
- WSLg display with Mesa D3D12 (Radeon RX 580), `--disable-vsync`, at 1920×1080.
- One Godot at a time, with isolated user data, a 3500 MB cap and fixed dice.

[`gpu_bench.py`](gpu_bench.py) differs only in the worktree it runs: #647's tree at `c07663cf`,
the code merged as `b3485b52`. The table comes from
[`../gpu-2026-11-13/gpu_summary.py`](../gpu-2026-11-13/gpu_summary.py). Load from other projects
was 1.9 at the start and 2.5 at the end.

## Result

| Run | Variant | Frame p50 / p95 / p99 (ms) | Frame p95 − control | Transition (ms) | Planner refresh p95 (ms) | D9 mean (ms) | Budget |
|---|---|---|---|---|---|---|---|
| 1 | none (control) | 34.37 / 93.19 / 430.33 | — | 1074 | 1.75 | 11.77 | FAIL |
| 1 | cached | 34.45 / 96.08 / 386.52 | +2.89 | 851 | 8.72 | 6.66 | FAIL |
| 1 | fallback24 | 69.17 / 157.38 / 497.33 | +64.19 | 868 | 74.00 | 8.94 | FAIL |
| 1 | full | 321.02 / 485.38 / 593.01 | +392.19 | 1037 | 362.62 | 7.20 | FAIL |
| 2 | none (control) | 37.77 / 97.92 / 374.99 | — | 873 | 1.45 | 7.96 | FAIL |
| 2 | cached | 63.99 / 108.86 / 523.85 | +10.93 | 1188 | 9.86 | 7.59 | FAIL |
| 2 | fallback24 | 67.55 / 107.92 / 429.11 | +10.00 | 887 | 47.85 | 6.84 | FAIL |
| 2 | full | 294.63 / 368.33 / 641.50 | +270.41 | 1220 | 291.81 | 7.23 | FAIL |

All 8 runs admitted 100 hostiles and logged no errors.

### Against 2026-11-13

| Measure | 2026-11-13 | 2026-11-20 |
|---|---|---|
| Control frame p95 | 189–195 ms | 93–98 ms |
| Full planner refresh p95 | 755 ms | 292–363 ms |
| fallback24 refresh p95 | 127–135 ms | 48–74 ms |
| Cached refresh p95 | 12–13 ms | 9–10 ms |
| Cached p95 − control | −3.4 / +3.8 ms | +2.9 / +10.9 ms |

## What it means

1. **Still no candidate meets #603's budget (frame p95 ≤ 16.67 ms).** Every frame of every run
   is over 16.67 ms, the control's included.
2. **The planner is not what fails it.** In the control, the 9 frames that carry an ally action
   take 66 ms to 1.8 s. The other 111 frames have a p50 of 33–37 ms and a p95 of 56–59 ms.
   - With 100 hostiles on the field, a frame with no action already costs about twice the budget.
   - On 2026-11-13 those frames had a p50 of 26.8 ms and a p95 of 32.6 ms. This rerun's machine
     carried load from other projects, so that difference is not attributed to the cut.
3. **Cached stays cheap:** +3 to +11 ms p95 against the control, with its own refresh at 9–10 ms.
4. **Full is still out.** The cut lowered its refresh to 292–363 ms, which is still many frames.
5. Every transition is under 2 s. D9's 2 ms per decision is still not met: the mean is 6.7–11.8 ms
   (advisory).

The phase's rule sends this back to the owner (owner item 50). Legibility also still stands at
2/3 until #639 (Guard), which is on hold under owner item 43.
