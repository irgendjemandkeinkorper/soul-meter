# Combat accuracy foundation — 2026-09-18

Task 2 in [the combat expansion checklist](../../tasks/called-shots-and-injuries.md) is implemented. Visible anatomy and cost-plus-penalty aiming are approved design rules; their selector and lab fixture remain the next slice.

## Behavior verified

- Ordinary accuracy preserves the existing 70 base, Alacrity/facing/height terms, 5–95 clamp, legacy auto-hit, and explicit guaranteed-hit behavior. The breakdown is additive and data-only.
- A successful Defining Strike knowledge check followed by a physical miss spends its legitimate AP cost but causes no HP loss or crippling effect. Repeated forecasts preserve action sequencing and return identical payloads.
- Displayed damage is conditional on landing; changing the deterministic seed across hits, misses, and fizzles does not reveal the upcoming outcome through the displayed damage. Cover/defense mitigation is included in the controller quote.
- Hidden draw rows and damage remain masked until revealed. Forecasts show actual hit chance instead of a fixed 90%, and display modifiers in percentage points. The Defining Strike dialog labels knowledge and physical-hit chances separately.

## Automated evidence

Godot 4.7.1, `scripts/test.sh` under Xvfb, `LP_NUM_THREADS=1`, disposable `SOUL_METER_TEST_DATA_DIR` paths. No real player saves used.

| Run | Suites | Result |
|---|---|---|
| `reports/report_1516` | Resolution, combat controller, forecast regions, battle interface | 91 passed; 0 failed/errors/skipped; exit 0 |
| `reports/report_1517` | Combat controller, forecast regions, class-resource seam v2, battle-screen commands, rendered accuracy capture | 90 passed; 0 failed/errors/skipped; exit 0 |
| `reports/report_1518` | Rendered forecast and live Defining Strike dialog | 2 passed; 0 failed/errors/skipped; exit 0 |

114 distinct test cases across the three green runs. The second run adds hidden-result and mitigation assertions; the third checks the actual Defining Strike dialog. Existing Godot teardown ObjectDB/resource leak diagnostics remain (texture diagnostics also occur in the first two runs); assertions passed and processes exited 0. These runs do not establish a leak-free shutdown or complete the full release gate.

## Rendered evidence

`test/manual/accuracy_forecast_capture.gd` loads the real battle interface with a controlled forecast fixture. Automated bounds checks pass, and both captures were visually inspected: the entire forecast and accuracy explanation fit without clipping.

- [1920×1080 forecast](combat-accuracy-2026-09-18/accuracy-1920.png)
- [1280×720 forecast](combat-accuracy-2026-09-18/accuracy-1280.png)
- [Defining Strike dialog](combat-accuracy-2026-09-18/defining-strike.png): knowledge chance, hit chance, conditional damage, and effect prerequisite fit inside the real dialog; inspected after the live screen opened it.

This is a HUD fixture, not a complete encounter or a subjective readability/play-feel evaluation. Production anatomy selection, physical visibility modifiers, persistent injuries, and treatment are not implemented by this slice. No new injury balance values are ratified.
