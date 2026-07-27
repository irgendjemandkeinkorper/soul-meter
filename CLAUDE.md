<!--
  CLAUDE.md — L0 baseline (the MAP + the RULES).
  ALWAYS loaded and prompt-cached. Keep it SMALL, STABLE, DURABLE.
  Edit BETWEEN tasks, never mid-task (edits invalidate the cache rightward).
  Transient/"for this session" understanding goes in the vault (L1), not here.
-->

# Soul Meter

A dialogue-and-consequence-first CRPG built solo in **Godot 4.7** — a consequence-driven RPG
in Era 3 of the Dramgid Cycle. **2D, isometric, rendered from 3D models.** Design-doc-first;
config name `SoulMeter`.

## Status (2026-07-26)
<!-- What actually exists, so a fresh session doesn't re-discover or re-litigate it. -->

The dialogue-and-consequence LOOP IS CLOSED end-to-end: lore vault → Pandora → reputation
ledger → dialogue → visible in-game consequence. Playable: launch, walk the field room
(WASD), talk to Iris Illepah (E) — her choices spend the Soul Meter and write the ledger live.
GLoot-based grid inventory is fully integrated into GameState and wired to the UI inventory screen.
**Still open / next candidates:** Maaack's setup wizard (editor-interactive, do on the Windows machine),
GodotGAS (store download, no public repo), portrait art
PNGs from the DS project, localization POT enablement, `docs/godot-architecture.md`'s open
human questions (gamepad-at-ship, gdUnit4/GUT).

## Architecture map
<!-- Read THIS instead of grepping to "discover" structure. Load-bearing paths only. -->

- **Engine:** Godot 4.7.1, Forward Plus, Jolt physics. Binary at `~/.local/bin/godot`
  (headless verify: `godot --headless --path . --import` then `--quit-after N`; screenshot
  under xvfb — see DEPENDENCIES.md for the window-size gotcha).
- **Entry:** `run/main_scene` = `ui/screens/main_menu.tscn`.
- **Flow (POLICY):** `ui/flow/game_flow.tscn` — the **Godot State Charts** root chart
  (Boot / Menus / Playing:Loading·Active·Paused). UI sends `GameFlow.send_event("...")`;
  **no `change_scene_to_file()` in game code, ever.** SceneLoader (Maaack) is the mechanism.
  GameFlow also mirrors `Reputation` standings into chart expression properties
  (`rep_<faction>`) so transitions can use guards.
- **Global state:** `globals/game_state.gd` (`GameState`) — flags, Soul Meter, party,
  inventory (GLoot-based), settings (persisted). `party_member.gd` is its resource.
  `globals/reputation.gd` (`Reputation`, separate autoload) — the append-only
  consequence ledger: `record(actor, faction, delta, cause, scene)` is the ONLY write path;
  `standing()`/`band()`/`why()` are derived reads. See `globals/reputation_event.gd`.
- **UI:** `ui/ui_manager.gd` (`UIManager`, mechanism-only screen stack) + `ui/screens/*`
  (Screen base + main_menu/pause/inventory/party/settings) + `ui/hud/` (`SoulGauge`,
  `field_hud.tscn`) + `ui/dialogue/` (`SMPortrait`, `SMDialogueChoice`, the Echo Gate
  balloon — Dialogue Manager's registered runtime balloon).
- **Design system:** `ui/theme/ds.gd` (token constants) + `theme_builder.gd` (the Theme —
  type variations only, e.g. `HeroLabel`/`DangerButton`; never per-node overrides). Source of
  truth is the synced Claude design-system project — see `design/DESIGN_SYSTEM.md`. Fonts in
  `assets/fonts/soul-meter/` (Cinzel/Cormorant/Fira, OFL).
- **World:** `world/test_room.tscn` (field room, has `FieldHUD` + an NPC) + `actors/player/`
  (CharacterBody2D) + `actors/npc/` (interactable, E to talk — see `dialogue/*.dialogue`).
- **Data:** `data.pandora` (committed) — canonical game data, seeded from the lore vault by
  `tools/seed_pandora.gd` (idempotent). `tools/generate_gloot.gd` is the one-way Pandora→GLoot
  generator (`data/generated/`: prototree JSON, `ItemIds` constants, `items.pot`); run via
  `Project → Tools → Regenerate GLoot prototypes` (our own `addons/soul_meter_tools`) or
  headless with `SOUL_METER_DRIFT_CHECK=1` for CI. **GLoot is fully wired to GameState and the inventory screen.**
- **Dialogue content:** `dialogue/*.dialogue` (Dialogue Manager text format). Response
  conditions need the self-closing form `[if expr /]` — plain `[if expr]` silently no-ops
  (see DEPENDENCIES.md). Metadata rides tags: `[#tag=X] [#cost=-6 soul] [#consequence=...]`.
- **Addons (13):** see `DEPENDENCIES.md` for pins & quirks — Maaack's template, State Charts,
  Pandora, Dialogue Manager, QuestSystem, GLoot, Phantom Camera, Anima, Juicee, SmartShape2D,
  PixelPen (parked on Linux). **Never edit anything under `addons/`** (except our own
  `addons/soul_meter_tools`, which is project-owned).
- **Art:** `assets/kenney/` (CC0, curated; see its ATTRIBUTION.md).
- **Where NOT to look:** `.godot/`, `.git/`, `*.import`, `dramgid-lore-dump.md` (superseded).

## The architecture spec is `docs/godot-architecture.md`
<!-- The full handoff: layers, plugin stack, sync specs, conventions. Read before building systems. -->

Five layers, dependencies point down only: **Flow (state charts) → Presentation → Systems
(GAS/GLoot/reputation) → Narrative (Dialogue Manager/QuestSystem) → Data (Pandora)**.
Load-bearing rules:

- **Pandora is canonical; nothing writes back.** GLoot prototypes / GAS effects / lookup
  tables are *generated* artifacts (`data/generated/`) — never hand-edit; regenerate via
  `tools/generate_gloot.gd`. Entities carry a `Vault Id` property bridging to the lore vault:
  Pandora owns *game data*, the vault owns *lore prose*.
- **Flow:** buttons send events, never name destinations; guards not `if`s; every state pairs
  enter/exit.
- **Reputation:** append-only event log `{actor, faction, delta, cause, scene, timestamp}` —
  **implemented**, see `globals/reputation.gd` above. Faction ids are the lore vault's kebab
  ids (60 factions exist).
- **Theming:** theme type variations, no per-node overrides; 9-patch `StyleBoxTexture` (not
  yet built — corners are currently sharp, tracked as a gap in `design/DESIGN_SYSTEM.md`).
- **Combat collision:** in-house hitbox/hurtbox (Area2D pair), GDQuest pattern — not yet built.
- **Human decisions on record:** localization = PO/gettext; inventory = grid (`Grid Size`
  required on Pandora `Items`); multiplayer = co-op is a live maybe (keep GameState
  serializable, wrap GAS behind a seam, `StateChartSerializer` matters).
- Also read `docs/godot-flow-handoff.md` (statechart tree detail) and `DEPENDENCIES.md`
  (pins; what's pending: Maaack wizard, localization POT enablement, GodotGAS, CI drift hook).

## The design doc is the spec (game design)

`soul-meter-crpg-design-doc.md` defines [CANON] vs [PROPOSAL]. §6 chassis (field → battle
scene → turn-based) is DECIDED; §9 mandates the serialized game-state singleton (exists:
`GameState`). §10 open canon questions — never resolve silently. ⚠ The doc predates the lore
vault; where they conflict (e.g. Maiiam kidnapped vs withdrawing), flag it — vault wins until
the doc is revised.

## World lore lives in the Dramgid vault (source of truth)

`~/projects/dramgid-vault/` (own git repo): 172 entities incl. `factions/` (60) and
`characters/` (25). **Read `index.json` first**, open only the 2–4 entity files the task
needs, follow `related` ids. `canon/` + `cosmology/` are do-not-contradict;
`canon/open-questions.md` = deliberate mysteries. Load-bearing for the game:
`cosmology/souls.md` (Soul Gauge = the Soul Meter), `systems/magic-system.md`,
`systems/ten-patron-classes.md`, `systems/character-creation.md`. New lore ⇒ edit entity,
rerun `build_index.py` + `validate.py` (venv at `dramgid-vault/.venv`).

## Conventions

- GDScript: static typing, `snake_case` files/vars, `PascalCase` nodes/classes; one script
  per node; signals over polling; autoloads for global state.
- Scenes `.tscn`; hand-edit only surgically; keep `uid://` refs intact.
- `rg` over `grep`, `fd` over `find`.

## Working agreement (token discipline)

- Use the map + specs above before searching; a named file/scene/symbol is your pivot.
- Prefer signatures/headings over full bodies; whole-file reads only when editing.
- Side investigations go to a subagent.
- End-of-task: learned something durable → vault note or CLAUDE.md edit (between tasks).

## Do NOT

- Don't edit this file mid-task. Don't read/edit `.godot/`.
- **Don't edit anything under `addons/`.** Don't hand-edit generated `data/generated/*`.
- Don't call `change_scene_to_file()` in game code — send a GameFlow event.
- Don't resolve open canon questions or override [CANON] in code without asking.
- Don't add mechanics without the relevant design-doc/architecture section first.
- Don't reformat/mass-rename outside the task's scope.
