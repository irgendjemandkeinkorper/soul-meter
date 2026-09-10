# Shared rules for the complete spell-card draft

**2026-09-09 · Initial playtest specification.** Extends the accepted Khash card
approach across the [spell-form catalog](spell-forms-and-hybrids.md). New numbers,
statuses and behaviors are design proposals; these documents do not implement or
rebalance live spells. The existing ten-element Wheel and nine-choice character
structure remain intact. No spell, hybrid or ultimate grants Soul.

## Reading the cards

| Code / form | Magnitude | Default AP / CT | Default Breath | Purpose |
|---|---|---|---|---|
| N / Primary | Note | 2 / 30 | 3 | A precise application. |
| P / Secondary | Phrase | 3 / 45 | 6 | A targeted tactical extension. |
| S / Tertiary | Song | 4 / 60 | 12 | A field, route or prepared position. |
| R / Ultimate | Refrain | 4 / 60 | 24 | A decisive bounded opportunity. |

Each card inherits these prices unless it names an exception. AP and CT are
alternative scheduler prices, never both charged. The Breath ladder remains the
earlier economy draft's provisional ladder, not a ratification of its other tables.
Keep normal fizzle, hit, Harmony/mastery gates and runtime overreach/failure rules.
Strained hybrids also retain their existing composition-reported Vär/strain cost;
verify its actual settlement before implementing these cards.

**Power** is an input to creature damage before existing modifiers; **fixed damage**
is the explicitly stated continuing loss, without another hit/affinity roll.
**Integrity damage** is separately authored physical damage. Never apply a creature
damage multiplier, a tile detonation or an Aftertone bonus to an object implicitly.

All range numbers are Chebyshev grid-cell distance. Radius 1 is a 3×3 square;
radius 2 is a 5×5 square. Target cells need line of sight unless an existing named
Triad specifically supplies an exception. Objects can be targeted at their visible
surface; their own blocking footprint does not hide that surface from the caster.

An **attack**, **support** or **environment** intent determines the recipient effect
set. Support never damages its recipient or automatically applies a hostile
imposition because of its element. It does not strike/detonate target tile charge.
Physical-object effects leave elemental tile charge and creature Aftertones alone
in this first prototype. Creature attacks retain the ordinary charge path. These
are explicit future resolver requirements, not behavior achieved by setting power 0.

## Proposed creature-status contract

These operational definitions fill the draft's previously unspecified status
behavior. The element/status names are established; the numbers and movement rules
are new playtest proposals. A card applies a status only when it explicitly says so.

| Status | Proposed effect | Expiry / counter |
|---|---|---|
| Exposed | Eligible concealed magical properties are revealed to the caster's side under ordinary revelation rules. No automatic defense penalty or invented weakness. | Two checkpoints; later concealment cannot hide those properties until this revelation ends, except a cataloged Triad restriction. |
| Overgrown | The target's next ordinary movement action can end at most one cell from its start. Preview the restricted destinations and pay only the actual move cost. | Consumed by that successful movement, or after two checkpoints. It does not block attacking, guarding or separately authored teleports. |
| Soaked | Prevent this packet's Burning application and quench its existing creature Burning. | Two checkpoints; not immunity to direct fire or a magical line's separate hazard damage. |
| Weighted | The first ordinary movement action on each turn pays one extra step: +1 AP or +20 CT. It does not change path length or already committed moves. | Two checkpoints; never taxes guard or attacks. The quote must show the surcharge before movement. |
| Blinded | The next committed attack has a −10 percentage-point hit modifier, subject to existing hit-chance clamps. | Consumed by the attempt even if it misses, or after two checkpoints. Support and movement do not consume it. |
| Decaying | Lose 3 fixed HP at each of the next three checkpoints after application. | One instance per target; a refresh replaces remaining duration, not a parallel stack. No automatic execution or corpse conversion. |
| Burning | Lose 3 fixed HP at each of the next two checkpoints after application. | One instance; refresh without stacking. Soaked/Douse removes it. See the Khash packet for the separate line-hazard cap. |
| Muted | The applying working resets Tempo; later Tempo behavior follows ordinary rules. | Instant reset, not a two-round prohibition on casting or generating Tempo. Ongoing suppression requires a specifically authored field. |
| Shocked | The next committed non-movement, non-guard action costs +1 AP or +10 CT. Cap only the added surcharge at `max(maximum budget − base cost, 0)`; never reduce the base cost. | Consumed by that action, or after two checkpoints. Does not interrupt or retroactively tax an already committed action. |

Movement/status taxes never consume resources for a rejected action. Khor's ordinary
hold does not preserve hostile impositions; Vel extends only eligible owned buffs.
Zhem's ordinary removal targets buffs/Aftertones/eligible workings, not every hostile
status by implication. Future cleanses need an explicit status list.

Burning and Decaying are different effects and can coexist. Each has one credited
owner, one remaining-duration record and at most one ongoing tick per checkpoint.
Refreshing transfers future credit to the latest successful application. Fixed
effect ticks do not become new CAST events or repeat the original attack's bonuses.

## Duration, sustain and handoff

Use the Khash packet's round-checkpoint ordering. Effects created at a checkpoint
neither age nor receive a continuing tick at that same checkpoint. Existing effects
receive their final eligible tick/protection before duration reaches zero. Once-only
casts, actions or tick ids cannot be replayed by loading the same snapshot.

| Mechanism | Shared contract |
|---|---|
| Ordinary field | Lasts two checkpoints unless its card overrides this. The card states whether it is an eligible owned Note that Khor can hold. |
| Hold | One sustain slot per starter caster. Freeze one eligible Note's remaining duration by paying 1 AP or 30 CT and 1 Breath at each upkeep. Breaking upkeep resumes the remaining duration. |
| Vel extension | Add one remaining checkpoint once per eligible owned buff instance, capped at its original duration +1. No refreshing the extension allowance by recasting Cultivate. |
| Passing Tone | Transfer the hold atomically to a willing ally with a free slot. Original ownership, remaining duration and instance id persist; the new holder pays upkeep. Rejection leaves the original hold intact. |
| Refrain window | Its special window and spent-use flag cannot be held, extended, copied or transferred. An underlying ordinary field can still be held if its own card permits it. |

The holder supplies upkeep and interruption checks. The original caster remains the
owner for buff eligibility, damage credit and existing ownership-dependent lifetime
rules. If either the effect's stated life conditions fail or the holder cannot
maintain it, follow the applicable expiry/break rule. No copied ownership or double slot.

All ordinary temporary combat fields/holds end on combat exit in this prototype;
independent physical damage and material fire persist. Khor cannot freeze rebuilding
time, physical combustion, a corpse's eligibility or the ultimate-use allowance.

## Refrain commitment and interruption

One committed R per character per encounter is the initial test limit across all
families, not one use of each ultimate. Rejection spends nothing; commitment pays
the card's normal costs and consumes the use. A committed fizzle follows the existing
failure rules and consumes that use. This harsh failure tradeoff remains a tuning item.

Every R card declares **instant** or **wind-up**. Wind-up uses Crown's tethered release:
fixed marks at commitment, release at the caster's next scheduled turn, cancelled
by leaving the commitment cell, incapacitation/death or a valid pending-effect cancel.
Lost/occluded targets are skipped at release; never silently select replacements.
Original target identity matters for object consumption and restoration. A marked
attack cell can affect its current eligible occupant as disclosed by that card.

**Proposed interruption settlement:** keep paid Breath, already-paid Soul costs and
the spent R use; use the existing scheduler cancellation policy for any AP/CT refund.
Do not roll a second fizzle or charge failure Soul merely because an enemy interrupted
the wind-up. A resource refund supplied by an existing patron needs its own qualifying
event; interruption is not automatically Vicoar's fizzle event. This proposal closes
the earlier Khash packet's unspecified spell-resource refund case for playtesting.

Instant R cards offer no invented interrupt window. Their counterplay is positioning,
eligibility and disrupting preparation before commitment. Exploration use still
requires an authored recovery gate; encounter entry/exit must not reset farmable
reclamation or restoration opportunities. No runtime global cooldown is added here.

Zero-action R commits must leave the actor's remaining AP/CT and ordinary turn
opportunity intact, while still settling Breath, fizzle, events and the spent-use
guard exactly once. A zero price that nevertheless ends the actor's turn would
defeat the card's purpose. A bonus/out-of-turn opportunity does not count as the
next ordinary scheduled turn for a tethered wind-up release.

## Resource and material budgets

| Channel | Concrete initial contract |
|---|---|
| Luth restoration | Total restored Breath ≤ Breath actually paid for that cast, after capacity clamping. Missing Breath paid from Soul adds no restoration budget. Choose allocations before payment; no duplicate payout or refund of an already-delivered installment. |
| Mozh conversion | Eligible fixture corpse/expendable source yields 9 Breath once. Claim stable ids atomically; exclude essential quest items, conjured material, summoned creatures' remains and already claimed sources. Rebuilt/crafted objects do not acquire yield unless explicitly authored. |
| Temporary growth | Created vegetation is a magical, non-harvestable construct: 9 integrity and three finite fuel ticks per cell. Authored fire/decay can damage it; removal clears its footprint without repairing underlying terrain. |
| Temporary stone cover | Cover-height obstruction, not a new elevated floor. No creation in occupied cells; expiry cannot strand an actor on a nonexistent platform. Ineligible terrain is rejected before payment. |
| Conductive route | Only authored connected surface links conduct. A creature's Soaked status and a tile's elemental charge do not automatically create links. Preview affected allies and use a finite, once-per-entity damage budget. |

Recipients cannot exceed their Breath capacity. Choose any distribution at commitment;
if a delayed recipient dies or becomes ineligible, its allocation is lost unless the
specific card permits reassignment. Sources cannot be consumed before a successful
release. At release, consume only still-eligible original ids; no automatic replacement
with the next nearby corpse. Missing sources yield nothing and do not refund the cast.

Actor damage, magical effects, elemental charge and physical materials remain
separate state channels. Ending a spell does not restore damaged infrastructure;
maintained buildings retain their authored recovery timer, and abandoned sites stay
ruined without a story restoration. Physical fire catch-up follows the finite-fuel
world-phase proposal in the Khash packet, not wall-clock time.

## Implementation boundary

Temporary growth uses the Khash packet's 3-integrity physical burn tick and explicit
thermal-impact amounts, with its own smaller durability/fuel values. Removal of the
magical construct removes its remaining fuel and ends combustion on that segment.
Independently ignited ordinary material follows its own persistent record. No
automatic spread to nearby objects is introduced by these cards.

These rules unify the design packet. Status operation, per-working intent, explicit
imposition choice, object targeting, fields, consumption accounting, hold ownership
and wind-up/refund handling still need runtime implementation and acceptance tests.
Keep generated catalogs and existing class APIs intact until each approved slice
is implemented through forecast and commit together.

Sources: [Khash prototype](khash-prototype-spell-cards.md),
[elemental design](elemental-magic-systems.md),
[existing resolution coverage](../element-resolution-integrity.md),
[composition resolver](../../globals/elements/composition_resolver.gd),
[casting gate](../../globals/elements/casting_gate.gd), and
[combat rules](../../globals/combat/combat_rules.gd).
