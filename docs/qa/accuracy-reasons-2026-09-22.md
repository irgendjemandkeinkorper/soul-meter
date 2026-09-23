# Accuracy explanations — 2026-09-22

Selected scope: explain existing hit-chance modifiers using a short summary and
expandable details. No accuracy, injury, cover, range, cost, or save rules changed.

## Observable behavior

- The compact forecast names up to two nonzero effects, prioritizing the largest
  penalties, then bonuses. It counts additional effects available in details.
- “Show combat details” replaces that summary with the base chance, every nonzero
  modifier, any minimum/maximum adjustment, and the final effective hit chance.
  The heading explains that `pp` means percentage points.
- Guaranteed hits and chance limits are explicit. Neutral accuracy shows “No
  accuracy modifiers.” Cover and range are not invented as percentage penalties:
  this presentation consumes the resolver's existing public breakdown.
- Aim changes and visibility events refresh the explanation. Refusals, action
  resets, and class commands clear it. Keyboard expansion retains focus and spends
  no AP. The explanation neither mutates the quote nor displays future rolls.
- The existing aiming view keeps other combat details collapsed. For actions
  without aim profiles, the existing damage/element view remains visible and the
  new accuracy calculation uses the same details toggle.

Implementation: `ui/hud/regions/forecast_panel/forecast_panel_region.gd` and its
scene. Existing theme variations and gettext extraction registrations are reused.

## Rendered evidence

Godot 4.7.1 Compatibility renderer under Xvfb, isolated user data. Inspected:

- [Called-shot summary](accuracy-reasons-2026-09-22/serious-aim-1920.png)
- [Called-shot expanded details](accuracy-reasons-2026-09-22/serious-aim-details-1920.png)
- [Multiple penalties, compact at 1920](accuracy-reasons-2026-09-22/accuracy-reasons-compact-1920.png)
- [Multiple penalties, expanded at 1920](accuracy-reasons-2026-09-22/accuracy-reasons-details-1920.png)
- [Compact at 1280](accuracy-reasons-2026-09-22/accuracy-reasons-compact-1280.png)
- [Expanded at 1280](accuracy-reasons-2026-09-22/accuracy-reasons-details-1280.png)

The multiple-penalty fixture resolves 70 + 8 + 8 - 4 - 25 - 15 = 42%. The compact
view highlights obscured visibility and the arm injury; details show all five
effects. The live called-shot fixture quotes an arm shot at 59% and submits an
action through the controller. These are focused fixtures, not a chapter playthrough.

Initial screenshot inspection caught an expanded panel pushing the bottom HUD
outside the viewport despite the old panel-bound checks passing. Replacing the
summary on expansion and omitting zero terms corrected that fixture. Rendered
checks now also assert that the complete HUD rows fit inside the viewport.

## Verification

```bash
LP_NUM_THREADS=1 \
SOUL_METER_TEST_DATA_DIR=/tmp/soul-meter-accuracy-reasons-20260922 \
bash scripts/test.sh \
  -a test/test_weather_forecast_regions.gd \
  -a test/integration/test_battle_interface.gd \
  -a test/manual/accuracy_forecast_capture.gd \
  -a test/manual/serious_aim_capture.gd

LP_NUM_THREADS=1 \
SOUL_METER_TEST_DATA_DIR=/tmp/soul-meter-accuracy-head-20260922 \
bash scripts/test.sh -a test/manual/head_aim_capture.gd
```

| Suite | Cases | Result |
|---|---:|---|
| Weather/forecast regions | 12 | Passed: summary ordering, full arithmetic, limits, guaranteed hits, quote immutability, stale-state clearing, existing hidden-roll/damage checks |
| Battle interface | 6 | Passed: keyboard focus, expansion without AP spending, controller quote agreement, live submission, visibility refresh, unavailable targets |
| Accuracy capture | 2 | Passed: compact/expanded layouts at both resolutions; existing defining-strike dialog |
| Serious aim capture | 1 | Passed: compact/expanded called shot, complete HUD bounds, existing injury notification/badges |
| Head aim capture | 1 | Passed: head injury accuracy explanation via the new details label |

22 cases passed, zero test errors/failures/skips; both processes exited 0.
`git diff --check` passed. Tests needed execution outside the sandbox because its
display restrictions prevent Xvfb access. Context Mode could not directly process
the `/tmp` log, so final results were read from the repository's XML report and
the second run's repository-local log.

Godot still reports ObjectDB leaks and resources in use during shutdown, as in
earlier checks; these are unresolved. No full-suite, release, physical-controller,
or subjective readability acceptance is claimed. Changes remain uncommitted.
