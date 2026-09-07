# DRAMGID numbers — the §6 freeze

`docs/architecture-dramgid.md` §6 asks for a design note, pure functions and tests covering
seven items. **Four are frozen here. Three are not, for a named reason.**

| §6 item | status |
|---|---|
| `max_hp(grit)` | **frozen** — `12 + grit × 6` |
| `breath_max(intuition)` | **frozen** — `9 + intuition × 3` |
| `attack(muster)` | **frozen** — `muster × 2` |
| `defense(alacrity)` | **frozen** — `alacrity` (unchanged) |
| `ct_speed(reason)` | **reported, not applied** — its consumer still reads `edge` (§3.9) |
| `fizzle_reduction(intuition)` | **verified unchanged** — 48 ratified readings, 0 mismatches |
| Karma/Fame tiers, `karma_bonus`, decay | **already shipped** — recorded below, not re-proposed |

The three unfrozen items are all the same blocker: `CombatRules.charge_speed_attribute` and
`Resolution`'s `edge_delta` still read `attributes["edge"]`, and moving those reads is §3.9 —
F3b, blocked on #281. Landing a formula ahead of its consumer strands it, which is exactly why
§3.6 is being held back too.

- Sweep: `tools/dramgid_derived_sweep.gd` (read-only)
- Code: `globals/stats/dramgid_derived.gd`
- Pins: `test/unit/test_dramgid_numbers.gd`

## 1. The shape of every formula

DRAMGID point-buys attributes **2..5** (`DramgidSchema.ATTRIBUTE_FLOOR` / `ATTRIBUTE_CAP`).
That single fact decides the shape of all four:

> A bare `point × step` puts the floor at **40%** of the cap. A 2.5× spread from one attribute
> does not make that attribute *meaningful*, it makes it *mandatory* — every build maxes it,
> and the point buy stops being a choice.

So every formula below is `base + point × step`. The base is what keeps a minimum-Grit
character playable; the step is what keeps Grit worth buying.

## 2. `max_hp(grit) = 12 + grit × 6`

| grit | 2 | 3 | 4 | 5 | spread |
|---|---|---|---|---|---|
| before (`grit × 8`) | 16 | 24 | 32 | 40 | 2.50 |
| **after** | **24** | **30** | **36** | **42** | **1.75** |

Migration report — §6 requires shipped party HP to stay within ±15%:

| member | authored | grit | derived | error |
|---|---|---|---|---|
| vex | 44 | 5 | 42 | −4.5% |
| serai-lun | 30 | 3 | 30 | 0.0% |
| old-grumbrand | 38 | 4 | 36 | −5.3% |
| wyneth-hallow-tide | 34 | 4 | 36 | +5.9% |
| ressa-quickfingers | 28 | 3 | 30 | +7.1% |
| korrath-ninefold | 42 | 5 | 42 | 0.0% |
| maura-greyfen | 34 | 4 | 36 | +5.9% |

Worst fit **+7.1%**, comfortably inside the tolerance. The old formula also passed ±15% (worst
−14.3%, on the edge), so the tolerance is not why this changes.

**Why it changes.** Under `grit × 8` a minimum-Grit created character starts on **16 HP**
against authored enemies of 14–36 HP (`data/generated/encounters.json`) — the weakest enemy on
the roster has almost as much health as the player. A floor of 24 puts the player above every
enemy's low end while a maxed build still gets 1.75× the HP of a minimum one.

## 3. `breath_max(intuition) = 9 + intuition × 3`

| intuition | 2 | 3 | 4 | 5 |
|---|---|---|---|---|
| before (flat) | 15 | 15 | 15 | 15 |
| **after** | **15** | **18** | **21** | **24** |
| Notes (3) | 5 | 6 | 7 | 8 |
| Phrases (6) | 2 | 3 | 3 | 4 |
| Songs (12) | 1 | 1 | 1 | 2 |
| Refrains (24) | 0 | 0 | 0 | **1** |

Two properties were chosen for, and both hold exactly:

1. **Intuition 2 reproduces today's flat 15**, so no existing caster regresses and every
   ratified sanity reading in `docs/casting-economy.md` still holds at the floor.
2. **Intuition 5 buys exactly one Refrain** (24 Breath). The top of the point buy is the first
   rung that can attempt the largest working at all — a legible reward with no table lookup.

This is the **base** pool. `docs/casting-economy.md`'s veteran (30) and master (60) ceilings are
progression tiers and belong to F5 (#285), not to an attribute.

## 4. `attack(muster) = muster × 2`

| muster | 2 | 3 | 4 | 5 |
|---|---|---|---|---|
| before (`= muster`) | 2 | 3 | 4 | 5 |
| **after** | **4** | **6** | **8** | **10** |

The authored party spans attack **4..9** (`GameState._make_member`). Under `attack = muster` a
created character maxing Muster reached **5** against the pre-made protagonist's **9** — the
character the player built was strictly worse than the one they did not. `muster × 2` spans
4..10, which contains the authored range.

| member | authored attack | muster | derived |
|---|---|---|---|
| vex | 9 | 4 | 8 |
| serai-lun | 8 | 4 | 8 |
| old-grumbrand | 5 | 2 | 4 |
| wyneth-hallow-tide | 4 | 2 | 4 |
| ressa-quickfingers | 9 | 4 | 8 |
| korrath-ninefold | 7 | 3 | 6 |
| maura-greyfen | 6 | 3 | 6 |

This is the one formula whose spread stays 2.5×, and deliberately: damage is `attack − defense`
in `battle.gd`, so the *difference* is what the player feels, not the ratio.

## 5. `defense(alacrity) = alacrity` — unchanged

The authored party spans defense **1..6**; the point buy gives 2..5, which sits inside it with
one glass cannon (`ressa-quickfingers`, 1) and two walls (`old-grumbrand` and
`korrath-ninefold`, 6) outside. Those are authored characters, not a range the formula has to
reproduce.

No base term is added, for a specific reason — see §6.

## 6. The finding this pass did not fix

`globals/battle.gd:813` resolves damage as:

```gdscript
var damage := maxi(1, foe.attack - target.defense)
```

With defense on a 2..5 range and authored enemies at attack 5, an Alacrity-5 character takes
the **damage floor of 1** from most of the roster — roughly 42 hits to fall. Adding a base term
to `defense()` would make that worse, not better, which is why §5 leaves it alone.

The floor itself is the problem, and it is not a number this file can change: `battle.gd`'s
legacy rule is replaced by `Resolution` under same-map combat (§3.9 / #281). **Flagged for the
owner, not silently tuned around.**

## 7. `ct_speed(reason)` — reported, not applied

§6 says "confirm or propose". The grid says the shipped shape barely functions:

| reason | 2 | 3 | 4 | 5 | spread |
|---|---|---|---|---|---|
| `6 + reason/2` (§6's candidate) | 7 | 7 | 8 | 8 | **1.14** |
| `5 + reason` | 7 | 8 | 9 | 10 | 1.43 |
| `4 + reason × 2` | 8 | 10 | 12 | 14 | 1.75 |

Integer division by 2 across a four-point range yields **two distinct speeds**. A player who
buys Reason from 2 to 3 sees no change in initiative at all. **Proposed: `5 + reason`** — the
same base neighbourhood, four distinct values, and a 1.43× spread that matches the HP curve's
restraint rather than the attack curve's.

Not applied here. `CombatRules.charge_speed_attribute` is still `&"edge"` and
`base_charge_speed`/`attribute_points_per_speed` are authored `Resource` data; changing the
attribute is §3.9. This section is the evidence for that change when it lands.

## 8. `fizzle_reduction(intuition)` — verified, zero drift

§6: *"re-run the ratified fizzle sanity readings with Intuition in Pitch's seat; report any
reading that changes."*

The formula is `max(intuition − 2, 0) × 2` — byte-identical to Pitch's. Rather than assert
that, the sweep prints the full grid and it was diffed against
`tools/casting_economy_sweep.gd`, whose readings are the ones verified against
`docs/casting-economy.md`:

```
ratified rows compared: 48 | mismatches: 0
```

**No reading changes.** Reported as required.

## 9. Karma and Fame — already shipped, recorded here

§6 lists these; #384/#390 landed them. Recorded rather than re-proposed:

| thing | value | where |
|---|---|---|
| Karma tiers | Damned / Cruel / Troubled / Uncertain / Upright / Virtuous / Exalted | `Renown.KARMA_TIER_NAMES` |
| Karma floors | −1000 / −600 / −250 / −50 / 50 / 250 / 600 | `Renown.KARMA_TIER_FLOORS` |
| Neutral rung | Uncertain (index 3) | `Renown.KARMA_NEUTRAL_TIER` |
| Fame tiers | Unknown / Whispered / Known / Renowned / Legendary | `Renown.FAME_TIER_NAMES` |
| Fame floors | 0 / 50 / 200 / 450 / 750 | `Renown.FAME_TIER_FLOORS` |
| `karma_bonus` per tier | ±1.0 per rung from Uncertain, on `bellow`/`sway` only | `SkillCheckService.KARMA_BONUS_PER_TIER` |
| Extreme-tier decay | 10% of the excess per week, asymptotic, day-change only | `Renown.DECAY_FRACTION_PER_WEEK` |
| `witness_factor` | default 1.0, applied before the Decorum scale | `Renown.gain_reputation/gain_infamy` |

One number there is still open and stays open: `Renown.ATTRIBUTE_SCALE_DIVISOR = 10.0`.
RFC-0007 writes both shift formulas over a `/10` divisor annotated "Doctrine or Decorum of
10 = 1.0×", and 10 is unreachable under a 2..5 point buy, so every multiplier lands in
0.2×–0.5×. It shipped as the RFC writes it under owner ruling 9. Rescaling it changes two live
recruit gates (`GameState._make_member`: reputation ≥ 10 for Korrath Ninefold, infamy ≥ 8 for
Maura Greyfen) against grants that top out at 12 — so it is an owner call with a blast radius,
not a sweep result. Left as shipped.

## 10. What this document does not decide

- The `max(1, attack − defense)` damage floor in `battle.gd` (§6).
- Whether `ct_speed` moves to Reason at all, and at which shape (§7) — §3.9 owns it.
- `ATTRIBUTE_SCALE_DIVISOR` (§9).
- Whether the shipped party gets the migrated attribute values in §2 and §4 as *authored*
  attributes. The migration report shows they fit; writing them into
  `GameState._make_member()` is a content change and is not made here.
