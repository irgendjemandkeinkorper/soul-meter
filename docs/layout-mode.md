# In-game layout mode

Layout mode is a debug-build-only map editing overlay. It is disabled by default and has no runtime behavior unless `SOUL_METER_LAYOUT=1` is present when the game starts.

From the repository root, launch a debug build with:

```bash
SOUL_METER_LAYOUT=1 ~/.local/bin/godot --path .
```

Release builds ignore the environment variable. Automated tests also remain unaffected unless they explicitly use the `force_enabled_for_tests` seam.

## Controls

- `F10`: enter or exit layout mode in a gameplay scene. The world is paused while the overlay is open, and its prior pause state is restored on exit.
- Click: select an editable dressing prop, NPC, marker, vendor/NPC spot, facade, building door, or travel exit. When props overlap, the smallest one under the cursor wins; between two of the same size the one drawn on top wins, so a click picks what you can see.
- `Shift`+click: add the prop to the selection, or take it back out if it is already in it. The most recent addition becomes the primary — the one whose grid snapping the group follows.
- Drag: move the selection on the 8 px grid. A group moves rigidly and lands as one undo step; `Delete`, `Ctrl+D`, and the arrow keys likewise act on the whole group.
- Hold `Shift` while dragging: move freely without grid snapping.
- Hold `Shift` while clicking to place: keep placing the same texture. A normal click places once and clears the brush; `Esc` or right-click cancels it.
- Hold `Alt` while placing: bypass grid snapping (can combine with `Shift`).
- Arrow keys: nudge the selection by 1 px.
- `Delete`: delete the selection.
- `Ctrl+D`: duplicate a dressing-layer prop.
- `S` or `Ctrl+S`: save the current scratch override.
- `Ctrl+G`: save the current selection to the pattern library under the name in the Group field.
- `Ctrl+Z`: undo; `Ctrl+Shift+Z` or `Ctrl+Y`: redo. A drag is one undo step. The toolbar also exposes Undo, Redo, Duplicate, and Delete.

Pick a category in the palette's dropdown (Town, Castle, Nature, Terrain & ground, World objects, World locations, Units & NPCs, Mini characters, Items) and type in the search box to narrow it further; the search is fuzzy, so `mkt` finds `market-stall`. Categories come from where the art actually lives on disk — there is deliberately no "Enemies" folder, because enemy, companion, and NPC art all sit side by side under `units/`, and which unit is hostile is `EncounterCatalog` data rather than a property of the file.

Choose `GroundDetails`, `SoftDetails`, or `SolidProps` in the palette before placing a texture. Solid props receive a `StaticBody2D` with the footprint shown by the width and height spinboxes; the provisional default is 64×24 px.

Select an asset to edit position, independent X/Y scale, rotation, skew, horizontal/vertical flip, or grayscale. Shrink/Enlarge buttons resize both axes. Grayscale is reversible and leaves texture files unchanged; assets with custom or inherited materials keep their existing material instead.

For a selected rectangular solid prop, footprint width/height update its collision immediately; the cyan outline shows the effective collision area. Dimensions are local pixels, so scaling and rotating the prop also transform its footprint. Without a selected solid, these controls apply only to the next SolidProps placement (initial placement is capped at 120×48 px).

Drag the panel's title bar to move it; its position survives closing/reopening F10 in the same scene. Scroll inside the panel to reach the palette and lower controls; the Save button stays outside the scrolling area. Numeric fields keep keyboard editing separate from map shortcuts; clicking the map returns keyboard focus to editing. Gameplay menu hotkeys cannot open menus behind the editor.

Duplicate supports plain sprites and simple rectangular solid props, preserving their visual offsets, child transforms, frame/region settings, and collision geometry. Compound/scripted props and custom materials that cannot round-trip safely are refused with a visible message.

## The pattern library

A pattern is a reusable arrangement of props — a market stall with its crates and awning, a
campfire ring, a stretch of fence. Select the props, type a name in the Group field, and press
`Ctrl+G` or the Group button. The pattern appears in the list below; clicking one arms it as a
brush, and the next map click stamps the whole arrangement at the cursor (`Shift` to keep
stamping, `Alt` to bypass snapping, `Esc` or right-click to cancel). A freshly stamped pattern
stays selected, so you can rearrange it and `Ctrl+G` back over the same name to update it.

Patterns are stored one JSON file per pattern:

```text
user://layout_patterns/<pattern-id>.json
```

The id is the kebab-cased name, so saving over the same name replaces the pattern rather than
piling up near-duplicates. Offsets inside a pattern are recorded in **world space** relative to
the selection's top-left corner, not in any one layer's local space — that is what lets a
pattern spanning `GroundDetails` and `SolidProps` stamp correctly into a scene whose layers sit
at different transforms. Stamping into a scene that lacks one of the pattern's layers places
everything else and says which layer it skipped.

Only nodes layout mode can re-create are captured. Authored scene content (NPCs, doors, travel
exits) is refused by name so it is obvious what was left out, and a selection with nothing
patternable in it is refused outright.

The format (`globals/layout_patterns.gd`, schema 1) is deliberately editor-agnostic: it knows
about layers, textures, transforms, and offsets, and nothing about F10's UI. Weftlumin re-hosts
the same library later without a migration. A pattern worth keeping can be promoted out of
`user://` into the repo by hand — like scratch overrides, nothing under `user://` is canonical.

## Scratch override files

Saving writes one JSON file per scene basename:

```text
user://layout_overrides/<scene-file-basename>.json
```

The file records transforms, deletions, and additions. While layout mode is enabled, its autoload applies an existing matching override when the gameplay scene loads. Missing node paths are warned about and skipped, so a stale scratch file does not prevent the scene from loading.

Overrides are a scratch surface only. The committed `.tscn` file remains canonical; do not commit an override JSON as the final map change.

## Recovery and save safety

Closing F10 retains the live scene's editing document and undo/redo history. Each completed edit or undo/redo also writes an atomic recovery checkpoint under `user://layout_overrides/recovery/`, keyed by the full scene path. On a fresh scene load with layout mode enabled, a matching recovery checkpoint restores unsaved work. It does not restore old undo history after a process restart.

Manual Save replaces the scratch file only after a complete temporary file has been written and flushed. A failed write/replacement retains the previous file and the editor's unsaved status. The status bar reports save or recovery errors. Successful Save clears the obsolete recovery checkpoint; if the saved file changed externally, stale recovery is ignored.

## Bake an override

The legacy bake below is not the new Weftlumin surgical bake. It has known editable-instance/export preservation defects documented in [the editor architecture](architecture-in-game-editor.md#02-five-findings-that-change-the-design-verified-this-session). Do not overwrite a canonical scene with it; keep layout work as scratch until the reviewed surgical bake is available.

Use the headless bake tool to turn reviewed scratch data into a scene change:

```bash
~/.local/bin/godot --headless --path . \
  --script tools/bake_layout_overrides.gd \
  --scene res://world/starting_town.tscn \
  --overrides /absolute/path/to/starting_town.json \
  --out res://reports/starting_town_candidate.tscn
```

The default output is the input scene. To preserve the source while inspecting a candidate, pass `--out res://path/to/candidate.tscn`.

The required workflow is:

1. Bake the override.
2. Review the `.tscn` git diff carefully.
3. Run the relevant integration tests and the full suite.
4. Commit the canonical `.tscn` change only after review.

The tool prints applied edit/deletion/addition counts and skipped paths. Judge that summary when running in automation; a known engine teardown flake can produce exit 134 after successful output.
