# Tavern Screen Grouping and Selection Smoke Test

This manual checklist covers visual and behavioral verification of the Tavern recruitment roster screen.

## Setup
1. Launch the game.
2. Interact with the tavern facade (press `E` to open the party-picker).

## 1. Grouping and Visual Scannability
- [ ] Verify that there is a window titled "The Four Arms — Choose Your Party" of width 640 and height 560.
- [ ] Verify that all ten patron classes are visually represented as headings (e.g. "Ironbrand (Kero)", "Mirrorblade (Maiiam)", etc.).
- [ ] Confirm that each class has exactly two recruits displayed below it.
- [ ] Verify that recruit rows are indented under their respective headings (via `MarginContainer`), creating a clear hierarchical structure.
- [ ] Verify that an `HSeparator` divider is shown between class groupings to cleanly separate them.
- [ ] Confirm that every recruit's race, class, level, HP, and biography (or lock reason if locked) are fully visible.
- [ ] Hover over any recruit checkbox, the "Set out" button, or the "Leave without choosing" button. Verify the cursor changes to a pointing-hand shape.

## 2. Selection Limits (Max Party Size)
- [ ] Uncheck any checked recruits.
- [ ] Select three unlocked candidates (from the same or different class groups).
- [ ] Attempt to select a fourth candidate. Verify that checking the fourth box is prevented (it should immediately uncheck itself) and doesn't exceed the limit of 3.
- [ ] Uncheck one of the three selected candidates. Verify the current selection count decreases to 2.

## 3. Renown / Infamy Gating (Locked Candidates)
- [ ] Scan the roster for locked candidates (e.g., Korrath Ninefold who requires Renown 10, or Maura Greyfen who requires Infamy 8).
- [ ] Verify that locked candidates are visually distinguished (semi-transparent/muted text).
- [ ] Verify that locked candidates display their lock reason (e.g., "Won't talk to you yet — needs Renown 10 (you have 0).") instead of their biography.
- [ ] Verify that their checkboxes are disabled (not clickable).

## 4. Confirmation Behavior
- [ ] Select up to 3 unlocked candidates (e.g., Vex the Unbowed, Serai-Lun, Old Grumbrand).
- [ ] Confirm that the "Set out" button is enabled.
- [ ] Click the "Set out" button.
- [ ] Verify that the Tavern screen closes.
- [ ] Open the Party screen or view the party state. Verify that exactly those chosen characters are now in your active party.

## 5. Reopening the Tavern
- [ ] From the world map/starting town, interact with the tavern door/facade again to reopen the party-picker.
- [ ] Verify that the roster layout, grouping, and spacing are identical to the first opening.
- [ ] Verify that checkboxes are reset to empty, allowing a fresh selection.
- [ ] Choose a different set of recruits and click "Set out".
- [ ] Confirm that the active party correctly updates to the new selection.
