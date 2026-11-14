# P1.4 weapon-stat draft packet — 2026-11-01

**Status: PROVISIONAL; owner review only. Nothing ships until the owner accepts it.**

Issue #533, roadmap P1.4 step 1. This packet covers only
`weapons/forge_hammer`, `weapons/roadwarden_spear`, and
`weapons/taubstummer_axe`, all authored for `main_hand`. It changes no game data,
code, items, canon, prices, or progression rules.

**Finding:** this checkout has no individual Kit weapon attack values and no
equipment-to-combat reader. Kit selection grants starting ARMS training; attacks
read the character's stats. Therefore a differentiated, nonzero weapon table
cannot both use today's weapon fields and stay within an existing Kit weapon
stat envelope. The conservative draft below preserves the current numeric
baseline. It is not a claim that meaningful equipment effects are implemented,
balanced, or ready for P1.4 step 2.

## 1. Authority and evidence boundary

The dispatch records owner item 29 answered `b` on 2026-11-01: draft provisional
weapon stats for review. In this worktree, `docs/owner-decisions.md:42` starts §5
with the 2026-10-30 entry at line 44; neither item 29 nor a 2026-11-01 entry is
present. The dispatch supplies the draft authorization; this packet does not
invent a repository ruling or record acceptance. The one-file scope leaves the
owner log untouched.

Source snapshot: `45a83c5fa008b58caa77ee087bce9d926e3bee2c`, on
`codex/roadmap-p1-4-weapon-stat-packet` (stacked on PR #541 per dispatch).
References below are repository-relative `file:line` locations at that snapshot;
no remote state was consulted.

The governing bounds remain:

| Bound | Evidence and consequence |
|---|---|
| Same-map combat; stats matter in the field; class is identity and DRAMGID determines capability; XP/skills/perks drive progression | `docs/game-identity.md:16`, `:17`, `:18`, `:19`. A weapon must not replace attributes, grant a patron identity, or silently grant permanent skill training. |
| Chapter 1 cap **6**, perks at **2/4/6**, no quest XP from suspended stubs | `docs/owner-decisions.md:65`; `docs/progression-bound-packet.md:18`; `globals/stats/xp_curve.gd:40`. The older cap-7 discussion is superseded. Kill-XP scaling remains −30% per overlevel, floor 10%; +25% per underlevel, ceiling 150% (`xp_curve.gd:44`). No weapon-level scaling is proposed. |
| Enemy curves and variation remain intact | `docs/enemy-curve-packet.md:7`, `:42`; `globals/stats/enemy_derived.gd:19`, `:38`, `:62`. HP = `round(2 + 6*grit + 2*muster)`, attack = `round(1 + 1.5*muster)`, defense = `max(round(-2.5 + 1.25*grit), 0)` over the authored range. Wild HP/attack/defense independently vary ±15%; set-pieces do not roll. No player weapon bonus is inferred from those enemy values. |
| Physical Kits retain their function in low Integrity/Hush | `docs/prd-chapter-one.md:146`; `docs/phase-0-ratification.md:148`; `globals/stats/dramgid_schema.gd:140`. No new Loom tax, Soul cost, or elemental property is inferred from a weapon's description. |

## 2. What combat reads today

### Inputs, damage, accuracy, and equipment persistence

| Existing input | Actual read/write path | Meaning for this draft |
|---|---|---|
| `PartyMember.attack`, `defense` | Defaults **5/2** at `globals/party_member.gd:56`; created characters are recomputed at `globals/chargen/chargen_build.gd:353`. `globals/stats/dramgid_derived.gd:62`, `:71`, `:79` set attack = **2 × Muster**, defense = **Alacrity**. `globals/battle_actor.gd:114` copies them into the battle actor. | These are character values, not weapon ratings. Preserve the member's actual values, including existing saves/authored characters; do not replace them with the illustrative baseline below. |
| Effective attack/defense | `globals/battle_actor.gd:153`, `:157` apply Defining Strike deltas and unused-AP defense. `globals/combat/combat_controller.gd:2396` builds mundane attack power from effective attack + `CombatAction.power_bonus` + zone flank bonus + balance damage bonus. | An attack/defense modifier has an existing mathematical destination, but no item reader supplies one. Adding one is **needs code**, excluded from the recommended table. |
| Damage calculation | `globals/combat/resolution.gd:293`, `:390` multiply power by attack scale, elemental matrix, height, facing, and source-tile multiplier, round, then add applicable effect bonuses. `globals/combat/combat_controller.gd:2080` subtracts effective defense (after any bypass), balance defense, and cover; a landed damaging attack has a floor of **1**, a miss does **0**. | Ordinary physical damage has no weapon dice or random min/max range. Existing hit rolls and class-effect draws are not weapon damage dice. |
| Accuracy | `globals/combat/resolution.gd:23`, `:41`: grid hit chance = `clamp(70 + 2*(attacker Alacrity - defender Alacrity) + facing + 4*height_steps + applicable visibility/aim/injury terms, 5, 95)`. Front/side/back hit terms are **0/+8/+15** at line 14. `globals/combat/combat_controller.gd:2452`, `:2478` supplies attributes and positional context. | No ARMS percentage, weapon accuracy, or `attack` stat enters this to-hit calculation. A neutral front-facing, equal-height/equal-Alacrity attack is **70%**; legacy zone combat is **100%** unless a separate gate blocks the action. |
| Action cost, profile, and shape | `data/combat/actions/01_strike.tres:11` gives Strike **2 AP / 30 CT**, `target_profile = melee`; `globals/combat_action.gd:19`, `:44` default to `power_bonus = 0`, `aoe_shape = single`. | These belong to the selected action, not to the item. Preserving them needs no code; selecting different values from equipment does. AP is the shipped default (`globals/battle_actor.gd:6`); 30 CT is the authored cost for the alternate CT path, not an additional AP-mode charge. |
| Grid reach | `globals/combat/grid_battlefield_model.gd:474` gives ranged actions LOS checks and ordinary melee Chebyshev adjacency (**1 cell**, including diagonals), with an elevation gate. `data/combat/actions/40_thrust.tres:11` authors Thrust at **2 AP / 30 CT**, ranged, `effect_payload.range = 2`; `globals/combat/combat_controller.gd:3475` reads that range. | Two-cell reach exists as an action parameter. A spear does not select Thrust or modify Strike today. The ARMS skill named `reach` is not a cell count. |
| Kit and ARMS | `globals/chargen/chargen_build.gd:159` grants the selected Kit skill a Trained tier; `:337` stores `kit_weapon_skill` but sets `kit_weapon = ""`. `globals/party_member.gd:104`, `:145` round-trip both. Neither the actor conversion nor combat resolver uses them to select a weapon or compute accuracy/damage. | A Kit name has no flat attack bonus. Bare hands have no separate fallback damage formula. Equipping a purchased weapon neither trains a skill nor selects an ARMS combat calculation today. |
| Inventory slot | `ui/screens/inventory.gd:7`, `:396` map authored `equip_slot = main_hand` to UI/save key **`main`**. On screen close, `:51` records the prototype ID in `GameState.equipped_slots` and returns the item to the persistent bag; `:66` restores the rail next time. | Slot state is presentation/persistence today. An equipped item also being in the bag after close must never be counted as a second effect in step 2. |
| Save ownership | `globals/game_state.gd:113` defines a flat slot-name → prototype-ID dictionary, with no member ID. `:1215` and `:1247` deep-copy it through saves; missing old-save data defaults to `{}`. | There is no existing per-member equipment owner to assume. Do not apply one main-hand record to every party actor. |

The loaded rules also provide cover **+2**, zone flank power **+2**, and unused-AP
defense **+1 per AP capped at +1** (`data/combat/combat_rules.tres:13`). These are
combat rules, not spear bonuses. Grid positioning replaces the zone flat flank
term (`globals/combat/combat_controller.gd:2740`).

`data/generated/combat_identity.json:13`, `:33`, `:53` carries balance-band
damage **+2** and center defense **+2**; `:107`, `:123` carries Defining Strike
defense/attack deltas **−2**. That file contains balance and weaknesses, not a
weapon catalog. Reusing those numbers as weapon stats would invent a balance
decision. Patron resources can also alter the final result through
`globals/combat/combat_controller.gd:2499`; those remain class effects.

### Fields excluded from the recommendation: needs code

Every entry below is **needs code**, even where an underlying combat input
already exists. An equipment adapter is still new combat integration; this
packet does not disguise that work as a data-only change.

| Candidate weapon field/effect | Existing destination, or missing behavior | Status |
|---|---|---|
| Flat attack, damage/power bonus, defense bonus, attack multiplier | `BattleActor.attack` / `defense` / `attack_scale`; `CombatAction.power_bonus`; paths above. No Pandora weapon property, generator mapping, or equipment consumer supplies them. A modifier must not overwrite or repeatedly increment saved base stats. | **needs code**; no nonzero value recommended. |
| ARMS skill used by the weapon, training from equipping, weapon accuracy | `kit_weapon_skill` is creation metadata; `SkillCheck.preview()` exists at `globals/skill_check.gd:49` but physical combat does not call it. Schema candidates are **Heft** for the hammer (inference from mauls/war pick), **Reach** for the spear, **Heft** for the axe; fists are **Grip** (`globals/stats/dramgid_schema.gd:142`). | **needs code**; classifications are review notes, not live bonuses or new training grants. No skill-to-hit formula proposed. |
| Heavy/slow AP or CT cost, weight-based speed | `CombatAction.ap_cost` / `ct_cost` are existing action inputs; item weight is inventory metadata. No weight-to-AP/CT/speed reader exists in this path. | **needs code**; no hammer/axe delay or AP surcharge recommended. |
| Spear reach/defensive benefit | Thrust already has range **2**, Hook and Draw range **2** and **3 AP / 45 CT**, with zero direct damage (`data/combat/actions/41_hook_and_draw.tres:11`). Neither is bound to the spear or an ARMS skill. Defense exists on the actor, with no equipment binding. | **needs code** for equipment action selection or defense contribution; neither bonus enters the table. |
| Axe cleave, damage dice/range, armor penetration, critical or elemental effect | `aoe_shape` reaches `battlefield.targets_for()` at `globals/combat/combat_controller.gd:2305`; grid `single`/`position` hit one, while `side` hits **every living unit on the target side** (`globals/combat/grid_battlefield_model.gd:610`). It is not a local cleave. Open Seam's existing bypass **1** is action-owned (`data/combat/actions/46_open_seam.tres:16`); dice and weapon crits have no weapon input. | **needs code**; no cleave geometry, dice, penetration, crit, or soul/elemental property recommended. Do not turn the axe into an all-enemies attack. |

## 3. Kit weapons and bare hands: measured baseline

Pandora was readable. Its ten class entities (`data.pandora:849` through the
Threadwalker entity at `:1074`) contain display name, patron, resource name, and
Vault Id; their schema has no Kit weapon stats. The three item entities are at
`data.pandora:1324` (axe), `:6543` (spear), and `:6588` (hammer). Their inherited
item properties likewise contain no combat stats. The Vex loadout's `Equip` is
`{}` (`data.pandora:15582`), not a hidden set of weapon ratings.

The available Kit names and skills come from the explicitly provisional
`ClassCatalog` (`globals/stats/class_catalog.gd:5`). The numbers below are
calculated from live data/formulas, not a claim of running a battle. Isolate the
weapon contribution by holding class resources, perks, injuries, balance
bonuses, cover, terrain, weather, and elemental multipliers neutral. Use Muster
**3**, Alacrity **3**, an equal-Alacrity defender with defense **2**, front-facing
adjacency at equal elevation, and ordinary Strike. This gives attack **6**,
defense **3**, hit **70%**, and **4 damage on a hit / 0 on a miss** for every row.

| Class | Existing Kit weapon wording | Selected ARMS skill; starting skill % at attribute 3 | Attack / defense | Grid hit / damage on hit | Kit source |
|---|---|---|---|---|---|
| Mirrorblade | Paired balanced daggers | `keen`, Trained **44%** | 6 / 3 | 70% / 4 | `globals/stats/class_catalog.gd:25` |
| River-Mother | Water harp, net-and-whip, hospice tools | `reach`, Trained **44%** | 6 / 3 | 70% / 4 | `globals/stats/class_catalog.gd:36` |
| Ironbrand | Greatsword **or** spiked gauntlet | `heft` **or** `grip`, chosen skill Trained **44%** | 6 / 3 | 70% / 4 | `globals/stats/class_catalog.gd:47` |
| Lensbearer | Quarterstaff | `reach`, Trained **44%** | 6 / 3 | 70% / 4 | `globals/stats/class_catalog.gd:58` |
| Husk-bearer | Cleaver or sickle, gut-lute | `keen`, Trained **44%** | 6 / 3 | 70% / 4 | `globals/stats/class_catalog.gd:69` |
| Flamebinder | War pick | `heft`, Trained **44%** | 6 / 3 | 70% / 4 | `globals/stats/class_catalog.gd:80` |
| Stormbearer | Greatclub | `heft`, Trained **44%** | 6 / 3 | 70% / 4 | `globals/stats/class_catalog.gd:91` |
| Oathclock | Halberd | `reach`, Trained **44%** | 6 / 3 | 70% / 4 | `globals/stats/class_catalog.gd:102` |
| Locksmirk | Blowgun | `loose`, Trained **44%** | 6 / 3 | 70% / 4 | `globals/stats/class_catalog.gd:114` |
| Threadwalker | Whip-dagger | `keen`, Trained **44%** | 6 / 3 | 70% / 4 | `globals/stats/class_catalog.gd:126` |
| Bare hands | No equipped weapon; Grip covers fists | `grip`, Untrained **24%** if not otherwise trained/bought | 6 / 3 | 70% / 4 | `globals/stats/dramgid_schema.gd:146`; `globals/battle_actor.gd:109` |

The skill service computes `8*attribute + tier_bonus + purchased_percentage`,
capped at **95%**; Trained adds **20 percentage points**
(`globals/skill_check.gd:28`, `:60`). Thus a trained Kit skill spans
**36/44/52/60%** over governing attributes **2/3/4/5**, before purchases. These
are skill-check percentages, **not weapon hit chances**. Removing a weapon does
not erase training: a character already trained in Grip remains trained when
bare-handed. No hit-use training/XP loop is inferred.

Across the same point-buy range, every class's derived attack is **4/6/8/10**
and defense is **2/3/4/5**. Those ranges belong to attributes, not to different
Kit weapons. There is no strongest Kit weapon rating to copy. At fixed character
stats and action, the current weapon-specific attack/defense contribution is
**0 for every Kit and for bare hands**. In a full battle, patron mechanics can
make the classes differ; this comparison deliberately does not price those
mechanics as equipment.

Other physical cards do not establish a weapon-stat hierarchy either:
Close Strike and Quick Cut both cost **2 AP / 30 CT**, use melee, and inherit
power bonus **0** (`data/combat/actions/42_close_strike.tres:11`,
`data/combat/actions/45_quick_cut.tres:11`). Thrust shares that power/cost but
has the action-owned range described above. Bare hands do not automatically
select Close Strike; the Kit's blowgun does not automatically turn Strike into
a ranged attack. `CombatActionCatalog.player_actions()` selects authored
player-available actions (`globals/combat/combat_action_catalog.gd:20`), not
equipment-specific actions.

## 4. PROVISIONAL recommended table: preserve supported inputs

**Recommendation: retain zero weapon-derived changes until a nonzero budget and
its code integration are approved.** The following values are the existing
runtime inputs to retain when using ordinary Strike. They are not new fields to
add to Pandora or GLoot, and **6/3 must not be hard-coded onto a character**.
`A` means the member's existing attack; `D` means existing defense. For the
controlled baseline above, `A/D = 6/3`.

| Weapon prototype | `equip_slot` → saved key | Actor `attack` / `defense` | Strike `power_bonus`; `ap_cost` / `ct_cost` | Strike `target_profile` / `aoe_shape` | Existing `base_price` / `weight` |
|---|---|---|---|---|---|
| `weapons/forge_hammer` | `main_hand` → `main` | **A / D**, unchanged (6 / 3 example) | **0; 2 / 30** | **melee / single** | **42 / 2.5** |
| `weapons/roadwarden_spear` | `main_hand` → `main` | **A / D**, unchanged (6 / 3 example) | **0; 2 / 30** | **melee / single** | **55 / 3.0** |
| `weapons/taubstummer_axe` | `main_hand` → `main` | **A / D**, unchanged (6 / 3 example) | **0; 2 / 30** | **melee / single** | **90 / 6.0** |

Every proposed retained field maps to §2: slot → inventory alias/persistence;
attack/defense → member-to-actor copy; power/cost/profile/shape → existing Strike
resource and action defaults. Price and weight are existing inventory metadata,
not additional combat inputs. Accuracy and damage stay derived: **70% and 4 on
hit** in the controlled example; ordinary melee remains **1-cell adjacency**.

This meets the bound only as **equality with the current Kit baseline**: all
weapon-specific deltas are zero. It does not justify choosing hammer/spear/axe
bonuses from the character's 4–10 attack range. Ten is not an equipment ceiling
or a clamp on saved characters, class bonuses, or future story attribute boosts.

| Weapon | One-line rationale and price/weight consistency |
|---|---|
| Forge Hammer | Its existing description is a balanced smith's hammer usable in the field; the requested heavy/slow role can suggest Heft, but **2.5** is the lightest of these items and creates no slow-attack rule. Its **42** price remains the lowest; no combat premium is invented. |
| Roadwarden Spear | Its ash shaft and Iron Company pattern head fit the requested reach/defensive role, but range/defense are not read from this item; **55 / 3.0** remains between hammer and axe without pretending it buys two-cell Strike or extra defense. |
| Taubstummer Axe | Its existing sealed soul-weapon description, mythic rarity, **90** price and **6.0** weight distinguish the inventory item; the requested cleaving role supplies no current local-cleave behavior and does not authorize stronger damage, Soul effects, or new canon. |

Metadata sources: `data/generated/gloot_prototree.json:211`, `:223`, `:235`,
cross-checked against the three Pandora entities. All three have max stack size
**1**; grid sizes are **2×2**, **1×3**, and **2×3** respectively. The price/weight
ordering is preserved, but there is **no implemented combat-value return for
the higher prices**. That is a review limitation, not a claim of economic balance.

## 5. P1.4 step 2 effects fixture plan — after acceptance

No fixture or runtime change is made in this documentation step. Use existing
inventory/controller test patterns, isolated user data, and the project's
`scripts/test.sh` runner. The acceptance assertions are:

1. **Build the real equipment-to-combat case.** For each of the three existing
   prototypes, equip through the inventory path, close the screen to commit
   `equipped_slots["main"]`, and create the intended actor through
   `BattleActor.from_party_member()`. Hold the controlled baseline inputs fixed.
   Include the corresponding unequipped Kit/bare-hands case and a second party
   member. The actor that owns this flat equipment record must be explicitly
   agreed before implementing a nonzero effect.
2. **Apply every accepted effect exactly once.** Compare unequipped and equipped
   forecasts, the runtime inputs, and a committed `submit_action()` result with
   fixed seeds. For an approved nonzero contribution `E`, expect one `E` at its
   designated input, never `2*E`; check final damage through the existing
   multipliers/mitigation rather than assuming every input changes HP linearly.
   Repeat previews, equip/close/reopen, actor construction and battle starts;
   no accumulation, base-member mutation, extra skill training, duplicate HP
   writes, or extra AP payment. An equipped item returned to the bag, or another
   copy of the same prototype in the bag, must not count twice. For multiple
   accepted effects, check each input independently as well as their combined
   committed outcome.
3. **Remove effects completely.** Unequip, close, and rebuild/refresh the actor
   through the supported lifecycle. Assert the original attack, defense,
   accuracy, action costs and target rules return; inventory-only weapons and
   other party members receive no equipment contribution. Replace hammer →
   spear → axe and verify only the current slot's accepted effects remain.
   Preserve the permanent Kit training and patron-resource behavior throughout.
4. **Round-trip slots and base state.** Save/load real inventory plus
   `{"main": "weapons/<selected_prototype>"}` and verify exact slot spelling,
   prototype identity, item count, and unchanged base member stats/Kit fields.
   Reopening the screen must seat exactly one item; actor reconstruction must
   apply an accepted effect once, not once from saved stats and again from the
   slot. Missing `equipped_slots` in an old save yields `{}` and no equipment
   effects. Existing unrelated legacy slot payloads must not be silently
   reinterpreted as a new per-member format.
5. **Exercise observable behavior and report the limit.** Commit both a landed
   attack and a miss, compare forecast to execution, and verify target legality
   at 1 and 2 cells. With this neutral draft, Strike stays adjacent/single-target
   and gives the baseline numbers for all three items. Run the inventory
   integration under Xvfb/display and inspect equip/unequip/reopen behavior;
   run affected controller/save tests with isolated data. If later accepted
   fields affect costs, reach, defense or targets, exercise those effects through
   their real consumers as well. **Zero-only equality cannot prove a nonzero
   effect is applied exactly once; do not declare the effects implementation
   complete on that evidence.** A positive effects test needs an approved
   nonzero input and its implementation, neither supplied by this packet.

Existing anchors: `test/integration/test_inventory_screen.gd:104` already checks
close/reopen and `GameState` round-trip for the axe;
`test/unit/test_save_migration_sweep.gd:177` preserves arbitrary old slot data
by value. Its nested `vex`/`korrath` fixture (`:96`) is **not** the live inventory
rail's flat shape. Use `test/integration/test_combat_controller.gd` for submitted
actions. The verification obligations come from `docs/agent-verification.md:9`,
`:12`, `:19`; this plan does not claim those future runtime checks passed.

## 6. Review risks, open decisions, and response

| Risk/open decision | Consequence for owner review |
|---|---|
| No authored Kit weapon stat envelope | A differentiated nonzero draft would need an explicitly approved comparison budget; character attribute maxima and class-resource bonuses cannot stand in for missing weapon ratings. This packet recommends only the neutral baseline. |
| No equipment reader or member ownership | Any real effect needs code and an agreed recipient for the flat `main` record. This packet does not choose protagonist-only, party-wide, or a per-member save redesign. |
| Role and price expectations exceed current effects | Heavy/slow, reach/defensive, and cleaving remain requested roles without the supporting item integration. Accepting this packet does not certify that buying a more expensive weapon improves combat or that those roles are implemented. |
| Authority log is older than the dispatch | Claude/owner must reconcile item 29 in the normal owner log when allowed; it is neither added nor marked resolved here. No new canon or shipped balance approval follows from this draft. |

**How to answer:** `weapons: accept` / `weapons: change <weapon> <field> <value>`.
Use one of the three full prototype IDs for `<weapon>`. `accept` accepts only
this provisional neutral table and its stated limitations. A requested change
to a **needs code** field requires a revised packet/code scope and a valid
balance anchor before implementation; it is not an instruction to invent a
system or silently alter class Kits.

## 7. Documentation verification

Host checks passed: all **64** fully qualified `file:line` references resolve;
the three Pandora/generated metadata pairs agree; all ten Kit skill mappings
match the catalog; and the displayed baseline arithmetic is consistent with
the source constants. The staged documentation passed `git diff --cached --check`,
with this single Markdown file as the only change.

No engine tests were run: the documentation gate requires source/path and
consistency checks, not a gameplay sweep (`docs/agent-verification.md:9`). No
equipment runtime effect or visual correctness is claimed. The step 2 fixture
assertions remain pending acceptance and implementation.

The local commit attempt was blocked when Git could not create
`/home/adamjroder/projects/soul-meter/.git/worktrees/codex-p1-4/index.lock`
(`Read-only file system`). No commit was created. The earlier packet is staged;
this final verification note is in the working copy. Restage this file and
commit it in an environment with writable Git metadata, on the same branch.
