# Chargen overhaul — mockup and build captures (2026-11-02)

Plan: `docs/design/chargen-overhaul-plan-2026-11-02.md` (PR #563). The owner approved it
2026-11-02 ("approve; build it"). Tones in the preview: "show it honestly".

## Files

| File | What it shows |
|---|---|
| `01-mockup-calling-tab.jpg` | The approved mockup, rendered from `mockup.html` with the game's data. |
| `02-built-calling-opens-rolled.jpg` | The built screen as it opens: pre-rolled, on CALLING. |
| `03-built-hover-card.jpg` | Ironbrand on Khash/Mozh with the Crown of Embers card open. |
| `04-built-locked-signature.jpg` | Debt of Arms dimmed, its card reading "Needs the Debt of Arms perk." |
| `05-built-stormbearer-gaps.jpg` | Stormbearer: "No actions of its own yet." and "No Zhur spells yet." |
| `06-built-origin.jpg`, `07-built-measures.jpg`, `08-built-name.jpg` | The other three tabs. |
| `09-built-begin-without-a-name.jpg` | BEGIN with a blank name: the status line says "Name the entry to begin" and the name field has focus. |
| `10-built-calling-1366x768.jpg` | CALLING at 1366×768. The header, tab bar, and footer buttons stay inside the frame. |

## How the build captures were made

`test/manual/chargen_register_capture.gd` opens character creation through `GameFlow` (the
production path) at 1920×1080 under Xvfb:

```bash
CAPTURE_OUT=<dir> scripts/test.sh -a test/manual/chargen_register_capture.gd
```

It also prints what it read from the screen, so the frames can be checked against text:

- `CARD` Crown of Embers: "Cells · Khash Refrain. Mark three cells within 5. … · 4 AP + 24 Breath"
- `CARD` Debt of Arms: "… Needs the Debt of Arms perk. · 1 AP"
- `STATUS` "Name the entry to begin", with focus on `NameEdit`
- `FIT` BEGIN, RANDOMIZE ALL, ROLL THIS TAB, and CANCEL ENTRY are inside the 1366×768 frame

The PNGs were converted to JPEG (quality 85) for the repo.

## Limits

- The screen was rendered by software GL under Xvfb, not on the owner's GPU or display.
- The likeness plates, emblems, and fonts are the shipped assets. There is no class art yet
  (plan gap 2).
- The "In a fight" hotbar row is not built yet. It waits for #556 to reach `main`.
