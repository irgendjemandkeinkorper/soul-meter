# Called-shot feedback — 2026-09-21

Selecting an anatomical aim now immediately displays a compact quote for the inspected
target. Previously the player had to hover the battlefield again, and the important
numbers appeared after the full damage calculation.

## Observable changes

- Aim buttons come first. Brackets identify the selected location independently of color.
- A framed summary shows hit chance, the active scheduler's total cost, conditional damage,
  and separately labeled injury chances on hit and overall.
- Possible serious injuries have an explicit severity label and a reminder that they persist
  after combat until treated. Below the escalation threshold, the required damage is shown.
- “Show combat details” expands the existing element controls, affinities, and full calculation.
  Actions without aim profiles retain their existing detailed view.
- Keyboard activation retains focus, previewing spends no action points, and refusals replace
  stale probabilities with their reason. Unrevealed hidden damage stays masked on future hits
  and misses. Combat rules, injury thresholds, and save formats are unchanged.

Presentation is owned by `ForecastPanelRegion`; `BattleInterface` requests fresh controller
quotes when the aim changes. The warning style uses a theme variation and DS tokens.
The new presentation sources are registered for Godot's PO/gettext extraction.

## Rendered evidence

Godot 4.7.1, Xvfb, isolated user data, fixed 1920×1080 design frame. Both captures were inspected.

- [Compact serious-injury quote](called-shot-feedback-2026-09-21/serious-aim-1920.png)
- [Expanded combat details](called-shot-feedback-2026-09-21/serious-aim-details-1920.png)

The compact panel exposes the decision without the calculation wall. The expanded panel
and all its visible contents remain within the design frame. Minor throat and head-aim
captures were also inspected from the disposable QA output.

## Verification

Run through `scripts/test.sh`, with `LP_NUM_THREADS=1` and separate disposable
`SOUL_METER_TEST_DATA_DIR` paths under `/tmp`. Xvfb required execution outside the filesystem
sandbox because the sandboxed process could not connect to its X11 display.

| Suites | Cases | Result |
|---|---:|---|
| `test/integration/test_battle_interface.gd` | 6 | Passed, including keyboard aim/details activation, focus retention, immediate quote and live submission |
| `test/test_weather_forecast_regions.gd` | 10 | Passed, including CT cost, refusal replacement, and hidden-damage masking across seeded hits/misses |
| `test/manual/serious_aim_capture.gd` | 1 | Passed; compact and expanded captures, frame containment |
| `test/manual/aim_row_capture.gd`, `head_aim_capture.gd`, `leg_aim_capture.gd` | 3 | Passed |
| `test/integration/test_production_aim.gd` | 11 | Passed |

31 cases, zero test errors or failures; both test invocations exited successfully.
Godot reported ObjectDB/resource-in-use warnings at shutdown; these are not counted as
assertion failures by gdUnit4. `git diff --check` passed. No full-suite, release, localization
translation, or physical-controller certification is claimed by this focused UI task.
