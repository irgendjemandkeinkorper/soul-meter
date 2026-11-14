# U1 conversation rework: after captures (2026-11-01)

Rendered under Xvfb at 1920×1080 by `test/manual/ui_audit_capture.gd`, the same harness that
made the "before" set in `../ui-audit-2026-11-01/`. Plan and rulings:
`docs/design/ui-rework-plan-2026-11-01.md`.

| After | Before | What changed |
|---|---|---|
| `01-iris-choice-menu.jpg` | `01-conversation-iris-menu.jpg` | 15 rows (10 locked) → 6 (1 locked, with its reason). Exact effect chips on each row. The field HUD, its second Soul gauge and the world labels are gone. The promise line shows once, for the focused choice. |
| `02-iris-after-a-choice.jpg` | `02-conversation-after-choice.jpg` | The reply carries its ledger strip: `RECORDED · SSAE SEEDERS +8`. The field notice for that event is not repeated after the conversation. |
| `03-council-skill-check-menu.jpg` | `03-conversation-council-check.jpg` | 8 rows (6 locked) → 3. The locked Undertone check names its bar: `Undertone 40 needed — you have 0.` Dom's building names no longer show through. |
| `04-council-open-check.jpg` | (new) | The same check, open: `[UNDERTONE] 52%`, the chance `resolve()` rolls against. |

The capture party has no trained protagonist, so "you have 0" in `03` is the harness's state,
not a bug. `04` gives the protagonist 52% Undertone.
