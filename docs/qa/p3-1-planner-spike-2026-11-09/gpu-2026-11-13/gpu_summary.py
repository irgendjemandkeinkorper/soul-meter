"""Summarise the GPU planner-spike runs against the no-planner control (same run)."""
import json
import statistics
import sys
from pathlib import Path

OUT = Path(sys.argv[1])
rows = {}
for f in sorted(OUT.glob("gpu-run*-*.json")):
    run, variant = f.stem.split("-")[1], f.stem.split("-", 2)[2]
    d = json.loads(f.read_text())
    rows[(run, variant)] = d

print("| Run | Variant | Adapter | Frame p50 / p95 / p99 (ms) | Frame p95 − control | Transition (ms) | Transition − control | Planner refresh p95 | D9 mean | Budget |")
print("|---|---|---|---|---|---|---|---|---|---|")
for (run, variant), d in sorted(rows.items(), key=lambda kv: (kv[0][0], ["none", "cached", "fallback24", "full"].index(kv[0][1]))):
    ctl = rows.get((run, "none"))
    fi = d["frame_interval_ms"]
    dp = fi["p95"] - ctl["frame_interval_ms"]["p95"] if ctl else float("nan")
    dt = d["transition_ms"] - ctl["transition_ms"] if ctl else float("nan")
    print(f"| {run[-1]} | {variant} | {d['environment']['video_adapter'][:28]} | "
          f"{fi['p50']:.2f} / {fi['p95']:.2f} / {fi['p99']:.2f} | {dp:+.2f} | {d['transition_ms']:.0f} | {dt:+.0f} | "
          f"{d['planner_refresh_ms']['p95']:.2f} | {d['d9_event_decision_ms_advisory']['mean']:.2f} | "
          f"{'PASS' if d['budget_pass'] else 'FAIL'} |")

# Where do slow frames come from? Frames over budget vs frames that carried a production action.
print()
for (run, variant), d in sorted(rows.items()):
    frames = d["raw"]["frame_interval_ms"]
    over = [x for x in frames if x > 16.67]
    print(f"run{run[-1]} {variant}: {len(over)}/{len(frames)} frames over 16.67 ms; "
          f"median of the rest {statistics.median([x for x in frames if x <= 16.67] or [0]):.2f} ms; "
          f"errors={len(d['errors'])} status={d['status']}")
if rows:
    sample = next(iter(rows.values()))["raw"]["frames"][0]
    print("raw.frames[0] keys:", sorted(sample.keys()) if isinstance(sample, dict) else type(sample))
