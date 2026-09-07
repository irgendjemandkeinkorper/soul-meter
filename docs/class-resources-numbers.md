# Class-resource numbers (B11 / #234)

Every number in `globals/combat/class_resources/*.gd` shipped marked
`PROVISIONAL — B11 owns tuning`. This is B11: the reading of those numbers, the
sweep that produced it, and one proposed value per constant.

**Nothing here is applied.** The issue's boundary is explicit — values land in
`.tres`/constants *after owner review*. This document is the review packet.

- Sweep tool: `tools/class_resource_sweep.gd` (read-only)
  ```
  godot --headless --path . --script res://tools/class_resource_sweep.gd
  ```
- Pinned by: `test/unit/test_class_resource_numbers.gd`
- Every fizzle figure below comes from the **ratified**
  `SkillCheckService.fizzle_percent()`. No number in this document was computed
  by hand.

## 1. Assumptions (argue with these first)

| assumption | value | source |
|---|---|---|
| battle lengths swept | 6 / 10 / 14 rounds | none authored — stated so it can be corrected |
| enemy HP band | 14–36 | `data/generated/encounters.json`, authored enemies |
| party max HP | 10 | `PartyMember.max_hp` default |
| Breath pool | 15 | `PartyMember.DEFAULT_BREATH_MAX` |
| Note cost | 3 Breath | `docs/casting-economy.md` |
| accords swept | 95 / 80 / 60 / 40 | `docs/thinning-gradient.md` effective values |

If the real battle length is 20 rounds rather than 10, three of the
recommendations below move. That is why the assumption table is first.

## 2. Summary — shipped vs proposed

| constant | shipped | proposed | verdict |
|---|---|---|---|
| `IronbrandScars.MAX_SCARS` | 5 | **3** | change |
| `VicoarInstructiveFailure.MAX_TOKENS` | 3 | **3** | keep |
| `VhorrHunger.MAX_HUNGER` | 5 | **3** | change |
| `VhorrHunger.BREATH_REFUND` | 1 | **3** | change |
| `HaerenNameLedger.BREATH_REFUND` | 1 | **3** | change |
| `StuidClarity.MAX_CLARITY` | 3 | **3** | keep |
| `PazzahLedger.MAX_ENTRIES` | 3 | **3** | keep |
| `IzhakelThreads.MAX_THREADS` | 3 | **3** | keep |
| `MaiiamBalance.UNBALANCED_AFTER_STREAK` | 2 | **2** | keep |
| `MaiiamBalance.UNBALANCED_DAMAGE_MULTIPLIER` | 1.25 | **1.25** | keep |
| `MaiiamBalance.UNBALANCED_FIZZLE_INTEGRITY_PENALTY` | 15.0 | **15.0** | keep |
| `SkillCheckService.FIZZLE_FLOOR_PERCENT` | 5.0 | **5.0** | keep, with a flag |
| `OfshutjeAttribution.EFFECT_TABLE` | 3 rows | **6 rows** | change |

Eight of thirteen are already right. The five that move are below.

## 3. Kero — Ironbrand: Scars

`MAX_SCARS` caps banked guaranteed-hit windows; one is banked per HP loss.

| hits taken / round | rounds | cap 2 | cap 3 | cap 5 | cap 8 |
|---|---|---|---|---|---|
| 0.5 | 10 | capped R4, 3 lost | capped R6, 2 lost | capped R10, 0 lost | never caps |
| 1.0 | 10 | capped R2, 8 lost | capped R3, 7 lost | capped R5, 5 lost | capped R8, 2 lost |
| 2.0 | 10 | capped R1, 18 lost | capped R2, 17 lost | capped R3, 15 lost | capped R4, 12 lost |

**Proposed: 3.** At the shipped 5 the cap only binds when the owner is being hit
once a round or harder — and a party member has 10 max HP, so at that rate they
are dead or healed long before round 10. The cap therefore almost never binds in
a real battle, which makes it decoration rather than a limit. A cap of 3 is
reached by round 3 under pressure and by round 6 when hits are occasional, so it
is a *choice* (spend now or bank) instead of a number nobody meets.

## 4. Vhorr — Husk-bearer: Hunger

The queued DoT re-queues itself while the target lives, at the Hunger it was
queued with, so the tick in round *r* is `min(r - 1, cap)`.

| cap | 6 rounds | 10 rounds | 14 rounds | kills 14 HP | kills 36 HP |
|---|---|---|---|---|---|
| 3 | 12 | 24 | 36 | round 7 | round 14 |
| 5 (shipped) | 15 | 35 | 55 | round 6 | round 11 |
| 8 | 15 | 44 | 76 | round 6 | round 9 |

**Proposed: 3.** At the shipped 5 the Hunger DoT alone kills the *toughest*
authored enemy by round 11 and deals 55 damage across a long battle, for the
price of one landed hit — the rest is free and unconditional. At 3 it kills the
low end of the HP band by round 7 and never finishes the high end inside a
normal battle: pressure that the party still has to close, which is what a
per-class resource should be. This is a magnitude change only; the re-queue
logic is out of scope (`Do not touch resource logic`).

## 5. Breath refunds — Haeren and Vhorr

Both refund `1` Breath. A Note costs **3** Breath and the pool is **15**.

| refund | names / kills | Breath returned | Notes bought |
|---|---|---|---|
| 1 (shipped) | 3 | 3 | 1.00 |
| 2 | 3 | 6 | 2.00 |
| 3 | 3 | 9 | 3.00 |

**Proposed: 3 for both.** At 1 the refund buys a third of a Note; three separate
acts are needed before the player can cast anything with it, which is below the
threshold where a reward reads as a reward. At 3 one recorded name — or one DoT
kill — returns exactly one Note. The unit is legible at the table: *a name is
worth a Note*.

Both refunds moved from Soul to Breath under the owner's ruling that the Soul
Gauge rises **only** through an act of Agreement (`docs/game-identity.md`
ruling 3). Raising the Breath magnitude does not reopen that; it prices the
substitute currency.

## 6. Ofshütje — Stormbearer: Attribution

Roadmap B9 calls for a "hidden table, semi-random **big effects**".

| table | rows | min | max | mean | spread |
|---|---|---|---|---|---|
| shipped `[1, 2, 3]` | 3 | 1 | 3 | 2.00 | 2 |
| floored `[2, 2, 3, 4]` | 4 | 2 | 4 | 2.75 | 2 |
| tailed `[1, 1, 2, 2, 3, 6]` | 6 | 1 | 6 | 2.50 | 5 |

**Proposed: the tailed table.** The shipped placeholder has a spread of 2 — a
uniform draw between 1 and 3 is not "the storm chooses", it is a rounding error
the player cannot feel. The tailed table keeps the same mean (2.5 vs 2.0) while
giving a 1-in-6 result that is worth waiting for, and it keeps a floor of 1 so a
draw is never nothing. Row weights are expressed as repeated rows because
`hidden_draw` draws uniformly over `rows`.

## 7. Kept as shipped — with the evidence

### Maiiam — Mirrorblade: Balance (streak 2, ×1.25, −15 accord)

At the shipped values Unbalanced is worth it in **9 of 16** swept rows, and the
split falls exactly where the fiction wants it:

| accord | note | phrase | song | refrain |
|---|---|---|---|---|
| 95 | worth it | worth it | no | no |
| 80 | worth it | worth it | no | no |
| 60 | worth it | no | no | (clamped) |
| 40 | worth it | no | (clamped) | (clamped) |

Spamming one side rewards quick jabs and punishes big commitments. No other
swept pair produces that shape: ×1.5 makes Unbalanced correct almost always
(11–16 of 16), and a −25 penalty makes it almost never correct (3–9 of 16).

**Flag (not a number):** once both sides hit `MAX_EFFECTIVE_PERCENT` (95%) the
accord penalty stops mattering and the damage multiplier is free, so Unbalanced
becomes strictly better at the bottom of the accord range. Those are the rows
marked "(clamped)". Whether that is acceptable is a design call, not a tuning
one.

### Vicoar — Flamebinder: Failure Tokens (cap 3)

Tokens banked over 10 casts, by where you are standing:

| accord | Note fizzle | tokens | Song fizzle | tokens |
|---|---|---|---|---|
| 95 (Dom) | 3% | **0** | 9% | **0** |
| 80 (Wilds) | 10% | 0 | 35% | 3 |
| 60 (Dorthkor) | 20% | 2 | 70% | 6 |
| 40 (Wound Lip) | 30% | 2 | 95% | 9 |

Cap 3 wastes nothing anywhere except deep-front Songs, so the cap is correct.

**Flag (not a number):** the class's whole resource is **inert in Dom**. At hub
accord a Flamebinder banks zero tokens across a full battle at either magnitude,
so Instructive Failure does not exist for a player who has not left the city.
That is a content/design question — an early low-accord encounter, a strain
source, or an authored starting token — not a cap to retune.

### Fickah — Locksmirk: fizzle floor (5%)

At Mastery on Note and Phrase every other patron reaches **0.0%** at every swept
accord; Locksmirk reaches **5.0%**. The floor is `maxf`, so it is a *cost*
wherever the natural rate is below it and invisible everywhere else — the
rule-breaker is the only class that can never be certain.

That is roadmap B8's stated intent ("floor > 0% fizzle at Mastery"), so the
number stays. **Flag:** the compensating upside is `jam_the_gears`, which cannot
be reached from the action catalog — `CombatAction` has no enemy-target channel
for a class-resource command (documented in `docs/class-resources.md` §4). Until
that lands, Locksmirk carries a pure downside.

### Budget caps — Stuid 3, Pazzah 3, Izhakel 3

| cap | rounds per use, 6-round battle | 10-round | 14-round |
|---|---|---|---|
| 2 | 3.00 | 5.00 | 7.00 |
| 3 (shipped) | 2.00 | 3.33 | 4.67 |
| 5 | 1.20 | 2.00 | 2.80 |

Three uses puts one every 3–5 rounds in a normal battle: often enough to be a
tool, rare enough to be a decision. Two is one use per act; five is effectively
uncapped. Kept.

## 8. What this document does not decide

- Whether the Hunger DoT should re-queue itself at all (logic, not a number).
- Whether Locksmirk needs a compensating upside, and what it is.
- Whether Instructive Failure should be reachable in Dom.
- The `MAX_EFFECTIVE_PERCENT` clamp interaction with the Balance multiplier.

Each is an owner call and each is flagged in place above.
