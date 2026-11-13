"""P3.1 planner spike on the real GPU: WSLg display + Mesa d3d12 (Radeon RX 580).

Same benchmark, fixture and variants as tools/planner_spike/measure_capped.py (PR #640),
with three changes: real display instead of xvfb, GALLIUM_DRIVER=d3d12 instead of
single-thread llvmpipe, and --disable-vsync so 60 Hz vsync cannot pin p95 at 16.67 ms.
One Godot at a time; 3500 MB RSS cap; 900 s timeout per run. Outputs stay in the scratchpad.
"""
import os
from pathlib import Path
import signal
import subprocess
import sys
import tempfile
import time

WT = Path("/home/adamjroder/projects/soul-meter-wt/codex-planner-603")
OUT = Path(sys.argv[1]).resolve()
OUT.mkdir(parents=True, exist_ok=True)
LEG = WT / "docs/qa/p3-1-planner-spike-2026-11-09/retained-legibility.json"
ORDER = ["none", "full", "cached", "fallback24"]

for run in (1, 2):
    for variant in ORDER:
        stem = f"gpu-run{run}-{variant}"
        run_dir = Path(tempfile.mkdtemp(prefix=f"{stem}-", dir=OUT))
        env = os.environ.copy()
        env.pop("LP_NUM_THREADS", None)
        env.update(GALLIUM_DRIVER="d3d12", SOUL_METER_FIXED_DICE="1",
                   XDG_DATA_HOME=str(run_dir / "data"),
                   XDG_CONFIG_HOME=str(run_dir / "config"),
                   XDG_CACHE_HOME=str(run_dir / "cache"))
        cfg = Path(env["XDG_DATA_HOME"]) / "godot/app_userdata/SoulMeter/player_config.cfg"
        cfg.parent.mkdir(parents=True, exist_ok=True)
        cfg.write_text('[VideoSettings]\n\nScreenResolution=Vector2i(1920, 1080)\n')
        cmd = [str(Path.home() / ".local/bin/godot"), "--path", ".", "--resolution", "1920x1080",
               "--disable-vsync", "--script", "res://tools/populated_field_benchmark.gd", "--",
               "--planner-variant", variant, "--planner-output", str(OUT / f"{stem}.json"),
               "--planner-reuse-legibility", str(LEG)]
        log_path = OUT / f"{stem}.log"
        started = time.monotonic()
        peak = killed = 0
        with open(log_path, "w") as log:
            child = subprocess.Popen(cmd, cwd=WT, env=env, stdout=log, stderr=subprocess.STDOUT,
                                     start_new_session=True)
            while child.poll() is None:
                try:
                    rss = next(int(l.split()[1]) // 1024 for l in
                               Path(f"/proc/{child.pid}/status").read_text().splitlines()
                               if l.startswith("VmRSS:"))
                    peak = max(peak, rss)
                    killed = int(rss > 3500)
                except (OSError, StopIteration, ValueError):
                    pass
                if killed or time.monotonic() - started > 900:
                    os.killpg(child.pid, signal.SIGKILL)
                    child.wait()
                    break
                time.sleep(0.25)
        print(f"{stem}: exit={child.returncode} killed={killed} peak_rss_mb={peak} "
              f"secs={time.monotonic() - started:.0f}", flush=True)
