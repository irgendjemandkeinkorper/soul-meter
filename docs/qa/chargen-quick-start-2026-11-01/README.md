# QUICK START — rendered check (2026-11-01)

Owner, 2026-11-01: "Add QUICK START" — a debug-build button on page one of character
creation that rolls every leaf, names the hero `Tester` and begins the game.

Harness: `test/manual/chargen_quick_start_capture.gd`, run under Xvfb with
`SOUL_METER_TEST_DATA_DIR=<fresh dir> bash scripts/test.sh -a test/manual/chargen_quick_start_capture.gd`.
It enters chargen through GameFlow (`start_chargen`), presses the button, and stops at the
intro with the loading handler unhooked.

| Frame | What it shows |
|---|---|
| `01-page-one-1366x768.png` | Page one at 1366×768: CANCEL ENTRY · RANDOMIZE · QUICK START · LEAF 1 OF 9 · NEXT LEAF. All three buttons sit inside the window. |
| `03-summary-stamped.png` | The press lands on the summary with the stamp struck ("RECORDED"): name `Tester`, Vael Thamshaper of the River-Mother, every leaf filled, 0 creation points left. ACCEPT is dimmed while the stamp plays, so a second press cannot accept twice. |
| `04-intro.png` | 0.35 s later GameFlow is in the intro ("THE FRONT IS COMING", 1 / 4). Skip goes straight to the Lower Trial Hall load. |

Seen in `03` and left for the UI audit (not caused by this change): when a long roll wraps
the CREATION POINTS line, the summary pushes the navigation row about 8 px past the bottom
edge, and LIKENESS prints the raw id (`likeness_02`).

**2026-11-02, UI rework U3 item 6** (`claude/chargen-summary-fix`):

| File | What it shows |
|---|---|
| `05-summary-before-after-u3.jpg` | Before (left), the summary page grows past the frame (note the outer scrollbar) and LIKENESS prints the raw id `likeness_02`. After (right, a different roll), the record scrolls inside its own column, the page fits, and LIKENESS names the plate ("Vael Hospice Wayfarer"). |
