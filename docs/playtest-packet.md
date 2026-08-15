# Phase 1.5 playtest execution packet

Use this packet to run the comprehension gate defined by
[`playtest-protocol.md`](playtest-protocol.md). This is an execution record, not a substitute
for that protocol. Run the same build with **3–5 outside testers**, one fresh save per tester,
and one copy of the observation form per tester.

The companion performance gate has a separate procedure in
[`fr-904-runbook.md`](fr-904-runbook.md).

## Build and session record

Complete these fields before the first session. If the build changes, start a new packet.

| Field | Value |
|---|---|
| Build artifact / filename | |
| Commit SHA | |
| Build date (UTC) | |
| Godot version | |
| Export target | Windows Desktop / other: |
| Facilitator | |
| Planned tester IDs | T1 / T2 / T3 / T4 / T5 |
| Packet execution dates | |
| Recording location and retention date, if consented | |

Preflight:

- [ ] The artifact and commit above match.
- [ ] Each tester is outside the project and has not seen this slice before.
- [ ] Each tester has a fresh save and default settings.
- [ ] The build exposes every G1–G7 subsystem listed in `playtest-protocol.md` §2. If any is
      unavailable, stop: the build is not eligible for this gate.
- [ ] Screen/audio recording is off unless the tester explicitly consents.
- [ ] The facilitator has a timer, this packet, and a separate observation form for each tester.

## Facilitator script

Read this verbatim before control is handed to the tester:

> Play until you reach a natural stopping point, or about an hour. Think aloud when you can.
> I can't answer questions about how the game works during play. If you're stuck, say so and
> keep going however you like. Being stuck is useful data, not a failure on your part.

During play, do not explain mechanics, point at the interface, suggest a route or response, or
confirm a theory. Record questions and stalls without answering them. Administrative help is
limited to hardware failure or restarting a crashed build; record either as a defect.

## Scenario script (45–90 minutes)

The timing bands are guides, not prompts to the tester. Do not announce objectives that the game
has not surfaced. The session is invalid if it ends before 45 minutes, exceeds 90 minutes, or
skips a required subsystem.

### 1. Start in Dom and form the company (about 5–10 minutes)

1. Start **New Game**.
2. Let the tester discover movement, interaction, the HUD objective, and the locked road markers.
3. Enter the Four Arms and recruit exactly two available companions; Vex remains the fixed lead.
4. Let the tester inspect any surfaced party or inventory information without direction.

Record onboarding questions, objective uncertainty, and whether the tester understands why a
candidate or confirmation action is unavailable.

### 2. Take the commission and follow one town thread (about 10–20 minutes)

1. Let the objective lead the tester to Marshal Coiljaw and **The Broken Muster** commission.
2. The tester must encounter one visible dialogue skill check through the build's existing
   dialogue path. Record the displayed chance, choice, result, and the tester's interpretation.
3. The tester must accept and resolve one existing consequence-bearing side quest. Record its
   name and later read-back; do not choose the outcome for the tester.
4. Open the journal or standings only if the tester chooses to do so. Record whether the
   consequence can be found without help.

If the build does not surface a dialogue skill check or a resolvable side quest, mark the session
**INVALID — INCOMPLETE SLICE**. Do not replace either with an explanation or debug action.

### 3. Travel to Dorthkor Road and complete the tactical encounter (about 15–30 minutes)

1. Follow the commissioned road and encounter the demon vanguard.
2. Continue to the Mustered Bloodbellow encounter.
3. Across the tactical play, observe all of the following without coaching:
   - AP spent;
   - zone facing or movement used;
   - Balance Gauge visibly moved;
   - at least one Defining Strike attempted or used;
   - one cast fails and presents its existing reason or unblock condition.
4. Let the tester choose the authored force, muster-name, or release route that they can reach.

Immediately after the first failed cast, ask exactly once:

> Why did that cast fail?

Immediately after the Balance Gauge has visibly moved, ask exactly once:

> What does this gauge do?

Record both answers verbatim. Do not rephrase, probe, correct, or ask again.

### 4. Save and load during the slice (about 5–10 minutes)

After the tester has made meaningful progress but before the final ruling, ask only:

> Please save, then load that save, and continue.

The tester chooses when and how. After loading, record whether position, party, health, Soul,
Balance/encounter state where applicable, quest state, flags, inventory, and ledger consequences
match the pre-save state. Any missing or altered state fails G6.

### 5. Return, report, and inspect consequences (about 10–15 minutes)

1. Return to Coiljaw and report the Bloodbellow outcome.
2. Let the tester choose Dom's ruling.
3. On the consequence screen, record whether the tester can identify the main outcome and the
   chosen side quest's read-back.
4. Continue Exploring and confirm the existing free-roam handoff.

### 6. Existing NG+ mock rollover (about 5 minutes)

Run the build's existing mock rollover at the slice end. Do not describe expected carry-overs
before the tester inspects the result. Ask the tester to compare the pre-rollover completion
state with the mock new-game state, then record which existing style points, purchased
carry-overs, and completion metadata were applied.

If the tested build has no human-visible way to execute and inspect the mock rollover, mark G7
**NOT RUN** and the overall gate **FAIL**. A unit test, console edit, or facilitator explanation
is not human playtest evidence.

## Per-tester observation form

Copy this section once for each pseudonymous tester. Do not commit real names.

### Tester ID: T__

| Field | Observation |
|---|---|
| Date / facilitator | |
| Build / commit verified | yes / no |
| Outside tester, no prior slice exposure | yes / no |
| Recording consent | yes / no / not recorded |
| Start / end / total duration | |
| Completed unaided | yes / no |
| Invalidating interruption or assistance | none / details: |

Subsystem coverage:

- [ ] Exploration in Dom and travel transition
- [ ] Visible dialogue skill check
- [ ] Consequence-bearing side quest and later read-back
- [ ] AP spent
- [ ] Zone facing or movement used
- [ ] Balance Gauge visibly moved
- [ ] Defining Strike attempted or used
- [ ] Failed cast encountered
- [ ] Save/load completed and state compared
- [ ] Mock NG+ rollover inspected

Comprehension evidence:

| Gate question | Verbatim answer | Actual in-game reason/function | PASS / FAIL |
|---|---|---|---|
| Why did that cast fail? | | | |
| What does this gauge do? | | | |

State and consequence evidence:

| Check | Before | After | PASS / FAIL |
|---|---|---|---|
| Save/load state | | | |
| Side-quest ledger read-back | | | |
| Mock NG+ carry-overs | | | |

Behavioral observations (timestamps where possible):

| Time | Game state / screen | Tester action or verbatim remark | Expected | Observed | Severity / note |
|---|---|---|---|---|---|
| | | | | | |

Questions asked by the tester (leave unanswered during play):

| Time | Verbatim question | Context |
|---|---|---|
| | | |

Legibility issues, recorded separately from comprehension:

| Time | Element | Problem observed | Settings / resolution |
|---|---|---|---|
| | | | |

## Defect log

Use one row per distinct defect. Attach evidence by relative path or issue URL; do not put tester
names in filenames.

| ID | Tester | Build / commit | Time | Area | Reproduction steps | Expected | Actual | Severity | Evidence | Status |
|---|---|---|---|---|---|---|---|---|---|---|
| P15-001 | | | | | | | | blocker / major / minor | | open |

## Gate summary and sign-off

| Requirement | Result | Evidence |
|---|---|---|
| G1 — 3–5 outside testers | PASS / FAIL | |
| G2 — unaided completion | PASS / FAIL | |
| G3 — every session 45–90 minutes | PASS / FAIL | |
| G4 — every tester explains the failed cast | PASS / FAIL | |
| G5 — every tester explains the Balance Gauge | PASS / FAIL | |
| G6 — state survives save/load | PASS / FAIL | |
| G7 — mock NG+ carry-overs apply correctly | PASS / FAIL | |

**Pass threshold:** at least three eligible outside testers complete the full slice unaided in
45–90 minutes, every tester answers **both** comprehension questions correctly without hints,
and G6–G7 pass. One tester missing either question makes the entire gate fail.

Overall Phase 1.5 gate: **PASS / FAIL**

Defects accepted for this gate, with rationale:

Human gate owner: ____________________  Date: __________  Commit: ____________________

**Region-content merge authorization:** I authorize region-content changes to merge only because
this packet records a Phase 1.5 **PASS** under the threshold above.

Authorized by: ____________________  Signature: ____________________  Date: __________

If the result is FAIL, NOT RUN, or INVALID, this line must remain unsigned and region content
must not merge into `world/locations/` or `LocationRegistry.ALL`.
