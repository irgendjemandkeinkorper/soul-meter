# What combat still needs

**2026-09-10 · Repository-grounded design review.** Recommendations below are proposed
next work, not new approved mechanics. The spell catalog now has 170 named forms,
but completing that design inventory does not make the full combat system playable.

**Design continuation, 2026-09-10:** the [martial/defensive rules](martial-combat-rules.md),
[27 weapon action cards](martial-action-cards.md) and
[mixed encounter fixture](martial-combat-encounter.md) now flesh out the first two
areas and a bounded example of enemy/objective integration. These are proposed
contracts and art cues; the runtime gaps and broader progression work below remain.

**The strongest next design step is weapons and defensive actions.** We have detailed
choices for casting; the next question is what a character can meaningfully do with
a weapon, a shield, positioning and preparation between casts.

## Five remaining areas, in recommended design order

| Priority / area | Existing foundation | What still needs fleshing out | A concrete completion check |
|---|---|---|---|
| **1. Weapons, armor and martial techniques** | Strike, Defining Strike, Guard, damage/defense calculations, cover and flanking already exist. | Give weapon families distinct jobs: reach, target patterns, commitment, armor interaction and utility. Define how equipment and DRAMGID proficiency support the patron/element build. Decide which techniques can carry elemental effects, with explicit costs and limits. Critical hits, stagger, disarm or weapon durability are candidate decisions, not assumed features. | Put a spear, a shield-bearing fighter and a bow user in the same encounter. Each has a situation where its choices are useful, without relying on a different spell list or a larger damage number. |
| **2. Defensive counterplay and action timing** | Guard, movement, positional defenses and specific cancellation tools such as Fickah's Jam exist. New Refrain cards describe interruption windows. | Finish the general response rules: which threats can be blocked, avoided, interrupted or resisted; whether to add bracing, parrying or prepared attacks; who pays and when. Define forced movement, collision and ledge behavior if introduced. Establish boss/control resistance and protections against repeated loss of turns. Keep friendly fire and hazard eligibility visible. | For each major threat, the player can identify a useful response before committing. Reaction chains terminate; a response never grants an unpriced extra turn or repeatedly taxes an already committed action. |
| **3. Enemy kits, cooperation and encounter objectives** | Enemy positioning AI already considers cover/high ground; same-map sessions and reinforcement admission have implementation and tests. | Author enemies that use the new mechanics: defenders protect casters, disruptors threaten holds, scavengers compete for finite remains, and mobile enemies change routes around fire. Design readable boss commitments and recovery openings. Extend encounter content with protection, escape, ritual interruption or territory objectives where appropriate. Morale/surrender are optional extensions, not prerequisites. | A small enemy group presents a readable plan and changes its behavior when cover breaks or a route becomes dangerous. The player can win an authored objective without every encounter requiring the same kill order. |
| **4. Build progression, recovery and encounter endurance** | Patron resource loops, Breath/Soul boundaries, hollowing and retreat rulings already exist. Some patron signatures remain explicitly unimplemented. | Finish the path from starting kit to advanced forms: technique unlocks, mastery requirements, equipment choices and any prepared-spell limits. Set the intended HP/Breath recovery loop and consumable role across several fights. Complete the relevant patron signatures. Reconcile level/perk cadence and enemy tuning decisions still marked open in the inspected identity packet before treating them as settled. | A starting character and a developed character both have coherent, affordable turns. A sequence of fights tests different resource decisions. Recovery cannot manufacture Soul, reset finite source claims or bypass advanced Khor mastery. |
| **5. Spell/terrain integration, readable feedback and balance proof** | The spell design packet, combat forecasting, existing elemental resolution and persistent-structure yard provide separate foundations. | Implement the new target intents, statuses, holds, finite source claims, traps, material fire and temporary constructs through preview and resolution. Reconcile the documented Triad gaps. Show target eligibility, status duration, hazard footprint, cast timing and lasting structural consequences with shapes/symbols as well as color. Test the combined encounter under the supported scheduler paths. | The forecast agrees with the result, enemies respond to the changed battlefield, temporary magic expires correctly, and physical destruction survives combat/travel. Ending or reloading state cannot duplicate rewards, source yields or one-use effects. |

The fifth area is the **largest implementation dependency**. The first two are the
best next **design** work. They can be specified while the existing Kindle/Douse
prototype remains the first bounded implementation slice.

## Decisions worth making concrete

For weapons, start with the decisions a player faces. A spear could trade close-range
flexibility for reach and a prepared approach defense. A heavy weapon could commit
more time to damaging a susceptible brace. A shield could protect a specific direction
or ally at an explicit action cost. These are examples to evaluate, not confirmed
mechanics. None should grant an elemental spell or patron ability simply by equipping it.

For defenses, define the response to a visible ultimate, an ordinary attack, a
continuing damage effect and an environmental collapse. Those are different threats.
For example, guarding might help against a weapon hit while leaving the actor exposed
to a burning tile; moving could escape the tile but spend the opportunity to interrupt
the caster. The intended tradeoffs need cards as concrete as the spell cards.

For enemy design, distinguish a creature's role from its stats. A defender that
protects a narrow route and a hunter that circles temporary cover create different
problems even with similar HP. Each needs limits on what it knows: concealed information
should not become freely available to AI just because the simulation stores it.

For progression, the key unresolved gameplay question is how much of the large catalog
a character can access at once and how they learn it. A known-spell list, a prepared
loadout and a mastery gate are different controls; select the intended controls rather
than accidentally imposing all three. Shared Khor remains a starting common language,
not a shortcut to every advanced Khor technique.

For art, the highest-value missing layer is readable state: a weapon's threatened
space, the defense being offered, an interruptible wind-up, the remaining charges of
a trap, and the difference between temporary magical cover and a damaged town wall.
The spell-family visual notes are direction for that work, not finished combat assets.

## Existing rules to preserve

- **Soul is not HP or ordinary mana.** Zero Soul causes hollowing; Soul returns through
  Agreement, not rest, potions, elemental spells or repeatable class loops.
- **Retreat already has an owner ruling.** Same-map fleeing uses separation from
  living hostiles across the required CT measures. The architecture document's dated
  ruling takes precedence over the identity document's stale open-question entry.
- **Destruction persists; corpses follow a separate policy.** Selected maintained
  infrastructure can rebuild. Abandoned ruins do not automatically recover. The
  same-map ruling despawns downed hostiles on scene exit, so Mozh design must not
  silently introduce persistent physical corpses or restore spent source eligibility.
- **The selection structure is already decided.** Nine starting patrons and nine
  selectable major elements; shared Khor and unavailable starting Maiiam. Completing
  weapon or defensive rules does not replace the deity/element axes or DRAMGID.
- **Resource-loop completion is not full class-kit completion.** Haeren stabilization,
  Stuid's broader telegraphs, Pazzah's additional sentence payloads and Izhakel's broader
  contracts are among the explicitly documented remaining signatures.

## Smallest useful next deliverable

1. Write a small martial-action packet using the spell-card format: weapon role,
   target/reach, action price, effect, defense, counter and terrain interaction.
2. Pair it with a defense/interrupt table covering the same actions and the already
   authored spell wind-ups. Resolve timing once across these examples.
3. Specify one mixed encounter: a defender and caster around a breakable barricade,
   one flanking route, a finite fire source and an objective worth protecting.

The review encounter is ready for implementation when every action and response can
be predicted from these cards without inventing a new rule during play. After that,
expand enemy and weapon content using evidence from the working fight.

**Next two-minute action:** compare the polearm and hammer families in the
[new weapon cards](martial-action-cards.md); their approach-control and terrain-breaking
roles show the intended contrast. The next broader design passes are enemy kits and
progression/recovery, after review of this martial/defensive draft.

## Evidence and limits

This is a source/document inspection, not a fresh gameplay test or an exhaustive
absence audit. Existing test files establish authored coverage, not that a new run
passed. No runtime code, combat balance or UI was changed during this review.

| Evidence | What it supports |
|---|---|
| [CombatAction](../../globals/combat_action.gd), [CombatRules](../../globals/combat/combat_rules.gd), [controller](../../globals/combat/combat_controller.gd) | Existing action kinds, positional modifiers, timing foundations and enemy position scoring. |
| [Enemy grid AI test](../../test/integration/test_enemy_grid_ai.gd), [session tests](../../test/integration/test_combat_session.gd) | Existing authored checks for positional AI, session admission and reinforcement behavior. |
| [Class completion](../class-completion.md) | Playable resource loops and explicit remaining class signatures. |
| [Identity rulings](../game-identity.md), [same-map architecture and dated rulings](../architecture-same-map-combat.md) | Resource/progression boundaries, retreat, corpse lifetime and known documentation disagreement. |
| [Spell catalog](spell-card-catalog.md), [Triad cards](triad-spell-cards.md), [persistent structures](../persistent-structures.md) | Design coverage, unresolved spell integration and the implemented structure foundation. |
