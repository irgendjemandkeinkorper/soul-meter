# Manual acceptance — click-to-move input and refusal

Use this checklist when changing `actors/player/`, `world/nav/`, the gameplay HUD, or input
routing. Run it in a headed Godot build at **1152×648 or larger**. Do not use a direct scene
swap; reach Dom through the normal game flow.

**Last run:** _(fill in: Godot version, OS, date, pass/fail)_

## 1. Reach the navigation scene

| Do | Expect |
|---|---|
| Launch the project and use the normal menus/game flow to enter Dom (`world/starting_town.tscn`) | Dom renders, the player is controllable, and no `SCRIPT ERROR:` appears |
| Move the pointer over visible open ground inside the game window | The pointer position remains inside the viewport; no menu or overlay intercepts field input |

## 2. Real click-to-move

| Do | Expect |
|---|---|
| Left-click open ground several tiles from the player | The player begins moving toward the clicked location |
| Choose open ground on the far side of a building and left-click it | The player routes around the building and reaches the far side; the player does not cross the building footprint or grind against its edge |
| While the player is following that route, press and hold A or D | Click movement stops immediately and keyboard movement takes control |

## 3. Refusal path and message

| Do | Expect |
|---|---|
| Left-click visibly inside a building footprint | The player does not enter the building, and player-facing feedback says **“Something is in the way.”** |
| Left-click beyond the reachable map boundary, if the camera/debug setup permits it | The player stays put, and player-facing feedback says **“There is no route to that spot.”** |
| Repeat an invalid click after one valid move | Every invalid click produces feedback; refusals are not silent or one-shot |

If movement refuses but no message is visible, record this checklist as **FAIL**. The current
code re-emits `Player.move_refused`, but a repository search found no HUD/UI subscriber; absence
of player-facing feedback must not be treated as a pass merely because the signal fired.

## 4. Console hygiene

| Do | Expect |
|---|---|
| Watch the console/output panel throughout the run | No new `ERROR:` or `SCRIPT ERROR:` lines; only the known Phantom Camera teardown noise documented in `DEPENDENCIES.md` is acceptable |
