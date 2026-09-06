# Handoff — DRAMGID reader brief (Codex, read-only research)

**Objective:** produce `docs/briefs/dramgid-brief.md` — a compact, fully cited fact base Claude will
architect the DRAMGID migration (#283) from. Facts only. No recommendations, no design, no code.

**Worker:** Codex. **Scope:** write ONLY `docs/briefs/dramgid-brief.md`. Read anything under
`~/projects/soul-meter`, `~/projects/dramgid-vault`, `~/projects/dramgid-mono` (or wherever RFC-0001 lives —
locate it with `rg -l "RFC-0001|dramgid-mono" ~/projects`). Do not edit any other file. Do not run the
game or the test suite.

**Hard cap:** 300 lines. Every factual line carries a citation `path:line` or `path:line-range`. Prefer
tables. Where sources disagree, put both claims side by side in §7 and do not resolve.

## Required sections

1. **Ratified rulings on DRAMGID** — quote (verbatim, short) every ruling in `docs/game-identity.md`,
   `docs/fleet-roadmap.md` (F3 row) and `docs/ship-plan-2026-10.md` that mentions DRAMGID, seven
   attributes, 22 skills, XP/skill points/perks, Yothmeru, Karma/Fame, Doctrine/Decorum, class = identity.
2. **The DRAMGID spec itself** — from RFC-0001 and the vault (`systems/character-creation.md`,
   `systems/ten-patron-classes.md`, `systems/magic-system.md` where it touches stats): the seven
   attributes (id, name, one-line meaning), the 22 skills (id, name, governing attribute(s), what it
   gates), derived values (HP, Breath, initiative/CT, carry, to-hit, fizzle inputs), level/XP curve if
   stated, skill-point rules, perk rules, class perk lists per patron class if listed, peoples/races and
   any stat modifiers or restrictions they carry, and Yothmeru Karma/Fame definitions.
3. **Current six-stat build — every surface that must migrate.** For each, file, symbol, line range,
   and what it does with stats: `globals/chargen_data.gd` (ATTRIBUTE_IDS, point-buy rules), the chargen
   wizard scenes/scripts, `globals/party_member.gd`, `globals/battle_actor.gd`, `globals/unit_roster*`,
   `globals/skill_check.gd` (full public API + every caller, `rg "SkillCheck\."`), `Resolution`/
   `CombatController` reads of attributes, class resources (`globals/combat/class_resources/`) reading
   stats, `globals/renown.gd` public API, `Reputation` bands used as gates, `globals/save_migrations.gd`
   (schema 7 contents; which keys carry stats), Pandora columns and seeders for Classes/Peoples/Combatants
   (`tools/seed_*.gd`; `Pandora.create_property` calls), `globals/campaign_encounter_loader.gd`
   `ENEMY_FIELDS`, `data/generated/*` files that contain stat fields, dialogue conditions referencing
   stats (`rg -n "stat|attribute|strength|agility|will|wit|charm|vigor|luck" dialogue/*.dialogue`,
   adjust to the real names), and the count of tests referencing each attribute id (`rg -c`).
4. **Player-facing strings** that name attributes/skills (UI labels, POT entries) with file:line.
5. **Save-schema history** — table of schema versions 1→7 from `save_migrations.gd`: version, what
   changed, migration function.
6. **Sibling references** — does any other repo under `~/projects` (petalkeep, hexgame, squadtactics,
   dayinthelife-godot, idyllicdram, site-k) already implement DRAMGID attributes/skills? File paths only.
7. **Contradictions and gaps** — spec vs spec, spec vs code, undefined values (e.g. a skill with no
   governing attribute, a derived value with no formula). Bullet list, cited.
8. **Numbers Claude will need** — every constant currently in code that depends on a stat (fizzle
   table inputs, to-hit constants, CT wait refund, Breath sizes) with file:line.

## Acceptance (self-check before finishing)

- File exists, ≤ 300 lines, every factual line cited, sections 1–8 present, no recommendations.
- `git status --short` shows only `docs/briefs/dramgid-brief.md` (and this handoff) changed.
- Final message: the line count, the number of contradictions in §7, and any source you could not find.
