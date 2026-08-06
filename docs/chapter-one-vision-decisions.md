# Chapter 1 — Vision Decisions (V1–V10)

**Status:** DECIDED by the user 2026-08-04 · **Owner:** Adam (solo dev)
**Supersedes:** the open questions in `docs/chapter-one-open-questions.md`, which remains the
evidence and reasoning record.
**Normative for:** scope, phase order, and priority. Amendments this record requires in
`docs/prd-chapter-one.md`, `soul-meter-crpg-design-doc.md`, and
`docs/phase-0-ratification.md` are listed in §3 and are **NOT yet applied.**

---

## 1. The decisions

| # | Question | Decision |
|---|---|---|
| **V1** | What is Chapter 1 proving? | **Ships as a standalone episode.** |
| **V2** | Do the Definition/Paradox trees ship in Ch1? | **Yes.** |
| **V3** | What fires the cut list? | **Hours ceiling per phase** — 25% overrun on the Phase 0 estimate fires the next cut-list item automatically. |
| **V4** | Phase 1.5's dependency on later phases | **Renumber to Phase 2.5**; pull FR-606 forward into Phase 2. |
| **V5** | Character creation before the gate? | **Yes** — minimal creation must land by end of Phase 2. |
| **V6** | What protects the refusal build? | **A Background**, available to all ancestries. Kes'reth stays cuttable. |
| **V7** | Region map / fast travel priority | **P0**, unambiguous. |
| **V8** | Companion personal quests in Phase 4's estimate? | **Yes** — they are inside the 120–180h line. |
| **V9** | Playtime authoring target | **8–12 dense hours.** 15–25h is dead as a target. |
| **V10** | Performance trip-wire | **Loaded-hub test at the Phase 3 gate.** |

---

## 2. Consequences

### 2.1 The Phase 0 hour estimate is now stale — and V3 depends on it

This is the load-bearing consequence. **V3 fires cuts against the Phase 0 table (350–510h), but
V1, V2, V5 and V7 all add work that table never counted.** An hours ceiling measured against a
stale baseline will fire cuts too late, or fire them for the wrong reason.

Rough delta, to be replaced by a real re-estimate:

| Source | Δ hours | Why |
|---|---|---|
| V2 — Definition/Paradox trees | **+40–70** | A two-tree escalating ability system: acquisition, tier gating, Meter-consumption accounting, and the temptation UI. Smaller than the element engine, same shape. Currently in *no* phase. |
| V1 — standalone episode | **+15–30** | A Chapter-1 ending beat and epilogue slides that resolve rather than merely seed; Mirror Shop moves from nice-to-have to required. |
| V7 — region map/fast travel at P0 | **+10–15** | Map screen, discovery state, travel-cost model. |
| V5 — creation pulled into Phase 2 | **±0 (moves ~15–25h earlier)** | Not new work; it lands sooner and enlarges Phase 2's ceiling. |
| **Revised total** | **~415–625h** | 41–62 weeks at 10 h/week; 21–31 weeks at 20 h/week. |

**Required before V3 can operate:** re-estimate the Phase 0 §8 table with V1/V2/V7 included, and
set the per-phase ceilings from the revised numbers. Until then V3 has nothing valid to measure
against.

**Also required:** V3 needs rough hour logging per phase. It is the only decision here with an
ongoing habit cost.

### 2.2 V2 needs an FR block that does not exist

The Definition and Paradox trees are referenced once in the whole PRD — inside FR-104, as push
directions on the Balance Gauge. Shipping them in Chapter 1 requires writing the requirement
before building it. Proposed home: a new **§6.10 / FR-350s** block covering acquisition sources
(QUINE shards and order-relics for Definition; Maiiam's loose essence for Paradox), tier
escalation, the essence-consumption accounting that makes design doc §4.2's load-bearing
[PROPOSAL] mechanically true, and the temptation-surfacing UI.

Open sub-question this record does *not* resolve: **which phase owns it.** The trees depend on the
Soul Meter (exists) and feed the Balance Gauge (Phase 2), so Phase 2 or a Phase 2b are the
candidates. Flagging rather than deciding.

### 2.3 V4 + V5 restructure the phase list

- Phase 1.5 becomes **Phase 2.5**, positioned after the combat vertical, and keeps its status as
  the go/no-go for content production.
- **FR-606** (blocked-action explanation) moves Phase 3 → Phase 2. It is the feature that makes
  the gate's comprehension question — *"why did that cast fail?"* — answerable.
- **Minimal character creation** (FR-202 core, FR-701 ancestry selection) moves Phase 3 → Phase 2,
  so the gate can test the ≥4 build archetypes the §3 metrics table demands.
- Phase 2's ceiling grows accordingly. Under V3 this matters: Phase 2 was already the largest
  engineering block at 70–100h.

### 2.4 V6 needs a Background designed

The refusal/center-holding identity moves off Kes'reth and onto a Background available to all five
ancestries. That Background does not exist yet and is now thesis-critical — it is how RESTORE, the
hardest and most central ending path, gets an identity at character creation. Phase 0's cut-list
item 3 (drop Kes'reth) survives unchanged and becomes genuinely cheap.

### 2.5 V8 confirmed, with a caveat worth watching

Companion personal quests are inside Phase 4's 120–180h. Three to five quests at FR-502 standard
(≥2 real outcomes, ≥1 ledger write, no pure fetch) is 30–50% of the ≥10 side-quest bar. The
estimate is accepted as-is, but companions remain absent from the cut list — under V3 they are
currently uncuttable by omission. Consider adding "companions 4–5 drop to 3" as a cut item.

---

## 3. Amendments required (NOT yet applied)

| Target | Change | Source |
|---|---|---|
| `docs/prd-chapter-one.md` line 14 | "15–25 hours" → "8–12 dense hours" | V9 |
| `soul-meter-crpg-design-doc.md` §8 line 157 | "15–25 hours" → "8–12 dense hours" | V9 |
| `docs/prd-chapter-one.md` FR-503 | Remove the embedded "(P1 for fast-travel)"; the FR is P0 throughout | V7 |
| `docs/prd-chapter-one.md` §7 | Phase 1.5 → Phase 2.5; move FR-606 and minimal creation into Phase 2 | V4, V5 |
| `docs/prd-chapter-one.md` §6 | New FR-350s block for the Definition/Paradox trees | V2 |
| `docs/prd-chapter-one.md` §1, G7, FR-801 | Standalone-episode framing; Mirror Shop and a Ch1 ending beat become required | V1 |
| `docs/phase-0-ratification.md` §8 | Re-estimate the table with V1/V2/V7; add per-phase hour ceilings | V3 |
| `docs/phase-0-ratification.md` §8 cut list | Refusal identity moves to a Background (item 3 unchanged); consider a companions cut item | V6, V8 |
| `soul-meter-crpg-design-doc.md` §10 Q12 | Strike — the chassis question is answered in §6 | housekeeping |
| `docs/playtest-protocol.md` | Retitle the gate Phase 2.5; add creation and tree-comprehension to the checks | V4, V5, V2 |

---

## 4. Still open

- **Which phase owns the FR-350s tree block** (§2.2).
- **The vault-vs-doc check.** `CLAUDE.md` records that the design doc predates the lore vault and
  that where they conflict — it names *Maiiam kidnapped* vs *withdrawing* — the vault wins. The
  design doc now marks the kidnapping **[CANON]** and Act III rests on it. Not re-verified against
  `~/projects/dramgid-vault/` in this pass.
- **Design doc §10 canon questions 1–11** remain open by design; none block Chapter 1.
