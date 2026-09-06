# DRAMGID migration — architecture note (F3 design, #283)

**Status:** DRAFT for owner ratification (§5) · 2026-09-04 · author: Claude (architecture) · fact base:
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
   (§5.1). Ship plan's "save schema 7" gate wording is stale: DRAMGID is **schema 8** (B§7).

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

### 2.1 Save schema 7 → 8 (`SaveMigrations._migrate_v7_to_v8`)

For every party row and custom-recruit row (B§3 `PartyMember`, B§5):

1. `attributes`: rename keys by the table in §1.1 (`forge→muster`, `edge→alacrity`, `anchor→grit`,
   `pitch→intuition`, `voice→decorum`, `spark→reason`); add `doctrine: 2`. Assert the new sum is 22
   for player-created rows; authored recruits keep whatever they sum to (they were never point-bought).
2. `skill_percentages` / `skill_tiers`: rename by §1.2's last column; **Alchemy**: compute the points
   spent from its percentage via the advancement cost curve and add them to `advancement_points`
   (name per `globals/advancement.gd`), then drop the key. Skills with no old source start at 0%/tier 0.
3. Add `xp: 0` and keep `level`; add nothing for perks (F5 decides the perk container).
4. `renown`: add `karma: []` event list and `karma_total: 0` (§3.7). Existing reputation/infamy events untouched.
5. `skill_check`: recorded recent checks carry old skill ids — rename in place.
6. Derived stats (`max_hp`, `attack`, `defense`, `breath_max`) are **recomputed** from the new
   attributes by the DeepSeek-ratified formulas (§6) rather than copied; the migration logs the
   before/after per member so a playtester can see the change.

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

| # | Surface | Change | Half |
|---|---|---|---|
| 3.1 | `globals/stats/dramgid_schema.gd` (new) | Attributes, skills, Loom enum, point-buy constants, old→new maps, `mono_token`s; pure static | F3a |
| 3.2 | `globals/skill_check.gd` | Definitions built from the schema (22); `karma_bonus` term; `loom_penalty` hook (returns 0); `fizzle_percent`'s `pitch` parameter becomes `intuition` (same formula: `max(intuition − 2, 0) × 2`, §6 verifies); recorded-check id rename | F3a |
| 3.3 | `globals/party_member.gd`, `globals/battle_actor.gd` | Attribute dictionaries keyed by new ids; `attribute_value()` unchanged API; `xp` field; derived-stat recompute helper `DramgidDerived.recompute(member)` | F3a |
| 3.4 | `globals/chargen_data.gd`, `ui/screens/character_creation.gd/.tscn`, `ui/screens/character_sheet.gd` | Seven rows, 22-point text, skills grouped by attribute, five peoples with leaning hints, `_build_member` uses `DramgidDerived`; all labels through the schema (POT-ready) | F3a |
| 3.5 | `globals/advancement.gd` | Skill-point pool receives Alchemy refund; API otherwise unchanged (XP curve is F5) | F3a |
| 3.6 | Pandora seeders + generators + `campaign_encounter_loader.gd` | Columns per §2.2; drift checks green | F3a |
| 3.7 | `globals/renown.gd` | **Yothmeru on Renown**: add signed `karma` ledger (`gain_karma(actor, base, cause, scene)` applies `× Doctrine/10` of the *player* at write time and records both `base` and `applied`), `karma_total()`, `karma_tier()` (seven tiers, thresholds from RFC-0007 via §6), `fame()` = reputation + infamy, `fame_tier()` (five tiers); `gain_reputation/gain_infamy` gain an optional `witness_factor` (default 1.0) and apply `× Decorum/10`; extreme-tier decay (Damned/Exalted/Legendary toward the boundary) runs on `WorldClock` day change only — never on a timer; `why("karma")` supported. Existing totals/API untouched so tavern gates keep working | F3a |
| 3.8 | `globals/save_migrations.gd` | `CURRENT_SCHEMA_VERSION = 8`, `_migrate_v7_to_v8` per §2.1, fixture saves for v7→v8 | F3a |
| 3.9 | `globals/combat/combat_rules.gd`, `resolution.gd`, `combat_controller.gd` | CT speed `6 + Reason/2` (was Edge); to-hit difference on Alacrity (was Edge); `calculate_damage` power term on Muster via `attack`; `_fizzle_context` supplies Intuition (was Pitch). Numbers unchanged unless §6 says otherwise | **F3b, after #281** |
| 3.10 | Dialogue + quest audit + docs | §2.2 renames; `docs/dialogue-checks.md`; CLAUDE.md status line ("save schema 8") | F3a |
| 3.11 | Tests | `test_chargen_data` rewritten to the schema; 147 legacy-id lines across `test/` (B§3) renamed by map; new: schema invariants (22 skills, each with a governing attribute; sum-22 validation), v7→v8 migration fixtures incl. Alchemy refund, Yothmeru shift/tier/decay, `karma_bonus` only on bellow/sway, `SkillCheck` API parity | F3a/F3b |

Weftlumin's character kind (`stats.schema = "dramgid.v1"`, `docs/architecture-in-game-editor.md` §4.7)
validates against `DramgidSchema` — one more reader, no second definition.

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
8. **Fizzle reduction attribute = Intuition** (RFC-0001) and the vault/mono `magic-system.md` copies are
   edited to drop "Pitch" — a canon-doc task (Kimi/Ollama), not code.

---

## 6. DeepSeek numeric brief (design note + pure functions + tests; Claude review = freeze before F3a merges)

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
