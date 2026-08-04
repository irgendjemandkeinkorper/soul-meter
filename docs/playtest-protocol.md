# Phase 1.5 Playtest Protocol — the comprehension go/no-go gate

**Status:** gate materials ready; **the gate has never been run.**
**Gate authority:** `docs/prd-chapter-one.md` line 185 (RATIFIED 2026-08-03). Passing this gate
is the go/no-go for region content production. It is not advisory and not waivable by an agent.
**Who runs it:** a human. The 3–5 testers must be *outside* the project. No agent, simulation,
or internal review substitutes for this — that substitution is explicitly disallowed.

---

## 1. What the gate actually requires

Verbatim obligations from PRD line 185, each restated as a checkable condition:

| # | Requirement | Pass condition |
|---|---|---|
| G1 | 3–5 outside playtesters (**not one**) | ≥3 distinct testers, none a project contributor |
| G2 | Complete the slice **unaided** | No hints from the facilitator during play (see §5) |
| G3 | 45–90 minute slice | Session fits the window without skipping subsystems |
| G4 | "Why did that cast fail?" answered correctly | Per tester, for the systems the slice exposes |
| G5 | "What does this gauge do?" answered correctly | Per tester, for the Balance Gauge |
| G6 | Every subsystem state survives save/load | Verified mid-slice, by the tester, not scripted |
| G7 | NG+ mock applies carry-overs correctly | Mock rollover observed at slice end |

**The gate fails if any single tester misses G4 or G5** for a system the slice put in front of
them. The complexity budget is the thing under test — not the tester.

---

## 2. Slice contents (PRD line 185, breadth-first)

The slice must exercise every subsystem end-to-end:

1. **Exploration** — Dom, plus one travel transition via `GameFlow.travel()`.
2. **One dialogue skill check** — a visible percentile check through `SkillCheck`.
3. **One consequence-bearing side quest** — resolution writes a ledger event, read back later.
4. **One full tactical encounter** — must include *all four*: AP spend, at least one Defining
   Strike, zone facing, and Balance Gauge movement.
5. **Save/load mid-slice** — tester-initiated, mid-encounter or mid-quest.
6. **Mock NG+ rollover** — carry-overs applied and visible.

**Onboarding is breadth-first (§8 risk plan): the slice opens Tone-only.** Chords and Triads
must not be exposed in the opening beat. The progression to build toward:

`Tone-only cast → AP + zone move → a Balance-moving action → weakness / Defining Strike →
combat speech → an explicit failure with its unblock condition stated`

---

## 3. The known comprehension hazards (what we expect to fail)

These are recorded *before* the test so the results can't be rationalized afterward.

- **H1 — Command rail overload.** The rail can expose Strike, Guard, Stabilize, Defining
  Strike, Paradox, Speech-seam, three movement actions, and Focus simultaneously.
  Hypothesis: testers cannot form a model of *when* each applies.
- **H2 — Refusal reasons are one hover away.** `Battle.action_lock_reason()` returns a
  structured reason, but `ui/screens/battle.gd:331` renders only `LOCKED` on the button and
  puts the reason in `tooltip_text` (line 338). Hypothesis: testers see *that* something is
  blocked, never *why* — this directly threatens G4.
- **H3 — `ASH_DIM` / `ASH_FAINT` contrast on dark stone** is unaudited. If a tester says they
  cannot *read* a disabled-state explanation, that is a contrast failure, not a comprehension
  failure — record it separately (see §6) so the two don't get conflated.

---

## 4. Facilitator setup

1. Build the slice (Windows artifact from CI, or a local export).
2. Fresh save; no prior progress; default settings.
3. Recording: screen + audio if the tester consents. **Consent is required and must be
   explicit.** If telemetry or uploaded saves are ever added, consent, data minimization,
   retention, pseudonymous tester IDs, and deletion must be settled first — none of that is
   in place today, so **collect nothing beyond notes and consented recordings.**
4. Assign a pseudonymous tester ID (`T1`…`T5`). Do not record real names in the repo.

---

## 5. Session script

Read verbatim; do not improvise help.

> "Play until you reach a natural stopping point, or about an hour. Think aloud when you can.
> I can't answer questions about how the game works during play — if you're stuck, say so and
> keep going however you like. Being stuck is useful data, not a failure on your part."

**During play, the facilitator may not:** explain a mechanic, point at UI, or confirm/deny a
tester's theory. Log every question asked instead — an unanswered question is a finding.

**Prompt only at these two moments** (after the relevant subsystem has been encountered):

- After a *failed* cast: **"Why did that cast fail?"** — record the answer verbatim.
- After the Balance Gauge has visibly moved: **"What does this gauge do?"** — verbatim.

Ask each exactly once. Do not rephrase into a leading question.

---

## 6. Evidence template

One file per tester, committed to `test/manual/phase-1-5/<tester-id>.md`.

```markdown
# Phase 1.5 comprehension gate — tester <ID>

Date:
Facilitator:
Build (commit SHA):
Session length:
Outside tester (not a contributor): yes / no
Consent to record: yes / no

## Subsystem coverage
- [ ] Exploration + travel transition
- [ ] Dialogue skill check
- [ ] Consequence-bearing side quest (ledger write observed)
- [ ] Tactical encounter: AP spent / Defining Strike / zone facing / Balance moved
- [ ] Save + load mid-slice
- [ ] Mock NG+ rollover

## G4 — "Why did that cast fail?"
Verbatim answer:
Correct for the systems exposed: PASS / FAIL
What the actual reason was:

## G5 — "What does this gauge do?"
Verbatim answer:
Correct: PASS / FAIL

## G6 — state survived save/load
Observed discrepancies (list, or "none"):

## G7 — NG+ mock carry-overs
Applied correctly: yes / no. Details:

## Questions the tester asked (each one is a finding)

## Legibility problems (contrast/readability — NOT comprehension)

## Facilitator notes
```

Plus one `test/manual/phase-1-5/summary.md` recording the overall **PASS / FAIL**, tester
count, and — if FAIL — which of G1–G7 failed and for whom.

---

## 7. If the gate fails

**Do not let an agent redesign the combat rail in response.** Cutting or hiding any of the
actions from the permanent roster is a product decision reserved for the human
(`CLAUDE.md`: don't add or remove mechanics without the design-doc section first).

The permitted agent response to a failure is:

1. Record the failure and the specific misconception, verbatim.
2. Propose options with trade-offs to the human — do not pick one.
3. Ship only changes that surface *existing* information better (e.g. rendering the already-
   structured `action_lock_reason` persistently instead of tooltip-only). Presenting existing
   domain state more legibly is not a mechanics change; removing an action is.

Re-run the full gate with fresh testers after any remediation. A tester who has already seen
the slice can no longer answer G4/G5 cold.

---

## 8. What this gate does *not* certify

- **Not performance.** FR-904 has its own instrumentation and its own baseline; a comprehension
  pass says nothing about frame budget.
- **Not narrative coherence.** That is FR-906's per-wave playtest pass against the world-state
  matrix.
- **Not accessibility.** §3's H3 contrast check is a spot-check, not a WCAG sweep.
