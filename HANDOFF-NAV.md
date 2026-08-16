# Issue #203 — Field Navigation / Presentation Handoff

## Status

Complete on `fix/field-nav-cluster`. The affected suites and the full suite are green.

## Per-case verdicts

1. `test_actor_presentation.gd:12` invalid `Enemy.visual_region` assignment — **stale test**.
   Commit `cd59a8e` removed the Kenney atlas exports and made `Enemy` resolve full painterly textures through `UnitArt`. The test still assigned the deleted properties. It now verifies the resolved texture, disabled atlas region, painterly foot offset, unit scale, and white modulation.
2. `test_y_sort` Iris sprite node position — **stale test**.
   `UnitArt.PIVOT_OFFSET` now places foot contact at the actor origin while resolver-driven NPC sprites remain at local node position zero. The old `sprite.position.y < 0` expectation predated that contract; the test now checks the shared painterly offset.
3. `test_click_to_move` destination distance (`54.4px`, expected `<20px`) — **source bug**.
   Dom's `Blocking` layer is scaled to `2.2`, but `IsoGrid` baked its authored cell IDs directly into Ground cell space. AStar and physics therefore disagreed about the wall's world footprint. Field navigation now explicitly projects transformed blocking diamonds into Ground cells and applies one cell of body clearance.
4. `test_click_to_move` path remained active — **source bug**.
   Periodic repaths could retain the start-cell centre behind the moving body, and a frame could step across a waypoint without entering the fixed epsilon. The controller now drops the AStar start cell by cell identity and recognizes segment crossings. The route coordinates and frame budget were also stale after the 3400x2200 Dom layout and are documented inline.
5. `test_click_to_move_input` blocked target outside the viewport — **stale test**.
   Hardcoded Blocking cell `(29,33)` came from the pre-rework layout. The acceptance test now selects a painted, transformed obstacle that is actually visible through the live camera transform.
6. `test_click_to_move_input` returned `blocked_by_unreachable` instead of `blocked_by_obstacle` — **source bug**.
   The unprojected Blocking/Ground transform mismatch classified the physical obstacle target in the wrong navigation space. The click controller's projected grid now classifies it as an obstacle.
7. `test_click_to_move_input` returned no `nearest_unblock` (`TYPE_NIL` instead of `TYPE_VECTOR2`) — **source bug**.
   This was downstream of the same out-of-bounds/unreachable misclassification. With the transformed obstacle baked into Ground space, the obstacle refusal performs its bounded neighbor search and returns a world-space unblock point.

## Changed files

- `world/nav/iso_grid.gd` — opt-in transformed Blocking projection and configurable static clearance; aligned/default consumers retain exact authored-cell behavior.
- `actors/player/click_move_controller.gd` — enables field projection/clearance and makes waypoint completion robust across repaths and frame steps.
- `test/unit/test_actor_presentation.gd` — verifies the painterly `UnitArt` enemy contract.
- `test/integration/test_y_sort.gd` — verifies painterly foot offsets and the current nested Registry Archive door prop.
- `test/integration/test_click_to_move.gd` — uses current-layout obstacle coordinates/targets and preserves the arrival and queue-drained assertions.
- `test/nav_acceptance/test_click_to_move_input.gd` — clicks a visible current-layout transformed obstacle.

## Verification

- `test/unit/test_iso_grid.gd`: 15 cases, 0 failures.
- `test/unit/test_actor_presentation.gd`: 2 cases, 0 failures.
- `test/integration/test_y_sort.gd`: 7 cases, 0 failures.
- `test/integration/test_click_to_move.gd`: 8 cases, 0 failures (also passed twice consecutively during flake checking).
- `test/nav_acceptance/test_click_to_move_input.gd`: 1 case, 0 failures.
- `test/integration/test_blocking_layer.gd`: 2 cases, 0 failures (compatibility guard for default aligned-cell behavior).
- Full command: `DISPLAY=:0 GODOT_BIN=~/.local/bin/godot bash scripts/test.sh`
- Full result: exit 0; 114 suites, **740 cases**, 0 errors, 0 failures, 0 flaky, 0 skipped, 0 orphans; 43.433s.

The delegation brief expected 731 cases; this checkout's runner currently discovers 740. The acceptance condition is otherwise stronger: every discovered case passed.

## Risks

- Projected field-grid rebuilds sample five points for each used Ground cell. Dom's 54x69 map makes this bounded (at most 18,630 samples per rebuild), but much larger future field maps may merit caching or dirty-region updates.
- Static clearance is intentionally opt-in through `ClickMoveController`; direct/default `IsoGrid` consumers, including tactical code, retain exact cell semantics.

## Open questions

- Why the brief's historical suite count is 731 while this branch discovers 740 was not investigated; no cases are skipped or failing.

## Recommended next action

Planner/Claude review the commit and the opt-in `IsoGrid.build(..., project_blocking_to_ground)` boundary, then merge through the normal workflow.
