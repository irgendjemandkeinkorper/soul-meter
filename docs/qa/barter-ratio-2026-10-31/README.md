# Barter ratio capture — 2026-10-31

Instrument: `test/manual/barter_ratio_capture.gd`, run by Claude under Xvfb:

```
bash scripts/test.sh -a test/manual/barter_ratio_capture.gd
-> 1 test cases | 0 errors | 0 failures
```

Same vendor (Iron & Thread), same basket, two Sway values for the protagonist (Vex). The script asserts that the readout text differs and that every displayed price equals the silver actually charged or paid.

| Capture | Sway | Ratio | Roadwarden Spear buy / sell |
|---|---|---|---|
| `barter-sway-00-1920.png` | 0% | buy ×1.00 / sell ×1.00, "No barter adjustment" | 58 / 28 |
| `barter-sway-95-1920.png` | 95% (the cap, `SkillCheck.MAX_EFFECTIVE_PERCENT`) | buy ×0.80 / sell ×1.20, base prices shown | 46 / 33 |

`BARTER_SWING` and all prices are unchanged; only their display is new.
