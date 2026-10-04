# Active-character injury badges — 2026-09-21

The active character panel now shows one clickable badge per current injury, labeled with
the authored body-part name and explicit minor/serious severity. Serious badges also use the
existing danger-button theme. Both freshly inflicted and restored injuries appear from the
current combat snapshot; no new impact event is required.

Clicking a badge opens a separate detail card below the active panel. It shows the victim,
body part, actual penalties, and current recovery rule, using the same record presentation
as the injury-impact notification. A Close button dismisses it. This inspection does not
consume or disturb queued impact notifications, pause combat, or spend AP/CT.

The card remains open through ordinary HP/CT updates. It updates when the selected record
changes, closes when that injury is removed or the active combatant changes, and stays
closed after deliberate dismissal. Surviving badge controls are reused so incoming snapshots
do not steal keyboard focus.

## Implementation

- `unit_plate_region.gd`/`.tscn`: badges from the active unit's serialized injury/anatomy data;
  emits location-selection intent and retains existing scene node paths.
- `battle_interface.gd`/`.tscn`: positions and refreshes the independent inspector, clearing
  stale selections across turn/controller changes.
- `injury_notice.gd`: adds a record-inspection entry point using its existing penalty and
  recovery wording; the impact queue remains a separate instance.
- `project.godot`: registers the unit-plate source for PO/gettext extraction.

Combat mechanics, treatment operations, balance, and serialized save data are unchanged.

## Evidence

[Four active injury badges with throat details open](active-injury-badges-2026-09-21/active-injury-badges-1920.png)

Rendered under Godot 4.7.1/Xvfb at the canonical 1920×1080 frame and visually inspected.
The four-location fixture uses the production strike's serious-injury records. Badge,
detail-card, and visible aim-panel bounds are asserted; the capture uses the compact aim view.

## Verification

`scripts/test.sh` ran with `LP_NUM_THREADS=1` and isolated user data at
`/tmp/soul-meter-injury-badges-20260921`. Xvfb checks ran outside the sandbox.

| Suite | Cases | Result |
|---|---:|---|
| `test/test_unit_plate_region.gd` | 4 | Existing portrait, vitals, and resource presentation passed |
| `test/integration/test_injury_notice.gd` | 5 | Mouse/keyboard opening and closing, focus retention, injury removal, active-unit switching, impact queue independence passed |
| `test/integration/test_injuries.gd` | 7 | Injury application, refresh, live notification path and penalties passed |
| `test/integration/test_battle_interface.gd` | 6 | Existing HUD, aiming and submission checks passed |
| `test/manual/serious_aim_capture.gd` | 1 | Aim/impact captures plus four-badge inspection render and bounds passed |

23 cases passed, zero assertion failures/errors, process exit 0. `git diff --check` passed.
Godot reported ObjectDB/resource-in-use warnings at shutdown. No full-suite, release,
physical-controller, or translated-layout certification is claimed by this focused UI task.
