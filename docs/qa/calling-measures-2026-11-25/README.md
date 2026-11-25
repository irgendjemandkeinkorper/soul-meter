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

The S2 frames were re-rendered after S5, so the MEASURES frames also show the SUGGEST button.

## S4 — Disciplines live

| File | What it shows |
|---|---|
| `s4-07-calling-stormbearer-chordblade.jpg` | The DISCIPLINE line ends with what it does in a fight: "every path costs 20% less." |

The fight effects themselves (footwork price, footing term, hushed cells) are proven headless in
`test/integration/test_disciplines_in_combat.gd`; no battle frame was taken.

## S5 — class-shaped rolls

| File | What it shows |
|---|---|
| `s5-06-measures-stormbearer-suggested.jpg` | SUGGEST FOR STORMBEARER placed Intuition 5 (patron measure), Muster 4 (the Heft Kit's measure), then 3s. The Intuition row carries "Stormbearer: Storm rows deal +3 to +8"; the Kit line reads "Heft (Kit): 52% · weapon hits +6%" (S3). |

## How they were made

```bash
CAPTURE_OUT=<dir> GODOT_BIN=~/.local/bin/godot scripts/test.sh -a test/manual/calling_measures_capture.gd
```

Rendered by software GL under Xvfb, not on the owner's GPU. PNGs converted to JPEG (quality 85).
