# Navigation acceptance audit — issues #161, #162, and #191

Audited against the issue text on 2026-08-08. Ratings mean:

- **Met:** implementation and behavioral evidence cover the criterion.
- **Partially met:** relevant implementation exists, but the criterion is only indirectly or
  incompletely proved.
- **Unmet:** the repository contradicts the literal criterion or lacks the required behavior.

## Issue #161 — Blocking TileMapLayer

1. **Partially met — `Blocking` exists on the y-sorted scene root, but not under a node named
   `YSortRoot`.** The scene root is `StartingTown` with `y_sort_enabled = true`
   (`world/starting_town.tscn:52-53`), and `Blocking` is its direct `TileMapLayer` child
   (`world/starting_town.tscn:84-89`). This satisfies the apparent structural intent but not the
   criterion's literal `YSortRoot` hierarchy.

2. **Met — painted cells are the shared static source for pathfinding and physics.** The scene
   owns opaque but non-empty `tile_map_data` and assigns `blocking_tiles.tres`
   (`world/starting_town.tscn:79-89`). `IsoGrid` iterates that same layer's `get_used_cells()` and
   marks the AStar points solid (`world/nav/iso_grid.gd:49-75`). The assigned TileSet defines a
   diamond physics polygon and collision layer (`world/nav/blocking_tiles.tres:5-16`). The
   integration test independently exercises both consumers (`test/integration/test_blocking_layer.gd:12-53`
   and `:56-89`).

3. **Partially met — some Dom building footprints are proved, not all buildings.** The painted
   byte array exists (`world/starting_town.tscn:84-89`), and tests identify/assert a TrialHall
   solid cell (`test/integration/test_blocking_layer.gd:27-53`) and a PlayersHouse solid cell
   (`test/integration/test_blocking_layer.gd:63-66`). There is no test or readable mapping that
   enumerates every Dom building and proves its visual footprint overlaps blocking cells.

4. **Met — a path cannot cross a blocking cell.** The test builds `IsoGrid` from the real town
   layers, proves the endpoints are open, proves a route exists, checks every returned cell is
   absent from `Blocking`, and refuses a destination inside TrialHall
   (`test/integration/test_blocking_layer.gd:12-53`).

5. **Met — a physics body cannot enter a blocking cell.** A real `CharacterBody2D` is driven at
   the PlayersHouse cell; the test requires a slide collision and requires the body to remain
   outside the cell (`test/integration/test_blocking_layer.gd:56-89`).

6. **Partially met — the relevant `test_room` suites exist, but this audit could not complete a
   display-backed full-suite run.** Movement, wall collision, and NPC-range behavior are asserted
   in `test/integration/test_field_room.gd:8-59`. Their existence is useful evidence, but the
   criterion says they still *pass*; the host's Xvfb failure described below prevented a fresh
   headed/full verification.

## Issue #162 — click-to-move controller

1. **Met — the component exists and Player remains a `CharacterBody2D`.** The controller is a
   named class extending `Node` (`actors/player/click_move_controller.gd:1-2`), while Player
   extends `CharacterBody2D` (`actors/player/player.gd:1-2`) and the scene attaches the controller
   as a child (`actors/player/player.tscn:3-5`, `:10-11`, `:37-38`).

2. **Partially met — routing and physical arrival around real town obstacle data are proved, but
   the click-to-arrival chain is split across tests.** The existing test duplicates the real
   town ground/blocking layers (`test/integration/test_click_to_move.gd:38-68`), proves the direct
   route crosses a building, requests a path, advances physics, and verifies arrival
   (`test/integration/test_click_to_move.gd:71-111`). The new viewport test proves real input
   dispatch for a refused click (`test/nav_acceptance/test_click_to_move_input.gd:13-72`), but no
   single test proves viewport click → route around building → arrival in the complete town.

3. **Met at the controller/player seam — unreachable clicks return and emit the complete refusal
   shape.** Production creates all four required keys and emits them
   (`actors/player/click_move_controller.gd:266-277`); Player re-emits the refusal
   (`actors/player/player.gd:15-17`, `:40-48`). The new viewport test verifies an actual
   `Viewport.push_input()` click reaches that path and checks all keys plus both signals
   (`test/nav_acceptance/test_click_to_move_input.gd:35-72`). **Player-facing UI remains unmet:**
   no production subscriber to `Player.move_refused` exists, so a human cannot currently see the
   message; the manual checklist intentionally records that as a failure.

4. **Partially met — periodic recalculation is implemented but obstacle-change behavior is not
   tested.** An active route starts a repeating timer (`actors/player/click_move_controller.gd:57-64`,
   `:148-151`); timeout calls `refresh_path()`, which rebuilds the grid and reroutes or stops
   (`actors/player/click_move_controller.gd:232-251`). No navigation test changes an obstacle
   mid-route and proves the new route is used.

5. **Partially met — spacing is guarded, footsteps working is not.** Player still accumulates
   actual motion and plays a footstep at `FOOTSTEP_SPACING` (`actors/player/player.gd:24-31`,
   `:68-86`), and the test locks the constant to 78 px
   (`test/integration/test_click_to_move.gd:259-264`). No test proves click-driven motion triggers
   audio at the same cadence.

6. **Met — `facing_direction` updates during click movement.** Player updates it from the chosen
   direction (`actors/player/player.gd:51-65`), and an integration test requires eastward facing
   after following an eastward click path (`test/integration/test_click_to_move.gd:238-256`).

7. **Met — WASD remains functional and cancels click movement.** Player reads the four movement
   actions and cancels the click path when keyboard input is non-zero
   (`actors/player/player.gd:51-58`). The integration test verifies both cancellation and actual
   leftward movement (`test/integration/test_click_to_move.gd:211-235`).

## Issue #191 — real viewport input path

`test/nav_acceptance/test_click_to_move_input.gd` closes the consumer-seam weakness in test
design: it places the real `starting_town.tscn` inside an isolated `SubViewport`, constructs a
real `InputEventMouseButton` at an asserted in-viewport position, calls
`SubViewport.push_input()`, and observes controller and Player refusal signals. It never calls
`_unhandled_input()` directly (`test/nav_acceptance/test_click_to_move_input.gd:13-72`). The
isolated viewport prevents unrelated root-level `Control` nodes from swallowing the event.

The test passed headlessly: **1 case, 0 errors, 0 failures, 0 skipped**. That proves Godot's
explicit viewport dispatch reaches `_unhandled_input`; gdUnit4's warning about transported OS
input does not apply to an explicit `Viewport.push_input()` call.

Display-backed verification was attempted and did **not** run. The exact Xvfb error was:

```text
_XSERVTransmkdir: Owner of /tmp/.X11-unix should be set to root
_XSERVTransmkdir: Mode of /tmp/.X11-unix should be set to 1777
Fatal server error: Cannot establish any listening sockets
```

On this host, `/tmp/.X11-unix` is owned by `nobody:nogroup` with mode `0777`, and the sandbox
cannot repair the system directory. Godot consequently reports `X11 Display is not available`.
Because a display-backed result and a full-suite result remain unproved here,
`manual_click_to_move.md` is included as the explicit fallback; do not claim #191 fully closed
until the automated test passes under a healthy Xvfb display and in the full suite.

The requested addon wrapper also cannot discover tests on Godot 4.7.1: it passes
`--remote-debug tcp://127.0.0.1:0`, producing `The remote port number must be between 1 and 65535`
before aborting. `scripts/test.sh` is the repository-documented compatible runner.
