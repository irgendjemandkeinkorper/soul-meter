# Combat presentation: one bar, both modes (owner ruling 2026-11-01)

Branch: `claude/combat-one-bar` (based on `main` @ `9e1ee0f9`). Lower Trial Hall warden fight,
1920x1080, as the player sees it.

**Ruling under test** (`docs/owner-decisions.md` §5, "Combat presentation", 2026-11-01):
combat does not go to a separate screen. The field HUD's single bottom bar grows its combat
parts on combat start and retracts them on combat end; the only top element is a thin
turn-order strip; detail lives on hover, the full breakdown behind a toggle; the field camera
follows the actor without reframing.

**Verdict from these frames: met.** The map stays full-screen in both modes. Nothing docks
left or right. The bar grows from 84 px to 196 px and back. The strip is 52 px tall and
shrink-wraps to its two markers plus the weather chip (523 px wide, centred). Hover gives
name / HP / hit % / damage in one tooltip. The breakdown is closed until asked for and opens
as a 496x560 popover above the bar's right end.

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
| `02-combat-start-player-turn` | Combat begins, Vex's turn. Same bar at 196 px: plate (portrait, HP, AP pips, Breath/Tempo/Scars/CT/Aftertones) · cursor strip, balance meter and message window (`COMBAT BEGINS`, `TURN · VEX THE UNBOWED`) · COMMAND grid with AP costs and lock states · PARTY · END TURN / WITHDRAW / BREAKDOWN · soul gauge. Thin turn strip at top centre with Vex's marker lit. Map untouched behind it; camera unchanged. | Ruling 1 (one bar), ruling 3 (no reframing), ruling 4 (log line). |
| `03-enemy-turn` | Mid-beat on the warden's turn. Strip marker moves to Trial Warden (`ACTIVE`), Vex reads `ACTED`. Plate follows the presented actor (Trial Warden, HP 2/2, AP 3/4). Message window carries the turn cue and the move line. Camera stays put because the warden is already on screen (D9 rule). | Ruling 1 (strip highlights the active actor), ruling 3 (pan only when needed). |
| `04-enemy-hover-tooltip` | Cursor over the warden on Vex's turn. Tooltip at the body: `Trial Warden / HP 2 / 2 / ORDINARY · HIT 70% · 9 DMG`. AIM row shows on the bar (ORDINARY, ARM, HEAD, LEG, THROAT, TORSO). Cursor strip reads `(52,53) · HEIGHT 0 · TRIAL WARDEN`. | Ruling 2, hover half. |
| `05-breakdown-open` | After pressing BREAKDOWN (or B). One popover, bottom-right above the bar: forecast card, hit-chance breakdown, attunement wheel, power formula, then tactical data scrolling below. Bar and strip unchanged beneath it; the popover does not overlap the bar. | Ruling 2, toggle half. |
| `06-after-combat-bar-retracted` | Encounter resolved and continued. The bar is back at 84 px with the exploration readout; strip, popover and combat parts are gone; the warden lies where it fell. | Ruling 1, retract half. |

The entry cue (vignette flash and the combat-start sound) is not capturable as a still; its
timing is pinned in `test/integration/test_combat_bar.gd` (vignette gone and bar at full
height within 0.5 s; no motion and no vignette under reduced motion; `COMBAT BEGINS` first in
the window; `CombatAudio` mounted).

## Where the old regions went

| Old `battle.tscn` region | New home |
|---|---|
| Unit plate (top-left) | Left end of the bar (`ActiveUnitPlate`, compact two-column stats). |
| CT timeline (top) | Thin turn strip (`TurnStrip/StripRow/TurnTimeline`), one row of portrait markers. |
| Weather chip (top-right) | Right end of the turn strip. |
| Tactical / forecast panel (docked right) | AIM row on the bar's command column; forecast card and breakdown inside the `TacticalPopover`. |
| Tactical data (party panel) | `TacticalPopover`, below the forecast breakdown. |
| Command dock (bottom-left) | Bar command column (`CombatBar/CommandColumn`). |
| Foe / log panel (bottom-centre) | Bar message window (`CombatBar/LogColumn/MessageLog`) and FOE readout under the command grid. |
| Party panel (bottom-right) | Bar party column (`CombatBar/PartyColumn`). |
| Stage window / reframe / floor tint | Removed. Stage spans the viewport minus bar and strip; reachable tint shows only while a pointer action is live. |

## Remaining limits (honest)

- Long command labels clip at 4 columns (`DEFINING STRIKE · 3`, `SPEND CLARITY · 1 A`); the
  full name, cost and lock reason are in each button's tooltip. A 3-column grid would fit them
  at the cost of a taller bar.
- The plate's `CT 4 · FACING E` and the cursor strip's occupant name ellipsise at 280 px.
- The combat-start sound reuses `impactBell_heavy_002.ogg` (`CombatAudio.CUE_COMBAT_START`)
  until a dedicated cue is authored.
- Frames are 1920x1080 only; the bar's fixed column widths (280 / 280 / 560 / 220 / 124) fit a
  1626 px interior and have not been checked below 1600 px wide.
