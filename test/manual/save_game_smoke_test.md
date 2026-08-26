# Save game smoke test

- Start a new game, choose two companions, accept Coiljaw's commission, travel to Dorthkor, and move away from the entrance.
- At party, commission, arrival, and encounter checkpoints, expect **AUTOSAVED** feedback.
- Pause and choose **Save — Slot 1**. Expect **Saved to slot 1.** and the button label to pick up the location + play time.
- Save to Slot 1 again. Expect a **Confirm Overwrite — Slot 1** arm step first; pressing a different slot button disarms it.
- Save to Slot 2 in a different location. Expect both slot labels to show their own location/time (slots are independent).
- Return to the main menu and choose **Continue**. Expect the wilds to load with the player at the saved position.
- From the main menu choose **Load Game**. Expect the autosave row plus 3 slot rows — empty slots disabled, filled slots labeled with location/time — and loading Slot 2 to restore that state.
- Open Inventory and Standing. Expect the acquired item and consequence history to match the saved game.
- Quit and relaunch. Expect **Continue** to remain enabled and restore the same state.
- Start **New Game** and confirm overwrite. Expect Dom, Vex alone, starting inventory, 50 Soul, and no prior consequences or quest progress.
- Confirm an old/non-v2 payload is rejected without partially changing the current session.
