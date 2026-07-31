# Save game smoke test

- Start a new game, choose two companions, accept Coiljaw's commission, travel to Dorthkor, and move away from the entrance.
- At party, commission, arrival, and encounter checkpoints, expect **AUTOSAVED** feedback.
- Pause and choose **Manual Save**, then confirm overwrite. Expect **Chapter saved.**
- Return to the main menu and choose **Continue**. Expect the wilds to load with the player at the saved position.
- Open Inventory and Standing. Expect the acquired item and consequence history to match the saved game.
- Quit and relaunch. Expect **Continue** to remain enabled and restore the same state.
- Start **New Game** and confirm overwrite. Expect Dom, Vex alone, starting inventory, 50 Soul, and no prior consequences or quest progress.
- Confirm an old/non-v2 payload is rejected without partially changing the current session.
