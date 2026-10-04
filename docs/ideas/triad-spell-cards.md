# Existing Triads: compatibility cards

**2026-09-09 · Design compatibility pass, not new runtime behavior.** These ten
cards preserve the generated Triad names, components, centers and unique-effect
parameters. They accompany the 92 named pure/Chord forms; they are not ten newly
invented ultimate powers. Existing live consumers implement approximations of
several effects, which must not be mistaken for complete catalog behavior.

## Common profile

Initial profile: **Song, 4 AP or 60 CT, 12 Breath**, target/anchor within 4 unless
the unique effect is encounter-wide. Use the existing Triad Harmony/mastery gate.
The existing solo highest-mastery exception requires Refrain-tier payment: **24
Breath** in this draft. A cost-tier exception does not silently change the spell's
magnitude or unique effect. If authored as an actual Refrain, use the shared R
commitment/use rules; no larger effect is granted merely by increasing its price.

Each card's center supplies its amplified imposition where an authored hostile
profile applies one; utility intent never afflicts allies with an unwanted center
status. Wing rule bends do not grant three independent full attacks. These initial cards
are utility/unique-effect profiles with **no additional base HP hit**. Explicit
bursts and damaging statuses below remain real damage. Founding/Stillpoint retain
their utility centers and cannot acquire direct damage through their wings.

Effects resolve immediately after successful casting unless the card says otherwise.
Cataloged duration/end checkpoints take precedence over the generic two-checkpoint
field default. Named Triad exceptions do not leak into ordinary elemental/Chord spells.

## Ten compatibility cards

| Triad / components → center | Scope and exact identity retained | Initial card treatment / counter |
|---|---|---|
| **Dayspring** · Zhur + Sul + Vel → Sul | **First Light:** one-round revelation of Aftertones, Discord signatures, queued effects and discovered weaknesses; cataloged Defining Strike cost becomes 0. | Reveal eligible information for the caster's side in the declared encounter scope. Preserve the exact Defining Strike cost channel when wired; do not infer free movement, infinite extra actions or Soul grants. Counter through positioning and the end of the window. |
| **Fruiting** · Sul + Vel + Luth → Vel | **Second Season:** copy active friendly buffs; each new copy has the cataloged two-recipient distribution. | At commitment select eligible originals and two valid recipients per original in reach. Copies preserve remaining duration and effect restrictions. Exclude R windows, consumed-use flags, prepaid resource pools and copied copies from recursive production. No duration reset or cloning a restoration payment. |
| **Rivermouth** · Vel + Luth + Khor → Luth | **The Mouth Opens:** area effects ignore zone boundaries for one round; zone-change AP cost is 0. | Applies only through an authored zone-aware battlefield adapter. Ordinary grid-cell movement is not automatically free. Show which area and zone transitions qualify; block an unsupported profile before payment. |
| **Founding** · Luth + Khor + Tham → Khor | **Cornerstone:** freeze remaining durations until the end of the next turn. | Preserve the existing duration-freeze scope/checkpoint and original remaining values. No direct damage, physical-fire freeze, rebuilding pause, refreshed R allowance or free-copy loop. Eligible severing still ends an effect. |
| **Vault** · Khor + Tham + Vekh → Tham | **Sealed Ground:** fortify a zone for the encounter, deny enemy consumption of its anchored Aftertones, add 1 AP on entry, and apply Weighted from its eligible ranged attacks. | Select one authored zone anchor in reach; one instance per zone, no stacking entry surcharge. Requires zone/ownership-aware eligibility. Fortification is a combat effect, not permanent wall construction. CT entry-cost adaptation needs explicit authoring. |
| **Barrow** · Tham + Vekh + Mozh → Vekh | **Unlisted:** one round of friendly-position/queue/signature concealment, the cataloged back-zone targeting restriction and prohibition on enemy reveal effects. | The proposed zone adapter protects the caster side's back-zone actors from enemy targeting; test the directional interpretation explicitly. This is the named exception ordinary Vekh does not possess. Do not turn all physical objects or all actors in every region untargetable. |
| **Pyre** · Vekh + Mozh + Khash → Mozh | **The Rendering:** convert corpses, destroyed objects and expired Aftertones; split Breath across the side; preserve the shared-corpse Decaying condition. | Select up to three stable eligible source ids. Initial fixture yield: 9 per corpse/object, 1 per eligible expired Aftertone; share one finite pool among living allies with capacity clamping. An expired trace can be claimed once, not re-counted each cast. Contested/shared-source handling needs an authored recipient rule before those sources are enabled. |
| **Cinderfall** · Mozh + Khash + Zhem → Khash | **Everything Burns At Once:** consume all Aftertones on both sides and yield the bursts to the caster's side. | Snapshot the encounter's eligible Aftertone ids before resolution, including anchored ones under this explicit exception. Initial burst proposal: one power-1 contribution per consumed trace, each allocated once to a declared enemy in reach. No base hit, repeat consumption, or consumption of fresh traces created by this same release. Show friendly setup losses. |
| **Stillpoint** · Khash + Zhem + Zhur → Zhem | **The Held Silence:** center Balance, lock it through the end of the next round and suppress threshold effects for that window. | Encounter-wide Balance operation using the existing endpoint. Do not alter Soul, reset HP or apply a direct attack. The tactical cost includes losing favorable thresholds while the lock persists. |
| **Thunderhead** · Zhem + Zhur + Sul → Zhur | **Nothing Is Uncertain:** one-round Instability exception and one out-of-turn ally opportunity. | Select one eligible ally for the scheduler grant. No duplicate turn from a forecast, reload or repeated callback. Preserve the Instability exception without adding blanket guaranteed hits/fizzles merely from the effect name. |

## Where live behavior still differs

For Fruiting, the two recipients of a copied original must be distinct and valid;
preserve the original owner's identity and an original-source id on each copy.
A recipient already carrying a copy of that original cannot receive a second one.
Copies cannot become new copying sources through a duration refresh or renamed
instance. This preserves a finite two-recipient operation rather than recursive
buff multiplication.

This is an implementation handoff, not permission to silently change the running
game while completing these design documents. The current controller labels its
Triad consumers provisional. Reconcile them through focused forecast/commit tests.

| Area | Current inspected behavior / remaining gap |
|---|---|
| Fruiting | The consumer extends allied Aftertone durations; the catalog instead calls for eligible friendly-buff copying. Ownership, copying eligibility and two-recipient behavior need implementation. |
| Pyre | The consumer counts dead enemies and spent Aftertones for a Breath payout. A stable one-time source ledger, object conversion, capacity clamping and shared-source handling are still needed. |
| Thunderhead | The consumer grants allies a hit flag and requests an extra turn for the actor. The catalog's selected ally/Instability behavior needs exact reconciliation. |
| Zone-dependent effects | Rivermouth, Vault and Barrow need explicit grid/CT adapters rather than treating zone terms as universal cell rules. Dayspring's zero-cost Defining Strike channel also needs wiring and repeat-action checks. |
| Duration/consumption scope | Founding's checkpoint and restoration behavior, Cinderfall's all-trace snapshot and one-time yield, and Stillpoint's existing Balance lock need acceptance tests against the exact catalog parameters. |

## Release gates for implementation

Every unique effect must have a supported battlefield scope, known recipients,
exact cost/clock channel, source ownership and a deterministic once-only commit.
An unsupported adapter or unresolved shared-corpse rule is an explicit pre-cost
refusal for that affected profile/source, not a quiet fallback with different powers.
Utility-center damage guards, physical persistence and Agreement-only Soul recovery
remain in force across all ten cards.

Sources: [generated Triad catalog](../../data/generated/elements.json),
[current controller consumers](../../globals/combat/combat_controller.gd),
[composition resolver](../../globals/elements/composition_resolver.gd),
[casting gate](../../globals/elements/casting_gate.gd),
[shared card rules](spell-card-rules.md), and
[named spell forms](spell-forms-and-hybrids.md).
