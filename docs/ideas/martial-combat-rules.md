# Martial combat, armor and defensive timing

**2026-09-10 · Initial playtest proposal, not implemented balance.** This packet
develops the first two areas in the [combat review](combat-gap-review.md). Read the
[weapon cards](martial-action-cards.md) for techniques and the
[mixed encounter](martial-combat-encounter.md) for enemies and acceptance scenarios.
The [spell contracts](spell-card-rules.md) still govern spells and elemental statuses.

## What defines a martial character

Patron supplies the resource/decision loop; major element supplies magical identity;
DRAMGID and its skills supply proficiency; equipment supplies reachable actions and
physical tradeoffs. A weapon grants neither a patron power nor mastery of an element.
The existing Arms skills remain **Keen, Heft, Reach, Loose and Grip**. The nine proposed
weapon families use those skills; they are not nine new skills or nine replacement classes.

Every family gets a basic attack, a committed technique and a utility/preparation
choice. Basic attacks remain useful when preparation is unavailable or expensive.
Equipping the matching weapon enables its basic attack; learning a technique and
meeting the existing skill gate enables that technique. Exact numeric skill thresholds
are deferred to the existing progression pass; do not invent levels or unlock these
advanced techniques for every starting character. Fixture access is explicitly unlocked.

## Costs, targets and damage channels

| Contract | Initial proposal |
|---|---|
| Price | Every card explicitly quotes AP **or** CT. Never charge both or derive all CT prices from a global conversion. Ordinary martial actions cost zero Breath/Soul; ammunition and item costs are separate and explicit. |
| Attack power | `A` means the actor's existing effective attack. A card's `A + n` is its complete proposed weapon/technique power contribution before ordinary hit, defense and positional resolution. Do not add a second passive weapon bonus. No new critical-hit roll or automatic elemental imposition is introduced. |
| Accuracy | Use the existing normal hit rules and visible positional modifiers. A maneuver's additional effect requires its stated hit/position conditions. A miss spends a committed attack and ammunition but applies no hit-dependent benefit. |
| Reach | Chebyshev cells, visible target required. Melee reach 1 does not pass through a blocked diagonal corner; reach 2 needs an unobstructed connecting line. Ranged lines respect normal cover/height/LOS; no ally collision or shot-through-actor rule is invented here. |
| Zero damage | Preparation, repositioning, marking and pure forced movement are explicitly zero-HP effects. They never inherit `A`, a minimum damage floor, tile detonation, elemental charge or a hostile status by accident. |
| Material impact | Only a card with an explicit integrity value damages an object. No `A`, affinity, flank, elemental Aftertone bonus or creature damage floor applies to this channel. Material susceptibility and actual support relationships control structural failure. |
| Multiple targets | Declare original targets before payment; one normal hit per unique actor. Never allocate two hits to a large creature occupying several cells. Each separately eligible target uses its own defense. No automatic replacements for missing or occluded targets. |
| Failure | Reject invalid reach, occupancy, ammunition or equipment before payment. Committed misses spend normal costs. A pending martial attack cancelled by interruption retains paid consumables and its preparation use; scheduler AP/CT refund follows the existing cancellation policy. It is not a spell fizzle or a Vicoar token event. |

For this first packet, **mundane attacks do not produce or consume elemental tile
charge or Aftertones**. The current resolver's neutral element fallback is an
implementation detail, not Sul membership. Existing explicit patron hooks remain
available for actual qualifying attacks, subject to the event limits below.

The cards do not yet add weapon enchantment spells. An elemental strike needs its
own learned, priced technique with a declared component, damage budget, status,
charge behavior and fizzle settlement. Holding a flaming sword near a target is not
a free Kindle cast. Mundane tools can damage susceptible objects through their
authored material card; no bypass of spell composition or advanced Khor gates.

## Armor and hands

These are three fixture profiles for comparison, not a replacement for the current
defense formula or an invented equipment progression. **Armor rating (AR)** is a
separate, physical-hit-only subtraction after existing stat/cover mitigation. If a
future equipment item also contributes to existing defense, it must not apply the
same protection again as AR. For the fixture, existing defense excludes equipment AR.

| Profile | Physical protection | Cost/tradeoff | Art cue |
|---|---|---|---|
| Flexible | AR 0 | No armor movement surcharge. Useful when reach and positioning prevent hits. | Loose silhouette and clear movement range. |
| Layered | AR 1 | First ordinary movement action on each own turn costs +1 AP or +10 CT. | Distinct overlapping layers; show the movement surcharge in preview. |
| Reinforced | AR 2 | First ordinary movement action on each own turn costs +1 AP or +20 CT. | Rigid torso/shoulder silhouette; no implied elemental immunity. |

AR applies to direct mundane weapon/creature physical hits. It does not mitigate
Burning/Decaying ticks, magical line hazards, direct elemental damage or structural
collapse unless an eventual collapse profile explicitly permits it. It grants no
automatic resistance to Weighted, Shocked, concealment, fire ignition or fizzle.

Movement surcharges from armor and Weighted use the **larger**, not their sum, on
the first ordinary move that turn. Charge the action's normal distance price plus
that surcharge; a rejected move consumes neither movement nor the once-per-turn
flag. Later ordinary moves on that same turn pay their normal price. Bonus turns
must not reset an already-used surcharge flag for the ordinary turn. This is new
tuning and must be compared against the spell packet's Weighted behavior in playtests.

Short blades, thrown weapons and a single gauntlet leave an off hand available for
a shield. Heavy blades, axes, hammers, polearms, staves and bows use both hands in
this fixture. Shields unlock their explicit defensive cards, not passive AR or
free reactions. No paired-weapon extra attack is included. Unarmed actors retain
the Grip basic attack with `A`, using normal reach 1.

Swap a carried weapon set with **1 AP / 20 CT**, zero Breath/Soul, only on an ordinary
own turn. A set includes compatible main/off-hand equipment; reject incompatible
two-handed/shield combinations. Swapping ends that actor's prepared response before
changing equipment and does not reload ammunition, restore thrown items, clear taxes
or refresh action/resource limits. Starting a battle does not refill a quiver.

## One prepared response per actor

Guard, Brace, Parry, Interpose, Set Spear and Watch Shot all occupy the same **one
response slot**. They are chosen and paid for on an ordinary own turn. Triggering
them later costs no additional action or resource because the quoted preparation
price already bought that one response. There is no real-time button prompt.

The slot's window ends at the start of the actor's next **ordinary scheduled turn**,
or when spent, replaced, voluntarily cancelled, the actor moves, swaps equipment,
loses required equipment, becomes incapacitated or dies. A bonus/out-of-turn action
cannot refresh the window. New preparations replace the old one without refund;
arming the same still-active preparation is refused before payment. Replacing one
requires its full cost and any fresh ammunition.

Stabilize is an explicit exception to duplicate-preparation refusal when Balance
can actually move toward equilibrium: pay its normal cost, apply that one Balance
change and preserve an already-active Guard's original expiry/use record. It cannot
refresh Guard for free. At exact equilibrium with Guard already active, refuse it.

Martial preparations and Footing are not magical Notes or copyable buffs. Khor,
Vel and buff-copy effects cannot extend their windows, refill ammunition or create
an extra response slot. Rooted is a visible creature trait, not a removable spell
buff; a scenario can explicitly change that trait through its own authored phase.

Rotation is chosen when preparing. The selected arc is fixed until the slot ends;
do not allow free reactive rotation. For a grid-facing cardinal direction `f`, a
source lies in the frontal arc when `dot(source_cell − defender_cell, f) > 0`.
For diagonal facings normalize to one of the fixture's four cardinal facing choices
before commitment. Side/rear cells with dot product zero or less are not frontal.
The preview highlights exactly the eligible cells.

| Response timing | Rule |
|---|---|
| Defensive prevention | Guard/Parry/Interpose settle after an eligible attack hits and before HP damage. A miss leaves the defense available. They do not roll a separate hit or create another action. |
| Forced-move defense | Brace is consumed by the first eligible displacement attempt after its hit/eligibility gate passes, before moving the defender. Rejecting an illegal shove does not bait it. |
| Offensive preparation | Set Spear/Watch Shot trigger **after** the enemy finishes its entire voluntary movement action and movement hazards settle, before it starts another action. They never interrupt a move halfway or cancel already-resolved damage. Forced movement, teleportation and field movement do not trigger them. |
| Trigger hit | A prepared attack spends its slot before its single normal hit, even on a miss. Range, LOS, equipment and source/target life must still be valid. An invalid candidate does not consume the slot; it may wait for another eligible movement inside the window. |
| Response order | Resolve eligible offensive preparations in the snapshot's ordinary initiative order, then stable actor id. Revalidate between responses. Each prepared attack may meet one ordinary defensive response under the selection rules below, but cannot generate another offensive response. Defensive results cannot trigger a further response. Maximum one spent response per prepared actor; a killed mover cannot receive later strikes. |

All reaction results use the original incoming/movement event id and a once-only
response ledger. A prepared attack reports its real damage for Scars and similar
damage events, but is not another voluntary ATTACK/CAST commitment: it does not
advance Maiiam's voluntary rhythm, trigger Izhakel's next-ATTACK contract, seed a
new Vhorr Hunger chain, spend a Defining Strike or consume an armed guaranteed-hit
window. Existing damage to the victim can still trigger its ordinary damage hook.
These are explicit proposed event semantics, not behavior already implemented.

## Defensive cards

All cards cost zero Breath/Soul. Guard and Stabilize retain the existing 2 AP price;
the explicit CT prices and precise scope below are the proposed unified contract.

| Card / price | Target and window | Effect / counter |
|---|---|---|
| **Guard** · 2 AP / 30 CT | Self; one response slot, any direction | Halve the next direct damaging weapon or elemental hit after ordinary mitigation: for positive incoming `D`, take `max(1, floor(D/2))`; zero stays zero. Consume on that hit even if the reduction is zero. Does not prevent attached statuses, periodic damage, hazards or collapse. Bait with a small hit or pressure with a different damage channel. |
| **Stabilize** · 2 AP / 30 CT | Self; Guard window | Prepare the same Guard response and move Balance 30 toward equilibrium once at commitment, using the existing Stabilize identity. Replace a different response; preserve an already-active Guard's expiry/use under the exception above. Never stack a second Guard. Future field pressure can move Balance again. |
| **Brace** · 2 AP / 30 CT | Self; one response slot | Refuse one legal 1-cell forced displacement from any direction. No HP mitigation, status cleanse or protection from destruction of the supporting floor. Consume only when it prevents that displacement. Attack directly, wait it out or remove its preparation. |
| **Parry** · 2 AP / 30 CT | Self, short blade/staff/gauntlet equipped; frontal arc | Reduce the next successful direct melee physical hit by 3 HP after ordinary mitigation, minimum zero. No counterattack. It does not parry arrows, elemental hits, hazards or a pure shove. Reach attacks qualify only if the attacker is in the declared frontal arc. Flank or use another attack type. |
| **Interpose** · 3 AP / 45 CT | Shield required; name one adjacent willing ally | Against the next direct, single-target physical hit on that ally from the defender's frontal arc, absorb up to 3 of its post-mitigation HP damage. Ally takes the remainder; defender takes the absorbed amount as fixed HP loss with no second mitigation. Ally and defender must still be adjacent/visible. No redirect of statuses or AoE, no recursive interposition or reflect chain. Reposition either participant or use a different threat. |
| **Shield Bash** · 3 AP / 45 CT | Shield required; one adjacent enemy | Zero initial HP damage; one normal hit attempts a 1-cell push directly away along a selected legal cardinal direction. Does not prepare a response. Subject to displacement/Footing rules below; no automatic stun, silence or interrupt of an instant action. |

Interpose's fixed loss is attributed to the original attack and does not generate a
second ATTACK/CAST event. A qualifying damage-based resource may react once per
damaged actor, but cannot recurse into another interception. The attack's original
on-hit statuses remain on its original target even if its HP damage becomes zero.

For one hit, the original target's eligible Guard/Parry has priority and prevents
Interpose from triggering on that same hit; the interposer keeps its slot. If no
personal response qualifies, choose the first eligible interposer in snapshot
initiative order, then stable actor id. All others remain armed. Preview this
selection so two allies cannot accidentally pay the same interception twice.

The current legacy battle path halves a guarded enemy hit and clears `guarding`.
The inspected main controller sets `guarding` for Guard/Stabilize, while its damage
calculator does not read that flag. Therefore the unified Guard behavior above is
an **implementation and forecast acceptance requirement**, not a claim that current
same-map Guard already satisfies it. This design pass does not silently fix runtime code.

## Displacement and control limits

Shove effects in this packet move at most **one cardinal cell**, away from or toward
the attacker as stated. Choose and preview the exact destination before commitment.
It must be supported, traversable, unoccupied and within the original battlefield.
No diagonal squeezing, falling off ledges, swapping actors, pushing through walls,
moving an actor onto a non-floor cover block, chaining bodies or unpriced collision damage.

For an aligned melee actor, only the cardinal away/toward cell qualifies. For a
diagonally adjacent actor, either of the two cardinal cells that increases/decreases
its Manhattan distance from the attacker may qualify; choose one before payment.
If a destination becomes invalid, a pure displacement action rejects before payment
when still uncommitted; a committed result skips displacement with no reroute/refund.
An attack that also deals damage can still resolve its damage independently.

A successful forced displacement grants **Footing** through the end of the victim's
next ordinary scheduled turn. Footing prevents further forced displacement, not
damage, normal movement, elemental status taxes or the victim's own decisions.
Successful displacement also ends any position-tethered martial preparation, eligible
hold or pending spell wind-up under that effect's own rules. Footing does not stop
Fickah's explicit cancellation. Brace prevention does not count as displacement.

Large fixture bosses expose a visible **Rooted** trait preventing these shoves;
their ordinary spell/status susceptibility remains separately authored. Avoid making
every boss immune to every control effect. Boss testing must include another route
to interrupt an interruptible commitment, such as its declared support/effect target
or the existing Jam action. No generic stun, lost-turn chain or invented resistance roll.

Landing in a hazard may trigger that hazard's normal entry rule. Preserve the
same per-actor/per-round ledger: shoving into the same Firebreak repeatedly cannot
repeat its hazard hit. A hazard does not become an additional weapon hit or grant
a second voluntary-action resource event.

## Material and defense ordering

For an ordinary positive physical hit, let `D` be damage after existing actor defense
and cover but before this packet's equipment/response handling. Apply `max(1, D − AR)`
when `D > 0`; preserve zero on misses/zero-power utility. A card's armor bypass reduces
only AR, never actor defense, cover, Guard or magical protection. Then apply the one
eligible prepared defense. Parry can reduce the remainder to zero; Guard uses its
stated positive-damage floor. Interpose splits the resulting loss between its actors.
There is no second minimum-damage clamp after Parry or an interception split.

Material mode never attacks an actor sharing/adjacent to the selected surface. The
fixture uses **cuttable timber**, **breakable masonry** and **non-susceptible material**
tags. A normal creature attack does not damage the wall behind it. Collapsing a selected
component changes collision, cover and support only through its authored structure rules.
No harvesting or Mozh yield is granted to rubble unless the source was authored eligible.

All new temporary responses, Footing and weapon wind-ups end at combat exit. Physical
object damage, spent ammunition and source claims retain their ordinary persistence.
Do not expose player combat saving merely because model snapshots are used for tests;
the existing same-map save prohibition remains in force.

## Acceptance examples

| Scenario | Expected result |
|---|---|
| Incoming physical `D=9`, reinforced AR 2, Guard armed | AR leaves 7; Guard leaves 3. One Guard spent; no second defense response. |
| Incoming physical `D=4`, layered AR 1, Parry armed and eligible | AR leaves 3; Parry leaves 0. Do not reapply the generic 1-HP floor. |
| Incoming physical `D=9`, reinforced AR 2, armor bypass 1 | Effective AR 1; take 8 before any eligible response. Actor defense/cover were not bypassed. |
| Interpose covers a post-mitigation 8-HP hit | Ally loses 5, defender loses 3: total remains 8. Neither portion can be intercepted again. |
| Reinforced armor and Weighted affect the first 1-cell move | Pay normal movement plus the larger surcharge: +1 AP or +20 CT, not two surcharges. |
| A prepared bow shot misses after the enemy finishes moving | Its one reserved arrow and response slot are spent. The move is not undone; no immediate second shot. |
| A shove lands a target in Firebreak; another shove follows before its next ordinary turn ends | First shove grants Footing and uses normal hazard accounting. Second displacement is refused; neither rule grants another fire event. |

Sources: [actions](../../globals/combat_action.gd),
[rules](../../globals/combat/combat_rules.gd),
[controller](../../globals/combat/combat_controller.gd),
[legacy battle path](../../globals/battle.gd),
[Arms skill schema](../../globals/stats/dramgid_schema.gd),
[current item metadata](../../data/generated/gloot_prototree.json).
