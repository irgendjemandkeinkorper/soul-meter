# Combat presentation: one bar, both modes (owner ruling 2026-11-01)

Branch: `claude/combat-one-bar` (based on `main` @ `9e1ee0f9`). Lower Trial Hall warden fight,
1920x1080 logical canvas, as the player sees it. Frames 01–08 are the review pass of
2026-11-01 (command column reworked, fighters kept clear of the HUD, Space ends the turn).

**Ruling under test** (`docs/owner-decisions.md` §5, "Combat presentation", 2026-11-01):
combat does not go to a separate screen. The field HUD's single bottom bar grows its combat
parts on combat start and retracts them on combat end; the only top element is a thin
turn-order strip; detail lives on hover, the full breakdown behind a toggle; the field camera
follows the actor without reframing.

**Lead review (2026-11-01), both blockers addressed in these frames:**

1. *Command column.* The ready commands sit in a flow at full label width, catalog order,
   no scrolling on a normal turn (25 ready actions in five 22 px rows). Nothing is clipped;
   `clip_text` is off and every button is as wide as its label. The locked rest (39 here)
   waits behind `MORE · 39`, which lists each one disabled beside its lock reason; `LESS`
   folds them away. The AIM row takes the FOE readout's place on the footer line only while
   an aimed action quotes a hovered enemy. The unit plate stacks its stats in one column so
   `CT 4 · FACING E` reads whole.
2. *Fighters and the HUD.* The camera's top and bottom limits grow by the strip and bar
   insets plus a 64 px clearance while combat runs, so the room's south wall scrolls up clear
   of the bar (the void below the wall is the room's edge, not map art). A body is framed only
   when its sprite and cell diamond sit inside the open window with that clearance; the
   acting unit's turn, and an action beat with its target, pan to satisfy it. Zoom and side
   limits never change; the limits return (smoothed) on combat end.

**Verdict from these frames: met.** The map stays full-screen in both modes. Nothing docks
left or right. The bar grows from 84 px to 196 px and back. The strip is 52 px tall and
shrink-wraps to its two markers plus the weather chip. Hover gives name / HP / hit % / damage
in one tooltip. The breakdown is closed until asked for and opens as a 496x560 popover above
the bar's right end.

## How the frames were made

`SOUL_METER_TEST_DATA_DIR=<fresh dir> xvfb-run -a -s "-screen 0 1920x1080x24" bash scripts/test.sh -a test/manual/combat_one_bar_capture.gd`
(Godot 4.7.1). Result: 1/1 passed. The harness loads the trial scene, hides the harness's
own root canvas items, starts the warden session through `Battle.start_session` and grows the
HUD with `FieldHUD.enter_combat(field)` exactly as `GameFlow._on_battle_entered` does. Frames
are keyed to presented beats, not wall-clock offsets. Full frames are quantised to 256 colours
(the soul gauge gradient bands slightly as a result; the live render does not).

## Frames

| Frame | Shows | Read it for |
|---|---|---|
| `01-exploration-bar` | Exploration: 84 px bar with the objective lines, Vex's HP/Breath readout and the soul gauge. Field hints across the top. | The baseline the combat bar grows out of. |
| `02-combat-start-player-turn` | Combat begins, Vex's turn. The camera has panned the pair up into the open window; the south wall sits clear above the bar. Same bar at 196 px: plate (portrait, HP, AP pips, one-column Breath/Tempo/Scars/CT·Facing/Aftertones/Element) · cursor strip, balance meter and message window (`COMBAT BEGINS`, `TURN · VEX THE UNBOWED`) · 25 ready commands in five rows at full width · footer `FOE TRIAL WARDEN · HP 2 / 2` and `MORE · 39` · PARTY · END TURN / WITHDRAW / BREAKDOWN · soul gauge. Thin turn strip at top centre with Vex's marker lit. The strikes are locked on this first turn (the warden is not yet in reach), so the row starts at GUARD. | Rulings 1, 3, 4; review item 1 (no clipping, no scrolling) and item 2 (clear of the bar). |
| `03-enemy-turn` | Mid-beat on the warden's turn. Strip marker moves to Trial Warden (`ACTIVE`), Vex reads `ACTED`. Plate follows the presented actor (Trial Warden, HP 2/2, AP 3/4). Both bodies stay framed; no pan was needed. | Ruling 1 (strip highlights the active actor), ruling 3 (pan only when needed), review item 2. |
| `04-enemy-hover-tooltip` | Cursor over the warden on Vex's second turn (the warden now adjacent, so STRIKE / DEFINING STRIKE / PARADOX STRIKE / CLOSE STRIKE / SHOVE / QUICK CUT are ready). Tooltip at the body: `Trial Warden / HP 2 / 2 / ORDINARY · HIT 70% · 9 DMG`. The footer line now reads `AIM [ORDINARY] ARM HEAD LEG THROAT TORSO` with `MORE · 33`; the ready rows above are unchanged and still unscrolled. | Ruling 2, hover half; review item 1 (the AIM row costs no command rows). |
| `05-breakdown-open` | After pressing BREAKDOWN (or B). One popover, bottom-right above the bar: forecast card, hit-chance breakdown, attunement wheel, power formula, then tactical data scrolling below. Bar and strip unchanged beneath it; the popover does not overlap the bar. | Ruling 2, toggle half. |
| `06-after-combat-bar-retracted` | Encounter resolved and continued. The bar is back at 84 px with the exploration readout; strip, popover and combat parts are gone; the camera limits are the room's again. | Ruling 1, retract half. |
| `07-more-open` | `MORE · 33` pressed (reads `LESS`). The ready rows stay on top; below them the locked commands list one per row, disabled, each beside its lock reason (`RECORD NAME · 2 AP — Vex the Unbowed cannot use that class action.` first). The list scrolls inside the bar; the bar does not grow. | Review item 1 (every command reachable, lock reasons shown). |
| `08-1366x768-player-turn` | The same turn with the window at 1366x768. The project stretches its 1920x1080 canvas (`canvas_items`, keep aspect), so this is the identical layout at 0.71 scale: nothing reflows, nothing clips, text is 71 % size. | Owner answer 2: minimum width. |

The entry cue (vignette flash and the combat-start sound) is not capturable as a still; its
timing is pinned in `test/integration/test_combat_bar.gd` (vignette gone and bar at full
height within 0.5 s; no motion and no vignette under reduced motion; `COMBAT BEGINS` first in
the window; `CombatAudio` mounted). Space ending the turn is pinned there too (player's turn
only; blocked while a text field or the breakdown popover holds focus).

## Where the old regions went

| Old `battle.tscn` region | New home |
|---|---|
| Unit plate (top-left) | Left end of the bar (`ActiveUnitPlate`, one-column stats). |
| CT timeline (top) | Thin turn strip (`TurnStrip/StripRow/TurnTimeline`), one row of portrait markers. |
| Weather chip (top-right) | Right end of the turn strip (owner: keep it there). |
| Tactical / forecast panel (docked right) | AIM row on the command footer while aiming; forecast card and breakdown inside the `TacticalPopover`. |
| Tactical data (party panel) | `TacticalPopover`, below the forecast breakdown. |
| Command dock (bottom-left) | Bar command column (`CombatBar/CommandColumn`): ready flow, `MORE` list, footer. |
| Foe / log panel (bottom-centre) | Bar message window (`CombatBar/LogColumn/MessageLog`) and the FOE readout on the command footer. |
| Party panel (bottom-right) | Bar party column (`CombatBar/PartyColumn`). |
| Stage window / reframe / floor tint | Removed. Stage spans the viewport minus bar and strip; reachable tint shows only while a pointer action is live. |

## Remaining limits (honest)

- Five rows of ready commands fit at 720 px; a kit with many more ready actions than this
  party's 25 would scroll the ready flow (the `MORE` list always scrolls). The footer line
  holds AIM (six locations) + MORE + TARGET with about 16 px to spare in a two-enemy fight;
  TARGET is hidden with a single enemy.
- 1366x768 is a uniform 0.71 scale of the 1920x1080 layout, so 12 px labels render at about
  8.5 px there. Readability at that size is the owner's call; nothing clips.
- The combat-start sound reuses `impactBell_heavy_002.ogg` (`CombatAudio.CUE_COMBAT_START`),
  per the owner's answer.
- The two flat tan bands across the Trial Hall are map art present in exploration too; the
  lead is handling them separately.
