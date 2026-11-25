# Calling and measures — captures (2026-11-25)

Evidence for `docs/design/calling-and-measures-2026-11-25.md`. Each slice adds its frames with
its slice prefix.

## S2 — measure readouts

| File | What it shows |
|---|---|
| `s2-01-calling-lensbearer-reason-5.jpg` | A Lensbearer's class card: PATRON MEASURE · REASON, "Reason 5 now: 5 Clarity each battle." |
| `s2-02-measures-lensbearer-reason-5.jpg` | The MEASURES tab for that build. Each row shows its live numbers, then in gold what +1 would change. The Reason row carries "Lensbearer: 5 Clarity each battle". |
| `s2-03-measures-ironbrand-grit-5.jpg` | The same register as an Ironbrand at Grit 5: HP 42, "Ironbrand: Scars bank up to 5". |
| `s2-04-calling-ironbrand-grit-5.jpg` | The Ironbrand card: "Grit 5 now: Scars bank up to 5. The most a measure reaches at creation." |
| `s2-05-measures-1366x768.jpg` | The MEASURES tab at 1366×768: rows wrap inside the column, buttons stay centred on their rows. |

## How they were made

```bash
CAPTURE_OUT=<dir> GODOT_BIN=~/.local/bin/godot scripts/test.sh -a test/manual/calling_measures_capture.gd
```

Rendered by software GL under Xvfb, not on the owner's GPU. PNGs converted to JPEG (quality 85).
