# DRAMGID (#283) — Codex implementation handoff

**Spec:** `docs/architecture-dramgid.md` (read §0–§3 and §7 first; §5 lists PROVISIONAL points — implement
them as written and note them in the PR). **Fact base:** `docs/briefs/dramgid-brief.md`.
Ground rules are the same as `docs/handoff-weftlumin-codex.md` §1 (one issue = one branch = one PR; never
change labels; suite green; never edit `addons/`; no canon edits). Additional rule: **no stat id may be
hard-coded anywhere except `globals/stats/dramgid_schema.gd`.**

## PR 1 — F3a-1: schema + SkillCheck + PartyMember/BattleActor (branch `feat/dramgid-schema`)
Scope: `globals/stats/dramgid_schema.gd` (new), `globals/stats/dramgid_derived.gd` (new; **stub** that
returns today's formulas `max_hp = grit × 8`, `attack = muster`, `defense = alacrity`, `breath_max = 15`
until DeepSeek's numbers are frozen), `globals/skill_check.gd`, `globals/party_member.gd`,
`globals/battle_actor.gd`, `globals/advancement.gd`, tests.
Deliver: §1.1/§1.2 tables as data; 22 `SkillCheck` definitions from the schema; `karma_bonus` term
(reads `Renown.karma_tier()`, returns 0 until PR 3 lands — guard with `has_method`); `loom_penalty`
hook returning 0; `fizzle_percent` parameter `pitch` → `intuition`, formula unchanged; `xp` field.
Accept: schema invariant tests (7 attributes, 22 skills each with a governing attribute, sum-22
validation); `SkillCheck` public API unchanged except the renamed parameter; suite green.

## PR 2 — F3a-2: save schema 8 + dialogue/audit renames (branch `feat/dramgid-save-8`)
Scope: `globals/save_migrations.gd`, `test/fixtures/saves/v7_*.json` (new), `dialogue/council_elder.dialogue`,
`dialogue/lower_trial_hall.dialogue`, `dialogue/dom_side_quests.dialogue`, `tools/quest_audit.gd`,
`docs/dialogue-checks.md`, tests.
Deliver: `_migrate_v7_to_v8` exactly per spec §2.1 (attribute rename + `doctrine: 2`; skill rename; Alchemy
refund via the advancement cost curve; `xp: 0`; `renown.karma` keys; recorded-check id rename; derived
stats recomputed through `DramgidDerived` with a before/after log line per member).
Accept: fixture v7 saves migrate and load; player rows sum to 22; Alchemy points equal the refund;
`quest_audit` 0 errors; `test_dialogue_checks` green with new ids.

## PR 3 — F3a-3: Yothmeru on Renown (branch `feat/dramgid-yothmeru`)
Scope: `globals/renown.gd`, `globals/world_clock.gd` (subscribe to day change only if E1.10's
`phase_count` has merged; otherwise leave decay unwired and say so), tests.
Deliver: spec §3.7 — `gain_karma`, `karma_total`, `karma_tier`, `fame`, `fame_tier`, `witness_factor`
param with Decorum scaling, extreme-tier decay on day change, `why("karma")`. Tier thresholds from RFC-0007
as constants in `dramgid_schema.gd` (DeepSeek may adjust later — keep them in one place).
Accept: existing Renown tests untouched and green; tavern recruit gates unchanged; new tests for shift
scaling (Doctrine/Decorum 10 = 1×), tiers, decay only at extremes, serialization round-trip.

## PR 4 — F3a-4: chargen + character sheet (branch `feat/dramgid-chargen`)
Scope: `globals/chargen_data.gd`, `ui/screens/character_creation.gd/.tscn`, `ui/screens/character_sheet.gd`,
tests (`test_chargen_data` rewritten).
Deliver: seven attribute rows, budget 22 / floor 2 / cap 5 copy, skills grouped by governing attribute,
five peoples (Vael, Kaan, Vaerin, Weftkin, Kes'reth) with leaning **hints only**, backgrounds retrained to
new skill ids, `_build_member` via `DramgidDerived`. All labels via the schema; theme variations only.
Accept: wizard cannot finish with sum ≠ 22 or any attribute > 5; character sheet shows 22 skills with
effective %; suite green.

## PR 5 — F3a-5: Pandora columns + generators + encounter loader (branch `feat/dramgid-pandora`)
Scope: `tools/seed_pandora.gd` (+ the combatant/peoples seeders), `data.pandora`, `tools/generate_gloot.gd`
(encounter emit), `data/generated/encounters.json`, `globals/campaign_encounter_loader.gd` (`ENEMY_FIELDS`),
`scripts/check_generated_data.sh` unchanged, tests.
Deliver: Combatants: seven attribute columns replacing `Edge` (default 2; existing enemies get `alacrity =
old Edge`, others 2); Peoples: `Leaning Primary/Secondary`; regenerate; loader requires the seven ids
from the schema. Accept: drift checks green; encounter validation tests updated; no other Pandora change.

## PR 6 — F3b: combat stat reads (branch `feat/dramgid-combat`) — **blocked until #281 merges**
Scope: `globals/combat/combat_rules.gd`, `globals/combat/resolution.gd`, `globals/combat/combat_controller.gd`, tests.
Deliver: spec §3.9 (Reason for CT speed, Alacrity for to-hit difference, Muster via `attack`, Intuition in
the fizzle context). Accept: forecast == resolution tests green; `test_combat_controller` green; the
hit-chance table moves by at most one band vs the pre-migration fixture (DeepSeek's report).

## Handoff format (every PR)
```
Changed files: …
Tests: <suite summary line>; new tests: …
Acceptance: <each check above, pass/fail>
PROVISIONAL points implemented as written: <list from spec §5>
Risks / open questions: …
```
