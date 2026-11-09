# P3.1 / #603 planner spike — 2026-11-09

Evidence only. Nothing ships. R10 remains `defer`; ruling 6 is unchanged.
The official rendered FR-904 reference-hardware gate remains in Phase 6.

**Result: FAIL — return the measured question to the owner.** All three comparators
completed at **100 present, 100 alerted/admitted, 100 retained in CT**. Neither uncapped
candidate meets the local interim frame budget. All transitions pass. The inspected
legibility capture reaches **PROVISIONAL 2/3**, not the required 3/3.

| PROVISIONAL comparator | Rendered frame p95 (ms) | Transition (ms) | D9 mean per decision, advisory (ms) | Frame / transition | Budget verdict |
|---|---:|---:|---:|---|---|
| Uncapped full | 1000.300 | 1411.146 | 15.052 | FAIL / PASS | **FAIL** |
| Uncapped tiered/cached | 335.064 | 893.711 | 15.056 | FAIL / PASS | **FAIL** |
| 24-decider comparison only | 472.555 | 1045.205 | 14.875 | FAIL / PASS | **FAIL** |

Raw reports: [full.json](full.json), [cached.json](cached.json),
[fallback24.json](fallback24.json). Each contains 120 raw rendered frame intervals,
106 production enemy outcome timings, 100-hostile CT membership counts on every refresh,
per-refresh planner counters, environment, placement, admission and capture facts.
No comparator is missing. No target count was reduced for the final comparison.

Planner-refresh p95 alone was 720.915 / 11.291 / 158.891 ms respectively. The cached
planner's own work fits 16.67 ms, but the full rendered field does not; that is **not**
a passing candidate. Cached refreshes retained 100 plans, with 1–7 detailed and
93–99 cheap intents, and 0–100 cache hits depending on combat invalidation.

## Legibility evidence — inspected, 2/3

Open [legibility.html](legibility.html) for the three named facts marked over the original
captures, a comparator selector, and the response image. All six PNGs were opened and
visually inspected by Codex. This is agent inspection of a scripted static fixture,
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

The benchmark uses the existing populated field, alert/admission path, CT controller,
and HUD. A tool-only planner reads that controller; it does not replace combat execution.
Each comparator runs in a fresh process with the same placement, dice and party fixture.
Full planning includes the existing strike/aim forecast and the existing movement search
for advances. Cached planning can retain a cheap distant intent and computes full detail
for imminent or revealed enemies; decision-time requests always compute fresh detail.
The fallback compares 24 speculative planners while retaining the 100-hostile field and CT
load. It is not an admission ceiling or an estimate of a shipped queue implementation.

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
One run per variant, on the shared local machine; background load was not controlled.
These software-rendered numbers cannot establish performance on the owner's GPU.
Final benchmark peaks were 945 / 972 / 974 MB, with no watchdog kills.

## Verification and review boundary

[verification.md](verification.md) records every suite invocation and summary, including
the failing-first run, the baseline memory-cap failure, and the harness repairs discovered
while running this older benchmark against the current integration tip. The new four-case
spike suite passes. No production combat, scheduler, UI, actor, world or data file changed.
The [byte comparison](production-unchanged.json) confirms the core combat files match HEAD.
Hex combat and all 69 controller cases pass before and after. The session run hit its cap
both times: 18 cases completed before the first kill; all 20 passed before the second kill,
but its process still exited 137. Neither capped run is reported as a clean pass.
No git writes, GitHub writes, vendor edits, generated-data edits or UID rewrites occurred.

Open owner/Claude questions, retained here because the handoff confines evidence to this directory:

- Which profiling or hardware-measurement step follows this failed local uncapped gate? No ceiling or permanent planner is selected.
- Should Guard mitigation and the overflowing intent strip receive separate repair scope before the next legibility gate?
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
