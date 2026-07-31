# Standing Screen Smoke Test

## Faction-Specific Standing Test
1. Launch the game and enter the wilds/field room.
2. Talk to Iris Illepah (press `E`).
3. Make a dialogue choice that affects reputation (the choice will say something like `[#consequence=...]`).
4. Press `R` to open the Standing screen.
5. Confirm the game pauses.
6. Look at the left side of the screen; you should see the affected faction.
7. Select the faction; on the right side, confirm the delta (e.g. +10, -5) and cause text matches what the dialogue choice promised.
8. Confirm that if a faction exists but has no events recorded, or before selecting, clear empty states are displayed where applicable.
9. Press `Esc` or the Back button to close the screen.
10. Confirm the game resumes.

## Global Consequence Overview Test
1. Open the Standing screen (press `R`).
2. Verify that there is a **Global Ledger** section at the top of the Standing window, clearly separated from the faction list below.
3. Verify that the current **Global Renown** and **Global Infamy** totals are displayed side-by-side:
   - "Global Renown: [Total]" on the left (colored with design-system GILD_2).
   - "Global Infamy: [Total]" on the right (colored with design-system CINDER_3).
4. Verify the **Recent Causes** listed under each global total:
   - It should display the newest two causes for Renown and Infamy (if any have been earned).
   - Verify that the causes are listed newest-first.
5. Verify **Empty States**:
   - If no Renown has been gained yet, confirm it displays a clear empty state: `(No Renown accumulated yet)` under the Renown total.
   - If no Infamy has been gained yet, confirm it displays a clear empty state: `(No Infamy accumulated yet)` under the Infamy total.
   - For factions, if there are no faction-specific events, verify that the screen displays `(No faction events yet)`.
