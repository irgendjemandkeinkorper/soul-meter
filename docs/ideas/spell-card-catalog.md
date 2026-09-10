# Complete spell-card design packet

**2026-09-09 · Design-card pass complete.** All 92 named forms now have a priced card
or an explicit shared-price reference, targeting, concrete effect budgets, duration
and counter/persistence rules. The ten existing Triads have separate compatibility
cards. These are initial playtest proposals, not implemented or final-balanced spells.

## Read the packet

| Document | What it defines |
|---|---|
| [Shared card rules](spell-card-rules.md) | Default costs, operational statuses, target intent, ownership, upkeep, resource budgets and interruption settlement. |
| [Elemental cards](elemental-spell-cards.md) and [Khash cards](khash-prototype-spell-cards.md) | Every primary, secondary, tertiary and ultimate form for the nine chosen elements and shared Khor. |
| [Hybrid cards](hybrid-spell-cards.md) | All ten adjacent Chord families and all four currently listed strained families, including their exact limits. |
| [Existing Triad cards](triad-spell-cards.md) | The ten canonical component/center/unique-effect identities and the remaining gaps in current consumers/adapters. |

## Coverage

| Group | Families | Forms / cards |
|---|---|---|
| Chosen elements plus shared Khor | 10 | 40 named forms |
| Natural adjacent Chords | 10 | 40 named forms |
| Listed advanced strained Chords | 4 | 12 named forms |
| Existing cataloged Triads | 10 | 10 compatibility cards, separate from the 92-form inventory |

This covers the existing proposed form catalog. It does not invent a spell for
every legal distant pair, a 93rd hybrid, a new patron or a new elemental position.
Khor remains shared; Maiiam remains unavailable as a starting patron; the underlying
ten-element Wheel and opposed-pair refusals remain intact.

## Cost and use conventions

N/P/S/R defaults are **2/3/4/4 AP**, **30/45/60/60 CT**, and **3/6/12/24 Breath**.
Use AP or CT according to the scheduler, never both. Power, fixed damage, object
integrity damage and finite Breath yields are separate authored budgets.

| Explicit exception | AP / CT | Breath | Why it differs |
|---|---|---|---|
| Hold Note / continuing upkeep | 1 / 30 | 1 | Shared preservation needs an affordable action/resource tradeoff. |
| Unbroken Refrain | 0 / 0 | 9 | Paying four AP to save one maintenance AP defeated its intended purpose; this revision buys an actual action opportunity. |
| Returning Tide | 1 / 30 | 3 | Reassigns only remaining prepaid restoration; it does not create a new restoration budget. |
| Unfading Brand | 0 / 0 | 12 | Buys upkeep freedom plus one legal unanchored fire-line shift, with existing strain and damage caps preserved. |

All R forms still share the proposed one-commitment allowance per character per
encounter and normal fizzle rules. A free-action R does not mean a free spell or a
repeatable trigger. Its own window/use flag cannot be copied or extended.

## Worked consistency checks

| Case | Required result |
|---|---|
| Second Breath costs 6; caster pays 5 Breath plus normal Soul overreach; recipient has room for 3 | Restore **3**, not 6. Actual Breath budget is 5; capacity is 3. No unused-budget refund. |
| Reservoir Hymn paid 6, reserving 1 for upkeep; first installment delivers 2; Returning Tide redirects the rest | Remaining pool is **3**. Redirect it once; the original later installment cannot pay again. Returning Tide's own 3-Breath cost adds no pool. |
| Two fixture sources worth 9 each are reclaimed by one 12-Breath Hollow Veil | At most **18 restored** from finite original ids, before capacity clamp; replaying either source yields 0. |
| One Unbroken Bastion recipient has a 9-HP ward and takes successive 14-damage events | Ward absorbs **9 total**: the recipient loses 5, then 14. It does not refresh per hit. |
| A creature crosses the same fire line repeatedly after Unfading Brand shifts it | Preserve the same instance/per-round ledger; at most one eligible line-hazard event that round. |
| Strained status convention applied to two-checkpoint Burning and three-checkpoint Decaying | Burning lasts **1 checkpoint**, Decaying **2**, with the stated per-tick damage unchanged. |

These are checks of the proposed contracts, not reports of Godot integration tests.
The Khash packet separately checks quenching at 21 integrity, finite burn collapse
and equivalent bulk/stepwise world-phase catch-up.

## Runtime handoff

1. Implement explicit attack/support/environment intent through forecast and commit;
   utility and status-only profiles must preserve their declared zero initial damage.
2. Build Kindle/Douse object targeting and finite physical fire in the isolated yard,
   including save/load and maintained-versus-abandoned recovery.
3. Add the shared status/field/ownership contracts, then price and exercise one
   complete four-form family and its strained hybrid in both AP and CT modes.
4. Reconcile Triad consumers and zone/CT adapters against their exact cataloged
   effects before enabling those profiles. The compatibility cards list the gaps.
5. Run balance/readability playtests before treating these provisional prices,
   ultimate failure rules or status taxes as final tuning.

Current runtime limits are material: this pass adds no spells or art to the game,
does not implement shared Khor access or new selection gates, and does not repair
the documented approximate Triad consumers. No campaign structures or generated
data were changed. The design is now concrete enough for those implementation slices.
