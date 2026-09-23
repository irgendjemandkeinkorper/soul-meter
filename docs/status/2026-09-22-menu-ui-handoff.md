# Menu UI pass — paused 2026-09-22

User requested a pause for the day. Resume implementation only when asked.

## Agreed scope

- First screens: **character sheet, inventory, shops**.
- Visual direction: **weathered dark stone, engraved bronze, restrained ritual detail; clear text**.
- Improve readability and smooth transitions within the existing Dramgid design system. No gameplay, balance, or lore changes requested.

## Working-tree implementation so far

These edits are **unfinished and unverified**. They are saved locally, not committed or published.

| File | Current changes |
| --- | --- |
| `ui/theme/theme_builder.gd` | Added `build_ledger()`, a theme scoped to these menus: larger body text, brighter muted text, more spacing, framed panels, and semantic grid/row styles. Uses the existing notched atlas and DS tokens. |
| `ui/components/ledger_backdrop.gd` | New procedural dark stone backdrop with subtle weathering, iron framing, and a restrained eclipse engraving. |
| `ui/screens/screen.gd` | Added opt-in ledger styling and panel helpers; content-only fades; pinned footer Back button; removed the outer scroll for opted-in screens. Shared shell transitions now respect reduced-motion positioning and retain the current transition state when interrupted. |
| `ui/screens/character_sheet.gd` | Opted in; framed party list and detail pane; one detail scroll instead of nested scrolling; brighter identity text; spaced skill grid; attributes in three columns; content-only selection fade. |
| `ui/screens/inventory.gd` | Opted in; framed equipment/item details; carried-item heading; pinned Back; removed inert party tabs and placeholder stats; item selection now fades details rather than moving/fading the entire screen. |
| `ui/screens/shop.gd` | Opted in; opaque backdrop; independently scrolling catalog; pinned Back and corrected treatment-notice dismissal focus target; framed stock rows. |

The working tree also contains earlier combat, injury, treatment, and QA work. Preserve all unrelated edits. In particular, character-sheet/shop/theme files already had changes before this menu pass; do not restore whole files to undo an individual menu edit.

## Verification state

- No successful parse, automated test, or rendered check has been completed for this menu pass.
- The focused Xvfb test request was interrupted while awaiting execution/approval. `reports/ledger-menus-20260922.log` does not exist; there is no result to treat as passing.
- Existing screenshots/test results from earlier combat work do **not** verify these menus.
- Earlier completed work has separate evidence in `docs/qa/accuracy-reasons-2026-09-22.md` and `docs/qa/combat-results-2026-09-22.md`.

## Resume in this order

1. **Check parsing and affected behavior.** Inspect the current diff, then run the four focused suites below with isolated test data. Fix failures introduced by the menu changes. Follow `docs/agent-verification.md` and `docs/testing.md`; use Xvfb for rendering/input.
2. **Capture and inspect all three menus at 1920×1080 and 1280×720.** Seed representative party members and inventory/vendor content. Check text wrapping, panel widths, scroll boundaries, bottom controls, focus visibility, and the actual stone/bronze balance. The existing screenshot sweep assigns `ThemeBuilder.build()` after scene creation, which would overwrite the new ledger theme; use a focused harness that preserves the screen's theme.
3. **Finish layout and interaction details revealed by rendering.** Character-sheet injury controls and shop treatment rows still need a spacing/wrapping review. Inventory equipment labels still say EMPTY, and dropping the selected item leaves stale detail text; assess and fix those presentation issues without changing equipment mechanics. Verify shop transaction refresh and keyboard focus. Avoid adding unrequested mechanics or decorative placeholder controls.
4. **Verify transition edge cases.** Rapid inventory selections must not move or fade the root screen. Check reduced-motion behavior and closing during an enter animation. Add focused regression coverage where existing suites do not cover these changes. Check localization extraction for new strings, then record final screenshots and results in a menu QA note.

Suggested focused test command (from repository root; use an available unique disposable data directory):

```bash
LP_NUM_THREADS=1 \
SOUL_METER_TEST_DATA_DIR=/tmp/soul-meter-ledger-resume \
bash scripts/test.sh \
  -a test/integration/test_character_sheet.gd \
  -a test/integration/test_inventory_screen.gd \
  -a test/integration/test_treatment_shop.gd \
  -a test/integration/test_screen_shell_transitions.gd \
  > reports/ledger-menus-resume.log 2>&1
```

Use `design/DESIGN_SYSTEM.md`, `design/ui-shell-conventions.md`, and DS/theme tokens as the presentation authority. Keep one ceremonial bronze emphasis per screen, the SoulGauge rightmost, existing node contracts intact, and per-node theme overrides out of new work. Routine implementation and verification are authorized on resumption; commits, publication, deployment, and external review have not been requested.
