# Chargen "In a fight" row — captures (2026-11-14)

The last deferred piece of the chargen overhaul (`docs/design/chargen-overhaul-plan-2026-11-02.md`,
"Still deferred"). The entry column now ends with the eight slots a fight opens with.

| File | What it shows |
|---|---|
| `01-fight-row-1920x1080.jpg` | Ironbrand on Khash/Mozh: Strike, Guard, Spend Scars, Defining Strike, two weapon arts, Kindle and a Mozh spell. Keys 1–8 top left of each slot. |
| `02-fight-row-1366x768.jpg` | The same entry at 1366×768; the row stays inside the entry column. |

## How it was made

```bash
CAPTURE_OUT=<dir> GODOT_BIN=~/.local/bin/godot scripts/test.sh -a test/manual/chargen_register_capture.gd
```

Rendered by software GL under Xvfb, not on the owner's GPU. PNGs converted to JPEG (quality 85).

## What makes it the battle's bar

- The fill moved out of `CombatBar` into `globals/combat/hotbar_fill.gd` (`HotbarFill`), unchanged.
  The battle bar and `KitPreview.hotbar()` both call it.
- `KitPreview.hotbar()` reads "usable now" as a fresh fight would: nothing banked (a signature
  still holds its slot), full Breath, the member's Var Harmony, no Jam landed, no field object to
  hold (`CombatController._OBJECT_ONLY_EFFECTS`).
- `test_combat_bar.gd` checks that the preview for the acting ally's member equals the live
  bar at the first ally turn.
