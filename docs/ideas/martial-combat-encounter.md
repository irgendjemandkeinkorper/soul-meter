# Mixed combat fixture: the burning pump court

**2026-09-10 · Proposed test encounter, not an authored live scene.** This fixture
tests the [weapon cards](martial-action-cards.md), [defensive rules](martial-combat-rules.md)
and existing [Khash/Luth spell proposal](khash-prototype-spell-cards.md) together.
It is a contained design exercise, not a change to an existing town or quest.

## What the player is trying to do

Keep a maintained pump standing long enough for the wellkeeper to secure the relief
supply. Enemies try to burn it and deny the work area. The player can fight through
the barricade, take an exposed flank or use magic to contain the fire.

The objective gives the party a reason to spend actions on protecting a place and
moving people. Destroying every enemy still resolves combat through the existing
session rules; objective success/failure is recorded separately and does not end a
session while hostile actors remain active.

## Terrain and initial actors

Use a **9×9** grid, coordinates `(x,y)` from `(0,0)` at the northwest. Ordinary ground
is supported and traversable. Diagonal movement/LOS use the battlefield's normal
corner rules; fixture path examples below use cardinal steps. Materials do not
automatically spread fire, conduct lightning or grant resource yields.

| Feature | Cells / state | Gameplay consequence |
|---|---|---|
| Maintained timber barricade B1 | `(4,3)`, `(4,4)`, `(4,5)`; one shared component id, 30 integrity, 9 fuel ticks | Intact footprint blocks movement/LOS. Ruin removes its blocking footprint. Hitting multiple occupied cells never multiplies integrity damage to B1. Two-world-phase rebuilding after ruin, with normal safe-placement checks. |
| Maintained pump P1 | `(3,4)`; 30 integrity, 9 fuel ticks, wettable timber housing | One occupied object cell, not a standing tile. Two-phase reconstruction restores the physical fixture later; it does not reverse an objective failure or restore destroyed supplies. |
| Abandoned masonry screen M1 | `(5,2)`; 18 integrity, breakable masonry, noncombustible | Blocks movement/LOS until ruined; hammer can break it in two 9-integrity actions. Thermal-only object attacks are rejected. No automatic rebuild or Mozh yield. |
| Flank routes | North via row `y=1`; south via row `y=6` | Both bypass B1 without destroying it. The northern masonry screen changes sight lines; neither route is a mandatory corridor or an invisible trigger. |
| Rescue work area | Supported, non-object cells within radius 1 of P1 | The wellkeeper's objective can progress only while a living ally protects the work area and no living enemy occupies it. The pump itself stays impassable. |

All three structures use separate persistent ids. Assign their material records and
recovery policies explicitly; town maintenance does not make every nearby object
rebuildable. The absent NPC work simulation is represented by the objective counter
for this fixture; no new autonomous civilian pathfinder is required to test combat.

| Party fixture role / start | HP / A / existing defense / armor | Explicit test access |
|---|---|---|
| Shield bearer `(1,3)` | 36 / 9 / 3 / Layered AR 1 | Short blade, shield; Quick Cut, Feint, Guard, Interpose, Shield Bash. |
| Reach fighter `(1,4)` | 36 / 9 / 3 / Flexible AR 0 | Polearm; Thrust, Hook and Draw, Set Spear, Guard, Brace. |
| Breaker `(1,5)` | 36 / 9 / 3 / Reinforced AR 2 | Hammer; Crushing Blow, Drive Back, Break Masonry, Guard, Brace. |
| Elementalist `(0,4)` | 27 / 6 / 3 / Flexible AR 0; 24 Breath | Staff and explicit test access to Staff Strike, Break Cadence, Kindle, Douse, Cinder Spear, Firebreak and Hold Note. Khash and Luth are separate casts, never an opposed hybrid. |

These are fixed actor overrides for a reproducible fixture, not outputs of a newly
chosen character-creation formula. Use four available AP per ordinary actor turn in
the AP comparison, normal existing CT scheduling in the CT comparison, and each
card's explicit alternative price. Existing hit/elemental/fizzle rules still apply.
Test patron hooks in separate variations using the real class resource objects;
do not invent a blended resource loop for the four roles above.

## Three enemy roles and information limits

| Role / start | Fixture budget | Observed-state behavior and counter |
|---|---|---|
| Gatekeeper `(5,4)` | HP 36, A 9, defense 3, Layered AR 1; polearm | Protect a currently useful passage. Set Spear if a visible approach is likely; Thrust at a legal exposed enemy otherwise; move if its position no longer contests access. Once B1 breaks, reconsider the opening instead of guarding the obsolete wall. It never knows a concealed queued target. |
| Lookout `(6,3)` | HP 27, A 9, defense 3, Flexible AR 0; bow, 9 arrows | Prefer a legal shot or a visible Watch Shot lane covering the party's current approach. Reposition when adjacent enemies invalidate bow range. Never shoot through B1/M1, fire more arrows than it owns or receive a free shot when a prepared arrow expires. |
| Cinder hand `(7,5)` | HP 27, A 6, defense 3, Flexible AR 0; 18 Breath | Use Kindle/Cinder Spear on a visible eligible pump or opponent; Firebreak may contest an accessible route. Do not cast a thermal-only object attack on M1 or ignite wet timber with a false promise. When Breath is insufficient, use a legal staff action or move; fixture AI does not silently spend Soul to maintain its script. |

Enemy priority is an authored ordered policy for testing, not a claim that current
AI already understands these cards. Evaluate legality and visible consequences first,
then objective value, then damage/position; break equal choices with stable ids.
An enemy may react to witnessed destruction, visible hazards, known range and revealed
preparation cues. It may not inspect hidden spell identity, future player inputs or
unrevealed random outcomes simply because those values exist in memory.

An obvious alternative path should make the enemy reconsider a watched lane. Do not
grant it instant movement, free preparation replacement or ammunition reimbursement
to make it appear clever. Resource constraints are part of the encounter.

## Objective state and aftermath

One conscious party member adjacent to P1 can use **Start Relief Work: 2 AP / 30 CT**,
zero Breath/Soul. Require intact P1 and a visible valid work position; reject duplicate
activation without payment. This is a fixture interaction, not a new global combat verb.

The objective tracks a progress value from 0 to 3 and the last processed checkpoint.
At each later round checkpoint in AP, or the corresponding shared effect checkpoint
in CT, add one if P1 is not ruined, at least one living party member is adjacent to it,
and no living hostile occupies any adjacent work-area cell. Failure of the occupancy
condition pauses progress; it does not reset it or consume a free extra checkpoint.
Creation never increments progress at that same checkpoint. Use the spell packet's
checkpoint adapter, not every actor turn or every CT tick.

At progress 3, record **relief secured** once. If P1 reaches zero integrity first,
record **relief lost** once. Those outcomes are mutually exclusive and persistent.
Later destruction after success damages the pump but does not retroactively un-rescue
supplies. A later rebuild repairs the structure, not the outcome. Source claims,
objective rewards and group victory rewards keep separate ids and cannot double-pay.

If combat ends before a terminal objective state, stop the combat timer. A remaining
intact pump can use an explicit out-of-combat **Finish Relief Work** interaction to
secure the supply once when no hostile remains and P1/work-area cells have no active
physical fire or damaging hazard. If the party flees/leaves while it is
unsecured, record the fixture's relief-lost outcome; no world-time progress while
unattended. This is an encounter-specific consequence, not a change to global fleeing.
Enemy group rewards still follow the existing victory/flee ledger; objective success
does not grant kills or Soul. A future quest reward requires separate authoring.

## Concrete tactical questions to exercise

1. **Can the party protect the work area while approaching?** The shield bearer can
   intercept a physical shot aimed at the adjacent elementalist. An elemental attack
   or fire hazard remains a different threat; Interpose does not redirect either.
2. **Does a changed battlefield change the fight?** Four successful Hew Support
   actions in an axe-equipment variant destroy untouched B1. A spell variant can ignite
   it, then decide whether to quench it before the route changes. Recompute both sides'
   legal paths, sight lines and watched lanes after the footprint changes.
3. **Is interruption a real choice?** In an advanced variant, give the cinder hand one
   visibly marked Crown of Embers wind-up and 24 starting Breath. Break Cadence can
   cancel it on a legal hit; a successful shove can break its positional tether.
   Test Brace's push prevention separately unless the actor has an explicitly funded
   action budget for both preparation and wind-up; do not grant a free Brace alongside
   a 4-AP Crown on the 4-AP fixture. Instant Kindle has no such interrupt window.
4. **Are finite resources actually finite?** A Watch Shot miss still spends an arrow.
   Holding Firebreak spends upkeep and does not refill physical fuel. Douse extinguishes
   the pump's physical fire but does not erase a separate magical line over a nearby cell.
5. **Can the party choose what survives?** B1 and P1 can rebuild later under their own
   policies; M1 remains broken. Objective success, expenditures and destroyed supplies
   retain their results independently of the repaired art and collision.

Use one variant at a time. The axe variant replaces the breaker's hammer with an
explicitly granted axe kit; the advanced enemy variant replaces its starting Breath
budget instead of granting a free Refrain. A bow-player variation similarly replaces
one martial role; it does not create a fifth free actor or duplicate ammunition.

## Forecast and visual acceptance

| Situation | What must be legible before commitment | What must remain legible afterward |
|---|---|---|
| Set Spear / Watch Shot | Fixed arc or marked cells, range/LOS gaps, one response and paid ammunition | Slot spent or still armed; no invisible second reaction. |
| Guard / Parry / Interpose | Which specific incoming damage channel qualifies; final recipient(s) and loss | One consumed response; separate HP loss on an interceptor; no false status protection. |
| Drive Back / Hook / Shield Bash | Exact destination, Footing/Brace/Rooted refusal or hazard consequence | Updated footprint, broken tether and any unchanged/used hazard ledger. |
| Structure impact | Component id, remaining integrity, susceptible material, actual blocking footprint | Damaged/ruined state, correct paths/LOS and independent fire/fuel record. |
| Spell wind-up and objective | Visible dangerous marks, interruptibility, release point; objective progress/paused reason | Cancelled or resolved commitment, spent resources and one terminal objective result. |

Use distinct outlines/icons for physical impact, magical hazard and delayed release;
do not rely on orange versus red alone. Reduced-motion presentation should still
show the same affected cells and commitment/result events. These are state/readability
requirements for future art, not a UI redesign or finished asset claim.

## Verification and implementation order

Implement the shared Guard/zero-damage/equipment intent contract through forecast
and commit first; it exposes the current Guard-path discrepancy without adding all
weapon content at once. Then wire a spear attack and prepared response, a shield
defense, one object-impact action and the existing Kindle/Douse prototype. Only after
those agree should the mixed objective and enemy policy be enabled.

| Acceptance case | Required result |
|---|---|
| Undamaged B1 receives four Hew Support actions | Integrity 30 → 21 → 12 → 3 → 0. No AoE multiplication across its three cells. |
| M1 receives two Break Masonry actions | Integrity 18 → 9 → 0; footprint opens, no fire and no automatic rebuild. |
| Pump receives Kindle, two burn ticks, then Douse | Integrity 30 → 27 → 24 → 21; 7 fuel ticks remain, physical fire off, Wet active. |
| Guard user takes a 9-HP physical hit after ordinary defense, with AR 2 | Final HP loss 3. Forecast and resolution must both include the same armor and Guard application. |
| Shield bearer intercepts an eligible 8-HP shot at the adjacent caster | Caster loses 5, bearer loses 3. The bearer cannot halve that fixed 3 again. |
| Started objective sees safe, contested, safe, safe later checkpoints | Progress 1, 1, 2, 3; one success event. Reprocessing the last checkpoint grants nothing. |
| Pump ruins before progress 3, then rebuilds later | One failure remains recorded; a physical rebuild cannot change it to success or spawn replacement supplies. |

The checks above describe expected behavior. No gameplay scene, Godot test, runtime
enemy policy or art asset was added by this design pass. The current full combat
prototype must be exercised before these prices or encounter budgets are called balanced.

Sources: [same-map rulings](../architecture-same-map-combat.md),
[persistent structures](../persistent-structures.md),
[class boundaries](../class-completion.md), [spell rules](spell-card-rules.md).
