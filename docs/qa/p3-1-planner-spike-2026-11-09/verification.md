# Verification log

## No-planner control follow-up — 2026-11-09

Follow-up base: `25d3cf1d` on `codex/p3-1-planner-spike`, initially clean.
The original spike history below is retained; its earlier suite runs were not repeated.
This follow-up ran only the affected suite, once red and once green. No import was needed.
One Godot process at a time, no git writes, no GitHub operations, and no capture reruns.

Both suite commands ran from the worktree root. The supplied capped runner's referenced
`scripts/test.sh` was again confirmed byte-identical to this worktree's wrapper with `cmp`.

Failing-first command, before implementation:

```bash
CAP_MB=3500 TIMEOUT_S=900 LOG=/tmp/codex-planner2/planner-red.log \
  SOUL_METER_HEADLESS=0 GODOT_BIN="$HOME/.local/bin/godot" LP_NUM_THREADS=1 \
  XDG_DATA_HOME=/tmp/codex-planner2/data XDG_CONFIG_HOME=/tmp/codex-planner2/config \
  XDG_CACHE_HOME=/tmp/codex-planner2/cache \
  xvfb-run -a -s "-screen 0 1920x1080x24" \
  bash /tmp/codex-tools/test_capped.sh res://test/unit/test_planner_spike.gd
```

Summary: `exit=100 peak_rss_mb=485 killed=0 log=/tmp/codex-planner2/planner-red.log`.
Six cases executed: three passed and three failed, with six assertion failures and no
parse errors. The expected failures were missing variant validation, `none` producing
100 plans instead of zero, and speculative work/cache-listener activity in the control.

Passing command, after implementation:

```bash
CAP_MB=3500 TIMEOUT_S=900 LOG=/tmp/codex-planner2/planner-green.log \
  SOUL_METER_HEADLESS=0 GODOT_BIN="$HOME/.local/bin/godot" LP_NUM_THREADS=1 \
  XDG_DATA_HOME=/tmp/codex-planner2/data XDG_CONFIG_HOME=/tmp/codex-planner2/config \
  XDG_CACHE_HOME=/tmp/codex-planner2/cache \
  xvfb-run -a -s "-screen 0 1920x1080x24" \
  bash /tmp/codex-tools/test_capped.sh res://test/unit/test_planner_spike.gd
```

Summary: `exit=0 peak_rss_mb=469 killed=0 log=/tmp/codex-planner2/planner-green.log`.
All six cases passed, zero errors/failures/orphans. Coverage accepts all four names,
rejects unknown/empty names, retains 100 CT seats without changing scheduler state,
requires zero speculative work/listeners for `none`, checks its default decision plan,
and preserves the original gate and cache-invalidation contracts. Both runs log the
existing 32-resources-in-use teardown warning; the green process exits 0.

### Follow-up measurement protocol

The exact sequential command was:

```bash
set -o pipefail
for round in 1 2; do
  for variant in none full cached fallback24; do
    prefix=""
    if [ "$round" = 1 ]; then prefix="run1-"; fi
    python3 tools/planner_spike/measure_capped.py "$variant" \
      "$PWD/docs/qa/p3-1-planner-spike-2026-11-09/${prefix}${variant}.json" \
      --reuse-legibility "$PWD/docs/qa/p3-1-planner-spike-2026-11-09/retained-legibility.json" \
      | tee -a /tmp/codex-planner2/measurement-launches.log || exit "$?"
  done
done
```

Each call starts a fresh Godot process, waits for it to exit, and enforces the unchanged
3500 MB / 900 second watchdog. Each has fresh isolated XDG directories under
`/tmp/codex-planner2/bench-<report-stem>-*`, fixed dice, `LP_NUM_THREADS=1`, Xvfb/X11,
Compatibility/Mesa llvmpipe and a seeded 1920×1080 player config. The new optional flag
passes `--planner-reuse-legibility` to Godot and bypasses capture execution. The original
capture fixture and its 2/3 verdict remain unchanged. The control explicitly references
the cached capture evidence, not a newly measured control capture.

All eight launches completed successfully, in this exact order. Each summary's `log=`
path is `/tmp/codex-planner2/benchmark-<report-stem>.log`. The full printed Godot commands
and summary lines are retained in [measurement-launches.txt](measurement-launches.txt).

| Order | Report | Summary |
|---|---|---|
| 1 | [run1-none.json](run1-none.json) | `exit=0 peak_rss_mb=920 killed=0` |
| 2 | [run1-full.json](run1-full.json) | `exit=0 peak_rss_mb=920 killed=0` |
| 3 | [run1-cached.json](run1-cached.json) | `exit=0 peak_rss_mb=920 killed=0` |
| 4 | [run1-fallback24.json](run1-fallback24.json) | `exit=0 peak_rss_mb=918 killed=0` |
| 5 | [none.json](none.json) | `exit=0 peak_rss_mb=917 killed=0` |
| 6 | [full.json](full.json) | `exit=0 peak_rss_mb=927 killed=0` |
| 7 | [cached.json](cached.json) | `exit=0 peak_rss_mb=922 killed=0` |
| 8 | [fallback24.json](fallback24.json) | `exit=0 peak_rss_mb=919 killed=0` |

Every report has 120 frames, 106 production enemy outcomes, 100 admitted hostiles and
100 CT seats throughout, and an empty `errors` array. The two controls have no speculative
plans or computation samples. Report exit 0 means measurement completed, not a budget
pass: all eight frame p95 values exceed 16.67 ms. All transitions are below 2,000 ms.
Legibility remains the retained 2/3. Each log contains the same 18 pre-existing
`FieldMap::_theme_world_label` conversion errors and one 38-resources-in-use teardown
warning; there are no new script errors. No out-of-scope repair was attempted.

### Capture conversion

`/usr/bin/python3` with PIL 12.3.0 converted all six images using
`Image.open(source).convert("RGB").save(target, "JPEG", quality=90)`. Each JPEG decoded
successfully at 1920×1080 before its source was removed. All six JPEGs were opened with
`view_image`; the displayed next actor, revealed strike, Guard text and HP response
remain present. This checks conversion integrity without re-judging the existing verdict.
The default `python3` lacked PIL; the system interpreter supplied it. No repository
dependency changed. [capture-compression.json](capture-compression.json) retains the
source and target hashes/sizes; [legibility.html](legibility.html) uses the JPEGs.

### Follow-up acceptance checks

[control-followup-checks.json](control-followup-checks.json) records the independent
Python checks over the eight reports: original top-level/raw/frame schema keys, 120 raw
samples, nearest-rank p95 and means recomputed, same environment/placement/fixture/actions,
100-hostile admission and CT counts, expected 0/100/100/24 speculative plans, empty
report errors, unchanged gate arithmetic, and explicit reused-capture provenance.
README values and overheads use the control from the same run.

All seven distinct HTML targets resolve, including the six images reached by the
comparator selector's JavaScript. Markdown links resolve. No capture PNG remains and
all six JPEG hashes match the conversion manifest; source hashes match the original
HEAD images. `git diff --check` passes and the Python wrapper compiles.

`git diff --stat HEAD -- globals actors ui world data` is empty.
`git diff --quiet HEAD -- globals actors ui world data project.godot` exits 0.
[production-unchanged.json](production-unchanged.json) has been refreshed against
`25d3cf1d` and confirms byte equality for the combat controller, Battle, scheduler and
kit AI. All changed/untracked source and evidence files are within the allowed scope.
No Godot process remained after the measurement sequence.

Open questions/deviations: no new ruling or scope deviation; owner hardware/profiling
choice remains open, Guard is Claude's separate issue, and the inherited 2/3 verdict
was not re-judged. The historical session-suite memory limitation below remains unchanged.

## Original spike verification (historical)

Worktree: `/home/adamjroder/projects/soul-meter-wt/codex-planner-603`.
Base: `d39acca91466d793843bbd2e06cf19e23d8c57fe` (`codex/p3-1-planner-spike`).
No git writes or GitHub operations. One Godot process at a time throughout.

## Exact suite invocation

Each row below substitutes `CAP`, `LOG_NAME`, and `SUITE` in this command, run from the worktree root:

```bash
CAP_MB=CAP TIMEOUT_S=900 LOG=/tmp/codex-planner/LOG_NAME.log \
  SOUL_METER_HEADLESS=0 GODOT_BIN="$HOME/.local/bin/godot" LP_NUM_THREADS=1 \
  XDG_DATA_HOME=/tmp/codex-planner/data XDG_CONFIG_HOME=/tmp/codex-planner/config \
  XDG_CACHE_HOME=/tmp/codex-planner/cache \
  xvfb-run -a -s "-screen 0 1920x1080x24" \
  bash /tmp/codex-tools/test_capped.sh res://test/SUITE.gd
```

The supplied runner references another worktree's `scripts/test.sh`; `cmp` verified that
wrapper is byte-for-byte identical to this worktree's wrapper. It uses `--path .`, so all
tests ran against this worktree. The requested session/hex suites are actually under
`test/integration/`, not `test/unit/`. There is one combat-controller suite here.

| Order | CAP | LOG_NAME | SUITE | Result |
|---|---:|---|---|---|
| 1 | 3500 | before-combat-session | integration/test_combat_session | `exit=137 peak_rss_mb=3598 killed=1` — 18 cases completed before cap kill; not a pass |
| 2 | 5500 | before-hex-combat | integration/test_hex_combat | `exit=0 peak_rss_mb=4707 killed=0` — 1 case / 10 seeds passed |
| 3 | 3500 | planner-red | unit/test_planner_spike | `exit=105 peak_rss_mb=469 killed=0` — test-scaffold parse errors; not the intended red phase |
| 4 | 3500 | planner-red-assertions | unit/test_planner_spike | `exit=100 peak_rss_mb=466 killed=0` — all 4 intended assertions failed before implementation |
| 5 | 3500 | before-combat-controller | integration/test_combat_controller | `exit=0 peak_rss_mb=470 killed=0` — 69 passed |
| 6 | 3500 | planner-green | unit/test_planner_spike | `exit=0 peak_rss_mb=467 killed=0` — 4 passed; 0 errors/failures/orphans |
| 7 | 3500 | after-combat-session | integration/test_combat_session | `exit=137 peak_rss_mb=3531 killed=1` — all 20 cases passed, then cap kill before clean exit; run still fails |
| 8 | 5500 | after-hex-combat | integration/test_hex_combat | `exit=0 peak_rss_mb=4705 killed=0` — 1 case / 10 seeds passed |
| 9 | 3500 | after-combat-controller | integration/test_combat_controller | `exit=0 peak_rss_mb=470 killed=0` — 69 passed |

The first red launch needed test-scaffold corrections: call static functions through a
`Script` value and load the unnamed zone-board implementation by path. No planner code
was written before the second red run reported all four expected assertion failures.
The extra launch is the deviation from the approximately eight-call budget.

## Import and benchmark launches

One initial import, before tests; exit 0:

```bash
XDG_DATA_HOME=/tmp/codex-planner/data XDG_CONFIG_HOME=/tmp/codex-planner/config \
  XDG_CACHE_HOME=/tmp/codex-planner/cache LP_NUM_THREADS=1 \
  timeout 900 xvfb-run -a "$HOME/.local/bin/godot" --headless --path . --import \
  > /tmp/codex-planner/import.log 2>&1
```

The fresh import logged transient unresolved UIDs/autoload compile errors and addon
shutdown errors. Subsequent runtime/suite launches loaded the project. Vendor files and
UID references were not changed.

Rendered measurements use `/tmp/codex-planner/measure_capped.py`, a single-process-group
watchdog (3500 MB per process, 900 seconds), with isolated per-variant XDG directories,
`LP_NUM_THREADS=1`, `SOUL_METER_FIXED_DICE=1`, and a seeded 1920×1080 player config.
Its source is retained at `tools/planner_spike/measure_capped.py`; use
`python3 tools/planner_spike/measure_capped.py VARIANT ABSOLUTE_REPORT_PATH` to reproduce,
one variant at a time. This wrapper runs the measurement tool only; every gdUnit suite
used the supplied `/tmp/codex-tools/test_capped.sh`.
The exact Godot command for each VARIANT is:

```bash
xvfb-run -a -s "-screen 0 1920x1080x24" "$HOME/.local/bin/godot" \
  --path . --resolution 1920x1080 --script res://tools/populated_field_benchmark.gd -- \
  --planner-variant VARIANT --planner-output \
  /home/adamjroder/projects/soul-meter-wt/codex-planner-603/docs/qa/p3-1-planner-spike-2026-11-09/VARIANT.json
```

The first `full` launch exited 1 (`peak_rss_mb=499 killed=0`) before measuring because the
existing SceneTree harness compiled concrete combat types before autoload registration
(`Renown`, `GameState`, `UIManager` unavailable). Its references now use engine base types
at that boundary, with concrete planner/capture scripts loaded after boot. The production
controller and game autoloads remain unchanged.

The second `full` launch was stopped deliberately (`exit=-15 peak_rss_mb=672 killed=0`,
shell exit 143). Inspection found the old harness waiting for a HUD under UIManager while
the current one-bar HUD is owned by FieldHUD. That wait cannot measure a valid transition.
The benchmark now discovers the existing field HUD before trying the no-field fallback.
The stopped-run log is `/tmp/codex-planner/benchmark-full-obsolete-hud.log`.
The next launch was also stopped before valid sampling (`exit=-15 peak_rss_mb=658 killed=0`,
shell exit 143) to correct that lookup's base type: FieldHUD extends CanvasLayer, not Control.
Its log is `/tmp/codex-planner/benchmark-full-hud-type.log`.

The first completed diagnostic run reached 100 present / 99 in CT (`exit=1
peak_rss_mb=949 killed=0`): `BenchHostile010` was refused because its cell was occupied.
The opening wight had already moved before the other bodies joined the model. This is
not accepted as a 100-hostile result. Diagnostic JSON and log are preserved at
`/tmp/codex-planner/full-99.json` and `/tmp/codex-planner/benchmark-full-99.log`.
The final common fixture gives only the synthetic opening wight PROVISIONAL Reason 0
before the initial alert, allowing a party turn before it can occupy another body's cell.

That diagnostic screenshot was opened and inspected: old queued action beats overwrote
the newly revealed turn strip. The capture now uses the existing stage replay seam to
flush prior beats before the static capture. It also resets prior guarding and uses
PROVISIONAL capture-only wight attack 20 / party HP 100, making Guard's effect measurable
above the minimum damage floor. These changes happen after all performance samples.

Final comparable runs, all with 100 in CT and all 120 frame samples:

| Variant | Summary | Report |
|---|---|---|
| full | `exit=0 peak_rss_mb=945 killed=0` | `full.json` |
| cached | `exit=0 peak_rss_mb=972 killed=0` | `cached.json` |
| fallback24 | `exit=0 peak_rss_mb=974 killed=0` | `fallback24.json` |

Benchmark exit 0 means measurement completed; each report's `budget_pass` is false.
All six final captures were opened and inspected. Each reports 2/3 facts; no candidate
passes the combined performance/legibility gate.

The environment is Xvfb / Compatibility / Mesa llvmpipe. It is local software-rendered
evidence, not the Phase 6 reference hardware gate. Existing deferred
`FieldMap::_theme_world_label` conversion errors occur in both baseline and benchmark logs;
no out-of-scope field/UI repair was attempted. Existing suite teardown resource warnings
are retained in the logs.

## Artifact and isolation checks

The raw arrays were independently checked with Python: nearest-rank p95 recomputed,
120 samples per variant, identical planned cells, every frame retaining 100 CT hostiles,
100 / 100 / 24 speculative plans, visible rendered HUD, six captures (now JPEGs), no report errors.
All final screenshots were opened before the 2/3 visual verdict was recorded.
`git diff --check` passed. The Python measurement wrapper compiles. Local report/HTML
links resolve. `production-unchanged.json` records SHA-256 comparisons with HEAD;
`git diff --quiet HEAD -- globals actors world ui data project.godot` returned 0.
No broader regression sweep was run; the existing session suite remains incomplete under
the requested cap in both before and after runs.
The existing export presets exclude `tools/*`, `test/*` and `docs/*`; no export configuration
was changed. No Godot process remained after verification.
