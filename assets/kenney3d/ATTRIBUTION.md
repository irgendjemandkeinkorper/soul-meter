# Kenney 3D kits — attribution

All assets in this directory are by **Kenney** (https://kenney.nl) and released under
**CC0 1.0 Universal (public domain dedication)**. No attribution is legally required;
it is recorded here as good practice and so the provenance of every asset is traceable.

| Kit | Source | Models | Used for |
|---|---|---|---|
| `fantasy-town-kit` | https://kenney.nl/assets/fantasy-town-kit | 167 | Town buildings, market stalls, carts, banners, doors |
| `nature-kit` | https://kenney.nl/assets/nature-kit | 329 | Trees, grass, rocks, bridges, terrain dressing |
| `castle-kit` | https://kenney.nl/assets/castle-kit | 76 | Walls, gates, towers, the Trial Hall and civic structures |

Downloaded 2026-08-04. Only the **GLB** format is vendored; the FBX/OBJ/DAE duplicates that
ship in the same archives were dropped to keep the repository lean.

## Why 3D models in a 2D game

The design doc specifies **"2D, isometric, rendered from 3D models."** These GLB files are the
*source*; they are never rendered live in game. `tools/render_isometric_sprites.gd` is the
one-way generator that renders each model through an orthographic camera at the project's
dimetric angle into a 2D sprite atlas under `assets/generated/sprites/`, following the same
one-way-generator convention as `tools/generate_gloot.gd`.

**Never hand-edit the rendered output.** Change the model or the render settings and regenerate.

## Audio

`assets/audio/music/` and `assets/audio/sfx/` come from the same source and the same CC0 licence:

| Pack | Source | Files |
|---|---|---|
| `music-jingles` | https://kenney.nl/assets/music-jingles | 86 |
| `rpg-audio` | https://kenney.nl/assets/rpg-audio | 52 |
| `impact-sounds` | https://kenney.nl/assets/impact-sounds | 130 |
