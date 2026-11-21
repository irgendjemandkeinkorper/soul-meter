"""Render or capture through the documented temporary-autoload recipe.

Run from the repository root. The before captures must be made before replacing the
kit. Each invocation runs exactly one Godot process and restores project.godot.
"""
from pathlib import Path
import hashlib
import os
import subprocess
import sys

ROOT = Path(__file__).resolve().parents[3]
PROJECT = ROOT / 'project.godot'
MODE = sys.argv[1] if len(sys.argv) == 2 else ''
assert MODE in ('before', 'after', 'render'), 'Choose before, after, or render'
SCRIPT = 'tools/render_building_kit.gd' if MODE == 'render' else 'docs/qa/building-kit-painterly-2026-11-09/capture.gd'
BEFORE = PROJECT.read_bytes()
ENV = dict(os.environ, XDG_DATA_HOME='/tmp/codex-kit/data', XDG_CONFIG_HOME='/tmp/codex-kit/config',
           XDG_CACHE_HOME='/tmp/codex-kit/cache', LP_NUM_THREADS='1', GODOT_BIN=str(Path.home()/'.local/bin/godot'))
ENV['SOUL_METER_BUILDING_KIT' if MODE == 'render' else 'SOUL_METER_KIT_CAPTURE'] = '1' if MODE == 'render' else MODE
for directory in ['data', 'config', 'cache', 'logs']:
    (Path('/tmp/codex-kit')/directory).mkdir(parents=True, exist_ok=True)
LOG = Path('/tmp/codex-kit/logs') / (MODE + '.log')
try:
    lines = BEFORE.splitlines(keepends=True)
    index = next(i for i, line in enumerate(lines) if line.startswith(b'Pandora=')) + 1
    lines.insert(index, ('BuildingKitQA="*res://' + SCRIPT + '"\n').encode())
    PROJECT.write_bytes(b''.join(lines))
    with LOG.open('w') as output:
        result = subprocess.run(['xvfb-run', '-a', '-s', '-screen 0 1920x1080x24', ENV['GODOT_BIN'], '--path', '.'],
                                cwd=ROOT, env=ENV, stdout=output, stderr=subprocess.STDOUT, timeout=240)
    print(MODE, 'exit', result.returncode, 'log', LOG)
    assert result.returncode == 0
    marker = 'BUILDING-KIT: ok\n' if MODE == 'render' else 'KIT-CAPTURE: PASS'
    assert marker in LOG.read_text(), 'Missing success marker; inspect log'
finally:
    PROJECT.write_bytes(BEFORE)
    assert PROJECT.read_bytes() == BEFORE
    print('project.godot restored SHA256', hashlib.sha256(BEFORE).hexdigest())
