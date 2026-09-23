# Target identification — 2026-09-21

Resumed after the power interruption. The last selected scope was targeting clarity
with short labels and key numbers beside the target. Existing uncommitted injury,
aiming-panel, and hit-feedback work was preserved.

## Observable behavior

- The tactical board and field overlay identify the inspected target with its name,
  aimed body part (or ORDINARY), and the controller forecast's hit percentage.
- Unavailable actions show UNAVAILABLE. Previewing or changing aim spends no AP.
- The target outline and label remain while choosing a body part with the keyboard.
  Changing actions, clearing the pointer, or resolving the action clears the label.
- The label stays at HUD text scale, follows field projection, and is clamped inside
  the stage. Its controls ignore pointer input.

Implementation is in `ui/hud/battle_interface.gd`,
`ui/hud/regions/stage/battle_stage_region.gd`, `ui/hud/target_preview.tscn`, and
`world/combat_overlay.gd`. It uses existing theme variations and DS tokens.

## Rendered evidence

- [Tactical board, 1920×1080](target-preview-2026-09-21/target-preview-board-1920.png)
- [Field overlay fixture, 1920×1080](target-preview-2026-09-21/target-preview-field-1920.png)

Both images were rendered with Godot 4.7.1 under Xvfb and visually inspected.
Both show Bog Wight, ARM, and HIT 59%, agreeing with the aiming panel.
The field fixture uses borrowed actor art on a translated, 3× scaled grid;
it is not a full exploration-map playthrough. The runtime check also moves the
field and verifies that the label follows by the same screen distance.

## Verification

The interrupted capture script had a Variant-inference parse error at its target
cell declaration. An explicit `Vector2i` type fixes the error.

```bash
LP_NUM_THREADS=1 \
SOUL_METER_TEST_DATA_DIR=/tmp/soul-meter-target-recovery-20260921 \
bash scripts/test.sh \
  -a test/integration/test_battle_interface.gd \
  -a test/test_battle_stage_region.gd \
  -a test/unit/test_combat_overlay.gd \
  -a test/manual/target_preview_capture.gd
```

| Suite | Cases | Result |
|---|---:|---|
| Battle interface | 6 | Passed; keyboard aim, forecast agreement, unavailable quote, cleanup, live submission |
| Battle stage | 12 | Passed; existing projection, pointer, movement, hit-feedback, and KO checks |
| Combat overlay | 5 | Passed; existing borrowed-actor, transform, movement, and hit-feedback checks |
| Target preview capture | 1 | Passed; both views, label bounds, field tracking, pointer pass-through, AP unchanged, cleanup |

24 cases passed, zero test errors/failures/skips; process exit 0. `git diff --check`
passed. Xvfb needed execution outside the sandbox because its display was inaccessible
inside it. Godot emitted ObjectDB leak and resource-in-use messages during teardown;
these remain unresolved. Full-suite, release, physical-controller, and subjective
readability acceptance were not performed in this focused recovery pass.
