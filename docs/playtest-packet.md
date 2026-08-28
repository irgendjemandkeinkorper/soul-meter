# Gate T criterion 6 playtest execution packet

This is the fillable execution record for `docs/playtest-protocol.md`. Run one
immutable build with 3–5 eligible outside testers. Copy the per-tester form once per
valid session and complete the summary only after all sessions are finished.

Do not write real names, contact details, or recording links in this repository.

## Build and session record

| Field | Value |
|---|---|
| Build artifact / filename | |
| Commit SHA | |
| Export target | Windows Desktop / Linux / other: |
| Godot version | 4.7.1 |
| Build prepared by | |
| Test dates | |
| Evidence directory | `test/manual/gate-t/` |

Build the official Linux artifact from a clean worktree:

```bash
scripts/build_playtest.sh
cd build/playtest/linux
sha256sum -c SHA256SUMS
```

The builder runs strict acceptance, exports the release executable and pack, boots
the exported binary headlessly, and writes `BUILD-MANIFEST.txt` plus `SHA256SUMS`.
It refuses a dirty worktree by default. `--allow-dirty` is for local verification
only; never use an artifact whose manifest says `valid_for_gate_t=no` in a tester
session.

Preflight:

- [ ] Artifact, commit SHA, and export target match for every session.
- [ ] `BUILD-MANIFEST.txt` says `worktree=clean` and `valid_for_gate_t=yes`.
- [ ] `sha256sum -c SHA256SUMS` passes before the first session and after transfer.
- [ ] The acceptance gate is green for this exact commit.
- [ ] Each tester is outside the project and has not previously inspected the slice.
- [ ] Each tester uses a fresh save and default settings.
- [ ] The build exposes the required dialogue, consequence, tactical, save/load, and
  mock-NG+ breadth.
- [ ] The tactical encounter uses charge time (CT), not the retired AP chassis.
- [ ] The tactical encounter exposes the grid, elevation, and facing.
- [ ] The encounter visibly exposes Balance/weather and at least one tile charge, residue, or detonation event.
- [ ] Recording is disabled unless the tester explicitly opts in.
- [ ] The facilitator has a timer and a separate copy of the tester form.

## Facilitator script

Read this verbatim:

> You are testing the game, not being tested yourself. Start from this fresh save and
> play until the chapter slice reaches its natural stopping point, for about an hour.
> Please think aloud when you can. I can help only with controls the game does not
> display; I cannot explain mechanics or tell you whether a theory is right. If you
> get stuck, say what you expected and continue however seems best.

During play:

- Do not name mechanics, point at UI, recommend an action, or answer “am I doing this
  right?” before the four comprehension answers are captured.
- Record questions, hesitation, misclicks, unreadable labels, and moments where the
  tester’s model diverges from the build.
- Ask each gate question once, immediately after its relevant event. Capture the
  answer verbatim before any follow-up.
- If a required event never appears, mark the session invalid rather than coaching
  the tester into it.

## Scenario checklist

The tester should, without hints:

- [ ] Explore Dom and form the company.
- [ ] Complete a visible dialogue skill check.
- [ ] Resolve one consequence-bearing town thread.
- [ ] Observe a later dialogue, price, encounter, or NPC read-back of that choice.
- [ ] Travel to Dorthkor Road.
- [ ] Read and use the CT timeline.
- [ ] Move or attack using meaningful height or facing.
- [ ] Attempt or use a Defining Strike.
- [ ] Move the Balance axis and observe weather/board feedback.
- [ ] Observe tile charge, residue, hush, or detonation feedback.
- [ ] Use or attempt combat speech.
- [ ] Encounter one blocked cast with a named reason and unblock condition.
- [ ] Save, alter visible state, load, and compare the restored state.
- [ ] Return and report the encounter outcome.
- [ ] Inspect the existing mock NG+ rollover and visible carry-over.

## Per-tester observation form

### Tester ID: T__

| Field | Value |
|---|---|
| Date | |
| Build artifact / SHA verified | yes / no |
| Outside tester, no prior exposure | yes / no |
| Start time | |
| End time | |
| Duration (45–90 minutes required) | |
| Completed unaided | yes / no |
| Session valid | yes / no |
| Recording consent | none / notes only / audio-video opt-in |

### Subsystem coverage

Copy the scenario checklist here and mark every observed item. For any missing item,
record whether the build did not expose it or the tester did not discover it.

### Gate question 1 — cast refusal

Prompt: **“Why did that cast fail?”**

| Verbatim answer | Actual `blocked_by` reason and unblock condition | Correct? |
|---|---|---|
| | | PASS / FAIL |

### Gate question 2 — Balance

Prompt: **“What does this gauge do?”**

| Verbatim answer | Actual board/weather function observed | Correct? |
|---|---|---|
| | | PASS / FAIL |

### Gate question 3 — CT order

Prompt: **“Who acts next, and why?”**

| Verbatim answer | Actual next actor and CT/speed/cost reason | Correct? |
|---|---|---|
| | | PASS / FAIL |

### Gate question 4 — tile state

Prompt: **“Explain what just happened on that tile.”**

| Verbatim answer | Actual charge/residue/weather/hush/detonation cause | Correct? |
|---|---|---|
| | | PASS / FAIL |

### Save/load comparison

| State | Before save | After load | Match? |
|---|---|---|---|
| Location and position | | | |
| Party and HP | | | |
| Quest/consequence flags | | | |
| Soul and Balance-related state | | | |
| Visible tactical state tested | | | |

### Mock NG+ comparison

| Carry-over | Before rollover | Fresh-save result | Correct? |
|---|---|---|---|
| Style points | | | |
| Mirror Shop purchase(s) | | | |
| Expected reset state | | | |

### Observations

| Time | Area | Tester action / verbatim comment | Expected | Actual | Severity |
|---|---|---|---|---|---|
| | | | | | |

### Facilitator interventions

| Time | Intervention | Control-only? | Session still valid? |
|---|---|---|---|
| | | yes / no | yes / no |

## Gate summary

Exclude invalid or ineligible sessions before tallying.

| Tester | Valid? | Unaided? | Q1 cast | Q2 Balance | Q3 CT | Q4 tile |
|---|---|---|---|---|---|---|
| T1 | | | PASS / FAIL | PASS / FAIL | PASS / FAIL | PASS / FAIL |
| T2 | | | PASS / FAIL | PASS / FAIL | PASS / FAIL | PASS / FAIL |
| T3 | | | PASS / FAIL | PASS / FAIL | PASS / FAIL | PASS / FAIL |
| T4 | | | PASS / FAIL | PASS / FAIL | PASS / FAIL | PASS / FAIL |
| T5 | | | PASS / FAIL | PASS / FAIL | PASS / FAIL | PASS / FAIL |

| Gate item | Result | Evidence |
|---|---|---|
| 3–5 eligible outside testers | PASS / FAIL | |
| Every counted session valid and unaided | PASS / FAIL | |
| Q1 majority: cast refusal | __ / __ — PASS / FAIL | |
| Q2 majority: Balance | __ / __ — PASS / FAIL | |
| Q3 majority: CT order | __ / __ — PASS / FAIL | |
| Q4 majority: tile state | __ / __ — PASS / FAIL | |
| Save/load breadth completed | PASS / FAIL | |
| Mock NG+ breadth completed | PASS / FAIL | |

**Pass threshold:** a **majority of eligible testers** must answer each of the four
questions correctly, scored per question rather than averaged. At least three valid
outside-player sessions are required.

Gate T criterion 6: **PASS / FAIL**

Human gate owner: ____________________  Date: __________

Build SHA: ____________________  Reviewer: ____________________

If the result is FAIL, stop region-content production and hand the verbatim
misconceptions to Claude for the ratified design response. Do not reinterpret a failed
question as a pass and do not merge it into an average score.
