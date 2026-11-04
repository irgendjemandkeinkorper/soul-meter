# Walk-in buildings (owner list item 35, 2026-11-03; layouts 2026-11-04)

The party walks into a building on the map with no loading screen. The roof fades out while anyone in the party stands inside, and the walls in front of the party's room drop to stubs. Kesselford has four: the Ferry Bell Wayhouse (a tavern), the Ford Chandlery (a shop), and an unnamed cottage and warehouse south of the Dom road. Every other building keeps its painted facade and its door until it converts.

Rulings of 2026-11-03 (owner list §5):
- `Modular kit`
- `One prototype`
- `Placeholders now`
- `One-cell wall line`
- `Grow to 12 × 9` (replaced on 2026-11-04 by the 16 × 13 tavern layout)
- `Retire, redirect saves`
- Fights can happen inside ("yeah fights can happen there")
- `Shots pass windows`

Rulings of 2026-11-04 (owner list §5): "the variety of structure is more important than the color/skin/art for right now".
- `Your room opens`: inner walls stand; inside, only the walls in front of the party's room drop.
- `All four`: tavern, shop, cottage and warehouse layouts. The Wayhouse becomes the tavern and the Ford Chandlery the shop, whose room retires.
- `Cottage + warehouse south`: open ground south of the Dom road. Both are scenery, with no names or canon.

Plan pages: https://claude.ai/artifact/GJjChytsAWShKHGU9y1445 (the 2026-11-03 prototype) and https://claude.ai/artifact/1TVbWAnzJ6G113uWgqjFez (the layouts).

All looks, sizes and pieces are PROVISIONAL.

## Layouts

A layout is a `BuildingLayout` resource (`world/buildings/layouts/*.tres`): rows of text, back row first, one character per ground cell.

| Character | Cell |
|---|---|
| `#` | wall |
| `W` | window: a wall that stops a walk but not a shot |
| `D` | doorway |
| `.` | floor |
| space | outside the building |
| `B` `T` `S` `c` `F` `K` `E` | furniture on the floor: counter, table, shelves, chest, hearth, stove, bed. A run of the same letter is one piece. |

`BuildingPlan` reads a layout. It finds the rooms (floor regions walled apart, joined by doorways), the furniture pieces, the kit piece for each wall cell, the solid cells, the cells that stop a shot and the roof. `problems()` names what is wrong with a layout: uneven rows, unknown characters, floor open to the outside, a doorway or window that is not in a straight wall, furniture that is not a rectangle, or a room no outer doorway reaches. `test_building_plan.gd` checks the four layouts.

A building on the map is a `WalkInBuilding` node with a `layout`, an `origin_cell` (the ground cell under the grid's back corner) and `quarter_turns`. Each quarter turn puts the layout's front row on the right. To add a building, write a layout, place the node, render the kit (its roof and any new furniture size), and run `tools/paint_blocking.gd`.

## Kit spec for the Blender pieces

The kit uses the yaw (45°), orthographic projection and scale of `tools/render_isometric_sprites.gd` at its own pitch: 30° (asin ½). One model unit is one cell edge, and at 30° a 1 × 1 floor tile renders as the exact 64 × 32 ground diamond. One unit of height is about 39.2 px on screen.

Why not the sprite tool's pitch: its atan(½) (26.57°) draws a floor tile 64 × 28.6. A small prop hides that, but the 12 × 9 roof landed about 15 px off the ground grid at its corners, so the corner posts showed above it (fixed 2026-11-04). Units and props keep the sprite tool's pitch.

| Piece | Model size (units) | Notes |
|---|---|---|
| Floor tile | 1 × 1 | `floor-planks`; `floor-footing` (stone) under a wall cell |
| Wall | 1 long, 4 tall, 0.2 thick, in the middle of its cell | `wall-x`, `wall-z` (one per run direction); `wall-window-x`, `wall-window-z` |
| Half wall | ½ long, from the cell's middle to its edge | `wall-half-x`, `wall-half-z`, for corners, junctions and wall ends |
| Wall stub | the same, 0.5 tall | `wall-stub-*`, `wall-stub-half-*`: the cutaway forms |
| Lintel | 1 long, the top 1 of 4 | stands over each doorway cell; the doorway opening is 3 tall; it goes when its wall drops |
| Post | 0.26 square, 4 tall (stub 0.5) | where walls meet or end |
| Pillar | 0.5 square, 4 tall (stub 0.5), stone | a wall cell with no wall beside it |
| Roof | the whole footprint | one piece per layout and turn (`roof-<layout>-t<turns>`); see below |
| Furniture | its cells, 0.1 in from their edges | `<kind>-<w>x<h>` for each size the layouts use: counter, table, shelves, chest (one per cell), hearth, stove, bed |

**Roof.** The roof is worked out from the footprint's outline, so a new layout needs no roof work. Every point rises at 30° with its distance from the outside: slopes from each outer wall meet in ridges and hips, and valleys form where wings join. Its edge sits 0.03 over the wall tops at the wall line. The roof's pivot is the grid's back corner; on the map it sorts at the footprint's front-most point, so anyone in front draws over it.

Each piece is a transparent PNG with a pivot in `building_kit.json`. A floor tile's pivot is its centre. A wall, stub, lintel, post or pillar's pivot is the middle of its base. A piece of furniture's pivot is the centre of its footprint, where its body stands on the map. A piece of furniture longer along z is the x piece turned a quarter. To replace a placeholder, keep the file name, write the new image, and set its pivot in the manifest.

The placeholders come from `tools/render_building_kit.gd`, which renders the Kenney Fantasy Town models (CC0, already in the repository). The furniture is plain boxes in wood tones, because the Kenney kits have no counter, table or chest:

```
cp project.godot /tmp/project.godot.bak
sed -i '/^Pandora=/a BuildingKitRender="*res://tools/render_building_kit.gd"' project.godot
SOUL_METER_BUILDING_KIT=1 xvfb-run -a -s "-screen 0 1280x1024x24" "$GODOT_BIN" --path .
cp /tmp/project.godot.bak project.godot
"$GODOT_BIN" --headless --path . --import
```

## How a building works

- **Pieces:** in `_ready` the building places a floor tile per cell, a kit piece for every wall piece of the plan, the furniture and the roof.
- **Looks:**
  - OUTSIDE: the roof is on and every wall stands.
  - SEEN_THROUGH: someone stands behind the building, under its roof's silhouette, so the roof and walls fade to `DS.FACADE_OCCLUDED_ALPHA`.
  - INSIDE: a party member's feet are on the footprint. The roof fades out. The walls in front of the party's rooms drop to stubs, and a doorway in them loses its lintel. A wall of another room that would hide part of the party's rooms fades. Every other wall stands, so a room nobody is in stays tucked away until someone walks in (`Your room opens`).
- **Walls:** walls, windows and furniture are solid cells. `tools/paint_blocking.gd` writes them into the scene as the building's `WallBody` shapes (one per rectangle of `solid_rects()`) and paints them into the map's Blocking layer. Run it after you add, move, turn or change a building. `test_walk_in_buildings` and `test_blocking_paint` fail until you do.
- **Thin cells:** every painted cell on a footprint uses the blocking tile's thin variant (`BlockingLayer.THIN_TILE`).
  - Why: the player's walk grid keeps one cell of clearance round a solid cell, because the tile's collision is the whole diamond. With ordinary cells, that clearance would close the doorways and most rooms.
  - What changes: a thin cell gets no clearance ring, and its collision is an inset diamond. The `WallBody` shapes stand 3 px in from their cells' edges, so the player's 30 × 22 box clears them from the next cell.
  - A fight on a live map uses the same grid as walking, so it sees the same open rooms. Cells outside walk-in buildings are unchanged.
- **Line of fire:** fights can happen inside (ruled 2026-11-03). A painted cell stops a walk but not a shot, so the same tool also writes the wall cells into the map's combat terrain (`CombatTerrainLayer.blocks_fire_cells`). Windows, doorways and furniture let a shot through (`Shots pass windows`); walls stop it.
- **People:** a building's people use an outdoor placement anchor on the map, such as `kesselford_wayhouse_floor` → `WayhouseKeeperSpot` in `tools/seed_town_npcs.gd`, with zero jitter. A shop's vendors are `vendor_ids` on the building; they stand at `vendor_cell`, behind the counter, and trade across it (interaction radius 96 px).

## Retiring a building's room

When a building converts, its interior scene, location and door transitions go, and its vendors move to the building's `vendor_ids`. Its location id is added to `LocationRegistry.RETIRED` with the map and an inside spawn, so a save made in the old room loads inside the building. Spawns that other code uses outside the door stay.
