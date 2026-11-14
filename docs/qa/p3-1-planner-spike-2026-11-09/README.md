# P3.1 / #603 planner spike — 2026-11-09

Evidence only. Nothing ships. R10 remains `defer`; ruling 6 is unchanged.
The official rendered FR-904 reference-hardware gate remains in Phase 6.

**Result remains FAIL under the unchanged #603 rules.** All four variants completed
twice at **100 present, 100 alerted/admitted, 100 retained in CT**. Neither uncapped
candidate meets the local interim frame budget in either run. All transitions pass.
The retained legibility verdict is **PROVISIONAL 2/3**, not the required 3/3.

**The no-planner control itself does not meet 16.67 ms on this machine:** frame p95 is
**377.350 ms in run 1 and 356.417 ms in run 2**. The non-speculative field/HUD and driven
production actions already exceed the frame gate. This control does not isolate rendering
from other production work, and cannot establish performance on the owner's GPU.

All measurements and differences below are **PROVISIONAL**. Each overhead is the variant
minus `none` **within the same run**, calculated from unrounded values. These are observed
differences between whole-process measurements, not isolated planner-computation costs.
Negative differences are retained: cached's −9.091 ms in run 1 and +15.122 ms in run 2
show that its frame difference is not stable across these two samples. No overhead is
subtracted when applying the gate.

| Run | PROVISIONAL variant / raw report | Frame p95 (ms) | Planner overhead: frame p95 (ms) | Transition (ms) | Planner overhead: transition (ms) | D9 mean, advisory (ms) | Frame / transition | Budget verdict |
|---|---|---:|---:|---:|---:|---:|---|---|
| 1 | [none — control](run1-none.json) | 377.350 | +0.000 | 1017.385 | +0.000 | 16.829 | FAIL / PASS | **FAIL** |
| 2 | [none — control](none.json) | 356.417 | +0.000 | 1000.991 | +0.000 | 16.941 | FAIL / PASS | **FAIL** |
| 1 | [full — uncapped](run1-full.json) | 1122.401 | +745.051 | 1792.366 | +774.981 | 17.139 | FAIL / PASS | **FAIL** |
| 2 | [full — uncapped](full.json) | 1103.127 | +746.710 | 1766.585 | +765.594 | 16.763 | FAIL / PASS | **FAIL** |
| 1 | [cached — uncapped](run1-cached.json) | 368.259 | -9.091 | 1092.183 | +74.798 | 17.067 | FAIL / PASS | **FAIL** |
| 2 | [cached — uncapped](cached.json) | 371.539 | +15.122 | 1035.475 | +34.484 | 17.269 | FAIL / PASS | **FAIL** |
| 1 | [fallback24 — comparison only](run1-fallback24.json) | 508.285 | +130.935 | 1172.865 | +155.480 | 17.400 | FAIL / PASS | **FAIL** |
| 2 | [fallback24 — comparison only](fallback24.json) | 518.247 | +161.830 | 1164.429 | +163.438 | 17.135 | FAIL / PASS | **FAIL** |

The reports linked in the table each contain 120 raw rendered frame intervals,
106 production enemy outcome timings, 100-hostile CT membership counts on every refresh,
per-refresh planner counters, environment, placement, admission and retained capture facts.
Run 1 uses `run1-<variant>.json`; run 2 uses `<variant>.json` and replaces the previous
single-run measurements. No comparator is missing and no target count was reduced.

Planner-refresh p95 in runs 1 / 2 is 0.637 / 0.603 ms for control instrumentation,
817.293 / 803.920 ms for full, 12.252 / 11.894 ms for cached, and 141.180 / 150.030 ms
for fallback24. The cached planner's own work fits 16.67 ms, but the rendered field
does not; that is **not** a passing candidate. Cached refreshes retained 100 plans,
with 1–7 detailed and 93–99 cheap intents, and 0–100 cache hits depending on combat
invalidation. Both controls have zero plans, zero detailed/cheap intents, zero cache
hits and empty planner-computation arrays throughout.

## Legibility evidence — inspected, 2/3

Open [legibility.html](legibility.html) for the three named facts marked over the retained
captures, a comparator selector, and the response image. The six captures were converted
with PIL to JPEG quality 90 at their original 1920×1080 resolution, then all six JPEGs
were opened and visually inspected by Codex. Total size fell from 21,178,739 to 4,465,456
bytes (78.9% smaller); [capture-compression.json](capture-compression.json) records sizes
and hashes. The PNGs were removed. No capture was rerun and the existing 2/3 verdict stands.
This is agent inspection of a scripted static fixture,
not an independent human playtest or a claim about game feel.

| Named fact | Observed answer | Verdict |
|---|---|---|
| Next actor | **Benchmark Wight 001**, after Vex's active turn; top strip | PASS |
| Revealed intent | **Strike Vex the Unbowed**, 74% hit, 13 damage on hit; the revealed strip row matches the prototype's fresh plan | PASS |
| Right response | **Guard** is offered with “Reduces the next hit”; submit succeeds and sets guarding, but forecast stays 13 and the captured strike takes Vex from 100 to 87 HP | **FAIL** |

The right response is deliberately not credited merely because the Guard button exists.
Its advertised reduction is not demonstrated by this live action path. The controller's
damage finalization does not consume `guarding` in this path; fixing production combat
is outside the allowed spike scope. No alternative response was silently substituted.
The long revealed-intent row also pushes part of the active marker off the left edge;
the next enemy's name and intent remain visible, and Vex's active plate is visible below.
No HUD layout or rule was changed to hide this finding.

## Measurement contract

The interim budget is frame p95 ≤16.67 ms and battle transition <2,000 ms.
D9's mean per decision ≤2 ms is advisory. All fixture sizes, sample counts,
cadences, tier distances and the 24-decider comparison are PROVISIONAL.
The capacity under test is the ratified approximately 100 present-and-alerted hostiles.
The #603 gate rules are unchanged: all three original comparators must be present, and
at least one uncapped candidate (`full` or `cached`) must pass both timing limits and
all three legibility facts. Neither `fallback24` nor the diagnostic `none` control can
pass that gate. Control-subtracted timings are diagnostic only and cannot replace the
absolute frame/transition limits.

The benchmark uses the existing populated field, alert/admission path, CT controller,
and HUD. A tool-only planner reads that controller; it does not replace combat execution.
Each comparator runs in a fresh process with the same placement, dice and party fixture.
The `none` control only counts CT membership, with no speculative plans, movement search,
intent forecasts, cache entries or cache-invalidation listener. Its small nonzero refresh
time is instrumentation. All enemy actions use the unchanged production default path;
the capture's decision-query seam also uses that default plan for `none`.
Full planning includes the existing strike/aim forecast and the existing movement search
for advances. Cached planning can retain a cheap distant intent and computes full detail
for imminent or revealed enemies; decision-time requests always compute fresh detail.
The fallback compares 24 speculative planners while retaining the 100-hostile field and CT
load. It is not an admission ceiling or an estimate of a shipped queue implementation.

Timing reruns use `--planner-reuse-legibility` with
[retained-legibility.json](retained-legibility.json), which preserves the inspected
evidence from HEAD `25d3cf1d`. Each report records `capture_rerun: false`, its source
variant and that evidence path. `none` references the cached fixture's existing evidence;
it has no separate capture or newly awarded legibility facts. The capture implementation
and capture-only fixture are unchanged.

Raw rendered frame intervals include planner work and any driven combat action in that
frame. Cold planning is included in transition readiness, and frame outliers remain in
the raw report. No future archetype abilities or permanent planner architecture are chosen.

PROVISIONAL protocol: 120 samples, one ally yield/Guard attempt every fourth sample until
at least 100 enemy outcomes, 2,000 ms post-cold settle, next-eight CT projection plus
six-hex proximity for detailed cached work. Every combat event invalidates the cache.
The opener has fixture Reason 0 so it cannot move onto another synthetic body's cell
before admission completes; every other hostile retains its existing archetype stats.
Party HP is 1,000,000 during timing. Capture-only changes then place one wight adjacent,
set its attack to 20, restore party HP to 100 and clear prior guarding, set deterministic
CT readiness, lock the existing intent, and flush prior animation through the replay seam.
These are instrumentation fixtures, not balance decisions. The capture uses the existing
lock seam directly; it does not claim to test Sacred Clarity's acquisition or cost.

Frame p95 uses nearest rank over complete wall-clock intervals, including planner work,
the rendered field/HUD and driven actions. Transition covers first alert through every
admission, cold planning and the next rendered frame. D9 follows the existing event-span
instrument: action request / previous enemy outcome to the next enemy outcome, including
synchronous controller and presentation listeners. It is not pure planner time; pure
planner-computation and refresh timings are reported separately. Outliers are retained.

Environment: Godot 4.7.1 official, Linux 22.04, Intel i5-13400F (16 reported processors),
Compatibility renderer, X11/Xvfb at 1920×1080, Mesa llvmpipe, `LP_NUM_THREADS=1`, fixed
fight dice, isolated XDG directories. VSync setting is unsupported by this display driver.
Two sequential sets in order `none`, `full`, `cached`, `fallback24`, one fresh process per
variant with fresh isolated XDG directories, on the shared local machine; background load
was not controlled. Placement, environment and all 120 driven-action entries match across
the eight reports. No code or fixture changed between measurements.
These software-rendered numbers cannot establish performance on the owner's GPU.
Benchmark peaks were 917–927 MB, with no watchdog kills; all eight processes exited 0.

## Verification and review boundary

[verification.md](verification.md) records both follow-up suite invocations, including
the expected failing-first run, and all eight benchmark summaries. The six-case spike
suite passes. [control-followup-checks.json](control-followup-checks.json) records the
schema, counts, raw-statistic calculations, links and scope checks. All eight report
`errors` arrays are empty; the logs still contain the pre-existing field-label conversion
errors and teardown resource warnings, equally in controls and comparators.
No production combat, scheduler, UI, actor, world or data file changed. The
[byte comparison](production-unchanged.json) confirms the core combat files match HEAD
`25d3cf1d`; `git diff --stat HEAD -- globals actors ui world data` is empty.
The original spike's hex/controller passes and capped session failures remain historical
evidence in the verification log; those broader suites were not rerun for this follow-up.
No git writes, GitHub writes, vendor edits, generated-data edits or UID rewrites occurred.

Open owner/Claude questions, retained here because the handoff confines evidence to this directory:

- Which profiling or hardware-measurement step follows this failed local uncapped gate? No ceiling or permanent planner is selected.
- Claude is filing Guard mitigation separately; the existing overflowing intent strip also remains outside this follow-up. The capture verdict stays 2/3.
- The existing combat-session suite exceeds the mandated 3.5 GB cap; its complete before/after pass is unavailable under that cap.

## Sources and open decisions

- Task contract: #603 supplied in the handoff; worktree base `claude/land-rest`.
- Read-only roadmap sources: `origin/claude/roadmap-2026-11-08`,
  `docs/roadmap-2026-11-08.md`, `docs/roadmap-issues-2026-10-30.md`,
  `docs/roadmap-2026-10-30.md` Phase 3 and R10.
- That branch's `docs/owner-decisions.md` records the 2026-10-31 R10 `defer`
  answer in §5; the ruling text is in the referenced roadmap. No alternate fallback
  number was supplied.
- P3.2 onward still wait for Phase 2 acceptance. These measurements authorize no ceiling,
  new HUD rule, enemy content, or release.
