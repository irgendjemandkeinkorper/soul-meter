# Called-shot HUD selection — 2026-09-19

Task 4 in [the combat expansion checklist](../../tasks/called-shots-and-injuries.md) is implemented: the real battle interface offers the armed action's authored locations and submits the chosen aim through the controller.

## Behavior verified

- Hovering an enemy with an action that carries `aim_profiles` rebuilds an aim row in the forecast panel: ORDINARY plus one button per authored location, labelled from the target's anatomy. Ordinary actions show no row.
- Every location is quoted through `CombatController.forecast_action`, so a location the controller would refuse (covered arm, missing throat, unaffordable surcharge) stays visible but disabled with the controller's message as its tooltip.
- Selecting a location arms it for the selected action; the next hover shows the aim penalty inside the accuracy terms plus an `AIM … · COST … · NO INJURY EFFECT YET` line priced for the active scheduler. Pressing the enemy submits with `aim_location` and pays the surcharged AP.
- ORDINARY cancels the aim; re-arming any action through `select_pointer_action` clears the aim and the row. A stale aim against a target that cannot take it is refused by the controller without spending.
- Buttons are ordinary focusable controls, so existing keyboard/controller focus navigation reaches them. No dedicated `ui_cancel` binding was added.

## Automated evidence

Godot 4.7.1, `scripts/test.sh` under Xvfb, `LP_NUM_THREADS=1`, disposable `SOUL_METER_TEST_DATA_DIR`.

| Suites | Result |
|---|---|
| Battle interface (incl. new aim-row test), called shots, forecast regions, rendered aim-row capture | 24 passed; 0 failed |
| Battle stage, unit plate, battle HUD, wave-1 battle screen, screen formatting, combat lab | 49 passed; 0 failed (run with the capture before its SubViewport change) |

## Rendered evidence

`test/manual/aim_row_capture.gd` renders the real interface in a private SubViewport at the 1920×1080 design frame with the throat aim armed. Bounds checks pass and the capture was inspected: the aim row (ORDINARY / TORSO / SHIELD ARM disabled / THROAT selected) and the aim line fit inside the forecast panel.

- [1920×1080 aim row](called-shot-hud-2026-09-19/aim-row-1920.png)

At a raw 1280×720 viewport the panel overflows by roughly 47 px; the design system fixes the frame at 1920×1080 and scales smaller windows, so that viewport is not a supported layout and is not asserted.

## Not covered

No production action authors `aim_profiles` yet (task 11), so the row never appears in a shipped encounter. The injury consequence line was added by task 7 (see `called-shot-injury-2026-09-19.md`); `aim-row-1920.png` was recaptured then. Controller/keyboard navigation was not exercised with real input events.
