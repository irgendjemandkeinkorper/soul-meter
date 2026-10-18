# Weftlumin in-game editor — debug tools

Weftlumin is the debug-build-only in-game editor shell (`addons/weftlumin`, architecture in
`docs/architecture-in-game-editor.md`). Since E2.5b (#337) it is the **only** host for the five
former debug tools: the state console, the consequence timeline, Combat Lab, Dialogue Lab and the
quest editor. This page replaces the five per-tool documents (`dev-console.md`,
`consequence-timeline.md`, `combat-lab.md`, `dialogue-lab.md`, `quest-editor.md`); their rules are
carried over below, restated for the panel host.

## Status

| Tool | Panel (dock slot) | Model (`weftlumin/panels/models/`) | Retired legacy surface |
| --- | --- | --- | --- |
| State console | `console_panel.gd` (Console) | `dev_console.gd` | `DevConsole` autoload, F1 overlay, `SOUL_METER_DEV_CONSOLE` |
| Consequence timeline | `timeline_panel.gd` (Consequence timeline) | `consequence_timeline.gd` | `ConsequenceTimeline` autoload, F4 overlay, `SOUL_METER_CONSEQUENCE_TIMELINE` |
| Combat Lab | `combat_lab_panel.gd` (Combat lab) | `combat_lab.gd` | `CombatLab` autoload, F3 overlay, `SOUL_METER_COMBAT_LAB` |
| Dialogue Lab | `dialogue_panel.gd` (Dialogue lab) | `dialogue_lab.gd` | `DialogueLab` autoload, F5 overlay, `SOUL_METER_DIALOGUE_LAB` |
| Quest editor | `quest_panel.gd` (Quest editor) | `quest_editor.gd` | `QuestEditor` autoload, F6 overlay, `SOUL_METER_QUEST_EDITOR` |
| Scene layout | `scene_panel.gd` (Scene tree, Palette, Inspector) | `addons/weftlumin/core/scene_model.gd` | Former F10 overlay and autoload retired in #470 |
| Location metadata | `location_panel.gd` (Locations) | `location_metadata.gd` | New in E3.3a (#341); no legacy surface |
| Characters | `character_panel.gd` (Characters) | `character_roster.gd` | New in E5.1 (#347); no legacy surface |
| Spawn tables | `spawn_panel.gd` (Spawns) | `spawn_tables_editor.gd` | New in E4.2 (#346); no legacy surface |
| Accord overlay | `accord_overlay.gd` (Accord overlay) | none (read-only) | New in E6.2 (#350); no legacy surface |

Scene layout now runs through `WeftluminSceneModel` in the shell. F10 and
`SOUL_METER_LAYOUT` no longer activate an editor; use the enablement below.

## Scene layout

Click an editable object in the centre viewport to select it. Ctrl-click or Shift-click toggles
membership; clicking an existing member keeps the group and makes it primary. Dragging moves the
group rigidly, with one undo step on release, including release over a dock. The primary chooses
the snap: **8 px**, **Cell** through the scene's `IsoGrid`, or **No snap**. Alt (or Shift while
dragging) temporarily bypasses snapping. A click without movement does not snap or create history.
Empty space clears the selection. The existing free camera still uses middle-drag and wheel zoom.
Selection outlines use the model's bounds, follow pan/zoom, and clip to the centre viewport.

The Scene tree and viewport share one selection. The existing Inspector slot edits the primary's
position, scale, rotation, skew, sprite flips, grayscale, and solid footprint. Arrow keys nudge;
Delete, Ctrl+D, Ctrl+Z, Ctrl+Shift+Z/Ctrl+Y delete, duplicate, undo and redo. Text fields retain native
editing shortcuts. Ctrl+S (or Save scratch) commits pending numeric input and saves the scratch
document. Closing also commits pending input and the current drag.

The existing Palette slot offers the former asset categories and fuzzy search. Select a texture,
choose a dressing layer, then click to place; Shift repeats and Alt bypasses snap. Escape/right-click
cancels placement. Ctrl+G saves the selected group under the pattern name; select a saved pattern
and click to stamp it as one undo step. Patterns retain their relative spacing across layers.
The adapter still decides editable roots, and the model enforces scene/instance ownership.

### Actors palette and export inspector (E3.1b, #339)

The Palette slot's **Actors** tab lists `adapter.placeables()` (`WeftluminPlaceable`: scene or
engine class, display, group, default exports), filtered by group and the same fuzzy search. The
Soul Meter registry is ruling 8's existing actor types: NPC, Hostile, BuildingDoor, TravelExit,
SMInteractable, Chest, Pickup, InteractiveSwitch, a `Marker2D` spawn marker and a `Marker2D`
spawn-slot anchor (#346), plus the one new type, `AccordZone` (owner ruling 2026-10-11, #349: a
Harmonic Accord data volume). ZhavarTelegraph
is not offered: it is a positionless `Node` overlay and the scene model edits `Node2D`s. Choose an
entry, then click: the instance lands under the scene root at the nearest open walkable cell
(`GridPlacement.open_cell_center_near`; Alt or snap off keeps the cursor; Shift repeats), is
selected, and is one undo step. Placed and existing placeable actors are selectable.

Below the transform fields the Inspector lists the primary's exported script properties from
`get_property_list()` (`PROPERTY_USAGE_SCRIPT_VARIABLE` + editor-visible), with `@export_group`
headings and an editor per type and hint: check box, spin box (`@export_range` bounds), enum
option, line edit, multiline text, `@export_file` choices, vector/rect spin boxes, colour button,
and a `var_to_str` literal box for arrays and dictionaries. The adapter's `pickers()` table
(`weftlumin/panels/pickers.gd`, export-excluded) claims properties by name and adds a Pick menu
plus live validation: flags (grammar-checked through `quest_audit.flag_grammar_violations`),
factions, locations, spawn ids (of the destination location), dialogue file and title, item ids
and unit ids. A refused value is shown under its field and changes nothing.

Every placement and export edit is a `scene` command (`add_node` with an `instance` spec;
`set_property` with `export` + `value_text`), replayable from the command log. They are **not**
part of the layout scratch document: Save scratch and recovery carry dressing only, so placed
actors and export edits last for the live scene session until the scene bake (E3.5, below)
consumes the log.

History belongs to the live scene and survives closing/reopening the shell. Scratch changes are
checkpointed through `LayoutRecovery`, including undo/redo, and restored on the next hosted scene
session. Files retain the existing `user://layout_overrides/` and pattern-library formats. Runtime
gameplay does not apply scratch documents while the editor is disabled. Scene exit closes the
shell and releases detached history nodes. The shared replay/bake primitive remains
`LayoutOverrides.apply_to_scene()`.

The pinned layout behaviors now live in `test/integration/test_scene_pick_{controls,input,patterns,lifecycle,inert}.gd`
and `test/unit/test_weftlumin_scene_model.gd`; layout schema, pattern-format, recovery and bake suites
remain in place. The former floating panel's bounds check is replaced by an existing-dock containment
check; shell activation/pause remains covered by `test_weftlumin_shell.gd` and `test_weftlumin_inert.gd`.

### Rendered pick/drag evidence

Rendered capture, under Xvfb or a display (omit `SOUL_METER_HEADLESS`):

```bash
SOUL_METER_SCENE_PICK_CAPTURE_DIR=/tmp/scene-pick-capture \
SOUL_METER_TEST_DATA_DIR="$(mktemp -d)" \
GODOT_BIN="$HOME/.local/bin/godot" \
bash scripts/test.sh -a test/integration/test_scene_pick_input.gd
```

`test_rendered_pick_drag_capture` pushes fresh press/release events, picks and drags an object,
checks the outline pixels at each step and its final position, and writes `01-picked.png`,
`02-dragging.png` (mid-drag, before release) and `03-dropped.png`; the #470 evidence is in
`docs/qa/viewport-pick-470-2026-10-10/`. Without
the capture variable it returns immediately; requesting a capture under headless rendering fails.
Headless tests do not establish visual correctness.

### Pattern library (E3.1c, #370)

The Palette slot's Dressing tab hosts the pattern browser (`addons/weftlumin/shell/patterns/pattern_browser.gd`)
over `WeftluminPatternLibrary` (`addons/weftlumin/core/pattern_library.gd`). The format is unchanged:
`globals/layout_patterns.gd` schema 1 captures and stamps, with world-space offsets from the selection
anchor and a name resolver that receives the names already reserved by the same stamp.

Select props, type a name and press Save pattern or Ctrl+G. Choose a row to arm it as a brush and fill
the name field; click to stamp (Shift repeats, Alt bypasses snap). Stamped props stay selected, so they
can be rearranged and saved again under the same name. Rename uses the name field. Delete removes the
user file. **Promote to repo** moves a user pattern byte for byte from `user://layout_patterns/` to
`res://weftlumin/patterns/`, replacing a repo pattern with the same id.

Repo rows are marked `repo, read-only`. Rename, Delete and Promote are disabled for them, and the model
refuses those operations. A repo pattern can still be armed. Saving under its name writes a user copy
that shadows it in the list; promoting that copy updates the repo pattern.

Each save, stamp, rename, delete and promotion is one undo step on the scene history. Library writes are
`pattern` document commands (`save`, `rename`, `delete`, `promote`). Their `pre_state` is the touched
files' prior content, so undo restores those files exactly. Rename changes only the top-level `id` and
`name` values. Integers stay integers because the library does not re-serialize the document.

Rendered capture: `SOUL_METER_PATTERN_CAPTURE_DIR=<dir>` with
`test/integration/test_scene_pick_pattern_browser.gd` under Xvfb. The #370 evidence is in
`docs/qa/weftlumin-patterns-370-2026-10-11/`.

### Data-layer painters (E3.2, #340)

The Scene tree slot's **Paint data layers** toggle routes viewport clicks to the painters
(`addons/weftlumin/shell/painter/`) instead of selection. Choose a layer, a brush (Cell, Rect, Line,
Fill) and a value; press, drag and release paints one stroke, which is one `scene/paint_cells`
command and one undo step (Ctrl+Z / Ctrl+Shift+Z). Right-click or Escape cancels a stroke.

- **Blocking** paints in its own cell space (`local_to_map(to_local(world))`) and persists as its
  `tile_map_data`. After every stroke, undo and redo, `IsoGrid.build()` re-runs on the player's own
  grid (the `ClickMoveController` instance `FieldMap.iso_grid()` returns) and on a placement grid,
  so walkability changes live.
- **Terrain** matches #281 step 2: the `CombatTerrainLayer` whose cells
  `GridBattlefieldModel._read_authored_terrain()` reads as ground cells, persisted as its exported
  `cover_cells` / `elevation_one_cells` / `elevation_two_cells`. It paints in the ground's lattice and
  keeps those lists in step with its tiles. No separate `terrain_tiles.tres` exists; the layer's
  tile set is `world/nav/combat_terrain_tiles.tres`.
- **Overlay.** The walkability overlay names the grid and clearance it shows: *player path,
  clearance 1 cell* (`ClickMoveController.STATIC_CLEARANCE_CELLS`) or *placement, clearance 0 cells*
  (`GridPlacement.PLACEMENT_CLEARANCE_CELLS`).
- **Bake.** `WeftluminTileBake.bake(text, log_entries)` replays a log's effective `paint_cells`
  stream against the `.tscn` text, verifying each recorded `pre_state` (cells and layer transform)
  first, and writes through `TscnDocument.set_packed_bytes()` / `set_property()`. Painting is live
  only until baked; the scene scratch file does not carry tiles.
- **`normalize_blocking_scale`** exists only on the bake bus, never on a live scene. It re-authors a
  scaled `Blocking` at scale 1 in its ground's lattice using the same five sample points as
  `IsoGrid`, so placement walkability is identical; footprint cells just past the ground lattice are
  kept (they still collide) and add the player's one-cell clearance on the lattice's edge row. Dom's
  `Blocking` is **not** re-authored (ruling 9); `test_weftlumin_tile_bake.gd` dry-runs it in memory.

Suites: `test/unit/test_weftlumin_{brushes,tile_painter,tile_bake}.gd` and
`test/integration/test_weftlumin_painters.gd`. With `SOUL_METER_PAINTER_CAPTURE_DIR` set (under Xvfb or
a display), the integration suite writes the stroke preview and both overlays; the #340 evidence is
in `docs/qa/weftlumin-painters-340-2026-10-11/`.

### Scene bake (E3.5, #344)

`WeftluminBake.bake(entries, target_root, write, force)` (`addons/weftlumin/core/bake.gd`) turns a
command log's effective `scene` stream into surgical `.tscn` text patches and returns a
`weftlumin.bake.v1` report. Soul Meter reaches it through the `scenes` kind
(`weftlumin/kinds/scenes.gd`, `WeftluminScenesKind`), whose documents are a package's
`commands.jsonl` entries (`load_log()`, `validate()`).

- **How.** Each scene is opened as text (`TscnDocument`) and as a fresh out-of-tree instance. A
  scene model over that instance replays every layout, placement, export and removal command
  (so `pre_state` drift and ownership refusals match the live editor), and the bake writes into the
  text only the stored properties each command changed. Tile commands go through
  `WeftluminTileBake` on the same document. New resources are declared once with their `uid://`;
  a resized collision rectangle or the layout grayscale material becomes a `<Type>_weftlumin<N>`
  sub-resource. Nothing is packed, so untouched lines stay byte-identical and the format stays 3.
- **Report only by default.** Without `write` nothing is written (the load check uses one
  transient copy under `user://` and deletes it). With `write`, each changed scene lands under
  `target_root` (`res://` patches in place). A target that holds neither the source scene nor the
  bake's output is refused unless `force`; `force` without `write` is an error. Any error in any
  scene writes nothing.
- **Validators.** Before writing, the baked text must load and instantiate, every section the log
  did not touch must be byte-identical (declarations and `uid://` references included), and every
  node the bake wrote must reload equal to the replayed edit. The `scenes` kind adds the scene
  contracts: canon spawn markers, building-transition and NPC-placement anchors still resolve; Dom
  keeps the `test_starting_town.gd` invariants; and Dom's `Blocking` is never re-authored
  (ruling 9) — a log with `normalize_blocking_scale` on Dom is refused, and its transform, tile set
  and script lines must stay unchanged.
- **Limits.** A layout edit of a layer painted earlier in the same log is refused (bake them as
  separate logs). Scripted nodes outside an instanced scene and resources with scripts cannot be
  written. There is no in-game bake button yet; the headless CLI and PR flow are below (E7.1).

The Dom fixture log is `test/fixtures/weftlumin/dom_scene_bake/commands.jsonl` (14 effective
commands of every class above plus an undone nudge); `test/integration/test_weftlumin_scene_bake.gd`
covers report and write modes, idempotence, live-session equivalence, Dom survival and the
refusals, and records the fixture again with `SOUL_METER_SCENE_BAKE_RECORD_FIXTURE=1`. With
`SOUL_METER_SCENE_BAKE_CAPTURE_DIR` set (under Xvfb or a display) it renders Dom before and after
the fixture bake; the #344 evidence is in `docs/qa/weftlumin-bake-344-2026-10-11/`.

### Accord overlay and saturation lint (E6.2, #350)

The **Accord overlay** bottom tab draws hidden per-area state over the centre viewport once
**Show overlay** is ticked (off by default; it then draws whichever tab is showing). Layers:
**Accord heatmap** (per ground cell, `clamp(base_adjusted + zone_delta, 0, 100)` between the DS
stops violet 0 / gild 50 / constant-green 100, with each `AccordZone`'s cells outlined and its
anchor labelled with its delta and elemental default), **Weather element** (badge: the live
battle's `Weather` element, else the location's `weather_default`), **Tile charge** (the live
controller's `TileState`s with charge or Hush), and **Walkability** (the player's own
`FieldMap.iso_grid()`, clearance 1 cell). Hovering a cell shows its accord, zone delta,
elemental default, charge and walkability.

- **Read-only.** It reads `FieldMap` and the live `CombatController` only — it iterates the
  controller's existing `tile_states` and never calls `tile_state_at()`, which creates tiles —
  and changes no accord, charge or weather number. In a battle the base is the controller's
  `agreement_integrity` (what combat samples); otherwise `FieldMap.accord_base()`.
- **No variation.** E1.7's variation is held at 0.0 in live combat, so the heatmap does not
  preview it; the caption says *variation not applied (E1.7 held at 0.0)*.
- **Saturation lint.** `WeftluminScenesKind.accord_saturation` is a `scenes` bake validator
  (§4.11): it warns when `base_adjusted + max(zone_delta) + 10 > 100` or
  `base_adjusted + min(zone_delta) − 10 < 0` over the baked field's ground cells
  (`AccordMath.saturation_warnings()`). Its entries carry `"severity": "warning"`, which
  `WeftluminBake` routes to the report's `warnings` and `lint.warnings` instead of `errors`, so a
  warning never blocks a write. The panel shows the same warnings for the live field.
  Every location authored at 95 with no thinning (Dom and the interiors) warns high today
  (95 + 0 + 10 > 100), because the ±10 band is provisional.

Suites: `test/unit/test_weftlumin_accord_saturation.gd`,
`test/integration/test_weftlumin_accord_overlay.gd`. With `SOUL_METER_ACCORD_OVERLAY_CAPTURE_DIR`
set (under Xvfb or a display) the integration suite renders the heatmap over the Wilds with two
zones, a charged tile and a live battle; the #350 evidence is in
`docs/qa/accord-heatmap-350-2026-10-12/`.

### New scene (E3.4, #343)

`new_scene {hub, id, size_cells, backdrop, template, display_name}` creates a playable location
without touching `res://`. It is a `scene`-kind document op, `WeftluminSceneCreator`
(`addons/weftlumin/core/scene_creator.gd`), and the scene model registers it on its bus. Build the
command with `WeftluminSceneCreator.command(params, package, errors)`.

- **What it writes.** It renders `addons/weftlumin/templates/field_scene.tscn.tmpl` or
  `interior_scene.tscn.tmpl` (`WeftluminSceneTemplate`) to
  `user://weftlumin/<package>/scenes/<id>.tscn`. It writes the package's
  `locations/<id>.json` and creates or extends `campaign.json` with the hub and the `scenes` and
  `locations` kinds. Then it registers the location live: `LocationRegistry.register_runtime()`
  with the scratch scene path. Undo restores the three files and unregisters the location.
- **Travelling is a separate step.** `WeftluminSceneCreator.travel_to(id)` goes through
  `GameFlow.travel()`. A replayed log must never travel.
- **The field template** mirrors `world/test_room.tscn`:
  - a `FieldMap` child, backdrop, and hidden `IsometricGround`/`Blocking`/`Terrain` layers;
  - walls, `Player`, `PartyFollowers`, `SpawnDefault` and `FieldHUD`;
  - `<Id>Dressing/{GroundDetails,SoftDetails,SolidProps}`.

  `size_cells` sets the grid. The room scales from test_room's 70 cells to 2000×1200 px.
  `CombatOverlay` is omitted, as in every current scene.
- **The interior template** instances `world/interiors/building_interior.tscn`, as `bell_loft`
  does, and carries the dressing floor every concrete interior must meet
  (`test_building_interiors.gd`): one `AmbientPropMotion` hanging lantern under `SoftDetails` and
  one `StaticBody2D` wall bench under `SolidProps`; a package adds the rest. Canon
  `no_combat_zone` is `true`, and `register_runtime(definition, true)` carries that flag to the
  unbaked scene.
- **Location document.**
  - It names the baked paths: `res://world/<id>.tscn` (interiors under `world/interiors/`) and the
    matching `world/locations/…/<id>.tres`.
  - Other values are `LocationDefinition` defaults, for the owner to set in the location panel.
  - The locations kind accepts its not-yet-existing `scene_path` while the package holds the
    rendered scene.
- **Bake.** `WeftluminBake` reads a `new_scene` entry as the start of that scene's group. It
  renders the template again from the logged params, so the bake does not depend on the scratch
  file and works in a fresh worktree. It replays the scene's later edits, which name the scratch
  path, onto that text and writes the baked path under `target_root`.
- **Hub-capable fields (C1 / #238).** The field template carries `world/chapter_location.gd` on
  its root (arrival flag and checkpoint from the location document) and an `OutdoorTownsfolk`
  `TownNpcSpawner`. The spawner resolves its town from the scene through
  `FastTravelRegistry.by_scene()`, or else through the baked location the scene is when
  `NpcRoster.town_ids()` lists it (C3 / #240: The Long Verge is a wilds road with a Company camp,
  a roster town that is not a fast-travel hub), and reads that town's generated roster and
  placements (`NpcRoster.roster_path()` / `placements_path()`); in a scene with no roster it
  stays idle. Characters whose `placement_anchor` row names the town (`tools/seed_town_npcs.gd`
  `PLACEMENT_ANCHORS`, `"town"`; the town id is the `canon/<town>/` directory and the location
  id) land in that town's artifacts, and their routine coordinates are the town scene's
  (`NpcRoutines.hub_scene()`).
- **Limits.** These stay hand-wired in the same PR as the package (Kesselford, #238, is the
  worked example):
  - `FastTravelRegistry._HUBS` (which makes the scene a hub; a wilds location with a roster
    skips this row), `WorldMapRegistry` rows and the `LocationRegistry` named consts a test
    requires for every baked location.
  - An interior's `BuildingTransitionRegistry` `.tres` pair and preload consts (#342); the
    package sets the interior `Room`'s `exit_transition_id` export to `<name>_exit`, and the exit's
    `source_anchor` is `Room/ExitDoor`.
  - The placement anchor rows and `TOWN_SCENES` / `TOWN_NAMES` entries in
    `tools/seed_town_npcs.gd` and the vendor row in `tools/seed_town_vendors.gd` (then
    `scripts/seed_town_npcs.sh` / the vendor seeder and `regen --write`), plus
    `BuildingInterior.VENDORS_BY_INTERIOR`.
  - The reverse travel exit lives in the other scene's log (Dom's `FordRoad` is two `add_node`
    commands on `res://world/starting_town.tscn` in the same package).

## Locations

The **Locations** bottom tab (E3.3a, #341) edits the hidden state of every location with a scene:
Harmonic Accord, thinning tier, weather default (calm or an element on the wheel), no-combat zone,
respawn policy, gameplay permission, default spawn, spawn aliases (`alias = spawn id`, one per
line), and the arrival flag/checkpoint. Identity — id, scene and the `.tres` it bakes to — and the
gazetteer facet (display name, patron, agreement, vault id) are read-only.

- **Canon.** `canon/<hub>/locations/<id>.json` (`weftlumin.location.v1`) is the source.
  `WeftluminLocationsKind` (`weftlumin/kinds/locations.gd`) validates it with attributed errors,
  and `tools/generate_locations.gd` bakes it into `world/locations/**/*.tres` and
  `data/generated/location_index.json`. A bake of unchanged canon is byte-identical to the
  committed files; `scripts/check_generated_data.sh` runs it as the `LOCATIONS-GEN` drift stage.
- **Drafts.** Save draft validates the whole location set with the edit applied and writes only
  `user://weftlumin/location-drafts/locations/<id>.json`. The panel never writes `res://`.
  **Bake preview** lists the definitions the generator would rewrite. To promote drafts, run the
  generator with `SOUL_METER_LOCATION_DRAFTS=<globalized draft directory>`. It replaces the canon
  documents of the same ids and regenerates. A draft cannot create a location.
- **Runtime.** `LocationRegistry.ALL` is read from the index (E3.3b, #342); the named consts
  (`LocationRegistry.DOM`, ...) resolve to the same resources. `FieldMap.no_combat_zone()` reads
  canon `no_combat_zone` through `LocationRegistry.no_combat_zone_by_scene()`.
  `LocationRegistry.register_runtime(def)` registers an unbaked location for the session and emits
  `LocationRegistry.locations_changed`; `GameFlow` validates travel with
  `LocationRegistry.is_gameplay_scene()`. `WorldMapRegistry`, `FastTravelRegistry` and
  `BuildingTransitionRegistry` still hold their own tables: `weftlumin.location.v1` has no world-map,
  hub or transition facet for them to read yet.
  Rendered evidence of a new game travelling Dom -> Equipment Shop through the index-driven
  registry is in `docs/qa/registries-342-2026-10-11/`, from `test/manual/registry_travel_capture.gd`.

Rendered evidence of the tab (canon form, then a saved draft with its bake preview) is in
`docs/qa/weftlumin-locations-341-2026-10-11/`. It comes from
`test_rendered_location_panel_capture` in `test/integration/test_weftlumin_location_panel.gd`
with `SOUL_METER_LOCATION_PANEL_CAPTURE_DIR` set under Xvfb.

## Characters

The **Characters** bottom tab (E5.1, #347) edits every `canon/<hub>/characters/<id>.json`
(`weftlumin.character.v1`) — Dom's 60 townsfolk (`npc`), the six combat archetypes (`archetype`)
and new recruits (`recruit`) — and creates new ones.

- **Open registries.** `kind` and `stats.schema` are not enums. `WeftluminCharactersKind`
  (`weftlumin/kinds/characters.gd`) holds what the host declares through
  `register_character_kind` and `register_stat_schema`. Soul Meter's adapter
  (`soul_meter_adapter.gd` `kinds()`) declares npc, archetype and recruit, plus `dramgid.v1`
  and `six-stat.v1`. An undeclared kind or schema is refused. The npc and archetype contracts are
  the same as `CanonReader`'s, and a test checks that they match.
- **Generic form, opaque stats.** The form is built from the kind's contract. `stats` is shown
  key by key in the order its schema declares, followed by any other keys. The editor does not
  interpret stat values. `dramgid.v1` is checked through `DramgidSchema`: each attribute is
  present and whole. `six-stat.v1` has no installed definition, so any object naming it passes.
- **vault_id.** A recruit must name a lore-vault character when it is created. The id is checked
  against `../dramgid-vault/index.json` (`type: "character"`) through
  `PartyMember.vault_id_refusal`. If the vault is missing, the check refuses instead of passing.
  A vault_id that has been set is never renamed (the field becomes read-only), and the editor
  never fills one in.
- **Pickers.** Portraits come from `assets/generated/portraits/**` and are previewed through
  `ChargenArtResolver.portrait_texture`. Sprites come from the units under
  `assets/generated/sprites/units/` and are previewed through `UnitArt`. Both are also semantic
  pickers in `pickers.gd` (`portrait_path`, `sprite_unit_id`). `sprite_unit_id` is stored in
  canon, but seeders still resolve art by character id, and the panel notes this.
- **Drafts.** Save draft writes only to `user://weftlumin/character-drafts/characters/<id>.json`.
  **Bake preview** lists the canon documents that would be created or updated. When an npc
  changes, it also lists the roster and placements that `tools/generate_gloot.gd` would
  regenerate. That generator now emits `dom_npc_roster.json` and `dom_npc_placements.json` from
  canon npc rows, using the town seeder's own derivation, and the output is byte-identical
  (`GLOOT-GEN` drift stage). No tool promotes character drafts into canon yet.
- **Not yet consumed.** Recruits are not seeded, and the tavern bench is still
  `GameState.recruitable_candidates()`. The generator still expects exactly 60 Dom NPCs.

Rendered evidence (an npc with its pickers, archetype stats rendered from the schema, and a
recruit refused without a vault_id) is in `docs/qa/weftlumin-characters-347-2026-10-11/`, from
`test_rendered_character_panel_capture` in `test/integration/test_weftlumin_character_panel.gd`
with `SOUL_METER_CHARACTER_PANEL_CAPTURE_DIR` set under Xvfb.

## Spawns

The **Spawns** bottom tab (E4.2, #346, architecture §4.10) edits the spawn tables that
`SpawnDirector` (E4.1, #345) reads, places their anchor markers, and shows each slot's live state.

- **Canon.** `canon/<hub>/spawn_tables/<id>.json` (`weftlumin.spawn_table.v1`) is the source;
  `SpawnDirector` reads it directly, so there is no bake. `WeftluminSpawnTablesKind`
  (`weftlumin/kinds/spawn_tables.gd`) validates §4.10 step 5's invariants as attributed errors
  (`field` is a path such as `slots[0].entries[1].weight`): every slot has a non-empty entry with
  weight > 0, weights are positive integers, `respawn_days >= 1`, `1 <= pack_size.min <= max`, and
  the anchor exists in the scene. It also applies the location's `respawn_policy` through
  `SpawnMath.policy_violations()` (`none` refuses every table; `limited` enforces its provisional
  bounds); a scene with no location document is `none`, as at runtime. An archetype missing from
  the encounter catalog is a note, not an error. Inside a package, a table may name a scene the
  same package creates with `new_scene` before the bake writes it: the rendered template under
  `<package>/scenes/` plus the names the package's `add_node` commands place stand in for the
  `.tscn`, and the package's own `locations/*.json` supply the `respawn_policy` ahead of canon
  (C2 / #239; mirrors the locations kind).
- **Editing.** Pick a table and a slot; edit the anchor, respawn days, pack size, the entries
  (`archetype_id = weight` or `empty = weight`, one per line) and the table's `max_alive` (0 = the
  policy default). Add slot gives the new slot the anchor `SpawnSlot<PascalCase id>`. Identity —
  the table id and its scene — is read-only. **Save draft** validates the whole table set with the
  edit applied and writes only `user://weftlumin/spawn-drafts/spawn_tables/<id>.json`, in the exact
  layout of the canon files (an unchanged table saves byte-identical), so promoting a draft is
  copying it over the canon file the identity line names. The panel never writes `res://`.
- **Anchors.** **Place anchor** arms the scene model with the `spawn_slot` placeable (a `Marker2D`,
  adapter `PLACEABLES`) named after the slot's anchor; the next viewport click places it at the
  nearest open cell as one `add_node` command (undo/redo with the rest of the scene history). The
  Palette's Actors tab offers the same placeable as **Spawn slot**. A marker placed in the live scene
  satisfies the anchor invariant for drafts and is noted until the scene bake (E3.5) writes it to
  the `.tscn`.
- **Live state.** One line per slot from `SaveGame.spawn_director.slot_state()`: anchor present or
  `MISSING`, never rolled / members alive with their day-stamped group / cleared day, and
  blocked-by-cap. The panel reads state only.
- **Debug verbs.** `respawn now <table:slot>` and `clear slot <table:slot>` are Console verbs, below.

Rendered evidence (a placed `SpawnSlotGladeSouth` with its rolled pack, and the tab's live state) is
in `docs/qa/weftlumin-spawns-346-2026-10-11/`, from `test_rendered_spawn_panel_capture` in
`test/integration/test_weftlumin_spawn_panel.gd` with `SOUL_METER_SPAWN_PANEL_CAPTURE_DIR` set under
Xvfb.

## Headless CLI and PR flow (E7.1, #351)

`addons/weftlumin/tools/weftlumin.gd` runs the same code as the editor without a window
(architecture §4.13). It is a thin `SceneTree` entry. It loads `cli.gd` inside `_initialize()`,
after the autoloads exist, and runs the subcommand on the first frame, once they are ready.

```
godot --headless --path . --script addons/weftlumin/tools/weftlumin.gd -- <subcommand> [args] [--report <path>]
  validate <package_dir>                   manifest + every kind, attributed errors
  apply    <package_dir> <commands.jsonl>  replay onto fresh instances; scratch only (never res://)
  bake     <package_dir> [--write] [--force]  weftlumin.bake.v1 report; writes only with --write
  regen    [--write]                       drift stages; seeds Pandora and regenerates only with --write
  lint     <package_dir>                   [if /] lint, quest_audit statics, flag grammar, POT delta
  pr       <package_dir> [--issue N] [--draft] [--force] [--execute] [--open-prs FILE]
```

- **Package directory.** `campaign.json` is the optional manifest (`weftlumin.package.v1`).
  `commands.jsonl` is the scene command log. `locations/`, `characters/` and `spawn_tables/` hold
  canon documents. A document replaces the canon document with the same id, or is new under
  `canon/<hub>/`. `quests/` and `encounters/` are validated through `CampaignQuestLoader`, and
  `dialogue/**/*.dialogue` is linted. Without a manifest, the id comes from the log and the kinds
  are the ones present. The Dom fixture (`test/fixtures/weftlumin/dom_scene_bake`) is a valid
  package.
- **Output.** Each run prints human-readable lines, then `WEFTLUMIN-REPORT <json>`, then
  `WEFTLUMIN: <verb> <ok|errors|usage|refused_overlap> exit=<0|1|2|3>`. `--report` writes the
  same JSON to a file atomically. Godot can abort at teardown, so judge that line or the file,
  never the process exit code.
- **Same path as the UI.** `apply` and `bake` replay through `WeftluminBake` and
  `WeftluminCommandBus.replay()`, so `pre_state` drift refuses as it does in the editor. Logged
  live-state verbs (`{"kind": "console", "op": "execute", "params": {"command": "…"}}`) run
  against the live autoloads through the console interpreter (`weftlumin/panels/live_verbs.gd`, which is export-excluded like the panels). They keep its `[debug] `
  provenance and are excluded from replay. Game-specific work goes through new
  `WeftluminGameAdapter` hooks implemented in `soul_meter_adapter.gd`: `cli_kinds`, package
  validate/bake, scene contracts, `lint_package`, `pot_files`, `player_facing_keys`, `regen`,
  `run_live_verb` and `affected_test_globs`.
- **Lint.** It runs a GDScript port of `tools/lint_dialogue_conditions.py`, with the same codes
  and the same self-test cases. CI still runs the Python lint before Godot exists. It also runs
  `quest_audit`'s statics over the package. Flag grammar violations are errors here because a
  package's flags are new. It also checks softlocks in checked responses and phase reachability
  for the givers of package quests. Finally, it reports a POT delta: player-facing strings that
  the package adds and that neither `locale/project.pot` nor `data/generated/items.pot` contains.
  These are dialogue lines (heuristic) and the string exports in
  `PLAYER_FACING_KEYS`. The delta is reported only and never written, because regenerating the
  POT is still an editor-machine chore. `bake --write` refuses when lint has errors.
- **`pr` is a dry run unless `--execute`.** The dry run bakes in report mode, lints, and expands
  the adapter's fixed kind → test-glob map (scenes → `test_starting_town`, `test_field_room`,
  `test_travel_*`; quests → `test_quest_*`, `test_campaign_*`; encounters and spawn tables →
  `test_encounter_*`, `test_spawn_*`; characters → `test_party_*`, `test_npc_*`; canon → the drift
  stages). It then prints the plan. The plan creates a `weftlumin/<package id>` worktree, imports,
  runs `bake --write` there (plus `regen --write` when the bake lists regenerated files), runs lint
  and the affected tests, and commits. The commit carries `Closes #N` and only the `--trailer`
  values given. The plan then pushes and runs `gh pr create [--draft]`, with the bake report and
  `Closes #N` as the body. A dry run starts no process and makes no network call. The overlap scan
  reads `--open-prs FILE` (`gh pr list --json number,title,headRefName,files`). Otherwise it reports
  itself unchecked; `--execute` asks `gh`. If a planned file is also changed by an open PR, the run
  is refused with `refused_overlap` and exit 3 unless `--force`. It never sets labels, milestones or
  assignees.
- **Launcher.** `pr.gd` `launch()` / `poll()` / `cancel()` start the CLI as a detached headless
  Godot through `OS.create_process` (debug builds only, never `OS.execute`). They poll its
  `--report` file and can kill the process. The in-game **Bake & PR** button is not wired yet; it
  needs a package panel to host it.

`test/unit/test_weftlumin_cli.gd` covers every verb in-process, the overlap refusal, the
launcher and the `[if /]` port. Its process runner fails the test if anything is executed. A
transcript of each verb run against the Dom fixture is in `docs/qa/weftlumin-cli-351-2026-10-12/`.

## Enablement and release safety

Open Weftlumin with **F12** (the remappable `weftlumin_toggle` action) in a debug build started
with `SOUL_METER_WEFTLUMIN=1`. The shell owns activation, key bindings and pause; no tool listens for
its old F-key or environment variable any more.

Each panel creates **one private instance** of its model as a child (`SoulMeterToolPanel.configure()`)
and enables it through the model's `host_in_panel()` seam. A model that no panel hosts is inert: no
children, no signal connections, no input processing, no files, and every mutating entry point
refuses. `host_in_panel()` refuses in release builds (`OS.is_debug_build()` is load-bearing and must
never be weakened), outside the scene tree, and — for the two sandbox tools — without the shell's
sandbox owner token.

Release builds contain none of this code. `weftlumin/panels/*` (panels and models) is in every
preset's `exclude_filter` in `export_presets.cfg`, the five autoload entries are gone from
`project.godot`, and no shipped script references a model. The `*_inert` suites under
`test/integration/` pin exactly that (via `test/helpers/weftlumin_tool_release.gd`), alongside the
bootstrap's own `test_weftlumin_inert.gd`. Never ship a Gate T playtest artifact with tool access:
such a session is invalid evidence.

The shell's production-owner predicate (`production_owner_live()` in
`addons/weftlumin/shell/soul_meter_adapter.gd`) treats a live
`Battle` session or any Dialogue Manager balloon under the current scene as production content; the
sandbox tools refuse to start over it.

## State console

The console reaches authored mid-chapter states without replaying the chapter. Enter a command and
submit it; `Up`/`Down` navigate history. Bad arguments and unknown commands produce `ERROR:` log
lines instead of engine errors.

| Command | Public implementation path | Result |
| --- | --- | --- |
| `flag <name> [true\|false]` | `GameState.set_flag()` / `get_flag()` | Sets a flag; omitted value means `true`. |
| `flags [filter]` | `GameState.flags` names plus `GameState.get_flag()` | Lists flags, optionally filtered by case-insensitive substring. |
| `soul <value>` | `GameState.set_soul_meter()` | Sets the Soul Meter through its normal clamping and husking rules. |
| `gp <value>` | `GameState.set_gp()` | Sets GP through its normal non-negative clamp. |
| `rep <faction> <delta>` | Generated `FactionIds` catalog, then `Reputation.record()` | Appends a tagged faction-consequence event. |
| `standing <faction>` | `Reputation.standing()` / `band()` | Shows the derived standing and band. |
| `why <faction>` | `Reputation.why()` | Shows the newest recorded faction reasons. |
| `renown <delta>` / `infamy <delta>` | `Renown.gain_reputation()` / `gain_infamy()` | Appends a tagged Renown or Infamy event. |
| `why renown` / `why infamy` | `Renown.why()` | Shows the newest reasons for that ledger. |
| `item <item_id> [count]` | Generated `ItemIds` catalog, then `GameState.inventory.create_and_add_item()` | Adds valid item prototypes; count defaults to one. |
| `treat <member_id> <location> [service-test\|field-test] [practitioner_id]` | Treatment coordinator | Drives treatment through its public path and refuses cleanly. |
| `quest offer <quest_id>` | Runtime-aware `QuestRegistry` catalog, then `QuestRegistry.offer()` | Offers and starts the quest; refuses a completed quest. |
| `quest complete <quest_id>` | Not available | Returns an error and changes no quest state (see below). |
| `phase <morning\|afternoon\|evening\|night>` / `phase next` | `WorldClock.set_phase()` / `advance()` | Sets or advances the phase. |
| `goto <scene-or-hub-id>` | `LocationRegistry`, then `GameFlow.travel()` | Requests legal travel; never `change_scene_to_file()`. |
| `respawn now <table:slot>` | `SaveGame.spawn_director` (`to_dict()`/`from_dict()`, `populate()`) | `[debug]`: forgets the slot's state, takes the scene's spawn-slot hostiles off the field and repopulates, as a same-day re-entry would. The E4.1 roll is unchanged: same save and day, same result (`empty` included). Refused during combat. |
| `clear slot <table:slot>` | `SaveGame.spawn_director` (`to_dict()`/`from_dict()`) | `[debug]`: removes the slot's hostiles and records it cleared today; it rolls again after its cadence. Refused during combat. |
| `help` | Console read path | Lists commands. |

`quest complete` stays refused: `QuestRegistry.debug_force_complete(quest)` accepts no cause, and
some resolvers append ledger events, so debug evidence would be indistinguishable from play.

**Tagged provenance.** Every console-originated ledger write passes a cause beginning with the
model's exported `DEBUG_CAUSE_PREFIX` (`[debug] `); `is_debug_caused(cause)` is the canonical test.
Never add an untagged or post-hoc mutation path.
`respawn now` and `clear slot` write no ledger (`SpawnDirector` takes no cause): they are listed in
`help` and logged with the `[debug] ` prefix, and, like every command, set `dev_console_used`. They
are live-state verbs, excluded from replay-equivalence (§4.4).

**Session hygiene.** The first command of each hosted session sets the durable, write-once
`dev_console_used` flag (not settable from the console). The model keeps a session command audit.
When `PlaytestRecorder` is active, each command appends one `dev_console_command` event.

## Consequence timeline

A read-only observer of both append-only ledgers (`Reputation` per-faction, `Renown`
reputation/infamy). It never calls a ledger mutator or `from_dict()`; it connects only
`reputation_changed`, `renown_changed` and `SaveGame.load_requested` (a load replaces both ledgers
without a change signal, so it resynchronises from history).

Live rows are newest-first by the observer's private arrival counter, never written to a ledger.
History that predates the observer is backfilled per ledger in that ledger's own `order` and labelled
`RESTORED HISTORY / CROSS-LEDGER ORDER APPROXIMATE`. Each row shows timestamp, ledger, faction or kind,
signed delta, resulting value, cause, actor and scene; causes with the console's `DEBUG_CAUSE_PREFIX`
are flagged `DEBUG-INJECTED`. At most `MAX_RETAINED_ROWS` (200) rows are kept.

## Combat Lab

An encounter sandbox for provisional combat balance in the running game. The panel needs the shell
sandbox: the shell arms the shared `WeftluminSandbox` under the panel's token and the lab's sessions
restart under that same token.

- **Setup.** Encounters come from `EncounterCatalog` (including registered campaign encounters).
  Party choices combine the current party and recruitable candidates, capped at
  `GameState.REQUIRED_COMPANIONS + 1`. "Opens on" picks the set-piece (the selected encounter) or a
  living field hostile as hop 0. Weather starts from the live field's location default (or `CALM`)
  and is labelled as location, absent or overridden; encounters carry no weather (§4.9). A tile seed sets cell, element and charge
  on the runtime `TileState`. Called-shot anatomy and visibility fixtures are lab-only.
- **Production path** (E5.2, #348). `Battle.start_set_piece(field, encounter_id)`, or
  `Battle.start_session(field, hostile)` for a field hostile, on the field production sessions use
  (`Battle._current_field_map()`), then `GameFlow.send_event("enter_battle")`; the lab never changes
  scenes or substitutes a controller. Before Battle is touched the setup must fit the board
  (`CampaignEncounterLoader.fits_the_board`: deployable cells hold party + hostiles; a set-piece's
  authored `ally_cells` are deployable here); a refusal is shown in the panel and leaves no battle
  and no armed sandbox. Stop and restart release the lab's own session through `Battle.abandon()`.
- **Inspector feed.** The model emits `inspector_changed(payload)` from `Battle.combat_event`,
  `turn_resolved`, `balance_changed` and `battle_ended` (no polling): scheduler order and READY_AT,
  the pending forecast, matching resolution, Balance, weather, tiles, style points, turns and outcome.
- **Forecast equals resolution** (#209). The lab compares the controller's own forecast with the
  later `action_resolved` damage for the same target and labels any mismatch
  **FORECAST / RESOLUTION DIVERGENCE** — a combat correctness defect, never display variance.
- **Seeds.** The seed drives `SkillCheck`'s RNG only; combat damage is deterministic per controller
  sequence, so "new seed" re-rolls skill checks and leaves damage identical by design.
- **Containment.** Every session arms the shared sandbox over everything
  `SaveGame.capture_runtime_state()` covers (enumerated once, in `SaveGame`), plus the RNG position;
  autosaves are refused at staging while armed. Restarts restore-then-capture as a pair.
- **Ownership.** Every start and restart refuses over a production battle or another tool's armed
  sandbox; the panel shows `REFUSAL_WARNING`.
- **Export.** `user://combat_lab/<timestamp>.md` with setup, a forecast/resolution parity table,
  outcome and, for weather overrides, an authoring candidate for a human to apply. The lab has no
  write path to catalogs, the element matrix, Pandora or generated data.
- **Recorder.** Each lab battle appends one `combat_lab_battle_started` event.

## Dialogue Lab

A read-only play-edit-reload loop for `.dialogue` resources under `dialogue/` and
`dialogue/companions/`.

1. Pick a resource and one of its titles (read from the imported `DialogueResource`).
2. Optionally seed replay-only flags, faction standings and Renown targets.
3. Play. Dialogue launches through `DialogueManager.show_dialogue_balloon()`, the production path.
4. Edit the file externally, then **Reload from disk + replay** (`CACHE_MODE_IGNORE`), or
   **Replay same state**.
5. **End session**, or leave the tab, to restore.

**Containment** is the same shared sandbox as Combat Lab: every session begins armed, seeded state is
applied after capture, a session restores exactly once and then disarms, and autosaves cannot be
staged while armed. **Ownership:** every replay entry point (`start_replay`, `start_test_session`,
`replay_same_state`, `reload_and_replay`) refuses over a production battle, a production dialogue
balloon, or another tool's armed sandbox; the panel shows `REFUSAL_WARNING`. The lab never writes
dialogue text and has no export path.

## Quest editor

Authors runtime campaign packages in the exact format `CampaignQuestLoader` consumes. The panel edits
`campaign.json` and the quest documents as JSON; validation, transactional writes, reload and
registration are the model's.

- **Validate** uses `CampaignQuestLoader.validate_package_data()` — the single rule implementation —
  and lists errors with `file`, `field`, `expected` and `message`.
- **Save** stages every document as a `.tmp` sibling, protects the previous files as `.bak`, then
  promotes the complete set; failures roll back. It writes only
  `user://campaigns/<campaign_id>/campaign.json` and `quests/<quest_id>.json`; existing package
  `dialogue/` and `encounters/` files are preserved byte-for-byte. It never writes `res://`, committed
  sources, Pandora or the vault; promotion to canon is `tools/bake_campaign.gd`'s job.
- **Registration** happens only after a zero-error loader round trip, and replaces the runtime set.
  If a registered runtime quest has live progress, save/reload refuse to register, name every
  affected quest, and offer **Authorize reset of listed live quests**, which authorises exactly those
  identities (a newly conflicting identity refuses again).
- The editor never offers, resolves or advances quests and never opens a save sandbox.
- **Package rules** (portable quest-id paths, case-folded uniqueness, discovery depth and link
  limits, campaign encounters, campaign dialogue compiled with `DMCompiler`, campaign-first title
  resolution) are owned by `CampaignQuestLoader`; campaign encounters are reachable from campaign
  dialogue `do Battle.start(...)` and from the Combat Lab panel.
- **Limits:** package containment is lexical (symlinked roots are out of scope), runtime dialogue is
  not sandboxed, and save is rollback-capable but not crash-atomic.

## Tests

| Coverage | Suites |
| --- | --- |
| Release build carries no tool code; unhosted models are inert | `test/integration/test_{dev_console,consequence_timeline,combat_lab,dialogue_lab,quest_editor}_inert.gd`, `test_weftlumin_inert.gd` |
| Model behaviour | `test/unit/test_{dev_console_commands,consequence_timeline,combat_lab,dialogue_lab,quest_editor,campaign_encounters,campaign_quest_registry}.gd` |
| Panels in the shell | `test/integration/test_weftlumin_panels.gd`, `test_weftlumin_shell.gd` |
| Placeables and export inspector (#339) | `test/unit/test_weftlumin_placeables.gd`, `test/integration/test_weftlumin_palette_inspector.gd` (rendered capture with `SOUL_METER_WEFTLUMIN_PALETTE_CAPTURE_DIR`; evidence in `docs/qa/weftlumin-palette-339-2026-10-11/`) |
| Pattern library (#370) | `test/unit/test_weftlumin_pattern_library.gd`, `test/integration/test_scene_pick_pattern_browser.gd`; format: `test/unit/test_layout_patterns.gd` |
| Locations kind, generator, drift and drafts | `test/unit/test_weftlumin_locations_kind.gd`; panel: `test/integration/test_weftlumin_location_panel.gd` |
| Characters kind, registries, vault_id, roster-from-canon, pickers | `test/unit/test_weftlumin_characters_kind.gd`; panel: `test/integration/test_weftlumin_character_panel.gd` |
| Spawn tables kind, panel, anchors and debug verbs (#346) | `test/unit/test_weftlumin_spawn_tables_kind.gd`, `test/unit/test_dev_console_spawn_verbs.gd`; panel: `test/integration/test_weftlumin_spawn_panel.gd` |
| Accord overlay and bake saturation lint (#350) | `test/unit/test_weftlumin_accord_saturation.gd`; panel: `test/integration/test_weftlumin_accord_overlay.gd` |
| Headless CLI verbs, `[if /]` port, POT delta, overlap refusal, launcher (#351) | `test/unit/test_weftlumin_cli.gd`; transcript in `docs/qa/weftlumin-cli-351-2026-10-12/` |

The original file-to-behaviour migration plan is `docs/weftlumin-test-migration.md` (E1.9).
