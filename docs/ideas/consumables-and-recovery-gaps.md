# Consumables and the remaining combat gaps

**2026-09-10 · Design assessment, not implemented item effects.**

**Yes: consumables are the next substantial combat layer to design.** Their main
job is to offer a limited, carried answer to a problem: patch a wound, remove a
specific condition, extinguish a fire or buy a little more casting time. Using one
must compete with attacking, defending and moving for the same action budget.

The best next packet is **combat items plus downed/recovery rules together**. A
healing item's role cannot be priced properly until we distinguish healing a living
ally, keeping a downed ally from further consequences and returning someone to action.
Those are different effects; an ordinary poultice should not silently do all three.

## What we already have

Generated item records include **Bitterleaf Poultice**, several foods, and **Lamp Oil**.
Inventory, stacks, buying/selling and loot distribution have existing foundations.
In the inspected first-party sources, these records supply inventory metadata and
flavor; I did not find a general combat-item effect/targeting implementation. That
is a bounded inspection result, not a claim that every possible item path was tested.

Breath already refills through the gameplay-scene-entry flow; the immediate load
from a save skips that refill, and returning from pause/battle is not the refill
event. This is important when pricing restoratives: their immediate use is within
a fight or continued activity on one map. We should evaluate the existing recovery
policy before adding a competing rest/potion economy, not silently replace it.

Soul remains Agreement-only recovery. Food, poultices, stimulants, ammunition and
throwables cannot restore Soul, undo overreach spending or refresh an ultimate-use flag.

## Five useful item groups

These are proposed roles. Names beyond existing inventory records are examples,
not new canon or finalized item cards.

| Group | Examples / tactical job | Boundary to define |
|---|---|---|
| **Field medicine** | Use Bitterleaf Poultice for bounded HP treatment; a separately authored rescue supply could assist a downed ally if the downed rules permit it. | Self versus adjacent-ally use, immediate versus delayed healing, interruption, HP-cap clamping, and whether a target must already be conscious. No universal resurrection effect. |
| **Breath restoratives and provisions** | A finite restorative buys another cast; existing bread/fish can support the out-of-combat recovery layer. | Exact yield, action cost, supply/replenishment and interaction with scene-entry refill. Decide whether any saturation rule is needed after testing; do not add a new meter automatically. No Soul or free ultimate reset. |
| **Specific remedies** | A quenching flask removes Burning; a separately authored rinse or dressing could address a particular physical condition. | Name the exact statuses removed. Do not invent poison/bleeding merely to justify antidotes. A remedy must not become generic Zhem removal or an automatic cure for every magical effect. |
| **Tactical throwables and surface supplies** | Grit, finite smoke, extinguishing fluid, or lamp oil used as authored fuel preparation. | Throw range, hit/scatter policy, ally exposure, footprint, duration, wind/weather interactions and cleanup. Oil is not ignition; smoke is not magical revelation immunity. Supplies should have narrower finite effects than specialist spells. |
| **Ammunition and utility tools** | Arrows, throwing units and the grit packets referenced by the martial cards; later, explicitly authored trap or repair supplies. | Stack quantities, hand requirements, when an item is spent, retrieval and replenishment. A field repair item must not resurrect a ruined building or bypass its rebuild/quest policy. |

## The item-use contract we are missing

| Question | Proposed direction for the next design pass |
|---|---|
| When can an item be used? | During combat, use is an ordinary priced action on the actor's legal turn. Opening inventory is not a free heal or a way to bypass a pending commitment. Every item card states AP and CT alternatives. |
| Who can receive it? | Distinguish self-use, adjacent assistance, thrown delivery and a ground/object target. No remote access to another actor's carried supplies unless an explicit transfer rule permits it. |
| When is it consumed? | Invalid target, missing supply or known no-effect use rejects before payment. At legal commitment, settle the action and exactly one item quantity atomically. Miss/interruption/refund policy must be authored; a preview never spends stock. |
| Does everyone carry everything into a fight? | Start by separating carried inventory from immediately usable supplies. Evaluate a small prepared belt against access to the full carried inventory; the slot count is still a design choice, not an assumed nine-slot rule. Any belt replenishment/swap needs an explicit combat price. |
| What happens afterward? | Item count, remaining field/fuel state and any recoverable projectile id have one authoritative record. No duplication from dropping, trading, re-entering a scene or reprocessing a result. Normal scene-entry Breath refill does not recreate spent items. |

A first implementation acceptance case should be small: a damaged conscious ally,
one poultice, a declared action price, a forecasted HP gain, one consumed unit and
no Soul change. Then test the same attempt at full HP, without enough action budget,
with no item left and with the recipient becoming invalid before resolution.

## What else remains after the martial packet

| Remaining area | Concrete missing decision/work |
|---|---|
| **Downed allies and recovery** | Specify who can be assisted, what assistance restores, when they act again and what survives combat. Reconcile with existing defeat/hollowing rules and Haeren's unimplemented Last Washing. Do not add permanent death or a bleed-out timer by implication. |
| **Enemy kits and bosses** | Expand the three-role demonstration into authored enemy abilities, cooperation, readable boss phases and answers to control. Include finite enemy item use if desired; enemies must not create unlimited healing supplies. |
| **Progression and equipment** | Set learning/mastery gates, practical access to known spells/techniques, equipment upgrades and their tradeoffs. The 170 spell forms and 33 martial/defensive cards are design coverage, not an already implemented unlock progression. |
| **Recovery and encounter pacing** | Test several fights on one map, scene changes, retreat and resupply together. Establish how much pressure belongs to HP, Breath, ammunition and permanent Soul expenditure, preserving the agreed distinctions. |
| **Runtime integration and clarity** | Implement item targeting, the shared Guard contract, new spells/statuses, material fire and enemy responses through forecast and commit. Display item targets, stock, timing and consequences. Then balance using real encounters; document checks cannot establish gameplay balance. |

Critical hits, elaborate grapples, weapon durability, morale and crafting depth can
be considered later. They are not prerequisites for making the current attack,
defense, spell, terrain and finite-supply choices work together.

**Next two-minute review:** compare the intended roles of a poultice, a Breath
restorative and a quenching flask. Those three cover HP, casting endurance and a
world/status interaction, making them the best first item cards to flesh out.

## Sources and verification limits

| Inspected source | Evidence |
|---|---|
| [Generated items](../../data/generated/gloot_prototree.json), [loot registry](../../globals/loot_table_registry.gd) | Existing consumable/material names, metadata and loot references. |
| [GameState](../../globals/game_state.gd), [game flow](../../ui/flow/game_flow.gd) | Inventory quantities/trading and the scene-entry Breath refill with save-load skip. |
| [Identity rulings](../game-identity.md), [class completion](../class-completion.md) | Agreement-only Soul recovery and remaining class signatures. |
| [Martial cards](martial-action-cards.md), [martial rules](martial-combat-rules.md), [spell rules](spell-card-rules.md) | Already drafted ammunition, action, status and material boundaries that item cards need to respect. |

This review adds no item effects or runtime changes. No gameplay tests were run;
source inspection supports the baseline and the proposals remain unbalanced design work.
