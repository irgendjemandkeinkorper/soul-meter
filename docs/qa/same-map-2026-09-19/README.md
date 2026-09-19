# Same-map combat — ambient entry evidence, 2026-09-19

Branch: `feat/same-map-ambient`. Tracker: #281.

## What changed

Before this branch, `Battle.start_session()` had no production caller and no world scene
authored a `Hostile`: ambient combat existed only in labs and tests. Now:

| Piece | Where |
|---|---|
| First accepted alert opens a session and sends `enter_battle`; later alerts are admitted by Battle | `GameFlow.watch_field_hostiles()` / `_on_field_hostile_alerted()` in `ui/flow/game_flow.gd`, armed in `_complete_scene_load()` |
| Hostiles that arrive after field `_ready` (spawned, fixtures) still reach the flow | `FieldMap.register_hostile()`, called from `Hostile._ready()` |
| Session end settles the field: dead → `DOWNED` (dim, walk-over collision), standing → `IDLE` at full HP under the re-alert cooldown | `Battle._settle_session_hostiles()`, `Hostile.mark_downed()` / `release_from_session()` |
| Beaten groups do not come back (`defeated_*` flags gate pickups and follow-up fights); the retired node hides, leaves physics and frees on a later idle frame | `Hostile._ready()` / `_retire()` |
| Sensor toggles are deferred (Godot refused them inside `body_entered`) | `Hostile._set_sensor_enabled()` |
| Authored ambient hostiles | `test_room`: Bog Wight, Loam Boar. `dorthkor_road`: Breach Hound + Rift Scavenger (group `dorthkor-vanguard`). `MusteredDead` and `jawbrace-empty-post` stay `Enemy` set-pieces. |

## Rendered check (Xvfb, 1920x1080)

`test/manual/ambient_session_capture.gd`: the flow watch is armed, the player is placed inside
the authored Bog Wight's alert radius, the session opens through the real path (hostile ends
`IN_COMBAT`, `Battle.session_active`), the battle screen is mounted over the field camera with
the log column hidden, one Strike is submitted.

| Shot | File | Observed |
|---|---|---|
| Session open | `ambient-open.png` | Field rendered in place, Bog Wight (20) and Vex (44) with HP bars, cursor diamond, command dock, forecast panel. |
| After one Strike | `ambient-after-strike.png` | Wight HP 20 → 10 on the bar and in the print. |

**Readability verdict against #281's carried-forward acceptance ("readable end-to-end with the
log hidden"): not yet met.** Two defects are visible in the shots:

1. The party is seated on the cell directly behind the hostile, so the two sprites and their HP
   bars stack. Who is where is not legible at a glance.
2. Twenty frames after the strike no attacker lunge, damage number, or facing change is visible.
   Either the beat is shorter than the capture window or the overlay does not draw it on the
   live field. Needs a frame-by-frame capture to tell which.

Both are #211 items carried into #281 (units visible where they stand; action feedback beats).

## Automated checks

See the PR body for the exact suites and their summaries.
