# Lived-in Kesselford — QA evidence (2026-11-02)

Plan and as-built notes: `docs/design/map-lived-in-plan-2026-11-02.md`. Owner review:
`docs/owner-decisions.md` item 32.

## Captures (1920×1080, camera zoom 1; overview at zoom 0.5)

Rendered under Xvfb by `test/manual/lived_in_capture.gd` with the HUD and title screen hidden.
"Before" is `origin/main` at `9e1ee0f9`; "after" is this branch, dressing seed 1102.

| Spot | Before | After |
|---|---|---|
| Overview | `before-overview.jpg` | `after-overview.jpg` |
| Wayhouse front (1150, 860) | `before-wayhouse.jpg` | `after-wayhouse.jpg` |
| Chandlery front (1900, 860) | `before-chandlery.jpg` | `after-chandlery.jpg` |
| South yards (1500, 1400) | `before-south-yards.jpg` | `after-south-yards.jpg` |

Draw calls on `main` (before): wayhouse 18, chandlery 28, south yards 16, overview 33.

Counts after: 211 ground decals, 272 standing pieces (79 solid, 11 cover), 284 contact
shadows, 79 Blocking cells painted at load.

## Sheets

- `sheet-ground.jpg`, `sheet-wall-bases.jpg`, `sheet-yard-street.jpg`,
  `sheet-growth-stories.jpg`: the 84 finished sprites for the owner's second approval. Each
  cell has a light thumbnail to check the alpha. S = solid, w = walkable, g = ground decal.
- `sheet-scale.jpg`: every standing sprite at its in-game size beside the 112 px adult, with
  its class height dashed.

## Checks

- `test/unit/test_lived_in_dresser.gd` (5): seeded, routes and keep-clear zones stay empty,
  solid pieces block their cell, walkable decor blocks nothing, wall bases get clusters.
- `test/integration/test_kesselford_lived_in.gd` (3): the dressing loads; its solid cells
  are painted into Blocking and are solid for pathfinding; cover cells carry the cover tile;
  spawns and exits stay clear; standing props cast shadows and facades do not.
- `test/integration/test_kesselford.gd` (7): unchanged anchors still resolve.

Headless runs cannot judge the look. The owner's playtest does.
