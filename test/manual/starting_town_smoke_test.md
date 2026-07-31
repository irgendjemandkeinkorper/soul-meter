# Manual smoke test — Dom, company assembly, and route gates

Use the full [`prototype_acceptance.md`](prototype_acceptance.md) before sharing a build. This
short checklist is for changes limited to Dom/tavern/travel wiring.

**Last run:** _(Godot version, date, pass/fail)_

| Do | Expect |
|---|---|
| Start New Game | Dom loads at `SpawnNewGame`; Vex is the only party member; objective points to the Four Arms |
| Walk with WASD | Camera follows smoothly but remains inside the 1600×1000 town bounds |
| Approach the Four Arms and press E | Six companion candidates appear; Vex is fixed above the list |
| Inspect Korrath and Maura | Korrath states Renown 10; Maura states Infamy 8; both checkboxes are disabled at a fresh start |
| Select fewer/more than two | Confirm is disabled or the third choice is rejected |
| Select exactly two and confirm | Party screen lists Vex first and the selected pair; HUD updates and autosave feedback appears |
| Walk into Dorthkor before Coiljaw | Exit remains visible and explains that a commission is required |
| Accept Coiljaw's commission | Dorthkor exit unlocks; arrival uses `SpawnFromDom` and sets the road-reached flag |
| Walk into Loamroot before the recap | Exit explains that Coiljaw's ruling is required and does not travel |
| Continue Exploring from the recap | Loamroot opens; returning to Dom uses the named `SpawnFromWilds` marker |

No step should produce script errors beyond the documented addon shutdown noise.
