# Strained spell cards: the remaining Wheel pairs

**2026-09-10 · Initial playtest proposals; no runtime changes.** These 78 forms
complete the 26 previously unauthored distant pairs. Together with the four
[existing strained families](hybrid-spell-cards.md#strained-hybrids-additional-shapes-existing-strain),
every legal distance-2/3/4 pair now has a secondary, tertiary and ultimate form.
See the [packet index](spell-card-catalog.md) for the full inventory.

## Shared reading and casting contract

| Form | Magnitude | AP / CT | Breath |
|---|---|---|---|
| P · Secondary | Phrase | 3 / 45 | 6 |
| S · Tertiary | Song | 4 / 60 | 12 |
| R · Ultimate | Refrain | 4 / 60 | 24 |

Every card below uses these prices without exception, plus the existing distance's
strain/Vär/fizzle consequences. AP and CT are alternatives. Both components and the
technique need their normal learning/mastery gates; shared access to basic Khor
does not unlock advanced Khor hybrids. These are additional learnable techniques,
not mandatory steps before casting an existing spell.

The [shared rules](spell-card-rules.md) govern intent, ownership, line of sight,
checkpoints, finite sources and interruption. **Weak** means the
[strained-duration convention](hybrid-spell-cards.md#weakened-hostile-statuses-for-the-first-prototype):
one checkpoint for Exposed/Overgrown/Soaked/Weighted/Blinded/Burning/Shocked;
two for Decaying. One-use consumption and per-event values remain unchanged.
Only explicitly listed hostile statuses apply, on a successful normal hit unless
the card says otherwise. Utility revelation, physical Wet, growth and concealment
use their separately stated durations. A status-only attack has zero initial HP
damage but still uses a normal hit; it must not gain a damage floor from bonuses.

All fields last two checkpoints unless stated. A card must explicitly say
**hold-eligible** to permit Khor sustain. None of this supplement's R-created fields,
windows or prepaid trigger budgets can be held, extended, copied or transferred.
Ordinary P/S fields may receive a normal eligible owned-buff extension; this never
refills a finite trigger, restoration pool or one-time use. Fields carrying any
finite pool or trigger budget are ineligible for buff copying. A prepaid trigger is
not another cast and cannot repeat cast resource hooks or generate a new Aftertone.

Each wind-up marks its original cells, recipients, sources and effect ids at
commitment, then uses the shared tethered release rule. Named creature recipients
must still be in reach and visible at release; marked attack cells instead affect
their current occupants. Deduplicate large creatures across cells. Missing targets
are skipped, without replacement, refund or redistribution unless explicitly stated.
All mixed support/attack casts preview both recipient sets and reject harmful support
allocations. For area cards, targets, sources and effect anchors must also remain
inside the declared footprint when their part resolves, including later installments.
If a card offers **either/or**, choose one mode before payment.

Cover and growth use [elemental placement](elemental-spell-cards.md) and
[material/fire rules](khash-prototype-spell-cards.md): valid unoccupied ground or
substrate, 9 integrity per cell, no trapping an actor inside a closed formation.
Stone contributes +1 cover where it actually blocks the attack; cover bonuses from
these cards do not stack. Growth is non-harvestable, with three finite fuel ticks.
Neither can repair or replace the persistent state of a destroyed building.
Routes require authored conductive material links; neither plants, corpses, fire,
Soaked actors nor elemental tile charge automatically make a conductive network.

All creature power totals below are base budgets before ordinary modifiers. Direct
Khash creature hits retain the ordinary eligible Aftertone-consumption bonus; object
integrity damage does not. No card supplies Soul. Mozh always uses stable, eligible,
once-only source claims; Luth always caps transfers by actual Breath paid and capacity.
Concealed casting never hides a hazardous footprint, obstruction or interrupt cue.
Visual notes are art direction for eventual implementation, not existing assets.

## Sul + Luth — distance 2

**Playstyle:** reveal a safe approach while passing a finite Breath reserve to allies.
**Read:** clear ribbons carry small white glints toward the recipient; revealed magic
gets a crisp outline rather than a blinding screen wash.

| Form / working | Reach / duration | Concrete effect and limit |
|---|---|---|
| P · **Clearwater Gift** | One other willing ally within 4; instant transfer, revelation two checkpoints | Restore up to 6 actually paid Breath, capacity-clamped, and reveal eligible magical properties at the ally's current cell. No heal, hostile Soaked or invented weakness. |
| S · **Lantern Spring** | Fixed center within 4, radius 1; two checkpoints | Reveal eligible magic in the field. Allocate a paid pool of at most 12 to ≤3 other willing allies in it, delivered in two declared checkpoint installments while each recipient remains inside. Hold-eligible for revelation only; never recharge or repeat the transfer pool. |
| R · **Estuary of Truth** | Center within 5, radius 2; instant | Reveal eligible magic for one checkpoint, quench physical fire/Burning in ≤3 declared cells, and immediately divide at most 24 actually paid Breath among ≤4 other willing allies in the area. Physical Wet and friendly Soaked last two checkpoints. Quenching does not undo integrity loss. |

**Counter / aftermath:** move out of the spring to forfeit an installment, sever its
Note or use opaque cover. Revelation exposes properties, not hidden map geometry;
independent physical fires outside the chosen quench cells continue.

## Sul + Khor — distance 3

**Playstyle:** maintain a useful observation point while the party changes position.
**Read:** a suspended lens trails a thin tether to its holder; only currently revealed
properties glow. The tether and lens remain readable under visual clutter.

| Form / working | Reach / duration | Concrete effect and limit |
|---|---|---|
| P · **Witness Thread** | One visible cell within 4; two checkpoints | Create a radius-0 revelation Note and establish its hold in one cast, requiring a free sustain slot. Later upkeep is normal; revelation follows current eligible properties, not a permanent lock on a departing creature. |
| S · **Walking Lantern** | One willing holder within 4, mobile radius 1; two checkpoints | Create a hold-eligible revelation field attached to that holder. Establish the caster's hold if its slot is free at commitment. Movement carries the field, not terrain, targets or stored revelation; maintaining it does not recast Exposed. |
| R · **Constellation of Witnesses** | Three fixed visible cells within 5, radius 1 each; wind-up | Establish three revelation windows through the next checkpoint after release. Union their coverage without tripling effects; no sustain slots required and no later hold. Ordinary concealment is revealed only while eligible properties are inside the surviving windows. |

**Counter / aftermath:** remove the lens, break sustain or leave its coverage. Current
revelation does not track a creature through walls, negate Barrow or retain an expired
magical effect as a consumable trace.

## Sul + Tham — distance 4

**Playstyle:** build visible defensive positions that make nearby magical preparation legible.
**Read:** pale seams run through stone; a low light ring shows the actual inspection
area and stops at occlusion.

| Form / working | Reach / duration | Concrete effect and limit |
|---|---|---|
| P · **Surveyor's Stone** | One valid cell within 4; two checkpoints | Create one 9-integrity stone-cover cell and reveal eligible magic within radius 1 of it. Hold-eligible as one combined Note; no enemy hit or terrain excavation. |
| S · **Beacon Redoubt** | Two connected valid cells within 4; two checkpoints | Create two cover cells with a shared radius-1 revelation footprint around surviving cells. Hold-eligible as one Note. Destroying a cell removes that cell's cover and light contribution. |
| R · **Bastion of Noon** | Four connected valid cells within 5; wind-up | Raise the marked four-cell cover formation with an open entrance. Each surviving cell reveals eligible magic within radius 1 for two checkpoints; union overlapping areas. No bonus attack, unbreakable wall or persistent construction. |

**Counter / aftermath:** destroy a segment, approach from outside its sight lines or
dispel the combined Note. Broken mundane walls behind it remain broken when it expires.

## Sul + Mozh — distance 4

**Playstyle:** expose a target's condition, then choose attrition or a visible finite conversion.
**Read:** bright fault lines become dusty violet flecks; a claimable source has one
small, countable spark rather than an endless stream of energy.

| Form / working | Reach / duration | Concrete effect and limit |
|---|---|---|
| P · **Faultlight** | One enemy or one eligible source within 4 | Attack mode: power 9 with weak Exposed/Decaying. Conversion mode: consume one eligible source for 9 Breath to the caster, capacity-clamped, and reveal eligible magic at its cell for two checkpoints; no creature attack in that mode. |
| S · **Witness of Ruin** | Fixed center within 4, radius 1; two checkpoints | Reveal eligible magic; choose up to two original eligible sources in the area. Convert one declared source at each of the next two checkpoints, at most 18 total Breath to the caster. Hold-eligible for revelation only; source conversion schedule cannot freeze, repeat or refill. |
| R · **Testament of Dust** | Center within 5, radius 1; wind-up | Apply weak Exposed/Decaying with normal hits and zero initial HP damage to ≤4 declared enemies; convert ≤3 original eligible sources, at most 27 Breath to the caster. A creature killed by later decay is not an additional selected source. |

**Counter / aftermath:** leave the marked area, move or consume a selected source,
remove the Note or interrupt the caster. Revelation grants no automatic critical hit;
conversion cannot erase an essential quest object or claim a living creature.

## Sul + Khash — distance 3

**Playstyle:** fire that makes both the victim's magic and the affected ground readable.
**Read:** a white core sits inside amber flame, with a sharp edge marking damage cells.
Bright presentation never obscures enemy response cues.

| Form / working | Reach / duration | Concrete effect and limit |
|---|---|---|
| P · **Lantern Spear** | One enemy or combustible object within 5 | Attack: power 18 with weak Exposed/Burning. Object: 9 thermal integrity damage and eligible ignition. Either mode reveals eligible magic at the impact cell for one checkpoint; the object mode has no actor hit or tile-charge detonation. |
| S · **Cresset Line** | Three cardinal contiguous cells within 4; two checkpoints | Create the ordinary Firebreak line plus revelation of eligible magic in its cells. One hold-eligible Note; inherit Firebreak's hazard ledger and object ignition with zero initial object impact. No separate arrival explosion or repeated hostile Exposed. |
| R · **Dawn Pyre** | Three fixed cells within 5; wind-up | Release power 18 per unique creature with weak Exposed/Burning, or 9 thermal integrity damage per eligible object, plus ignition. Reveal eligible magic within radius 1 of the surviving marks for one checkpoint. No ongoing fire line is created by the release. |

**Counter / aftermath:** move off the marks, interrupt, quench or take cover. Revelation
does not make stone combustible; physical ignition and destruction persist independently
of the light window.

## Sul + Zhem — distance 2

**Playstyle:** inspect and dismantle a specific magical preparation without an HP attack.
**Read:** a white contour identifies the chosen effect; a clean gap closes across that
contour on removal. The preview names which effect will end.

| Form / working | Reach / duration | Concrete effect and limit |
|---|---|---|
| P · **Name the Silence** | One visible creature/effect anchor within 4 | Reveal eligible properties for one checkpoint, remove one declared eligible buff/Aftertone/working and reset that creature's Tempo if present. Zero HP damage. Selection must already be legal in preview; reveal cannot secretly auto-select a different hidden effect after payment. |
| S · **Quiet Observatory** | Center within 4, radius 1; two checkpoints | Create a hold-eligible revelation field. At initial resolution only, remove ≤3 declared eligible effect ids and reset Tempo on ≤3 declared creatures inside. Holding continues revelation, not removal or Tempo suppression. |
| R · **Unwritten Sky** | Center within 5, radius 2; wind-up | Reveal eligible magic for one checkpoint, remove ≤9 original eligible effect ids and reset Tempo on creatures currently in the marked area, including friendlies. No replacement targets discovered by the release; zero HP damage and no global Balance lock. |

**Counter / aftermath:** move effects/creatures out of reach, break line of sight or
interrupt. Removing a magical fire Note does not quench independently burning timber,
and removing concealment does not delete its caster's physical footprints.

## Vel + Khor — distance 2

**Playstyle:** sustain and reposition a small living obstacle without regenerating it.
**Read:** roots knot around a visible sustain filament; damaged sections stay visibly
damaged when the field moves.

| Form / working | Reach / duration | Concrete effect and limit |
|---|---|---|
| P · **Trellis Hymn** | One eligible owned growth Note within 4 | Establish its hold and grant its one normal capped owned-buff extension if unused. Require a free sustain slot and an existing eligible Note; no new growth, repaired integrity or hostile Overgrown. |
| S · **Pilgrim Roots** | Two connected valid cells within 4; two checkpoints | Create one hold-eligible two-cell growth Note and establish its hold. On the holder's next successful ordinary upkeep only, optionally translate the whole unanchored formation one cardinal cell within 4 of the holder, requiring valid unoccupied cells. Preserve ids, integrity, fuel and duration; the move allowance is spent once. |
| R · **Procession of Boughs** | Four connected valid cells within 5; wind-up | Create four growth cells for two checkpoints. At the first later checkpoint, execute one translation chosen at commitment: zero or one cardinal cell, with all destinations revalidated. If blocked, remain in place. No upkeep or repeat movement, damage pulse, trapping, repair or duration refresh. |

**Counter / aftermath:** destroy growth, anchor it against translation or occupy the
previewed destination. Cancellation clears only the construct; natural fires that it
helped ignite remain on their own finite fuel records.

## Vel + Vekh — distance 4

**Playstyle:** shape cover for an approach, then slow pursuit through a visible thicket.
**Read:** dark leaves shelter a muted interior; the perimeter and obstructing roots
remain visible even when casting identity is concealed.

| Form / working | Reach / duration | Concrete effect and limit |
|---|---|---|
| P · **Briarblind** | One enemy within 4 | Power 9 with weak Overgrown/Blinded. Conceal eligible preparation identity, but show the target/attack cue. No persistent vegetation is created on the occupied target cell. |
| S · **Hollow Thicket** | Two connected valid growth cells within 4, radius 1 around them; two checkpoints | Create a hold-eligible growth/shroud Note. Shroud conceals eligible friendly magical signatures in the union of the surviving cells' areas under ordinary Veil rules. It does not hide physical bodies, collisions or flames. |
| R · **Forest Without Footfalls** | Four connected valid growth cells within 5; wind-up | Create the four-cell growth/shroud formation for two checkpoints. At release, make zero-initial-damage hits on ≤3 declared enemies within radius 1 of its cells, applying weak Overgrown/Blinded. No repeating status attack on entry. |

**Counter / aftermath:** reveal the sheltered magic, burn or cut the growth, or move
away from the formation. This is not Barrow's immunity to revelation or targeting rule.

## Vel + Khash — distance 4

**Playstyle:** commit expendable growth as a short-lived fire obstacle.
**Read:** green veins turn orange before the visible burn footprint appears; each
segment's shrinking stem shows its finite integrity and fuel.

| Form / working | Reach / duration | Concrete effect and limit |
|---|---|---|
| P · **Briarbrand** | One enemy or one owned growth segment within 4 | Attack: power 9 with weak Overgrown/Burning. Growth mode: ignite the existing segment and attach a Firebreak hazard to that cell for two checkpoints, with zero initial integrity/HP hit. Hazard requires that same surviving growth segment; no hidden spread. |
| S · **Kindling Hedge** | Two connected valid growth cells within 4; two checkpoints | Create two growth segments and ignite them, each with the ordinary Firebreak cell hazard. One hold-eligible combined Note; upkeep freezes magical duration but not physical fuel/3-integrity burn ticks. Removing or burning down a segment ends its hazard. |
| R · **Season of Ash** | Three connected valid growth cells within 5; wind-up | Create and ignite three marked growth/hazard segments for two checkpoints. Apply power 9 with weak Overgrown/Burning to ≤3 declared enemies within radius 1 of the formation, at most 27 base power. No damage allocation can repeat on a large creature; line hazards use the shared once-per-round cap. |

**Counter / aftermath:** quench a segment's physical fire to end its attached hazard,
destroy it or avoid the footprint. Expiry/dispelling ends remaining construct hazards.
Conjured growth never yields Mozh Breath or harvest goods; independently ignited mundane
material persists. There is no automatic fire spread between hedge cells or nearby objects.

## Vel + Zhem — distance 3

**Playstyle:** selectively prune hostile preparations while preserving one owned boon.
**Read:** a single root tightens around the chosen magical contour and clips it;
unselected ally buffs retain their original silhouette.

| Form / working | Reach / duration | Concrete effect and limit |
|---|---|---|
| P · **Pruning Word** | One eligible effect and one eligible owned buff within 4 | Remove the declared effect, then extend the distinct owned buff by its normal capped +1 checkpoint. Zero HP damage; no removal/recreation of the buff to reset extension eligibility. If either target is missing at resolution, resolve only the still-valid independent part. |
| S · **Hushroot Garden** | Two connected valid growth cells within 4; two checkpoints | Create one hold-eligible growth Note. At creation only, remove ≤2 declared eligible effect ids whose anchors are within radius 1 of the formation. No ongoing dispel aura, passive debuff cleanse or silence on entry. |
| R · **The Final Pruning** | Center within 5, radius 2; wind-up | Remove ≤6 original eligible effect ids; independently extend ≤3 distinct eligible owned buffs normally. Reset Tempo on ≤3 declared enemies still inside at release. Zero HP damage; ultimate windows, finite pools and previously used extension allowances stay ineligible. |

**Counter / aftermath:** leave the area, cancel the preparation or force a choice
between valuable removal targets. Severing a growth Note does not restore the terrain
beneath it, and Muted is a reset rather than a lasting ban on actions.

## Vel + Zhur — distance 2

**Playstyle:** place a living obstacle beside a usable electrical route, then punish
enemies who cannot move clear. **Read:** visible arcs follow material links between
root silhouettes; disconnected roots never show a misleading live wire.

| Form / working | Reach / duration | Concrete effect and limit |
|---|---|---|
| P · **Nettle Arc** | One enemy within 4 | Power 9 with weak Overgrown/Shocked. No conjured conductor under the target, repeated shock or extra movement tax beyond the named statuses. |
| S · **Wirethorn** | One valid growth cell and an existing route of ≤6 edges within 4 | Create one hold-eligible growth segment for two checkpoints; discharge once along the separately validated route at ≤3 creatures, power 6 each, at most 18 total, with weak Overgrown/Shocked. Holding the root never repeats the discharge. |
| R · **Thunder Orchard** | Three valid connected growth cells and ≤9 route edges within 5; wind-up | Create three growth segments for two checkpoints and discharge power 9 at ≤4 declared creatures on the original surviving route, at most 36 total, with weak Overgrown/Shocked. The route must work without assuming the newly created roots conduct. |

**Counter / aftermath:** break an authored conductive link, leave the route or destroy
the growth. Soaked does not make a creature an unlimited bridge, and there is no persistent
electrical field after the one-time discharge.

## Luth + Tham — distance 2

**Playstyle:** make a quenched defensive pocket and commit resources to people who hold it.
**Read:** water gathers on the sheltered side of temporary stone; a small pool marker
shows undelivered Breath, separately from wet material.

| Form / working | Reach / duration | Concrete effect and limit |
|---|---|---|
| P · **Cistern Stone** | One valid cover cell and one other willing ally adjacent to it, all within 4 | Create one 9-integrity stone-cover cell for two checkpoints and restore up to 6 actually paid Breath to that ally immediately. Cover is hold-eligible; restoration is not repeated by sustain. |
| S · **Sheltered Well** | Two connected cover cells within 4, radius 1 around them; two checkpoints | Create a hold-eligible cover Note. At creation quench ≤2 declared cells in that area and apply physical Wet/friendly Soaked for two checkpoints. Allocate at most 12 paid Breath among ≤3 other willing allies, delivered at the next checkpoint only if still in the area of a surviving cover cell. |
| R · **Harbor Against the Flame** | Four connected valid cover cells within 5; wind-up | Raise the open four-cell formation for two checkpoints, quench ≤4 declared cells within radius 1 and divide at most 24 actually paid Breath among ≤4 original other willing allies still within radius 1. Wet/friendly Soaked last two checkpoints; no refund or reassignment of invalid allocations. |

**Counter / aftermath:** destroy the shelter before its delayed payout, force recipients
out or interrupt. Temporary stone does not dam an entire river, replace a broken bridge,
repair integrity or accelerate a town's rebuilding clock.

## Luth + Vekh — distance 3

**Playstyle:** conceal a recovery handoff while giving enemies a visible area to contest.
**Read:** pale droplets disappear inside a dark, clearly edged veil; recipients' resource
gain stays readable to their own side without broadcasting every preparation detail.

| Form / working | Reach / duration | Concrete effect and limit |
|---|---|---|
| P · **Veiled Draught** | One other willing ally within 4 | Restore up to 6 actually paid Breath and conceal that ally's eligible magical signatures for two checkpoints under Veil rules. The concealment buff is hold-eligible; maintenance cannot repeat restoration. No hostile Blinded/Soaked on the recipient. |
| S · **Mist Refuge** | Fixed center within 4, radius 1; two checkpoints | Create a hold-eligible shroud and quench ≤2 declared cells at creation, with two-checkpoint physical Wet/friendly Soaked. Divide up to 12 actually paid Breath among ≤3 other willing allies at the next checkpoint if still inside. Holding extends shroud only, not quenching or payout. |
| R · **The Unseen Crossing** | Caster-centered radius 2; instant | Create a mobile shroud through the next checkpoint. At commitment, quench ≤3 cells in the area and divide up to 24 actually paid Breath among ≤4 other willing allies inside. The moving shroud does not carry a quench aura or restore additional arrivals. |

**Counter / aftermath:** reveal eligible concealed magic, pressure the refuge or prevent
the initial handoff. This does not teleport the party, hide physical destruction or grant
Barrow's protected concealment and targeting restrictions.

## Luth + Mozh — distance 4

**Playstyle:** combine a paid transfer with salvage from genuinely expendable remains.
**Read:** blue transfer threads and violet source sparks enter separate preview meters;
the source spark disappears permanently when claimed.

| Form / working | Reach / duration | Concrete effect and limit |
|---|---|---|
| P · **Last Draught** | One eligible source and one other willing ally, both within 4 | Consume the source for a pool of 9 and add a transfer pool of at most 6 actually paid Breath. Deliver both to the declared ally, capacity-clamped across their combined total. Unused capacity is not a refund; a missing source does not cancel an otherwise valid paid transfer. |
| S · **Wakewater** | Fixed center within 4, radius 1; next checkpoint | Declare ≤2 eligible sources and ≤3 other willing allies. At the next checkpoint, convert surviving original sources for ≤18 and deliver a separately allocated paid pool ≤12. Each source's recipient allocations are fixed independently; lost sources/recipients reduce payout, never substitute or redistribute. The pending working is not hold-eligible. |
| R · **Confluence of Remains** | Center within 5, radius 2; wind-up | Convert ≤3 original eligible sources for ≤27 and deliver a separate paid pool ≤24 to ≤4 original other willing allies. Each source and the transfer pool have their own declared allocations. Maximum aggregate payout is 51 before capacity and actual-payment clamps; no living targets are damaged or converted. |

**Counter / aftermath:** remove a source, separate recipients from the area or interrupt.
Payment is measured before reclamation: reclaimed Breath cannot retroactively count as
Breath paid, refund overreach or increase the transfer pool. One corpse supplies one
9-point pool across all casters and spells; conjured growth supplies none.

## Luth + Zhem — distance 4

**Playstyle:** put out a dangerous effect without turning safety into a universal cleanse.
**Read:** the chosen magical contour opens, then a thin water ring quenches the marked
cell. The preview distinguishes removed magic, extinguished fire and resource transfer.

| Form / working | Reach / duration | Concrete effect and limit |
|---|---|---|
| P · **Quietwater** | One declared cell within 4 | Quench physical fire and creature Burning there; apply physical Wet and friendly Soaked for two checkpoints. Independently remove one declared eligible effect anchored there and reset the occupant's Tempo. Show allied Tempo loss; zero initial HP damage and no automatic removal of other debuffs. |
| S · **Stillwater Passage** | Three cardinal contiguous cells within 4; instant, Wet two checkpoints | Quench the three cells, apply physical Wet/friendly Soaked and remove ≤3 original eligible effect ids anchored there. Reset Tempo on current occupants once each. Divide up to 12 actually paid Breath among ≤3 declared other willing allies in those cells. No ongoing silence field or repeated transfer. |
| R · **Mercy of the Quiet Sea** | Center within 5, radius 1; instant | Quench the area's cells, apply physical Wet/friendly Soaked, remove ≤6 declared eligible effect ids and reset Tempo on all current occupants, including allies. Divide at most 24 actually paid Breath among ≤4 other willing allies in the area. No HP heal, Soul gain, status purge or Balance lock. |

**Counter / aftermath:** place important effects beyond the footprint or force an awkward
choice of allied effects/Tempo. Quenching does not protect against direct fire impact,
and removing a Note does not automatically remove independent physical combustion.

## Khor + Vekh — distance 2

**Playstyle:** carry a sustained concealment screen while preserving its ownership limits.
**Read:** a fine dark tether connects holder and veil; the field edge moves continuously
rather than blinking to hide a dangerous change in position.

| Form / working | Reach / duration | Concrete effect and limit |
|---|---|---|
| P · **Hidden Canticle** | One existing eligible owned concealment Note within 4 | Establish its hold and, if explicitly mobile-eligible and unanchored, attach it to the caster's movement. Preserve remaining duration and id. Require a free sustain slot; no free extension, hostile Blinded or concealment of physical consequences. |
| S · **Traveler's Shroud** | One willing holder within 4, mobile radius 1; two checkpoints | Create one hold-eligible shroud attached to that holder and establish the caster's hold. Maintain ordinary upkeep and ownership; conceal eligible friendly magical signatures inside, with ordinary revelation counterplay. Moving it does not refresh any separate ally buff. |
| R · **Night in Three Places** | Three fixed cells within 5, radius 1 each; wind-up | Create three concealment windows through the next checkpoint after release. Their union conceals eligible friendly magical signatures, without sustain slots. No body invisibility, misleading substitute actor, revelation immunity or transfer of the windows. |

**Counter / aftermath:** dispel or reveal the screen, break the holder's sustain or
leave its protection. A sustained veil cannot hold an expired attack queue in existence
or hide the visible cue for an enemy-interruptible ultimate.

## Khor + Mozh — distance 3

**Playstyle:** sustain a finite reclamation station until another ally can use its reserve.
**Read:** each original source has a numbered violet thread; a spent thread stays gone
even while the station's central tether remains sustained.

| Form / working | Reach / duration | Concrete effect and limit |
|---|---|---|
| P · **Patient Requiem** | One eligible source within 4, fixed radius 1 around its original cell; two checkpoints | Create a hold-eligible collection Note tied to that source. The first eligible other willing ally already inside or later entering the area triggers conversion of the still-valid source, receiving up to 9 Breath. One source claim for the whole instance; sustain extends the opportunity, never replenishes it. |
| S · **Reclaimer's Vigil** | Fixed center within 4, radius 1; two checkpoints | Create a hold-eligible station tied to ≤2 original sources inside. Eligible other willing allies already inside or later entering each trigger one source conversion, yielding up to 9 each, at most 18 total. Each ally can collect once per instance. Holding neither preserves source eligibility nor creates new collection slots. |
| R · **Bell of the Last Watch** | Center within 5, radius 2; wind-up | Establish a station through the next checkpoint after release, tied to ≤4 original sources. Other willing allies collect once each under the station rules, at most 36 Breath total. At release only, apply weak Decaying by zero-initial-damage hits to ≤3 declared enemies still inside. No hold, frozen status duration or new sources from later deaths. |

**Counter / aftermath:** claim or remove a source first, move beyond collection reach,
cancel the station or interrupt. A collecting ally must have Breath capacity, be visible
and within the card's reach of the living caster; its assigned source must still be
eligible, visible, in reach and inside the original footprint. Sources stay unclaimed
until a valid collection: other casters may consume them first. At commitment, order
sources and select willing allied participants; simultaneous occupants resolve in stable
actor-id order, each taking the next still-valid original source. Missing sources yield
nothing; only another already-declared source can serve the next collection. Any excess
over recipient capacity is discarded. No new recipient or source ids can be added later.
Holding the opportunity does not freeze physical decay, grant a new claim or sustain
hostile Decaying. Continuing sustain after all original sources are spent has no benefit.

## Khor + Zhur — distance 4

**Playstyle:** pay for a finite electrical ambush instead of repeating a free lightning spell.
**Read:** countable charge beads sit on a visible route; each discharged bead vanishes.
Spent sections keep their spent appearance if the field is held or moved by another rule.

| Form / working | Reach / duration | Concrete effect and limit |
|---|---|---|
| P · **Waiting Spark** | One visible empty cell within 4; two checkpoints | Create one hold-eligible armed Note with one prepaid power-9 shot and weak Shocked. The first creature entering that cell triggers the normal hit, friend or foe; spend the shot even on a miss. One shot for the entire instance, never one per round. |
| S · **Suspended Circuit** | Original conductive route ≤6 edges within 4; two checkpoints | Create a hold-eligible armed route with two prepaid power-9 shots, at most 18 total. Initial occupants and later entrants are eligible, but each creature can trigger only once per instance. Each trigger spends a shot and applies weak Shocked on hit; no repeat-cast hooks. |
| R · **The Storm That Waits** | Original route ≤9 edges within 5; wind-up | Arm the surviving route at release through the next checkpoint with four prepaid power-9 shots, at most 36 total, and weak Shocked on hits. Resolve current occupants then later entries; each creature at most once and each shot once. Unused shots expire; no hold, extension or extra allied turn. |

**Counter / aftermath:** enter with a different creature, break the circuit, remove the
Note or wait out the finite window. All sides can trigger it. At simultaneous occupancy,
resolve in the route-cell order selected at commitment, then stable actor-id order;
preview which creatures consume the available shots. Before every trigger, revalidate
that the cell is still connected to the original route origin and visible/in range of
the living caster. Broken links disable only disconnected portions; no automatic reroute.
P uses the same visibility/range check without a material route. A spent shot never
returns if the target misses, dies, moves out and back, or the game reloads.

## Tham + Mozh — distance 2

**Playstyle:** hold a firing position while weakening an exposed organic support nearby.
**Read:** stone stays solid grey; only decay-susceptible braces show spreading violet
faults. Structural failure has a distinct silhouette from an actor's damage number.

| Form / working | Reach / duration | Concrete effect and limit |
|---|---|---|
| P · **Graveweight** | One enemy or organic structural component within 4 | Attack: power 9 with weak Weighted/Decaying. Structure mode: 9 integrity damage to one eligible organic component, with no creature hit, elemental detonation or Breath yield. Stone is not eligible merely because Tham is present. |
| S · **Cradle of Ruin** | One valid cover cell and one organic component within 4 | Create one hold-eligible 9-integrity cover cell for two checkpoints; apply 9 integrity damage once to the declared component. No repeat decay pulse during sustain, no harvest of temporary stone and no implied protection from an actual collapse. |
| R · **Pillars to Dust** | Two connected cover cells and ≤3 organic structural components within 5; wind-up | Raise two temporary cover cells for two checkpoints and apply 9 integrity damage to each still-valid original component, at most 27 total. Deduplicate component ids even if several marks touch one beam. Resolve the structure's authored collapse rules; no invented direct creature damage or conversion yield. |

**Counter / aftermath:** interrupt, hide/replace a targeted brace or use decay-resistant
construction. Forecast actual supported collapse and collateral hazards before commitment;
components without an authored structural relationship do not topple adjacent buildings.
Physical failure persists, with rebuilding only where that structure's policy permits it.

## Tham + Khash — distance 3

**Playstyle:** shape a defensible edge with durable cover beside a dangerous fire lane.
**Read:** cool stone silhouettes border orange hazard cells; the wall itself does not
appear combustible or promise immunity to fire attacks.

| Form / working | Reach / duration | Concrete effect and limit |
|---|---|---|
| P · **Kilnshot** | One enemy or combustible object within 5 | Attack: power 18 with weak Weighted/Burning. Object: 9 thermal integrity damage plus eligible ignition. No stone melting, automatic metal deformation or cover creation on an occupied target. |
| S · **Hearthwall** | One valid cover cell and two cardinal contiguous fire cells within 4; two checkpoints | Create a 9-integrity stone segment and an adjacent two-cell Firebreak line as one hold-eligible Note. Cover and fire cells must be distinct. Use ordinary line hazards/ignition with no initial burst or direct object impact. |
| R · **Citadel of Coals** | Three connected cover cells and three cardinal contiguous fire cells within 5; wind-up | Create the marked open cover formation beside the separate fire line for two checkpoints. Each cover cell has 9 integrity; the fire line uses the ordinary hazard ledger. No initial area explosion, extra integrity hit or automatic spreading fire. |

**Counter / aftermath:** use the open approach, quench affected creatures/materials,
destroy cover or remove the fire Note. Douse does not cancel a magical line by itself;
independently ignited timber still needs quenching after the combined Note is removed.

## Tham + Zhem — distance 4

**Playstyle:** retain an anchor of your own while removing the enemy setup contesting it.
**Read:** one stone-ringed tether remains intact while individually selected foreign
contours are clipped. The visual never suggests that every nearby spell is disabled.

| Form / working | Reach / duration | Concrete effect and limit |
|---|---|---|
| P · **Keystone Severance** | One friendly eligible trace and one distinct eligible effect within 4 | Anchor the friendly trace without changing duration, then remove the separately declared effect. Zero HP damage and no hostile Weighted on the friendly recipient. An anchor is not immunity to every form of removal. |
| S · **Quiet Redoubt** | Two connected valid cover cells within 4; two checkpoints | Create one hold-eligible two-cell cover Note. At creation only, remove ≤2 declared eligible effect ids within radius 1 of the formation. No recurring removal aura, entry silence or slowing field. |
| R · **The Unspoken Fortress** | Four connected valid cover cells within 5; wind-up | Raise the open cover formation for two checkpoints, remove ≤4 original eligible effect ids within radius 1 and reset Tempo on ≤3 declared creatures there. Show friendly resets/removals explicitly. No direct HP damage, zone-wide consumption immunity or global Hush. |

**Counter / aftermath:** move effects out of reach, destroy segments, interrupt or target
the combined Note. This does not inherit Vault's encounter-long protected zone; persistent
world structures keep their own damage and rebuilding state.

## Vekh + Zhem — distance 3

**Playstyle:** conceal who dismantled a preparation while leaving the actual loss readable.
**Read:** a dark thread retracts from the selected contour, which visibly breaks;
enemy feedback still identifies the effect that ended.

| Form / working | Reach / duration | Concrete effect and limit |
|---|---|---|
| P · **Anonymous Severance** | One eligible effect within 4 | Remove that effect and conceal the caster's eligible magical signature for two checkpoints. Conceal eligible preparation identity, not the removal result or threat cue. The resulting concealment buff is hold-eligible; removal never repeats. Zero HP damage. |
| S · **Chamber of Omission** | Fixed center within 4, radius 1; two checkpoints | Create a hold-eligible shroud; at creation remove ≤3 declared eligible effect ids in its area. Reset Tempo on ≤2 declared creatures inside once. No recurring suppression, physical invisibility or automatic cleansing of friendly hostile statuses. |
| R · **The Missing Verse** | Center within 5, radius 2; wind-up | Remove ≤6 original eligible effect ids, reset Tempo on ≤4 declared creatures still inside and create a shroud through the next checkpoint. Conceal eligible preparation identity while keeping marks and interruption cues visible. Zero HP damage; no Balance change or permanent loss of learned spells. |

**Counter / aftermath:** reveal eligible concealment, move effects away or interrupt.
Physical evidence and independent fires survive; this cannot erase a witnessed crime,
change NPC memory or hide the absence of a destroyed building.

## Vekh + Zhur — distance 4

**Playstyle:** disguise the source of a quick electrical strike while its route remains fair to read.
**Read:** dim violet preparation turns into a bright, brief discharge; all affected
route cells are visible before commitment even if the caster's identity is concealed.

| Form / working | Reach / duration | Concrete effect and limit |
|---|---|---|
| P · **Muffled Bolt** | One enemy within 5 | Power 18 with weak Blinded/Shocked; conceal eligible preparation identity. No invisible projectile or guaranteed hit from concealment. |
| S · **Shadow Circuit** | Original conductive route ≤6 edges within 4, ≤3 creatures | Power 6 per declared creature, at most 18 total, with weak Blinded/Shocked. Conceal the caster's eligible magical signature for two checkpoints after resolution; that buff is hold-eligible, the one-time discharge is not. |
| R · **Nightstorm Passage** | Original route ≤9 edges within 5, ≤4 creatures; wind-up | Discharge power 9 per declared creature, at most 36 total, with weak Blinded/Shocked. Create a caster-centered radius-1 shroud through the next checkpoint. Preserve visible route/interrupt cues during concealed preparation; no reroute or extra turn. |

**Counter / aftermath:** break connectivity, leave the route, reveal the caster or
interrupt. The shroud does not let electricity cross insulating gaps, pierce opaque
cover or repeatedly strike the same actor through multiple route nodes.

## Mozh + Zhem — distance 2

**Playstyle:** strip a useful magical protection and let bounded decay pressure its owner.
**Read:** the removed contour crumbles into dull flakes; a separate finite decay marker
shows remaining ticks. Neither effect resembles an instant execution.

| Form / working | Reach / duration | Concrete effect and limit |
|---|---|---|
| P · **Unravel Flesh** | One enemy and one eligible effect anchored to it within 4 | Make a power-9 attack with weak Decaying and instant Tempo reset on hit. Independently remove the original declared eligible effect if still valid; a missed attack does not choose a different removal target. No direct max-HP reduction or source conversion. |
| S · **Choir of Attrition** | Center within 4, radius 1; instant statuses | Make zero-initial-damage hits on ≤3 declared enemies, applying weak Decaying and instant Tempo reset on hits. Independently remove ≤3 original eligible effect ids inside. No persistent field or repeated decay applications. |
| R · **Elegy Without Echo** | Center within 5, radius 2; wind-up | Apply weak Decaying/instant Tempo reset by zero-initial-damage hits to ≤4 declared enemies, remove ≤6 original eligible effect ids and convert ≤3 original eligible sources for at most 27 Breath to the caster. Each channel resolves only its original valid targets. |

**Counter / aftermath:** move away, interrupt or remove the preparations before release.
Zhem removal does not automatically cleanse Decaying, and later deaths never become
new conversion targets. Claimed remains cannot return through reloading or rebuilding.

## Mozh + Zhur — distance 3

**Playstyle:** route an attrition attack through usable material and salvage an original source.
**Read:** sharp arcs leave a subdued violet decay marker; salvage appears as a separate
single source spark, not lightning bouncing endlessly between corpses.

| Form / working | Reach / duration | Concrete effect and limit |
|---|---|---|
| P · **Carrion Spark** | One enemy within 4 | Power 9 with weak Decaying/Shocked. The victim's death does not automatically restore Breath, turn it into a conductor or create an additional strike. |
| S · **Ossuary Circuit** | Original route ≤6 edges within 4, ≤3 creatures, one eligible source at a route cell | Discharge power 6 per declared creature, at most 18 total, with weak Decaying/Shocked. After the discharge, convert the separately declared still-eligible source for 9 Breath to the caster. The source is optional; its body/material does not create a missing link. |
| R · **Thunder of the Last Breath** | Original route ≤9 edges within 5, ≤4 creatures and ≤3 eligible sources at route cells; wind-up | Discharge power 9 per declared creature, at most 36 total, with weak Decaying/Shocked. Then convert surviving original sources for at most 27 Breath to the caster. Revalidate the route before striking; no replacement sources from creatures killed by this release. |

**Counter / aftermath:** break the original route, move off it, consume a source or
interrupt. Conversion waits until after the discharge; a source lost during the attack
yields nothing. Only sources still connected to the original route origin may convert.

## Khash + Zhur — distance 2

**Playstyle:** combine one bounded electrical discharge with separately budgeted ignition.
**Read:** a short white-blue arc precedes orange flame at selected combustible surfaces;
the preview never implies that flame itself carries electricity across gaps.

| Form / working | Reach / duration | Concrete effect and limit |
|---|---|---|
| P · **Flashbrand** | One enemy or combustible object within 5 | Attack: one power-18 hit with weak Burning/Shocked, not two power-18 hits. Object: 9 thermal integrity damage and eligible ignition, with no automatic arc to adjacent actors. |
| S · **Arc Furnace** | Original route ≤6 edges within 4, ≤3 creatures and one combustible object at a route cell | Discharge power 6 per declared creature, at most 18 total, with weak Burning/Shocked. Independently apply one 9-integrity thermal hit and ignition to the optional declared object on a surviving connected link. No repeating electrical field or automatic fire spread. |
| R · **The Burning Firmament** | Original route ≤9 edges within 5, ≤4 creatures and ≤3 combustible objects at route cells; wind-up | Discharge one power-9 hit per declared creature, at most 36 total, with weak Burning/Shocked. Apply 9 thermal integrity damage once per surviving original object, at most 27 total, and eligible ignition. Resolve actors and original network validity before object damage; fire never creates a reroute. |

**Counter / aftermath:** interrupt, break connectivity, take cover or quench. Soaked
prevents/removes Burning but does not cancel direct lightning/fire impact or Shocked;
Wet material resists ignition under the ordinary material contract. Remaining physical
fuel burns and persistent structural damage survive the magical discharge's end.

## Boundaries and acceptance examples

The five opposed pairs remain refused in one cast: **Sul/Vekh, Vel/Mozh,
Luth/Khash, Khor/Zhem and Tham/Zhur**. Sequential world interactions remain legal:
Douse may quench an existing Khash fire, and Wither may damage eligible growth without
inventing a permitted opposed hybrid. No new element, patron or starting option is added.

| Case | Required result |
|---|---|
| Last Draught pays 6 Breath; its one source is valid; the ally has room for 11 | Available 15, restored 11. Source claimed once; 4 discarded, no refund or Soul recovery. |
| Confluence pays only 20 of its nominal 24 Breath, has three valid sources and enough recipient capacity | At most 47 restored: 20 paid-transfer + 27 finite-source yield. Reclaimed Breath does not raise actual payment to 24. |
| Wakewater allocates source A's 9 to ally X, source B's 9 to Y, and paid 12 as 6 each; A disappears | X can receive only its paid 6; Y can receive 15, both capacity-clamped. No reassignment of A's missing 9. |
| A held Lantern Spring pays 12, schedules 6 at each of two checkpoints and stays held for five | At most 12 total restoration; only revelation survives beyond the original payout schedule. |
| Suspended Circuit has two shots; the first misses and the second hits | Both shots spent, at most one power-9 hit lands. Further entries, holding and same-snapshot reload produce zero new shots. |
| Reclaimer's Vigil has sources A/B and participants X/Y; X collects, leaves and returns, then Y enters | X receives at most 9 once; Y receives at most 9 from the other still-valid source. Re-entry, sustain and reloading cannot recreate either source or X's collection allowance. |
| A held Kindling Hedge segment starts at 9 integrity with three fuel ticks | Physical burn leaves 6, then 3, then 0 integrity at three eligible checkpoints. Its segment hazard ends at destruction even if magical duration was held. |
| The Burning Firmament reaches four creatures and three combustible objects | At most 36 base creature power and 27 direct object integrity damage in separate channels; later physical burn uses finite fuel. No 63-power creature hit. |

These are specification checks, not runtime test results. Implementation needs explicit
intent, material/source ids, trigger ledgers and snapshot-safe one-time settlement before
these cards can be enabled. The [Triad compatibility packet](triad-spell-cards.md) retains
its separate consumer/adapter gaps; finishing these pairs does not resolve them.
