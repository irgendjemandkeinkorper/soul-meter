"""One benchmark process, isolated data, 3500 MB per-process cap, 900 second timeout."""
import argparse
import os
from pathlib import Path
import signal
import subprocess
import sys
import tempfile
import time

parser = argparse.ArgumentParser(description=__doc__)
parser.add_argument("variant", choices=("none", "full", "cached", "fallback24"))
parser.add_argument("output", type=Path)
parser.add_argument("--reuse-legibility", type=Path, help="Retained evidence JSON; skip capture execution")
args = parser.parse_args()
variant = args.variant
output = str(args.output.resolve())
work_dir = Path("/tmp/codex-planner2")
work_dir.mkdir(parents=True, exist_ok=True)
run_dir = Path(tempfile.mkdtemp(prefix=f"bench-{args.output.stem}-", dir=work_dir))
log_path = work_dir / f"benchmark-{args.output.stem}.log"
env = os.environ.copy()
env.update(LP_NUM_THREADS="1", SOUL_METER_FIXED_DICE="1",
           XDG_DATA_HOME=str(run_dir / "data"),
           XDG_CONFIG_HOME=str(run_dir / "config"),
           XDG_CACHE_HOME=str(run_dir / "cache"))
config = Path(env["XDG_DATA_HOME"]) / "godot/app_userdata/SoulMeter/player_config.cfg"
config.parent.mkdir(parents=True, exist_ok=True)
config.write_text('[VideoSettings]\n\nScreenResolution=Vector2i(1920, 1080)\n')
command = ["xvfb-run", "-a", "-s", "-screen 0 1920x1080x24",
           str(Path.home() / ".local/bin/godot"), "--path", ".", "--resolution", "1920x1080",
           "--script", "res://tools/populated_field_benchmark.gd", "--",
           "--planner-variant", variant, "--planner-output", output]
if args.reuse_legibility:
    command.extend(["--planner-reuse-legibility", str(args.reuse_legibility.resolve())])
print("command=" + repr(command), flush=True)
started = time.monotonic()
peak = killed = 0
with open(log_path, "w") as log:
    child = subprocess.Popen(command, env=env, stdout=log, stderr=subprocess.STDOUT, start_new_session=True)
    while child.poll() is None:
        for proc in Path("/proc").glob("[0-9]*"):
            try:
                stat = (proc / "stat").read_text().split(") ", 1)[1].split()
                if int(stat[2]) != child.pid:
                    continue
                rss = next(int(line.split()[1]) // 1024 for line in (proc / "status").read_text().splitlines() if line.startswith("VmRSS:"))
                peak = max(peak, rss)
                if rss > 3500:
                    killed = 1
            except (OSError, ValueError, StopIteration):
                continue
        if killed or time.monotonic() - started > 900:
            os.killpg(child.pid, signal.SIGKILL)
            child.wait()
            break
        time.sleep(0.25)
status = 137 if killed else child.returncode
print(f"exit={status} peak_rss_mb={peak} killed={killed} log={log_path}")
sys.exit(status if status >= 0 else 128 - status)
