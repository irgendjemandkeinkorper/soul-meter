# Weftlumin — the in-game editor (architecture note, E0)

**Status:** DRAFT for owner ratification · 2026-09-04 · author: Claude (architecture)
**Name:** *Weftlumin* (`addons/weftlumin/`) — owner ruling 2026-09-04 (replaces the working name "Forge").
**Extends:** issue #214 (play-while-editing suite, all six items shipped) and its ratified pattern.
**Traceability:** PRD FR-108 (encounter authoring pipeline), FR-501/403 (quest audit), owner directive
2026-08-31 (#214), owner rulings 2026-09-04 (§0.1). Same-map combat contract:
`docs/architecture-same-map-combat.md` (F0, #280, ratified).

---

## 0. Read this first

Weftlumin replaces the seven separately gated debug overlays (F1 dev console, F3 combat lab, F4 consequence
timeline, F5 dialogue lab, F6 quest editor, F10 layout mode, plus the pause-menu god mode) with **one
shell** in **one project-owned addon**, and widens authoring from "dressing + quests" to **scenes,
tiles, actors, characters, encounters, spawn tables, and hidden per-area state** (Harmonic Accord,
elemental defaults). Every editor operation is a **command** that a headless CLI can replay, so
Claude/Codex author content through the same validated bake path as the owner. The **bake** writes
reviewable repo artifacts and can open a PR. Canon is never written directly.

### 0.1 Owner rulings this note encodes (2026-09-04)

| # | Ruling |
|---|---|
| 1 | **Harmonic Accord** is Agreement Integrity renamed (`LocationDefinition.integrity`, `globals/location_definition.gd:14`). Per-location base stays authored; DeepSeek designs bounded passive/background variation. |
| 2 | Pandora-owned data authored in the editor bakes into a **text canonical layer in the repo** that seeds Pandora (option C). Pandora stays the runtime database; nothing writes it at runtime. |
| 3 | **Full scene creation in-game** as far as possible. Under same-map combat, field tiles are the battle grid, so tile painting is combat authoring. |
| 4 | Dialogue prose stays in external `.dialogue` files. Weftlumin **wires** NPC → file/title, creates stubs, hot-reloads. It never writes prose. |
| 5 | Author **every character kind** (NPC roster, recruitable `PartyMember`, enemy archetype, hostile placement), schema-agnostic. Plus a **random spawn system**: per-map spawn tables with % chances rolled on map load; a spawned mob persists until killed; after the player leaves and a day passes, the slot respawns (possibly a different mob). |
| 6 | **One shell**, moved into **its own project-owned addon** for reuse in sibling games (heavy rewiring accepted). |
| 7 | Sibling games (Petalkeep, Hexgame, SquadTactics, DayInTheLife, Idyllicdram, Site K) get editors later. Design the **adapter boundary now**, build adapters later. |
| 8 | Triggers = the **existing actor types** made placeable/editable (TravelExit, BuildingDoor, SMInteractable/Chest/Pickup/Switch, Enemy→Hostile, NPC, ZhavarTelegraph). No generic rule language. |
| 9 | Every operation is a **headless-replayable command**; agents may drive it; a bake may **open a PR** automatically. Human PR review stays the merge gate. |
| 10 | First content: **Dom**, then side quests, then combat encounters. |

Evening rulings (2026-09-04, on the draft):

| # | Ruling |
|---|---|
| 11 | The editor is named **Weftlumin**; F12 via the `weftlumin_toggle` action is confirmed. |
| 12 | **Canon text feeding Pandora is approved** (the one-way-rule amendment in §4.3.1 is ratified). |
| 13 | **Respawn policy by area class:** wilderness areas respawn (spawn tables replicate random encounters); towns and important quest areas do not, except limited minor respawns. See §4.10 `respawn_policy`. |
| 14 | Capacity: Codex is not hour-capped; the real constraints are the `GameFlow`/combat/stats freeze and review bandwidth (§6). Codex continues on E0.3 + E1 now. |

Assumptions where a sub-question went unanswered: the character editor is **stat-schema-agnostic**
(reads exported fields; DRAMGID #283 swaps a validator, not the editor); tile/blocking painting
targets the **F0 `FieldMap` contract** and lands after #281 step 2.

### 0.2 Five findings that change the design (verified this session)

1. **The shipped scene bake destroys authored data.** `tools/bake_layout_overrides.gd` does its work in
   `_init()`, before autoloads exist, so every actor script that names `GameState`/`GameFlow`/… fails
   to compile during the bake and **its exported overrides are dropped while the tool reports
   success** (`transition_id` 10→0, `dialogue_path` 4→0, `target_scene` 3→0 in Dom). Moving the body
   to `_initialize()` (as `tools/bake_campaign.gd:21` does) restores them. Fix in E1 (§7).
2. **`PackedScene.pack()` of a runtime instance cannot round-trip editable-instance overrides.** Dom has
   21 `editable_children = true` nodes and 79 override blocks (`TavernDoor/Facade visible=false` is
   pinned by `test/integration/test_starting_town.gd:369-370`). Every `pack()` variant loses them, and
   a first bake rewrites ~1700 of 2525 lines (format 3→4, `unique_id`, ext-id churn). **Weftlumin never
   packs a scene for `.tscn` output**; it patches the `.tscn` text surgically (§4.6.2).
3. **A scene cannot be created from data.** `LocationRegistry.ALL`, `BuildingTransitionRegistry`,
   `WorldMapRegistry._location_rows()`, `FastTravelRegistry._HUBS` are hardcoded preload arrays;
   `GameFlow.GAMEPLAY_SCENES` is derived from `LocationRegistry.gameplay_scenes()`
   (`ui/flow/game_flow.gd:57,89-92`). Ruling 3 requires these to become data-driven (§4.3.3).
4. **The runtime sandbox has no owner.** Combat Lab and Dialogue Lab each hold a private copy of the
   `SaveGame.capture_runtime_state()`/`restore_runtime_state()` + RNG snapshot and are mutually
   exclusive by a bare counter, because non-LIFO restore corrupts state. Weftlumin is the **one sandbox
   owner** (§4.5.6); authoring panels declare `needs_sandbox = false` or their runtime registration
   would be rolled back.
5. **WorldClock has no day.** Four phases, advanced only by travel and quests, `to_dict()` is `{phase}`
   (`globals/world_clock.gd:22-46,80-81`). Ruling 5's "a day passes" needs a monotonic phase counter in
   the save (§4.10). **No per-save seed exists either** (only `EncounterDirector.build_schedule()`
   takes one as a parameter), so deterministic spawn rolls need a persisted `GameState.world_seed`. Save schema today is **7** (`SaveMigrations.CURRENT_SCHEMA_VERSION`); #283 takes
   8; spawn persistence rides 8 or an additive key.

Also verified: **PlaytestRecorder (F8/F9) is not debug-gated by design** and ships in exported
playtest builds (`globals/playtest_recorder.gd:204-208`). It stays **outside** the shell (§8, ruling
needed). The seven tools sit *above* Flow and nothing in production references them (rg: only a comment
at `globals/campaign_quest_loader.gd:613`), so the migration cost is tests (13 files) and docs, not
production code.

---

## 1. Goals and non-goals

**Goals.** (a) One enablement flag, one hotkey, one dock; closed = zero resident nodes. (b) Author a
whole gameplay location in-game — backdrop, lattice, blocking, terrain data (cover/elevation/accord),
spawns, dressing, actors, metadata — and play it immediately. (c) Author characters, encounters,
quests, spawn tables as data; wire dialogue. (d) Surface hidden per-area state (Harmonic Accord,
weather/element defaults, tile charge) as overlays. (e) Every action is a replayable command; a
headless CLI drives the same code; a bake produces a review-equivalent PR. (f) Core is game-agnostic
behind an adapter so Petalkeep et al. can host it later.

**Non-goals.** Writing dialogue prose (ruling 4). Writing canon directly (ratified). Visual ground-tile
painting *before* an art atlas exists (§4.6.3). A generic trigger/rule language (ruling 8). Shipping
Weftlumin to players (debug builds only; the recorder is the one player-facing tool and is not part of it).
Building sibling-game adapters now (ruling 7).

---

## 2. What exists and what is wrong with it

| # | Finding (ranked by design impact) | Evidence |
|---|---|---|
| 1 | Bake drops autoload-referencing exports; reports success | `tools/bake_layout_overrides.gd:7` (`_init`); probe in session map `layout.md §4.2` |
| 2 | `pack()` loses editable-instance overrides; first-bake diff explosion; `--out` defaults to overwriting the source scene | `bake_layout_overrides.gd:13-15,47-56`; probe `layout.md §4.3-4.4` |
| 3 | Seven autoloads re-implement the same ~60-90 line host (activation, F-key, CanvasLayer at 1000-1200, pause save/restore, teardown) | `globals/{layout_mode,dev_console,combat_lab,dialogue_lab,consequence_timeline,quest_editor}.gd` |
| 4 | Two private sandbox copies, mutual exclusion by counter, RNG position outside `capture_runtime_state()` | `globals/save_game.gd:212-265`; `dialogue_lab.gd:250-279`; `combat_lab.gd:698-737` |
| 5 | Three uncoordinated pause owners (GameFlow Paused state, `UIManager._paused_by_ui`, labs); Esc swallowed over a lab | `ui/flow/game_flow.gd:686-692`; `ui/ui_manager.gd:90-93,150-156` |
| 6 | Hardcoded F-keys violate the ratified action-based input rule ("never hardcode a key") | `docs/godot-architecture.md:267-269`; every tool's `_unhandled_key_input` |
| 7 | Hardcoded registries block data-only scene creation | `globals/location_registry.gd:5-88`; `actors/building_door/building_transition_registry.gd` |
| 8 | Layout mode edits only `position`/`scale` and adds sprites/props; tiles, blocking, actor exports, metadata are outside its schema; no undo, no inspector, no multi-select, steals the game camera | `globals/layout_overrides.gd:10-17,85-161`; `ui/debug/layout_editor.gd` |
| 9 | Campaign overlay is add-only (cannot re-author committed Dom content); quest JSON is lossy vs `.tres`; registration couples quests and encounters non-atomically | `globals/quest_registry.gd:190-249`; `campaign_quest_loader.gd:160-178` |
| 10 | Encounter validator hard-codes the six-stat enemy field set (nine `ENEMY_FIELDS` incl. hp/speed/name) and a per-encounter `grid` — both obsolete under #283/#281 | `globals/campaign_encounter_loader.gd:6-16,156-158` |
| 11 | Text canon today is eight GDScript row tables (`tools/seed_*.gd`) with no seeder↔`data.pandora` drift check; CI drift-checks only the GLoot and iso-sprite generators | `scripts/check_generated_data.sh:41-48` |
| 12 | No visual tile pipeline: ground is a backdrop PNG + an invisible procedural lattice; only Dom has a painted `Blocking` (scale 2.2 vs unscaled ground) | `world/isometric_blockout.gd`; `world/starting_town.tscn` |
| 13 | God mode force-completes quests with no cause and grants renown without the `[debug] ` cause prefix, so `is_debug_caused()` misses it; the console refuses `quest complete` for exactly that reason | `ui/screens/debug_menu.gd:41,58,83`; `globals/dev_console.gd:330-335` |
| 14 | Debug UIs are inconsistent with the design system; `theme_builder.gd` styles only Button/LineEdit/PanelContainer families — no Tree/Tab/Split/SpinBox/OptionButton/CheckBox/TextEdit/PopupMenu | `ui/theme/theme_builder.gd` (rg of control names); `ui/debug/combat_lab.gd:60-66` |
| 15 | Player-facing strings in actor exports (`locked_message`, `prompt_text`) are outside the POT pipeline; POT regeneration is editor-UI-only | `project.godot [internationalization]`; `scripts/acceptance_gate.sh:62-80` |

---

## 3. Principles

- **P1 Tools propose, never write canon.** (ratified) Scratch under `user://weftlumin/`; bake to reviewable
  files; PR review is the gate.
- **P2 One flag, one action, one layer.** `SOUL_METER_WEFTLUMIN=1` + `OS.is_debug_build()`; InputMap action
  `weftlumin_toggle` (default F12) registered at runtime only when enabled; one `CanvasLayer` at 1000.
- **P3 Inert when disabled — test-proven.** Zero children, no signal connections, no input processing,
  no `load()` of panels, no files. One parametrised inert suite replaces seven.
- **P4 Everything is a command.** UI → `WeftluminCommand` → `WeftluminCommandBus.execute()`. The bus validates,
  applies, logs, and supports undo. The CLI replays the same log with the same code.
- **P5 Never `pack()` a live scene for `.tscn` output.** `.tscn` writes are surgical text patches that
  preserve `uid://`, format, ext-resource ids, editable-instance blocks.
- **P6 Overlay is add-only; canon edits round-trip through the bake.** Live play sees scratch as a runtime
  overlay; committed content is edited by baking, regenerating, restarting. The UI badges every entity
  CANON / SCRATCH / OVERRIDE.
- **P7 Weftlumin is a Tooling layer above Flow.** Production never references it; production may grow small
  downward services Weftlumin calls (`Battle.abandon()`, a sandbox owner API, registry registration hooks,
  a chart expression property).
- **P8 Schema-agnostic where the schema is moving.** Inspectors use `get_property_list()` filtered on
  `PROPERTY_USAGE_SCRIPT_VARIABLE`; character `stats` is an opaque block validated by a pluggable schema.
- **P9 Provenance is visible.** Ledger writes carry `DevConsole.DEBUG_CAUSE_PREFIX`; every command carries
  `provenance {source: ui|cli|agent, actor}`; a bake report is the PR body; auto-PRs never set labels.
- **P10 Adapter boundary, not conditionals.** Core knows nothing about Soul Meter. The game implements
  `WeftluminGameAdapter`; panels and kinds are registered by the adapter.

---

## 4. System architecture

### 4.1 Layer placement and repository layout

```
Tooling      Weftlumin core (addon)  +  Soul Meter adapter, kinds, panels      ← calls down only
Flow         GameFlow chart (gains one expression property: editor_open)
Presentation UIManager, screens, HUD
Systems      Battle, SaveGame (gains sandbox-owner API), registries (become data-driven)
Narrative    Dialogue Manager, QuestSystem
Data         Pandora  ←  canon/ (text canonical layer)  →  data/generated/
```

Tooling is a **debug-only sixth layer** on top of the ratified five (`docs/godot-architecture.md:24-35`):
it depends down on all of them and nothing depends on it; it is absent from release builds by the
activation gate and export filter. This is a spec amendment (§8 ruling 2) recorded alongside the
data-rule amendment in E1.3a.

```
addons/weftlumin/                  # CORE — game-agnostic, project-owned, vendorable
  plugin.cfg, plugin.gd                # optional EditorPlugin: tool-menu entries only (never the activation path)
  bootstrap.gd                         # the ONLY node resident in disabled builds; declared as a project.godot
                                       # autoload (`WeftluminBootstrap`), so exports carry it and the inert test
                                       # exercises the real activation path
  core/  command.gd command_bus.gd package.gd kind_registry.gd sandbox.gd scene_model.gd
         tscn_document.gd bake.gd report.gd adapter.gd (WeftluminGameAdapter interface)
  shell/ shell.tscn shell.gd dock/… inspector/… palette/… camera.gd
  panels/ (universal panels: scene, package, console-host, log)         # export-excluded
  tools/  weftlumin.gd (CLI, SceneTree script) pr.gd                         # export-excluded
  templates/ field_scene.tscn.tmpl location.json.tmpl …
weftlumin/                                 # SOUL METER ADAPTER — game-specific, in this repo
  soul_meter_adapter.gd               # implements WeftluminGameAdapter
  kinds/   locations.gd characters.gd encounters.gd spawn_tables.gd quests.gd dialogue_wiring.gd
  panels/  combat_lab_panel.gd dialogue_panel.gd quest_panel.gd console_panel.gd timeline_panel.gd
           spawn_panel.gd character_panel.gd accord_overlay.gd
canon/                                 # TEXT CANONICAL LAYER (§4.3), committed
  dom/  campaign.json  locations/  characters/  encounters/  spawn_tables/  quests/
  wilds/ …
```

Export: `addons/weftlumin/panels/*`, `addons/weftlumin/tools/*`, `weftlumin/panels/*` join
`export_filter`'s exclude list. `bootstrap.gd`, `core/*` and the adapter ship (inert). If an env-enabled
debug export lacks the panels, the bootstrap fails closed with one `push_warning`.

### 4.2 Package model: the campaign envelope, generalised

Weftlumin does not invent a new scratch format. The campaign package
(`user://campaigns/<id>/campaign.json + quests/ + dialogue/ + encounters/`, `docs/quest-editor.md:29-49`)
becomes the **Weftlumin package**, and its loader pattern becomes a **kind registry**:

```gdscript
class_name WeftluminKind extends RefCounted
var id: StringName            # &"locations", &"characters", &"encounters", &"spawn_tables", &"quests", &"scenes"
var subdir: String            # "locations"
var ext: String               # "json"
var stable_id_kind: StringName
func validate(documents: Array[Dictionary], errors: Array[Dictionary]) -> Array[Dictionary]  # pure
func register(normalised: Array[Dictionary]) -> bool     # runtime overlay (replace-whole-kind)
func clear() -> void
func diff(previous: Array[Dictionary], next: Array[Dictionary]) -> Dictionary
func bake(normalised: Array[Dictionary], target_root: String, write: bool, force: bool) -> Dictionary  # weftlumin.bake.v1 report
```

Reused as-is: bounded discovery (`globals/campaign_package_files.gd:41-128`), the attributed error shape
`{file, field, expected, code, message, line?}` (`:131-149`), `StableIds` grammar (add kinds
`location`, `encounter`, `spawn_table`, `scene`), the tolerant-load / strict-register split, the
transactional writer (`globals/quest_editor.gd:401-600`: tmp → bak → promote, rollback, path
containment) — moved into `core/package.gd`. Fixed: the manifest gains `schema`, `kinds`,
`base_commit`, `provenance`; register/clear become **per kind** with a single `apply(package)` that only
touches kinds whose content changed (today quests clear encounters and a refused encounter set leaves
quests registered, `campaign_quest_loader.gd:160-178`).

Package root while editing: `user://weftlumin/<package_id>/`. A package targets a **hub** (`dom`, `wilds`,
…) and its bake lands in `canon/<hub>/` (§4.3) and the hub's scenes.

### 4.3 The text canonical layer (ruling 2)

**4.3.1 Direction.** This **amends the one-way data rule** in `docs/godot-architecture.md`: the chain
becomes `canon/` text → `data.pandora` → `data/generated/`, still one-way, one hop longer. Ruling 2 is
that amendment; E1.3 records it in the architecture spec before any category migrates (§8).
Today the de-facto canon is GDScript row tables in eight `tools/seed_*.gd` scripts →
`data.pandora` (committed, 16,990 lines) → `tools/generate_gloot.gd` → `data/generated/*.json|gd`.
Weftlumin makes the first hop **data**: `canon/<hub>/<kind>/*.json` is the source; `tools/seed_pandora.gd`
gains a `CanonReader` that upserts Pandora entities by stable id (the existing `_find_by_vault_id`
pattern in `tools/seed_town_npcs.gd:481-483`); the generator is unchanged. Row tables migrate into canon
JSON one category at a time (Elements, Classes, Peoples, Items, Spells, Effects, Factions, NPCs,
Combatants, Encounters, Locations, Lore — the categories `seed_pandora.gd` creates). The `Vault Id`
property remains the bridge to the lore vault; Weftlumin treats `vault_id` as required-on-create for
recruits, validates it against `~/projects/dramgid-vault/index.json` (read-only), refuses renames, and
never generates one (canon proposals are the Ollama worker's job).

**4.3.2 Drift checks.** `scripts/check_generated_data.sh` gains a second stage: seed in
`SOUL_METER_DRIFT_CHECK=1` mode reports `CANON-SEED: no drift.` when `canon/` fully explains
`data.pandora`. The existing GLoot stage keeps checking `data.pandora` → `data/generated`. Auto-PRs
that touch canon therefore also carry the regenerated `data.pandora` and `data/generated` diffs; the
PR body lists the regenerated files separately from the authored ones.

**4.3.3 Registries become data-driven** (prerequisite for ruling 3). A location document
`canon/<hub>/locations/<id>.json` carries everything today's four hardcoded arrays hold:

```json
{ "schema": "weftlumin.location.v1", "id": "loamroot-grove", "display_name": "Loamroot Grove",
  "scene_path": "res://world/loamroot_grove.tscn", "allowed_gameplay": true,
  "default_spawn_id": "default", "spawns": {"from_dom": "from_dom"},
  "arrival_flag": "chapter_loamroot_reached", "arrival_checkpoint": "location-arrival",
  "harmonic_accord": 82.0, "thinning_tier": 1, "weather_default": "mozh", "no_combat_zone": false,
  "respawn_policy": "wilderness",
  "world_map": {"position": [420, 310], "routes": [{"to": "dom", "danger_rank": 1, "encounter_table": "wilds-road"}]},
  "fast_travel_hub": false,
  "transitions": [{"id": "grove-shrine-door", "destination": "res://world/interiors/grove_shrine.tscn", "spawn_id": "from_grove"}],
  "vault_id": "loamroot-grove" }
```

The bake generates `world/locations/<id>.tres` (`LocationDefinition`, never hand-edited after migration)
and `data/generated/location_index.json`; `LocationRegistry.ALL`, `WorldMapRegistry._location_rows()`,
`FastTravelRegistry._HUBS`, `BuildingTransitionRegistry` read the index. Named preload consts
(`LocationRegistry.DOM`…) stay for code references. A live `LocationRegistry.register_runtime(def)` lets
an unbaked scene be travelled to in-session (overlay, P6). `GameFlow.GAMEPLAY_SCENES` is a cache
computed once at load (`ui/flow/game_flow.gd:57,89-92`), so travel validation must query
`LocationRegistry.is_gameplay_scene()` dynamically (or refresh on a `locations_changed` signal) — a
`GameFlow` touch that waits for the F1 + F3 freeze to lift and rides E3.3b.

### 4.4 Commands, undo, log

```json
{ "schema": "weftlumin.command.v1", "id": "01J…", "ts": "2026-09-04T22:10:03Z",
  "package": "dom-market-pass", "kind": "scene", "op": "set_property",
  "target": {"scene": "res://world/starting_town.tscn", "node": "Actors/BellHouseDoor"},
  "params": {"key": "locked_message", "value": "The bell-house is shut at night."},
  "pre_state": {"value": "This door is locked."},
  "provenance": {"source": "ui", "actor": "owner"} }
```

- `WeftluminCommandBus.execute(cmd)` → validate (kind-specific) → **capture `pre_state` authoritatively
  from the live model** (a caller-supplied `pre_state` is ignored) → apply → append to
  `user://weftlumin/<package>/commands.jsonl` → push onto Godot's runtime `UndoRedo` with the inverse
  (kinds without a natural inverse snapshot the affected document). **Undo and redo are themselves
  logged** as `{"op": "undo", "target": {"command": "<id>"}}` entries, so the log's *effective stream*
  (commands minus undone ones) is what replay and bake apply; replay verifies each recorded
  `pre_state` against the fresh instance and refuses on mismatch (drift detection). Merge mode
  groups drag-moves into one undo step.
- Two op classes. **Document ops** (scene, package, dialogue-wiring) mutate files or out-of-tree scene
  instances and are **replayable**: `replay(log)` re-executes them against a fresh out-of-tree instance
  of the target scene or a fresh package, never against the running scene (P5); the CLI (§4.13) and the
  replay-equivalence tests use this path. **Live-state verbs** (the console vocabulary, `respawn now`,
  sandbox arm/disarm) act on the running autoloads; they are logged with provenance for the session
  record but are **excluded from replay-equivalence** — headless, the CLI runs them against the live
  autoloads inside `_initialize()`, never against an out-of-tree instance.
- Document ops (initial set): scene — `set_property`, `add_node`, `remove_node`, `move_node`,
  `paint_cells`, `set_metadata`, `new_scene`, `normalize_blocking_scale`; package — `upsert_document`,
  `delete_document`, `register`, `clear`; dialogue — `create_stub`, `wire_npc`. Live-state verbs: the
  existing `DevConsole.execute_command` vocabulary, unchanged and still `[debug] `-tagged.
- Recorder interop preserved: the shell emits the existing `dev_console_command` and
  `combat_lab_battle_started` events (pinned by tests) plus a new `weftlumin_command` event.

### 4.5 The shell

**4.5.1 Activation.** `WeftluminBootstrap` (a `project.godot` autoload, one `Node`, present in every build
including exports — the addon's `plugin.gd` is *not* the activation path): `force_enabled_for_tests` setter →
`_refresh_activation()`; enabled iff `OS.is_debug_build()` and `OS.get_environment(adapter.env_flag) == "1"`
or the test seam. On enable: register InputMap action `weftlumin_toggle` (default `KEY_F12`, remappable),
`load()` the shell scene lazily on first toggle. On disable: unregister, free shell, restore everything.
Pattern lifted from `globals/layout_mode.gd:8-11,69-86` (one copy, not seven).

**4.5.2 Chart integration, pause, input.** Weftlumin does not write `get_tree().paused`. The adapter exposes
`set_editor_open(open: bool)`; Soul Meter's implementation sets a GameFlow **expression property**
`editor_open` (the same mechanism as `rep_<faction>`, `ui/flow/game_flow.tscn:24-27`) and GameFlow pauses
the tree in a guarded transition. Guards on `pause`, `enter_battle`, `travel` read `editor_open`, so the
pause menu cannot open over the editor and travel is refused while a scene is being edited (guards, not
`if`s). This is the one production touch on `GameFlow`, so it waits for **both** F1 (#281) and F3 (#283)
to merge, per the ship plan's freeze. The shell is a `CanvasLayer` (layer 1000, `PROCESS_MODE_ALWAYS`) whose single child is a full-rect
`Control` root carrying `theme = adapter.theme()` — `CanvasLayer` has no `theme`, and children of a
CanvasLayer do not inherit the scene root's theme (`ui/ui_manager.gd:96`). The shell marks all its
input handled while open. `UIManager` gains nothing except tolerating an external modal owner.

**4.5.3 Layering.** Production ladder is FieldHUD 5 / DialogueBalloon 8 / UIManager 10 / LoadingScreen
100. Weftlumin sits at **1000** and **closes itself on `Loading` enter** so it never persists across a
`GameFlow.travel()` load.

**4.5.4 Camera.** Weftlumin owns a free `Camera2D` made current on open; the player's camera is restored on
close; `Player.camera_bounds` is ignored while editing so the owner can look past the map edge.

**4.5.5 Dock.** Left: scene tree + palette; centre: viewport passthrough with overlays; right: inspector
(schema-agnostic, P8); bottom: tabs for console, command log, consequence timeline, validation. Panels
implement one contract:

```gdscript
class_name WeftluminPanel extends Control
var title: String; var needs_sandbox: bool; var hotkey_hint: String   # shell owns bindings; panels ask
func configure(host: WeftluminShell) -> void
func refresh(payload: Dictionary) -> void
func commands() -> Array[Callable]   # the panel's command constructors, for the CLI's help
```

**4.5.6 Sandbox owner.** `core/sandbox.gd` is the single owner: `arm(owner_token)` = restore-if-armed
then capture (the unconditional pair from `dialogue_lab.gd:169-179`), `disarm()` = restore once then
clear, `is_armed()`, `owner()`. It captures `SaveGame.capture_runtime_state()` **plus** the
`SkillCheck` RNG seed/state, restoring seed before state. The owner never enumerates surfaces itself:
anything a later wave adds to `SaveGame.capture_runtime_state()` (spawn slots, E4.1) is covered
automatically. Autosave suppression stays in `SaveGame`
(`request_autosave()` refuses at staging while armed). Panels with `needs_sandbox = true` (combat
replay, dialogue replay) request it; the shell refuses audibly if another sandbox panel holds it, or
ends that session first (LIFO only). Authoring panels (`needs_sandbox = false`) never run inside a
sandbox. The production-ownership predicate ("a real battle or balloon is live") lives in the shell and
switches to `Battle.session_active` after #281. Prerequisite production seam: `Battle.abandon()`, so
the shell never pokes `Battle` privates the way `combat_lab.gd:232-243` does.

**4.5.7 Design system.** Editor chrome is **developer tooling**: DS-token-bound (`ui/theme/ds.gd`
colours/fonts only) but exempt from composition rules (one bronze element, 1080 frame). `theme_builder.gd`
gains a small `Editor*` variation family for the controls a dock needs (Tree, TabContainer, SplitContainer,
SpinBox, OptionButton, CheckBox, TextEdit, PopupMenu). No emoji, ever. Ruling needed (§8).

### 4.6 Scene authoring

**4.6.1 Scene model.** `core/scene_model.gd` wraps the live gameplay scene: editable predicate (the
`layout_editor.gd:180-193` rules, widened to every `Node2D` under adapter-declared editable roots)
**with scene-ownership boundaries**: nodes owned by the edited scene accept every op; nodes inside an
instanced sub-scene accept only property overrides (written as `editable path=` override blocks, and
only when the instance is `editable_children`); adds and removes are allowed only under scene-owned
nodes or editable instances. The model tracks `Node.owner` and the instance boundary per node,
picking (`_pick_editable`, `_editable_bounds`), snapping (8 px, and **cell snap** via
`IsoGrid.cell_to_world`), selection set, and the node → command mapping. It applies commands to the live
scene the way `LayoutOverrides.apply_to_scene()` does today (kept as the replay primitive), tagging
additions with meta so they re-select.

**4.6.2 `.tscn` text patcher (`core/tscn_document.gd`).** Parses a `.tscn` into header, `ext_resource`,
`sub_resource`, node blocks (name/type/parent/instance/groups + raw property lines), connections,
`editable path=` lines. Operations: `set_property(node_path, key, value_text)`, `add_node(block, parent,
index)`, `remove_node(path)` (with descendants + connections), `add_ext_resource(path, type, uid)` with
stable ids, `set_packed_bytes(node_path, key, bytes)` (writes `tile_map_data` in the file's existing
style). Untouched lines are byte-preserved; set values go through a **type-aware encoder**: primitives via
`var_to_str`, `Resource` values via `add_ext_resource` + `ExtResource("<id>")` (or an existing
`SubResource`), and every other type refused with an attributed error — `var_to_str` alone is not a
`.tscn` codec. **Round-trip test:
parse + serialise every `.tscn` in the repo, as committed, = byte-identical** (this proves the parser;
it does not promise stability across an engine re-save, which is why canonical scenes are never
re-saved from the Godot editor casually — the existing "hand-edit only surgically" rule). **Bake
idempotence test:** baking the same log twice yields identical output. Bake = load `.tscn` text →
apply the scene commands from the log → write. Format stays 3, `uid://` refs intact (CLAUDE.md: "hand-edit only
surgically; keep `uid://` refs intact" — this is that rule, automated). New nodes referencing an
autoload-using script are fine: nothing is instantiated.

**4.6.3 Tiles and data layers.** Visible ground is a backdrop PNG (`TerrainBackdrop`) over an invisible
procedural lattice (`IsometricGround`, `world/isometric_blockout.gd`); there is no ground atlas to paint
yet. Weftlumin therefore paints **data layers**: `Blocking` (existing, `world/nav/blocking_tiles.tres`) and a
new **`Terrain`** `TileMapLayer` with a project-owned tileset carrying custom-data layers `cover: bool`,
`elevation: int` (F0 D1's "third layer" option; recommended because `ground_tileset.tres` is generated)
and, in v2, `accord_delta: int` (§4.11). Brushes: cell, rect, line, fill; paint in the **layer's own cell
space** (`local_to_map(to_local(world))`); after each stroke `IsoGrid.build()` re-runs so the
walkability overlay updates live (the overlay states which clearance it shows: player path dilates by
`STATIC_CLEARANCE_CELLS = 1`, placement uses 0). Dom's `Blocking` is at scale 2.2; a one-shot
`normalize_blocking_scale` command re-authors it at scale 1 (bake-only, reviewed). Backdrop placement
and swap is a plain `set_property`. When #298's art pipeline yields a real ground atlas, the same brush
paints `IsometricGround` visually; nothing else changes.

**4.6.4 Actors (ruling 8).** The palette is **registry-driven**: the adapter declares
`placeables() -> Array[WeftluminPlaceable]` (`scene: PackedScene, display, group, default_exports`), initially
NPC, BuildingDoor, TravelExit, SMInteractable, Chest, Pickup, InteractiveSwitch, Enemy (→ `Hostile` after
#281), ZhavarTelegraph, Marker2D spawn markers, and #284's new interactables when they land. The
inspector edits exports via `get_property_list()` (P8) with editors per type hint (`@export_file`,
`@export_range`, enums, `StringName`), plus **semantic pickers** the adapter supplies: location ids,
spawn ids, flag names (grammar-checked live via `quest_audit.flag_grammar_violations`), faction ids,
dialogue file + title (§4.8), item ids, unit ids. Placement snaps to a walkable cell
(`GridPlacement.open_cell_center_near`). Dressing (the current layout tool) is one sub-tool.

**4.6.5 New scene.** `new_scene {hub, id, size_cells, backdrop}` renders `templates/field_scene.tscn.tmpl`
into the package scratch — `user://weftlumin/<package>/scenes/<id>.tscn` — never into `res://` (P1;
exported `res://` is read-only anyway). The scene is loaded from `user://` for live play and moves to
`world/<id>.tscn` only at bake. It carries the minimum viable skeleton (root `Node2D` y-sorted with the `FieldMap`
script after #281; `TerrainBackdrop`; `IsometricGround`; empty `Blocking` and `Terrain`; `Walls`;
`Player`; `PartyFollowers`; `SpawnDefault`; `FieldHUD`; `<Id>Dressing/{GroundDetails,SoftDetails,SolidProps}`;
`CombatOverlay` after #281), writes the location document into the package (`locations/<id>.json`,
baked to `canon/<hub>/locations/` later), registers the location live (§4.3.3) and travels there. Interiors use an `interior_scene` template (no grid, `no_combat_zone: true`
per the F0 ruling).

### 4.7 Characters (ruling 5, schema-agnostic)

One document kind, `canon/<hub>/characters/<id>.json`, with a discriminator:

```json
{ "schema": "weftlumin.character.v1", "id": "aela-quietweftlumin", "kind": "npc|recruit|archetype",
  "display_name": "Aela Quietweftlumin", "vault_id": "aela-quietweftlumin", "faction_id": "shattersteel-concord",
  "portrait": {"asset_path": "res://assets/generated/portraits/…png"}, "sprite_unit_id": "villager-f-03",
  "dialogue": {"path": "res://dialogue/dom_townsfolk.dialogue", "title": "dom_aela_quietweftlumin"},
  "placement": {"scene": "res://world/starting_town.tscn", "anchor": "WoundLip", "offset": [122, 80], "facing": "east"},
  "routine": {"morning": {"position": [2820, 1525], "state": "working"}, "night": null},
  "recruit": {"min_reputation": 0, "min_infamy": 0, "epithet": "…", "background": "…", "discipline": "…", "patron": "…"},
  "stats": {"schema": "six-stat.v1|dramgid.v1", "...": "opaque, validated by the schema named"} }
```

`kind` and `stats.schema` are **open registries declared by the adapter** (initial kinds: the three
above; initial schemas: `six-stat.v1` now, `dramgid.v1` after #283), not closed enums.
`npc` rows seed the Pandora NPC category and generate the roster/placement JSON `TownNpcSpawner`
already consumes; `recruit` rows seed the recruitable `PartyMember` set; `archetype` rows seed
Combatants and are what encounters and spawn tables reference by id (never inline stats — the
`archetype_id` indirection in `campaign_encounter_loader.gd:192-202` is the seam). The `stats` block is
validated by whichever schema `#283` installs; the inspector renders it from the schema, not from
hard-coded fields. Portrait/sprite pickers use the existing texture-level resolver pattern
(`ChargenArtResolver.portrait_texture`) and `assets/generated/sprites/units/<id>/…`.

### 4.8 Quests and dialogue wiring (rulings 4, 10)

The F6 quest editor's model (validate in memory → transactional write → reload through the same loader →
register → refuse to reset live progress without explicit authorisation, `globals/quest_editor.gd:75-598`)
is kept verbatim as the `quests` kind and re-hosted as a panel; quest JSON stops being lossy (adds
`required_flags`, `objectives`, `participant_actor_ids`, `hook_ids`, description/objective text so a
baked quest passes `template_conformance`). The F5 dialogue lab's replay lifecycle (`globals/dialogue_lab.gd:104-247`,
`CACHE_MODE_IGNORE` hot reload) is the **dialogue panel**, extended with: the *effective* NPC route with
the winning layer named (export → `QuestRegistry.dialogue_route_for_actor` → `NpcReactions`), a title
picker over saved and unsaved text (`DMCompiler.get_cues_in_text`), `create_stub {file, title, npc}`
that appends a minimal titled block to a `.dialogue` file under the package (never to `res://dialogue/`
until bake), and a GDScript port of the `[if expr]` self-closing lint (`tools/lint_dialogue_conditions.py`
runs in CI before Godot exists; the bake also runs the Python lint when present). Route tables
(`quest_registry.gd:696-721`, `globals/npc_reactions.gd`) move to the text layer in a later wave.
`quest_audit` checks that are pure statics run live per the table in the session map (`campaign.md §6`):
flag grammar, phase reachability, softlocks on dialogue save, distinct outcomes; read-back coverage and
orphaned flags run at bake.

### 4.9 Encounters after #281

Post-F1 an encounter definition owns actors (archetype ids), spoils, outcomes/consequences, speech hooks,
`group_id` — **not** a grid and not weather (F0 D8: grid derives from field tiles; weather is per
location). The `encounters` kind drops `grid` and `weather_default`, keeps everything else, and its
"fits the board" check moves to the scene: deployable cells ≥ party + hostiles. Set-piece encounters
carry authored deployment cells (`set_piece: {ally_cells: [...]}`). Hostile placement is in the scene
(`Hostile` instances via the palette). Combat Lab's model (`globals/combat_lab.gd:144-361,409-695`:
weather resolution, forecast==resolution tripwire, session markdown) becomes the **combat panel** and
starts sessions through `Battle.start_session(field, first_hostile)` / `start_set_piece(...)`.

### 4.10 Random spawn system (ruling 5)

**Data** — `canon/<hub>/spawn_tables/<id>.json`:

```json
{ "schema": "weftlumin.spawn_table.v1", "id": "loamroot-grove-ambient", "scene_path": "res://world/loamroot_grove.tscn",
  "slots": [
    {"id": "hollow-east", "anchor": "SpawnSlotHollowEast", "respawn_days": 1,
     "entries": [{"archetype_id": "bog-wight", "weight": 40}, {"archetype_id": "loam-boar", "weight": 40}, {"empty": true, "weight": 20}],
     "pack_size": {"min": 1, "max": 3}}
  ],
  "caps": {"max_alive": 12} }
```

**Respawn policy per location** (ruling 13). The location document carries
`respawn_policy: "none" | "limited" | "wilderness"`. `none` (towns, important quest areas): the
`spawn_tables` kind refuses any table targeting the scene. `limited` (minor respawns in otherwise
settled areas): at most 2 slots, `respawn_days >= 3`, `pack_size.max <= 2`, `empty` weight at least half
the total (PROVISIONAL bounds; DeepSeek sets them in E1.6). `wilderness`: full tables — this is how
Weftlumin replicates random encounters on a persistent map. Dom is `none`; `test_room`/the Wilds is
`wilderness`; new locations default to `limited` until authored.

**Runtime** — a production `SpawnDirector` (Systems layer, `globals/world/spawn_director.gd`):

1. **Seed and day.** `GameState.world_seed: int` is drawn once at New Game, persisted as an additive
   save key, and rides the `game_state` surface of `capture_runtime_state()`. `WorldClock` gains
   `phase_count: int` (monotonic, persisted, additive key); `day_index() -> int` is integer division
   `phase_count / 4`. Phases still advance only on travel and quests (FR-504a: never on a timer);
   leaving and returning costs two phase advances, "wait a day" is four.
2. **Slot state** per `(table, slot)`, persisted as `spawn_state` (additive key; schema bump only if
   #283 lands in the same release) and therefore inside `capture_runtime_state()` automatically:
   `{group_id, spawned_day, cleared_day, members: [{archetype_id, downed}], blocked_by_cap}`.
3. **On scene ready, rehydrate first, then roll.** Rehydrate: every slot with living (`downed ==
   false`) members re-instantiates them at the slot anchor under their stored `group_id`. Roll:
   tables ordered by id, slots in file order (deterministic), for each slot with `members == []` and (`cleared_day == null` or `day_index >= cleared_day + respawn_days`):
   `rng.seed = hash([world_seed, table_id, slot_id, day_index])` (`RandomNumberGenerator`, one per
   roll); pick an entry by relative weight; the **`empty` sentinel** sets `cleared_day = day_index`
   and instantiates nothing; otherwise draw `pack_size` and instantiate `Hostile`s with
   `unit_id = archetype_id`, `group_id = "<table>:<slot>:<day_index>"`. **Cap scope is per scene**:
   `max_alive` counts living members across all tables of that scene; a slot that would exceed it is
   marked `blocked_by_cap` and stays eligible (no `cleared_day`) for the next visit. IDLE hostiles
   must be free (#282 budget).
4. **Persistence until killed.** Members that survive a visit are re-instantiated at the slot anchor
   on the next visit; a member downed in combat is marked `downed` and never returns (F0 ruling 3:
   downed hostiles despawn on scene exit — that ruling governs authored hostiles; **spawn-slot
   hostiles respawn by design under owner ruling 5**, recorded as an F0 clarification in §8). The slot
   clears (`members = []`, `cleared_day = day_index`) when every member is downed; because the next
   roll gets a new day-stamped `group_id`, an old defeated-group flag never blocks it.
5. **Schema invariants** (validated by the `spawn_tables` kind): every slot has at least one non-empty
   entry with `weight > 0`; weights are positive integers; `respawn_days >= 1`; `pack_size.min >= 1`;
   the anchor marker exists in the scene. **Weights** are relative; DeepSeek owns normalisation,
   danger-rank scaling by `thinning_tier` (reuse `EncounterDirector._apply_thinning_weights`), respawn
   cadence vs the Zhavar rung, pack-size curves, and `max_alive` defaults — delivered as a design note
   + pure functions + deterministic tests over `SpawnDirector.roll()`, reviewed by Claude, frozen
   before E4 starts.

Weftlumin's **spawn panel** places `SpawnSlot<PascalCase>` markers (a `Marker2D` placeable), edits tables,
shows each slot's live state, and offers `respawn now` / `clear slot` as `[debug] `-tagged console
verbs. Interaction with travel encounters: `EncounterDirector` (journeys) and `SpawnDirector` (maps)
stay separate; both read the same archetype ids.

### 4.11 Harmonic Accord and elemental defaults (ruling 1)

**Rename.** `LocationDefinition.integrity` → `harmonic_accord` (code, `.tres`, docs; `thinning_tier`
stays a separate front-line modifier). `SkillCheck.location_fizzle_integrity()` keeps its math; the
context key `agreement_integrity` becomes `harmonic_accord` with a one-wave alias.

**Effective accord at a cell** (v1 scalar, v2 spatial):

```
accord_at(cell) = clamp(SkillCheck.location_fizzle_integrity(base, scene) + zone_delta(cell) + variation(day_index, phase, weather), 0, 100)
```

- Thinning is subtracted **once**, inside `location_fizzle_integrity()` (`globals/skill_check.gd:232-234`);
  the formula never applies `thinning_tier` a second time. `fizzle_percent(agreement_integrity, …)`
  keeps its parameter name; callers pass `accord_at(cell)`. The one-wave alias covers only the context
  dictionary key (`agreement_integrity` → `harmonic_accord`).
- `base` = the location document's `harmonic_accord` (C21/#258 authored values, DeepSeek).
- `zone_delta` (v2) = the sum of `AccordZone` volumes containing the cell — the **one new placeable**
  this note proposes (a data volume, not a trigger: exports `accord_delta`, optional `element_default`
  override for "this swamp corner is Mozh"). Alternative without a new type: `accord_delta` as Terrain
  custom data painted per cell. Ruling needed (§8).
- `variation` = DeepSeek's bounded background function (±10 PROVISIONAL) of `day_index`, WorldClock
  phase, the zone's Zhavar rung, and weather element vs the location's patron element; deterministic
  from `(world_seed, day_index, phase)`.
- **Sampling instant:** `Battle.forecast_context()` freezes `(day_index, phase, weather, cell)` when
  the forecast is built and resolution reuses that same context, so forecast == resolution holds by
  construction even if a phase or weather tick lands between the two.
- **Saturation lint** (bake): warn when `base_adjusted + max(zone_delta) + 10 > 100` or
  `base_adjusted + min(zone_delta) − 10 < 0`, so a clamp never hides an authoring error.
- Plug-in: `FieldMap.accord_at(cell)`; `Battle`/`CombatController` supply it per action from the caster's
  cell instead of one float per battle (`combat_controller.gd:74,143-144,1239-1240`) — a combat change
  that follows #281.

**Elemental default per area** ("a swamp has default Mozh"): `weather_default` per location (F0 D8) in
the location document, overridable per `AccordZone`. **Overlay:** Weftlumin draws a per-cell accord heatmap,
the effective weather element badge, tile charge (`TileState`), and Blocking/walkability — read-only,
from `FieldMap` and the live controller. It is how the owner *sees* hidden state while playing.

### 4.12 Console, timeline, god mode

The dev console's interpreter (`globals/dev_console.gd:86-451`, 11 pinned tests) is the console panel
and the seed of the CLI's state verbs; provenance rules are unchanged (`[debug] ` prefix,
`dev_console_used` flag). The consequence timeline's model (`globals/consequence_timeline.gd:158-280`)
is a bottom tab. The pause-menu god mode (`ui/screens/debug_menu.gd`) folds into the console once
`QuestRegistry.debug_force_complete()` accepts a `cause`, so `quest complete` can finally exist
tagged; until then god mode stays a separate, explicitly untagged debug-build surface.

### 4.13 Headless CLI, agent parity, auto-PR (ruling 9)

`addons/weftlumin/tools/weftlumin.gd` (a `SceneTree` script; body in `_initialize()` so autoloads exist):

```
godot --headless --path . --script addons/weftlumin/tools/weftlumin.gd -- <subcommand> [args]
  validate  <package_dir>                       # all kinds, attributed errors, exit 0/1
  apply     <package_dir> <commands.jsonl>      # replay onto fresh out-of-tree instances; write scratch
  bake      <package_dir> [--write] [--force]   # report by default (weftlumin.bake.v1); writes canon/, .tscn patches, generated .tres, index
  regen                                         # seed Pandora from canon/, run generators, drift checks
  lint      <package_dir>                       # quest_audit statics, dialogue [if /] lint, flag grammar, POT delta report
  pr        <package_dir> [--issue N] [--draft] # worktree branch weftlumin/<package>, run lint+suite subset, commit, gh pr create
```

Same code path as the UI: `WeftluminCommandBus.replay()`. Agents author by writing a package + command log
(or by calling the verbs) and running `bake`/`pr`. `pr`: creates `weftlumin/<package_id>` in a worktree,
applies the bake, runs `lint` + the affected tests, commits with the session trailers, and opens a PR
whose body is the bake report + `Closes #N`. "Affected" is a fixed kind → test-glob map declared by the
adapter (scenes → `test/integration/test_starting_town.gd`, `test_field_room.gd`, `test_travel_*`;
quests/dialogue → `test/unit/test_quest_*`, `test_campaign_*`; encounters/spawn → `test/unit/test_encounter_*`,
`test_spawn_*`; characters → `test/unit/test_party_*`, `test_npc_*`; canon → the drift stages). It never
sets labels or milestones (AI-ROLE-POLICY: labelling is Claude's triage act). `.tscn` patches to Dom
collide with #305's art batch — the PR flow runs `jules-merge-conflicts.yml`'s overlap scan locally
first and refuses to open a PR that touches a file with an open PR unless `--force`; the refusal is a
**reported outcome** (`refused_overlap` in the bake report, exit code 3), never silent. The in-game **Bake & PR** button launches the same
subcommands as a detached headless Godot via `OS.create_process` (debug builds only; `OS.execute`
would block the main thread for the whole run), polls the report file, supports cancel, and shows
the report.

### 4.14 Export, inertness, tests

- **Inert suite (parametrised):** disabled → autoload has 0 children, `is_processing_unhandled_key_input()
  == false`, no `weftlumin_toggle` action, no `user://weftlumin` directory, no production signal connected to a
  Weftlumin callable; enabled-then-disabled → identical. One suite replaces seven (`test/integration/test_*_inert.gd`).
- **Command tests:** every op has apply + undo + replay-equivalence (UI log replayed headless yields the
  same document/`.tscn` text).
- **Patcher tests:** repo-wide `.tscn` round-trip is byte-identical; each op on a fixture; Dom
  `TavernDoor/Facade.visible == false` survives a bake.
- **Bake tests:** report-only default writes nothing; `--write` output loads in a headless import and
  passes `test_starting_town`/`test_field_room` contract tests; drift checks green after `regen`.
- **Overlay boundary test:** registering a package at runtime (`apply`, `register_runtime`) leaves every
  file under `res://canon/` and `data.pandora` byte-identical (hash before/after) — ruling 2's
  "nothing writes Pandora at runtime" made testable.
- **Deliberately not tested:** stability of baked `.tscn` files across a Godot-editor re-save. Canonical
  scenes are not re-saved from the editor casually (existing rule); the byte-identical gate covers files
  as committed.
- **CI:** `test.yml` gains `weftlumin lint` over `canon/` and the canon drift stage; a nightly `weftlumin apply +
  bake --write` on the committed fixture package proves the replay path.
- gdUnit4 pitfalls to encode in every worker issue: no Variant-inferred `:=`, judge tool-script output
  not exit code (134 at teardown), re-import after adding a `class_name`.

---

## 5. Sibling-game reuse (ruling 7)

Stack survey (verified from each repo's `project.godot`/`addons/`): **Petalkeep** 4.7, Pandora, State
Charts, Dialogue Manager, QuestSystem, GUT, 2D+3D, already has `WorldEditor`/`ZoneManager` autoloads;
**DayInTheLife** 4.7, Pandora, State Charts, Dialogue Manager, QuestSystem, gdUnit4, tilemaps;
**Site K** 4.7 GL Compat, Pandora, State Charts, Dialogue Manager, QuestSystem, gdUnit4, `GameFlow`/`SaveGame`
autoloads named like Soul Meter's; **Hexgame** 4.7, Pandora, LimboAI, hex map addon, no tilemaps;
**SquadTactics** 4.7 GL Compat, Pandora, LimboAI, gdUnit4; **Idyllicdram** is a vault + prototype, no
`project.godot` at root.

| Universal (core addon) | Game-specific (adapter) |
|---|---|
| bootstrap, activation, InputMap action, shell/dock, camera, theme hook | env flag name, theme, chart hook (`set_editor_open`) |
| command bus, undo, log, replay, CLI, PR flow | command vocabularies beyond scene/package |
| package + kind registry, transactional writer, attributed errors | the kinds themselves and their validators |
| `.tscn` text patcher (Godot-universal), scene model, placeable palette, schema-agnostic inspector | placeable list, editable roots, **all cell-space assumptions** via the grid adapter (IsoGrid / hex / 3D) |
| Pandora text-canon reader + drift stage (games with Pandora: all six) | canon categories |
| sandbox owner (needs a `capture/restore` pair from the game) | the game's `SaveGame` seam |
| dialogue wiring (Dialogue Manager games: Petalkeep, DayInTheLife, Site K) | NPC route tables |
| — | combat lab, ledgers/timeline, accord overlay, spawn director |

`WeftluminGameAdapter` (interface, `core/adapter.gd`):

```gdscript
func env_flag() -> String                               # "SOUL_METER_WEFTLUMIN"
func theme() -> Theme
func set_editor_open(open: bool) -> void                # chart/pause integration
func gameplay_scene_root() -> Node                      # null when not in a gameplay scene
func editable_roots(scene_root: Node) -> Array[Node]
func grid() -> WeftluminGridAdapter                         # world<->cell, walkability, bounds (IsoGrid here)
func placeables() -> Array[WeftluminPlaceable]
func kinds() -> Array[WeftluminKind]
func panels() -> Array[PackedScene]
func capture_runtime_state() -> Dictionary; func restore_runtime_state(s: Dictionary) -> bool
func production_owner_live() -> bool                    # battle/balloon live
func pickers() -> Dictionary                            # semantic pickers: flags, factions, locations, items, units, dialogue
func canon_root() -> String                             # "res://canon"
func recorder() -> Node                                 # optional event sink
```

**Distribution:** ruling 6 is satisfied from day one — the core is a **project-owned addon in this
repo** (`addons/weftlumin/`, ignored by `verify_addon_pins.sh` like `soul_meter_tools`). When a
second game adopts it, the addon gets its own repo and is **vendored** (not submoduled) into each game
with a documented pin in that game's `DEPENDENCIES.md` — the same discipline as every other addon here.
Godot 4.7 is the floor. The core's own tests are gdUnit4; a host without gdUnit4 (Petalkeep uses GUT)
runs them from a CI-only harness rather than porting them.

---

## 6. Dependencies and sequencing

| Weftlumin work | Blocked by | Why |
|---|---|---|
| tile/terrain painting, hostile placeable, `FieldMap.accord_at`, combat panel | **#281** (F1 same-map combat) | `FieldMap`, `Hostile`, `Terrain` custom data, `Battle.start_session` are F1 deliverables; "nothing else touches `GameFlow`/combat until F1 and F3 merge" (ship plan) |
| spawn director budget, `max_alive` defaults | **#282** (100-mob floor) | IDLE hostiles must be free |
| character `stats` schema, encounter archetype columns | **#283** (DRAMGID) | schema 8, Pandora columns |
| new interactable placeables | #284 | palette is registry-driven, so additive |
| Dom content pass (ruling 10) | **#305** (Dom art batch) | both write `world/starting_town.tscn` |
| shell chart integration (E2.3) | **F1 + F3 merge** | `GameFlow` freeze covers both |
| canon migration of stat-bearing categories (Combatants, Encounters, recruits) | **#283** | migrating them first would bake the obsolete six-stat shape |
| everything else in E1 (§7) | nothing | touches no `GameFlow`/combat/stats files |

**Capacity (reframed after owner ruling 14).** Codex is a CLI with no hour cap, so "booked" was the
wrong word. The ship plan (`docs/ship-plan-2026-10.md`) lists Codex ship items for every week to the
Sep 21 content lock and Oct 2 gold; the two real constraints on Weftlumin are (a) the **file freeze** —
nothing but F1/F3 touches `GameFlow`, combat or stats until they merge — and (b) **review bandwidth**,
since every Weftlumin PR still gets a Claude/owner review. Every E0/E1 row touches none of the frozen
files, so Codex runs them **now, in parallel with ship work**; E2–E7 start when F1 + F3 merge. The
post-launch free-update content (locations 9–12, side quests 5–10) plus the Dom polish pass is the
editor's first real workload.

## 7. Wave plan and worker assignment

Every row becomes a GitHub issue using the fleet template (`docs/fleet-roadmap.md:121-132`); one
worker label each; cheap-worker cap ~4 files + tests / ≤ 1200 lines; workers run the suite before
handoff; workers never touch labels/milestones. Sizes S/M/L/XL as in the fleet roadmap.

### E0 — Architecture (Claude, now)
| Key | Task | Worker | Size |
|---|---|---|---|
| E0.1 | This note; owner rulings §8; index issue superseding #214 | Claude | S |
| E0.2 | Schemas frozen: `weftlumin.command.v1`, package manifest, `weftlumin.location.v1`, `weftlumin.character.v1`, `weftlumin.spawn_table.v1`, `weftlumin.bake.v1` (Appendix) | Claude | S |
| E0.3 | `WeftluminGameAdapter` + `WeftluminKind` + `WeftluminPanel` interface files (stubs with docs, no behaviour) | Claude | S |

### E1 — Foundations that touch no frozen file (pre-gold, cheap workers + Claude review)
Cheap-worker cap (~4 files + tests, ≤ 1200 lines) applies to every non-Codex row; rows are sized to it.
| Key | Task | Worker | Size |
|---|---|---|---|
| E1.1 | Fix `bake_layout_overrides.gd`: body to `_initialize()`, report-only default + `--write/--force` (copy `bake_campaign.gd`), regression test with a script-bearing fixture proving exports survive | Jules | S |
| E1.2a | `core/tscn_document.gd` parser + serialiser; repo-wide byte-identical round-trip test | Kimi (pre-gold) / Codex (escalation) | M |
| E1.2b | Patcher ops (`set_property`, `add_node`, `remove_node`, `add_ext_resource`, `set_packed_bytes`) + type-aware value encoder + per-op fixtures | Kimi / Codex | M |
| E1.2c | Dom survival + bake-idempotence tests (`TavernDoor/Facade.visible == false` after a bake; bake twice = identical) | Qwen | S |
| E1.3a | Record both spec amendments in `docs/godot-architecture.md` (one-way data rule; Tooling as debug-only sixth layer); `canon/` reader in `tools/seed_pandora.gd` upserting by stable id; first category **Factions** (stat-free) | Kimi | M |
| E1.3b | `CANON-SEED` drift stage in `scripts/check_generated_data.sh` + CI step | Jules | S |
| E1.4a–f | Migrate remaining **stat-free** seed tables to `canon/` JSON, **six separate issues** (one per category): Elements/Classes/Peoples; Items; Spells/Effects; NPC roster + placements + routines; Locations (also emits `location_index.json`, no registry change yet); Lore | Qwen | S ×6 |
| E1.4g | Migrate **Combatants + Encounters** (stat-bearing) — **blocked by #283** | Qwen | S |
| E1.5 | Kind registry refactor of the campaign loaders (`WeftluminKind` for quests + encounters; per-kind register/clear; manifest `schema`/`kinds`/`provenance`; lossless quest JSON) — Codex row, cheap-worker cap n/a | Codex (post-gold) | M |
| E1.6 | **Spawn math design note + pure functions**: weight normalisation with the `empty` sentinel, thinning/danger scaling, respawn cadence vs Zhavar rung, pack-size curves, `max_alive` defaults; deterministic tests over `roll()`; Claude review = design freeze for E4 | DeepSeek | M |
| E1.7 | **Harmonic Accord variation design note + pure function**: bounded `variation(day_index, phase, zhavar_rung, weather_element, patron_element, world_seed)`; sanity sweep vs the fizzle table; saturation-lint thresholds; tests; Claude review = design freeze for E6 | DeepSeek | M |
| E1.8 | Rename `integrity` → `harmonic_accord` across code/`.tres`/docs/templates with a one-wave context-key alias; tests | Kimi | S |
| E1.9 | Test-migration plan for the 13 files referencing the seven globals + parametrised inert-suite skeleton | Kimi | S |
| E1.10 | `WorldClock.phase_count: int` + `day_index()` and `GameState.world_seed` as additive save keys (no schema bump; coordination note with #283) | Kimi | S |

### E2 — Shell (Codex, after F1 and F3 merge)
| Key | Task | Worker | Size |
|---|---|---|---|
| E2.1 | Addon skeleton, `project.godot` autoload `WeftluminBootstrap`, activation + `weftlumin_toggle` action, export exclusions, `test_export_readiness` update, inert suite on the real path | Codex | M |
| E2.2 | `core/command_bus.gd`: two op classes, `UndoRedo`, JSONL log, replay, provenance; recorder interop (`dev_console_command`, `combat_lab_battle_started`, `weftlumin_command`) | Codex | M |
| E2.3 | Shell dock, free camera, input capture, theme hook, `Editor*` DS variations, panel contract; `GameFlow` `editor_open` expression property + guards; `Battle.abandon()` — **blocked by F1 + F3** | Codex | L |
| E2.4 | `core/sandbox.gd` single owner (RNG folded in, production-owner predicate); remove the two private copies | Codex | M |
| E2.5a | Re-host F1/F3/F4/F5/F6 models as panels behind the panel contract | Codex | M |
| E2.5b | Delete the six autoloads; migrate the 13 test files (E1.9 plan); collapse the six tool docs into `docs/weftlumin.md` | Kimi | M |

### E3 — Scene authoring (Codex, after E1.2 + #281 step 2)
| Key | Task | Worker | Size |
|---|---|---|---|
| E3.1a | `core/scene_model.gd`: editable predicate, pick, snap + cell snap, multi-select, node → command mapping; layout-tool port | Codex | M |
| E3.1b | Registry-driven placeable palette + schema-agnostic inspector with adapter pickers (flags, factions, locations, spawn ids, dialogue file/title, item and unit ids) | Codex | M |
| E3.2 | Blocking + `Terrain` painters (`terrain_tiles.tres` with `cover`/`elevation`), live `IsoGrid` rebuild, walkability overlay, `normalize_blocking_scale` command — **blocked by #281 step 2** | Codex | M |
| E3.3a | Location metadata panel (`weftlumin.location.v1`) + generated `world/locations/*.tres` from canon JSON | Codex | M |
| E3.3b | Data-driven registries: `LocationRegistry`/`WorldMapRegistry`/`FastTravelRegistry`/`BuildingTransitionRegistry` read `location_index.json`; `register_runtime()`; `GameFlow` queries the registry dynamically (**blocked by F1 + F3**); one registry per PR, journey tests green | Codex | M |
| E3.4 | `new_scene` command rendering into package scratch (`user://`) + field/interior templates + live registration + travel | Codex | M |
| E3.5 | Scene bake through the patcher; Dom bake fixture; contract tests as bake validators | Codex | M |

### E4 — Spawn system (Codex implementing E1.6's frozen design; after #281/#282)
| Key | Task | Worker | Size |
|---|---|---|---|
| E4.1 | `globals/world/spawn_director.gd`: slot state, deterministic roll from E1.6, `Hostile` instantiation with day-stamped `group_id`, per-scene cap, partial-clear semantics, `spawn_state` surface in `SaveGame` | Codex | L |
| E4.2 | `spawn_tables` kind (invariants) + spawn panel + `SpawnSlot` markers + `[debug] respawn/clear` verbs | Codex | M |

### E5 — Characters and encounters (after #283)
| Key | Task | Worker | Size |
|---|---|---|---|
| E5.1 | `characters` kind (open kind/schema registries; opaque `stats`) + character panel + portrait/sprite pickers; generator emits roster/placements from canon | Codex | L |
| E5.2 | `encounters` kind post-F1 (no grid/weather; set-piece cells) + combat panel on `Battle.start_session` | Codex | M |

### E6 — Harmonic Accord surfaces (Codex implementing E1.7's frozen design; after #281)
| Key | Task | Worker | Size |
|---|---|---|---|
| E6.1 | `AccordZone` placeable (or Terrain `accord_delta`, per ruling) + `FieldMap.accord_at()` + per-action accord in `CombatController` with the frozen forecast context (forecast == resolution test) | Codex | M |
| E6.2 | Accord/weather/charge heatmap overlay panel + saturation lint in the bake | Codex | S |

### E7 — CLI and PR flow
| Key | Task | Worker | Size |
|---|---|---|---|
| E7.1 | `weftlumin.gd` CLI (`validate/apply/bake/regen/lint/pr`), GDScript `[if /]` lint port, POT-delta report, kind → test-glob map, `refused_overlap` reporting | Codex | M |
| E7.2 | CI: `weftlumin lint` + canon drift + nightly replay job; PR-overlap pre-check | Jules | S |
| E7.3 | Agent runbook: how Claude/Codex author a package headlessly (`docs/weftlumin-agents.md`) | Claude | S |

### E8 — First content (owner + agents, after #305)
Dom polish pass, then side quests, then encounters — using Weftlumin, producing PRs.

**Counts:** 44 rows — Codex 20 (E1.5 now; E2–E7 after the F1 + F3 freeze lifts) · Kimi 7 · Qwen 8 · Jules 3 · DeepSeek 2 · Claude 4. E0.1 and
E0.2 are delivered by this note and the index issue; the other 42 rows are filed as issues. All 24
non-Codex rows can run pre-gold.

**Filed 2026-09-04** under index issue #311 (supersedes #214): E0.3 #312 · E1.1 #313 · E1.2a #314 · E1.2b #315 · E1.2c #316 · E1.3a #317 · E1.3b #318 · E1.4a #319 · E1.4b #320 · E1.4c #321 · E1.4d #322 · E1.4e #323 · E1.4f #324 · E1.4g #325 · E1.5 #326 · E1.6 #327 · E1.7 #328 · E1.8 #329 · E1.9 #330 · E1.10 #331 · E2.1 #332 · E2.2 #333 · E2.3 #334 · E2.4 #335 · E2.5a #336 · E2.5b #337 · E3.1a #338 · E3.1b #339 · E3.2 #340 · E3.3a #341 · E3.3b #342 · E3.4 #343 · E3.5 #344 · E4.1 #345 · E4.2 #346 · E5.1 #347 · E5.2 #348 · E6.1 #349 · E6.2 #350 · E7.1 #351 · E7.2 #352 · E7.3 #353.

---

## 8. Owner rulings

Resolved 2026-09-04 (evening): **name = Weftlumin**; **F12 / `weftlumin_toggle`**; **canon text feeds
Pandora** (one-way-rule amendment ratified); **respawn policy by area class** (§4.10 — wilderness
respawns, towns and quest areas `none` or `limited`); **capacity** (Codex continues on E0.3 + E1 now;
E2–E7 wait only for the F1 + F3 freeze to lift).

Still open:

1. **Tooling as a debug-only sixth layer** above Flow — spec wording lands with the data-rule
   amendment in E1.3a; confirm.
2. **PlaytestRecorder stays outside the shell** (recommended: yes; it is not debug-gated and ships in
   playtest builds).
3. **Editor chrome DS status:** developer tooling, token-bound, exempt from composition rules, with a
   small `Editor*` variation family (recommended).
4. **Terrain data layer:** third `Terrain` `TileMapLayer` with project-owned tileset (recommended;
   must be the same choice the #281 implementer makes in step 2).
5. **`AccordZone` as the one new placeable** for spatial accord/element overrides (recommended for v2),
   or per-cell `accord_delta` Terrain data instead.
6. **Re-author Dom's `Blocking` at scale 1** via a reviewed one-shot bake command (recommended).
7. **Location JSON is canon; `world/locations/*.tres` become generated** (recommended).
8. **God mode:** fold into the console once `debug_force_complete()` takes a `cause` (recommended), or
   keep as an untagged surface.
9. **Milestone:** create "Weftlumin — in-game editor" for E2–E7 (owner action; none exists).
10. **`limited` respawn bounds** (§4.10) — DeepSeek proposes in E1.6, owner confirms.

## 9. Risks

- **Patcher fidelity.** A text patcher that mis-parses one `.tscn` corrupts canon. Mitigation: repo-wide
  byte-identical round-trip test is a merge gate; bake is report-only by default; PR review.
- **F1 slip.** Scene/combat panels wait on #281; E1/E2 do not. If F1 slips past gold, E3 slips with it.
- **Registry migration blast radius.** Making four registries data-driven touches travel; do it with the
  existing `test_starting_town`/`test_field_room`/journey tests green, one registry per PR.
- **Schema 8 collision** between #283 and spawn persistence; coordinate in E1.10 (additive key fallback).
- **Dom `.tscn` contention** with #305; the PR overlap pre-check refuses to open a colliding PR.
- **Localisation debt** grows as authored strings land in exports; the bake reports POT deltas but POT
  regeneration remains an editor-machine chore.
- **Scope gravity.** Weftlumin is the #1 speed feature *after* the tool exists; before that it competes with
  the ship. The wave plan keeps E1 cheap and everything owner-visible behind E2.

---

## Appendix A — Package manifest

```json
{ "schema": "weftlumin.package.v1", "id": "dom-market-pass", "hub": "dom", "title": "Dom market pass",
  "kinds": ["locations", "characters", "spawn_tables", "quests", "scenes"],
  "base_commit": "b6fadc88", "created": "2026-09-04T22:00:00Z",
  "provenance": {"source": "ui", "actor": "owner", "weftlumin_version": "0.1.0"} }
```

## Appendix B — Bake report

```json
{ "schema": "weftlumin.bake.v1", "package": "dom-market-pass", "mode": "report|write",
  "planned": [{"kind": "scenes", "path": "res://world/starting_town.tscn", "ops": 14}],
  "written": [], "regenerated": ["data.pandora", "data/generated/encounters.json"],
  "lint": {"errors": 0, "warnings": 2, "pot_delta": ["The bell-house is shut at night."]},
  "refused_overlap": [], "errors": [], "summary": "14 scene ops, 2 locations, 1 spawn table" }
```

## Appendix C — Minimum viable field scene (template contents)

Root `Node2D` (y-sort; `FieldMap` script after #281) → `TerrainBackdrop` (Sprite2D, z −15) →
`IsometricGround` (TileMapLayer, hidden, `isometric_blockout.gd`, 64×32 DIAMOND_DOWN) → `Blocking`
(TileMapLayer, `blocking_tiles.tres`, `blocking_layer.gd`, scale 1) → `Terrain` (TileMapLayer,
`terrain_tiles.tres`, custom data `cover`/`elevation`) → `Walls` (StaticBody2D) → `Player` →
`PartyFollowers` → `SpawnDefault` (+ `Spawn<PascalCase>` per alias) → `FieldHUD` →
`<Id>Dressing/{GroundDetails, SoftDetails, SolidProps}` → `CombatOverlay` (after #281) → actors.
Outside the scene: `canon/<hub>/locations/<id>.json` → generated `world/locations/<id>.tres` + index.
