# Cross-screen shell conventions

**Closes #125.** These bind every screen in **Visual Alignment M2** (#126 Inventory, #128 World
Map, #129 Character Creation, and the Spell Wheel), so four screen issues do not each invent
their own layout.

**Relationship to `design/ui-screen-specs.md`:** that file does not exist yet — #112 vendors the
upstream `Godot UI Spec.md` into it **verbatim**, and explicitly forbids paraphrasing or
reordering while vendoring. So the conventions live here instead, in the repo's own voice, and
`ui-screen-specs.md` stays a clean mirror of the design project. When #112 lands, index this file
from `design/DESIGN_SYSTEM.md` beside it. Where the two ever disagree, the vendored spec wins and
this file gets corrected.

## The shell

Every full screen is:

```
Screen
└── MarginContainer            20px all sides   → ScreenShellMargin  (DS.PANEL_PAD)
    └── VBoxContainer          separation 16    → ScreenShellColumn  (DS.SPACE_6)
        ├── Header                              → ScreenHeader
        ├── Body                                (the only child that expands)
        └── HudBar                              → ScreenHudBar
```

Exactly three children. Not two, not four. **`HudBar` always ends with `SoulGauge`, rightmost** —
so `SoulGauge` is added last, whatever else the bar carries.

Implemented as `Screen._make_shell()` in `ui/screens/screen.gd`, which returns
`[header, body, hud_bar]`. All spacing comes from theme type variations registered in
`ui/theme/theme_builder.gd`; no per-node overrides, per the standing DS rule.

## Enter / exit

Fade + settle down 8px over `DS.DUR_BASE` (0.22s), `ease_out`. Exit is the reverse at
`DS.DUR_FAST` (0.14s). `Screen.play_enter()` / `play_exit()` implement it.

**Never** bounce, overshoot, or scale-in.

Transitions are driven from the state chart's `state_entered` / `state_exited`, not called
ad hoc — that is what makes it impossible for the animation and the game state to disagree. Per
`CLAUDE.md`, UI sends `GameFlow.send_event(...)`; there is no `change_scene_to_file()` in game
code, ever. Each overlay (inventory, wheel, map) is a state in `ui/flow/game_flow.tscn`.

## Hover / press

The theme handles edge-light. No Anima. Press is a 1px translate via the theme. Juicee inset
shake stays **off** for screens.

## One bronze per screen

Bronze is the single accent that says "this is the one thing to do here." One per screen, no
exceptions:

| Screen | The bronze element |
|---|---|
| Inventory | Equip button |
| Battle | End Turn |
| Spell Wheel | *none* — arcane owns the accent |
| World Map | Travel button + current-location mark |
| Character Creation | the attributes panel |

## Pause semantics

Spell Wheel and Inventory set `get_tree().paused = true`, with their UI on
`PROCESS_MODE_ALWAYS` (`Screen._ready()` already does this for every screen). The wheel backdrop
is the visual contract that time is held — if the backdrop is up, the world is stopped.

## Never

Bounce/overshoot easings · scale-down on press · rounded corners (radii are 0, with the 45°
notch) · sans-serif in menus (Cinzel display, Cormorant body, Fira Code for numbers only) ·
emoji · hue-only state encoding.

---

## Existing screens that violate these conventions

Named here, **not fixed here** — the issue asks for follow-ups instead, and migrating ten live
screens is not a documentation task. `_make_shell()` was therefore added *alongside* the existing
`_make_window()` rather than replacing it, so both shells coexist until the migration lands.

**All ten window-screens use the older centred dim+panel shell**, not Screen/Header/Body/HudBar,
and **none carries a `HudBar` or a `SoulGauge`** (today `SoulGauge` appears only in
`ui/hud/field_hud.gd`):

`chapter_complete` · `inventory` · `journal` · `party` · `pause_menu` · `settings` · `shop` ·
`standing` · `tavern` — plus the `_make_window` helper itself.

**Three screens use bespoke shells** and need individual assessment rather than a mechanical
migration: `battle`, `battle_stage`, `main_menu`.

Additionally, **no screen currently animates enter/exit from chart state at all** — the
`state_entered`/`state_exited` wiring described above is newly available via `play_enter()` /
`play_exit()` and is not yet connected anywhere.

### Suggested follow-ups

1. **Migrate `inventory` to the M2 shell** — highest value, since #126 rebuilds it anyway; fold
   the migration into that issue rather than doing it twice.
2. **Migrate the remaining eight window-screens**, one PR, mechanical, no behaviour change.
3. **Assess `battle` / `battle_stage` / `main_menu`** against the shell — `main_menu` may
   legitimately stay bespoke (it has no HUD and no game state behind it); the battle screens
   interact with `BattleHud*` variations that already exist.
4. **Wire `play_enter()` / `play_exit()` to `state_entered` / `state_exited`** in
   `ui/flow/game_flow.tscn` for the overlay states.

Filed as #149 (migrate the eight window-screens), #150 (assess battle / battle_stage / main_menu),
and #151 (wire enter/exit to chart state). The Inventory migration is folded into #126 rather than
duplicated — see the note on that issue.
