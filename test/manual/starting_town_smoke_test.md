# Manual smoke test — starting town, tavern, and travel to the wilds

Covers the parts of the new town/tavern/travel flow that automated tests can't reach: the
real Boot → Menus → `new_game` → Loading → Active path through `ui/flow/game_flow.gd`'s state
chart, and the full scene swap (Dom → the wilds) via `GameFlow.travel()`. Run this after any
change to `ui/flow/`, `world/starting_town.tscn`, `actors/tavern_door/`, `actors/travel_exit/`,
or `ui/screens/tavern.gd`.

What this checklist does NOT try to cover: anything already asserted by
[`test/integration/test_starting_town.gd`](../integration/test_starting_town.gd) (tavern-door
prompt range, tavern screen candidate list, the 3-recruit cap, confirming replaces
`GameState.party`, `TravelExit` setting `GameFlow._target_scene`) — re-verify those only if you
suspect this checklist and the automated suite disagree.

**Last run:** _(fill in: Godot version, date, pass/fail)_

## 1. Boot into the town (not the wilds)

| Do | Expect |
|---|---|
| Launch the project, select "New Game" | Dom (the starting town) loads — NOT `world/test_room.tscn` — no loading-screen hang, no `change_scene_to_file` warnings |
| Look around | Town square with a "THE FOUR ARMS" tavern facade and a "TRIAL COUNCIL HALL" building are visible; walls bound the square except a gap on the east side |

## 2. The tavern

| Do | Expect |
|---|---|
| Walk up to the tavern facade | An "E — ENTER" prompt appears in range, disappears out of range |
| Press E in range | The Tavern screen opens (paused), listing 5 candidates with race/class/HP/bio |
| Check 4 boxes | The 4th check is silently rejected — at most 3 stay checked |
| Uncheck one, check a different one, then press "Set out" | Screen closes; open the Party screen (default `open_party` keybind) and confirm it now shows exactly your chosen members, not the original demo trio |
| Re-enter the tavern and confirm a different selection | Party screen reflects the new selection — the tavern should be safely re-visitable, not one-time-only |
| Open the tavern and press "Leave without choosing" | Screen closes; Party screen is unchanged from before you opened it |

## 3. Travel to the wilds and back to parity with the old vertical slice

| Do | Expect |
|---|---|
| Walk through the gap on the town's east wall | A brief loading transition plays, then `world/test_room.tscn` (the wilds) loads — Iris Illepah, the Bog Wight, the Loam-Maddened Boar, and the three Loamroot Sprig pickups are all present and functional exactly as before this change |
| Fight the Bog Wight or Loam-Maddened Boar, win or lose | Reputation consequence still fires (see `test/manual/field_dialogue_smoke_test.md` for the dialogue-side equivalent) |
| While in the wilds, press the inventory/party/standing keybinds | They still open — confirms `UIManager._in_gameplay()`'s scene-set check works for both gameplay scenes, not just the town |

## 4. Console hygiene

| Do | Expect |
|---|---|
| Watch the console through the whole run | No `ERROR:`/`SCRIPT ERROR:` lines beyond the known, harmless Phantom Camera/Pandora dock noise documented in `DEPENDENCIES.md` |
