# A1 handoff — issue #215 tactical casting review fixes

## Status

GREEN. All six review fixes are committed separately and the final full suite passes. No push was attempted.

## T-1 root cause

The ATTACK migration changed the deterministic hit key. Legacy `calculate_damage()` called `Resolution.resolve_action()` with a wrapper whose top-level `battle_id` was absent, so plain attacks hashed the empty-string fallback. The migrated `forecast_context()` instead supplied encounter/tile battle identity, reshuffling every mundane attack roll and making the held and ignored T-1 outcomes equal. Plain ATTACK now deliberately preserves `battle_id == ""`; CAST and Defining Strike retain authored encounter identity. Stillpoint's balance effect was not lost: `apply_balance_effect()` still populates `balance_effects`, attacker `damage_bonus` still enters Resolution power, and target `defense_bonus` is still subtracted in `_finalize_resolution_damage()`.

## Changed files

- Runtime and filtering: `globals/combat/combat_controller.gd`, `globals/battle.gd`, `globals/jobs/ability_definition.gd`, `globals/units/tactical_tables.gd`, `globals/units/unit_loadout.gd`, `ui/hud/battle_interface.gd`.
- Ratified data path: `tools/seed_tactical_tables.gd`, `tools/generate_tactical_tables.gd`, `tools/generate_gloot.gd`, `data.pandora`, `data/generated/tactical_tables.json`, `data/generated/tactical_ids.gd`, `globals/elements/element_definition.gd`, `globals/elements/elements_data.gd`.
- Contracts: `test/integration/test_combat_controller.gd`, `test/integration/test_battle_interface.gd`, `test/integration/test_gate_t1_clearability.gd`, `test/unit/test_tactical_schema.gd`.

## What now works

- Plain ATTACK retains legacy deterministic rolls and the original strict T-1 Stillpoint assertion passes.
- Defining Strike forecast and commit share one Resolution context; forced-roll damage parity is covered.
- Non-single AoE resolves distinct HP writes per target against one pre-action snapshot, while Breath/Soul/tile costs remain one-action costs.
- Resolution refusals occur before player or enemy scheduler commit and emit `action_refused`, without spending action AP/CT.
- CAST requires an explicitly selected ability owned by the acting unit's loadout; no loadout exposes none and there is no alphabetical fallback.
- Ten generated `<Element> Note` action spells exist (`note-<element_id>`, power 6, MP/Breath 1, effective strike CT 30, range 3, AoE single, element vault id). Vex and the Gate T caster fixture have explicit action loadouts, and every caster self-play encounter records a real CAST resolution.

## Additive schema/generator changes

- Added Pandora `Unit Loadout.Action Ability Ids` as a JSON-array column and generated `action_ability_ids`.
- Allowed empty job ids for directly equipped action abilities and empty primary jobs for direct-only loadouts; job FK validation remains for non-empty values.
- Propagated existing element `vault_id` data into `ElementDefinition`/`ElementsData` so the Note rows use the element-owned vault id.
- Did not add `elements`, `magnitude`, or `breath` Pandora columns; runtime defaults and the existing MP-cost alias cover them.

## Test evidence

- Final exact suite command: `GODOT_BIN=~/.local/bin/godot xvfb-run -a bash addons/gdUnit4/runtest.sh -a test`.
- Aggregate: `Overall Summary: 1225 test cases | 0 errors | 0 failures | 0 flaky | 0 skipped | 0 orphans |` across 187 Statistics sections.
- Final emitted Statistics line: `Statistics: 1 test cases | 0 errors | 0 failures | 0 flaky | 0 skipped | 0 orphans | PASSED 61ms`.
- Focused evidence: combat controller 40/40, tactical schema/generator drift 16/16, Gate T-1 3/3, battle interface 5/5.
- `git diff --check` passes. No new `class_name` script was added, so a separate re-import step was not required.

## Risks

- `combat_lab_recorder/` remains untracked and untouched. The full suite also emitted untracked runtime evidence under `dev-console-recorder/`; neither directory is part of these commits.
- The unrelated `test_field_room.gd` flake fix remains inside prior commit `8dd54cf1`; rewriting already-reviewed history solely to extract it was not practical.

## Open questions

- None for the six requested fixes.

## Commits

- `350cbff3` Fix 5 — per-actor CAST loadout filtering and explicit selection.
- `2a61198e` Fix 1 — legacy plain-attack roll key and strict Gate T-1 assertion.
- `aa18d68a` Fix 2 — Defining Strike Resolution forecast parity.
- `bcdf07cd` Fix 3 — per-target AoE HP resolution with one-action resource costs.
- `1c18a13d` Fix 4 — Resolution refusal before scheduler commit.
- `c7a4249c` Fix 6 — additive Pandora Note spells, fixtures, generated artifacts, and caster self-play coverage.

## Pass 3

- Removed the Gate T `caster` unit and its loadout from the seeder and `data.pandora` through Pandora's idempotent deletion path; regenerated artifacts now contain only Vex, Vex's `note-scor` loadout, and all ten Note abilities.
- Gate T caster self-play now supplies an in-memory `TacticalTables` loadout and keeps `actor.breath = 99` test-only. Tactical schema/generator drift is 16/16 green; Gate T-1 is 3/3 green.
- Documented that the plain-ATTACK empty `battle_id` hash key is frozen for legacy roll parity. ATTACK now passes `options` through `_apply_action`, so enemy commit applies the pre-gated Resolution; combat controller is 42/42 green, including enemy refusal with no CT spent.
- Final full suite: `Overall Summary: 1227 test cases | 0 errors | 0 failures | 0 flaky | 0 skipped | 0 orphans |` across 187/187 suites. The preceding run exposed the unrelated wedged-keyboard timing case; `test_field_room.gd` then passed 12/12 focused before the clean full rerun.
- Pass 3 commits: `40581e68`, `025fb0bd`, `6b99db30`. No push was attempted, and no new `class_name` script was added, so re-import was not required.
