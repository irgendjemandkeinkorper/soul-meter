# Menu graphics completion — 2026-09-25

The character sheet, inventory, and shop pass resumed from the September 22 handoff.
The existing dark stone backdrop, notched bronze framing, larger typography, and pinned
Back controls are retained. This completes the scoped layout and interaction work.

## Screenshots

Unmodified Godot 4.7.1 runtime captures under Xvfb. Each screen keeps its own ledger theme.

| View | 1920×1080 | 1280×720 |
| --- | --- | --- |
| Character sheet | [View](ledger-menus-2026-09-25/character_sheet-1920.png) | [View](ledger-menus-2026-09-25/character_sheet-1280.png) |
| Inventory | [View](ledger-menus-2026-09-25/inventory-1920.png) | [View](ledger-menus-2026-09-25/inventory-1280.png) |
| Herbalist | [View](ledger-menus-2026-09-25/shop-1920.png) | [View](ledger-menus-2026-09-25/shop-1280.png) |
| Equipment vendor | [View](ledger-menus-2026-09-25/equipment-shop-1920.png) | [View](ledger-menus-2026-09-25/equipment-shop-1280.png) |
| Injury controls | [View](ledger-menus-2026-09-25/injuries-1920.png) | [View](ledger-menus-2026-09-25/injuries-1280.png) |
| Treatment receipt | [View](ledger-menus-2026-09-25/shop-recovery-1920.png) | [View](ledger-menus-2026-09-25/shop-recovery-1280.png) |

## Observable changes

- Character-sheet columns fit 720p without pushing the portrait or SoulGauge off screen.
  Identity, injury, and recent-check text wraps; field treatment puts the practitioner
  above a two-line supply action. Keyboard focus scrolls the details into view.
- Inventory columns leave room for the eight-column bag. Cell sizes adapt between the
  existing 48px and 64px DS sizes; the inherited small slot scene keeps item artwork inside
  compact cells. Item positions, footprints, capacity, and save data remain unchanged.
- Equipment labels update on equip, removal, and reopening. Dropping the selected bag
  item clears its details and disables empty actions. Equip uses the existing BronzeButton
  variation; unavailable actions are disabled.
- Shops wrap titles and metadata, retain keyboard focus on refreshed purchase controls,
  and fall back to Back when that action becomes unavailable. Initial focus waits for
  catalog layout. Treatment receipts retain dismissal focus, and changing vendors clears
  the previous transaction message.

## Verification

**32 distinct checks passed.** The four affected integration suites passed 30/30 in
`reports/report_1612/results.xml`; the final shop and capture run passed 8/8 in
`reports/report_1613/results.xml` (six shop checks repeated plus two rendered cases).
Both processes exited 0, with zero test errors, failures, skips, or reported test orphans.

Suites: `test_character_sheet.gd`, `test_inventory_screen.gd`, `test_treatment_shop.gd`,
and `test_screen_shell_transitions.gd` in `test/integration`, plus
`test/manual/ledger_menu_capture.gd`. New coverage includes stale dropped-item details,
equipment labels through save/reopen, rapid selection without root movement, reduced-motion
positioning, interrupted enter/exit animations, and focus after shop refresh.

Rendered assertions check body/footer bounds, treatment visibility, and receipt focus at
both resolutions. All six view types above were visually inspected. These are representative
English fixtures, not exhaustive checks of every party, item, or language.

Commands used `bash scripts/test.sh`, `LP_NUM_THREADS=1`, and disposable data directories
under `/tmp/soul-meter-ledger-20260925-*`. Reproduce screenshots by selecting
`-a test/manual/ledger_menu_capture.gd` with a fresh `SOUL_METER_TEST_DATA_DIR`.
Run suites sequentially when retaining gdUnit XML reports: its shared report-number
allocator can collide even when player-data directories are separate.

`git diff --check` and the artifact-only acceptance gate passed. The locale catalogs remain
aligned at 53 msgids. The menu scripts are not currently in the project's POT extraction
list; the existing English menu labels and dynamic treatment string remain a localization
coverage gap. This pass adds no new prose beyond the existing menu labels and a line break.

Godot still reports ObjectDB/resource diagnostics at shutdown, also present before these
changes. Successful tests are not a warning-free engine run. The complete release suite,
packaged exports, and physical-device rendering were not run for this scoped menu pass.
No commit or publication was requested.
