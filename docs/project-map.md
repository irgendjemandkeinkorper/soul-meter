# Soul Meter project map

This is a navigation aid, not a required reading list. Shared project rules live in `../AGENTS.md`; changing milestone history lives in `status/`.

| Area | Entry points and contracts |
|---|---|
| Engine and boot | `project.godot`; `ui/screens/main_menu.tscn`; engine/dependency pins in `../DEPENDENCIES.md`. Current project guidance targets Godot 4.7.1; verify the available binary before running commands. |
| Flow | `ui/flow/game_flow.tscn`, `GameFlow`; Boot / Menus / Playing, with Loading, Active, Paused, and Battle states. UI requests events, SceneLoader performs transitions. |
| Party and inventory | `globals/game_state.gd`, `party_member.gd`, `ui/screens/tavern.gd`; GLoot-backed inventory; `set_party()` and `party_changed`. |
| Consequence ledgers | `globals/reputation.gd`, `globals/reputation_event.gd`, `globals/renown.gd`; public write methods append events, standing/band/why are derived reads. |
| Presentation | `ui/ui_manager.gd`, `ui/screens/*`, `ui/hud/*`, `ui/dialogue/*`; `ui/theme/ds.gd` and `theme_builder.gd` define shared styling. |
| World interaction | `world/starting_town.tscn`, `world/test_room.tscn`, `actors/player/`, `actors/npc/`, `actors/tavern_door/`, `actors/travel_exit/`. |
| Tactical combat | `globals/combat/`, `ui/hud/battle_interface.*`, `ui/hud/regions/*`; inspect the live submit-action consumer as well as effect/resource definitions. Forecast and resolution must agree. |
| Data generation | `data.pandora`, `tools/seed_pandora.gd`, `tools/generate_gloot.gd`, `data/generated/`; use documented drift checks. |
| Dialogue | `dialogue/*.dialogue`; conditional responses use `[if expr /]`. Metadata uses tags such as `[#cost=-6 soul]`. Re-import after dialogue edits. |
| Art and dependencies | `assets/kenney/ATTRIBUTION.md`, `design/DESIGN_SYSTEM.md`, `../DEPENDENCIES.md`; vendor addons are protected. |

Use `godot-architecture.md` for boundary changes, `godot-flow-handoff.md` for transition changes, and `architecture-dramgid.md` for attribute/skill integration. The fleet roadmap is planning context, not a mandate to implement unrelated issues.

## Confirmed correction to inherited notes

On 2026-09-12, source inspection confirmed that `ui/theme/theme_builder.gd` uses `StyleBoxTexture` and preloads `assets/ui/notched_nine_patch_atlas.svg`. The old entry-file claim that nine-patch styling was unbuilt was stale. This source check does not substitute for a rendered visual inspection after a UI change.
