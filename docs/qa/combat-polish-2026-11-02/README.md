# Combat polish — demo and effect captures (2026-11-02)

As built: `docs/design/combat-polish-2026-11-02.md`. Rulings (owner, 2026-11-02, all the
recommended options): approach-and-act `preview, then refuse`; 5v5 `you lead 5, AI runs 5`;
animation `motion on current art`; effects `one look per tone + class flourishes`.

## Files

| File | What it shows |
|---|---|
| `01-demo-opening-two-lines.jpg` | CLASS DEMO (5V5) as it opens in Kesselford: your five in a line, the AI's five in a line five steps across. |
| `02-walk-in-quote.jpg` | Hovering an enemy out of reach: the path draws and the quote reads "WALK IN · MOVE 2 + STRIKE 2 = 4 AP". |
| `03-walk-in-one-order.jpg` | One click: the unit walks two cells and strikes (Husk-bearer 30 → 26). |
| `04-ai-five-used-their-kits.jpg` | The AI side's first round from the log: Shroud, Blinding Throw, Witness Light, Jam the Gears, and a move. |
| `05-class-flourish-river-mother.jpg` | River-Mother's class command with its flourish at the actor. |
| `06-tone-cast-impact-kindle.jpg` | Kindle (Khash) lands 7 on Threadwalker: the Khash look at the target. |
| `07-looks-sheet-t03.jpg`, `08-looks-sheet-t06.jpg` | Every look at two moments of the beat: the ten tones on top, the ten class flourishes below. |

## How the captures were made

Both run under Xvfb at 1920×1080:

```bash
CAPTURE_OUT=<dir> scripts/test.sh -a test/manual/class_demo_capture.gd
CAPTURE_OUT=<dir> scripts/test.sh -a test/manual/combat_looks_capture.gd
```

- `class_demo_capture.gd` presses CLASS DEMO through `GameFlow.start_class_demo()` (the title
  button's path), plays turns until an enemy can be walked to, and shoots frames 01–06.
- Software GL under Xvfb draws a few frames a second, so the capture slows the engine
  (`Engine.time_scale = 0.15`) and waits on each effect's own clock before it shoots.
- `combat_looks_capture.gd` draws every look on one sheet, straight from `CombatLook`.

The PNGs were converted to JPEG (quality 85) for the repo.

## Limits

- Software GL under Xvfb, not the owner's GPU or display. Motion and timing were checked by
  tests, not by eye at full frame rate.
- The bodies are the shipped idle art. Walk, attack, hit and fall frames do not exist yet;
  the poses (hop, lean, recoil, lift, slump) move that one frame.
- Look sizes and colours are PROVISIONAL (owner list item 30).
- A cast that deals no damage (Douse) still draws the miss seal. This predates the branch.
