# Journal Screen Smoke Test

## Quest ledger

1. Launch the game and enter Dom or the wilds.
2. Press `Q` → expect the Journal to open and gameplay to pause.
3. Accept an available commission → expect it under **Quests in motion** with its current
   objective, giver, location, and an **Active** or **Ready to report** state.
4. Complete and turn in that commission, then reopen the Journal → expect it under
   **Quests entered** with **Completed** state; expect no duplicate active entry.

## What the world remembers

1. Make a choice that changes faction standing, Renown, or Infamy.
2. Open the Journal → expect **What the world remembers** to quote the stored cause, name what
   changed, and identify where the event was entered.
3. Trigger several different consequences → expect the newest six entries in newest-first order.
4. Select **Standing and every recorded reason** → expect the existing Standing screen to open
   above the Journal with faction bands and cause history; press `Esc` to return to the Journal.
5. Close and reopen the Journal → expect quest and ledger state to be unchanged by viewing it.

## Legibility

1. At 960×540 and 1920×1080, inspect both quest columns → expect equal-width mirrored columns,
   wrapped text, and no content outside the carved panel.
2. With no active/completed quests or consequences, open the Journal → expect explicit empty-state
   prose in every section rather than blank space.
