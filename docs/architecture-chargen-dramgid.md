# Character creation on DRAMGID — architecture note (F3a-4, #283)

**Status:** DESIGN, 2026-09-05 (synthesized from a three-lens design panel — systems /
player / ship — scored by two judges; the ship-first chassis with the systems-first formulas
and the player-first guards). Elaborates PR 4 (`feat/dramgid-chargen`) of
`docs/handoff-dramgid-codex.md` and §3.4 of `docs/architecture-dramgid.md`. Stacked on
PR #360 (design) and PR #361 (`DramgidSchema`). Everything marked **PROVISIONAL** is a
recommendation the code implements *as written* until the owner rules otherwise (§12).
Nothing here resolves a canon open question; where canon is silent the note says so and
proposes.

**Owner ask (2026-09-05):** character-creation screen wired to DRAMGID, *meaningful* class
choice, Fallout-style skill points at creation — including **weapon skills** and
**elemental-magic skills** — documented end to end so any worker can pick it up.

**Read with:** `docs/architecture-dramgid.md` (schema, migration, rulings §5),
`docs/game-identity.md` (rulings 8 + 9), `docs/handoff-chargen-workers.md` (the bounded
tasks), mono `04-world/systems/character-creation.md` + `ten-patron-classes.md` (canon).

---

## 1. What exists today (facts)

| Fact | Where |
|---|---|
| Seven-page code-built wizard: Ancestry, Calling (discipline + patron + background as OptionButtons), Elements, Attributes (6 rows, 20 points), Skills (read-only preview), Identity, Summary. All state and navigation private; integration tests drive `_on_next()` etc. | `ui/screens/character_creation.gd` (903 lines), `test/integration/test_character_creation.gd` |
| Creation tables are hand-written on the six-stat/12-skill vocabulary, with a duplicated `attr×8 + 20` preview formula. | `globals/chargen_data.gd` |
| PR #361 makes `DramgidSchema` the ONLY home for attribute/skill ids: 7 attributes, floor 2, cap 5, budget 22, 22 field skills (RFC-0005 list, PROVISIONAL), 12 legacy ids kept for dialogue. `SkillCheck.SKILL_DEFINITIONS` is built from it. | `globals/stats/dramgid_schema.gd`, `globals/skill_check.gd` |
| Skill resolution (ratified): `effective% = attr×8 + tier(0/20/35) + advancement + situation`, cap 95, d100 roll-under; +5% steps cost 1/2/3 by resulting band; one ledger `GameState.skills[member.id][skill]`; Mirror Rewriting refunds every advancement point. | `globals/skill_check.gd`, `globals/advancement.gd` |
| **Live defect:** the wizard stores the class id (`"ironbrand"`) in `PartyMember.patron`, but `ClassResourceRegistry.for_patron()` keys on deity ids (`&"kero"`). A created protagonist attaches `NullClassResource` in every battle — class choice is mechanically empty for the player character. | `class_resource_registry.gd:9-46`, `combat_controller.gd:2155` |
| **Latent defect:** the advancement ledger writes lowercase tiers, the save validator only accepts `["Untrained","Trained","Expert"]`. First skill purchase → save rejected on load. | `advancement.gd:_ledger_row`, `game_state.gd:30, ~1194` |
| Canon has **no weapon skill and no per-element casting skill** in any list (12, 18, 22). Weapons exist only as class **Kit** prose. Elemental competence = Mastery (a Note/Phrase at 0% fizzle), Major/Minor pick (never opposed), Intuition fizzle reduction, Vär breadth gating. | mono `character-creation.md`, `magic-system.md`, `ten-patron-classes.md`; RFC-0004/0005 |
| Canon chargen order: Race → Discipline → Patron → Major/Minor → Attributes → Background → Skills ("remaining points from a Reason/Decorum-scaled pool", formula unstated) → Flaw (table unenumerated; "bonus skill point or starting resource"). | mono `character-creation.md` §Chargen Flow |
| Combat reads: to-hit `70 + facing + 4×height + 2×(edge delta)`; plain attack has no weapon and casts with a `&"suul"` placeholder element; casting power = `ability.power`; context built in `CombatController.forecast_context()` and consumed by `Resolution.resolve()` (forecast == resolution). Combat files are **frozen until #281 merges**. | `combat_rules.gd`, `resolution.gd`, `combat_controller.gd:1471-1548` |
| `GameState.equipped_slots` is party-wide and unread by combat; `UnitLoadout.equip` unread. Items carry only `Equip Slot`. | `game_state.gd:94`, `inventory.gd:42-56` |

---

## 2. The design in one paragraph

Everything a character can **grow** is a skill in `DramgidSchema`, resolved by
`SkillCheck.preview()`, bought through the `Advancement` cost curve, recorded in the one
ledger, and refunded by Mirror Rewriting. Weapon competence and per-element competence become
two new skill **groups** (ARMS, TONES) in that same schema — no second track, no second
resolver, no new save shape. Everything a character **is** (ancestry, discipline, class Kit,
Major/Minor, Background, Mastery) is a *grant*: it sets Trained tiers (the Fallout "tag"
analog) and identity fields, never points. DRAMGID sets the size of the creation point pool
and every percentage's base. The wizard becomes a data-driven nine-leaf flow over a pure,
testable `ChargenBuild` model; the class leaf shows what a class *does* (Kit → Trained weapon
skill, Resource, Signature, suggested Chord, discipline compatibility) and grants it. Combat
consumes the new percentages later (F3c, after #281) through two context keys computed in
`forecast_context()`, so forecast == resolution holds by construction.

Principles the code must keep:

1. **One definition.** No stat id outside `DramgidSchema`; class rows live in `ClassCatalog`;
   creation tables in `ChargenData`. The wizard and the sheet iterate schema groups, never
   literal id lists.
2. **One resolver, one ledger.** `SkillCheck.preview()` is the only formula; creation buys
   go through the same bands and land in `GameState.skills` so the Mirror reaches them.
3. **Grants are tiers, points are percentages.** A Kit, a Major, a Background never write a
   percentage. That keeps `skill_percentages` and the ledger in lock-step.
4. **Canon guards in code:** Major/Minor never opposed; no investment in a tone opposed to a
   held tone; Mastery is the only route to 0% fizzle; Kits (and therefore ARMS) ignore the
   Loom; Locksmirk never reaches 0%.
5. **Frozen files stay frozen.** F3a touches globals, chargen, sheet, tests. Combat reads are
   specified here (§4) and land in F3c.

---

## 3. Schema extension — skill groups, ARMS, TONES

### 3.1 Groups (every skill row gains `group`)

| group | label | members | note |
|---|---|---|---|
| `body` | BODY | strain, lilt, slip, tread, brace | Muster / Alacrity / Grit |
| `mind` | MIND | varlore, unweave, recall, wildlore, devotion, vantage | Reason |
| `soul` | SOUL | beastbond, undertone, mending, ear, wayfinding, sounding | Intuition |
| `voice` | VOICE | falsetto, bellow, varum, sway, downbeat | Decorum |
| `arms` | ARMS | §3.2 | new, PROVISIONAL |
| `tones` | TONES | §3.3 | new, PROVISIONAL |

`DramgidSchema.SKILL_GROUPS` (ordered `PackedStringArray`), `GROUP_LABELS`,
`skills_in_group(group)`, `skill_group(skill_id)`, `governing_attribute(skill_id)`,
`is_skill(skill_id)`. If the owner rules "12 skills, not 22" (§12 R1), only the field rows
change; ARMS/TONES and every consumer are unaffected because nothing enumerates ids.

### 3.2 ARMS — five weapon skills (PROVISIONAL, owner ruling R2)

| id | label | attribute | covers (from the ten Kits) | loom |
|---|---|---|---|---|
| `keen` | Keen | alacrity | paired daggers, cleaver, sickle, whip-dagger, knives, short blades | NONE |
| `heft` | Heft | muster | greatsword, greatclub, war pick, axes, mauls | NONE |
| `reach` | Reach | muster | quarterstaff, halberd, spear, net-and-whip | NONE |
| `loose` | Loose | alacrity | blowgun, sling, bow, thrown | NONE |
| `grip` | Grip | muster | spiked gauntlet, fists, wrestling, "lockpicking-as-combat" | NONE |

Why five (Fallout's Melee/Unarmed/Throwing/Small/Big Guns collapsed for a melee-heavy
setting): every canon Kit weapon lands in exactly one row; two Alacrity / three Muster so
Alacrity (already the to-hit-difference attribute) does not double-dip. `loom = NONE` is a
canon guard: Kits work at full strength in the Hush (`magic-system.md`), so `loom_penalty()`
must never touch ARMS — a schema test enforces it. Rows carry
`"source": "sm-chargen-proposal"` so a later canon pass can find every unratified id.

**Kit → skill map** (in `ClassCatalog`, not the schema):

| class | Kit (canon) | arms skill(s) |
|---|---|---|
| mirrorblade | paired balanced daggers | keen |
| river-mother | water harp, net-and-whip | reach |
| ironbrand | greatsword **or** spiked gauntlet | heft **or** grip — the one Kit with a real weapon choice |
| lensbearer | quarterstaff | reach |
| husk-bearer | cleaver or sickle | keen |
| flamebinder | war pick | heft |
| stormbearer | greatclub | heft |
| oathclock | halberd, pendulum bell | reach |
| locksmirk | blowgun | loose |
| threadwalker | whip-dagger | keen |

The Kit's arms skill starts **Trained** (the tag). Every other ARMS skill is Untrained and
raisable with points.

### 3.3 TONES — one skill per Wheel element (PROVISIONAL, owner ruling R3)

Ten rows `tone_<element>` for every id in `ElementWheel.ORDER`, label `"<Element> Tone"`,
attribute **intuition**, `loom = NONE` (the zone already enters fizzle through
`agreement_integrity`; a Loom penalty here would double-count). A Tone is the caster's
**Resonance** in that element — the undefined word in RFC-0002 OQ-0007, given a definition.

Canon guards:

- **Mastery stays the only route to 0%.** A Tone at 95% is not Mastery; `mastery` stays the
  per-Note/Phrase flag (§4.2). Fickah's floor 5 still applies last.
- **Only held tones are open in Chapter 1.** A character holds the Major and Minor Tones;
  the other eight ids exist in the schema but are not purchasable
  (`Advancement.buy` → `blocked_by: "unheld_tone"`; the wizard and sheet list held tones
  only). Because a valid pair is never opposed, this also keeps the canon rule "a mortal
  cannot hold both tones of an opposed pair" (`magic-system.md`) without a second check;
  `DramgidSchema.opposed_tone(id)` (via `ElementWheel.opposite()`) exists for the day a
  third tone opens.
- **Major and Minor Tones start Trained** (two tags). Locksmirk pre-fills nothing
  ("genuinely flexible"). F3c decides how the Major feeds `caster_relation()`; it must **not**
  be written into `BattleActor.element_id`, which is the target-side attunement that
  `ElementMatrix.damage_multiplier()` reads — that would change incoming damage to the party.
- Casting **power is untouched** (`ability.power`); Tones move fizzle only — one lever.

---

## 4. Where the new percentages are read

### 4.1 ARMS in combat (F3c, after #281 and the F3b rename; PROVISIONAL shape, DeepSeek tunes)

```
arms_percent  = SkillCheck.preview(weapon.skill_id, source_member)          # attr×8 + tier + adv, cap 95
weapon_bonus  = floori((arms_percent - 40) / 2)                               # 40 = today's implicit baseline → 0
hit%          = clamp(70 + weapon_bonus + facing + 4×height + 2×(alacrity_atk − alacrity_def), 5, 95)
power         = attack(muster) + weapon.damage + action.power_bonus + flank + balance
element(strike) = weapon.element if set, else identity row                    # replaces the &"suul" placeholder (ruling R9)
```

Calibration at the baseline: Untrained Alacrity 2 (16%) → −12; Kit-Trained Alacrity 3
(44%) → +2 ≈ today; Expert Alacrity 5 (95%) → +27. Enemies read a Pandora `Combatants`
column `Arms Percent` (default 40), so every existing hit-table case reproduces exactly and
the F3b "≤ one band" acceptance survives.

**Weapon identity per member.** `GameState.equipped_slots` cannot say who holds the axe. F3a
adds `PartyMember.kit_weapon_skill` (arms id) and `PartyMember.kit_weapon` (item prototype
id, may be empty until Pandora seeds Kit items). Resolution order in F3c:
`member.equipment.main` (per-member equipment, F4) → class Kit → bare hands (`grip`,
damage 0). Companions therefore always fight with their Kit until F4 — acceptable, Kit is
identity. Pandora `Items` gains `Weapon Skill`, `Damage`, `Element` columns in F3a-5
(generated into the prototree; read-only `WeaponProfile` helper).

Both context builders (`forecast_context()` and the static `Battle.calculate_damage()` path)
must learn `unit.arms_percent` and `unit.weapon`, or the legacy path diverges; F3c should
retire the static path. Roll keys are untouched (`ability_id = "attack"`).

### 4.2 TONES in fizzle (parameter lands in F3a; the live read in F3c)

`SkillCheck.fizzle_percent(..., intuition, mastery, patron, tone_bonus := 0.0)`:

```
tone_bonus          = tier_bonus + advancement of the LOWEST Tone across the composition's elements   # OQ-0007: lowest Resonance
intuition_reduction = max(intuition − 2, 0) × 2                                                        # unchanged, canon
tone_reduction      = floori(tone_bonus / 4)                                                           # Trained +5, Expert +8, each +5% step +1
raw = clamp((base + breadth_add + strain_add) × magnitude_mult − intuition_reduction − tone_reduction − mastery_reduction, 0, 95)
```

Why `/4`: an Untrained Tone's effective % is `intuition × 8`, and `(intuition×8 − 16)/4`
equals today's `intuition_reduction` at every value — the Tone skill *is* the Intuition
reduction with a learned part added on top, so no double-dip and all twelve ratified fizzle
readings (Pitch 2, untrained) are unchanged by construction. `SkillCheck.tone_bonus_for(member,
elements)` computes the lowest-tone bonus so `_fizzle_context()` in F3c is one line
(`fizzle.tone_bonus`, override-able through `deep_merge` like every other key; document in
`docs/class-resources.md`).

**Mastery becomes data:** `PartyMember.mastery_element` (additive, picked on the Elements leaf
from {Major, Minor}, default Major) so F3c can set `fizzle.mastery` for a Note/Phrase of that
element instead of the never-set bool. `starting_mastery` (string) stays for display.

### 4.3 Sheet and forecast reads (F3a)

- Character sheet: ARMS group rows; TONES as one row per held tone (`Scor Tone · I · ◆ ·
  52%`); derivation tooltip adds the tone line.
- Casting forecast panel (`CastingGate`): "Resonance 36% → −5" as a breakdown step (F3c).

---

## 5. Creation-time skill points (canon step 7, formula proposed)

| rule | value | status |
|---|---|---|
| Pool | `6 + reason + decorum` → 10 at floor, 16 at 5/5 | PROVISIONAL (R5) |
| Vael | +1 (canon: "extra skill point at creation") as data `ANCESTRIES[].creation_bonus_points` | canon |
| Flaw | +0 until the flaw table is enumerated (free text is unverifiable) | R6 |
| Cost curve | the ratified bands, judged on the resulting % — no creation discount | canon (R7 optional) |
| Tags (Trained, granted) | Background ×2 · Kit arms ×1 · Major Tone ×1 · Minor Tone ×1 · Weftkin `sounding` (canon "innate Weft-Sensing training", now data `ANCESTRIES[].trained_skills`) | canon + R3 |
| Purchasable at creation | every field and ARMS skill; the two held Tones | R3 |
| Refund at creation | LIFO sell-back of a bought step at its exact cost (wizard only; play has the Mirror) | design |
| Unspent | carries over into `advancement_points`; ACCEPT never blocks on unspent points; summary says "N points carried into play" | design |
| Ledger | creation buys are written to `GameState.skills[member.id]` at ACCEPT (after the id exists) → **Mirror Rewriting refunds them** (canon: "reclaims every advancement point"; tags and Masteries untouched) | design (R8) |

Mechanics: `ChargenBuild` keeps `creation_buys: {skill_id: [cost, cost, …]}` and a scratch
`PartyMember` rebuilt from the current choices; `can_buy`/`buy` use `Advancement.step_cost()`
on that scratch member, so the wizard and the sheet share the bands. Nothing touches
`GameState.skills` until ACCEPT: `GameState.apply_created_character()` /
`add_custom_recruit()` assign the id, then `Advancement.seed_creation_ledger(member, rows)`
writes `{percentage, tier, advancement_points_spent}` per bought skill. No draft rows can leak
on a crash or cancel.

The tier-casing defect is fixed in the same PR: `GameState._validate_save_data` accepts tiers
case-insensitively (SkillCheck already normalizes to lowercase; lowercase is canonical).

---

## 6. Meaningful class choice

### 6.1 `ClassCatalog` (new, `globals/stats/class_catalog.gd`, read-only, PROVISIONAL until Pandora `Classes` carries the columns)

```gdscript
{"id": "ironbrand", "name": "Ironbrand", "patron": "Kero", "patron_id": "kero", "role": "Berserker",
 "kit": "Greatsword or spiked gauntlet, ritual branding.",
 "kit_skills": ["heft", "grip"],                      # >1 entry = the card offers a choice
 "resource": "Scars", "resource_blurb": "Taking damage banks Scars; spend them to buy guaranteed-hit or guaranteed-crit windows.",
 "signature": "Debt of Arms", "signature_blurb": "Trade current HP for a massive damage or buff spike.",
 "suggested_major": "scor", "suggested_minor": "molm", "chord": "Ashfire",
 "retired_disciplines": [],                           # threadwalker: ["chordblade"]
 "watch_disciplines": [],                             # oathclock/locksmirk: ["hushwarden"]
 "notes": "",                                         # locksmirk: "Never reaches 0% fizzle, Mastery included."
 "vault_id": "kero"}
```

Copy comes from `ten-patron-classes.md` one-liners verbatim (marked for canon review, same
rule as recruit bios). `ChargenData.PATRONS` becomes a view over `ClassCatalog.ALL` so the
tavern and sheet keep working. Test: every `kit_skills` id ∈ ARMS; every `patron_id` ∈
`ClassResourceRegistry.PATRON_IDS`; every suggested pair passes `is_valid_element_pair()`;
`for_patron(patron)` is non-Null for all ten.

### 6.2 What the card shows and grants

Shows: name · patron · role · **Kit** line with the tag it grants ("Greatsword — *Heft,
Trained*"; a two-way toggle for Ironbrand) · **Resource** one-liner · **Signature** one-liner ·
suggested Major/Minor with the Chord name and a "Use suggestion" affordance · "Kit holds in
the Hush" mark · compatibility against the Discipline already chosen: clean / *watch* (muted
note, allowed) / **retired** (card disabled, "Not with Chordblade", `ten-patron-classes.md`
2026-08-07 ruling) · Locksmirk's fizzle note. No emblem art exists — monogram tinted by the
suggested Major's Wheel colour until emblems are generated.

Grants at ACCEPT: `class_id`, `patron` (deity display name), `char_class`
(`"Ironbrand (Kero)"`, the roster convention), `kit_weapon_skill` Trained, `kit_weapon`,
Major/Minor pre-fill → Trained Tones. The ClassResource attaches at battle exactly as today
through `ClassResourceRegistry.for_patron(member.patron)` — which now resolves.

### 6.3 Patron vocabulary (ruling R4, defect fix)

`PartyMember.patron` = **deity display name** (`"Kero"`, `"Ofshütje"`) — the roster's
vocabulary, what `has_party_patron("Haeren")` in dialogue compares, what the registry
normalizes. New additive `PartyMember.class_id` (`"ironbrand"`) for the F5 perk lists and the
sheet. The v7→v8 migration (Codex PR 2) rewrites any row whose `patron` matches a class id:
`class_id = patron; patron = ClassCatalog.patron_for(class_id)`; rows with a deity name get
`class_id` derived. `ClassCatalog.class_for_patron_value(value)` accepts either form.

---

## 7. The wizard

### 7.1 Nine leaves (canon order; Flaw folded into Identity, which canon does not place)

| # | id | player decides | gate | data |
|---|---|---|---|---|
| 1 | `ancestry` | one of five; trait shown as a mechanical line; leanings as hint chips (nudges, never auto-applied) | required | `ChargenData.ANCESTRIES` |
| 2 | `discipline` | three cards (movement / reach / verbs blurb) | **required** (today optional) | `ChargenData.DISCIPLINES` |
| 3 | `patron` | ten class cards (§6.2); Kit toggle where offered | **required**; retired pairing blocked | `ClassCatalog` |
| 4 | `elements` | Major / Minor on the `WheelWidget` (pre-filled from the card, editable, clash shown live); Root-Note Mastery pick ∈ {Major, Minor} | valid pair; Major set | `ElementWheel`, `ChargenData.is_valid_element_pair` |
| 5 | `attributes` | THE SEVEN MEASURES, 22 points, floor 2, cap 5; live readouts: HP, Breath, creation pool, Kit hit-band preview | sum 22, each 2–5 | `DramgidSchema`, `DramgidDerived` |
| 6 | `background` | five cards: two Trained skills + feature + Mastery | **required** | `ChargenData.BACKGROUNDS` |
| 7 | `skills` | spend the pool; groups collapsible; tags marked ◆; cost per step; only held Tones listed; refund a step | never blocks | `ChargenBuild` |
| 8 | `identity` | likeness, name, epithet, flaw (optional) | name non-empty | `ChargenData.LIKENESSES` |
| 9 | `summary` | full sheet preview; jump back to any leaf; ACCEPT | every gate | — |

### 7.2 `ChargenBuild` (new, `globals/chargen/chargen_build.gd`, RefCounted, no UI)

The single in-progress character. Public surface:

```
# choices
ancestry_id, discipline_id, class_id, kit_skill, major_element, minor_element, mastery_element,
attributes: Dictionary, background_id, display_name, epithet, flaw, likeness_id
# attributes
set_attribute(id, value) -> bool · step_attribute(id, delta) -> bool · remaining_attribute_points() -> int
# skills
granted_tiers() -> Dictionary          # skill → "trained" from background / kit / major / minor / ancestry
creation_pool() -> int · points_spent() -> int · points_remaining() -> int
can_buy(skill) -> Dictionary           # {allowed, blocked_by, cost, message} — Advancement gate shape
buy(skill) -> Dictionary · refund(skill) -> Dictionary
preview_percent(skill) -> float        # SkillCheck.preview() on the scratch member — the only formula
held_tones() -> PackedStringArray       # the purchasable tone ids (Major, Minor)
# flow
validate(step_id) -> Dictionary        # {valid, message}
to_party_member() -> PartyMember       # DramgidDerived.recompute(), tiers, percentages, class fields, advancement_points = remaining
creation_ledger_rows() -> Dictionary   # skill → {percentage, tier, advancement_points_spent}
```

`ChargenData.preview_skill_percentages()` is deleted (the duplicated formula).

### 7.3 Step registry (`globals/chargen/chargen_steps.gd`)

Ordered `Array[Dictionary]` `{id, title, registry_note, illustration_title}`; the screen builds
one page per entry through a `_build_<id>_page()` map and asks `build.validate(id)` for the
gate. Adding or reordering a leaf is a data edit plus one builder.

### 7.4 Screen public driving API (`ui/screens/character_creation.gd`)

Tests and the tavern use these, never private members:

```
var build: ChargenBuild
select_ancestry(id) · select_discipline(id) · select_class(id) · select_kit(arms_id)
select_major(id) · select_minor(id) · select_mastery(id) · set_attribute(id, value)
select_background(id) · buy_skill(id) · refund_skill(id)
set_display_name(text) · set_epithet(text) · set_flaw(text) · select_likeness(id)
next_step() · back_step() · go_to_step(id) · current_step_id() -> StringName · can_advance() -> bool · accept()
```

`Mode.PLAYER` / `Mode.RECRUIT`, `recruit_created`, the ACCEPT juice and the `new_game` event
are unchanged. ACCEPT order: build member → register (id assigned) → seed ledger → juice →
event/close.

### 7.5 Presentation (design system, `ui/theme/theme_builder.gd`)

Add type variations only — no per-node overrides: `ChargenCard` (PanelContainer, notched
frame, selected = violet edge, disabled at 42% alpha with the reason line), `ChargenCardTitle`
(display font), `ChargenCardMeta` (numeric font, ASH), `ChargenCardGrid` (GridContainer, 2
columns on the class leaf, 1 on discipline/background), `ChargenSkillRow` (HBox: name ·
attribute letter M/A/R/G/I/D · tier mark · effective % in Fira · `+5% (n pt)` / `−` buttons),
`ChargenGroupHeader`. Keep the one-bronze-element rule (attributes panel) and zero `tr()`.
Focus ring: every card and skill row registers in the page's focusable list; the rail marker
for each leaf keeps `ChargenStepMarker`.

---

## 8. PartyMember, GameState, save

Additive fields (serialize; loader defaults; **no schema bump** in this PR — the v8 bump is
Codex PR 2): `class_id: String`, `kit_weapon_skill: String`, `kit_weapon: String`,
`mastery_element: String`. `attribute_value()` falls back through
`DramgidSchema.ATTRIBUTE_RENAMES` in both directions so a DRAMGID-keyed member still answers a
legacy-id skill check (dialogue) and vice versa until PR 2 lands.

`Advancement`: `seed_creation_ledger(member, rows)`; `buy()` gains the `unheld_tone` gate
(a `tone_*` skill is purchasable only when it matches `member.major_element` or
`minor_element`); tier strings stay lowercase. `GameState`:
validator accepts tier casing; `apply_created_character()` / `add_custom_recruit()` unchanged.

Notes for PR 2 (migration): patron rewrite (§6.3); `class_id` derivation for the 20 roster
rows from `char_class`; Kit and Tone Trained tiers for legacy rows with a class/elements;
attribute-less hand-authored rows (`Vex`, recruits) must synthesize attributes
(`grit = max_hp/8, muster = attack, alacrity = defense, others 2`) before any `recompute()`.
`UnitMigration.reconcile()` projects `max_hp` into the tactical roster on save — unchanged.

---

## 9. Character sheet (F3a, same PR or the next)

Six groups from `SKILL_GROUPS`; ARMS and TONES open by default, field groups collapsible; TONES
shows the two held tones as rows (the `WheelWidget` stays as it is — per-spoke values are
new drawing work, deferred); buy buttons unchanged; derivation tooltip adds the weapon/tone
line. 37 ids in the schema, 29 rows visible for a two-tone character.

---

## 10. Sequencing and ownership

| slice | branch / PR | contents | owner | status |
|---|---|---|---|---|
| F3a-4a | `feat/dramgid-chargen` (this) | schema groups + ARMS + TONES; `ClassCatalog`; `ChargenData` retarget; `ChargenBuild` + steps; wizard rewrite with public API; `Advancement`/`SkillCheck`/`PartyMember` additive changes; validator casing; tests | Claude (first slice) | in progress |
| F3a-4b | same or follow-up | sheet groups + Wheel tone badges; manual checklist | Codex | handoff W2 |
| F3a-5 | `feat/dramgid-pandora` | Items `Weapon Skill/Damage/Element`, ten Kit items, Combatants `Arms Percent`, `WeaponProfile`; Defining-Strike `check_skill` legacy ids (`generate_gloot.gd:867`) | Codex | handoff W3 |
| PR 2 | `feat/dramgid-save-8` | v8 + §8 notes | Codex | handoff W4 |
| numbers | `docs/briefs/dramgid-numbers-deepseek.md` addendum | pool, arms baseline, tone divisor, enemy default, kit hit bands | DeepSeek | handoff N1 |
| F3c | after #281 + F3b | §4.1/§4.2 live reads in both context builders; retire static path | Codex | blocked |

Ship note: ARMS/TONES percentages are visible but combat-inert until F3c. The playtest packet
must say so, or testers will report "weapon skill broken".

---

## 11. Test plan (gdUnit4)

- `test_dramgid_schema`: 37 ids; every row has a valid `group`; groups partition `SKILL_IDS`;
  ARMS attributes ∈ {muster, alacrity} and loom NONE; a `tone_<e>` for every
  `ElementWheel.ORDER` id, attribute intuition, loom NONE; `opposed_tone("tone_scor") ==
  "tone_aqua"`; `tone_skill_for("scor") == "tone_scor"`; `loom_penalty()` returns 0 for every
  ARMS/TONES id.
- `test_class_catalog`: ten rows; kit skills ∈ ARMS; `patron_id` ∈ registry ids; suggested
  pairs valid; `for_patron()` non-Null; Threadwalker retires Chordblade.
- `test_chargen_data`: backgrounds reference schema ids only; Vael +1; Weftkin trained
  `sounding`; leans use DRAMGID labels.
- `test_chargen_build`: attribute budget (cannot exceed 22 / cap 5 / floor 2); pool table
  (10 / 16 / Vael 11); tags; buy/refund round-trip keeps `points_spent` exact; unheld-tone
  block; preview equals `SkillCheck.preview()` on `to_party_member()`; `validate()` per leaf;
  `to_party_member()` writes patron/class_id/kit/tiers/percentages/derived stats.
- `test_skill_check`: twelve ratified fizzle readings unchanged at `tone_bonus 0`;
  `tone_bonus 20 → −5`; Fickah floor last; `tone_bonus_for()` picks the lowest tone.
- `test_advancement`: `seed_creation_ledger` rows validate through `_validate_save_data`;
  `mirror_rewriting` refunds creation points; unheld-tone gate.
- `test_character_creation` (integration): nine leaves gate in order; class card disabled after
  Chordblade for Threadwalker; Ironbrand kit toggle; accepted protagonist has `patron "Kero"`,
  `class_id "ironbrand"`, `heft` Trained, `tone_scor` Trained, ledger rows, `advancement_points
  == pool − spent`; RECRUIT mode writes only `custom_recruits`; save → load round-trip keeps the
  same effective %; `ClassResourceRegistry.for_patron(member.patron)` is non-Null.
- Manual: `test/manual/character_creation_checklist.md` (new).

---

## 12. Owner rulings needed (the code implements the default until ruled)

| # | ruling | default implemented |
|---|---|---|
| R1 | Field skill list: RFC-0005's 22 (PR #361) vs SM-RFC-0001's 12. Wizard and sheet are list-agnostic. | 22 (as PR #361) |
| R2 | ARMS exist as five schema skills (keen/heft/reach/loose/grip) with the Kit map in §3.2; Ironbrand is the one Kit with a weapon choice. | yes |
| R3 | TONES exist as ten Intuition skills beside Mastery; Major and Minor both Trained and the only purchasable tones in Chapter 1; lowest tone rules Chords/Triads (OQ-0007). | yes |
| R4 | `patron` = deity display name, `class_id` additive; migration rewrites class-id rows. | yes |
| R5 | Creation pool `6 + reason + decorum` (+1 Vael); unspent carries over. | yes |
| R6 | Flaw grants +0 until the flaw table exists. | yes |
| R7 | (optional) tagged skills cost one band less at creation — a Fallout-tag feel; changes the ratified bands. | **no** |
| R8 | Creation points are advancement points → Mirror-refundable. | yes |
| R9 | Plain attacks take their element from the weapon (drops the `&"suul"` placeholder) — F3c. | deferred to F3c |
| R10 | Discipline, Patron, Background become required leaves; nine-leaf order. | yes |
| R11 | Tone fizzle term `floori(tone_bonus/4)` and ARMS hit baseline 40 — numbers for DeepSeek. | as §4 |
| R12 | Which attribute caps the Soul Gauge (Intuition per `character-creation.md` vs Grit per L-RFC-0006) — surfaces on the attributes leaf readouts. | Intuition (schema text) |

---

## 13. Risks

1. **Inert numbers until F3c** — two weeks of playtests with a sheet that lies unless the
   packet flags it, or F3b + F3c ship before content lock (Sep 21).
2. **"22 skills" is a ratified phrase** (ruling 8); 37 is a visible departure and RFC-0005 is
   itself `superseded` in mono. Expect canon pushback; the fallback is Mastery-only (drop
   TONES) and the design loses one column, nothing else.
3. **Merge hazard:** F3c lands on the same `resolution.gd` / `combat_controller.gd` lines as
   the F3b rename — one Codex PR after #281 or accept conflicts.
4. **Schema PR in flight:** PR #361 is unreviewed; this branch stacks on it and must rebase if
   Codex amends the schema.
5. **Comprehension for #93 testers:** 29 visible rows. Mitigated by groups, held-only tones,
   collapsed field groups, and the hit-band / fizzle readouts on the attributes leaf.
6. **Hand-authored recruits have no attributes** → 0% previews and zeroed HP on recompute
   until PR 2 synthesizes them.
7. **Alacrity vs Muster balance** (Alacrity: to-hit difference + keen/loose; Muster: power +
   heft/reach/grip) — DeepSeek must check light builds do not dominate.
8. **No emblem/discipline/background art**; cards launch with monograms.

## 14. Open questions this note does NOT resolve

Perk cadence and lists (F5); Chapter-1 level cap; XP (ruling 9) vs milestone leveling (owner
2026-08-24); per-member equipment UI (F4); flaw table; Pandora `Classes` table; enemy ARMS
authoring; the nine "watch" discipline cells beyond the three recorded.
