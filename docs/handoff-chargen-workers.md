# Character creation on DRAMGID — worker handoff (F3a-4, #283)

**Design of record:** `docs/architecture-chargen-dramgid.md` (read it first; §12 lists the
owner rulings the code implements as defaults). **Base branch:** `feat/dramgid-chargen`
(stacked on `feat/dramgid-schema`, PR #361, which stacks on `design/dramgid`, PR #360).
Everything below is bounded, non-recursive, and carries a *do-not-decide* line. Workers do
not touch GitHub labels or assignees, `addons/`, `data/generated/*` by hand, CLAUDE.md, or
any combat file (`globals/combat/**`) — combat reads are F3c and blocked on #281.

Return a compact handoff: changed files, tests added/run (with the suite line), risks, open
questions. Claude reviews and merges. Commit trailer: `Co-Authored-By` per repo convention.

Test command (run the touched suites, then the whole suite before handing back):

```
GODOT_BIN=~/.local/bin/godot bash scripts/test.sh -a test/unit/test_dramgid_schema.gd
GODOT_BIN=~/.local/bin/godot bash scripts/test.sh -a test
```

Gotchas: `:=` from a Variant-returning call (`auto_free()`) aborts the run with exit 105 —
type such vars explicitly; a new `class_name` needs `godot --headless --path . --import`
before tests see it; `--script` tool runs exit 134 at teardown ~20–30 % of the time — judge
the output, not the exit code.

---

## 0. What Claude's first slice delivers (F3a-4a) — do not redo

| area | delivered |
|---|---|
| Schema | `DramgidSchema`: `group` on every skill, `SKILL_GROUPS`, `GROUP_LABELS`, ARMS ×5, TONES ×10, `skills_in_group()`, `skill_group()`, `governing_attribute()`, `tone_skill_for()`, `opposed_tone()`, `is_tone_skill()`, `is_arms_skill()`, `creation_skill_pool()` |
| Class data | `globals/stats/class_catalog.gd` (`ClassCatalog`): ten rows (§6.1), `by_id()`, `patron_for()`, `class_for_patron_value()`, `is_retired_pairing()` |
| Creation tables | `ChargenData` retargeted: DRAMGID leans, `trained_skills`, `creation_bonus_points`, backgrounds on schema ids, `PATRONS` as a view over `ClassCatalog`, `preview_skill_percentages()` deleted |
| Model | `globals/chargen/chargen_build.gd` (`ChargenBuild`) + `globals/chargen/chargen_steps.gd` (`ChargenSteps`) per §7.2 / §7.3 |
| Stats core | `PartyMember.class_id / kit_weapon_skill / kit_weapon / mastery_element` (serialized, additive); `attribute_value()` legacy-alias fallback; `Advancement.seed_creation_ledger()` + `unheld_tone` gate; `SkillCheck.fizzle_percent(..., tone_bonus := 0.0)` + `tone_bonus_for()`; `GameState` validator accepts tier casing |
| Wizard | `ui/screens/character_creation.gd` rebuilt on `ChargenBuild`: nine leaves, class cards, skills spend page, public driving API (§7.4); `theme_builder.gd` `Chargen*` card/row variations |
| Tests | `test_dramgid_schema`, `test_class_catalog`, `test_chargen_data`, `test_chargen_build`, `test_skill_check` (tone rows), `test_advancement` (ledger seed, gate), `test_party_member` (new fields), `test_character_creation` (rewritten on the public API), `test/manual/screenshot_sweep.gd` re-pointed |

Check the branch log before starting: anything in the table that is missing or marked TODO in
the code is fair game for the matching task below.

---

## W1 — Codex: character sheet groups + tone rows (F3a-4b)

- **Objective:** `ui/screens/character_sheet.gd` iterates `DramgidSchema.SKILL_GROUPS`
  instead of `ChargenData.SKILL_IDS`; six group headers (ARMS and TONES first, open; field
  groups collapsible); TONES lists only `ChargenBuild`-style held tones
  (`member.major_element` / `minor_element`); each row keeps the buy button and the
  derivation tooltip, which gains the arms/tone line.
- **Scope:** `ui/screens/character_sheet.gd`, `ui/theme/theme_builder.gd` (reuse
  `ChargenSkillRow` / `ChargenGroupHeader`; add a variation only if the sheet needs a
  different density), `test/unit/test_character_sheet*.gd` (add if missing),
  `docs/testing.md` row.
- **Acceptance:** a chargen-built protagonist shows 22 field + 5 arms + 2 tone rows; a
  hand-authored recruit (no elements) shows 0 tone rows and no error; buy on `heft` moves
  the % and the ledger; the screenshot sweep still captures the sheet; suite green.
- **Do not decide:** skill ids, group membership, tone visibility rules, any number.

## W2 — Codex: Pandora weapon columns + `WeaponProfile` (F3a-5)

- **Objective:** Pandora `Items` gains `Weapon Skill` (one of the ARMS ids or empty),
  `Damage` (int), `Element` (Wheel id or empty); `tools/seed_pandora.gd` seeds the ten Kit
  weapons named in §3.2 (`ClassCatalog.kit_items` maps class → prototype ids once they
  exist); `tools/generate_gloot.gd` emits the three properties into the prototree and
  `ItemIds`; new read-only `globals/stats/weapon_profile.gd` with
  `for_member(member) -> {item_id, skill_id, damage, element}` resolving equipment → Kit →
  bare hands (`grip`, damage 0). Also move the Defining-Strike `check_skill` assert
  (`generate_gloot.gd:867`, `lore`/`insight`) and the 14 generated rows onto schema ids via
  `DramgidSchema.SKILL_RENAMES`.
- **Scope:** `tools/*.gd`, `data.pandora`, `data/generated/*` (regenerated, never
  hand-edited), `globals/stats/weapon_profile.gd`, `globals/stats/class_catalog.gd`
  (`kit_items` only), tests, `SOUL_METER_DRIFT_CHECK=1` run.
- **Acceptance:** drift check passes; every `ClassCatalog` kit skill has at least one
  seeded item whose `Weapon Skill` matches; `WeaponProfile.for_member()` returns the Kit
  weapon for a chargen protagonist and `grip` for a memberless call; suite green.
- **Do not decide:** damage values beyond the PROVISIONAL 2–6 band (DeepSeek N1), any
  combat read, per-member equipment (F4).

## W3 — Codex: save schema 8 additions (joins PR 2 `feat/dramgid-save-8`)

- **Objective:** in the v7→v8 migration, per party/recruit row: if `patron` matches a
  `ClassCatalog` id → `class_id = patron; patron = ClassCatalog.patron_for(class_id)`; if
  `patron` is a deity name → derive `class_id`; grant Trained tiers for
  `kit_weapon_skill` and `tone_<major>` / `tone_<minor>` when the row has them and the
  skill is Untrained; synthesize attributes for attribute-less rows
  (`grit = max_hp/8, muster = attack, alacrity = defense, others 2`) before any
  `DramgidDerived.recompute()`; normalize ledger tier strings to lowercase.
- **Scope:** `globals/save_migrations.gd`, `test/fixtures/save_game_schema_7.json` → 8
  fixture, `test/unit/test_save_migrations.gd`, `docs/architecture-dramgid.md` §2.1 (append
  the steps; do not rewrite the section).
- **Acceptance:** fixture with `patron: "ironbrand"` loads as `patron "Kero"`,
  `class_id "ironbrand"`; `ClassResourceRegistry.for_patron()` is non-Null for every
  migrated row; `Vex` and the twenty roster rows carry attributes summing to 22 or the
  synthesized set; validator accepts the migrated envelope; suite green.
- **Do not decide:** the attribute synthesis formula beyond the one written here, tier
  grants for rows without elements, anything about `equipped_slots` (F4).

## N1 — DeepSeek: numeric addendum

- **Objective:** append a section "Chargen and ARMS/TONES" to
  `docs/briefs/dramgid-numbers-deepseek.md` freezing: creation pool
  (`6 + reason + decorum`, Vael +1 — confirm or re-tune within 8–18), ARMS hit baseline
  (40) and `weapon_bonus` divisor (2) against the "≤ one band" acceptance for the twelve
  hit-table cases, tone divisor (4) against the twelve fizzle readings and the
  Intuition-5 / Trained-Major Dom Note case, Kit weapon `Damage` (2–6) per class, enemy
  `Arms Percent` default (40), and an Alacrity-vs-Muster check (light builds must not
  dominate).
- **Scope:** that one file. Read-only elsewhere.
- **Acceptance:** every number has a before/after table and a one-line rationale; no
  formula shape changes; every PROVISIONAL value in the architecture note §3–§5 is either
  confirmed or given a replacement with evidence.
- **Do not decide:** formula shapes, which skills exist, canon questions.

## T1 — Qwen: test breadth + manual checklist

- **Objective:** widen `test/unit/test_chargen_build.gd` with table-driven cases (every
  ancestry × every class × both Ironbrand kits → `to_party_member()` validates through
  `GameState._validate_save_data` after `to_dict()`; pool bounds; refund LIFO exactness;
  unheld-tone block; attribute cap/floor/sum edge cases); write
  `test/manual/character_creation_checklist.md` (nine leaves, keyboard-only pass,
  RECRUIT mode from the tavern, save → load → sheet parity).
- **Scope:** `test/unit/test_chargen_build.gd`, `test/manual/character_creation_checklist.md`,
  `docs/testing.md` rows.
- **Acceptance:** new cases pass; no production file touched; checklist follows the format
  of the existing `test/manual/*.md`.
- **Do not decide:** anything; if a case exposes a design gap, report it, do not patch
  production code.

## R1 — Jules / Gemini: card copy and flaw table research

- **Objective:** (a) for each of the ten classes, pull the verbatim Kit / Resource /
  Signature / suggested-element sentences from mono `04-world/systems/ten-patron-classes.md`
  and the vault entity, and diff them against `ClassCatalog` strings; (b) draft a PROPOSAL
  table of eight to twelve Waning-flavoured Flaws (name, one-line drawback, roleplay hook,
  the canon entity it leans on) for the owner — no code.
- **Scope:** a markdown report under `docs/briefs/chargen-copy-and-flaws.md`. Read-only
  elsewhere; the vault and mono are read-only.
- **Acceptance:** every diff line cites file and line; every flaw cites a canon entity;
  nothing is presented as ratified.
- **Do not decide:** which copy ships, whether flaws grant a point (ruling R6).

---

## Sequencing

```
#361 (schema) ──► feat/dramgid-chargen (this branch: F3a-4a) ──► W1 sheet ──► W2 pandora
                                                   └──► W3 joins PR 2 (save 8)
N1 and T1 and R1 run any time after the branch exists.
F3c (combat reads) waits for #281 and the F3b rename PR; nobody starts it from this handoff.
```

Nothing here changes the ship rule "nothing else touches GameFlow, combat, or stats until
#281/#283 merge" — this branch *is* #283's chargen half.
