# Chapter One field UX — Wave 0 symptom capture

Run date: 2026-09-13. Scope: `res://world/starting_town.tscn` and
`res://world/interiors/dom_tavern.tscn`. The test used 40 settle frames, then
three frames per town placement, and the requested `rest_on_grid()` call.

## Town facade evidence

All three facade nodes are 512×768 textures with offset `(0,-384)`, z-index 0.
The town root has `y_sort_enabled = true`; `Player` also has y-sort enabled and
its `Sprite2D` is visible, white-modulated, and z-index 0. `under_facade` below
means `player.global_position.y < building.global_position.y`, the ordering
that puts the player behind the building root under the current y-sort contract.

| Frame | Requested → actual position | Ordering | Feet texture pixel / alpha | Screen rect intersects opaque facade |
|---|---|---|---|---|
| town_four_arms_tavern_front_40 | (1700,1760) → (1700,1764) | under | (256,732) / 0.000 | yes |
| town_four_arms_tavern_front_120 | (1700,1680) → (1700,1663.93) | under | (256,631) / 1.000 | yes |
| town_four_arms_tavern_front_250 | (1700,1550) → (1700,1540) | under | (256,508) / 1.000 | yes |
| town_four_arms_tavern_left_120 | (1500,1680) → (1508,1668) | under | (64,636) / 1.000 | yes |
| town_four_arms_tavern_right_120 | (1900,1680) → (1892,1668) | under | (448,636) / 0.988 | yes |
| town_town_hall_front_40 | (2400,1060) → (2404,1060) | under | (260,728) / 0.000 | yes |
| town_town_hall_front_120 | (2400,980) → (2404,964) | under | (260,632) / 1.000 | yes |
| town_town_hall_front_250 | (2400,850) → (2404,836) | under | (260,504) / 1.000 | yes |
| town_town_hall_left_120 | (2200,980) → (2212,964) | under | (68,632) / 1.000 | yes |
| town_town_hall_right_120 | (2600,980) → (2596,964) | under | (452,632) / 0.000 | yes |
| town_trial_hall_front_40 | (1000,460) → (996,452) | under | (252,720) / 0.000 | yes |
| town_trial_hall_front_120 | (1000,380) → (996,388) | under | (252,656) / 1.000 | yes |
| town_trial_hall_front_250 | (1000,250) → (996,260) | under | (252,528) / 1.000 | yes |
| town_trial_hall_left_120 | (800,380) → (804,388) | under | (60,656) / 0.000 | yes |
| town_trial_hall_right_120 | (1200,380) → (1188,388) | under | (444,656) / 1.000 | yes |

Root cause statement (a): the actor is not disabled; it is structurally drawn
behind the facade whenever it is above the building origin in world Y. The
facade has no occlusion/fade owner: `starting_town.gd:26-34` only hides the old
kit Sprite2D children, while the facade remains a single opaque Sprite2D at
`starting_town.tscn:189-194`, `485-490`, and `795-800`. The diagnostic geometry
therefore identifies painter-order plus opaque texture overlap as the cause of
the vanish symptom. A rendered visual confirmation was not possible here.

## Interior evidence

`TavernDoor` is a custom `TavernDoor`, not a `BuildingDoor`; it has no
`transition_id`. `actors/tavern_door/tavern_door.gd:42-43` sends travel directly
to `GameFlow.TAVERN_SCENE` with spawn `entry`. With `SaveGame.pending_spawn_id =
&"entry"`, the player settled at `(480,533.07)`. `Sprite2D.visible = true`,
modulate `(1,1,1,1)`, z-index 0, and the point is inside `Floor` polygon
`(0,0)-(960,640)`. `Title` is present but does not overlap the player position;
`Walls` is collision-only and does not overlap; `ExitDoorSprite` overlaps and is
tree index 14. The player is authored later at tree index 16, so the candidate
draw order is `ExitDoorSprite → Player` under the root y-sort (`dom_tavern.tscn:45-47`,
`286-311`).

Root cause statement (b): no interior invisibility was reproduced in the
available runtime data. The player’s visibility and modulate are normal, the
spawn is inside the floor, and the only overlapping drawn node is the exit-door
sprite, authored before the player. The remaining uncertainty is rendered
camera/y-sort behavior, not an identified hidden flag or modulate assignment;
the requested X11 capture could not run in this sandbox.

## Cyan diagonal owner

The two town diagonals are the visible sides of the closed `Waterline` Line2D,
not travel-exit or click-path debug. `world/starting_town.tscn:124-129` uses the
town shoreline points, width 5, color `(0.12,0.56,0.68,0.72)`, and z-index -14.
`actors/travel_exit/travel_exit.tscn:6-12` has only `SignSprite`; it has no
Line2D/Polygon2D boundary. `ClickMoveController` exposes path signals and input
handling (`actors/player/click_move_controller.gd:21-23`, `71-79`) but no draw
method or path debug line. `Waterline` is not gated by `OS.is_debug_build()`.

## Reproduction and evidence limitation

The exact requested command failed before gdUnit4 because the sandbox’s shared
`/tmp/.X11-unix` is read-only and owned by `nobody`; Xvfb could not bind a
listener, so 0 tests and 0 PNGs ran. The headless fallback passed 1 test with 0
errors and 0 failures and emitted all diagnostics, but Godot’s dummy renderer
returned no viewport image (`WAVE0_PNG_UNAVAILABLE`), so no rendered PNGs were
copied to `docs/qa/wave0/`. The visual “fully invisible” frames, and the exact
interior rendered vanish, remain unreproduced.

## Rendered confirmation (Fable, host Xvfb, 2026-09-13)

Re-ran `test/manual/ch1_field_ux_wave0.gd` through `scripts/test.sh` on the host
(Xvfb available): 1 test, 0 failures, 16 PNGs. Five frames kept in `docs/qa/wave0/`.

- (a) **Confirmed.** `town_four_arms_tavern_front_120.png`: player at (1700,1664),
  feet alpha 1.0 → Vex is fully hidden behind the tavern facade; only followers
  south of the origin are visible. Same in `town_town_hall_front_120.png` and
  `town_trial_hall_front_120.png`.
- (b) **Not reproduced as invisible; reproduced as "standing inside the door".**
  `SpawnEntry` (480,510) sits 27 px below `ExitDoorSprite` (480,482.6), so the
  player y-sorts on top of the door art and spawns in the doorway, overlapping
  the "E — Enter" prompt. Note: the interior PNG also shows the town scene behind
  it because the test kept both scene runners alive — test artifact, not a bug.
- Cyan lines: `Waterline` Line2D (`starting_town.tscn:124-129`) is a blockout
  leftover; the terrain plate already paints the shore.
