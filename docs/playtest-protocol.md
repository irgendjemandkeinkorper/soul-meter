# Gate T criterion 6 playtest protocol — tactical comprehension

**Status:** ready to run; no qualifying outside-player result is recorded yet.

**Authority:** `docs/prd-amendment-tactical-layer.md` §5, criterion 6, ratified and
trimmed 2026-08-05. `docs/roadmap-chapter-one.md` §1.3 and M5 apply the same ruling.

Phase 1.5 is superseded by Gate T, not cancelled. There is **one gate**, and this is
**not a second session**. The earlier breadth-first slice remains the play scenario;
Gate T supplies the current tactical chassis and scoring rule.

Use `docs/playtest-packet.md` during each session and
`docs/playtest-run-of-show.md` for facilitator logistics. Performance is separate:
use `docs/fr-904-runbook.md` for Gate T criterion 9.

## 1. Eligibility and session validity

- Run the same immutable build with **3–5 eligible outside testers**. Recruit 6–8
  people to absorb dropouts.
- A tester is outside the project only if they did not author, review, or previously
  inspect this slice.
- Each tester starts from a fresh save and default settings.
- Each session lasts 45–90 minutes and covers the required slice without facilitator
  hints. A session outside that window, or one missing a required subsystem, is invalid.
- The facilitator may explain controls only when the build itself does not display
  them. They may not explain mechanics, point at relevant UI, or confirm a theory
  before the four answers are recorded.
- Recording is opt-in. Store pseudonymous IDs, never names or contact details.

## 2. Slice coverage

The inherited Phase 1.5 breadth is retained on the ratified tactical chassis:

1. Explore Dom and form the company.
2. Complete one visible dialogue skill check.
3. Resolve one consequence-bearing side thread and observe a later read-back.
4. Complete one full tactical encounter using charge time (CT), the grid,
   elevation/facing, a Defining Strike, Balance/weather movement, combat speech,
   and tile charge/residue/detonation.
5. Encounter at least one blocked cast whose FR-606 refusal names the blocking
   system and nearest unblock condition.
6. Save and load during the slice; compare the visible state before and after.
7. Inspect the existing mock NG+ rollover and visible carry-over.

Retired AP and zone-positioning instructions must not be used. The build under test
uses charge time plus grid/elevation/facing.

## 3. The four gate questions

Ask each question once, immediately after the relevant event. Record the answer
verbatim before asking follow-ups.

1. **“Why did that cast fail?”**
   A correct answer identifies the actual FR-606 `blocked_by` system and the nearest
   unblock condition shown by the build. Generic answers such as “not enough points”
   are insufficient when the game named Soul, Vär, Breath, CT, span, elevation,
   facing, occupancy, range, or husked state.
2. **“What does this gauge do?”**
   A correct answer explains that actions move the Balance axis and that its state
   changes the whole board through order/chaos weather bias or extreme effects. It is
   not merely alignment, mana, morality, or a cosmetic meter.
3. **“Who acts next, and why?”**
   A correct answer identifies the next actor from the CT timeline and connects the
   order to charge/speed and the CT cost of committed actions. “It alternates turns”
   is incorrect.
4. **“Explain what just happened on that tile.”**
   A correct answer connects the observed result to the tile’s element and charge,
   residue accumulation, weather interaction, hush, or detonation as applicable to
   the exact event. A generic “magic effect” answer is insufficient.

## 4. Scoring

Gate T criterion 6 passes only when:

- at least three valid outside-player sessions are complete;
- every valid tester completed the slice unaided; and
- a **majority of eligible testers** answers each question correctly **per question**.

Do not average all answers into one score. One well-understood mechanic cannot carry
another. With three testers, each question needs at least 2 correct answers; with four,
at least 3; with five, at least 3.

Save/load and mock NG+ observations remain required breadth evidence, but they do not
replace or dilute the four comprehension tallies. Automated Gate T criteria 1–5 and
7–10 remain separate evidence.

## 5. Evidence layout

Create one file per valid tester under `test/manual/gate-t/`:

```text
test/manual/gate-t/T1.md
test/manual/gate-t/T2.md
test/manual/gate-t/T3.md
test/manual/gate-t/summary.md
```

Copy the per-tester and summary templates from `docs/playtest-packet.md`. Include the
build filename, commit SHA, export target, session duration, subsystem coverage,
verbatim answers, correctness rationale, and facilitator-intervention log. Do not
commit recordings, names, email addresses, Discord handles, or other personal data.

## 6. Failure handling

If criterion 6 fails, stop region-content production as required by the roadmap.
Record the misconception verbatim and identify whether the failure is missing
information, unreadable presentation, or an incorrect player model. Do not remove or
redesign mechanics in this evidence pass. Claude owns the design response and the
ratified stop-loss decision; Codex may implement an approved presentation repair and
then the same immutable-build protocol must be rerun.
