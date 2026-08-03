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
| Walk the lower ward | Registry Archive, Lower Market, Bell House, River Shrine, Item Shop, Equipment Shop, Chef's House, and Iron Companies garrison are visibly distinct landmarks; building walls cannot be walked through |
| Visit the civic/residential loop | Town Hall, Chef's House, and Vex's House each have a readable sign, distinct silhouette, and a collision footprint that preserves a navigable approach |
| Browse the Item Shop and Equipment Shop | Each storefront shows its own interaction prompt, GP balance, prices, and repeatable stock/gear description; the visit flags persist |
| Buy Loam Bread | One unit is added to Inventory, the carry count updates, and the GP ledger drops by 8 |
| Spend below an item's price | The Buy control remains visible but disabled, with an insufficient-GP explanation |
| Visit the Garrison | The Iron Companies garrison responds with its roster/report-in description and remains available after the first interaction |
| Visit Vex's House and use the Home Save Point | The house and save marker are separate readable points; using the save point sets `dom_save_point_used` and queues a `save-point-save_point` autosave |
| Read the Notice Board | A one-time Dom event records that the silent bell house and east road are under Registry attention |
| Speak with Sella Varn | Sella offers “The Bell That Won't Ring”; the Bell House remains locked until the quest is accepted |
| Inspect the Bell House after accepting Sella's quest | The bell event records `dom_bellhouse_inspected`, updates the quest, and makes Sella's return line available |
| Return to Sella after inspecting the bell | The quest completes, the report is recorded in the ledgers, and the bell remains visibly present but unresolved |
| Speak with Marshal Coiljaw and choose the final conversation option | “Accept the field debt and open the east road” starts the commission and unlocks **TO THE WILDS** |
| Take the east road, approach the Bog Wight, and press E | The field transitions to the combat overlay with one enemy and the party action buttons |
| Complete several combat rounds and defeat the Bog Wight | The combat outcome appears; returning to the field reveals the loamroot proof at the enemy's position |
| Walk over the loamroot proof and return to Marshal Coiljaw in Dom | The proof is added to Inventory, the turn-in conversation opens four reward choices, and selecting one records its advertised reputation deltas |
| Speak with Hadrik Vale and Toma Reedhand | Each chat window presents its authored response menu; Registry and river-shrine conversations expose the `dom_registry_notice_seen`, `dom_registry_challenged`, `dom_shrine_asked`, and `dom_shrine_visited` state changes |

No step should produce script errors beyond the documented addon shutdown noise.
