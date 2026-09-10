# Mechanical systems: elements, patrons, spells and a reactive world

**Status:** working capability map and discussion packet, 2026-09-09. The owner
endorsed the interaction direction and confirmed the persistence/rebuilding rules
below. Other new interactions remain proposals, not ratified implementation specs.
**Request:** deepen the mechanical systems and the art that communicates them.
This replaces the opening-route focus of the earlier draft.

**Implementation update:** the opt-in state, save/world-clock and merchant-service
foundation is implemented. A standalone barricade yard now connects four-state art,
saved damage, collision, navigation and safe rebuilding. See
[the playable fixture and API](docs/persistent-structures.md).
The audit below records the pre-implementation baseline; campaign assignments,
spell targets, NPC movement and the broader proposed art remain pending.

The ten patron resource loops are now playable through the existing combat path;
see [class completion and remaining signatures](docs/class-completion.md). The
[deity/element class chart](docs/ideas/deity-element-class-chart.md) now records the
owner-approved nine-by-nine selection structure: 81 proposed specializations, Khor
shared by everyone, and Maiiam unavailable as a starting patron during the kidnapping.
The underlying ten-element Wheel remains intact. Names and techniques remain proposals;
runtime selection and shared Khor progression have not yet been changed.

Element resolution now preserves utility-only compositions through damage bonuses
and patron hooks. Local/global Hush suppresses tile reactions without refusing legal
actions or persisting temporary weather flags. See
[element resolution coverage and remaining work](docs/element-resolution-integrity.md).

The [elemental magic working design](docs/ideas/elemental-magic-systems.md) now develops
shared Khor upkeep, the nine elemental jobs, proposed spell forms, physical reaction
boundaries and a Khash/Luth barricade prototype. These new mechanics are proposals
for review; the document distinguishes them from implemented behavior.

[Spell forms and hybrids](docs/ideas/spell-forms-and-hybrids.md) extends that draft
through Note/Phrase/Song/Refrain progressions, all ten adjacent Chord families and
selected strained hybrids. New effects and ultimate-use restrictions remain proposals;
the existing composition gates, elemental identities and persistence rules are retained.

## The experience to develop

Owner-confirmed direction: the player should learn rules that remain useful across
combat and exploration. A spell can change an enemy, a magical trace, or a physical
object. The consequences should follow from the target and its current state.
Physical destruction survives combat. Some maintained structures can rebuild over
time; an abandoned site does not recover merely because time passed.

The established identity remains: class expresses who the character is;
DRAMGID determines capabilities. Patron resources, discipline tactics and elemental
composition already exist as separate concerns. See
[the DRAMGID architecture](docs/architecture-dramgid.md).

## Capability map for review

These are work boundaries, not decisions to replace the current architecture.

| Stable id | Player-facing responsibility | Foundation / dependency |
|---|---|---|
| `element-workings` | What an element does; how composition, magnitude, costs, aftertones and target attunement affect a spell | Existing composition, casting gate and Resolution |
| `patron-discipline-kits` | How gods/classes change preparation, risk, timing and payoff; how disciplines change tactical positioning | `element-workings`; existing patron hooks and DRAMGID constraints |
| `world-reactions` | How a working interacts with a material, surface, weather or existing magical state | `element-workings`; existing tile charge and weather |
| `terrain-mutation` | What breaks or changes shape; how cover, movement, sightlines and saved world state respond | `world-reactions`; existing field grid and navigation |
| `mechanical-art` | Make targets, preparation, pending effects, reactions and aftermath readable | Consumes the state/events of the other capabilities |

Proposed order: reconcile `element-workings` → try `world-reactions` → extend into
`terrain-mutation`. Exercise two existing patron kits in that first encounter.
Develop `mechanical-art` alongside each interaction so readability is tested early.
Expand the remaining class kits after the shared interactions work.

## Baseline audit before the implementation updates above

| System | Source evidence | Important limit |
|---|---|---|
| Ten-element composition | [CompositionResolver](globals/elements/composition_resolver.gd), [CastingGate](globals/elements/casting_gate.gd), [ElementMatrix](globals/elements/element_matrix.gd) | Compose-time span and target-side affinity are separate calculations. Matrix tuning is provisional. |
| Actor effects and aftertones | [Resolution](globals/combat/resolution.gd) consumes Khash, Tham, Zhem and Khor rule bends | A descriptive rule in the element catalog is not proof that every part of it has an executable effect. |
| Tile memory | [TileState](globals/combat/tile_state.gd) stores charge, Hush, height and cover | Current charge cap is 3; matching source charge adds 10% per level; Clash detonation adds 9 damage per charge. These are current constants, not proposed balance changes. |
| Weather | [Weather](globals/combat/weather.gd) changes matching/opposed tile charge per measure and handles global Hush | This is elemental attunement logic. It does not by itself implement rain wetting wood or wind spreading fire. |
| Ten patron resources | [ClassResourceRegistry](globals/combat/class_resources/class_resource_registry.gd) registers all ten implementations | Registration does not establish that every signature has a complete player-facing spell kit. |
| Physical terrain | [CombatTerrainLayer](world/nav/combat_terrain_layer.gd) authors cover/elevation; the field supplies the grid | No destructible-terrain implementation was identified in the inspected first-party source. Durability, break results and persistent navigation changes need an explicit design. |

## Element identities to preserve

The middle column summarizes [the generated element catalog](data/generated/elements.json).
The last column identifies a question for gameplay authoring; it is not a new power grant.

| Element | Established description | Mechanical question to flesh out |
|---|---|---|
| Sul | Exposed; reveals aftertones, Discord signatures and illusions | Which hidden properties can the player discover before committing an action? |
| Vel | Overgrown; extends the caster's buffs | What makes duration and growth useful in a changing battlefield? Physical vegetation is not yet an assumed implementation. |
| Luth | Soaked; restores Breath | How does Soaked affect eligible targets and surfaces? Keep direct restoration distinct from Mozh's conversion. |
| Khor | Holds notes and extends duration; no direct damage | Which expiring effect is worth preserving, and how is that remaining duration shown? |
| Tham | Weighted; creates cover and anchors aftertones | How does magical cover become a physical obstacle with readable shape and duration? |
| Vekh | Blinded; conceals Discord signatures | What information is concealed, from whom, and what can reveal it? |
| Mozh | Decaying; converts corpses/objects into Breath | Which objects are eligible, what is consumed, and how is repeat harvesting prevented? |
| Khash | Burning; consumes an aftertone for burst power | Which physical materials can burn, and how does ignition differ from aftertone consumption? |
| Zhem | Muted; ends aftertones, cancels buffs and zeroes Tempo; no direct damage | Which magical effects end, and which physical consequences remain afterward? |
| Zhur | Shocked; ignores the Instability die | Would material conduction deepen its role without becoming a second affinity system? |

Do not collapse **actor status**, **aftertone**, **tile charge** and **physical
material** into one label. A Soaked actor is not automatically a flooded tile.
An anchored aftertone is not a stone wall. A magical detonation is not automatically
structural damage. Those links need explicit, understandable rules.

## Make the gods change decisions

These loops are represented in the current resource implementations. The last column
is proposed encounter coverage, not permission to add a new resource channel.

| Patron / class | Existing resource loop | What a useful encounter should let the player demonstrate |
|---|---|---|
| Maiiam / Mirrorblade | Alternating strike/guard maintains Balance; repetition trades safety for stronger hits | Choose between maintaining the rhythm and taking an urgent opening |
| Haeren / River-Mother | Names of saved/fallen allies return Breath once per name per battle | Value rescue and remembrance without farming the same name |
| Kero / Ironbrand | Damage builds Scars; spending arms a guaranteed-hit window | Spend certainty on an important action; do not confuse guaranteed hit with guaranteed critical |
| Stuid / Lensbearer | Spend Clarity to expose a forecast | Pay for information before accepting a dangerous reaction chain |
| Vhorr / Husk-bearer | Damage-over-time ticks build Hunger; qualifying kills return Breath | Plan a sequence of damage over time instead of only immediate burst |
| Vicoar / Flamebinder | Fizzle banks a token that guarantees a later cast | Recover from a real failure; a rejected action must not manufacture a token |
| Ofshütje / Stormbearer | Attribution supplies a hidden outcome draw | Plan around the disclosed uncertainty rather than showing a false exact result |
| Pazzah / Oathclock | Queue effects for future checkpoints | Arrange a future payoff and show when it is pending |
| Fickah / Locksmirk | Retryable Jam and a patron fizzle floor | Interfere with a pending working while preserving the current commit boundary |
| Izhakel / Threadwalker | Bind conditional contracts; react to observed actions | Create a meaningful conditional threat within the existing contact rule |

Class flavor should change the player's decisions about an interaction. New elemental
permissions, new resource payouts for broken objects, and unrestricted discipline
pairings are not assumed by this packet.

## First proposed interaction playground

Use a small isolated test space before changing campaign locations: an existing-style
road segment with ordinary ground, a wooden barricade, a nonflammable stone obstacle,
and room to move around both. This is a mechanics fixture, not new world lore.

1. **Khash and combustible material.** Offer the choice to attack a foe or ignite the
   barricade. Burning and structural failure should be separate visible states.
   Stone provides a useful negative case: a fire effect does not imply every target burns.
2. **Luth and suppression.** Test the proposed ability to wet/extinguish eligible
   material. Stopping the fire does not restore already-lost structural integrity.
   Decide separately whether wetness permits Zhur conduction; do not add it implicitly.
3. **Tham and cover.** Exercise the established cover concept on the same field grid.
   Its forecast, collision, movement and visible footprint must agree. Test the
   occupied-cell case before allowing creation beneath a character.
4. **Zhem and aftermath.** Make the distinction between cancelling a magical effect
   and repairing physical damage explicit. Proposed default: cancelling magic does
   not reconstruct a burnt barricade or erase ordinary rubble.
5. **Class contrast.** Run the same situation with Vicoar and Pazzah. First use their
   already-supported spell actions to demonstrate recovery versus timing. Extending
   those actions to object targets is a separate change, not a free consequence of art.

This fixture should reveal which decisions are fun before broad spell or asset production.
The exact ignition thresholds, damage ticks, spread, durations and repair rules remain
unpriced. No new reaction table or save format is approved here.

## Art tied to those mechanics

Use [the approved world-art style](docs/art-aesthetics-bible.md). The
[patron aesthetic guide](design/god-aesthetic-style-guide.md) is a working draft,
so its individual motifs are references for review rather than newly ratified requirements.

| Visible state | Required information | Candidate treatment for review |
|---|---|---|
| Target before casting | What it is, what can be affected, and the footprint involved | Readable material and silhouette; concise inspect text for mechanical properties |
| Spell preparation | Element, area and commitment | Element glyph/shape with the existing element color; keep affected cells legible |
| Patron contribution | Which special resource or pending effect is relevant | One secondary patron motif; it must not obscure the underlying elemental effect |
| Continuing reaction | What is active and whether it is escalating or ending | Distinct wet/burning/charged/damaged states, supported by labels or symbols |
| Aftermath | What now blocks movement or sight and what was actually removed | Broken silhouette/rubble matching the gameplay footprint; no persistent invisible wall |

Begin with one barricade's intact, burning, damaged and broken states plus a wet
treatment. Reuse current spell and patron assets wherever they already communicate
the result. Validate at normal gameplay zoom, including overlap with actors and tile
highlights. This is a proposed asset list; nothing was generated in this pass.

## Owner decision: destruction and rebuilding

Confirmed in conversation, 2026-09-09:

1. **Physical destruction persists after combat.** Ending a battle does not restore
   a destroyed object or building.
2. **Some structures rebuild over time.** This mainly applies to maintained
   infrastructure and town buildings where people congregate.
3. **Abandoned structures stay ruined by default.** An isolated abandoned temple
   does not receive an automatic rebuild countdown.
4. **Unexpected restoration is story material.** If that temple is rebuilt, an
   authored quest or world event should explain it and can make it a quest hook.
5. **Temporary relocation is selective.** Some displaced shopkeepers can operate
   elsewhere during rebuilding; others remain unavailable. Do not relocate every
   merchant automatically. Individual assignments remain to be authored.

These rules concern a structure's physical recovery. They do not grant new spells,
set repair durations, or decide whether any particular canonical building is destructible.

### Proposed recovery policies

| Policy | Intended use | What can restore it |
|---|---|---|
| Maintained / timed | Selected occupied-town buildings, communal structures and maintained infrastructure | Its authored rebuilding interval, subject to authored eligibility |
| Abandoned / no automatic recovery | Isolated ruins, deserted temples and infrastructure nobody maintains | Nothing from elapsed time alone; an explicit story transition can change this |
| Story restoration | A ruin being reclaimed, a temple occupied by a new group, or a quest-funded repair | The specific quest/world event; a timer may follow if that event starts construction |

Assign the policy explicitly to the structure. Location alone is insufficient: a
ruin inside town can still be abandoned, and a remote bridge can have maintainers.
An NPC walking out of view must not change ownership or reset construction progress.
This does not require a simulated labor or materials economy in the first version.

### Proposed timer behavior

Use the existing [WorldClock](globals/world_clock.gd): four world phases per day,
advanced by declared travel and quest events. It is separate from combat's CT and
weather measure. [SaveGame](globals/save_game.gd) already persists that clock.
The reconstruction system itself does not exist yet.

Record the destruction state and authored recovery progress/deadline against a
stable structure identity. Unloaded locations must advance consistently with the
same world clock. Loading a save, reopening a map, ending combat, waiting in a menu
or changing the computer clock must not create extra repair progress.

Repair durations are still a tuning decision. An interval of world days is not an
estimate of real minutes: progress depends on the game's declared clock events.
If a maintained structure loses eligibility, the eventual spec must define whether
progress pauses; this packet does not silently add a settlement simulation.

### Proposed physical and visual progression

**Intact → damaged → ruined → rebuilding → restored.** The abandoned policy stops
at ruined until a story event explicitly changes it. A restored building becomes
its functional intact state while retaining whatever destruction history the
consequence systems require.

| State | Gameplay meaning to specify | Art needed for review |
|---|---|---|
| Damaged | Existing footprint may remain; remaining integrity is inspectable | Cracked/scorched material and a readable damaged silhouette |
| Ruined | Broken footprint, access and remaining cover reflect actual debris | Collapsed sections and rubble; preserve the object's identity |
| Rebuilding | Authored temporary access/obstruction and service availability | Scaffolding, fresh materials and partial reconstruction |
| Restored | Functional footprint returns when placement is safe | Repaired silhouette, with optional patches or fresh masonry |

A rebuild must not materialize a wall around an actor. Visuals, collision, cover,
navigation and any affected entrance must change together under the eventual
terrain-mutation contract. A restoration must not respawn original loot or reset
quest rewards. Service relocation follows the owner-confirmed selective policy
below; it is not an automatic consequence of swapping a sprite.

### Selective service relocation

Owner-confirmed: some shopkeepers relocate temporarily, but definitely not all.
Keep each NPC's relocation choice separate from the building's recovery policy:
a building can rebuild even when its merchant offers no temporary service.

Proposed authoring choices, with no NPC assignments or prices decided here:

| Service behavior | During rebuilding | Example rationale, not new canon |
|---|---|---|
| Temporary relocation | Operates at an explicitly authored safe location | Portable goods and an available market stall |
| Suspended service | Remains unavailable until its premises are usable | Depends on a forge, kitchen, secure storage or other fixed equipment |

A relocated NPC should remain the same merchant: retain identity, inventory,
quest state and dialogue history. Returning home must not duplicate the NPC,
restock rewards, or leave an active shop at both locations. Service availability
and map presentation must agree across travel and save/load.

For suspended services, provide a clear closure/repair cue at the old premises.
A temporary stall should make the displacement visible. Reduced inventory,
alternate living arrangements and quest-specific exceptions are possible later
content decisions; selective relocation does not automatically introduce them.

First service check: author one relocating merchant and one suspended merchant,
verify their different availability during repairs, then confirm each resumes
normal operation once its building is usable. These are future acceptance targets.

### First verification slice

Use two test structures with identical damage behavior and different recovery
policies: one maintained barricade and one abandoned ruin segment.

1. Destroy both; end combat, travel away, save and reload. Both remain destroyed.
2. Advance declared world time to just before the maintained structure's deadline.
   Its recovery is incomplete; the abandoned structure is unchanged.
3. Reach the deadline. The maintained structure restores once, subject to safe
   placement. Its art and navigation agree, including when its map was unloaded.
4. Advance more time. The abandoned structure remains ruined. An explicit test
   quest event can start its restoration; replaying that event does not duplicate it.
5. Reload at each stage and test destruction during rebuilding. Progress cannot
   duplicate rewards, unexpectedly reset, or resurrect an older reconstruction job.

These are acceptance targets for a future implementation, not tests run in this pass.

## Remaining scope decisions

| Decision | Candidate default to discuss | Consequence |
|---|---|---|
| Where interactions apply | **Owner confirmed:** shared combat/exploration direction | Exploration still needs explicit cost, time and targeting behavior; combat turns cannot silently become free casting |
| What can be destroyed | Material-tagged authored objects first | Gives consistent rules without promising arbitrary terrain deformation |
| What persists | **Owner confirmed:** destruction survives combat; selected maintained structures rebuild, abandoned sites do not automatically recover | Requires structure recovery policy and world-state persistence; temporary magic retains its own expiry rule |
| What the player knows | Forecast known direct results; disclose uncertain or hidden branches | A preview must not reveal hidden targets or patron draws accidentally |
| How far reactions propagate | Bounded, deterministic chains with recorded causes | Controls runaway reactions, repeated rewards and replay divergence |

Unconfirmed defaults remain proposals. Campaign gates, unique quest objects, rewards for
environmental kills, occupied tiles and friendly fire need explicit handling in the
eventual module specs. Do not resolve those questions through visual asset choices.

## Existing disagreements to resolve before implementation

1. `TileState` still cites a block on authoring the element matrix, but the runtime
   matrix was implemented in `fba5d14e`. The old comment must not be used as proof
   that target-affinity behavior is absent, or as approval for physical reactions.
2. The two compatibility sheets and `ClassCatalog` describe different historical
   states. The runtime catalog records a retired Threadwalker/Chordblade pairing.
   Reconcile with current canon before assuming all thirty pairings are available.
3. The patron art draft describes Haeren as recovering Gauge; the current resource
   implementation and class-resource contract return Breath and forbid Soul refunds.
   Mechanical copy and visuals must follow the current resource contract.

## Evidence and handoff

This pass inspected source, generated catalogs, design notes and relevant history.
It did not run the game, tune numbers, generate images or change gameplay.
The catalog describes ten elements; all ten patron implementations are registered;
the inspected combat-action directory contains eighteen action resources. These are
inventory facts, not playability or completeness claims.

Next review: have Claude reconcile the confirmed persistence/rebuilding rules and
proposed world-clock behavior with the current architecture, then write the first
bounded module spec.
The first playable acceptance target is one spell changing one authored object,
with an honest forecast, readable resulting art, correct navigation and the chosen
persistence behavior. Expand from that verified interaction.
