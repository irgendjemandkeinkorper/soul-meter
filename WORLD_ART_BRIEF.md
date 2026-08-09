# WORLD/TERRAIN/BATTLE-MAP lane — standing art-production task (Codex)

You own **town/terrain/battle-map** art only. Do not touch anything under
`assets/generated/sprites/units/`, `assets/generated/models/units/`, or
`assets/generated/sprites/manifests/units.json`.

## Ground truth to read first
- `art-request.md` — section "Dom, Dorthkor Road, Loamroot Grove, and Jawbrace
  environment sets" (P1) and the "Technical delivery defaults" / palette section at the
  top of the doc.
- `tools/render_isometric_sprites.gd` — the existing deterministic 3D→2D isometric
  render pipeline (camera: orthographic, 45° yaw, 26.565° pitch/atan(0.5), 256×256
  transparent output, 64×32 world tile = 1 model unit). Reuse this camera/light/pivot
  contract exactly.
- `assets/generated/sprites/manifest.json` and `assets/generated/sprites/ground/ground_tileset.tres`
  — existing manifest schema and the current 4-terrain-type tileset (grass, dirt, stone,
  road) you are extending.
- `world/starting_town.tscn` (Dom) and `world/test_room.tscn` (wilds/field room) — the
  actual scenes these tiles need to seam into at a 64×32 grid.
- `assets/kenney3d/` (castle-kit, fantasy-town-kit, nature-kit) — source CC0 models
  available for reuse/kitbashing.

## File ownership (exclusive — this lane only)
```
assets/generated/models/world/
assets/generated/sprites/world/
assets/generated/sprites/battle/
assets/generated/sprites/manifests/world.json
```

## Naming
`<location>-<material>-<edge-or-shape>[--<variant>].png`, e.g.
`dom-road-stone--corner-ne.png`, `dom-wall-brick--straight.png`. No spaces, no prompt
text, no version numbers in filenames.

## Calibration-first batch loop (do not skip steps)
1. **Golden set #1 — Dom calibration micro-set** (per art-request.md P1 + palette
   guidance): stone paving, wet road, mud edge, puddle, one wall/building facade, two
   props (crate, brazier). That's 7 pieces total, all Dom.
2. Stop after this micro-set. Assemble a contact sheet placed edge-to-edge in a real
   64×32 tile grid (a test scene or a composited PNG) showing seams align with no
   half-pixel shimmer, next to the existing `ground_tileset.tres` grass/dirt/stone/road
   for palette continuity.
3. Do NOT expand to Dorthkor Road, Loamroot Grove, Jawbrace, or battle-grid overlays
   until this Dom calibration set is reviewed and explicitly approved.

## Acceptance checklist per asset
- Orthographic, 45° yaw, 26.565° pitch, 256×256, transparent background (matches
  `render_isometric_sprites.gd` exactly).
- Tile seams aligned to the 64×32 world-tile convention, no shimmer/gaps when placed
  adjacently.
- Palette matches art-request.md's material cues (charcoal/blue-black stone, tarnished
  bronze institutional elements, restrained magic accents, damp organic growth) — the
  world should read as "civilization still functioning inside a metaphysical emergency,"
  not generic bright high fantasy or steampunk.
- Ground pieces at `z_index` convention consistent with existing ground tiles; props have
  correct bottom-center pivot for y-sorting against the player/NPCs.
- Manifest entry recorded in `assets/generated/sprites/manifests/world.json` mirroring
  the existing `manifest.json` schema: presentation id, source model path, output
  path(s), generator version, source/output SHA-256, license/provenance note (this is
  agent-generated, NOT "Kenney CC0" — record actual provenance even though it's
  Kenney-compatible in style).

## Godot import
After placing PNGs, run `godot --headless --path . --import` if the Godot binary is
available in this sandbox to generate `.import` sidecars, then commit both the PNG and
its `.png.import`. If unavailable, note it in your final report.

## Batch size
Calibration batch = exactly the 7-piece Dom micro-set above. Stop and report after that.

## Forbidden
- Editing anything under `assets/kenney/`, `assets/kenney3d/`, or the UNIT lane's
  directories/manifest.
- Editing `data.pandora`, `data/generated/*`, or any `.gd`/`.tscn` game logic (including
  `world/starting_town.tscn` itself — you produce assets, not scene wiring).
- Renaming or deleting existing files, including the existing `ground_tileset.tres`.

## Deliverable
When done: commit your work on this branch (`art/world-lane`) with a clear commit
message, and print a short final summary of what was produced, what was skipped, and
any open questions for the reviewer.
