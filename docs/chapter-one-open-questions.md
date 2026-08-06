# Chapter 1 — Ten Questions to Close the Vision Gaps

**Status:** ANSWERED 2026-08-04 — all ten decided. The decisions and their consequences live in
**`docs/chapter-one-vision-decisions.md`** (V1–V10), which is normative. This document remains the
evidence and reasoning record.
**Date:** 2026-08-04 · **Owner:** Adam (solo dev)
**Method:** single-model analysis (Claude) against the local corpus. The `/octo:council` run for
this task (`~/.claude-octopus/councils/20260804-211644-166c86/`) returned zero usable
perspectives — 4 of 7 seats were assigned to the host CLI, which cannot dispatch itself, and
`--research-first` reported "No local corpus workspace was detected." This document is **not**
council output and carries no multi-provider consensus.

Sources read: `docs/prd-chapter-one.md`, `soul-meter-crpg-design-doc.md`,
`docs/phase-0-ratification.md`, `CLAUDE.md`, plus symbol-level verification against the repo.
The Dramgid vault was **not** re-read for this pass — every vault claim below is marked as
needing verification.

Questions are ranked by **how much more expensive the answer gets if deferred**, not by
importance. Q1 is cheapest to answer today and most catastrophic to answer in Phase 4.

---

## Ranked questions

### Q1 — What is Chapter 1 proving, and to whom?
**Resolves:** nothing — and that is the finding. No FR, goal, or metric in the PRD states it.

The PRD defines "finished" with great precision and never says what finishing *decides*. Three
readings are all consistent with the current text and lead to materially different builds:

- **Chapter 1 ships standalone** (episodic / early access) → FR-801 Mirror Shop and NG+ carry-over
  are load-bearing revenue-and-retention features, and the three ending-family *seeds* must pay
  off inside Ch1 or players get an unresolved chord.
- **Chapter 1 is a vertical-slice demo** to prove the thesis before committing 2–3 more chapters →
  NG+ is decoration, ≥10 side quests is over-built, and the money is in one unforgettable
  consequence chain.
- **Chapter 1 is the foundation for a full game with no external audience yet** → the cut list
  should be invoked aggressively and the Phase 1.5 comprehension gate is the *only* gate that
  matters.

**Why it is cheapest now:** it re-weights G7, FR-801, FR-502's count, and the entire Phase 5
block. Answering it in Phase 4 means discarding authored content.

---

### Q2 — Do the Definition and Paradox ability trees ship in Chapter 1?
**Resolves:** design doc §4.2 + pillar 4; **no FR currently owns this.**

This is the largest traceability hole in the PRD. Design pillar 4 is *"Power is temptation, and
the meter is the bill"*; §4.2's essence-consumption rule is called **[PROPOSAL — load-bearing]**
and is the stated reason REPLACE and REDEFINE end with Maiiam dead. The two escalating ability
trees are the mechanism that makes the Soul Meter a *meter* rather than a score.

The PRD mentions them exactly once — inside FR-104, as push directions on the Balance Gauge
("Definition powers order, Paradox powers chaos"). FR-104 therefore **assumes a system no FR
specifies**. Grep confirms the code side: `data/combat/actions/05_paradox.tres` exists as a lone
action resource; there is no tree, no acquisition path, no consumption accounting.

The fork:
- **Trees ship in Ch1** → a new FR block (~FR-350s?) and a phase home are missing from a ratified
  PRD, and the person-hour estimate excludes them entirely.
- **Trees are Chapter 2+** → then in Chapter 1 the Soul Meter is spent only by dialogue choices
  and casting-past-empty-Breath, pillar 4 goes untested at the exact gate (Phase 1.5) designed to
  test whether players understand the systems, and "the three ending-family setups seeded"
  (executive summary) has no mechanism.

**Why it is expensive later:** the trees are the Meter's spend side. Retrofitting a temptation
economy after 12 locations of dialogue are authored means re-auditing every Meter cost in the
game.

---

### Q3 — What is the trigger condition for invoking the cut list?
**Resolves:** `docs/phase-0-ratification.md` §8; PRD §8 risk row "Solo-dev burnout / no deadline
= no finish".

Phase 0 produced the numbers that were supposed to make the cut list real: **350–510 person-hours,
35–51 weeks at 10 h/week, 18–26 weeks at 20 h/week.** It also pre-agreed a 4-step cut list. It did
not define *when* a cut fires. The PRD's stated mitigation for burnout is "phase gates are the
deadline substitute" — but a gate measures quality, not elapsed cost, so no gate can ever trigger
a cut.

A cut list with no trigger is a wish. The question is which trigger you want: a calendar date, an
hours-burned ceiling per phase (e.g. "Phase 2 exceeds 100h → cut item 4"), or a velocity check at
each gate.

**Why it is expensive later:** cuts taken early cost nothing; cuts taken after authoring destroy
finished work. Cut item 4 (ten Triads → five) is nearly free today and costs five authored Triad
effect sets in Phase 4.

---

### Q4 — What is the minimum build that satisfies the Phase 1.5 gate, given it depends on Phase 2 *and* Phase 3?
**Resolves:** PRD Phase 1.5 (line 184–185), FR-606, FR-603.

Phase 1.5 is ratified as **the go/no-go for content production** and has never been run. Its
required slice includes "one full tactical encounter (AP + at least one Defining Strike + zone
facing + Balance Gauge)" — all Phase 2 — and its pass condition requires each playtester to
correctly answer **"why did that cast fail?"**, which is precisely what FR-606 (blocked-action
explanation) exists to make answerable, and FR-606 is a P0 whose UI home is Phase 3.

So a gate positioned "before region production" transitively depends on two later phases. The PRD
acknowledges the chronology ("this gate sits between Phase 2 and Phase 4") but the phase list
still prints it as 1.5, and `CLAUDE.md` treats it as pending now.

The fork: does FR-606 move into Phase 2's scope, does the gate accept a text-only blocked-action
message as sufficient, or does the gate formally renumber to Phase 2.5 with an explicit
dependency list?

**Why it is expensive later:** every week of content authored before this gate is content built on
an unvalidated comprehension assumption — the PRD's own Appendix C assumption #1.

---

### Q5 — Does character creation exist before the Phase 1.5 gate?
**Resolves:** FR-202, FR-701, §3 metric "Distinct viable builds ≥ 4 archetypes".

**Verified: `ancestry` appears in zero code files** — only in the three design documents. The five
ratified ancestries (Vael, Kaan, Vaerin, Weftkin, Kes'reth) are a P0 requirement with no
implementation, scheduled for Phase 3, i.e. *after* the gate.

But the acceptance metric is "≥ 4 archetypes playtested (martial, caster, talker,
balanced/refusal)" and the gate asks outside playtesters to complete a slice. Without creation,
playtesters test a pregenerated character, which cannot surface the build-diversity question at
all — and build diversity is where the ancestry × Wheel-affinity × Background design either works
or collapses.

The fork: pregen characters for the gate (cheap, tests comprehension only), or pull minimal
creation forward into Phase 2 (expensive, tests the actual thesis).

---

### Q6 — When the cut list removes Kes'reth, what carries the refusal build?
**Resolves:** phase-0 §8 cut item 3 vs. design doc §4.2 "Neutrality = refusal" and FR-104's
"the refusal/stabilizer build must be mechanically rewarded".

Phase 0 designated Kes'reth (Voice/Anchor, *Mirrored Scars*) as **"the ancestry of the stabilizer
archetype"**, pairing with the Stillpoint Triad and giving "the refusal/center-holding build an
identity from character creation onward." Cut item 3 then names Kes'reth as the first ancestry to
drop, reasoning that it is the only new-canon one so "cutting it costs nothing already written."

That reasoning weighs authoring cost and ignores thesis cost. RESTORE — the equilibrium ending —
is explicitly *the hardest road*, requiring the player to refuse both ability trees all game. The
refusal build is the mechanical expression of the game's central claim. Cutting its ancestry
identity while the never-cut list protects the consequence mandate is an unexamined ranking.

The fork: reorder the cut list, move refusal identity onto Vael or a Background so it survives the
cut, or accept that the refusal build has no creation-time identity in Ch1.

---

### Q7 — Is the region map P0 or P1, and does it gate hub 2–3 authoring?
**Resolves:** FR-503.

FR-503 is tagged **(P0)** but its own text says "region map screen (P1 for fast-travel between
discovered hubs)" — the requirement contains both priorities in one sentence. Phase 0 ratified the
design answer ("yes — discovered hubs only, at a cost") but not the priority.

**Verified: zero code matches for `fast_travel`, `region_map`, or `RegionMap`.** Four locations
exist (`dom`, `dorthkor_road`, `wilds`, `wound_lip`) against a target of 8–12, and one hub of
three.

The reason this is a fork and not a detail: if traversal between three hubs is walk-only, hub
placement and the wilds connective tissue must be authored to make walking interesting, which is
Phase 4 content cost. If fast travel lands first, hubs can be placed for fiction and the
connective wilds can be thinner. You cannot author hubs 2–3 well without knowing which.

---

### Q8 — Are the 3–5 companion personal quests inside the 120–180h Phase 4 estimate?
**Resolves:** FR-505, phase-0 §8 estimate table.

**Verified: `personal_quest` appears nowhere in the repo** (only in `CLAUDE.md`'s gap list).

FR-505 is one P1 line requiring, per companion: a personal quest, battle barks, Balance-Gauge-
relevant abilities, and ending-family temperament coverage. A personal quest that satisfies FR-502
standards (≥2 genuinely different outcomes, ≥1 ledger write, no pure fetch) costs roughly what a
side quest costs. Three to five of them is 30–50% of the ≥10 side-quest bar, hidden inside a
single P1 bullet.

Phase 4's 120–180h line item does not break them out. Either the estimate silently includes ~5
extra quests or it is low by that much — and the cut list never mentions companions, so they are
currently uncuttable by omission.

---

### Q9 — Which playtime number is the Phase 4 authoring target: 8–12 dense hours or 15–25?
**Resolves:** G1 vs. PRD executive summary vs. design doc §8.

Phase 0 ratified **8–12 dense hours as the acceptance bar, 15–25h as a stretch, never a
requirement.** Two documents were not updated to match:

- `docs/prd-chapter-one.md` line 14 (executive summary) still reads *"one region (8–12 locations,
  3 hubs, 15–25 hours)"*.
- `soul-meter-crpg-design-doc.md` §8 line 157 still reads *"v1 = one region (8–12 locations, 3
  hubs, 15–25 hours)"* — Phase 0's write-back table amended §4, §6 and §7 of the design doc, but
  not §8.

This is live drift inside a ratified document, and it matters operationally: content-wave sizing
in Phase 4 is computed from the target. A 2× ambiguity in the target is a 2× ambiguity in the
largest phase.

---

### Q10 — What is the trip-wire that forces an architecture response to FR-904 before 12 locations exist?
**Resolves:** FR-904, `docs/performance-benchmark.md`.

FR-904 (60fps field with full HUD, battle transitions <2s) is **P1 and scheduled in Phase 5**, and
per `CLAUDE.md` it is instrumented but not satisfied — measured today at four locations, before
companions, before living-world texture (FR-504), before the Zhavar ambient VFX (FR-308).

Performance is the one requirement whose remedy is architectural. Discovering the floor is
unreachable in Phase 5 means changing rendering or scene-composition decisions after all content
is authored against them.

The question is what measurement, at what phase boundary, forces a response — e.g. "if a hub with
full HUD, 3 companions and living-texture NPCs cannot hold 60fps at the Phase 3 gate, the
Zhavar/VFX budget is cut before Phase 4 authoring begins."

---

## Conflicts and unsupported assumptions found

**Document-vs-document (verified this pass):**

| # | Conflict | Location |
|---|---|---|
| 1 | Playtime 15–25h vs ratified 8–12h bar | PRD line 14; design doc §8 line 157 (both un-amended by Phase 0) |
| 2 | FR-503 tagged P0 while its own text assigns P1 to fast travel | PRD line 135 |
| 3 | Phase 1.5 declared pre-content but depends on Phase 2 (encounter) and Phase 3 (FR-606) | PRD lines 184–185 |
| 4 | Cut list drops the refusal-build ancestry while refusal is thesis-critical | phase-0 §8 item 3 vs design doc §4.2 |
| 5 | Design doc §10 Q12 still lists "gameplay chassis" as "the next one to answer"; §6 marks it DECIDED | design doc lines 117, 185 |

**PRD assumes what the code does not have (verified by grep):**

| Assumption | Code state |
|---|---|
| FR-701 five playable ancestries (P0, ratified) | `ancestry` — **0 code references** |
| FR-505 companion personal quests (P1) | `personal_quest` — **0 references** |
| FR-503 region map / fast travel (P0, ratified) | `fast_travel`, `region_map` — **0 references** |
| D5 partial respec / Mirror Rewriting (ratified) | `respec` — **0 code references** |
| FR-801 Mirror Shop (P1) | `ng_plus.gd` exists; no shop |
| FR-104 assumes Definition/Paradox powers | one orphan `data/combat/actions/05_paradox.tres`; no tree |
| FR-501 region: 8–12 locations, 3 hubs | 4 location resources, 1 hub |

Implemented and verified present, contrary to any assumption they are open: Vär/harmony
(`globals/game_state.gd`, `casting_gate.gd`, `test/unit/test_var_harmony.gd`), Breath, Zhavar,
Aftertones, Tempo, Instability, the ten Triads, Defining Strikes, Balance arcs, style points.

**Vault-vs-doc — flagged, NOT verified this pass.** `CLAUDE.md` records that the design doc
predates the lore vault and that where they conflict (it names *Maiiam kidnapped* vs *withdrawing*)
the vault wins. Design doc §2 now marks the kidnapping **[CANON]** in several places, and Act III
depends on it. Nobody re-checked this against `~/projects/dramgid-vault/` in this pass. If the
vault still says withdrawing, the conflict sits under Act III and the REPLACE/REDEFINE ending
logic — worth a 10-minute check before it propagates further.
