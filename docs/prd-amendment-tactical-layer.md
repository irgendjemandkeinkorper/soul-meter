# PRD Amendment 1 — The Tactical Layer

**Status:** **RATIFIED 2026-08-05** — owner sign-off, with one item deliberately still open (§9.2)
**Date:** 2026-08-05 · **Owner:** Adam (solo dev)
**Amends:** `docs/prd-chapter-one.md` (RATIFIED 2026-08-03, zero ⚑) and
`soul-meter-crpg-design-doc.md` §7
**Source:** the `Elemental Architecture` design doc, rev 0.2, 2026-08-04 —
https://claude.ai/design/p/e9041b0a-90c3-43af-95c7-fe8bef3185fa
**Direction set by:** owner, 2026-08-04 ("full tactical redesign")

---

## 0. What this amendment is, and what it admits

This amendment retires two **ratified P0 requirements** — FR-102 (Action Point economy) and
FR-105 (Zones, not grids) — and replaces them with a charge-time turn order and a square grid
with elevation and facing.

**It pre-empts a gate rather than deferring one, and says so.** The ratified PRD is explicit:

> **The zones-depth question is settled HERE, not deferred to v2:** the gate playtest must
> demonstrate real positional tradeoffs (cover, range/reach, flank pressure, movement cost);
> if zones can't produce them, the grid decision escalates to the human immediately.
> — `docs/prd-chapter-one.md`, Phase 2 gate

The Phase 2 gate playtest has not been run. The grid is therefore being adopted on **owner
judgment, ahead of the evidence the gate was designed to produce** — not because zones were
tested and failed. That is a legitimate call for a solo dev with a clear vision, and it is
recorded here as what it is rather than relabelled as a settled question.

Because the evidentiary bar is being skipped, §5 below installs a **replacement gate with
equivalent teeth**. Retiring a gate and retiring its criteria are different acts; only the
first is intended.

---

## 1. FR dispositions

Every FR that names AP or zones by name gets an explicit disposition. Nothing is left to be
inferred from silence.

| FR | Was | Disposition |
|---|---|---|
| **FR-102** | Action Point economy; AP per round from attributes; eclipse-phase pips | **RETIRED** → replaced by FR-102a (charge time) |
| **FR-105** | Zones, not grids; front/back/flank behind `BattlefieldModel` | **RETIRED** → replaced by FR-105a (grid + elevation + facing) |
| **FR-103** | Defining Strikes, priced in **AP** | **KEPT, REPRICED** — CT premium on top of the base action cost |
| **FR-104** | Balance Gauge, per-battle order↔chaos axis | **KEPT, RE-HOMED** — see §3 |
| **FR-106** | Speech as combat verb | **KEPT, UNCHANGED IN INTENT** — needs a new interrupt contract, see §4 |
| **FR-601** | "UI shows AP as eclipse-phase pips" | **AMENDED** — pip language becomes CT language, see §6 |
| **FR-603** | Battle HUD: "initiative, AP, zones…" | **AMENDED** — superseded by the Elemental Architecture region model |
| **FR-606** | Blocked-action explanation — *which* system blocked and what would unblock | **KEPT, EXTENDED** — see §2.2 |
| **FR-108** | Encounter pipeline: "composition, **zone layout**, Balance bias, speech hooks" | **AMENDED** — zone layout becomes map/tile/elevation authoring |

### FR-102a (P0) — Charge-time turn economy

No team phases. Each tick, every unit gains CT equal to its Speed; a unit acts when **CT
reaches 100**. Moving costs 20, actions cost 30–60 by ability, waiting refunds. A full
**measure is 16 CT ticks**. The turn timeline is a projection of this arithmetic and must
never lie: the UI reads the scheduler's CT values, never a parallel estimate.

### FR-105a (P0) — Grid, elevation and facing

Square grid positioning. **Elevation 0–3**: melee requires `|Δh| ≤ jump`, arcs require
clearance, and height advantage adds +10% damage per step. **Facing**: FRONT ×1.00 / SIDE
×1.10 / BACK ×1.25, with hit bonuses +0 / +8 / +15. Positioning stays behind the
`BattlefieldModel` interface — the seam is retained, not retired (see §2).

### 1.1 All combat multipliers are PROVISIONAL — and the first sweep failed

Every number in FR-102a and FR-105a was transcribed from the Elemental Architecture doc. None was
validated against real damage curves. They are **PROVISIONAL** and must not harden into authored
content until a sweep is reviewed.

Run `godot --headless --path . --script res://tools/combat_number_sweep.gd`.

**Result of the first sweep (2026-08-05): the #133 gamble curve does not gamble.**

Expected turns-to-kill, fizzle included, at base power 42 / target HP 131 / base fizzle 15%:

| facing+elev | SAME | NEIGHBOUR | d2 | d3 | d4 | OPPOSED |
|---|---|---|---|---|---|---|
| FRONT+0 | 7.34 | 5.07 | 3.95 | 3.73 | 3.56 | **3.30** |
| BACK+3 | 4.52 | 3.12 | 2.43 | 2.30 | 2.19 | **2.03** |

**OPPOSED is the fastest expected kill in every row of the table.** The curve descends
monotonically from SAME to OPPOSED at every facing and every elevation. There is no distance at
which casting nearer is correct, so there is no decision — a player should simply always cast
opposed. The intent recorded in canon is *"near is safe and weak, opposed is a high-risk jackpot"*;
these values deliver "opposed is strictly better."

**Why a flat fizzle penalty cannot fix this by itself.** Damage is multiplicative (×1.35) while
`relation_add` is additive in percentage points, so the penalty's relative bite shrinks as base
fizzle falls. To make OPPOSED merely break even with distance 2 at 15% base fizzle,
`relation_add` at distance 5 would need to be about **+26**, not +15. In a thinning-wilds zone
(~40% base) break-even needs about +20. A single flat ladder cannot hold the tradeoff steady
across zones — which is itself an argument that the risk should not live entirely in fizzle.

### RESOLVED 2026-08-05 — the risk moved to Soul, and the structure now works

Owner ruled option 3: **a cast that reaches across the Wheel and fails spends Soul.** Nothing is
charged when it lands. Ladder (provisional): `0 / 0 / 1 / 2 / 3 / 5` by distance. Landed in the
vault at `magic-system.md` §"What a failed reach costs".

Re-running the sweep with the Soul term added:

```
--- IS IT A WAGER OR A RAMP? ---
  WAGER in all 12 rows: the fastest line is never also the cheapest.
```

**The structural problem is fixed.** Soul cost does not shrink as Agreement Integrity rises, so
the tradeoff holds steady across zones in a way the additive fizzle penalty could not.

**But the magnitudes now overshoot the other way, and this needs a second ruling.** At FRONT/flat,
distance 2 costs 3.95 turns and 1.05 soul; OPPOSED costs 3.30 turns and **7.07 soul**. That is
**0.65 turns bought for 6.02 soul** — and a heavy dialogue choice in this game costs about 6 soul.
An opposed cast is currently priced like a major moral decision for a marginal tactical gain,
which makes it a trap option rather than a wager. "Always take opposed" became "never take
opposed"; neither is a choice.

Two knobs, either works:

- **Halve the top of the Soul ladder** to roughly `0 / 0 / 0 / 1 / 2 / 3`. Cheapest fix.
- **Flatten `relation_add` fizzle** now that Soul carries the risk — say `+0/+1/+2/+3/+4/+5`.
  Opposed casts then land more often, so the Soul price is incurred less. This is arguably more
  correct: with two risk terms stacked, the fizzle ladder is now doing work it no longer needs to.

Left provisional deliberately — the numbers are tunable by play and the canon shape is settled.

---

**The three options as originally presented, retained as the record:**

1. **Steepen the fizzle ladder** to roughly `+0 / +5 / +11 / +16 / +21 / +27`. Cheapest; keeps
   the structure exactly as ratified. Still zone-sensitive.
2. **Flatten the damage curve** so distant casts are less rewarding. Changes the jackpot feel.
3. **Move the risk off fizzle entirely** — an opposed cast that fails costs **Soul Meter**, not
   just the turn. This is the most Soul-Meter-shaped answer: a gamble whose downside is a wasted
   turn is weak, a gamble whose downside is permanent is a real decision, and the game already
   has the currency for it. It also sidesteps the zone-sensitivity problem, because a Soul cost
   does not scale with Agreement Integrity.

**The canon shape survives all three.** The vault ratifies *damage rises with distance, fizzle
rises with distance, Vär flat* — that structure is intact and unchallenged. Only the magnitudes
failed, which is exactly what "PROVISIONAL pending the sweep" was written to catch.

**Confirmed separately:** the flagged stack is real. BACK × 2 elevation × OPPOSED measures
**×2.025**, matching the ×2.0 estimate; at 3 elevation steps it reaches **×2.194**, and the full
sweep spans ×0.50 to ×2.194 — a **×4.39 spread between the best and worst single hit**. Whether
that spread is intended is a separate ruling from the gamble-curve question above.

---

## 2. The asymmetry that governs sequencing

**This is the most important engineering finding behind this amendment, and it contradicts an
assumption in the ratified PRD's own risk table.**

The PRD's risk register frames combat-chassis change as insulated:

> **Combat depth vs. zones ceiling** — `BattlefieldModel` interface (FR-105) keeps grid swap
> possible in v2; playtest Phase 2 gate decides early.

That confidence is **correct for FR-105 and does not transfer to FR-102**:

- **Positioning is behind a real seam.** `globals/combat/battlefield_model.gd` documents it
  outright — consumers speak "opaque position/profile/shape APIs, so a grid can replace
  zones" — and `create_default()` is the only site naming the concrete type. Swapping zones
  for a grid touches the interface and its implementations, not the action pipeline.
- **AP is behind no seam at all.** `action_points` / `ap_cost` appear **34 times in
  `combat_controller.gd` alone** as inlined primitive ints — cost checks, deduction, refresh,
  event payloads, enemy-AI gating — and across nine other files: `battle_actor.gd`,
  `combat_rules.gd`, `combat_action.gd`, `battle.gd`, `battle_stage.gd`,
  `seed_phase_one_pandora.gd`, and three test suites.

**Consequence:** FR-105a is a cheap, revertible swap. FR-102a is a controller rewrite with a
materially higher reversal cost. Anyone reading the PRD's swap-cost confidence and applying it
uniformly to "the combat chassis" will underestimate the CT work specifically.

**Therefore:** the AP code path is **retained on a tag until the replacement gate passes.** Do
not delete AP call sites in the same change that introduces CT. Reverting after deletion means
re-deriving 34+ call sites from a PRD that no longer describes them.

**And note what "abort" actually means here.** Going AP → CT is a controller rewrite. Going
CT → AP afterwards is a *second* rewrite of the same magnitude, not an undo — there is no seam
to fall back through. Abort on the FR-102a side means committing to another rewrite, not
flipping a flag. Read §8's abort table with that asymmetry in mind: the grid row and the CT row
are not comparable.

### 2.1 Mandate — build the scheduler seam first

The reason FR-102 is expensive to retire is that it was never built behind an interface. Do not
reproduce that mistake in the replacement.

**The first implementation step of FR-102a is a thin scheduler interface**, mirroring
`BattlefieldModel`'s abstract-base + swappable-concrete pattern — *before* any CT logic is
inlined into `combat_controller.gd`. Every action obtains timing through that one contract; no
action mutates queue order, deducts a resource, or implements a private cooldown substitute.

This pays down exactly the seam debt that made this migration costly, so the *next* turn-order
change — CT → something else, or CT → AP on abort — is a swap rather than a rewrite.

**Verifiable:** a second concrete scheduler (a throwaway test-only implementation is fine) must
compile and pass the same determinism and interrupt tests as the production one. If it can't,
the seam isn't real.

**The controller must not remain the owner of action-specific timing rules.** `CombatController`
orchestrates the queue; it does not encode per-action timing. CT values are balance data, not
controller literals.

### 2.2 The refusal taxonomy must survive — FR-606

`BattlefieldModel._blocked()` returns `{allowed, blocked_by, nearest_unblock, message}`, and
`CompositionResolver` / `CastingGate` do the same for casting (`failure_id`, `blocked_by`,
`nearest_unblock`). That is a **typed "why was this denied" taxonomy**, and FR-606 mandates the
UI surface which system blocked an action and what would unblock it.

This is a design requirement, not incidental plumbing — it is the single mechanism the PRD
already promised for answering *"why did that fail?"*, which is one of the comprehension
questions the gate tests.

**The grid rewrite must preserve or re-derive it, with the new axes distinguished:**
blocked-by-elevation ≠ blocked-by-facing ≠ blocked-by-range ≠ blocked-by-occupancy ≠
blocked-by-CT-not-ready. Collapsing them into a generic "invalid move" loses the property.

**FR-606's own enumeration needs amending.** Its ratified text lists the blocking systems as
"(Vär, Breath, **AP**, span cap, Balance threshold)". AP is being retired, so that list becomes
**(Vär, Breath, CT, span cap, elevation, facing, occupancy, range, weather/Balance bias)**. This
is the one place an FR's *body text* names AP inline rather than in its title — easy to miss on a
disposition sweep that only reads FR headings.

### 2.3 The interface must grow, not just gain an implementation

`BattlefieldModel` is a real seam but **not a drop-in swap**. `position_of()` returns a
`StringName` (a zone id); the interface today has **no** API for cell coordinates, elevation,
facing, occupancy, line of sight, or path cost.

So FR-105a is cheap *relative to the CT rewrite*, not free. Expect to widen the interface —
deliberately, in one pass, with the concrete type still unnamed by consumers — rather than
encode a `Vector2i` inside a `StringName` to avoid touching the signature. Doing that would keep
the seam nominally intact while destroying what it is for.

---

## 3. FR-104 Balance Gauge — kept, and why cutting it was never cheap

The Elemental Architecture doc has no region for the Balance Gauge. That silence is not a
decision, and it is not a free one.

**The Balance Gauge is implemented and load-bearing.** `combat_controller.gd` carries
`_change_balance`, `_apply_balance_band`, `balance_lock_until_round`, and
`apply_balance_effect`; `CombatIdentityCatalog` supplies `balance_band` / `balance_effects`;
`ui/hud/balance_arcs.gd` renders it.

**It is consumed by the Elements system.** The **Stillpoint** Triad
(`globals/elements/elements_data.gd`) has a unique effect, *The Held Silence*, whose
parameters are `{"balance_gauge": "exact_center", "lock_until": "end_of_next_round",
"suppress_threshold_effects": true}` — resolved by `CombatController.apply_balance_effect()`.

> Cutting FR-104 does not delete an FR line. It breaks a shipped Triad.

**Disposition: KEPT, RE-HOMED.** The order↔chaos axis is re-expressed as a **global bias on
the weather / element-charge system** — order pulls the board toward predictability, chaos
toward volatility, applied on the same 16-tick measure as weather. The banding, threshold and
lock machinery is reused essentially verbatim; what changes is the *fiction* of the axis, not
its *mechanism*.

**Open risk, flagged for owner attention rather than resolved here.** With weather added, the
project would carry **four overlapping meter systems**: Weather (global, per-measure), Balance
(per-battle), Vär (personal, per-cast), Soul Meter (permanent). The ratified PRD's own risk
table already worried that three was near the complexity ceiling. Folding Balance into weather
brings it back to three and is part of why re-homing beats keeping them separate — but the
count should be re-examined at the §5 gate, not assumed fine.

---

## 4. FR-106 Speech — kept, with a new contract the old chassis did not need

Nothing in FR-106 references AP, zones, grid, or CT. It is the one FR-100 that is genuinely
chassis-agnostic, and `combat_speech_presenter.gd` / `combat_speech_option.gd` already work.

**But continuous CT removes a boundary that round-based AP provided for free.** Round-based
combat had an implicit "resolve the current turn, then check end conditions" seam. A
continuous CT queue has no such natural point. If a speech check can *end, split, or turn* a
fight mid-resolution, the scheduler needs an explicit answer to:

- Does CT freeze, or keep accruing, while a dialogue balloon is open?
- Is the acting unit's turn voided or completed when speech ends the battle?
- What happens to units already past CT 100 and queued to act?
- On a *split* (part of the enemy group leaves), how is the queue rebuilt without reordering
  units that have already banked CT?

**Disposition: KEPT.** FR-106 gains one new acceptance criterion at the §5 gate: speech
interrupt behaviour is tested against a mid-queue CT state, not only at a turn boundary.

**Cheap fallback if the interrupt contract proves intractable:** re-scope FR-106 to
pre-battle / post-battle / turn-boundary triggers only, dropping mid-queue interruption. That is
a spec cut, not an engineering rollback, and it preserves the FR's narrative purpose (fights
endable by talking) while removing the hardest ordering problem.

> **Correction to advisory input.** One provider asserted FR-106 is unbuilt and therefore free
> to re-scope. That is wrong: `ui/dialogue/combat_speech_presenter.gd`,
> `globals/combat/combat_speech_option.gd`, `CombatController.submit_speech()` and
> `test/unit/test_combat_speech.gd` all exist and pass today. Re-scoping FR-106 would discard
> working, tested code — treat it as a real cost, not a free out.

---

## 4.5 Boundaries — what this amendment does not touch

Stated in one place so a future reader (or a future agent session with no memory of this work)
can tell *"deliberately out of scope"* from *"forgotten."*

**Out of scope, deferred to a separate decision:**

- **Jobs vs the Ten Patron Classes (#132).** Recommended in §9.1, not resolved here. No
  combat-chassis code depends on the outcome — `globals/combat/` encodes no player class — so
  sequencing it after Gate T costs nothing.
- **NEIGHBOUR / SAME damage relations (#133).** A content-layer addition to the element wheel,
  not a chassis requirement. Adopting CT + grid does not require settling it, and conflating
  the two would make Gate T's pass/fail hostage to an unrelated design debate.
- **Vär and the Soul Meter.** Both are referenced in §3's meter count; neither changes. This
  amendment touches the *battle-scope* meter (Balance) only.
- **HUD work beyond CT and tile-charge legibility.** §6 covers `eclipse_pips.gd` because the
  AP → CT swap directly implicates it. No other HUD element is in scope; the Elemental
  Architecture region model is tracked separately in GitHub T2.

> **Settled 2026-08-05 — the Wheel is HYBRID, and this supersedes any "overlay in combat" text.**
> An **inline act-wheel in combat**, upholding "nothing is hidden in a submenu" where pacing
> matters; a **pause overlay for out-of-combat spell management**, where it does not. Both
> presentations exist and neither is a fallback for the other. GitHub #127 closed on this basis.
> Where the DS companion doc (`Godot UI Spec.md` §3, "Spell Wheel overlay… this is the pause")
> reads as though the overlay is the combat presentation, it describes the out-of-combat case
> only. The canon constraints on the Wheel itself are unchanged in both: closed set of ten,
> canon order, adjacency = Chord, diametric = Clash, read from `ElementWheel.ORDER`.
- **Enemy AI retuning.** Elevation, facing and CT change what good play means. Gate T requires
  the five encounters be *clearable*, not that difficulty matches the AP/zone curve. A harder
  or easier feel is a tuning finding to record, not a gate failure by itself.
- **Co-op / multiplayer serialisation of grid + CT state.** `CLAUDE.md` records co-op as a live
  maybe with a `StateChartSerializer` constraint. Gate T covers single-player save/load
  round-trip only. **Co-op compatibility of CT scheduling is not evaluated and must not be
  assumed.**

**Hard limits this amendment has no authority to move:**

- The vault remains fiction source-of-truth. Nothing here amends it.
- The Wheel of Ten stays closed and canon-ordered.
- Pandora stays canonical; generated artefacts stay generated.
- `CombatEvent` remains the only combat input to presentation.
- **FR numbering must not collide.** New requirements are **FR-102a** and **FR-105a**. They are
  *not* FR-107/FR-108 — those numbers are already taken by consequence-permanence and the
  encounter pipeline, and one advisory draft reused them by mistake.

---

## 5. Replacement gate — the teeth that replace the Phase 2 gate

The retired Phase 2 gate required: *5 archetype encounters (demon / undead / mixed whipsaw /
speech-winnable / stabilizer-showcase) playable and integration-tested; the four build
archetypes each clear them.* That bar is restated for the new chassis, plus the items the new
chassis introduces.

**Gate T — Tactical vertical slice.** Content production does not resume until all of:

1. **The original five archetype encounters** (demon / undead / mixed whipsaw /
   speech-winnable / stabilizer-showcase) are playable on grid + CT and integration-tested,
   and **the four build archetypes each clear them**. That count is carried over *unchanged* —
   it is the one number in the retired gate that had nothing to do with AP or zones
   specifically, so lowering it here would be gate erosion rather than adaptation. The
   stabilizer-showcase encounter must still reward the centre-holding build; that is the
   FR-104 re-homing's real test.

2. **Falsifiable positional-depth test — the inverse of the clause it replaces.** The retired
   gate asked *"can zones produce real positional tradeoffs?"* with a pre-committed escalation
   if the answer was no. The replacement asks the mirror: **grid + elevation + facing must
   produce a tradeoff that zones could not have given for free** — at least one encounter is
   meaningfully harder or unwinnable without exploiting height or facing. *If the grid cannot
   demonstrate that, the grid was the wrong trade, and that escalates to the human
   immediately.* A gate that cannot fail is not a gate.

   > **OWNER AMENDMENT (2026-08-24, #169):** after four runs (evidence:
   > `docs/gate-t2-evidence.md`), the binary victory/defeat clause is amended to: positional
   > victory AND (naive defeat OR naive loses a party member while positional loses none with
   > an HP differential ≥ 50% of max party HP). Criterion 2 is **PASSED** under run 4
   > (`phase2-undead`, selected by a pre-registered blind rule: 48/54 HP & 2 alive vs 15/54 &
   > 1 alive). The amendment is post-hoc and recorded as such.

3. **All three orphaned P0s demonstrably work:** a Defining Strike resolves at its CT price;
   the Balance axis visibly changes the board through weather bias; a speech check ends a
   fight from a mid-queue CT state without corrupting the timeline.

4. **CT-queue integrity under load** *(new — AP had no ordering ambiguity, so this gate did not
   previously need to exist)*. With ≥8 combatants queued, across 3+ consecutive battles: no
   turn-order deadlock, no double-resolution, no dropped interrupt.

5. **Speech-interrupt determinism** *(new)*. A speech check that ends a battle mid-queue leaves
   zero orphaned queued actions and zero half-applied status effects, and a save taken
   immediately after reloads to identical state. The gate does not accept §4's prose promise —
   it demands a reproducible test.

6. **Comprehension holds.** 3–5 outside playtesters complete the slice unaided and can answer
   *"why did that cast fail?"* and *"what does this gauge do?"* — plus two questions the
   tactical layer makes necessary: **"who acts next, and why?"** (CT legibility) and
   **"explain what just happened on that tile"** (charge/residue/detonation legibility).
   **Pass threshold: a majority of playtesters answer each of the four questions correctly** —
   per question, not averaged across them. Averaging lets one well-understood system carry a
   badly-understood one, which is the exact failure the complexity budget exists to catch.
   *"Why did that cast fail?"* is answered by the FR-606 refusal taxonomy in §2.2; if that
   taxonomy was collapsed, this criterion fails by construction.

7. **Determinism.** The same encounter, seed and inputs produce identical results; forecast
   output equals resolution output with writes disabled.

8. **Save/load.** Every new state survives a round trip: grid position, facing, elevation, CT,
   tile charge, weather phase.

9. **Performance.** FR-904's floor still holds with a populated grid and per-tile charge
   rendering.

10. **Migration completeness.** `grep -c 'action_points\|ap_cost' globals/combat/combat_controller.gd`
    returns **0**, or every remaining hit sits inside a documented compatibility shim with a
    removal ticket. A rewrite that leaves dead AP fields beside new CT fields is an incomplete
    migration wearing a "done" label.

**Every criterion above is binary and externally observable.** Each either passed or it did not,
and someone other than the author can check which. That is the whole selection rule.

### 5.0 Which criteria actually need outside humans

Audited 2026-08-05, because playtester recruitment reads like it gates everything and does not.

| Criterion | Needs outside humans? | How it is actually evidenced |
|---|---|---|
| 1 five encounters × four archetypes | No | Integration tests plus self-play for clearability |
| 2 positional-depth | **Borderline** | Scripted AI comparison can demonstrate it; a human read is more convincing, not required |
| 3 three orphaned P0s | No | Headless |
| 4 CT-queue integrity | No | Headless, ≥8 combatants |
| 5 speech-interrupt determinism | No | Headless + save/load assert |
| **6 comprehension** | **YES** | 3–5 outside playtesters. The only hard requirement. |
| 7 determinism | No | Fixed seed, headless |
| 8 save/load | No | Round-trip test |
| 9 performance | No | `scripts/benchmark_performance.sh` already exists |
| 10 migration completeness | No | Literally a grep |

**Exactly one criterion requires people who are not the author.** The meter-count question that
used to need them moved to §5.1, and when it is asked it folds into criterion 6's session — the
same sitting, one extra question, not a second recruitment round.

Practical consequence: recruit 6–8 to net 3–5 after dropout, and frame the ask as *"one
45-minute encounter and five questions"* rather than "playtest my game." Sources in rough order
of yield: genre-playing friends, local game store, Break My Game (Discord),
r/tabletopdesign or a genre subreddit, itch.io playtest calls.

### 5.1 Watch list — tracked, not gating

Two former criteria are moved here (owner decision, 2026-08-05). They were the two that could
not be stated as a clean pass/fail, and a criterion that needs a judgement call is a discussion,
not a gate.

- **Stillpoint regression.** *The Held Silence* must still lock the re-homed axis to centre and
  suppress threshold effects, verified by the existing Triad test **ported forward unmodified —
  same assertions, same expected outputs**. A passing test with *rewritten* assertions does not
  count; that hides a behaviour change behind a green tick.
  → **Entry criterion for T2.** It is a regression check on shipped code, so it belongs where the
  work that could break it happens, not at the end.
- **Meter-count re-score.** The risk table's gauge-soup row is re-scored with **four** systems
  present (Weather, re-homed Balance, Vär, Soul Meter) rather than silently inherited at its old
  three-meter rating.
  → **Entry criterion for T2.** Observability, not a gameplay outcome.

**Correcting an error in the previous version of this section.** It carried a note saying
criteria 6 and 7 could be "time-boxed into spikes" under schedule pressure, while also asserting
that criteria 1, 2 and 5 were "not negotiable." That was an escape hatch dressed as rigour: a
gate whose criteria can be downgraded when inconvenient is not a gate, and nothing enforced the
negotiable/non-negotiable split. The two soft criteria are now off the gate entirely and tracked
as T2 entry criteria. The remaining ten are all binary. There is no time-boxing clause.

**Phase 1.5 (#93) is superseded by Gate T, not cancelled.** Its slice text explicitly exercises
"AP + at least one Defining Strike + zone facing + Balance Gauge" — three of those four no
longer exist as written. Running it against a chassis being replaced would buy little; deleting
it would leave content production ungated. Gate T inherits its go/no-go authority and its
outside-playtester requirement.

---

## 6. FR-601 and `eclipse_pips.gd`

FR-601's prose ("UI shows AP as eclipse-phase pips") must change regardless. The component is
cheaper to keep than the FR text suggests: `ui/hud/eclipse_pips.gd` is a pure view over two
ints (`current_ap`, `maximum_ap`) with no AP-specific logic — it draws filled vs occluded discs
and encodes availability by fill as well as colour, so it is accessible by construction.

**Disposition:** repurpose the eclipse motif for **CT progress toward 100**. The eclipse phase
maps more naturally onto "how close am I to acting" than it ever did onto discrete AP, which
*strengthens* FR-602's one-visual-grammar goal.

**Do not assume a drop-in rename.** CT is continuous; the current `_draw()` renders N discrete
discs. Either the component becomes a filling disc (a percentage), or discrete pips are kept as
a deliberate stylisation of continuous CT (e.g. 10 pips × 10 CT). Budget for a `_draw()`
rewrite; keep the accessibility property that state never depends on hue alone.

---

## 7. Design frame (resolves #111)

Three sources disagreed. Verified state before this amendment:

| Source | Value |
|---|---|
| `Godot UI Spec.md` / all mockups | 1920×1080, `canvas_items`, aspect `keep` |
| `project.godot` | 1280×720, `canvas_items`, aspect **`expand`**, min 960×540 |
| `design/DESIGN_SYSTEM.md` | "fixed-frame 1440×900 thinking" |

**1440×900 is not a midpoint — it is a different shape.** 1440×900 is 16:10; the other two are
16:9. There is no clean multiplier between it and either candidate, so keeping it as
authoritative guarantees translation errors. It is treated here as stale prose from before the
mockups were re-authored.

**Decision: 1920×1080 is the canonical design frame.**

- `project.godot`: `viewport_width=1920`, `viewport_height=1080`, `stretch/mode="canvas_items"`,
  `stretch/aspect="keep"`.
- The **1280×720 window override is retained** for convenient development — a launch-window
  size, not a design frame.
- `min_width=960` / `min_height=540` retained; still a defensible floor (exactly 50% of the new
  base).

> **Gotcha, verified 2026-08-05.** `window/stretch/aspect="keep"` **will not appear** in
> `project.godot` — `keep` is the Godot 4 default, so the engine strips the line on import. The
> previous `"expand"` was visible only because it was non-default. Confirmed live via
> `ProjectSettings.get_setting("display/window/stretch/aspect")` → `keep`. Do not "fix" its
> absence by re-adding it; it will vanish again on the next import.

**Translation rule.** Mockup pixel values map **1:1** to `ds.gd` constants and scene layout at
1920×1080. No manual division is ever applied to a spec value. At runtime Godot applies one
uniform scale `s = min(window_w / 1920, window_h / 1080)` — `s = 2/3` at 1280×720. Accessibility
text scaling stays independent of this conversion.

**Accepted trade-off:** `keep` letterboxes non-16:9 displays where `expand` filled them.
Switching back to `expand` remains possible later, but only after safe-area behaviour is
designed and tested rather than inferred from fixed-frame mockups.

---

## 8. Reversibility and abort criteria

Written down now rather than discovered later. Reversal cost rises sharply after the third row.

**The two axes abort independently and must be tabled separately.** §2's asymmetry is not a
footnote on one shared table — it changes which system you revert. A single phase row saying
"the compatibility layer failed" cannot tell you whether to discard working grid work because CT
broke, and the likely failure mode is exactly that (grid has a seam, CT does not).

**Axis A — positioning (FR-105a: zones → grid)**

| Phase | Reversal cost | Abort criterion |
|---|---|---|
| Interface widening + `GridBattlefieldModel` | **Low** — a sibling implementation behind `create_default()`; no `CombatController` change | Stop if the interface cannot express cells/elevation/facing/occupancy/LOS/path-cost without consumers learning the concrete type |
| Grid vertical slice | **Low–medium** — grid code is discardable; the zone model is untouched | **Gate T criterion 2** fails (grid produces no tradeoff zones couldn't) **and** a second playtest confirms it — never abort on one noisy sample |
| Grid map / encounter production | **High** — elevation maps, AI tuning, residue puzzles become sunk content | Do not enter until Gate T passes |

*Reverting Axis A = selecting `ZoneBattlefieldModel` in the factory again. The widened interface
stays; zones simply don't use the new queries.*

**Axis B — turn economy (FR-102a: AP → CT)**

| Phase | Reversal cost | Abort criterion |
|---|---|---|
| Scheduler seam (§2.1) | **Low** — new code, nothing removed | Stop if a second throwaway scheduler cannot pass the same determinism/interrupt tests — the seam isn't real |
| CT authoritative, AP retained | **Medium** — AP paths still present and tagged | Gate T criterion 4 (queue integrity) fails twice consecutively, **or** criterion 5 (speech interrupt) cannot be made deterministic within the phase timebox |
| AP removal | **HIGH — and not symmetric** | Do not remove until Gate T passes in full |

> **Axis B's reversal is not an undo.** Going AP → CT was a controller rewrite across 34 inlined
> sites. Going back is a *second* rewrite of equal size, because there was never a seam to fall
> through — that is why §2.1 mandates building one now. **Aborting Axis B after AP removal means
> committing to another rewrite, not flipping a flag.** Before AP removal, reversal is
> medium-cost; after, it is the most expensive move in this amendment.

**Shared — content production**

| Phase | Reversal cost | Abort criterion |
|---|---|---|
| Broad content conversion | **Very high** — reverting discards authored tactical content | Treat failure here as scope reduction *within* grid + CT, not chassis reversal |

**Reading rule.** When Gate T fails, first attribute the failure to an axis. **Criterion 2** is
Axis A. **Criteria 4, 5 and 10** are Axis B. **Criterion 3** carries FR-104's re-homing, whose
reversal is low–medium on its own: `apply_balance_effect`'s contract does not change, only what
feeds its inputs, so reverting restores the axis's ownership without touching Triad code.
**Criteria 1, 6, 7, 8 and 9** are joint and require attribution before any revert.

**Parallel run is test-only.** Select `ZoneBattlefieldModel + AP` or `GridBattlefieldModel + CT`
through the factory, run the same deterministic fixtures, compare semantic outcomes. Shipping
both HUDs and both rule sets would double QA and confuse saves.

### 8.1 Stop-loss rules

- **No phase begins until the previous phase's rollback has been *demonstrated*, not merely
  documented.** A rollback path nobody has executed is a hypothesis.
- **AP compatibility is not removed in the same change that first makes CT authoritative.**
  Zone compatibility stays available through grid acceptance; its carrying cost is low.
- **Once the controller rewrite starts, report it as a controller rewrite.** It is not an
  AP-to-CT rename and must not be scheduled or described as one.
- **Any evidence of dual authority is a release blocker, not technical debt** — two sources of
  truth for turn order (AP *and* CT), for position (zone *and* grid), or for global bias
  (Balance *and* weather). Pick one authority per axis; the other is a compatibility shim with
  a deletion ticket.
- **New content must not acquire dependencies on retired concepts.** No encounter, ability or
  save written after this amendment may reference AP or zones except through a shim.

---

## 9. Still open — owner decisions this amendment does NOT make

Two canon questions remain deliberately unresolved. Per `CLAUDE.md`, canon is not resolved
silently, and adopting a design doc does not authorise overwriting the vault.

### 9.1 The three jobs vs the Ten Patron Classes — GitHub #132

The vault defines ten classes, each bound to a named patron with a patron-specific resource
(River-Mother's Name-Ledger refunds Soul Gauge — "being remembered restores the Gauge" made
literal; Locksmirk never reaches 0% fizzle). These are load-bearing counterweights to the
Waning's fizzle pressure, not flavour.

Elemental Architecture invents three unpatroned jobs: Chordblade, Terrashaper, Hushwarden.

**Recommendation (advisory consensus, not ratified):** adopt them as a **base tier that is not
a class**. Call them **combat disciplines** (or *foundations*) — the discipline governs
movement, reach, elevation and baseline tactical verbs; **Patron remains the class** and
governs Kit, signature Resource and theology. This preserves all ten, gives a legible level-1
on-ramp for a character who has not yet earned a god-bond, and matches the vault's own framing
that classes are *earned* theological commitments.

**It still requires a narrow vault amendment** describing the layering and when Patron
selection happens — claiming "no canon change" would be dishonest.

**Nothing in `globals/combat/` currently encodes any player class or job system**, so no option
has a code head start. This is a pure design decision; sunk cost should not bias it.

**Abort criterion if adopted:** before authoring abilities, complete a 3 × 10 compatibility
sheet. If any patron cannot use every discipline without a bespoke exception, or if a
discipline displaces a patron's signature loop, stop and use direct mappings instead. Reversal
is cheap while this is schema and prototype data only; it becomes expensive once companion
dialogue, animations and save IDs encode the dual layer.

### 9.2 NEIGHBOUR and SAME entering canon — GitHub #133 — **DECIDED 2026-08-05**

> **Resolved: canon, as a full wheel-distance gamble curve.** Damage *and* fizzle both scale
> with distance; Vär stays flat on this axis. Near-element casts are safe and weak, opposed
> casts are high-risk jackpots. Landed in the vault at
> `systems/magic-system.md` §"Target relation — the gamble curve".
>
> | Distance | 0 SAME | 1 NEIGHBOUR | 2 | 3 | 4 | 5 OPPOSED |
> |---|---|---|---|---|---|---|
> | Damage | ×0.50 | ×0.75 | ×1.00 | ×1.10 | ×1.20 | ×1.35 |
> | Fizzle | +0 | +3 | +6 | +9 | +12 | +15 |
>
> **Values PROVISIONAL pending the §7 sweep; the shape is canon.**
>
> **One structural choice was made in writing this up, and it is not from the decision doc:**
> `relation_add` attaches **outside** the magnitude multiply, in percentage points, beside
> `pitch_reduction` / `mastery_reduction`. Inside the parenthesis, a 4-step Triad into an
> opposed target at Refrain reads `(+18 +15) × 2.75 = +91`, pinning every high-magnitude cast
> to the 95% clamp and erasing the gamble. Flag if that reading is wrong.
>
> **Unblocks #136.** The analysis below is retained as the record of why the two-axis
> separation is mandatory.

The vault knows **Chord** (adjacency) and **Clash** (opposition) and prices wheel distance as a
*cost*: `strain_add` (adjacent 0 / 2 steps +6 / 3 steps +12 / 4 steps +18) is a term inside the
**fizzle-probability** formula, and `composition_resolver.gd` mirrors this faithfully —
`_resolve_chord()` sets `var_cost = distance_steps` and flags `fizzle_requested`. Strain never
touches damage.

Elemental Architecture adds **NEIGHBOUR ×0.75** and **SAME ×0.50** as *target-side damage
multipliers*.

**Do they double-count? Not arithmetically — today.** They sit on different axes: the ladder
prices *whether the cast lands*, the matrix prices *how much it hurts once it does*. Element
relation is currently not a damage multiplier anywhere in the codebase
(`CombatController.calculate_damage()` is pure stat arithmetic).

**But this is the highest-probability silent bug in the whole migration.** Both systems key off
the same 10-element wheel and use near-identical language ("adjacent" / "neighbour"). An
implementer reading both specs can easily apply a fizzle penalty *and* a damage penalty for the
same one-step gap — taxing adjacency twice under two names. A caster choosing an adjacent
element would then pay higher fizzle risk **and** a damage cut **and** get no breadth bonus:
three downward pressures on one fictional idea, making off-tone attacks strictly bad, which
directly contradicts the vault's design law that *wider is not stronger, wider is different*.

**Binding constraint if adopted** — these must be two named, independently-tested stages that
**never share a lookup table or a `distance` variable**:

- **Compose time** (caster-side, no target known): `strain_add` → fizzle%; `var_cost` → Vär.
  `CompositionResolver.resolve()` takes `elements, magnitude, caster_context` and has **no
  target parameter at all** today. That is the boundary.
- **Resolve time** (target-side): the matrix multiplier, applied post-hit.
- **CHORD ×1.15 is caster-side** and multiplies orthogonally against the target-side term:
  `final = base × chord_bonus × target_relation`. Easy to implement wrong; test it explicitly.

Whoever ratifies this should also produce a single reconciliation table showing, for wheel
distance 0–5, what happens to (a) fizzle%, (b) Vär cost, (c) damage multiplier. Without it,
someone will eventually implement them additively.

---

## 10. Ratification

**RATIFIED by the owner on 2026-08-05.** FR-102 and FR-105 are superseded as of this date;
`docs/prd-chapter-one.md` §6.1 is amended accordingly. Implementation may proceed on the whole
amendment: §9.2, the last open gate, was decided the same day.

| Item | Status |
|---|---|
| §1 FR dispositions | **RATIFIED 2026-08-05** |
| §2.1 scheduler seam mandate | **RATIFIED** — owner: *"keep scheduler seam mandate, we may pivot again still."* The stated reason is future pivots, so the seam is justified by optionality, not by CT specifically |
| §2.2 FR-606 refusal taxonomy | **RATIFIED** |
| §5 Gate T | **RATIFIED**, then **TRIMMED 2026-08-05** — 10 binary, externally observable criteria. Stillpoint regression and the meter-count re-score moved to §5.1 as T2 entry criteria; the time-boxing escape hatch is removed, not relocated |
| §7 design frame | **APPLIED** 2026-08-05 — resolves #111 |
| §8 abort criteria | **RATIFIED** — two axes, attribution before revert |
| §9.1 disciplines vs classes | **DECIDED 2026-08-05** — owner adopted combat disciplines with Patron remaining the class. Vault amendment required; see #132 |
| §9.2 NEIGHBOUR / SAME | **DECIDED 2026-08-05** — canon as a full wheel-distance gamble curve; see §9.2 for the table. Values PROVISIONAL, shape canon. #133 closed |

### 10.1 What §9.2 blocked, and what released it

**Superseded 2026-08-07.** This section previously read "`element_matrix` authoring (#136) stays
blocked." That was correct when written and stale within hours: #133 was decided and closed on
2026-08-05, the same day this amendment was ratified, and §9.2 was updated to say so while this
section was not. For two days the document told a reader of §9.2 to proceed and a reader of
§10.1 to stop. **§9.2 is the live text; #136 is unblocked.**

Two constraints from the blocked period survive the decision, because they are properties of the
design and not of the wait:

- **The two axes must never share a lookup table or a `distance` variable.** `strain_add` prices
  the caster's composition span and needs no target. `relation_add` prices the target. Both apply
  to the same cast, they are never the same number. See §9.2 for why stacking them makes off-tone
  attacks strictly bad, contradicting *wider is not stronger, wider is different*.
- **Never guess a multiplier.** If a term is needed before its value is ratified, stub it as an
  explicit identity multiplier (×1.00) with a `TODO`, never as a plausible number. A guessed
  multiplier that ships is a balance decision made by accident.

---

## Appendix — provenance

Drafted from a four-provider advisory pass (Codex `gpt-5.6-sol`, Claude Sonnet, Copilot;
Gemini timed out on rate limits and contributed nothing). Providers were advisory only and did
not edit files. Convergence was high on all five questions; no debate gate was triggered.

Findings that came from reading the code rather than the design doc, and that changed this
amendment's shape: the AP-vs-positioning seam asymmetry (§2), the Stillpoint Triad's dependency
on `apply_balance_effect` (§3), the CT-queue interrupt gap for speech (§4), the four-meter
count (§3), and the 16:10-vs-16:9 mismatch that identifies 1440×900 as stale (§7).

### Validation pass (2026-08-05)

The draft was reviewed by a second advisory pass against the repo. Every technical claim it
checked verified true: the 34 AP hits in `combat_controller.gd`, the nine other AP-touching
files, `apply_balance_effect` at `combat_controller.gd:232` reached from a `stillpoint` fixture
in `test/integration/test_combat_controller.gd`, `eclipse_pips.gd` as a pure two-int view,
`create_default()` as the sole concrete-type reference, and the speech files the amendment used
to correct an earlier provider error. No ratified FR was found dropped by silence.

Four defects it found, all fixed above:

1. **§8's abort table conflated the two axes** — it warned verbally that grid and CT are not
   comparable, then tabled them as shared phase rows, so "which system failed → which do I
   revert" was unanswerable. Now split into Axis A / Axis B with an attribution rule.
2. **FR-604 was listed as amended** but is the character-sheet/Wheel FR, unrelated to the combat
   chassis. Removed from the disposition table.
3. **Gate T criterion 8 had no pass threshold** while criterion 7 did. Now majority-per-question,
   explicitly not averaged.
4. **The FR-606 refusal taxonomy was missing entirely** — `BattlefieldModel._blocked()` returns
   `{allowed, blocked_by, nearest_unblock, message}`, which is the mechanism behind the gate's
   own *"why did that fail?"* question. Added as §2.2, plus §2.3 on the interface needing to
   grow rather than smuggle coordinates through a `StringName`.

The one soft spot this pass left open — §5's "On gate weight" note authorising time-boxing of two
criteria under schedule pressure — was **closed by owner decision on 2026-08-05**. Those two
criteria are now T2 entry criteria in §5.1 rather than downgradeable gate items, and the
time-boxing clause is gone. The gate is 10 criteria, all binary, all checkable by someone other
than the author.

Note the criterion numbering changed with that trim: cross-references in §8's reading rule and
§10's table were updated to match. Anything citing "criterion 12" or "criteria 6 and 7" from an
earlier revision is stale.
