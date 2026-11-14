# U3 panels: before and after (2026-11-02)

Rendered under Xvfb at 1920×1080 by `test/manual/ui_audit_capture.gd` (`test_panels`). The same
harness ran on the U2 commit (before) and on U3 (after). Each panel is opened through UIManager
over Dom, with a party of three, four carried items and the opening quests. Each image is
before on the left and after on the right, each half at 960×540. Plan and rulings:
`docs/design/ui-rework-plan-2026-11-01.md`.

| File | What changed |
|---|---|
| `01-party-to-register-summary.jpg` | P used to open a near-empty Party page (one stretched HP bar, a full-width BACK). It now opens the Register of Persons on its Summary tab: HP and Breath meters with numbers, attributes, the portrait, the Wheel and perks. |
| `02-register-skills-tab.jpg` | The Skills tab. Five groups flow side by side; with no points to spend there is no +5% column. |
| `03-journal.jpg` | One title and objective line for the thread; quests are three lines each (title, objective, who · where); no ACTIVE badges; with nothing completed, the quests in motion take the full width (owner decision 12); framed ledger shell; BACK bottom-left. |
| `04-standing-empty.jpg` | One line instead of an empty list beside an empty sheet. |
| `05-standing-with-factions.jpg` | Framed, fixed-width faction list beside its reasons. |
| `06-inventory-selected.jpg` | The selection is a violet edge (was GLoot's white outline). EQUIP and DROP show with a selection. |
| `07-inventory-nothing-selected.jpg` | With nothing selected, EQUIP and DROP are hidden. The mythic axe was a solid amber tile (its rarity frame, not a selection); it is now an amber edge on the dark well (owner decision 10). |
| `08-selection-edge-crop.jpg` | 1:1 crops, before and after: the selection edge on a common item, and the mythic axe (solid fill → amber edge, with the violet selection edge outside it). |

## Playtest fixes (owner playtest, 2026-11-02)

| File | What changed |
|---|---|
| `09-battle-spoils-over-battle.jpg` | Rendered by `test/manual/battle_spoils_capture.gd`: the battle open in UIManager's stack, spoils opened on top, as production does it. Before, the spoils drew under the combat HUD (it raises its own layers to z 10) and showed the battle through them. After, each screen opened on top draws above the one beneath, and the spoils are an opaque ledger window. |

Inventory dragging has no image; the proof is four mouse-driven tests in
`test/integration/test_panels_u3.gd`, which fail on the old code and pass on the fix. They
cover drag to a slot, drag onto a filled slot (swap), drag to another bag cell, and click to
select.

