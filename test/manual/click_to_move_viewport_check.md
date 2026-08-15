# Click-to-move viewport input check

The headless unit suite verifies that click input is classified and translated
from screen space to world space without a viewport. Godot does not dispatch
viewport `InputEvent`s reliably in headless mode, so the final engine-dispatch
boundary remains a manual check.

## Check

1. Run the project with a display and enter the starting town.
2. Left-click open ground several tiles away from the player.
3. Confirm the player begins moving toward the clicked world position.
4. Right-click the same ground, then release the left button over it without
   first pressing there.
5. Confirm neither rejected event starts or replaces the active route.
6. While a click route is active, press a movement key and confirm keyboard
   movement still cancels click-to-move.
7. Watch the output panel throughout and confirm no new `SCRIPT ERROR` or
   `ERROR` is emitted by click input handling.

This verifies the residual path from the real viewport through
`ClickMoveController._unhandled_input()`, including marking an accepted click
as handled. The pure event classification and coordinate conversion are covered
by `test/unit/test_click_move_input_translation.gd`; pathfinding and movement
behavior remain covered by `test/integration/test_click_to_move.gd`.
