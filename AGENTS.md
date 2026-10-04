# Soul Meter — repository instructions

These rules apply only inside this repository. Do not copy its mechanics, engine pins, lore paths, or test commands into global instructions or other projects.

Soul Meter is a dialogue-and-consequence CRPG in Era 3 of the Dramgid Cycle: 2D isometric presentation rendered from 3D models. Implement the requested outcome within ratified design; do not invent canon or unresolved mechanics.

## Read for the task

| Work | Source |
|---|---|
| Game identity, mechanics, or chapter scope | `docs/game-identity.md`, the relevant design document, `docs/prd-chapter-one.md`, and ratifications in `docs/phase-0-ratification.md` |
| System boundaries or navigation | `docs/godot-architecture.md`; `docs/godot-flow-handoff.md` for statechart transitions |
| Scene, dependency, or import behavior | `project.godot` and `DEPENDENCIES.md` |
| UI presentation | `design/DESIGN_SYSTEM.md`, `ui/theme/ds.gd`, `ui/theme/theme_builder.gd` |
| Tests or runtime verification | `docs/agent-verification.md`, then the relevant section of `docs/testing.md` |

Read only the sources needed for the affected behavior. Use `docs/project-map.md` for unfamiliar subsystems. Historical progress is in `docs/status/2026-09-12-inherited-project-status.md`; verify it against current code before relying on completion claims.

## Engineering invariants

- Five layers point downward: Flow → Presentation → Systems → Narrative → Data. UI emits events; `GameFlow` owns navigation through the statechart and SceneLoader. Do not call `change_scene_to_file()` in game code. Use `GameFlow.travel()` and its scene constants for travel.
- Pandora owns game data; the Dramgid vault owns lore prose. Do not write back to Pandora from generated artifacts or hand-edit `data/generated/*`; regenerate with the documented tools. `Vault Id` bridges the two sources.
- Reputation and Renown are separate append-only ledgers. Use their public write methods. Party changes use `GameState.set_party()` or preserve its `party_changed` notification contract. Preserve serialization and save compatibility.
- Theme type variations and DS tokens own styling; do not add per-node theme overrides. Preserve `.tscn` ownership, node paths, and `uid://` references. Use typed GDScript, snake_case files/variables, PascalCase nodes/classes, and signals for communication.
- Do not modify vendor `addons/*`; `addons/soul_meter_tools` is project-owned and is the exception. Avoid generated `.godot/` caches and `*.import` files as source material. Preserve unrelated working-tree changes.

## Lore and scope

For lore work, read `../dramgid-vault/index.json` and the relevant entities. `canon/`, `cosmology/`, and deliberate mysteries in `canon/open-questions.md` are authoritative. The older `soul-meter-crpg-design-doc.md` can conflict with later ratifications and vault lore; surface material conflicts rather than resolving them silently. Authorized vault edits require its own instructions, validation, and filesystem permission.

Keep class identity, DRAMGID, soul income, and combat behavior within the relevant ratified design. A requested implementation supplies its scope; ask only about material unresolved choices. Localization uses PO/gettext, inventory uses grid sizes, and shared state must remain serializable.

## Finish and verify

The agent owns routine verification: run affected automated tests, exercise the changed behavior in a suitable runtime, fix regressions caused by the change, and rerun affected checks. Do not hand the user a routine test command the agent can run. Follow `docs/agent-verification.md` for isolation, rendered checks, evidence, and legitimate human gates.

Keep required CI/release gates intact. A historical flaky-test label does not excuse a new failure. Report exact failing checks and remaining uncertainty; do not claim headless success proves visual correctness.

Use `/octo` only when the user explicitly requests cross-model review. Do not start or repeatedly propose external reviewers during ordinary implementation. Follow the shared role policy for an assigned handoff; do not delegate merely because an investigation is unfamiliar.
