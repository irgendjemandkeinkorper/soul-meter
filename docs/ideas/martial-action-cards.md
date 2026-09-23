# Weapon families and martial action cards

**2026-09-10 · Initial playtest proposal.** These 27 cards add a concrete martial
design alongside the spell catalog; they are not new spell forms and do not change
its 170-form count. All cards inherit the [martial rules](martial-combat-rules.md).
`A` is existing effective attack before the card's complete stated power contribution.
AP and CT are alternative prices. Every card below costs **zero Breath and zero Soul**.
Material-only or utility cards deal zero initial creature HP damage.

## Family map

| Family | Existing skill / hands | Decision it adds | Principal limitation |
|---|---|---|---|
| Short blades | Keen / one hand | Open a defense or exploit a flank at low commitment. | Needs close access; little armor bypass from the front. |
| Heavy blades | Heft / two hands | Commit to a strong cut or split pressure across nearby targets. | Expensive swings and a visible delayed attack. |
| Axes | Heft / two hands | Defeat a prepared guard or cut a susceptible support. | Must choose creature pressure or material damage. |
| Hammers | Heft / two hands | Beat physical armor, displace a target or break masonry. | Short reach and higher commitment. |
| Polearms | Reach / two hands | Threaten an approach and pull a distant target off a position. | Clear lines required; a flanker can evade the fixed response arc. |
| Staves | Reach / two hands | Spread modest pressure or disrupt a nearby wind-up. | Lower burst; interrupt requires exposed close access and a hit. |
| Bows | Loose / two hands | Pressure at range and prepare a visible watched lane. | Minimum range, LOS and finite arrows. |
| Thrown weapons | Loose / one hand | Flexible short-range attack with a free shield hand. | Finite ammunition; less reach than a bow. Slings remain a later variant. |
| Fists and gauntlets | Grip / hand-dependent | Shove or dismantle a martial preparation in close quarters. | Utility techniques require an available grasping hand. |

The existing Roadwarden Spear and Forge Hammer are candidates for fixture profiles;
their generated inventory records currently supply item metadata, not these action
budgets. The named Taubstummer relic is not silently assigned an ordinary axe kit or
new Soul behavior. Short blades include suitable short swords; greatswords belong
to heavy blades. A shield is a defensive equipment choice, not a sixth Arms skill.

## Short blades — Keen

**Loop:** approach, bait or remove the enemy's defense, then exploit an exposed side.
**Read:** compact cuts, a visible feint line and a clean flank marker; no automatic
invisibility, teleportation or critical-hit flash.

| Id / action / price | Reach / target | Effect and limit |
|---|---|---|
| M01 · **Quick Cut** · 2 AP / 30 CT | One adjacent enemy | One normal physical attack at `A`. Compatible with an off-hand shield; no second off-hand hit. |
| M02 · **Open Seam** · 3 AP / 45 CT | One adjacent enemy; attacker must be in its side/rear at commitment and impact | One attack at `A`, ignoring 1 point of equipment AR for this hit. No bypass of actor defense, cover or Guard; a changed facing can remove the bypass while the otherwise legal attack still resolves. |
| M03 · **Feint** · 1 AP / 20 CT | One adjacent enemy with an eligible Guard or Parry response | Zero HP damage; a normal hit ends that one declared martial response. No effect on Brace, Interpose, Set Spear, Watch Shot, magical holds or pending spells. A miss spends the action. |

**Counter / aftermath:** keep the blade user at reach, change facing, use armor or
choose a preparation Feint cannot remove. Feint is a voluntary hostile ATTACK intent
for relevant contracts, but is not a damaging hit for Hunger or hit-damage rewards.

## Heavy blades — Heft

**Loop:** threaten more power than a light strike can deliver, then make the opponent
choose between yielding ground and contesting the commitment.
**Read:** a wide weapon silhouette and a clearly marked destination for the delayed cut.

| Id / action / price | Reach / target | Effect and limit |
|---|---|---|
| M04 · **Great Cut** · 3 AP / 45 CT | One adjacent enemy | One physical attack at `A + 3`. No automatic displacement, armor bypass or second target. |
| M05 · **Cleaving Arc** · 4 AP / 60 CT | Up to two distinct adjacent enemies in the chosen frontal arc | One attack at `A` per declared target. No target receives the Great Cut bonus; no actor is struck twice. Blocks/Parries resolve separately per target. |
| M06 · **Falling Edge** · 4 AP / 60 CT | One fixed adjacent attack cell; wind-up | Commit a visible mark; at the start of the next ordinary own turn, release one `A + 6` physical attack at the current hostile occupant if still legal. Tethered to the commitment cell and equipped heavy blade. Moving, incapacitation, equipment loss or a valid wind-up cancellation ends it. Empty/friendly-occupied marks are skipped with no retarget/refund. |

**Counter / aftermath:** step away from the mark, break LOS or disrupt the wielder.
Falling Edge is a martial wind-up, not a Refrain: it neither grants nor spends the
once-per-encounter spell ultimate allowance. It uses the pending-action slot and
cannot overlap another pending martial/spell wind-up from the same actor.

## Axes — Heft

**Loop:** punish a protected opponent or open a route by cutting an actual support.
**Read:** broad chopping impacts; susceptible timber shows a cut seam and remaining
integrity. Incidental wood splinters do not imply unbudgeted damage to nearby objects.

| Id / action / price | Reach / target | Effect and limit |
|---|---|---|
| M07 · **Chop** · 2 AP / 30 CT | One adjacent enemy | One physical attack at `A + 1`. No automatic bleed or material damage behind the target. |
| M08 · **Split Guard** · 3 AP / 45 CT | One adjacent enemy | One normal attack at `A`; on a hit, end that target's eligible Guard or Parry before applying this hit's damage. If both are absent, resolve the ordinary attack. AR, cover and all other defenses still apply; no removal on a miss. |
| M09 · **Hew Support** · 3 AP / 45 CT | One visible adjacent cuttable-timber component | Deal 9 integrity damage once, without a creature hit or elemental interaction. Preview the component's actual support/collision consequences; no automatic collapse of unrelated objects, fuel refill or conversion yield. |

**Counter / aftermath:** avoid relying on the specific response being split, keep
distance or use a non-susceptible material. A cut town barricade follows its rebuilding
policy; an abandoned support does not repair itself after the fight.

## Hammers — Heft

**Loop:** trade action commitment for armor pressure, displacement or masonry work.
**Read:** a compact heavy impact; armor bypass and structural damage use distinct icons.

| Id / action / price | Reach / target | Effect and limit |
|---|---|---|
| M10 · **Crushing Blow** · 3 AP / 45 CT | One adjacent enemy | One physical attack at `A + 2`, ignoring up to 2 equipment AR. No bypass of actor defense, cover, Guard or elemental resistance. |
| M11 · **Drive Back** · 3 AP / 45 CT | One adjacent enemy and a declared legal cardinal destination away | One physical attack at `A`; on hit attempt the 1-cell push. Damage can still resolve if Brace/Footing/Rooted prevents movement or a destination becomes blocked. It does not add collision damage or stun. |
| M12 · **Break Masonry** · 4 AP / 60 CT | One visible adjacent breakable-masonry component | Deal 9 integrity damage once. Only an explicitly susceptible object is legal; the card does not damage arbitrary map rock, melt metal, mine unlimited ore or automatically harvest rubble. |

**Counter / aftermath:** keep the hammer user out of reach, prepare Brace against
movement or use Guard against damage. Broken masonry persists according to its
structure policy; temporary summoned stone never yields salvage Breath.

## Polearms — Reach

**Loop:** keep an approach under threat, then choose between attacking at reach and
moving an opponent off the position they wanted.
**Read:** a narrow reach guide and a fixed wedge for Set Spear; both stop at blockers.

| Id / action / price | Reach / target | Effect and limit |
|---|---|---|
| M13 · **Thrust** · 2 AP / 30 CT | One enemy within 2 | One physical attack at `A`. Requires a clear connecting line; no attack through another blocking actor, closed wall or invalid corner. |
| M14 · **Hook and Draw** · 3 AP / 45 CT | One enemy exactly 2 cells away on a cardinal line | Zero HP damage; a normal hit attempts to pull the target one cell toward the wielder into the declared empty supported cell. Refuse known Brace-independent impossibilities such as Rooted/Footing or an occupied destination before payment. Brace may prevent the otherwise legal pull. |
| M15 · **Set Spear** · 3 AP / 45 CT | Self; fixed frontal arc within reach 2 | Prepare one response at `A + 2`. Trigger after the first visible hostile voluntary move that starts outside and ends inside the threatened cells; revalidate reach/LOS. Spend on its normal hit attempt, including a miss. No hit on every traversed cell or extra attack on an actor already inside. |

**Counter / aftermath:** flank outside the arc, use a ranged attack or finish movement
beyond the threatened cells. Set Spear does not halt movement midway and creates no
invisible zone of control. Moving the wielder ends the preparation.

## Staves — Reach

**Loop:** keep nearby foes busy while retaining a precise tool for interrupting a commitment.
**Read:** sweeping staff motion for two targets; a single bright contact cue for an
interrupt attempt, distinct from Zhem spell removal.

| Id / action / price | Reach / target | Effect and limit |
|---|---|---|
| M16 · **Staff Strike** · 2 AP / 30 CT | One adjacent enemy | One physical attack at `A`. A staff also qualifies for the shared Parry card; no passive parry from merely equipping it. |
| M17 · **Sweeping Staff** · 3 AP / 45 CT | Up to two distinct adjacent enemies in the chosen frontal arc | One attack at `max(0, A − 2)` per target. No Overgrown, trip, repeated hit or automatic cancellation. A zero-power allocation stays zero damage. |
| M18 · **Break Cadence** · 3 AP / 45 CT | One visible enemy within 2 with a revealed interruptible pending wind-up | Zero HP damage; on a normal hit cancel the one original declared pending martial/spell wind-up. Does not dispel an established field, cancel an already-resolved instant action, reset Tempo or erase Pazzah/Izhakel deferred records. |

**Counter / aftermath:** deny the staff user a clear reach line, protect the caster
or avoid offering a pending wind-up. A visible interrupt cue is sufficient; hiding
the spell's identity alone does not prevent this attempt. Rooted blocks displacement,
not this explicitly authored interrupt; it remains subject to ordinary hit rules.

## Bows — Loose

**Loop:** choose an immediate ranged attack, a precise shot through partial cover or
one prepared lane that an enemy may avoid.
**Read:** a drawn string, an arrow count and a clearly edged watched lane. No hidden
full-map overwatch or automatic attack against every movement.

| Id / action / price | Reach / target | Effect and limit |
|---|---|---|
| M19 · **Loose Arrow** · 2 AP / 30 CT | One enemy at range 2–6; 1 arrow | One physical attack at `A`. Cannot target an adjacent enemy; cover and LOS apply. Commit consumes one arrow even on a miss. |
| M20 · **Thread the Cover** · 3 AP / 45 CT | One enemy at range 2–6; 1 arrow | One physical attack at `A + 1`, ignoring at most 1 point of cover defense. Cannot ignore blocked LOS, actor defense, AR or a prepared response. |
| M21 · **Watch Shot** · 3 AP / 45 CT | Mark up to three cardinal-contiguous visible cells at range 2–6; 1 arrow | Consume/reserve one arrow at commitment and prepare one response at `A`. Trigger after the first visible hostile voluntary move starting outside and ending inside the marked cells. It spends its slot on the normal hit attempt; no second arrow cost at trigger and no arrow refund on expiry/cancellation. |

**Counter / aftermath:** close to adjacent range, stay in full cover, disrupt the
archer or choose a route ending outside the watched cells. Arrow recovery is not
implemented by this packet; no automatic encounter refill or reusable spent-arrow source.

## Thrown weapons — Loose

**Loop:** use a short-range option while retaining shield access, choosing ammunition
for damage or a specific nuisance effect.
**Read:** one visible trajectory per projectile; a grit impact has an eye/expiry symbol,
not a Vekh Note or magical concealment field.

| Id / action / price | Reach / target | Effect and limit |
|---|---|---|
| M22 · **Cast Iron** · 2 AP / 30 CT | One enemy within 4; 1 ordinary throwing unit | One physical attack at `max(0, A − 1)`. One-handed; compatible shield remains equipped. Misses consume the unit; no automatically returning weapon. |
| M23 · **Double Cast** · 3 AP / 45 CT | Up to two distinct enemies within 3; 1 throwing unit per declared target | One attack at `max(0, A − 2)` per target. Reserve and spend all declared ammunition on commitment; no reallocating both throws to one actor or refund for a later-invalid target. |
| M24 · **Blinding Throw** · 2 AP / 30 CT | One sighted enemy within 3; 1 carried grit packet | Zero HP damage; normal hit applies the spell packet's one-checkpoint weakened Blinded behavior. Physical application creates no Vekh charge/Aftertone and rolls no spell fizzle. Reject a known sightless/immune target or missing grit before payment. |

**Counter / aftermath:** take cover, move outside the short range or exploit the
finite ammunition. The physical and magical Blinded versions share one status instance
and the same nonstacking accuracy penalty; neither creates an extra turn loss.

## Fists and gauntlets — Grip

**Loop:** get into close contact, remove a prepared advantage or shove an enemy into
a worse position. A free grasping hand is the utility tradeoff.
**Read:** body contact and a single destination marker. No lingering grapple rope or
stun icon, because this packet does not introduce a sustained grapple system.

| Id / action / price | Reach / target | Effect and limit |
|---|---|---|
| M25 · **Close Strike** · 2 AP / 30 CT | One adjacent enemy; fist or gauntlet | One physical attack at `A`. A gauntlet can pair with a shield for this attack, but a shield occupies the hand needed by the following Grip techniques. |
| M26 · **Shove** · 2 AP / 30 CT | One adjacent enemy; two free hands, or gauntlet plus free hand | Zero HP damage; a normal hit attempts the declared legal 1-cell push away. Follows Brace, Footing, Rooted and occupancy rules. No collision damage, automatic interrupt on a prevented move or ledge kill. |
| M27 · **Unseat** · 3 AP / 45 CT | One adjacent enemy with a martial response; same hand requirement as Shove | Zero HP damage; normal hit ends the one declared Guard, Brace, Parry, Interpose, Set Spear or Watch Shot. Does not steal equipment, recover its spent ammunition, cancel a spell wind-up or erase a magical hold. |

**Counter / aftermath:** deny contact, occupy the shove destination or attack from
reach. Removing a preparation does not refund what its owner spent to arm it.

## Preview, event and unlock checks

Every card displays its action price, hand requirement, target legality, final physical
power, mitigation and any separately gated utility result. A Drive Back preview can
say “damage applies; target is Rooted, no push” instead of promising an interrupt.
Pure displacement against a known unmovable target is refused before payment.

Multi-target attacks count as one voluntary action commitment. For this packet,
one-use next-hit enhancements affect only the first declared target allocation and
are consumed on that attempt according to their own miss/fizzle policy; they do not
silently multiply across every target. Ordinary successful-damage hooks retain their
per-target eligibility. Utility attacks cannot seed damaging-hit rewards solely because
they use the ATTACK verb. Reconcile each patron's current event hooks before implementation.

First playtest access: all actors know their family's basic card; fixture-specific
actors are explicitly granted selected advanced cards. Normal progression must still
meet learned-technique and Arms skill gates. No change to patron selection, shared
Khor access, spell mastery or the existing chapter/perk progression is implied.

These are proposed profiles. No generated item metadata, class resource code, action
enum or animation asset has been changed by this design pass.
