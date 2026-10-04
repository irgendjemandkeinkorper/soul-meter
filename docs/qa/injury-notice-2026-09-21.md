# Injury impact notification — 2026-09-21

Confirmed injuries now create a compact notification at the lower left of the combat stage.
The label names the victim, authored body part, and minor/serious severity. “Injury details”
expands the actual penalties and recovery rule from the committed record. It spends no AP/CT
and does not pause combat. The notice stays until dismissed; consecutive injuries queue behind
it, with “Next (N)” showing the number waiting. Expanded details are never replaced by a new hit.

## Presentation contract

`ui/hud/injury_notice.gd` and its scene consume existing `injury_applied` events through
`BattleInterface`. They do not query future rolls or alter combat state. Victim and body-part
names come from the event snapshot; severity/effects come from the applied record. Refreshes
are labeled explicitly and explain that penalties do not stack. Record instance/revision
identity suppresses duplicate delivery. Battle start and controller binding clear the queue;
the production screen binds after replay, preventing old hits from being presented as new ones.

Details support attack, vocal, and sight accuracy in percentage points, movement cost in
percent, and voice blocking. Serious injuries explain persistence until treatment; minor
injuries explain the current combat-end clearing rule. Theme variations and DS tokens provide
styling, and both sources are registered for PO/gettext extraction. Combat mechanics, balance,
injury persistence, and treatment remain unchanged.

## Evidence

- [Compact notification](injury-notice-2026-09-21/injury-notice-compact-1920.png)
- [Expanded penalties and recovery](injury-notice-2026-09-21/injury-notice-details-1920.png)

Both images were rendered with Godot 4.7.1 under Xvfb and visually inspected at the canonical
1920×1080 frame. The screenshot fixture commits a real production arm strike and checks the
resulting serious injury and −20 percentage-point penalty. Compact and expanded cards stay
within the combat stage without overlapping the aim panel.

## Checks

Executed through `scripts/test.sh` with isolated user data at
`/tmp/soul-meter-injury-notice-20260921`, `LP_NUM_THREADS=1`, and Xvfb outside the sandbox.

| Suite | Cases | Evidence |
|---|---:|---|
| `test/integration/test_injury_notice.gd` | 3 | Keyboard expansion/next/dismiss; queue retention; duplicate suppression; refresh and reset; no notices from unrelated events |
| `test/integration/test_injuries.gd` | 7 | Real submit-action hit/miss and replay path; previews and misses do not announce an injury; committed injury does |
| `test/integration/test_battle_interface.gd` | 6 | Existing HUD, aim selection, keyboard focus/details, and live action submission |
| `test/manual/serious_aim_capture.gd` | 1 | Rendered aim and committed notification, compact/expanded bounds and screenshots |

17 cases passed, zero assertion failures/errors; process exit 0. `git diff --check` passed.
Godot emitted ObjectDB/resource-in-use warnings during shutdown. This focused check does not
claim full-suite, release, physical-controller, or subjective usability acceptance.
