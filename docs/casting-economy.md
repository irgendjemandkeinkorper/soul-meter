# Casting Economy Numeric Sweep

This document is a pure numeric-verification and proposal artifact for the Soul Meter
casting economy. It does not change any runtime behavior. All numbers in Part (b) are
**PROVISIONAL** and are not ratified canon.

---

## (a) Verification table — ratified fizzle formula

The ratified formula from `globals/skill_check.gd` / `globals/fizzle_table.gd` is:

```
base            = clamp(100 - agreement_integrity, 0, 100)
breadth_add     = { Tone: 0, Chord: +5, Triad: +12 }
strain_add      = { adjacent: 0, 2 steps: +6, 3 steps: +12, 4 steps: +18 }
magnitude_mult  = { Note: 0.5, Phrase: 1.0, Song: 1.75, Refrain: 2.75 }
pitch_reduction = max(0, (Pitch - 2)) * 2
mastery_reduction = 0 for these readings
fizzle%         = clamp((base + breadth_add + strain_add) * magnitude_mult
                        - pitch_reduction - mastery_reduction, 0, 95)
```

Naming (#329): the quantity `agreement_integrity` above is now called **Harmonic Accord**.
The rename is a rename only — no number in this document moves. The fizzle context key is
`harmonic_accord`, with `agreement_integrity` accepted as an alias for one wave; the ratified
formula's own parameter names in `globals/skill_check.gd` keep their original spelling
deliberately, so the readings below stay verifiable against the code that produced them.

The implementation rounds to the nearest integer, with the documented display
convention: small Note values round upward, while larger Song/Refrain values
truncate. The sanity readings below use `strain_steps = 0`, `pitch = 2`, and
`mastery = false`, so `strain_add`, `pitch_reduction`, and `mastery_reduction`
are all zero.

### Vervulling core — Integrity 92

`base = clamp(100 - 92, 0, 100) = 8`

| Breadth | Magnitude | Arithmetic | Raw | Rounded | Ratified |
|---|---|---|---|---|---|
| Tone | Note | `(8 + 0 + 0) * 0.5` | 4.0 | 4 | **4%** |
| Chord | Phrase | `(8 + 5 + 0) * 1.0` | 13.0 | 13 | **13%** |
| Triad | Song | `(8 + 12 + 0) * 1.75` | 35.0 | 35 | **35%** |

### Dom (starting town) — Integrity 85

`base = clamp(100 - 85, 0, 100) = 15`

| Breadth | Magnitude | Arithmetic | Raw | Rounded | Ratified |
|---|---|---|---|---|---|
| Tone | Note | `(15 + 0 + 0) * 0.5` | 7.5 | 8 | 7.5% doc / **8%** code |
| Chord | Phrase | `(15 + 5 + 0) * 1.0` | 20.0 | 20 | **20%** |
| Triad | Song | `(15 + 12 + 0) * 1.75` | 47.25 | 47 | **47%** |

**Discrepancy note (Dom Tone·Note):** `docs/phase-0-ratification.md` §3 prints this cell as
**7.5%**, but `SkillCheckService._round_fizzle()` rounds every result to a whole percentage —
for the Note tier a `.5` fraction rounds *up* (only Song/Refrain truncate a `.5`), so the actual
implementation returns **8%**, matching the existing `test/unit/test_skill_check.gd` assertion
(`fizzle_percent(85.0, "tone", 0, "note", 2)` `.is_equal(8.0)`). This sweep's own unit test
(`test/unit/test_casting_economy.gd`) asserts the code's real output, **8.0**, not the
documentation's unrounded 7.5 — the doc's 7.5% appears to be the raw pre-rounding value, not
what the game actually rolls against. This is flagged here rather than silently resolved; per
this task's do-not-decide boundary, the formula/rounding convention is not being changed.

### Thinning wilds — Integrity 70

`base = clamp(100 - 70, 0, 100) = 30`

| Breadth | Magnitude | Arithmetic | Raw | Rounded | Ratified |
|---|---|---|---|---|---|
| Tone | Note | `(30 + 0 + 0) * 0.5` | 15.0 | 15 | **15%** |
| Chord | Phrase | `(30 + 5 + 0) * 1.0` | 35.0 | 35 | **35%** |
| Triad | Song | `(30 + 12 + 0) * 1.75` | 73.5 | 73 | **73%** |

### The Hush — Integrity 40

`base = clamp(100 - 40, 0, 100) = 60`

| Breadth | Magnitude | Arithmetic | Raw | Rounded | Ratified |
|---|---|---|---|---|---|
| Tone | Note | `(60 + 0 + 0) * 0.5` | 30.0 | 30 | **30%** |
| Chord | Phrase | `(60 + 5 + 0) * 1.0` | 65.0 | 65 | **65%** |
| Triad | Song | `(60 + 12 + 0) * 1.75` | 126.0 | 126 | **95%** (clamped) |

The Hush Triad·Song cell is the documented clamp case: raw
`(60 + 12) * 1.75 = 126`, which exceeds the `MAX_EFFECTIVE_PERCENT` ceiling of
95 and is therefore clamped to **95%**.

---

## (b) PROVISIONAL Breath / Soul economy proposal

> **Every number in this section is PROVISIONAL.** These values are a starting
> proposal for playtesting and are not ratified canon. They do not change the
> ratified fizzle formula or the ratified "failure spends Soul by wheel
> distance" table.

### Proposed Breath costs per magnitude tier

| Magnitude | Breath cost |
|---|---|
| Note | 3 |
| Phrase | 6 |
| Song | 12 |
| Refrain | 24 |

### Proposed `breath_max` by class tier

The codebase does not yet have a canonical class-tier enum for Breath. This
proposal assumes three simple tiers:

| Tier | `breath_max` |
|---|---|
| Base | 15 |
| Veteran | 30 |
| Master | 60 |

### Proposed Luth restore amount

One Luth working restores **6 Breath**.

### Proposed Mozh corpse/object conversion amount

One corpse or object converted by Mozh restores **12 Breath**.

### Proposed Soul overreach rate

When a caster continues to cast past empty Breath, the missing Breath is paid
straight out of the Soul Gauge at the following **PROVISIONAL** per-magnitude
rate:

| Magnitude | Soul spent per overreach cast |
|---|---|
| Note | 1 |
| Phrase | 2 |
| Song | 4 |
| Refrain | 8 |

This is a **different** Soul-spend mechanism from the existing ratified
"failure spends Soul by wheel distance" table:

| Distance | 0 SAME | 1 NEIGHBOUR | 2 | 3 | 4 | 5 OPPOSED |
|---|---|---|---|---|---|---|
| Soul spent on failure | 0 | 0 | 1 | 2 | 3 | 5 |

The existing table charges Soul when a **reach-cast fails at range**. The new
proposal charges Soul when a caster **casts past empty Breath**, regardless of
whether the cast succeeds or fails. The two mechanisms are independent and must
not be conflated.

### Constraint arithmetic

**Constraint 1 — a Tone-only opening battle of 4 Note casts never drains a
starting caster's `breath_max` to the point of overreach.**

```
4 * note_breath_cost = 4 * 3 = 12
breath_max (base tier) = 15
15 >= 12, with 3 Breath of headroom
```

Therefore `breath_max >= 4 * note_breath_cost` holds for the base tier.

**Constraint 2 — a single Refrain cast always risks overreach for a
starting/base-tier caster.**

```
refrain_breath_cost = 24
breath_max (base tier) = 15
24 > 15
```

Therefore `refrain_breath_cost > breath_max` holds for the base tier, so a
base-tier caster cannot Refrain even once without touching Soul.

---

## (c) Set-piece Breath drain — P2.2 (#595), measured 2026-11-19

R2 (owner, 2026-10-31): keep per-scene refill, and size pools so set-pieces drain Breath by
**PROVISIONAL round 3–4**, so the overreach decision arrives mid-fight. Nothing in this section
changes a number. Every value stays PROVISIONAL under owner item 5.

**Instrument.** `godot --headless --path . --script res://tools/casting_economy_sweep.gd`
(add `-- --set-pieces-only` to skip §(a)–(b), `-- --seeds=N` for fights per row, default 20).
The set-piece part lives in `tools/set_piece_drain.gd`. Before this change the tool printed
compile errors instead of its grid: its `preload` of `skill_check.gd` compiled scripts that
name autoloads before a `--script` run has them. It now loads them after the first frame.
`test/unit/test_breath_drain_r2.gd` pins the steady-casting half below against the live
numbers.

**Live numbers, not §(b)'s proposal.**

- `breath_max = 9 + 3 × Intuition`: 15 / 18 / 21 / 24 for Intuition 2–5
  (`globals/stats/dramgid_derived.gd`).
- Spell costs are 3 / 6 / 12 / 24 by tier.
- The shipped rules give 4 AP a turn.
- Refill is per scene (`GameState.refill_party_breath()` on scene entry, pinned by
  `test/integration/test_travel_flow.gd` and `test/unit/test_game_state_party.gd`). Unchanged.
- **Overreach differs from §(b).** `Resolution` charges 1 Soul for each Breath point the pool
  cannot pay (`globals/combat/resolution.gd`, `soul_overreach`). §(b) proposes a flat 1 / 2 / 4 / 8
  Soul per cast by tier. A Song cast on an empty pool costs 12 Soul live and 4 under §(b).
  This is owner item 45 (c).

### Steady casting: the turn the overreach decision first appears

A caster who casts one tier as often as 4 AP allows (the cheapest card of that cost sets the
AP). The turn shown is the first turn that has a cast its Breath cannot pay.

| Tier | Breath | AP | Casts a turn | Int 2 (15) | Int 3 (18) | Int 4 (21) | Int 5 (24) |
|---|---|---|---|---|---|---|---|
| Note | 3 | 2 | 2 | 3 | 4 | 4 | 5 |
| Phrase | 6 | 3 | 1 | 3 | 4 | 4 | 5 |
| Song | 12 | 3 | 1 | 2 | 2 | 2 | 3 |
| Refrain | 24 | 4 | 1 | 1 | 1 | 1 | 2 |

Note and Phrase play lands on R2's turn 3–4 at Intuition 2–4 **with today's pools**.
Intuition 5 reaches it on turn 5. Song-first play reaches it on turn 2, and any Refrain on
turn 1–2.

### Set-piece fights under KitAI

KitAI plays both sides of each fight on an open 12×6 board, with the live rules (AP rounds;
neither set-piece sets `use_charge_time`). Every fight opens on full Breath and Soul 50 (R3's
start), and each row is 20 seeded fights. The members are the class demo's builds
(`ClassDemo.member()`, Intuition 3, 18 Breath). "Dry" means a turn opened with less Breath than
the class's cheapest kit spell. The round shown is the median, and the rounds column gives
median (max).

| Party | Dead Muster: wins | rounds | dry in | dry round | Empty Post: wins | rounds | dry in | dry round |
|---|---|---|---|---|---|---|---|---|
| Mirrorblade alone | 0/20 | 5 (5) | 20/20 | 4 | 0/20 | 5 (6) | 20/20 | 4 |
| River-Mother alone | 20/20 | 10 (11) | 0/20 | — | 18/20 | 20 (22) | 0/20 | — |
| Ironbrand alone | 20/20 | 4 (5) | 2/20 | 5 | 20/20 | 5 (7) | 13/20 | 5 |
| Lensbearer alone | 20/20 | 10 (12) | 20/20 | 3 | 20/20 | 11 (14) | 20/20 | 3 |
| Husk-bearer alone | 0/20 | 5 (6) | 20/20 | 4 | 0/20 | 4 (6) | 20/20 | 4 |
| Flamebinder alone | 20/20 | 10 (12) | 0/20 | — | 20/20 | 15 (19) | 0/20 | — |
| Stormbearer alone | 20/20 | 9 (14) | 20/20 | 3 | 20/20 | 10 (12) | 20/20 | 3 |
| Oathclock alone | 20/20 | 4 (6) | 0/20 | — | 20/20 | 5 (6) | 0/20 | — |
| Locksmirk alone | 20/20 | 9 (13) | 20/20 | 3 | 19/20 | 10 (12) | 20/20 | 3 |
| Threadwalker alone | 0/20 | 5 (5) | 20/20 | 4 | 0/20 | 5 (6) | 20/20 | 4 |
| Five (Ironbrand, River-Mother, Lensbearer, Mirrorblade, Threadwalker) | 20/20 | 3 (3) | 0/20 each | — | 20/20 | 3 (4) | 0/20 each | — |

A lone caster that casts runs dry on round 3–4, inside R2's band, because KitAI spends big.
A party of five ends both set-pieces by round 3–4, and no member ran dry in any of the
40 fights.

### Findings

1. **Pools: no change proposed.** The smallest change that meets R2 is none. A steady caster
   meets the overreach decision on turn 3–4 at Intuition 2–4. Two outliers go to the owner
   rather than being tuned away. Intuition 5 reaches the decision on turn 5, and that is the
   ratified property that maximum Intuition buys exactly one Refrain
   (`test_dramgid_numbers.gd`). Song-first play reaches it on turn 2.
2. **Set-piece length fails R2 with a full party.** Both approved set-pieces (R14) are one
   enemy: the Mustered Bloodbellow (32 HP) and the Cleaned Jawbrace Guard (36 HP). A party of
   five ends them by round 3 (Dead Muster) and round 3–4 (Empty Post), and no member ran dry
   in 40 fights. So the decision arrives on the last round or not at all, and set-piece
   overreach adds about nothing to the unavoidable Soul spend #599 (P2.6) sizes. Breath cannot
   fix this. It needs set-piece length: a second
   body, a reinforcement or more HP. That is encounter content, and Phase 5 owns it (R14
   confirms these set-pieces without reauthoring them, and the Hollowmere set-piece is not
   written). Owner item 45 (b).
3. **KitAI is a greedy caster.** It prices damage, not Breath or Soul. It opens with its
   biggest spell and overreaches freely. In one solo Jawbrace fight, a Lensbearer cast a
   24-Breath Refrain from 18 Breath on round 2, then paid every later Song from Soul
   (50 → 8 by round 5). Its rounds are a lower bound on drain, not a player's pace. Autoplay
   (the 5v5 class demo) spends the real gauge the same way, which `test_kit_ai.gd` already
   restores after each run.
4. **Outlier classes under KitAI**, for the owner's balance pass and not tuned here:
   - **River-Mother** never runs dry because it refills its own Breath, yet it paid Soul on
     about 14 casts per Empty Post fight (280 over 20). That is the largest Soul drain in the
     sweep.
   - **Flamebinder** never casts. Its kit spells are Hold Note (1 Breath) and Anchor, and
     KitAI always prefers its arms, so its fights run 10–15 rounds.
   - **Oathclock and Ironbrand** seldom or never run dry, and their fights end on round 4–5.
   - **This is not a Breath finding, but the sweep showed it:** Mirrorblade, Husk-bearer and
     Threadwalker lose every set-piece alone (0/20 on both). Gate T1 checks clearability on
     its own fixtures, not these set-pieces. This belongs in the owner's balance pass, and
     it matters only if Chapter 1 can send the protagonist into a set-piece alone.

---

## Out of scope

The vault `magic-system.md` fizzle math includes a `relation_add` target-relation
term that `SkillCheck.fizzle_percent()` does not implement. That term is
explicitly out of scope for this sweep and is ignored in all arithmetic above.
