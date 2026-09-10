# Khash prototype: spell cards and material rules

**2026-09-09 · Proposed playtest specification, not implemented or ratified balance.**
This makes the first family in [spell forms and hybrids](spell-forms-and-hybrids.md)
concrete enough to review and prototype: four Khash forms, Luth quenching, shared
Khor sustain, and the three advanced Khor/Khash forms.

## Shared card conventions

Ranges use grid cells with Chebyshev distance, matching the current grid's distance
convention; a diagonal adjacent cell is one cell away. All declared target cells
require the spell's line of sight. A line or footprint is previewed before payment;
none of these cards can target through opaque cover by default.

The AP and CT values below are separately proposed prices. They are not a new
automatic conversion rule. Normal casting gates, fizzle, hit, defense, facing and
elemental multipliers remain. **Power is an input to the existing creature-damage
calculation, not guaranteed HP loss.** Object damage is a separate authored integrity
amount and does not borrow creature affinity/defense modifiers.

Breath prices 3/6/12/24 reuse the earlier economy document's provisional magnitude
ladder for this experiment only. Normal runtime overreach/failure rules remain;
this does not adopt that document's separate proposed Soul-overreach price table.
The current +1 Khash Aftertone burst is retained as a provisional baseline.

## Nine proposed cards

| Working | Form / composition | AP / CT | Breath | Range / shape | Core effect |
|---|---|---|---|---|---|
| **Kindle** | Note / Khash Tone | 2 / 30 | 3 | 4; one creature or object | Creature power 9 plus Burning on a successful hit; or object integrity damage 3 and eligible ignition. |
| **Cinder Spear** | Phrase / Khash Tone | 3 / 45 | 6 | 5; one directed target | Creature power 18 plus Burning; or object integrity damage 9 and eligible ignition. Uses the existing eligible unanchored-Aftertone burst on a creature. |
| **Firebreak** | Song / Khash Tone | 4 / 60 | 12 | Every cell within 4; three contiguous cardinal cells in a straight line | Create a magical fire line for two round checkpoints. Creatures entering or occupying it face the hazard below. Eligible objects are ignited without an additional direct integrity hit. |
| **Crown of Embers** | Refrain / Khash Tone | 4 / 60 | 24 | Three distinct marked cells, all within 5 at commitment | Wind up, then resolve creature power 18 at each mark, apply Burning on hits, and deal object integrity damage 9 with eligible ignition. One hit per entity across the pattern. |
| **Douse** | Note / Luth Tone, utility form | 2 / 30 | 3 | 4; one creature or object | Remove this packet's Burning/physical fire and apply Soaked to a creature or Wet to an object for two round checkpoints. No damage, healing, Breath restoration or integrity repair in this mode. |
| **Hold Note** | Note / shared Khor Tone | 1 / 30 | 1, then 1 per upkeep | 4; one owned eligible Note/field anchor | Freeze its remaining duration through the next checkpoint. The caster has one initial sustain slot; the hold's own upkeep cannot be held. |
| **Held Ember** | Phrase / strained Khor + Khash Chord | 3 / 45 | 6, then normal upkeep | 4; one owned eligible fire Note | Establish the hold and apply a focused creature-power-9 pulse to a declared enemy in that Note's footprint. No new object impact or automatic field creation. |
| **Furnace Choir** | Song / strained Khor + Khash Chord | 4 / 60 | 12, then normal upkeep | Firebreak placement rules | Create Firebreak and establish its hold in one cast. It uses the same one sustain slot and the same per-entity hazard limits. |
| **Unfading Brand** | Refrain / strained Khor + Khash Chord | 4 / 60 | 24; next upkeep included | 4; one already held eligible fire Note | Prepay one round of sustain so its holder can take another action during that round. Does not add a field, an impact burst or a second sustain slot. |

**Khor + Khash is distance 4, a Strained Chord.** Keep its weakened impositions,
composition-reported Vär cost and existing fizzle/gate consequences visible. Universal
Khor access does not remove strain or grant the hybrid technique automatically.
The extra Vär settlement path needs verification before these become runtime cards;
do not silently substitute additional Soul or omit a declared cost.

### Targeting and spell identity

Kindle remains the cheap way to ignite a single obstacle; Cinder Spear trades more
resources for a stronger direct hit and greater reach. Firebreak controls movement
and has no initial creature burst. Crown rewards predicting positions through its
wind-up. It spends more Breath than three Kindles and concentrates a response window
around one large commitment. Its three marks are not three free single-target casts.

All direct Khash creature attacks retain the existing consumption of an eligible
unanchored Aftertone, including Kindle. The current deterministic eligible trace
must be shown in the preview; manual trace selection is not assumed implemented.
Cinder Spear's distinction is its power/reach, not exclusive access to consumption.

Object-only casts in this prototype do not write creature Aftertones or elemental
tile charge. Douse's utility mode also leaves elemental tile charge unchanged and
does not trigger a Clash detonation: it targets a status/material state, not charge.
This requires explicit target intent in the future resolver; setting damage power
to zero alone is insufficient. Normal creature attack charge reactions remain.

Direct creature attacks retain their existing target-relation gates. Firebreak and
Crown's areas affect allies as well as enemies; affected friendlies must appear in
the preview. Douse may help any eligible creature, and never rolls an attack hit to
harm its recipient. It still follows the normal spell fizzle and resource rules.

Firebreak placement requires three valid ground cells. It can run across a
combustible object footprint, but not through opaque noncombustible cover. Creatures
can occupy its cells at placement because it creates a hazard, not a blocking wall.
This is different from Tham's unoccupied-footprint requirement for solid cover.

Held Ember requires an existing eligible Note, a free sustain slot, and the declared
enemy within that Note's actual footprint. It cannot use a physical timber fire as
its Note. An empty footprint cannot satisfy the attack version; use Hold Note when
the player only wants preservation. Upkeep for all held forms is 1 AP or 30 CT plus
1 Breath per round; the commitment UI must disclose both the initial and continuing
cost. Passing a hold to another caster is outside this first prototype.

The different initial Hold Note Breath price is an explicit exception to the
experiment's default Note price. It is a proposal to test affordability of shared
Khor, not an accidental free resource or a global change to all Note spells.

## Creature fire and the magical line

| Effect | Proposed rule | Stacking and counterplay |
|---|---|---|
| Creature Burning | 3 HP loss at each of the next two round checkpoints after application. No same-checkpoint tick on application. | One instance per creature. Reapplication refreshes to two remaining ticks, never adds parallel burn stacks. Douse clears it. |
| Firebreak hazard | 3 HP loss on first entry or occupancy during a round, plus application of Burning. An occupant at successful creation receives that round's one hazard event immediately. | At most one hazard event per creature per round across this packet's overlapping fire lines. Leaving/re-entering or crossing several line cells does not repeat it. |
| Soaked creature | Douse's two-checkpoint Soaked state prevents application of this packet's Burning while active. | Does not grant immunity to the initial fire attack or the magical line's hazard damage. A spell that attacks a wet target can still hurt. |
| Held field | Pause the field's lifetime while valid upkeep is paid. | Holding does not reset per-round hazard tracking, add another impact or create extra burn stacks. |

For these prototype fixed-damage effects, 3 is actual HP loss after eligibility;
the application attack already uses the normal hit/defense calculation. Fixed burn
and line damage do not reroll a hit or receive another affinity/Aftertone multiplier.
They need separate forecast lines so players can see that this damage is distinct
from the initial power-based attack. These numbers and bypass rules need playtesting.

Firebreak can therefore cause up to 6 HP loss in a later occupied round: one hazard
event and one Burning tick, not one event per tile crossed. Leaving the line avoids
later hazard events but does not automatically remove an existing Burning effect.
These caps govern this packet's effects; other future fire effects need explicit
stacking rules rather than inheriting a hidden global cap.

Every damage event identifies its owner, cause and source. Patron hooks must receive
each real event once. Terrain ticks are not new CAST actions and cannot repeatedly
seed new Hunger chains merely because the same object or field continues burning.
Multiple owners' overlapping fields use one disclosed credited source per hazard
event; first-created eligible field wins, with stable source id as a tie-breaker.
Refreshing creature Burning transfers its future tick credit to the latest successful
application. No source receives kill credit or a Breath refund twice.

## Crown's commitment and response window

1. **Commit:** validate all three marks, resources, range and the unused Refrain
   allowance. Pay normal costs and resolve fizzle now. Rejection spends nothing;
   a committed fizzle creates no marks/effects and follows the proposed spent-use rule.
2. **Wind up:** display the marked cells and the caster's tether. Resolve at the start
   of the caster's next scheduled turn. Moving the caster from the commitment cell,
   incapacitating/killing them, or cancelling the pending working interrupts release.
3. **Respond:** enemies can leave the marks, force the caster to move, or use an
   existing valid cancellation capability. Douse can wet a threatened object before
   release, preventing ignition but not the direct thermal integrity hit.
4. **Release:** revalidate line of sight from the original cast position. Occluded or
   now-invalid marks do nothing; do not retarget them. Resolve each unique entity
   once even if its footprint occupies multiple marks. Unoccupied marks can still
   affect an eligible object/surface there.
5. **Settle:** each creature hit can consume at most one eligible unanchored Aftertone
   for the existing +1 power. New traces generated by the release cannot be consumed
   again by that same release. Apply ignition only to eligible targets; persist their
   physical damage. Ending the animation has no repair effect.

Cancellation uses the existing action/cancellation policy for action-cost refunds;
this specification does not override it with an invented all-resource refund.
The prototype needs a clear declaration of which committed spell costs survive
interruption before implementation. A kill before the next scheduled turn must
cancel the pending release, not leave a queue entry waiting forever for a dead actor.

The proposed one-Refrain allowance is shared by Crown of Embers and Unfading Brand
for a character. Khor cannot preserve it or create a second use. Unfading Brand has
no delayed area release; its price buys an action opportunity on an existing setup.

## Physical timber rules

The current yard barricades have maximum integrity 30. Preserve that baseline for
this experiment; do not silently change campaign structures to match the cards.

| Material state | Proposed rule |
|---|---|
| Dry timber | Combustible. Starts with nine finite fuel ticks. A successful eligible heat impact deals the card's direct integrity damage, then ignites it. |
| Burning timber | Loses 3 integrity and one fuel tick at each round checkpoint after ignition. Existing fire is not restarted by repeated heat hits; remaining fuel never refills. |
| Wet timber | Douse ends the current fire and makes it non-ignitable for two round checkpoints. A fire attack's listed direct integrity damage still applies. |
| Ruined timber | Integrity clamps at zero; blocking/navigation use the existing ruined footprint. The first prototype ends damaging combustion at collapse. Cosmetic embers do not create hidden damage. |
| Stone control object | Noncombustible and immune to these cards' authored thermal integrity damage. Other future physical damage channels require explicit authoring. |

Ignition itself adds no extra integrity hit: Kindle applies 3 once, Cinder Spear 9
once, Crown 9 once per unique object, and Firebreak zero. Subsequent physical burn
ticks own the continuing damage. A timber object in a fire line does not also receive
the line's creature hazard damage. A structure cannot detonate elemental tile charge
as an additional structural hit until a separate reaction explicitly connects them.

Directly targeting the stone control with an object-only thermal working is rejected
before costs, with a noncombustible/no-effect explanation. Stone incidentally inside
a valid area cast remains unaffected; it does not invalidate the entire cast. A
ruined object is not a valid new ignition target. Ineligible area targets receive
no hidden hit, residue or resource refund from this physical-object packet.

**Douse cannot permanently switch off an active magical fire line.** It removes
physical combustion and prevents reignition while Wet lasts. After Wet expires, an
active line can ignite timber with fuel remaining again. If the player needs the
line itself removed, the holder can release it or an eligible cancellation working
can end it. Firebreak expiration does not quench independent physical timber fire.

## Checkpoints, travel and saves

Use existing round checkpoints for active combat; do not add real-time timers tied
to rendering, menu duration or the computer clock. Snapshot the effects present at
checkpoint entry, then settle any coincident due cast/cancellation results. Apply
surviving field occupancy/reignition, respecting Soaked/Wet throughout their final
protected checkpoint, then apply surviving ongoing burn ticks that existed in the
entry snapshot. Finally decrement eligible remaining durations and expire them.
A newly created effect never also ages or receives its ongoing tick at that checkpoint.
An existing Burning effect refreshed by the field can still tick once; refreshing
does not turn it into a new effect to evade that tick. Douse removes it before it
can tick. Preserve per-round event tracking and the last processed checkpoint.

For this isolated prototype, unloaded/out-of-combat material time advances only
through declared WorldClock phases. On the first crossed world phase, consume the
remaining finite burn fuel once, stopping at collapse; the phase represents longer
than the remaining combat burn. Wet expires at that phase boundary. Unheld temporary
combat fields and deliberate holds end at combat exit; independent physical fire
remains. Simply ending combat, reopening the yard, or loading the same snapshot does
not advance the world phase or process another burn tick.

On a multi-phase jump, resolve pending material fire at the first crossed phase,
record any ruin at that phase, then advance existing recovery eligibility through
the remaining phases. This makes the result equal to crossing those phases one at
a time. The maintained fixture retains its authored two-phase rebuild interval;
the abandoned fixture does not gain one. Rebuilding restores authored intact fuel
only when the structure is actually restored, never on ordinary save/load.

Persist at minimum stable object identity, integrity, remaining fuel, burning/wet
state and remaining combat duration, the last processed phase/checkpoint, and the
existing recovery record. The exact save-model extension requires implementation
review; no fields or migration are added by this design document.

## Worked examples for review

All examples assume successful application to ordinary timber, no unrelated damage,
and no magical field continuing to reignite it. Actor power examples must additionally
use a declared neutral creature fixture before comparing exact HP numbers.

| Sequence | Expected proposed result |
|---|---|
| Fresh 30-integrity barricade; Kindle; two burn ticks; Douse | 30 − 3 − 3 − 3 = **21 integrity**, seven fuel ticks remain, no physical fire, Wet active. |
| Save and reload that quenched barricade without time advancing | **21 integrity**, seven fuel ticks and the same Wet duration. Loading has no repair or fuel refill. |
| Fresh barricade; Kindle; no response | After the ninth physical burn tick, **0 integrity** and ruined. Navigation opens through its ruined footprint. |
| Fresh barricade; Cinder Spear; no response | 30 − 9 leaves 21; the seventh physical burn tick reaches **0 integrity**. Collapse ends damaging combustion. |
| Fresh stone control; object-only Kindle | Rejected before payment; unchanged integrity and no ignition. |
| Crown marks three cells occupied by one large eligible object | Apply the object's listed **9 integrity hit once**, not three times, then eligible ignition. |
| Timber ignited, then cancelled Firebreak | Magical line gone; physical fire remains and follows its finite fuel/tick rules. |
| Kindle at phase P, leave, advance three phases on the maintained fixture | Material fire ruins it at P+1; the two-phase rebuild becomes eligible at P+3, subject to existing occupancy/combat repair checks. |
| Same three-phase sequence on the abandoned fixture | Ruined at P+1 and still ruined at P+3. |

## Prototype encounters and visible proof

| Encounter | Player decision | What must be visible |
|---|---|---|
| Two barricades, one stone control | Spend cheap ignition and wait, spend stronger impact, or preserve the route with Douse. | Direct integrity loss, next burn tick, remaining damage and the noncombustible control. |
| Enemy crossing an open route | Place Firebreak where avoiding it costs movement; choose whether upkeep is worth the action. | Line boundary, occupied cells, upkeep and one hazard event despite re-entry. |
| Three threatened positions | Predict Crown's release or force opponents to move. | Marks, caster tether, response window, blocked marks and physical ignition afterward. |
| Prepared fire field with another urgent action available | Use the costly strained Refrain to buy a round without maintenance. | Breath/strain cost, one held field, prepaid duration and the shared spent-Refrain allowance. |

Fire art needs separate readable states for magical line, creature Burning, dry/wet
timber, active combustion, damaged structure and ruins. The held-note connection
must point to its magical anchor, not imply that ordinary timber fire depends on
the caster staying alive. At normal gameplay zoom, preview outlines remain visible
under the ultimate's release and burning particles.

## Implementation handoff

Build and validate Kindle/Douse on objects before area hazards, sustain or delayed
Refrains. The existing yard currently provides manual structure damage and recovery;
it does not already cast these cards. Required seams include object targeting and
forecasting, per-working utility intent, material state/persistence, round/phase
catch-up and one-time area/source accounting. Later cards add sustained-field and
pending-release behavior only after that first loop works.

Open tuning items: AP/CT and Breath prices, power/damage values, wet/burn durations,
the Refrain fizzle-use tradeoff, interruption refunds and strain-cost integration.
Numbers above are concrete starting proposals so these choices can be tested;
they are not authorization to rebalance existing live abilities silently.

Sources: [spell forms](spell-forms-and-hybrids.md),
[elemental foundation](elemental-magic-systems.md),
[provisional casting economy](../casting-economy.md),
[current resolution](../../globals/combat/resolution.gd),
[combat rules](../../globals/combat/combat_rules.gd),
[grid targeting](../../globals/combat/grid_battlefield_model.gd), and
[persistent structure fixture](../persistent-structures.md).

Design checks: all nine card names match the progression catalog; the quench and
collapse examples were checked arithmetically. The proposed phase model produces
equal results for a three-phase jump and three single-phase steps, and replaying
the same phase does nothing. These validate the proposal, not an implemented Godot
simulation. Local source links resolve.
