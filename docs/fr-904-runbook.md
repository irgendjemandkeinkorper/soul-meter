# FR-904 reference-hardware runbook

This procedure turns the instrumentation described in
[`performance-benchmark.md`](performance-benchmark.md) into real-display acceptance evidence.
It complements the Phase 1.5 human gate in [`playtest-packet.md`](playtest-packet.md).

Headless results are useful for regression detection but **cannot pass FR-904**. The acceptance
run must render to a real display on declared reference hardware with the full field HUD visible.

## Run declaration

Complete once per three-run set. If any declared condition changes, discard the set and restart.

| Field | Value |
|---|---|
| Date / operator | |
| Build artifact and commit SHA | |
| Machine manufacturer / model | |
| CPU | |
| GPU and driver version | |
| RAM | |
| OS and build | |
| Display resolution and refresh rate | |
| Game resolution and window mode | |
| Scaling / VSync / frame cap | |
| Power source and OS power mode | AC / battery; mode: |
| Thermal / fan profile | |
| Renderer | Compatibility / Forward+ / Mobile / other: |
| Godot version and build | |
| Background-process policy | |
| Evidence directory | `reports/fr904-reference/<commit>/` |

Required fixed conditions:

- Use the same machine, display, renderer, resolution, window mode, power mode, and build for all
  three runs.
- Connect laptops to AC power and select the declared performance mode; disable automatic mode
  changes for the set.
- Close unrelated user applications, overlays, downloads, recorders, and update jobs. Use the
  platform's GPU/CPU capture tool only if it does not materially change frame timing; disclose it.
- Use a release-equivalent build. Do not run from an editor viewport.
- Run on a real display. Do not pass `--headless` and do not use the headless wrapper for the
  acceptance measurement.

## Evidence setup

1. Create the declared evidence directory.
2. Record the current commit SHA in `environment.md` in that directory, along with every field
   above.
3. Capture one screenshot showing the rendered starting-town field, the full HUD, resolution,
   and build identifier. Name it `full-hud.png`.
4. Capture the OS power-mode panel and renderer selection as `power-mode.png` and
   `renderer.png`, or include equivalent text evidence if the platform cannot capture them.
5. Keep the raw console log and JSON report from every run. Do not retain only a transcription.

An acceptance set is invalid if the screenshot does not show the full HUD, the report identifies
a different environment between runs, draw calls remain zero, or any required declaration is
blank.

## Warm-up and sample window

The harness discards **120 warm-up frames** and then records **600 consecutive frames**. At the
60fps target this is approximately **2 seconds of warm-up plus 10 seconds of measurement**.
Record the actual wall-clock warm-up and sample durations from each run; frame counts are fixed,
so slow hardware will take longer.

Before Run 1, additionally launch the same build once, reach the starting-town field with its
full HUD, leave it idle for 60 seconds so first-run imports and OS startup activity settle, then
quit. This environmental warm-up is not part of the 120 discarded harness frames.

Do not interact with the game during the 600-frame sample window.

## Execute three rendered runs

From the repository root, run the harness **without** `--headless` three times. Substitute the
declared Godot binary and evidence directory:

```bash
GODOT_BIN=~/.local/bin/godot
EVIDENCE_DIR=reports/fr904-reference/<commit>

"$GODOT_BIN" --path . --script res://tools/performance_benchmark.gd \
  >"$EVIDENCE_DIR/run-1.log" 2>&1
rg -m1 -o '\{.*\}' "$EVIDENCE_DIR/run-1.log" >"$EVIDENCE_DIR/run-1.json"
```

Repeat with `run-2` and `run-3`. Wait at least 30 seconds between runs and confirm the declared
power mode remains active. Godot may abort during teardown after emitting valid JSON; judge each
run by a well-formed JSON report with `status: "ok"`, not by process exit code.

For every run:

- [ ] The rendered starting-town field and full HUD were visibly present.
- [ ] The JSON report exists, parses, and reports `status: "ok"`.
- [ ] `environment` matches the declaration and the other two runs.
- [ ] Draw calls are greater than zero, confirming rendered work.
- [ ] Warm-up frames = 120 and sample count = 600.
- [ ] No editor, debugger, overlay, thermal warning, update, or user input disturbed the sample.

If a check fails, label that run **INVALID**, record why, and rerun it. Never discard a valid slow
run as an outlier.

## Results worksheet

Copy values from the committed JSON reports; retain milliseconds to at least three decimals.

| Metric | Run 1 | Run 2 | Run 3 | Median | Acceptance |
|---|---:|---:|---:|---:|---|
| Frame time p50 (ms) | | | | | record |
| **Frame time p95 (ms)** | | | | | **≤ 16.67 ms** |
| Frame time p99 (ms) | | | | | record; no separate threshold |
| Travel request → first interactive frame (ms) | | | | | < 2000 ms |
| Battle event → HUD interactive (ms) | | | | | < 2000 ms |
| Draw calls p50 | | | | | > 0 |
| Node count p50 | | | | | record |
| Actual warm-up duration (s) | | | | | record |
| Actual sample duration (s) | | | | | record |

For three values, the median is the middle value after sorting. Calculate the median separately
for every row; do not pool raw samples across runs and do not average the three percentiles.

## Acceptance definition

FR-904 field performance **passes** only when all three runs are valid, all show the full HUD on
the declared real-display configuration, draw calls are non-zero, and the **median of the three
run-level `frame_time_ms.p95` values is at most 16.67ms**. Record p99 for tail visibility even
though it has no independent pass threshold.

The transition portion passes only when the three-run median for both travel-to-interactive and
battle-event-to-interactive is below 2000ms. Report field performance and transitions separately;
one passing does not hide the other failing.

Do not claim FR-904 from a headless report, a single run, an average, a p50 value, a run without
the full HUD, or undeclared hardware/settings.

## Evidence index and sign-off

| Evidence | Path / value |
|---|---|
| Environment declaration | `environment.md` / |
| Full-HUD screenshot | `full-hud.png` / |
| Power-mode evidence | `power-mode.png` / |
| Renderer evidence | `renderer.png` / |
| Run 1 log / JSON | `run-1.log` / `run-1.json` / |
| Run 2 log / JSON | `run-2.log` / `run-2.json` / |
| Run 3 log / JSON | `run-3.log` / `run-3.json` / |
| Completed worksheet | |
| Invalid runs and reasons, if any | |

Field performance: **PASS / FAIL**

Transition performance: **PASS / FAIL**

FR-904 overall: **PASS / FAIL**

Operator: ____________________  Date: __________

Reviewer: ____________________  Date: __________
