# Walk-in buildings (owner list item 35, 2026-11-03)

The party walks into a building on the map with no loading screen. The roof fades out and the front walls drop to stubs while anyone in the party stands inside. The prototype is the Ferry Bell Wayhouse on the Kesselford map. Every other building keeps its painted facade and its door until it converts.

Rulings of 2026-11-03 (owner list §5):
- `Modular kit`
- `One prototype`
- `Placeholders now`
- `One-cell wall line`
- `Grow to 12 × 9`
- `Retire, redirect saves`
- Fights can happen inside ("yeah fights can happen there")
- `Shots pass windows`

Plan page with mockups: https://claude.ai/artifact/GJjChytsAWShKHGU9y1445

All looks, sizes and pieces are PROVISIONAL.

## Kit spec for the Blender pieces

The kit uses the camera of `tools/render_isometric_sprites.gd`: yaw 45°, pitch atan(½) (26.57°), orthographic. One model unit is one cell edge, so a 1 × 1 floor tile renders as the 64 × 32 ground diamond. One unit of height is about 40.5 px on screen.

| Piece | Model size (units) | Notes |
|---|---|---|
| Floor tile | 1 × 1 | `floor-planks` |
| Wall | 1 long, 4 tall, 0.2 thick | `wall-x`, `wall-z` (one per run direction); window variants `wall-window-x`, `wall-window-z` |
| Wall stub | 1 long, 0.5 tall | the cutaway form of every front wall piece |
| Lintel | 1 long, the top 1 of 4 | stands over each doorway cell; the doorway opening is 3 tall |
| Post | 4 tall (stub 0.5) | at the corners and the door jambs |
| Roof | the whole footprint, 35° pitch, 0.3 overhang | one piece per footprint size (`roof-12x9`) |

Each piece is a transparent PNG with a pivot in `building_kit.json`. A floor tile's pivot is its centre. A wall, stub, lintel or post's pivot is the middle of its base. The roof's pivot is the footprint's front (bottom) corner, so a person inside the building draws under it. To replace a placeholder, keep the file name, write the new image, and set its pivot in the manifest.

The placeholders come from `tools/render_building_kit.gd`, which renders the Kenney Fantasy Town models (CC0, already in the repository):

```
cp project.godot /tmp/project.godot.bak
sed -i '/^Pandora=/a BuildingKitRender="*res://tools/render_building_kit.gd"' project.godot
SOUL_METER_BUILDING_KIT=1 xvfb-run -a -s "-screen 0 1280x1024x24" "$GODOT_BIN" --path .
cp /tmp/project.godot.bak project.godot
"$GODOT_BIN" --headless --path . --import
```

## How a building works

- **Footprint:** `WalkInBuilding` holds a footprint of ground cells (`origin_cell` is the back corner, `cells` the size). It also holds a doorway (`door_side`, `door_start`, `door_width`) and the window cells for each side. In `_ready` it places the kit pieces: a floor tile per cell, a wall on every outer cell edge, a lintel over the doorway, posts, and the roof.
- **Looks:**
  - OUTSIDE: the roof is on and the back walls are hidden under it.
  - SEEN_THROUGH: someone stands behind the building, so the roof and front walls fade to `DS.FACADE_OCCLUDED_ALPHA`.
  - INSIDE: a party member's feet are on the footprint. The roof and the full front walls fade out, and the stubs and back walls show.
- **Walls:** the outer ring of footprint cells is solid, except the doorway. `tools/paint_blocking.gd` writes the ring into the scene as the building's `WallBody` shapes and paints them into the map's Blocking layer. Run it after you place, move or resize a building, or after you change its doorway. `test_walk_in_wayhouse` and `test_blocking_paint` fail until you do.
- **Thin cells:** every painted cell inside a footprint uses the blocking tile's thin variant (`BlockingLayer.THIN_TILE`).
  - Why: the player's walk grid keeps one cell of clearance round a solid cell, because the tile's collision is the whole diamond. With ordinary cells, that clearance would close a two-cell doorway and most of the room.
  - What changes: a thin cell gets no clearance ring, and its collision is an inset diamond. The `WallBody` strips and the furniture shapes stand 3 px in from their cells' edges, so the player's 30 × 22 box clears them from the next cell.
  - A fight on a live map uses the same grid as walking, so it sees the same open room. Cells outside walk-in buildings are unchanged.
- **Line of fire:** fights can happen inside (ruled 2026-11-03). A painted cell stops a walk but not a shot, so the same tool also writes the wall cells into the map's combat terrain (`CombatTerrainLayer.blocks_fire_cells`, the `blocks_fire` alternative of the plain terrain tile). A shot through the doorway or a window passes (`Shots pass windows`, 2026-11-03); a window still stops a walk. A corner cell passes a shot only when both of its wall pieces have a window. A shot through a wall is blocked. Furniture does not block shots.
- **Furniture:** a piece of furniture is a `StaticBody2D` whose position is the centre of its footprint, so the y-sort sees people correctly on either side of it. Its shape covers whole cells, and it stands under the map's `SolidProps`.
- **People:** a building's people use an outdoor placement anchor on the map, such as `kesselford_wayhouse_floor` → `WayhouseKeeperSpot` in `tools/seed_town_npcs.gd`, with zero jitter.

## Retiring a building's room

When a building converts, its interior scene, location and door transitions go. Its location id is added to `LocationRegistry.RETIRED` with the map and an inside spawn, so a save made in the old room loads inside the building. Spawns that other code uses outside the door stay.
