# DRAMGID migration — architecture note (F3 design, #283)

**Status:** DRAFT for owner ratification (§5) · 2026-09-04, progress recorded 2026-09-08 (§3, §7)
· author: Claude (architecture) · fact base:
`docs/briefs/dramgid-brief.md` (Codex reader, every claim cited there; this note cites the brief as `B§n`).
**Ratified inputs:** `docs/game-identity.md` rulings 8–9 (class = identity, DRAMGID = what you can do;
XP + skill points + class perks), fleet F3/F5 rows, mono RFC-0001 (Accepted). **Implements:** the
schema, the migration, `SkillCheck`, chargen, Pandora columns, Yothmeru-on-`Renown`. **Does not
implement:** XP awards, perk lists, carry weight, Loom zones (F4/F5 own those; §4).

---

## 0. Read this first

DRAMGID replaces the six-stat build (Forge/Edge/Anchor/Spark/Pitch/Voice, 12 skills, 20-point buy) with
**seven attributes, 22 skills, a 22-point buy** (B§2). The brief found fourteen contradictions (B§7);
this note routes each one either to a rule below or to an owner ruling in §5. Nothing is resolved
silently. Three facts shape the design:

1. **The budget math migrates exactly.** Old saves sum to 20 across six attributes; the seventh
   attribute, Doctrine, has no skills and a floor of 2, so `old 20 + Doctrine 2 = 22`. A save migrates
   with a pure rename plus one constant — no rebalancing pass (§2.1).
2. **Combat reads stats in files F1 owns right now.** `combat_rules.gd`, `resolution.gd`,
   `combat_controller.gd` read Edge (B§3, B§8). F3 therefore ships in two halves: **F3a** (schema,
   data, chargen, `SkillCheck`, dialogue, `Renown`, save 8) touches no combat file and starts now;
   **F3b** (combat stat reads) lands after #281 merges (§3.9).
3. **The 22-skill table exists only in a `proposed` RFC** (mono RFC-0005) while the Accepted
   character-creation file names 12 skills; the owner ratified "22 skills" in game-identity. This
   note adopts the RFC-0005 table **PROVISIONALLY** and asks the owner to ratify RFC-0005 in mono
   (§5.1). Ship plan's "save schema 7" gate wording is stale: DRAMGID shipped as **schema 9**
   (this note originally said 8; the elemental-wheel rename took that slot — see §2.1).

---

## 1. The canonical schema (one source of truth in code)

`globals/stats/dramgid_schema.gd` (`class_name DramgidSchema`, static, data-only) is the **only**
place attribute and skill ids, labels, governing attributes, Loom sensitivity and point-buy constants
live. `SkillCheck`, chargen, the character sheet, Pandora seeders, generators, encounter validation,
Weftlumin's character kind and the tests all read it. No other file may hard-code a stat id.

### 1.1 Attributes (RFC-0001, B§2)

| id | label | governs (design intent) | replaces |
|---|---|---|---|
| `doctrine` | Doctrine | Karma volatility (`karma_shift = base × Doctrine/10`); no skills | — (new) |
| `reason` | Reason | initiative/CT speed, tactics, non-elemental checks | Spark (PROVISIONAL, §5.3) |
| `alacrity` | Alacrity | accuracy, evasion, to-hit difference | Edge |
| `muster` | Muster | raw power (attack), carry | Forge |
| `grit` | Grit | HP pool, Discord/backlash resistance | Anchor |
| `intuition` | Intuition | Soul Gauge / Breath ceiling, base fizzle reduction | Pitch |
| `decorum` | Decorum | Consonance, Name-Ledger, social leverage, Fame volatility (`fame_shift = |base| × witness × Decorum/10`) | Voice |

Point buy: every attribute starts at **2**, total **22**, creation cap **5**, attributes rise only through
rare story boosts (B§2 "Point buy"; identity ruling 9). Ids are snake_case in code; the mono `ATTR.*`
tokens are the vault-side names (the `Vault Id`-style bridge is the schema's `mono_token` column).

### 1.2 Skills (RFC-0005 table, PROVISIONAL until §5.1)

| id | label | attr | Loom | old skill it absorbs |
|---|---|---|---|---|
| `strain` | Strain | muster | none | Athletics |
| `lilt` | Lilt | alacrity | none | — |
| `slip` | Slip | alacrity | none | Sleight of Hand |
| `tread` | Tread | alacrity | none | Stealth |
| `beastbond` | Beastbond | intuition | none | Beast Handling |
| `varlore` | Varlore | reason | full | — |
| `unweave` | Unweave | reason | full | Investigation |
| `recall` | Recall | reason | none | Lore |
| `wildlore` | Wildlore | reason | partial (Pozor exception) | — |
| `devotion` | Devotion | reason | partial (UNSETTLED, §5.6) | — |
| `undertone` | Undertone | intuition | full | Insight |
| `mending` | Mending | intuition | none | — |
| `ear` | Ear | intuition | partial | — |
| `wayfinding` | Wayfinding | intuition | partial (Pozor exception) | Survival |
| `sounding` | Sounding | intuition | full | Weft-Sensing (stated by RFC-0005) |
| `falsetto` | Falsetto | decorum | none | — |
| `bellow` | Bellow | decorum | none; negative-Karma tier bonus | — |
| `varum` | Vārum | decorum | none; received performance shifts Fame | Performance |
| `sway` | Sway | decorum | none; positive-Karma tier bonus | Persuasion |
| `downbeat` | Downbeat | decorum | none; combat: banks +1 Tempo | — |
| `brace` | Brace | grit | none; combat: reduces ally Discord damage | — |
| `vantage` | Vantage | reason | none; combat: battlefield reads | — |

**Alchemy has no DRAMGID target.** Its advancement is refunded to the skill-point pool on migration
(the Mirror Rewriting precedent: refunds advancement without changing identity — B§2). Owner
confirms §5.2. Loom sensitivity is stored as an enum `NONE | PARTIAL | FULL`; F3 adds the field and a
`loom_penalty(skill, zone) -> int` hook that returns 0 until F4 defines Hush/Waning zones.

### 1.3 Resolution (unchanged shape, B§2/B§8)

d100 roll-under; `effective% = attribute × 8 + tier_bonus(0/20/35) + advancement + situation + karma_bonus`,
cap 95, one Expert reroll per scene, advancement in +5% steps costing 1/2/3 points through 50/75/95.
`karma_bonus` is new and non-zero only for `bellow` (negative Karma tiers) and `sway` (positive Karma
tiers); DeepSeek sets the per-tier values (§6). Everything else in `SkillCheck` keeps its numbers.

---

## 2. Migration rules

### 2.1 Save schema 8 → 9 (`SaveMigrations._migrate_v8_to_v9`)

> **Renumbered 2026-09-07.** This section originally said 7 → 8. That slot is taken: the
> elemental-wheel rename shipped as `_migrate_v7_to_v8` (#371, `f5d7e24`) and
> `CURRENT_SCHEMA_VERSION` is 8 on main. DRAMGID is the next hop, 8 → 9.

For every party row and custom-recruit row (B§3 `PartyMember`, B§5):

1. `attributes`: rename keys by the table in §1.1 (`forge→muster`, `edge→alacrity`, `anchor→grit`,
   `pitch→intuition`, `voice→decorum`, `spark→reason`); add `doctrine: 2`. Assert the new sum is 22
   for player-created rows; authored recruits keep whatever they sum to (they were never point-bought).
2. `skill_percentages` / `skill_tiers`: rename by §1.2's last column; **Alchemy**: compute the points
   spent from its percentage via the advancement cost curve and add them to `advancement_points`
   (name per `globals/advancement.gd`), then drop the key. Skills with no old source start at 0%/tier 0.
3. Add `xp: 0` and keep `level`; add nothing for perks (F5 decides the perk container).
4. `renown`: **nothing to do — §3.7 shipped without needing a migration** (#384). Karma rides the
   existing append-only `log` under `kind: "karma"` rather than a parallel list, and `karma_total()`
   is derived by replaying it, so a pre-Yothmeru envelope loads as Karma 0 on its own. The four keys
   `RenownEvent` gained are additive and default to what an old row actually meant.
5. `skill_check`: recorded recent checks carry old skill ids — rename in place.
6. Derived stats (`max_hp`, `attack`, `defense`, `breath_max`) are **recomputed** from the new
   attributes by the DeepSeek-ratified formulas (§6) rather than copied; the migration logs the
   before/after per member so a playtester can see the change.
   > **Deferred, 2026-09-08 (#392).** Steps 1, 2, 3 and 5 shipped; this one did not. §6 has not
   > frozen, and `DramgidDerived` (§3.3) does not exist. A migrated member therefore keeps its
   > stored derived stats, and there is a test asserting exactly that, so the gap is visible in
   > the suite rather than assumed. Stubbing the recompute with today's formulas (what §7
   > originally suggested) would have rewritten every migrated save's combat numbers once now
   > and again after §6 freezes; carrying them across rewrites them zero times. When §6 lands,
   > this is an addition to `_migrate_v8_to_v9`, not a rewrite of it.

Everything else in the envelope is untouched. Weftlumin's `world_seed`/`phase_count`/`spawn_state` are
additive keys and do not participate (`docs/architecture-in-game-editor.md` §4.10).

### 2.2 Text and data

- `.dialogue` files: `SkillCheck.resolve("<old>")` / `last_check_succeeded("<old>")` ids renamed
  mechanically in `council_elder`, `lower_trial_hall`, `dom_side_quests` (B§3); `tools/quest_audit.gd:1100`'s
  id list reads `DramgidSchema` instead of a literal list; `docs/dialogue-checks.md` updated.
- Pandora (`tools/seed_pandora.gd`): **Combatants** — replace the single `Edge` column with seven
  attribute columns (ints, default 2); **Peoples** — add `Leaning Primary` / `Leaning Secondary`
  (attribute ids, display-only in F3; §5.4); **Classes** — no F3 change (perks are F5's `Perks`
  category). `data.pandora` re-seeded; `data/generated/encounters.json` enemy blocks carry seven
  attributes; `campaign_encounter_loader.ENEMY_FIELDS` requires them (Weftlumin E5.2 later removes
  grid/weather, not stats).
- Chargen backgrounds (`globals/chargen_data.gd`) retrain to new skill ids; ancestry entries use the
  five scoped peoples (Vael, Kaan, Vaerin, Weftkin, Kes'reth) with their stated leanings (B§2).

---

## 3. Surface-by-surface changes

**Status as of 2026-09-08.** Seven of the eleven surfaces have shipped. The `Half` column
says which half of F3 a surface belongs to; the `Status` column says what actually landed.
Anything still open is open for a named reason, not because nobody has picked it up.

| # | Surface | Status | Landed in |
|---|---|---|---|
| 3.1 | `dramgid_schema.gd` | **done** | `03e74195` |
| 3.2 | `skill_check.gd` | **done** — definitions from the schema, `karma_bonus` live on Yothmeru | #390 |
| 3.3 | `party_member.gd` / `battle_actor.gd` | **done** — `xp` field, the legacy↔DRAMGID `attribute_value()` bridge, and `DramgidDerived.recompute` (live consumer: `ChargenBuild.to_party_member()`) | chargen wave; §6 freeze |
| 3.4 | chargen + character sheet | **done** — the sheet reads `DramgidSchema.SKILL_GROUPS`; `ChargenData.SKILL_IDS`/`SKILL_LABELS` deleted | #394 |
| 3.5 | `advancement.gd` | **done** — the Alchemy refund arrives through the schema-9 migration | #392 |
| 3.6 | Pandora seeders + generators | **partial** — the Combatants category carries all seven attribute columns and they reach `BattleActor` 2026-09-07; the `check_skill` rename is still open, see the note under the table |  |
| 3.7 | `renown.gd` (Yothmeru) | **done** — see §3.7a for how its two halves were reconciled | #384 |
| 3.8 | `save_migrations.gd` | **done** — schema 9, §2.1 steps 1/2/3/5; step 6 deferred with §3.3 | #392 |
| 3.9 | combat rules | **partial** — to-hit/AP/CT attribute moved to Alacrity 2026-09-07; the CT *formula* (`6 + Reason/2`) and the damage power term are still F3b, after #281 |  |
| 3.10 | dialogue + quest audit + docs | **done** — 14 authored checks and 4 code call sites renamed; the quest audit needed no change (it matches the shape of a `check(` call, not a literal id list) | #393, #395 |
| 3.11 | tests | **rolling** — each surface above carried its own cases |  |

**§3.6's attribute columns landed 2026-09-07; what is left is the `check_skill` rename.**

The original deferral said `Edge` was read by the to-hit rule and that moving that read to
Alacrity was §3.9, blocked on #281 — so seeding seven columns would strand them. §3.9's
*attribute* half shipped that day, which voided the deferral, and leaving it in place had a
cost of its own: canon authored all seven attributes per archetype while Pandora carried one
column, so `data/generated/encounters.json` carried one number and every enemy read **0** for
doctrine, reason, muster, grit, intuition and decorum. `attribute_value()` returns 0 for a name
it does not hold, so nothing said so — the same silent shape as the chargen defect §3.9 closed
on the party's side.

The Combatants category now carries one `int` column per attribute, named off
`DramgidSchema.ATTRIBUTES` labels rather than a second literal list; `generate_gloot.gd` emits
them as an `attributes` block; `EncounterCatalog._actor_from_row()` reads that block by schema
id, so an eighth attribute would arrive without a code change. **`Edge` is kept beside
`Alacrity`, not replaced**: `Edge` is the key authored campaign packages write
(`campaign_encounter_loader.gd`), so both carry the same number, a package row with only `edge`
still lands on Alacrity, and the runtime prefers the DRAMGID block when it is present. Pinned by
`test_canon_and_the_generated_encounter_table_agree` (canon → Pandora → generated, all seven)
and three cases in `test_encounter_catalog.gd`.

Five of the six new attributes still have no *reader* — the CT formula on Reason, the damage
power term on Muster and `_fizzle_context`'s Intuition are §3.9's remaining half, after #281.
They are seeded anyway because the alternative is not "no data" but "0", silently, at the first
consumer that arrives — including #412's enemy stat scaling.

The other half of §3.6 (Peoples `Leaning Primary`/`Leaning Secondary`) is display-only in F3 and
`ChargenData.ANCESTRIES` already carries `lean_ids`, so it buys nothing on its own.

**Still open in §3.6:** `tools/seed_phase_one_pandora.gd`'s 14 authored `check_skill` values
are `lore`/`insight` — pre-DRAMGID ids whose renames are `recall`/`undertone`. They still
*resolve*, through `DramgidSchema.LEGACY_SKILL_DEFINITIONS` and `attribute_value()`'s
legacy bridge, so this is stale data rather than a live defect. It was left out of the column
re-seed on purpose: those two ids are also the legacy-compat fixture in roughly thirty test
files (`test_skill_check`, `test_advancement`, `test_party_member`, `test_save_game`), and the
defaults mirroring them live in `combat_controller.gd` and an assertion in `generate_gloot.gd`.
Renaming them is a data change with its own blast radius, not a rider on this one.

### 3.0 The original plan (for reference)

| # | Surface | Change | Half |
|---|---|---|---|
| 3.1 | `globals/stats/dramgid_schema.gd` (new) | Attributes, skills, Loom enum, point-buy constants, old→new maps, `mono_token`s; pure static | F3a |
| 3.2 | `globals/skill_check.gd` | Definitions built from the schema (22); `karma_bonus` term; `loom_penalty` hook (returns 0); `fizzle_percent`'s `pitch` parameter becomes `intuition` (same formula: `max(intuition − 2, 0) × 2`, §6 verifies); recorded-check id rename | F3a |
| 3.3 | `globals/party_member.gd`, `globals/battle_actor.gd` | Attribute dictionaries keyed by new ids; `attribute_value()` unchanged API; `xp` field; derived-stat recompute helper `DramgidDerived.recompute(member)` | F3a |
| 3.4 | `globals/chargen_data.gd`, `ui/screens/character_creation.gd/.tscn`, `ui/screens/character_sheet.gd` | Seven rows, 22-point text, skills grouped by attribute, five peoples with leaning hints, `_build_member` uses `DramgidDerived`; all labels through the schema (POT-ready) | F3a |
| 3.5 | `globals/advancement.gd` | Skill-point pool receives Alchemy refund; API otherwise unchanged (XP curve is F5) | F3a |
| 3.6 | Pandora seeders + generators + `campaign_encounter_loader.gd` | Columns per §2.2; drift checks green | F3a |
| 3.7 | `globals/renown.gd` | **Yothmeru on Renown**: add signed `karma` ledger (`gain_karma(actor, base, cause, scene)` applies `× Doctrine/10` of the *player* at write time and records both `base` and `applied`), `karma_total()`, `karma_tier()` (seven tiers, thresholds from RFC-0007 via §6), `fame()` = reputation + infamy, `fame_tier()` (five tiers); `gain_reputation/gain_infamy` gain an optional `witness_factor` (default 1.0) and apply `× Decorum/10`; extreme-tier decay (Damned/Exalted/Legendary toward the boundary) runs on `WorldClock` day change only — never on a timer; `why("karma")` supported. Existing totals/API untouched so tavern gates keep working | F3a |
| 3.8 | `globals/save_migrations.gd` | `CURRENT_SCHEMA_VERSION = 9`, `_migrate_v8_to_v9` per §2.1, fixture saves for v8→v9 (8 is the wheel rename, #371 — see §2.1) | F3a |
| 3.9 | `globals/combat/combat_rules.gd`, `resolution.gd`, `combat_controller.gd` | **DONE 2026-09-07**: to-hit difference on Alacrity; `action_point_attribute`/`charge_speed_attribute` on Alacrity; the snapshot key and `PROVISIONAL_TO_HIT` constant renamed with their readers; `BattleActor.attribute_value()` resolves the legacy name both ways. **STILL F3b, after #281**: the CT *formula* `6 + Reason/2` (this moved the attribute, not the curve), `calculate_damage`'s power term on Muster, and `_fizzle_context` supplying Intuition | **partial** |
| 3.10 | Dialogue + quest audit + docs | §2.2 renames; `docs/dialogue-checks.md`; CLAUDE.md status line ("save schema 8") | F3a |
| 3.11 | Tests | `test_chargen_data` rewritten to the schema; 147 legacy-id lines across `test/` (B§3) renamed by map; new: schema invariants (22 skills, each with a governing attribute; sum-22 validation), v7→v8 migration fixtures incl. Alchemy refund, Yothmeru shift/tier/decay, `karma_bonus` only on bellow/sway, `SkillCheck` API parity | F3a/F3b |

Weftlumin's character kind (`stats.schema = "dramgid.v1"`, `docs/architecture-in-game-editor.md` §4.7)
validates against `DramgidSchema` — one more reader, no second definition.

### 3.7a How §3.7's two halves were reconciled (implemented, `globals/renown.gd`)

§3.7 asks for two things that cannot both be literal. It says `gain_reputation`/`gain_infamy`
"apply `× Decorum/10`", and it says "existing totals/API untouched so tavern gates keep working."
DRAMGID point-buys attributes 2..5 (`DramgidSchema.ATTRIBUTE_FLOOR`/`ATTRIBUTE_CAP`), so that
multiplier can only land in 0.2×..0.5×. Two shipped recruit gates read the raw totals —
reputation ≥ 10 for Korrath Ninefold, infamy ≥ 8 for Maura Greyfen (`GameState._make_member`) —
against authored grants that top out at 12. Scaling the meters flips both gates.

Resolved so every clause of §3.7 stays literally true:

- **Karma** is a new axis, so nothing depended on it before: the `× Doctrine / 10` multiplier is
  **live** there, and each event records `base` and `applied` as §3.7 requires.
- **Reputation and Infamy** keep the authored value as their delta. The Decorum-scaled figure is
  **computed and recorded** on every event as `RenownEvent.fame_shift`, alongside `witness_factor`
  — so §6 rules on real play data instead of re-deriving it from prose — but it does not move a
  live total.
- **Fame** is `reputation() + infamy()` less Legendary decay, exactly as §3.7 defines it.

The divisor is one named constant, `Renown.ATTRIBUTE_SCALE_DIVISOR`, so the §6 freeze is a
one-line change. Extreme-tier decay is likewise one named `DECAY_FRACTION_PER_WEEK`; the
mechanism (asymptotic, boundary-respecting, on `WorldClock.day_changed` only, never a timer) is
what F3a owes, the percentage is §6's.

---

## 4. Explicitly out of F3 (owned elsewhere)

XP awards and the level curve (F5 #285; F3 only adds the `xp` field); class perk lists and the Pandora
`Perks` category (F5); carry weight (no system exists; Muster "governs" it in prose only); Loom-zone
degradation of skills (F4 #284 supplies zones; F3 supplies the hook); numeric peoples modifiers (§5.4);
Discord/backlash resistance from Grit (no Discord damage channel exists yet — F1/Wave B leftover);
"received performance shifts Fame" for Vārum (a quest/dialogue write through `gain_reputation(..., witness_factor)`,
authored later); companion recruits' attribute re-authoring beyond the mechanical rename.

---

## 5. Owner rulings required

1. **Ratify the 22-skill table** (mono RFC-0005, currently `proposed`) as Soul Meter canon, or name the
   22. Until then §1.2 is PROVISIONAL and Codex implements it as written.
2. **Alchemy** → refund to skill points on migration (recommended), or map to Varlore.
3. **Spark → Reason** as the sixth rename (recommended; the implementer verifies Spark's hint text in
   `chargen_data.gd` reads as wit/initiative — if it reads as soul/magic, swap with Pitch→Reason and
   Spark→Intuition).
4. **Peoples' leanings are display-only in F3** (recommended; canon calls them nudges with no numbers).
   A later ruling may add ±1.
5. **Doctrine = 2 for every migrated character** (recommended; it is the floor and makes the sum 22).
6. **Devotion's Loom sensitivity** — RFC-0005 leaves it unsettled; recommend `PARTIAL` until canon says.
7. **Yothmeru tiers/thresholds** adopted from RFC-0007 as written (Karma −1000..1000 seven tiers; Fame
   0..1000 five tiers) — confirm, DeepSeek checks the bands against current Renown totals so no existing
   recruit gate flips.
8. **Does Fame track the Decorum-scaled `fame_shift` instead of raw `reputation + infamy`?**
   §3.7 defines Fame as the raw sum, which is what shipped and what the recruit gates survive
   (see §3.7a). RFC-0007 §4 instead scales it by `witness_factor × Decorum / 10`. Both figures are
   recorded on every event today, so switching is a read change, not a migration — but it needs a
   baseline: RFC-0007's `/10` annotates itself "Doctrine or Decorum of 10 = 1.0x", and DRAMGID
   caps attributes at 5, so that baseline is unreachable and every act is dampened. Either confirm
   the dampening is intended, or name the attribute value that means 1.0× on a 2..5 scale.
9. **Fizzle reduction attribute = Intuition** (RFC-0001) and the vault/mono `magic-system.md` copies are
   edited to drop "Pitch" — a canon-doc task (Kimi/Ollama), not code.

---

## 6. DeepSeek numeric brief (design note + pure functions + tests; Claude review = freeze before F3a merges)

**Status 2026-09-07: four of the seven items are FROZEN.** `docs/dramgid-numbers.md` carries
the design note, the migration report and the reasoning; `globals/stats/dramgid_derived.gd`
carries the functions; `tools/dramgid_derived_sweep.gd` produces the grids and
`test/unit/test_dramgid_numbers.gd` pins them.

| item | status |
|---|---|
| `max_hp(grit)` | frozen — `12 + grit × 6` |
| `breath_max(intuition)` | frozen — `9 + intuition × 3` |
| `attack(muster)` | frozen — `muster × 2` |
| `defense(alacrity)` | frozen — `alacrity`, unchanged |
| `ct_speed(reason)` | reported, NOT applied. `charge_speed_attribute` moved `edge`→`alacrity` on 2026-09-07, which is the RENAME, not this formula: keying CT on Reason instead of Alacrity is a different claim and still §3.9 |
| `fizzle_reduction(intuition)` | verified unchanged — 48 ratified readings, 0 mismatches |
| Karma/Fame tiers, `karma_bonus`, decay | already shipped in #384/#390; recorded, not re-proposed |

The three unfrozen rows share one blocker: their consumers still read
`attributes["edge"]`, and moving that read is §3.9 (F3b, after #281).

> **Superseded in part, 2026-09-07 (owner ruling: "DRAMGID stats on enemies as well").**
> The attribute NAME moved: `edge` is `alacrity` everywhere in canon and the runtime, and the
> six enemy archetypes carry all seven DRAMGID attributes under a `dramgid.v1` stat block.
> This closed a live defect rather than only tidying names — `BattleActor.from_party_member()`
> copies the member's attributes verbatim, and a chargen-built character carries `alacrity`
> and no `edge` at all, so every player-built character was fighting with to-hit 0 and charge
> speed 0. What remains blocked on #281 is the FORMULAS, not the names.
>
> Enemy `max_hp`/`attack`/`defense` stay AUTHORED **for now — interim, tracked as #412**.
> The owner ruled on 2026-09-07 that enemy attributes should drive those three numbers, and
> that instances met in the wild should differ from each other: *"I don't want it to be a
> 'solved' kinda question."* What #412 will not do is reuse `DramgidDerived`: the party
> point-buys 2..5, so `12 + grit x 6` gives 24/30/36/42 while the shipped enemies run 14..36
> with a grit-1 boar the party can never build, so deriving through the party's curve would
> make that boar 24 HP and Gate T-1's ratified cleared-encounter evidence would stop
> describing the game. #412 carries an enemy-side curve plus deterministic per-spawn
> variation frozen at spawn (Gate T-7), sequenced behind #345's SpawnDirector.

The original brief follows.


Design within these constraints and deliver `docs/dramgid-numbers.md` + `globals/stats/dramgid_derived.gd`
(pure static) + tests:

- `max_hp(grit)` — today `Anchor × 8` (B§8); keep migrated party HP within ±15% of today for the
  shipped recruits and the demo protagonist.
- `breath_max(intuition)` — today a fixed 15; costs Note 3 / Phrase 6 / Song 12 / Refrain 24 (B§8). Keep a
  starting caster able to cast the ratified casting-economy sanity readings (`docs/casting-economy.md`).
- `attack(muster)`, `defense(alacrity)` — today `attack = Forge`, `defense = Edge`; to-hit base 70,
  +2/point difference, clamp 5–95 (B§8): show the hit-chance table does not move more than one band.
- `ct_speed(reason) = 6 + reason/2` clamped 1–30 (B§8) — confirm or propose; forecast == resolution
  must hold (deterministic).
- `fizzle_reduction(intuition) = max(intuition − 2, 0) × 2` — re-run the ratified fizzle sanity readings
  with Intuition in Pitch's seat; report any reading that changes.
- `karma_bonus(tier)` for `bellow`/`sway`; Karma/Fame tier thresholds; `witness_factor` guidance;
  extreme-tier decay per day.
- Migration report: for every shipped `PartyMember` and Combatant, before/after derived stats.

---

## 7. Sequencing

F3a (Codex, now, no combat files; blocked only by §6's freeze for the derived formulas — implement the
schema/migration first with `DramgidDerived` as a stub returning today's formulas, then swap in the
frozen numbers) → F3b (Codex, after #281 merges; one PR) → canon-doc edits (Kimi) → Weftlumin
#325/#347 unblock. The Codex handoff is `docs/handoff-dramgid-codex.md`.

**Where that leaves F3a (2026-09-08).** F3a is done except for the two things it was always
going to trip over, and both are the same blocker wearing two hats:

1. `DramgidDerived.recompute` (§3.3) and the migration's step-6 stat recompute (§2.1) wait on
   §6's frozen formulas. The plan above says to stub it with "today's formulas" — that was not
   done, deliberately. A stub that recomputes derived stats using the *current* numbers still
   rewrites every migrated save's `max_hp`/`attack`/`defense`/`breath_max`, and if §6 then
   freezes different numbers those saves have been through two rewrites instead of none.
   Carrying the stored values across is the reversible choice; the migration has a test
   asserting it, so the deferral is visible rather than assumed.
2. §3.6 and §3.9 have to ship together (see the note under §3's table).

Everything else F3a owns has merged: #384, #390, #392, #393, #394, #395.
