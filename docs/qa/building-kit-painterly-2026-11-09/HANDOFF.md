# Building kit painterly pass — issue #631

Ready for Claude's art review. All changes remain in the working tree on
`codex/painterly-building-kit`; no Git writes or GitHub actions were performed.

## Result and acceptance evidence

- All 36 original PNG names are regenerated. No kit piece was added or removed.
- All 36 pivots, all model geometry, all layout/door/roof definitions, and the 30°
  camera are unchanged. The 34 non-floor PNGs also retain byte-identical alpha
  masks and original dimensions. `baseline-manifest.json` records the input.
- Both floors use 64×32 canvases. Their opaque raster is 64×31 (the permitted
  one-pixel raster tolerance). Each 4×4 seam check has **0 gaps and 0 overlapping
  opaque pixels**. The original floor side faces extended 1–2 pixels beyond the
  ground diamond; export now masks that below-ground fringe. The source models
  and base pivots remain unchanged. Only the two floor heights and the manifest's
  description changed in `building_kit.json`.
- Roof/post alignment is visually unchanged in all four exterior captures.
  Both existing roof-coverage tests and the ground-grid corner test pass. No
  post or wall protrudes above the roof.
- All 24 layout captures were inspected in the four comparison sheets: four
  layouts × before/after × exterior, roof-hidden/walls-up, party-room cutaway.
  The sheet containing all 36 final pieces was also inspected.
- Focused building unit suites: **26 cases, 0 errors, 0 failures, 0 skips**.
  Asset checks pass; `git diff --check` passes; `project.godot` is restored.

## Art and provenance

Built-in `image_gen.imagegen`: **9 generations / 24 maximum**. Floor planks used
2/2 attempts; footing stone, wall plaster, roof slate, furniture wood, iron,
hearth stone and cloth each used 1/2. The first floor was superseded because of
a visibly repeating bright patch. All nine complete prompts and source paths,
including the superseded attempt, are in the kit's `provenance.json`.

All eight retained material images were inspected; Pillow reports opaque RGB
1254×1254 images (the tool's returned size). The 36 rendered sprites have both
fully transparent background pixels and fully opaque paint pixels. No texture
was substituted with a procedural or hand-painted bitmap.

The renderer uses the original Kenney meshes and original palette face IDs to
assign painted plaster, timber and iron. World-space texture coordinates avoid
stretching caused by the module scales; roof UVs follow the eaves. One unchanged
upper-left sun direction lights every piece, with less ambient fill and a lighter
final grade because the materials already contain the dark house palette.

Remaining visual limitations, for the art review:

- `hearth-1x1`, `hearth-2x1`, `stove-2x1`: the painted ember panels still read as
  rectangles; their original box geometry was retained.
- `shelves-4x1`: the small shelf contents retain their original cuboid shapes.
- Roof pieces, especially `roof-tavern-t0`: the rear-facing slate courses are
  compressed by the fixed camera/roof angles; those angles were preserved.
- Long walls show repeated plaster wear because they reuse one wall sprite.

## Captures and their interpretation

Folder: `docs/qa/building-kit-painterly-2026-11-09/`.

| Evidence | Files |
|---|---|
| Matched before/after layouts | `compare-tavern.png`, `compare-shop.png`, `compare-cottage.png`, `compare-warehouse.png` |
| Original 1280×900 captures | `{before,after}-{tavern,shop,cottage,warehouse}-{outside,walls-up,inside}.png` |
| All 36 pieces on painted field ground | `after-pieces-contact-sheet.png` (baseline: `before-pieces-contact-sheet.png`) |
| 4×4 floor seams, enlarged without smoothing | `after-floor-planks-seams-4x4.png`, `after-floor-footing-seams-4x4.png`; baseline counterparts also included |
| Machine-readable checks | `asset-checks.json`, `before-states.json`, `after-states.json` |

These are isolated Godot runtime captures using the real Kesselford terrain
backdrop, ground coordinates, layouts, turns, and `WalkInBuilding` behavior.
A cyan diamond marks a synthetic actor in the `player` group; its movement
triggers the normal physics/tween cutaway path. No character body, NPC, signage,
or new lore was generated. `walls-up` hides only the roof for diagnostic viewing.
Before/after captures use identical cameras and party positions. The field-only
plates are contact-sheet inputs, not additional gameplay states.

## Commands and results

Each Godot invocation had `GODOT_BIN=$HOME/.local/bin/godot`, `LP_NUM_THREADS=1`,
`XDG_CONFIG_HOME=/tmp/codex-kit/config`, and
`XDG_CACHE_HOME=/tmp/codex-kit/cache`. Only one Godot process ran at a time.

The exact focused test commands. Raw logs were kept out of the repository:

```bash
XDG_DATA_HOME=/tmp/codex-kit/tests-building-plan XDG_CONFIG_HOME=/tmp/codex-kit/config XDG_CACHE_HOME=/tmp/codex-kit/cache SOUL_METER_TEST_DATA_DIR=/tmp/codex-kit/tests-building-plan GODOT_BIN=$HOME/.local/bin/godot LP_NUM_THREADS=1 xvfb-run -a -s "-screen 0 1920x1080x24" bash scripts/test.sh -a test/unit/test_building_plan.gd
XDG_DATA_HOME=/tmp/codex-kit/tests-walk-in-building XDG_CONFIG_HOME=/tmp/codex-kit/config XDG_CACHE_HOME=/tmp/codex-kit/cache SOUL_METER_TEST_DATA_DIR=/tmp/codex-kit/tests-walk-in-building GODOT_BIN=$HOME/.local/bin/godot LP_NUM_THREADS=1 xvfb-run -a -s "-screen 0 1920x1080x24" bash scripts/test.sh -a test/unit/test_walk_in_building.gd
XDG_DATA_HOME=/tmp/codex-kit/tests-building-transitions XDG_CONFIG_HOME=/tmp/codex-kit/config XDG_CACHE_HOME=/tmp/codex-kit/cache SOUL_METER_TEST_DATA_DIR=/tmp/codex-kit/tests-building-transitions GODOT_BIN=$HOME/.local/bin/godot LP_NUM_THREADS=1 xvfb-run -a -s "-screen 0 1920x1080x24" bash scripts/test.sh -a test/unit/test_building_transition_registry.gd
```

| Suite | Overall summary | Exit |
|---|---|---|
| `test_building_plan.gd` | 10 test cases; 0 errors; 0 failures; 0 flaky; 0 skipped; 0 orphans | 0 |
| `test_walk_in_building.gd` | 9 test cases; 0 errors; 0 failures; 0 flaky; 0 skipped; 0 orphans | 0 |
| `test_building_transition_registry.gd` | 7 test cases; 0 errors; 0 failures; 0 flaky; 0 skipped; 0 orphans | 0 |

Import command, run initially before any tests, warmed after the fresh-worktree
import, and repeated after material/PNG regeneration:

```bash
XDG_DATA_HOME=/tmp/codex-kit/data XDG_CONFIG_HOME=/tmp/codex-kit/config XDG_CACHE_HOME=/tmp/codex-kit/cache GODOT_BIN=$HOME/.local/bin/godot LP_NUM_THREADS=1 xvfb-run -a "$HOME/.local/bin/godot" --headless --path . --import
```

Final import: exit 0; no script parse/compile errors. Initial cold-import UID
resolution diagnostics cleared on the warm import. Import shutdown still emits
PhantomCamera/Pandora editor cleanup and resource-leak diagnostics. The tests,
captures and renderer also emit the existing ObjectDB/resource cleanup warnings
after successful completion. These are recorded, not counted as test failures
or silently fixed in vendor code.

```bash
python3 docs/qa/building-kit-painterly-2026-11-09/run_recipe.py render
python3 docs/qa/building-kit-painterly-2026-11-09/run_recipe.py after
/usr/bin/python3 docs/qa/building-kit-painterly-2026-11-09/inspect_kit.py
git diff --check
```

Renderer: `BUILDING-KIT: ok` with 36 successful piece lines.
Capture: `KIT-CAPTURE: PASS (after; 12 layout captures + field plate)`.
Before capture has the equivalent PASS line. Early iterations used an identical
runner at `/tmp/codex-kit/run_autoload.py`; the durable runner above includes the
same recipe and checks its success marker. The first capture's early-autoload
ordering was corrected to the documented position after Pandora before the
retained baseline captures were made.

Pillow check: `KIT-ASSET-CHECK: PASS (36 pieces; exact floor diamonds; zero gaps/overlaps; all pivots/spec unchanged)`.
`git diff --check`: exit 0, no output. The system Python at `/usr/bin/python3`
provides Pillow; the default `python3` does not, so the initial inspection attempt
was rerun with that existing interpreter. No package was installed.

`run_recipe.py` restores `project.godot` in `finally`; its verified SHA256 is
`9fee2a8fac91beaca2cebd929edf5e68268723f133d7591586d88098e07724ce`.

## Changed files, grouped by directory

`assets/generated/sprites/building-kit/`: the same 36 PNGs listed in
`building_kit.json`, the regenerated manifest, and new `provenance.json`.

`assets/generated/sprites/building-kit/materials/`: `floor-planks.png`,
`footing-stone.png`, `wall-plaster.png`, `roof-slate.png`, `furniture-wood.png`,
`iron.png`, `hearth-stone.png`, `cloth.png`, and their Godot import sidecars.

`tools/`: `render_building_kit.gd`.

`docs/qa/building-kit-painterly-2026-11-09/`: this handoff, captures/contact sheets,
seam sheets, check/state JSON, baseline manifest, `capture.gd` and its UID,
`run_recipe.py`, `inspect_kit.py`, logs, and generated image import sidecars.
`changed-files.txt` is the exact inventory from the final working tree.

## Open questions and deviations

Open questions: none requiring a design or canon decision.

Raster correction: floor export masks the original side-face fringe to meet the
explicit seam contract; models and pivots were not changed.

Capture fixture: a synthetic party-position marker replaces characters/NPCs;
the actual building state machine, map background and layout geometry are used.

No permanent change to `project.godot`, layouts, gameplay, theme tokens, vendor
addons, `data/generated/*`, or files outside the authorized source/art/QA scope.

## Claude's review edits (2026-11-09)
- The 24 single-layout captures (`before|after-<layout>-<state>.png`, 38 MB) were moved out of the repository. The four `compare-<layout>.png` sheets show all of them side by side, and `capture.gd` regenerates them at full size.
- `materials/` carries a `.gdignore`. `tools/render_building_kit.gd` reads the textures with `Image.load_from_file()`, so they need no import, and 22 MB of source textures stay out of the exported game.
