# Elemental magic: working gameplay design

**2026-09-09 · Gameplay proposal for review.** The nine selectable elements, shared
Khor, unavailable starting patron Maiiam, retained ten-element Wheel and persistent
physical destruction are owner-approved. New spell names, restrictions, material
reactions and progression below are proposals, not shipped behavior or new canon.

## The playable foundation

An element should give the player a recognizable way to solve a problem. Each has
a reliable basic working, a signature tactical decision, and a world interaction.
Deity changes the resource loop used to execute that plan; DRAMGID determines
proficiency. Choosing a god does not grant exceptions to an element's rules.

| Part of a working | What the player chooses or learns |
|---|---|
| Element | The effect's identity and its permitted interactions. |
| Target | A creature, an existing magical effect, a surface or a physical object. Eligibility is explicit. |
| Breadth | Tone, Chord or Triad, subject to the existing Wheel and casting gates. |
| Magnitude | Note, Phrase, Song or Refrain; the authored working defines how scale changes. |
| Cost and aftermath | Action commitment, Breath, any Soul overreach, fizzle risk, and what remains afterward. |

A larger magnitude does not automatically improve damage, radius, duration and
target count together. Author the changed property for each working. Existing
costs and fizzle formulas remain the implementation baseline until tuning is approved.

## Khor: everyone's sustaining technique

Khor is the shared ability to hold a magical Note beyond its natural ending. It
deals no direct damage and does not replace the chosen element's identity.

**Proposed starter rule:** each caster can deliberately sustain one eligible Note
they own. Maintaining it takes an authored action and Breath expenditure each round;
the spell description shows that upkeep before the original cast. This is an initial
capacity proposal, not an existing class-stat change.

| Technique | Proposed behavior | Limit and player decision |
|---|---|---|
| Hold Note | Preserve the remaining duration of one owned, eligible Note through the next upkeep checkpoint. | Spend the current action on preservation or use a different action and let normal expiry resume. |
| Release Note | End the deliberate hold; the effect resumes its ordinary expiry behavior. | No damage burst or resource refund is granted by releasing it. |
| Carry the Note | Advanced training allows a specifically mobile sustained effect to follow its caster. | An anchored or location-bound effect remains where it was cast; this is not permission to drag a wall. |

Missing upkeep, incapacitation or death breaks the deliberate hold. Breaking the
hold resumes the remaining duration; it does not reset it to full. Zhem can end an
eligible held effect outright. Simultaneous sustain capacity and exact upkeep costs
must be tested before advanced mastery adds more maintained effects.

Keep three ideas distinct: **Khor sustains eligible Notes; Vel extends the caster's
own buffs; Tham anchors Aftertones.** Anchoring is not indefinite duration. Physical
fire, ordinary rubble, spent corpses and elapsed rebuilding time are not Notes.
Founding's existing special duration-freeze effect remains a distinct Triad exception.

Universal Khor access does not bypass Harmony, mastery or composition gates. A
character can learn the shared sustaining technique without receiving every Khor
Chord or Triad at character creation. It remains on the ten-element Wheel.

## The nine elemental jobs

The status names and core identities are established; the spell forms and operational
details in this table are proposed. These are initial working names, not final spell lists.

| Element / status | Basic working | Signature working and decision | World working and boundary |
|---|---|---|---|
| **Sul — Exposed** | **Unveil:** reveal eligible hidden magical properties on a visible target. | **Witness Light:** maintain revelation over a chosen area; decide where information will matter before allies commit. Sul reveals an existing weakness rather than manufacturing one. | **Read the Trace:** inspect illusions and magical remnants on an object or place. Opaque walls and undiscovered rooms remain opaque; revelation is not unrestricted map knowledge. |
| **Vel — Overgrown** | **Briar Touch:** apply the authored growth imposition to a creature. | **Cultivate:** extend one of the caster's own eligible buffs, up to its authored extension ceiling. Decide which preparation is worth preserving; repeated casts cannot build infinite duration. | **Rootwork:** grow vegetation from an eligible living substrate to obstruct a route. It needs a material/footprint rule and does not conjure stone or repair a destroyed building. |
| **Luth — Soaked** | **Douse:** apply Soaked to a creature or wet a separately eligible surface. | **Second Breath:** restore another character's casting Breath. For the first prototype, total restored Breath cannot exceed Breath actually paid by the caster; it redistributes capacity at an action cost. | **Quench:** stop burning on a reachable, eligible object. Prior structural damage remains. Luth restoration does not restore HP or Soul by default. |
| **Tham — Weighted** | **Ballast:** apply the authored weight imposition to a creature. | **Anchor:** secure an eligible Aftertone against the existing unanchored-consumption rule. Protect a setup instead of immediately spending it. | **Raise Cover:** create temporary cover in a legal, unoccupied footprint. It must agree with navigation and sightlines and expires as authored; permanent terrain creation is outside this initial working. |
| **Vekh — Blinded** | **Veil:** obscure an eligible casting signature. | **False Read:** conceal the preparation of a chosen working while preserving the tells needed to respond to its actual manifestation. Decide which commitment benefits from secrecy. | **Shroud:** conceal eligible magical signatures in a bounded area. Concealment does not delete physical collision, ordinary sound or visible structural damage. |
| **Mozh — Decaying** | **Wither:** apply the authored decay imposition to a creature. | **Reclaim:** irreversibly consume eligible remains or an expendable object for a finite Breath return. Decide whether that resource is worth losing the object and its other uses. | **Rot the Brace:** degrade a susceptible structural component. Material loss can change support and paths; stone is not automatically susceptible because wood is. |
| **Khash — Burning** | **Kindle:** apply the authored burning imposition or ignite an eligible material. | **Consume Aftertone:** trade an eligible unanchored Aftertone for the existing burst benefit on a damage-bearing composition. Spend magical preparation now or preserve it for later. | **Burn Through:** maintain ignition until a combustible obstacle loses integrity. Ignition, continuing combustion and collapse are separate states; fire does not make every material destructible. |
| **Zhem — Muted** | **Quiet:** zero the target's Tempo through the existing rule. | **Sever:** end eligible buffs or Aftertones, including a sustained Note. Remove a valuable setup without direct elemental damage. | **Unmake the Working:** cancel a magical field or temporary construct whose lifetime depends on that working. Ordinary fire and rubble remain physical consequences; ending magic cannot reconstruct a ruin. |
| **Zhur — Shocked** | **Arc:** apply shock through a damage-bearing lightning working. | **Sure Current:** use Zhur's established Instability-die exception when uncertainty matters. It does not guarantee a hit, ignore every fizzle source or automatically grant a stun. | **Conduct:** route a specifically authored lightning effect through a connected conductive surface. Preview the route and affected targets; Soaked alone does not create an infinite chain across the battlefield. |

**Luth economy proposal:** the initial redistribution rule makes self-restoration
unprofitable and prevents two Luth casters generating Breath by exchanging casts.
Soul overreach does not count as Breath paid for this restoration allowance. A later
net-positive replenishment spell needs an explicitly finite source or allowance;
it cannot be introduced as an unrestricted reusable conversion loop. Mozh instead
can produce a net Breath return because the eligible physical source is consumed.
No elemental working grants Soul; the existing Agreement-only recovery rule remains.

Damage capability is not an instruction to damage every target. A support working
such as Second Breath must explicitly suppress direct damage even though Luth can
also author attacks. The current composition-level damage permission only prevents
utility-only compositions from gaining damage; per-working intent needs its own
acceptance checks before these mixed attack/support spell sets are implemented.

## What changes, and what survives

| State | Example | Lifetime and cancellation rule |
|---|---|---|
| Creature imposition | Soaked, Burning, Weighted | Defined by the creature effect. It does not silently apply the same condition to the tile or clothing. |
| Note / Aftertone | A held support effect or anchored magical trace | Follows its authored duration and eligibility for sustain, anchoring, consumption or severing. |
| Elemental tile charge | A charged combat tile and its Clash reaction | Uses the existing charge/Weather/Hush rules. Charge is not a material simulation. |
| Active magical world effect | A sustained shroud or temporary cover construct | Can end through expiry or an eligible cancellation rule. Its removal updates the physical footprint if it had one. |
| Physical world state | Wet wood, burning timber, damaged masonry, rubble | Changes through explicit material rules. Structural destruction persists across combat and saves. |

A material effect caused by magic can survive the spell. Khash igniting ordinary
timber leaves a physical fire; stopping magical input is different from extinguishing
the timber. Tham's proposed temporary cover is explicitly a maintained magical
construct, so its expiry can remove that construct. Neither event restores a
previously destroyed building. Maintained structures use their authored rebuild
timers; abandoned sites require an explicit story restoration.

## Initial reaction rules to prototype

These are proposed sequential interactions. They do not authorize otherwise illegal
spell compositions, and they do not add automatic reactions to every contact.

| Sequence | Proposed result | Counterplay / limiting condition |
|---|---|---|
| Khash → dry, combustible object | Ignite it; subsequent authored burn ticks reduce integrity. | No ignition on a material marked noncombustible. Initial fire damage and later ticks must be distinguishable. |
| Luth → burning, quenchable object | Extinguish the physical fire and apply its authored wet state. | Damage already taken stays. Reignition must overcome the material's wetness rule. |
| Luth → conductive surface → Zhur | A connected, eligible wet surface permits the authored conduction route. | Propagation requires explicit connectivity and a finite range/target cap; allies on the route are shown before commitment. |
| Vel → eligible ground | Growth creates its authored obstruction. | Footprint cannot be created through an occupied actor; substrate eligibility is explicit. |
| Khash → combustible Vel growth | Burn the physical vegetation if that growth is marked combustible. | A growth buff on a creature is not automatically a patch of flammable terrain. |
| Tham → Aftertone → Khash | Anchoring protects the Aftertone from Khash's existing unanchored-consumption channel. | This does not grant fire immunity to the target or the terrain. |
| Vekh → hidden signature → Sul | Reveal an eligible concealed signature within the revelation rules. | Sul provides information, not automatic cancellation of the concealed working. |
| Khor → sustained effect → Zhem | Sever an eligible effect despite its deliberate hold. | Khor can preserve an effect's time; it does not make that effect immune to removal. |
| Mozh → eligible remains | Consume the source once and restore its authored Breath amount. | Stable identity prevents harvesting again after save/load or travel. Essential quest objects are ineligible unless specifically authored otherwise. |

For predictable chain reactions, the preview must distinguish the initial cast from
later burn ticks, propagation and collapse. Any uncertain outcome is shown as uncertain;
the player does not receive a false exact forecast. Global Hush continues to suppress
elemental charge behavior; it does not extinguish physical fire by implication.

## Composition and progression

Keep the existing two independent axes: **breadth** controls elemental composition,
while **magnitude** controls the authored scale. Khor is shared access, not an extra
free element attached to every cast. Chords still obey adjacency/strain rules;
Triads keep their defined center, span and unique effect. An unsupported composition
is refused before costs are paid. Sequential cast interactions are a separate system.

| Learning stage | Player lesson | Playable proof |
|---|---|---|
| Chosen Tone + shared Khor | Use an element's basic job and decide whether a support Note deserves upkeep. | Preserving one effect visibly trades away another action. |
| More workings in the chosen element | Distinguish an attack, a support effect and an object interaction. | Luth can attack with an authored attack, help an ally without damaging them, and quench an object through different target rules. |
| Chords at the established unlock | Combine rule bends without granting every element to every character. | A legal composition displays its costs, selected effects and added risk. |
| Triads at the established unlock | Prepare for a center-defined effect and a specific exceptional payoff. | A Khor- or Zhem-centered utility Triad remains non-damaging even if a wing can attack. |
| Advanced Khor and elemental mastery | Improve execution within explicit limits. | Additional sustain capacity or mobile effects are earned and priced, rather than silently granted at character creation. |

## First implementation slice

Use the existing isolated barricade yard to exercise **Khash → Luth → persistent
damage**. This provides a small complete world interaction before adding spread,
conduction, movable constructs or generic structure-targeting across the campaign.

1. Author dry timber as combustible and a stone control object as noncombustible;
   define exactly which working can target each object.
2. Give ignition a visible continuing state and a disclosed integrity-loss schedule.
3. Let Luth stop that fire while retaining the already-lost integrity.
4. Save, leave and reload the yard; damage remains, with existing recovery policies
   applied only to structures that have them.
5. Verify the same cast preview and committed result, including rejected targets,
   action/resource costs, quenching before collapse and a ruined object's footprint.

Before coding that slice, author the burn tick amount/interval, wet duration and
reignition threshold, action/Breath costs, target range and ongoing-fire behavior
while unloaded. These values are intentionally not borrowed from unrelated combat
damage or wall-clock timers. Visual acceptance: intact, burning, wet, damaged and
ruined states remain distinguishable at normal gameplay zoom.

## Implementation status and source boundaries

Already implemented: composition and casting gates; resource spending and fizzle;
several Aftertone interactions; tile charge/Clash/Weather/Hush; utility-composition
damage guards; patron resource loops; persistent destructible barricades and recovery.
See [resolution coverage](../element-resolution-integrity.md),
[class completion](../class-completion.md) and
[persistent structures](../persistent-structures.md).

Not implemented by this document: shared Khor starter access/upkeep, the proposed
spell set, universal creature-status behavior, per-working support damage suppression,
physical ignition/quenching/conduction and any new art or campaign assignment.

Sources: [selection decision and class chart](deity-element-class-chart.md),
[mechanical capability map](../../CAPABILITY-MAP-mechanical-systems.md),
[element definitions](../../data/generated/elements.json),
[composition resolver](../../globals/elements/composition_resolver.gd),
[casting gate](../../globals/elements/casting_gate.gd), and
[casting economy](../casting-economy.md). Numeric proposals in the economy document
remain provisional; this design does not ratify them by reference.
