# Called-shot line of fire and exposure — 2026-09-19

Task 5 in [the combat expansion checklist](../../tasks/called-shots-and-injuries.md) is implemented: a blocked shot and a partially exposed target are now different answers from the grid, and aiming consumes both.

## Behavior verified

- **Solid obstacle.** `GridBattlefieldModel.set_obstacle()` (or a Terrain tile with `blocks_fire = true` custom data) blocks line of fire with its own reason, `blocked_by_obstacle`, alongside the existing `blocked_by_elevation` and `blocked_by_occupancy`. Ordinary and aimed shots refuse identically at forecast and commit, before any chance is computed, so the minimum hit chance can never bypass a wall. The navigation blocking layer is deliberately not reused: a fence or shallow water does not silently stop a shot.
- **Partial exposure.** `location_cover(actor, target)` reports whether the target hugs a cover cell toward the attacker (the same directional rule as the cover bonus). Anatomy locations authored `hidden_by_cover: true` refuse with `aim_cover` while covered; the rest stay targetable. An attacker standing above the target sees over low cover (`seen_over`), matching the line-of-sight rule. Cover beside the attacker, or behind the target, hides nothing. Facing plays no part: a low wall hides the same parts from any side.
- **No double charge.** Exposure adds no accuracy term. The ordinary attack keeps its legacy cover damage mitigation, and an aimed shot at an exposed location keeps the same mitigation, so generic cover is never charged as both a hit penalty and a damage reduction. Switching cover from mitigation to a hit penalty needs a ratified value and is not done here.
- **Lab fixture.** Anatomy fixture `low_cover` seats one cover cell beside the wight on the party's side; the fixture torso is authored cover-hidden.

## Automated evidence

Godot 4.7.1, `scripts/test.sh` under Xvfb, `LP_NUM_THREADS=1`, disposable `SOUL_METER_TEST_DATA_DIR`.

| Suites | Result |
|---|---|
| Grid battlefield model (+2), called shots (+2, both schedulers), combat lab (+1), combat controller | 127 passed; 0 failed |
| Lab low-cover capture, combat session, battle interface, battle HUD, stage, unit plate, forecast regions, resolution, battlefield authoring, battle default grid, battle, wave-1 screen | 94 passed; 0 failed |

## Rendered evidence

`test/manual/lab_low_cover_capture.gd` opens the real combat lab overlay on the test room with the `low_cover` fixture and captures both states. Inspected:

- [Torso hidden](called-shot-exposure-2026-09-19/lab-low-cover-torso.png): the quote reads the controller's reason and FIRE LAB SHOT is disabled.
- [Throat open](called-shot-exposure-2026-09-19/lab-low-cover-throat.png): COST 2 AP, HIT 41%, Aim: Throat −25 pp, fire enabled.

The boot menu behind the overlay is the test process's current scene; the lab is a CanvasLayer above it.

## Not covered

No production terrain authors `blocks_fire` or cover-hidden anatomy yet (task 11). The `seen_over` result is not shown in any UI. Cover as an accuracy penalty remains an unratified proposal.
