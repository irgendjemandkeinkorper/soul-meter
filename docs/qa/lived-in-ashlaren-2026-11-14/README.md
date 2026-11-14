# Lived-in Ashlaren — QA evidence (2026-11-14)

The M6 roll-out's first map after Kesselford (owner 2026-11-02: `Kesselford, then roll out`;
the plan's M6: "other exteriors … with the same kit and tool, each location its own PR").
Plan: `docs/design/map-lived-in-plan-2026-11-02.md`. Kesselford's evidence:
`docs/qa/lived-in-2026-11-02/` and `docs/qa/lived-in-rollout-2026-11-14/`.

## Captures (1920×1080, camera zoom 1; overview at zoom 0.5)

Rendered under Xvfb by `test/manual/lived_in_capture.gd` with `LIVED_IN_MAP=ashlaren`.
"Before" hides the generated dressing (`LIVED_IN_OFF=1`) on this branch, so it already has the
calmed ground, the hidden paving stamps and the rescaled old props; it is not `main`.

| Spot | Before | After |
|---|---|---|
| Overview | `ashlaren-overview-before.jpg` | `ashlaren-overview-after.jpg` |
| Weighing Hall front (1300, 860) | `ashlaren-weighing-hall-before.jpg` | `ashlaren-weighing-hall-after.jpg` |
| Millhouse front (1950, 860) | `ashlaren-millhouse-before.jpg` | `ashlaren-millhouse-after.jpg` |
| Warehouse yard (2400, 1300) | `ashlaren-warehouse-yard-before.jpg` | `ashlaren-warehouse-yard-after.jpg` |
| Road in from Kesselford (500, 950) | `ashlaren-road-in-before.jpg` | `ashlaren-road-in-after.jpg` |

## What changed

- **Dressing.** `world/dressing/ashlaren_lived_in.tscn`, seed 1114, the same 84 approved
  Kesselford sprites: 182 ground decals, 350 standing pieces (134 solid, 37 give cover), 362
  contact shadows. No new art. The ford pass does not run (Ashlaren has no ford stamps).
- **Road band.** The ten `PavingGrainRoad*` stamps mark the road and are hidden; the
  generated band follows them, as on Kesselford.
- **Calmed ground.** `ground_calm.gdshader` on the Dom backdrop, as the plan gives every
  map that shares it.
- **Old props at their height class (M2)** against the 112 px adult:

| Prop | Class | Before (px) | After (px) | Scale |
|---|---|---|---|---|
| Grain cart | head 108 | 149 | 112 | 0.6 → 0.45 |
| Yard brazier | waist 64 | 116 | 70 | 0.5 → 0.3 |
| Sealed-sack crates | head 108 | 139 | 109 | 0.6 → 0.47 |
| Yard crates | head 108 | 116 | 109 | 0.5 → 0.47 |
| Weighing board | tall 150 | 214 | 150 | 1 → 0.7 |
| Market stalls (2) | ~1.5 adults | 225 | 169 | 1 → 0.75 |
| Grass tufts (6) | knee 42 | 171 | 43 | 1 → 0.25 |
| Flower clusters (4) | knee 42 | 159 | 43 | 1 → 0.27 |

Facades, the bell house, the warehouse walls, trees, lanterns and the banner are unchanged.
Blocking is repainted for the smaller footprints.

Draw calls per frame, dressing off → on: weighing hall 23 → 277, millhouse 33 → 297,
warehouse yard 24 → 259, road in 24 → 248, overview 41 → 556. Frame time on real hardware
stays with FR-904 (owner item 14).

## Seen in the captures, not changed here

- Two brown door placeholders from the shared door scene (`WeighingHallDoor`,
  `MillhouseDoor`), as Kesselford had before its walk-in buildings.
- The warehouse challenge shows a yellow square marker and a "WAREHOUSE WATCH" label.
- A few wall-base clusters (a ladder, a broom) lean on the cart and the weighing board, which
  the dresser reads as structures.
