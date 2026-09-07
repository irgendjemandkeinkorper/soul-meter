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

## Out of scope

The vault `magic-system.md` fizzle math includes a `relation_add` target-relation
term that `SkillCheck.fizzle_percent()` does not implement. That term is
explicitly out of scope for this sweep and is ignored in all arithmetic above.
