# Phase 0 — Ratification & Canon Sync (Ch1)

**Status:** RATIFIED · **Date:** 2026-08-03 · **Ratified by:** Adam (human, session decision)
**Closes:** GitHub #86 (⚑ ledger + canon write-back), #87 (hour estimate + three ratifications), #47 (gamepad)
**Governs:** `docs/prd-chapter-one.md` Appendix A (⚑ ledger), `soul-meter-crpg-design-doc.md` §4/§6/§7,
`docs/godot-architecture.md` open question #3, and the Dramgid vault `systems/` entities.

This document is the Phase 0 gate artifact. Every ⚑ in the PRD is resolved here. Nothing in
Phase 1 builds against an unratified item; anything marked **TUNABLE** below is a starting
value that Phase 2 playtesting may move without re-ratification, and anything marked
**⚑ REMAINS OPEN** is deliberately unresolved (design-doc §10 / vault `canon/open-questions.md`).

---

## 1. Ratified decisions (the eight structural calls)

| # | Question | Decision | Supersedes |
|---|---|---|---|
| D1 | Skill resolution model (FR-201/202) | **Hybrid — percentile surface, Ledger derives it.** `d100 ≤ effective%` is the one resolution path; the percentage is *derived* from the vault's Untrained/Trained/Expert tiers. | Nothing — reconciles PRD FR-201 with vault `character-creation.md` §Skills |
| D2 | Casting fuel vs. canon fact 8 (FR-302/309) | **Boundary model.** Breath is the per-scene casting pool; when Breath is exhausted and the caster commits anyway, the cost is drawn from the **Soul Meter** and does not come back. | Resolves the "resource split" reconciliation flag in vault `magic-system.md` §CRPG bridge notes |
| D3 | Advancement (FR-204) | **Point-buy on level.** No use-based drift. | Design doc was silent |
| D4 | Playable ancestries (FR-701) | **Vael, Kaan, Vaerin, Weftkin, Kes'reth** (5). | Vault `character-creation.md` §Races — Kes'reth leaning is NEW canon, written below |
| D5 | Respec (FR-907) | **Partial — one "Mirror Rewriting" per chapter.** Skill points only; ancestry, patron, Background, and Masteries are permanent. | PRD open item |
| D6 | Fast travel (FR-503) | **Yes, discovered hubs only, at a cost** (time passes / a resource is spent). | Design doc was silent |
| D7 | Gamepad at ship (FR-607 / arch doc Q3) | **Keyboard/mouse first.** Input map stays action-based; remapping ships per FR-607. Gamepad is post-Chapter-1. | `docs/godot-architecture.md` open question #3 — now ANSWERED |
| D8 | Playtime floor (G1) | **8–12 dense hours is the acceptance bar.** 15–25h is a stretch, never a requirement. | PRD G1 headline |

### D2 in detail — why the boundary model is canon-safe

Vault `magic-system.md` explicitly *declines* the Gauge→Breath split because it contradicts
canon fact 8 ("magic spends the Gauge, and it mostly only goes down") and Vervulling's
paired-expenditure Soul Gauge economy. The boundary model keeps fact 8 literally true:

- Routine casting inside your Breath spends Breath. Breath is scene-local and recovers.
- **Overreach** — casting past empty Breath — spends the Soul Meter, permanently, at the
  rate the tier demands. This is the only path from casting to Gauge loss, and it is a
  player choice made under a visible warning (FR-606).
- Luth and Mozh's Rule-Bends (FR-302) restore **Breath**, as specced. Nothing in the
  Elements & Music spec changes.
- Vervulling's doctrine reads correctly: paired expenditure keeps both casters inside
  Breath, so the *balanced* spend genuinely frays less. The Registry's observed-but-
  unexplained effect now has a mechanism.

---

## 2. Skill taxonomy (FR-202) — RATIFIED

Twelve skills, four per domain, each linked to one attribute. Taken directly from the vault's
sample-skills table; `Lore` stays **one** skill with tagged specializations (Age-of-Stars,
Registry Law, Old Tongue, Undertaking) rather than splitting into dead sub-skills.

| Domain | Skill | Governing attribute | Primary use surface |
|---|---|---|---|
| Body | Athletics | Forge | field traversal, zone shifts under pressure |
| Body | Stealth | Edge | field avoidance, opening ambush position |
| Body | Sleight of Hand | Edge | theft, trap disarm, battlefield item tricks |
| Body | Beast Handling | Forge | wilds encounters, non-violent beast resolutions |
| Mind | Lore *(tagged)* | Spark | **Defining Strikes**, dialogue gates, relic reading |
| Mind | Survival | Anchor | wilds travel cost, thinning-zone reading |
| Mind | Investigation | Spark | quest branching, evidence, read-backs |
| Mind | Alchemy | Anchor | consumables, Breath restoratives |
| Soul | Persuasion | Voice | dialogue, **speech-as-combat-verb** (FR-106) |
| Soul | Weft-Sensing | Pitch | reads local Agreement Integrity → shows true fizzle% pre-commit |
| Soul | Performance | Voice | ensemble/Tempo actions, social leverage |
| Soul | Insight | Pitch | detects lies, queued effects, hidden Contracts |

**Weft-Sensing is load-bearing:** it is the diegetic implementation of FR-205 ("checks surface
their numbers") for casting. Untrained casters see a fizzle *band*; trained ones see the number.

### Percentile derivation (D1)

```
effective% = (attribute × 8) + tier_bonus + advancement_points + situational_modifiers
```

- **Untrained** — tier_bonus `0`. (attr 2 → 16%, attr 5 → 40%)
- **Trained** — tier_bonus `+20`, bought at creation via the Background skill package or points.
- **Expert** — tier_bonus `+35`, **and** one reroll per scene on a failed check of that skill
  (the percentile expression of the vault's "reroll the worst die").
- **Chapter 1 cap: 95%.** 100% is not reachable in Ch1 — it stays a commitment, per FR-204.
- Resolution: roll `d100`; success on `roll ≤ effective%`. Roll happens **on commit**, after
  autosave (FR-905).

**Advancement costs (D3, TUNABLE):** points awarded at level-up; `+5%` costs **1** point up to
50%, **2** points from 50–75%, **3** points from 75–95%.

**Respec (D5):** the Mirror Rewriting refunds every advancement point ever spent and lets you
re-spend them. Tier purchases (Trained/Expert) and Masteries are untouched.

---

## 3. Fizzle table (FR-203) — RATIFIED, TUNABLE

The casting-side percentile. One formula, data-driven from Pandora, unit-tested in Phase 1.

```
base            = clamp(100 - agreement_integrity, 0, 100)
breadth_add     = { Tone: 0, Chord: +5, Triad: +12 }
strain_add      = { adjacent: 0, 2 steps: +6, 3 steps: +12, 4 steps: +18 }   # FR-305
magnitude_mult  = { Note: 0.5, Phrase: 1.0, Song: 1.75, Refrain: 2.75 }
pitch_reduction = max(0, (Pitch - 2)) × 2
fizzle%         = clamp((base + breadth_add + strain_add) × magnitude_mult
                        - pitch_reduction - mastery_reduction, 0, 95)
```

- **Mastery** zeroes `fizzle%` for one specific Note or Phrase (canon: Mastery is a Note/Phrase
  achievement — it does not reach Song/Refrain tier).
- **Fickah / Locksmirk floor:** never below **5%**, Mastery included (vault `ten-patron-classes.md`).
- Strained Chords additionally cost **Vär equal to the step distance** and land both Impositions
  weakened (FR-305, unchanged).
- Span > 2 steps is not a fizzle case — it is a **Clash** (self-inflicted Discord, FR-301), read
  per the span rule immediately below.

### The span rule (ratified 2026-08-03, resolving FR-301 vs FR-305)

FR-301 ("max 2-step span, wider = Clash") and FR-305 ("Strained Chords are castable at 2–4
steps") contradicted each other as written. Ratified reading:

- A **Triad**'s three elements must be **adjacent** — outer span exactly 2. A Triad whose
  elements span wider is a **Clash**. The 2-step cap is a statement about Triad structure.
- A **Chord** is two elements and may reach **2–4 steps** as a **Strained Chord**, paying raised
  fizzle (`strain_add`) and **Vär equal to the step distance**, with both Impositions weakened.
  Strained casting is the explicit, paid exception to the cap.
- **5 steps is the opposed pair** — always impossible, for any Breadth. No payment reaches it.
- Anything not covered above is a Clash.

Both original rules survive: the cap remains a real structural constraint, and FR-305's 3-step
and 4-step penalty tiers stay live rather than becoming dead data.

**Sanity readings** (these are the numbers the thinning gradient FR-506 is built to show):

| Zone | Integrity | Tone·Note | Chord·Phrase | Triad·Song |
|---|---|---|---|---|
| Vervulling core | 92 | 4% | 13% | 35% |
| Dom (starting town) | 85 | 7.5% | 20% | 47% |
| Thinning wilds | 70 | 15% | 35% | 73% |
| The Hush | 40 | 30% | 65% | **95%** (clamped) |

**Correction 2026-08-03 (post-implementation):** the Hush Triad·Song cell first printed **91%**,
which was an arithmetic slip — the formula gives `(60 + 12) × 1.75 = 126`, clamped to the 95
ceiling. The **formula is authoritative**; the table is a reading of it, never an override. The
implementation briefly carried a `sanity_readings` lookup that short-circuited the formula at
these named points; that path has been removed, and these readings are now asserted by
`test/unit/test_skill_check.gd` against the computed result. If a documented reading and the
formula ever disagree again, the document is wrong.

The pattern an attentive player reads: **in the Hush, only Notes are honest** — which is exactly
what `magic-system.md` says the Hush is. The Kit (always-on, physical) is unaffected everywhere.

---

## 4. The ten Triad-unique effects (FR-304) — RATIFIED, TUNABLE

Design rule enforced: **wider ≠ more damage; wider = structurally different capability.** None of
the ten deals damage. Each one buys a different structural verb, and each touches a different
subsystem, so no two Triads compete for the same slot in a build.

| Triad | Span → Center | Unique effect | Subsystem it bends |
|---|---|---|---|
| **Dayspring** | Zhur–Sul–Vel → Sul | **First Light.** All hidden state in the zone goes public for the round — enemy Aftertones, Discord signatures, queued effects, and every discovered weakness. Defining Strike checks cost no extra AP this round. | Information → tempo |
| **Fruiting** | Sul–Vel–Luth → Vel | **Second Season.** Every friendly buff currently active is *copied* onto one other ally; buffs cast this round land on two targets. | Buff propagation |
| **Rivermouth** | Vel–Luth–Khor → Luth | **The Mouth Opens.** Zone walls dissolve for one round: any combatant may change zone for 0 AP, and AoE shapes ignore zone boundaries. | Positioning (`BattlefieldModel`) |
| **Founding** | Luth–Khor–Tham → Khor | **Cornerstone.** Every active effect's remaining duration freezes — friend and foe — until the end of your next turn. | Duration / time |
| **Vault** | Khor–Tham–Vekh → Tham | **Sealed Ground.** Fortify one zone for the encounter: entering costs +1 AP, ranged attacks in suffer Weighted, and Aftertones anchored inside cannot be consumed by enemies. | Terrain authoring mid-battle |
| **Barrow** | Tham–Vekh–Mozh → Vekh | **Unlisted.** Your side's signatures, queued effects, and positions are hidden until they resolve; enemies cannot target your back zone this round and lose all reveal effects. | Information denial (mirror of Dayspring) |
| **Pyre** | Vekh–Mozh–Khash → Mozh | **The Rendering.** Every corpse, destroyed object, and expired Aftertone on the field converts at once to **Breath**, split across your side; enemies sharing a zone with a converted corpse take Decaying. | Mass resource conversion |
| **Cinderfall** | Mozh–Khash–Zhem → Khash | **Everything Burns At Once.** Consume *all* Aftertones on the field, both sides; each yields its burst to your side. | Aftertone economy cash-out |
| **Stillpoint** | Khash–Zhem–Zhur → Zhem | **The Held Silence.** The Balance Gauge is forced to exact center and locked there until the end of the next round; while locked, no order/chaos threshold effect can fire for anyone. | **Balance Gauge — the stabilizer/refusal payoff (FR-104)** |
| **Thunderhead** | Zhem–Zhur–Sul → Zhur | **Nothing Is Uncertain.** For one round your side skips the Instability die entirely, and one ally may act out of turn order. | Variance deletion + initiative |

Every element rules exactly one Triad and wings two, per FR-304. **Stillpoint** is the mechanical
answer to the PRD's requirement that the center-holding / refusal build be genuinely rewarded.

---

## 5. Vär and Zhavar — naming note (FR-306/308)

The PRD calls these **renames** ("Galm" → "Vär", "Carry"/"Overtone" → "Zhavar"). Checked against
the vault: **neither prior term appears anywhere in it.** These are therefore **additions**, not
renames — the harmony gauge and the zone-audibility ladder are new mechanical canon being written
into the vault for the first time by this ratification. No vault find-and-replace is required;
no existing entity contradicts them.

- **Vär (Harmony)** — personal scale, −5 (kesh) … +5 (sēl). Gates Breadth: Tone at any Vär;
  Chord at Vär ≥ 0 (or Solo with Mastery); Triad at Vär ≥ +2 (or Solo with highest Mastery +
  Refrain-tier Breath cost). Recoverable through *play*, not only story alignment (FR-306
  anti-build-lock rule). Tone is never gated.
- **Zhavar** — zone scale. Banking harmony raises local Agreement Integrity *and* how far the
  zone can be heard: low → rising → **tolling** (one Zhem dragon) → ringing (regional delegation)
  → unprecedented. Chapter 1 tracks and telegraphs it, with one scripted tolling event; dragon
  response is Chapter 2+.

Both are written into the vault as part of this gate (see §7).

---

## 6. Ancestries (D4) — the five, with Kes'reth as new canon

Four are straight from the vault's worked-examples table. **Kes'reth is new** and is the only
canon addition on the ancestry side:

| Ancestry | Leans | Minor trait | Source |
|---|---|---|---|
| **Vael** | Balanced | Extra skill point at creation (generalist) | vault, unchanged |
| **Kaan** | Forge / Anchor | Resistant to physical Discord; vulnerable to Mozh-adjacent effects | vault, unchanged |
| **Vaerin** | Spark / Pitch | Access to the **Fading** resource regardless of class | vault, unchanged |
| **Weftkin** | Pitch / Voice | Innate Weft-Sensing training (starts Trained) | vault, unchanged |
| **Kes'reth** *(Mirror-Veil)* | **Voice / Anchor** | **Mirrored Scars** — the health-for-memory exchange made mechanical: once per encounter, spend HP to negate one Discord-inflicted debuff. | **NEW — ratified here** |

Kes'reth's leaning is grounded in the Mirror-Veil physiology already in `peoples/kes-reth.md`
(mirror-bodied, reflective magic, health-for-memory exchange, paired/mirrored scars) and in the
Vow of the Unspoken Name. Voice/Anchor makes it the ancestry of the stabilizer archetype —
pairing naturally with **Stillpoint** (§4) and the Mirrorblade patron, and giving the
refusal/center-holding build an identity from character creation onward.

Per FR-701 each ancestry also carries a dialogue-reactivity package and a Wheel affinity *nudge*
(never a hard lock). Those are authored in Phase 3, not here.

---

## 7. Canon write-back performed by this gate

| Target | Change |
|---|---|
| `dramgid-vault/systems/elements-and-music.md` | **NEW entity** — the full Elements & Music spec (Breadth × Magnitude, the ten Impositions/Rule-Bends, composition algebra, the ten Triads and their unique effects, Strained Chords, Vär, Zhavar) |
| `dramgid-vault/systems/magic-system.md` | Resource-split reconciliation flag RESOLVED to the boundary model (D2); fizzle math tabulated (§3); links to the new entity |
| `dramgid-vault/systems/character-creation.md` | Percentile derivation (D1), advancement + respec (D3/D5), the five playable ancestries and the new Kes'reth leaning (D4) |
| `soul-meter-crpg-design-doc.md` | §4/§6/§7 amended to point at the ratified PRD spec; Balance Gauge / Defining Strikes marked [CANON, ratified] |
| `docs/godot-architecture.md` | Open question #3 (gamepad-at-ship) ANSWERED — keyboard/mouse first (D7) |
| `docs/prd-chapter-one.md` | Appendix A ⚑ ledger struck through with pointers to this document |

Vault `build_index.py` + `validate.py` are rerun after the edits; the gate is not passed until
both are green.

---

## 8. Person-hour estimate per phase (#87)

Human hours, **including** the mandatory Claude review pass on all delegated work — the review
bottleneck is the real constraint, not agent throughput (PRD §7 fleet-reality clauses).

| Phase | Person-hours | Notes |
|---|---|---|
| Phase 0 — Ratification | 8–12 | This session covers most of it |
| Phase 1 — Resolution spine | 40–60 | SkillCheck, fizzle, element algebra, Vär store, Pandora schemas, save envelope, CI |
| Phase 1.5 — Integrated slice gate | 20–30 | Assembly is cheap; recruiting and running 3–5 playtesters is not |
| Phase 2 — Combat vertical | 70–100 | Largest engineering block; the zones-vs-grid decision lands here |
| Phase 3 — Character & UI | 50–70 | Design-system extension gates the HUD work |
| Phase 4 — Region production | 120–180 | Review-bottlenecked; the whole cut list lives here |
| Phase 5 — NG+, polish, acceptance | 40–60 | Four full archetype playthroughs alone is ~15h |
| **Total** | **~350–510** | |

At **10 h/week → 35–51 weeks**. At **20 h/week → 18–26 weeks**. This is the number that makes
the cut list real rather than rhetorical.

### Pre-agreed cut list (invoked in phase order, top first)

1. All **P2** FRs — FR-110 spend side, FR-310 patron Kits, FR-506 thinning gradient, FR-605
   9-patch, FR-803 NG+ reactivity.
2. Side quests **11+** (floor of 10 is the FR-502 bar).
3. Ancestry #5 (**Kes'reth**) drops to four playable — it is the only new-canon one, so cutting
   it costs nothing already written.
4. Triads reduce from ten to the **five whose centers are the player's likely majors** (the other
   five become Chapter 2 content); the algebra still supports all ten.

**Never cut:** the consequence mandate (G5 / FR-403), the read-back audit (FR-501), failure-forward
design (FR-905), or the save envelope (FR-802).

---

## 9. ⚑ REMAINS OPEN (deliberately)

- Design-doc §10 canon questions — all eleven are Acts II/III; none block Chapter 1.
- Vault `canon/open-questions.md` — deliberate mysteries, untouched.
- `ten-patron-classes.md` §Open design threads (Fickah's floor scope, Ofshütje's random-table
  floor, counterplay vs. Sequenced Verdict, Vhorr's Hunger decay) — these are class-tuning
  questions that Phase 2 playtesting answers, not canon questions.
- Web export / GitHub Pages — **rejected** by the user 2026-08-02; not parked, dead.

---

*Gate status: all PRD ⚑ items resolved or explicitly deferred with a named owner phase. Phase 1
may begin.*
