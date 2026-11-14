"""One capped GPU run of the FR-904 benchmark in the scratch profiling worktree."""
import os, signal, subprocess, sys, tempfile, time
from pathlib import Path
WT = Path(sys.argv[1]); OUT = Path(sys.argv[2]); extra = sys.argv[3:]
OUT.parent.mkdir(parents=True, exist_ok=True)
run_dir = Path(tempfile.mkdtemp(prefix="run-", dir=OUT.parent))
env = os.environ.copy(); env.pop("LP_NUM_THREADS", None)
env.update(GALLIUM_DRIVER="d3d12", SOUL_METER_FIXED_DICE="1",
           XDG_DATA_HOME=str(run_dir/"data"), XDG_CONFIG_HOME=str(run_dir/"config"), XDG_CACHE_HOME=str(run_dir/"cache"))
cfg = Path(env["XDG_DATA_HOME"]) / "godot/app_userdata/SoulMeter/player_config.cfg"
cfg.parent.mkdir(parents=True, exist_ok=True)
cfg.write_text('[VideoSettings]\n\nScreenResolution=Vector2i(1920, 1080)\n')
cmd = [str(Path.home()/".local/bin/godot"), "--path", ".", "--resolution", "1920x1080", "--disable-vsync",
       "--script", "res://tools/populated_field_benchmark.gd", "--", *extra]
started = time.monotonic(); peak = killed = 0
with open(OUT, "w") as log:
    child = subprocess.Popen(cmd, cwd=WT, env=env, stdout=log, stderr=subprocess.STDOUT, start_new_session=True)
    while child.poll() is None:
        try:
            rss = next(int(l.split()[1])//1024 for l in Path(f"/proc/{child.pid}/status").read_text().splitlines() if l.startswith("VmRSS:"))
            peak = max(peak, rss); killed = int(rss > 3500)
        except (OSError, StopIteration, ValueError):
            pass
        if killed or time.monotonic() - started > 900:
            os.killpg(child.pid, signal.SIGKILL); child.wait(); break
        time.sleep(0.25)
print(f"exit={child.returncode} killed={killed} peak_rss_mb={peak} secs={time.monotonic()-started:.0f}")
