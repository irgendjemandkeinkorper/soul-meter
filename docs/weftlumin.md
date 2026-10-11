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
SMInteractable, Chest, Pickup, InteractiveSwitch and a `Marker2D` spawn marker. ZhavarTelegraph
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
  written. There is no bake button and no CLI yet; the PR flow is E7.1.

The Dom fixture log is `test/fixtures/weftlumin/dom_scene_bake/commands.jsonl` (14 effective
commands of every class above plus an undone nudge); `test/integration/test_weftlumin_scene_bake.gd`
covers report and write modes, idempotence, live-session equivalence, Dom survival and the
refusals, and records the fixture again with `SOUL_METER_SCENE_BAKE_RECORD_FIXTURE=1`. With
`SOUL_METER_SCENE_BAKE_CAPTURE_DIR` set (under Xvfb or a display) it renders Dom before and after
the fixture bake; the #344 evidence is in `docs/qa/weftlumin-bake-344-2026-10-11/`.

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
- **Not yet consumed.** The registries still preload the generated `.tres` files.
  `FieldMap.no_combat_zone()` still derives the zone from the `res://world/interiors/` prefix,
  and the panel notes any canon value the runtime would ignore. Reading the index and
  `no_combat_zone` at runtime is E3.3b (#342).

Rendered evidence of the tab (canon form, then a saved draft with its bake preview) is in
`docs/qa/weftlumin-locations-341-2026-10-11/`. It comes from
`test_rendered_location_panel_capture` in `test/integration/test_weftlumin_location_panel.gd`
with `SOUL_METER_LOCATION_PANEL_CAPTURE_DIR` set under Xvfb.

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
| `help` | Console read path | Lists commands. |

`quest complete` stays refused: `QuestRegistry.debug_force_complete(quest)` accepts no cause, and
some resolvers append ledger events, so debug evidence would be indistinguishable from play.

**Tagged provenance.** Every console-originated ledger write passes a cause beginning with the
model's exported `DEBUG_CAUSE_PREFIX` (`[debug] `); `is_debug_caused(cause)` is the canonical test.
Never add an untagged or post-hoc mutation path.

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
| Locations kind, generator, drift and drafts | `test/unit/test_weftlumin_locations_kind.gd`; panel: `test/integration/test_weftlumin_location_panel.gd` |

The original file-to-behaviour migration plan is `docs/weftlumin-test-migration.md` (E1.9).
