# Calling and measures — making class and attribute choices count (2026-11-25)

Status: **sprint plan and as-built, PROVISIONAL throughout.** Owner request, 2026-11-25:
"choices need to be more impactful in terms of differentiating classes and the attribute system
needs to also be more impactful." Built overnight without owner input; every number and every new
rule here is PROVISIONAL until the owner answers the questions in §6, which are also logged in
`docs/owner-decisions.md`. Ratified numbers are kept exactly where a build has not invested in a
measure (see §2's rule), so a playtest that ignores this sprint plays as before.

Branch `claude/chargen-classes-sprint`, stacked on #644 (chargen "In a fight" row).

## 1. What the audit found (2026-11-25, current `main`)

| Choice | What it changes in play today |
|---|---|
| **Class** | One resource loop and one signature each. No measure reads a class ability, so a Lensbearer with Reason 2 and one with Reason 5 have the same Clarity. Every class can cast every spell that is not patron-locked (owner SR9: no off-tone penalty). |
| **Discipline** | Nothing. Chordblade, Thamshaper and Hushwarden are text (`ChargenData.DISCIPLINES`: "no numeric baseline is ratified"). |
| **Kit** | Trains one ARMS skill, shown as a percentage in chargen and on the sheet. No combat code reads ARMS: the number is display only. |
| **Background** | Two Trained skills and a starting Mastery (live). The feature line is text. |
| **Ancestry** | Vael +1 creation point and Weftkin Trained Sounding are live; Kaan, Vaerin and Kes'reth traits are text. Leanings are text by canon ("nudges, not flat bonuses"). |
| **Measures** | Reason, Alacrity, Muster are big (turn speed 7→10, damage taken per hit ~4→~1, basic-attack power 4→10). Grit and Intuition are moderate (HP, Breath). Decorum is small (voice skills, ~5 pp barter). Doctrine only scales Karma, which no screen shows. The MEASURES tab shows none of these numbers. |

Smaller facts the audit turned up:

- Spell damage is the card's flat power. No measure scales it.
- Alacrity's action-point term is dead: every live fight runs charge time (D8), which ignores AP.
- Grit's "Discord/backlash resistance", Muster's "carry", Intuition's "Soul Gauge ceiling" and
  Decorum's "Consonance" and "Name-Ledger" exist only as schema text.
- Hand-made companions (`GameState._make_member`) have an empty attribute map, so every
  measure reads 0 for them: charge speed 5, no Alacrity in to-hit, no attribute share in skills.
- No content rolls a Grit skill (Brace) or an ARMS skill.

## 2. The design in one paragraph

**Class tells you which measures pay; measures decide how strong your class is.** Ruling 8
says the warrior who invests elsewhere "keeps weaker class abilities", and that is the coupling
this sprint builds. Each class names one **patron measure**. Above 3, each point strengthens the
class loop (+1 at 4, +2 at 5; nothing changes at 2 or 3, so the ratified B11 numbers hold for an
uninvested build). The Kit's ARMS skill goes live on weapon attacks, so the Kit and the measure
that governs it (Muster or Alacrity) show up in the hit chance. Disciplines get the movement and
footing that canon gives them. Chargen then shows all of it as numbers: each measure row says
what it does for this character now and what the next point buys, and the class card names its
patron measure.

## 3. Slices

| # | Slice | What a player sees | Status |
|---|---|---|---|
| S1 | **Patron measures** | Each class loop grows at measure 4 and 5 (table §4). | see As built |
| S2 | **Measure readouts** | MEASURES rows show live numbers and the next point's gain; the CALLING card names the patron measure; the sheet shows the same lines. | see As built |
| S3 | **Arms live** | The Kit's ARMS skill moves the hit chance of weapon attacks (F3c §4.1). | see As built |
| S4 | **Disciplines live** | Chordblade, Thamshaper and Hushwarden each change one fight rule. | see As built |
| S5 | **Class-shaped rolls** | RANDOMIZE, QUICK START and a SUGGEST button spend measures toward the class. | see As built |

Boundaries: no save-schema bump (every new field is additive and defaults to "no change"), no
change to enemies, no change to authored companions (their measures read 0, so they gain
nothing until §6 Q4 is answered), no canon prose, no Pandora writes.

## 4. Patron measures (S1)

`bonus = clamp(measure − 3, 0, 2)`. One number per class, chosen so the loop the B11 sweep
balanced keeps its shape and only grows.

| Class | Measure | Why this measure | At 4 / 5 |
|---|---|---|---|
| Mirrorblade | Alacrity | Duelist footwork, precision | Unbalanced hits ×1.35 / ×1.45 (ratified ×1.25) |
| River-Mother | Decorum | Canon: Decorum governs "Name-Ledger effectiveness" | Each name pays 4 / 5 Breath (3) |
| Ironbrand | Grit | Kero endures; Scars bank from damage taken | Scar cap 4 / 5 (3) |
| Lensbearer | Reason | Disclosure, reading the field | 4 / 5 Clarity per battle (3) |
| Husk-bearer | Muster | The Maw; Hunger is appetite | Hunger cap 4 / 5 (3) |
| Flamebinder | Reason | Instructive failure is a lesson learned | Token cap 4 / 5 (3) |
| Stormbearer | Intuition | The storm answers the caster's ear | Every storm row +1 / +2 damage |
| Oathclock | Reason | The Warden's timing and procedure | A Sentence deals 8 / 10 (6) |
| Locksmirk | Alacrity | The quick hand that jams the gear | Jam the Gears also delays its target 10 / 20 CT |
| Threadwalker | Decorum | A contract is agreed before it binds | A Hostility payoff deals 8 / 10 (6) |

Perks stack on top (a `cap_delta` perk still adds its +1). Companions and enemies read measure 0
and gain nothing.

## 5. As built

Every number below is PROVISIONAL and listed in owner item 51. Evidence frames:
`docs/qa/calling-measures-2026-11-25/`.

| Slice | Code | What a player sees | Tests |
|---|---|---|---|
| S1 | `ClassResource.apply_measure()` / `measure_bonus()`; `ClassCatalog` `measure` column and `patron_measure_value()`; the ten resources; `CombatController._attach_class_resources()` | Each loop plays its B11 number at measure ≤3 and grows at 4 and 5 (§4 table). A filed Sentence, a bound Hostility and a Jam say the measure's share in their forecast. | `test_patron_measures.gd` |
| S2 | `MeasureEffects` (pure; reads DramgidDerived, `CombatRules.charge_speed_at()`, Resolution, `SkillCheckService.intuition_fizzle_reduction()`, the class resource) | MEASURES rows: live numbers, then in gold what +1 changes. CALLING card: PATRON MEASURE with the loop now and at 4 and 5. Entry column: SPEED. Sheet: patron measure line; attribute tooltips carry the numbers. | `test_measure_effects.gd`, `test_character_creation.gd`, `test_character_sheet.gd` |
| S3 | `Resolution.arms_bonus()` and the `arms` modifier; `CombatController.arms_terms()` in both context builders | A weapon attack's hit chance carries the Kit skill: (ARMS % − 40) / 2. The forecast lists it as "Heft 57% +8 pp"; MEASURES shows "weapon hits +8%". Spells, enemies and authored companions carry no term. | `test_arms_in_combat.gd` |
| S4 | `DisciplineProfile`; `CombatController._move_cost_modifiers()`, `_tile_context()`, `discipline_accuracy_modifiers` | Chordblade: every path costs 20% less. Thamshaper: +4% to hit from higher ground, and a foe attacking up at one pays 4%. Hushwarden: cells within 1 are hushed (no tile charge feeds or takes a Song). The CALLING card says so. | `test_disciplines_in_combat.gd` |
| S5 | `ChargenRandomizer.class_leanings()`, `roll_measures()`, `suggest_measures()`; SUGGEST button | RANDOMIZE and QUICK START weight points 4/3/2/1 toward the patron measure, the Kit's measure, then Intuition. ROLL THIS TAB on MEASURES rolls for the build's own class. SUGGEST FOR <CLASS> places patron measure 5, Kit measure 4, then 3s. | `test_chargen_randomizer.gd`, `test_character_creation.gd` |

**Not built, and why**

- Hushwarden's fizzle tax: canon gives the field one, but who it taxes is open (vault
  `ten-patron-classes.md`). Item 51 (d).
- Enemy ARMS: §4.1 names a Pandora `Combatants` column `Arms Percent` (default 40). Pandora owns
  data, so enemies stay at the neutral baseline until the column is added. Item 51 (b).
- Rendered battle frame of the Arms and footing terms: proven headless through the forecast
  and commit; no battle capture was taken.
- The class demo (5v5) still places measures evenly; it was left alone so its balance tests
  hold. Item 51 (m).

## 6. Questions for the owner

`docs/owner-decisions.md` item 51.
