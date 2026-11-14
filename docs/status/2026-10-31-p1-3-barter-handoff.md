## Handoff back

P1.3 / #532 is implemented on `codex/roadmap-p1-3-barter-ratio`. Rendered acceptance is pending: the sandbox cannot initialize X11 or Wayland.

### What now works and how to see it

Open any vendor shop. A persistent readout names the barterer, shows effective Sway and both exchange multipliers, and explicitly explains zero adjustment. Buttons show the exact payable/receivable amounts; muted base prices appear only where barter changes the rounded amount. Existing refusal messages remain intact.

The readout and prices refresh on party replacement, skill advancement, Mirror Rewriting, Karma changes, and vendor reputation-band changes. Advancement and rewriting emit the existing Resource `changed` signal; no GameState signal was added. Existing theme variations provide styling. Scene paths, `BARTER_SWING`, all pricing formulas, and the #284 standing-modifier comment are unchanged.

The existing `GameState.barter_ratio()` resolves the protagonist even after party reordering. The readout names that same person, preserving prices and existing subject-selection tests. It never substitutes the first party slot or rolls dice.

The rendered acceptance command is:

```bash
GODOT_BIN="$HOME/.local/bin/godot" LP_NUM_THREADS=1 \
  SOUL_METER_TEST_DATA_DIR="$(mktemp -d /tmp/soul-meter-p1-3-capture.XXXXXX)" \
  bash scripts/test.sh -a test/manual/barter_ratio_capture.gd
```

It opens Iron and Thread with the same spear/hammer/rivets basket at 0% and 95% Sway, using `Advancement.buy()` to change Sway. It asserts different visible text, layout bounds, and displayed-price/GP-delta equality. With a display, it saves `user://qa/barter-sway-00-1920.png` and `user://qa/barter-sway-95-1920.png`. Headless runs execute accounting/layout assertions and explicitly produce no PNGs.

### Changed files

| File | Change |
| --- | --- |
| `globals/advancement.gd` | Resource notifications after successful advancement/refunds. |
| `globals/game_state.gd` | Unbartered buy/sell prices at the current vendor/reputation band; corrected subject comment. |
| `ui/screens/shop.gd` | Live readout, zero/no-leader explanation, muted base prices, signal subscriptions. |
| `locale/project.pot`, `project.godot` | Six msgids and shop registration for POT extraction. |
| `test/fixtures/barter_shop_fixture.gd` | Shared isolated basket, state restoration, advancement API, visible-price helpers. |
| `test/unit/test_shop_barter.gd` | Eight tests for accounting, live updates, identity, base prices, and refusal behavior. |
| `test/manual/barter_ratio_capture.gd` | Two-state capture and headless accounting preflight. |
| `docs/status/2026-10-31-p1-3-barter-handoff.md` | This handoff. |

### Checks run with results

Engine: Godot 4.7.1 stable, `a13da4feb`. All runs used `GODOT_BIN="$HOME/.local/bin/godot"`, `LP_NUM_THREADS=1`, and disposable test data. The required `bash scripts/test.sh -a test/unit`, focused suites, and capture were first attempted with the default Xvfb wrapper; each exited 1 before tests started:

```text
ERROR: X11 Display is not available
ERROR: Can't connect to a Wayland display.
ERROR: Unable to create DisplayServer, all display drivers failed.
```

Full unit CI-equivalent fallback, exit 0:

```bash
SOUL_METER_HEADLESS=1 GODOT_BIN="$HOME/.local/bin/godot" LP_NUM_THREADS=1 SOUL_METER_TEST_DATA_DIR="$(mktemp -d /tmp/soul-meter-p1-3-unit-headless.XXXXXX)" timeout 1800 bash scripts/test.sh -a test/unit
```

```text
Overall Summary: 1972 test cases | 0 errors | 0 failures | 0 flaky | 0 skipped | 0 orphans |
Executed test suites: (194/194)
Executed test cases : (1972/1972)
Total execution time: 3min 0s 730ms
```

Focused suites, exit 0:

```bash
SOUL_METER_HEADLESS=1 GODOT_BIN="$HOME/.local/bin/godot" LP_NUM_THREADS=1 SOUL_METER_TEST_DATA_DIR="$(mktemp -d /tmp/soul-meter-p1-3-focused-headless.XXXXXX)" timeout 300 bash scripts/test.sh -a test/unit/test_shop_barter.gd -a test/unit/test_vendor_pricing.gd -a test/unit/test_vendors.gd -a test/unit/test_advancement.gd -a test/integration/test_treatment_shop.gd
```

```text
Overall Summary: 48 test cases | 0 errors | 0 failures | 0 flaky | 0 skipped | 0 orphans |
Executed test suites: (5/5)
Executed test cases : (48/48)
Total execution time: 1s 382ms
```

Capture headless preflight, exit 0:

```bash
SOUL_METER_HEADLESS=1 GODOT_BIN="$HOME/.local/bin/godot" LP_NUM_THREADS=1 SOUL_METER_TEST_DATA_DIR="$(mktemp -d /tmp/soul-meter-p1-3-capture-headless.XXXXXX)" timeout 120 bash scripts/test.sh -a test/manual/barter_ratio_capture.gd
```

```text
BARTER-CAPTURE: headless accounting only; no PNGs rendered.
BARTER-CAPTURE: sway=0% buy=114 sell=55 net=59; BARTER  ·  Vex  ·  SWAY 0%  ·  BUY ×1.00 / SELL ×1.00
BARTER-CAPTURE: sway=95% buy=90 sell=65 net=25; BARTER  ·  Vex  ·  SWAY 95%  ·  BUY ×0.80 / SELL ×1.20
Overall Summary: 1 test cases | 0 errors | 0 failures | 0 flaky | 0 skipped | 0 orphans |
```

`GODOT_BIN="$HOME/.local/bin/godot" LP_NUM_THREADS=1 timeout 300 bash scripts/check_generated_data.sh` exited 0:

```text
GLOOT-GEN: no drift.
CANON-SEED: no drift.
LOCATIONS-GEN: no drift.
ISO-SPRITE-GEN: no drift. 598 sprites verified.
```

`git diff --check 935fc340^..HEAD` passed. All six shop `tr()` strings have POT entries. Logs: `/tmp/soul-meter-p1-3-{unit-display,unit-headless,focused-headless,capture,capture-headless,generated-data}.log`.

### New player-facing strings

| Purpose | Exact msgid |
| --- | --- |
| Readout | `BARTER  ·  %s  ·  SWAY %s%%  ·  BUY ×%.2f / SELL ×%.2f` |
| Missing subject | `NO LEADER` |
| Zero adjustment | `NO BARTER ADJUSTMENT` |
| Base buy | `BASE BUY  ·  %d SILVER` |
| Base sell | `BASE SELL  ·  %d SILVER` |
| Base offering | `BASE OFFER  ·  %d SILVER` |

### Risks

- No PNGs were produced; rendered appearance remains unverified. Headless bounds checks do not establish visual correctness.
- Multipliers display two decimal places; item prices retain the unchanged exact integer rounding/accounting path.
- Godot emitted ObjectDB/resource diagnostics during teardown despite exit 0. The unit run reported `WARNING: 388132 ObjectDB instances were leaked at exit (run with --verbose for details).` and `ERROR: 74 resources still in use at exit (run with --verbose for details).` Focused/capture runs also emitted teardown diagnostics. No crash occurred.

### Open decisions for the owner

None. No economy, subject-selection, canon, or R7-density decision was introduced.

### Code commits

- `935fc340a88f17b723693b96c21d20fc2797f97c` — `feat(shop): show live Sway barter ratios and base prices`
- `b452c6f4e4c4e49199291a02bf73ce3a2a8108cc` — `test(shop): capture and reconcile zero and mastered barter`

No branch switch, network call, push, or PR operation was performed. The four pre-existing untracked `.gd.uid` files remain untouched: `test/integration/test_loom_field_verbs.gd.uid`, `test/unit/test_encounter_verb_audit.gd.uid`, `test/unit/test_soul_lowest.gd.uid`, and `tools/audit_encounter_verbs.gd.uid`.

### Next milestone

Claude runs the display-backed capture above, reviews both PNGs, and integrates P1.3 into the existing PR stack.
