# In-game layout mode

Layout mode is a debug-build-only map editing overlay. It is disabled by default and has no runtime behavior unless `SOUL_METER_LAYOUT=1` is present when the game starts.

From the repository root, launch a debug build with:

```bash
SOUL_METER_LAYOUT=1 ~/.local/bin/godot --path .
```

Release builds ignore the environment variable. Automated tests also remain unaffected unless they explicitly use the `force_enabled_for_tests` seam.

## Controls

- `F10`: enter or exit layout mode in a gameplay scene. The world is paused while the overlay is open, and its prior pause state is restored on exit.
- Click: select an editable dressing prop, NPC, marker, vendor/NPC spot, facade, building door, or travel exit.
- Drag: move the selected node on the 8 px grid.
- Hold `Shift` while dragging or placing: move freely without grid snapping.
- Arrow keys: nudge the selection by 1 px.
- `Delete`: delete the selection.
- `Ctrl+D`: duplicate a dressing-layer prop.
- `S`: save the current scratch override.

Choose `GroundDetails`, `SoftDetails`, or `SolidProps` in the palette before placing a texture. Solid props receive a `StaticBody2D` with the footprint shown by the width and height spinboxes; the provisional default is 64×24 px.

## Scratch override files

Saving writes one JSON file per scene basename:

```text
user://layout_overrides/<scene-file-basename>.json
```

The file records transforms, deletions, and additions. While layout mode is enabled, its autoload applies an existing matching override when the gameplay scene loads. Missing node paths are warned about and skipped, so a stale scratch file does not prevent the scene from loading.

Overrides are a scratch surface only. The committed `.tscn` file remains canonical; do not commit an override JSON as the final map change.

## Bake an override

Run the headless bake tool in report-only mode first:

```bash
~/.local/bin/godot --headless --path . \
  --script tools/bake_layout_overrides.gd \
  --scene res://world/starting_town.tscn \
  --overrides /absolute/path/to/starting_town.json
```

By default, the tool runs in report-only mode and prints planned changes without modifying any scene files.
Pass `--write --out res://path/to/candidate.tscn` to inspect a separate candidate. An existing output also requires `--force`; without `--out`, output defaults to the source scene.

**Do not overwrite canonical maps with this legacy tool.** Moving execution after autoload initialization preserves actor exports, but its `PackedScene.pack()` path still loses editable-instance overrides. Dom's `TavernDoor/Facade.visible = false` is one known example. The surgical text patcher is a separate prerequisite before canonical baking is safe. `--force` permits overwriting; it does not make packing lossless.

The required workflow is:

1. Inspect the report-only summary.
2. Write only a separate candidate with `--write --out` if needed for inspection.
3. Review actor exports and editable-instance overrides against the source; a successful summary does not prove scene fidelity.
4. Use the surgical bake workflow and its acceptance tests before committing a canonical scene change.

The tool prints applied edit/deletion/addition counts and skipped paths. Judge that summary when running in automation; a known engine teardown flake can produce exit 134 after successful output.
