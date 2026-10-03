# Restrained hit feedback — 2026-09-21

Confirmed damaging hits now produce a brief four-arc impact pulse and a warm target tint.
The pulse expands from 12 to 20 local pixels and fades over the DS base duration (220 ms).
Attacker lunges are capped at eight coordinate units instead of traveling a quarter of the
distance to the target. The tactical-board view and same-map combat overlay share the pulse
and outcome interpretation. No camera shake, gameplay stagger, or combat timing rule was added.

Misses, fizzles, and zero-damage hits do not produce the damaging-hit pulse or flash. Existing
damage numbers remain; misses and fizzles are labeled explicitly. A real submission test found
that production strikes put `hit` inside `resolution`, while the old presentation only read the
flat field and displayed misses as “0”. Both views now support the production nested payload
and the existing flat compatibility payload.

Target flashes restore the original color, including scene-authored field tints. KO feedback
keeps ownership of fallen opacity; a death snapshot cancels an in-flight flash. Tactical hit
flashes survive ordinary follow-up snapshots and are canceled when their target is removed.
HUD history replay suppresses these action-feedback beats.

## Implementation

- `ui/hud/hit_pulse.gd`: transient code-drawn mark using DS palette/spacing/motion tokens,
  plus shared committed-outcome interpretation. Registered for translation extraction.
- `ui/hud/regions/stage/battle_stage_region.gd`: bounded lunge, damage-only pulse/flash,
  truthful hit/miss/fizzle text, flash lifecycle, and hit-feedback replay suppression.
- `world/combat_overlay.gd`: matching pulse and labels on borrowed field actors, bounded
  lunge returning to the authoritative grid location, original-color and KO preservation.

No combat-model, damage, accuracy, injury, or save-state changes.

## Rendered evidence

- [Real production strike: hit](hit-feedback-2026-09-21/hit-feedback-hit-1920.png)
- [Real production strike: miss](hit-feedback-2026-09-21/hit-feedback-miss-1920.png)
- [Field-overlay fixture with borrowed actor art](hit-feedback-2026-09-21/hit-feedback-field-1920.png)

All captures were rendered under Godot 4.7.1/Xvfb at 1920×1080 and visually inspected. The field
fixture uses a transformed grid at 3× scale and the production overlay drawing layer; it is an
isolated presentation fixture, not a full exploration-map playthrough. Screenshots show single
frames; duration, return-to-home, and cleanup are checked at runtime.

## Verification

`scripts/test.sh`, isolated user data under `/tmp/soul-meter-hit-feedback-20260921`,
`LP_NUM_THREADS=1`, Xvfb outside the sandbox:

| Suite | Cases | Evidence |
|---|---:|---|
| `test/test_battle_stage_region.gd` | 12 | Hit/zero/miss gating, lunge bound, subpixel home restoration, untouched defender position, cleanup, replay, existing KO/movement/render behavior |
| `test/unit/test_combat_overlay.gd` | 5 | Borrowed actor state, grid transforms, color/KO restoration, flat and nested results, fizzle, replay, movement cleanup |
| `test/manual/hit_feedback_capture.gd` | 2 | Real hit/miss submissions and rendered field-overlay pulse |

19 focused cases passed, zero assertion failures/errors, process exit 0. The two rendered cases
were rerun after correcting the fixture's overlay drawing layer and also passed. `git diff
--check` passed. Godot emitted ObjectDB/resource-in-use warnings during shutdown. Full-suite,
release, and subjective motion/readability acceptance were not part of this focused pass.
