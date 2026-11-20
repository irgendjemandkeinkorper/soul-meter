# Mock NG+ rollover — #652 gap 5

Rendered check for the minimal mock NG+ (owner item 48(c)).
Captured by `test/manual/mock_ng_plus_capture.gd` under Xvfb at 1920×1080, on branch `claude/652-mock-ng-plus`.

## Frames
1. **`01-chapter-complete.jpg`:** the chapter-complete screen with 37 style points staged.
   - The ledger gains **STYLE POINTS 37**.
   - **Begin Mock NG+** sits between Continue Exploring and Return to Title.
   - The company, ruling and side threads are the harness's seeded demo state, not a played chapter.
2. **`02-title-armed.jpg`:** the title after the **real** button press. The handler saved the run, armed the block, and sent `to_main_menu`.
   - The notice reads "MOCK NG+ · New Game starts over carrying 37 style points and Chapter One's completion."
   - Continue and Load Game are enabled because the press saved the run.
3. **`03-hadrik-echo-line.jpg`:** Hadrik Vale's hub after New Game applied the block. His NG+ echo line, "Have you filed a reflection that remembers me?", is offered first.
   - The harness opens the `hub` title directly. That title is response-only, so the line box is empty and there is no portrait. In play, Hadrik's opening line sits above these choices.

## Checked in the log
- `ARMED { "style_points": 37, "purchased_carry_overs": [], "completion_metadata": { "chapter_completions": 1, "mock": true } }`
- `NOTICE MOCK NG+  ·  New Game starts over carrying 37 style points and Chapter One's completion.`
- `APPLIED active=true`, with the same block.

## How the harness differs from play
- The harness builds a fresh title from its scene rather than waiting for GameFlow's chart to load it.
- A private `SaveGame` instance runs New Game, so no Dom load starts inside the harness. The block it produces is the one the autoload would hold. `test_mock_ng_plus.gd` covers the autoload's arm, apply and clear path.
