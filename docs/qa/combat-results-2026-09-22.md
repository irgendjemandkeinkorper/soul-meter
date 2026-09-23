# Committed results beside the target — 2026-09-22

Selected scope: clearer damage, miss, and injury results beside the target.

## Observable behavior

The tactical board and field overlay replace the short-lived floating number with
a compact framed result: target name, `13 DAMAGE`, `MISS`, `FIZZLE`, or `NO DAMAGE`.
Applied injuries add the authored body part and actual minor/serious severity.
An existing injury that was refreshed says `REFRESHED`.

The card holds for 1.8 seconds, then fades over the existing 220 ms theme duration.
It ignores pointer input and does not extend the action input lock or the field
animation gate. It follows its target, flips to the other side when necessary,
and clamps to the board or viewport. Field transforms do not magnify its text.
A newer result for the same target replaces the previous card; different targets
have independent cards. The existing persistent injury notice remains available
for penalty and recovery details.

Only resolved attack outcomes create cards. Movement, guard-like events,
non-damaging utility effects, forecasts, and suppressed history replay do not.
Injury text requires both the committed resolution and the matching snapshot
record's action provenance. It uses the record's retained severity, so a serious
roll that refreshes an existing minor injury correctly displays minor.

No combat calculations, costs, animation locks, injury rules, save formats, or
generated data were changed. Existing uncommitted work was preserved.

## Implementation

- `ui/hud/combat_result.gd` and `.tscn`: shared result card, target tracking,
  transform compensation, wrapping, input pass-through, and lifetime.
- `ui/hud/hit_pulse.gd`: shared outcome wording, applicability, and committed
  injury interpretation. This existing source is already registered for gettext.
- `ui/hud/regions/stage/battle_stage_region.gd` and `world/combat_overlay.gd`:
  replace damage labels with the shared card while retaining pulses and movement.

The card uses existing theme variations. Screenshot inspection caught excess
height from labels wrapping before their container received its width; following
the settled minimum size corrected it. Captures assert a bounded card height.

## Rendered evidence

All captures below were rendered with Godot 4.7.1 under Xvfb at 1920×1080 and
visually inspected. The five board cases submit real controller actions. The
field case is a translated, 3× scaled borrowed-actor fixture, not a chapter
playthrough.

| Result | Capture |
|---|---|
| Hit | [13 damage](combat-results-2026-09-22/combat-result-hit-1920.png) |
| Miss | [Miss](combat-results-2026-09-22/combat-result-miss-1920.png) |
| Minor injury | [Minor arm injury](combat-results-2026-09-22/combat-result-minor-1920.png) |
| Serious injury | [Serious arm injury](combat-results-2026-09-22/combat-result-serious-1920.png) |
| Refresh | [Minor injury retained and refreshed](combat-results-2026-09-22/combat-result-refresh-1920.png) |
| Field overlay | [Constant-size result card](combat-results-2026-09-22/combat-result-field-1920.png) |

## Verification

```bash
LP_NUM_THREADS=1 \
SOUL_METER_TEST_DATA_DIR=/tmp/soul-meter-combat-results-20260922 \
bash scripts/test.sh \
  -a test/unit/test_combat_result.gd \
  -a test/test_battle_stage_region.gd \
  -a test/unit/test_combat_overlay.gd \
  -a test/manual/hit_feedback_capture.gd
```

| Suite | Cases | Evidence |
|---|---:|---|
| Result interpretation | 2 | Damage/zero/miss/fizzle distinctions; non-attack suppression; committed injury provenance and severity; payload immutability |
| Battle stage | 12 | Result label; pulse/lunge/movement/KO behavior; cleanup; replay suppression; existing projection and pointer checks |
| Field overlay | 5 | Nested/flat hit payloads; fizzle; result lifetime independent of motion; replacement; existing state and transform checks |
| Rendered capture | 2 | Five real outcomes; no preview cards; card bounds and height; pointer pass-through; live input before expiry; field text scale, tracking, cleanup |

21 cases passed, zero test errors/failures/skips; process exit 0. The final
affected checks were rerun after the card-sizing correction. `git diff --check`
passed. Xvfb tests ran outside the sandbox with isolated user data.

Godot still emits ObjectDB leak and resource-in-use shutdown messages, as in
earlier focused runs. These remain unresolved. No full-suite, release,
physical-controller, or subjective timing/readability acceptance is claimed.
Changes remain uncommitted.
