# Enemy intent icons — #630

Review [contact-sheet.png](contact-sheet.png) at 100%: six intents at native 24 and 64 px on `DS.STONE_1` (`#1B1F27`) and captured field pixels, beside all 14 command icons at native 24 px on both backgrounds. All six use only `DS.PARCHMENT` (`#E2E8F0`). Approval remains `pending_owner_review`.

| Glyph | Depiction and reading at 24 px |
| --- | --- |
| strike | A horizontal spear-like point meets three impact marks: a directed attack, distinct from the command's diagonal sword and move's trailing bars. |
| hold | Two upright pause bars over a broad ground line: staying planted, distinct from guard's shield and end-turn's hourglass. |
| flank | A thick hooked arrow wraps around a square: a route around the side, distinct from move's straight arrow. |
| guard-ally | A solid shield beside a smaller upright pawn: protecting another, distinct from the command's single divided shield. |
| call | A flared signal horn with two expanding sound arcs: calling outward for help, distinct from speak's speech bubble. |
| flee | A leaning runner with split legs and a trailing dash: breaking away, distinct from withdraw's arrow through a doorway. |

## Visual comparison

Inspected every retained export in the final contact sheet at both native sizes, on both backgrounds; also inspected the field crop. No weak silhouette was flagged at 24 px. Semantic/owner approval remains pending. Each intent was compared with all 14 commands; none reuses a command silhouette.

All 15 intent pairs were visually checked at 24 px on both backgrounds; none shares a silhouette:

| Pair | Visible distinction |
| --- | --- |
| strike / hold | Horizontal point and impact marks / two uprights and a baseline. |
| strike / flank | Straight thrust / tall hooked route around a block. |
| strike / guard-ally | Point and burst / shield and separate round-headed pawn. |
| strike / call | Angular point and discrete impact marks / flared horn and curved arcs. |
| strike / flee | Horizontal thrust / articulated runner with round head. |
| hold / flank | Symmetric bars and baseline / asymmetric hook and square. |
| hold / guard-ally | Equal rectangular uprights / unequal shield and pawn. |
| hold / call | Parallel straight bars / flared cone and arcs. |
| hold / flee | Grounded symmetry / diagonal torso and separated legs. |
| flank / guard-ally | Hook and square / tapered shield and round head. |
| flank / call | Bent route around a block / outward sound arcs. |
| flank / flee | Continuous hook and block / articulated limbs and detached head. |
| guard-ally / call | Shield and pawn / horn and two arcs. |
| guard-ally / flee | Shield with upright companion / leaning runner and trailing dash. |
| call / flee | Cone and arcs / head, torso, and stride. |

## Capture provenance

[field-background.png](field-background.png) is an unscaled, unretouched crop `(48, 700, 1872, 790)` from the existing [1920×1080 field capture](../combat-icon-bar-2026-11-03/01-icon-bar-player-turn.png). It contains floor only. The sheet composites the exported PNGs directly over these pixels; it is not a new HUD capture or an integration of #605.

Image-generation calls: **0 / 0 allowed**, including rejects; each of the six assets used zero. SVG authoring, Godot rasterization, and PIL evidence composition only.

## Verification

Godot `4.7.1.stable.official.a13da4feb`. All Godot commands used `GODOT_BIN="$HOME/.local/bin/godot"`, `LP_NUM_THREADS=1`, `XDG_CONFIG_HOME=/tmp/codex-icons/config`, and `XDG_CACHE_HOME=/tmp/codex-icons/cache`. `XDG_DATA_HOME` was `/tmp/codex-icons/data` for import/export, and matched each test's `SOUL_METER_TEST_DATA_DIR` below. Only one task-owned Godot process ran at a time.

Commands executed, with the shared environment above:

```bash
xvfb-run -a godot --headless --path . --import
"$HOME/.local/bin/godot" --headless --path . --script tools/export_icons.gd

XDG_DATA_HOME=/tmp/codex-icons/intent-test SOUL_METER_TEST_DATA_DIR=/tmp/codex-icons/intent-test xvfb-run -a -s "-screen 0 1920x1080x24" bash scripts/test.sh -a test/unit/test_intent_icons.gd
XDG_DATA_HOME=/tmp/codex-icons/command-tests SOUL_METER_TEST_DATA_DIR=/tmp/codex-icons/command-tests xvfb-run -a -s "-screen 0 1920x1080x24" bash scripts/test.sh -a test/unit/test_combat_action.gd -a test/unit/test_combat_action_catalog.gd
XDG_DATA_HOME=/tmp/codex-icons/theme-tests SOUL_METER_TEST_DATA_DIR=/tmp/codex-icons/theme-tests xvfb-run -a -s "-screen 0 1920x1080x24" bash scripts/test.sh -a test/unit/test_theme_nine_patch.gd
```

| Check | Observed result |
| --- | --- |
| Intent exports | `Overall Summary: 1 test cases \| 0 errors \| 0 failures \| 0 flaky \| 0 skipped \| 0 orphans \|`; exit 0. |
| Combat action + catalog | `Overall Summary: 8 test cases \| 0 errors \| 0 failures \| 0 flaky \| 0 skipped \| 0 orphans \|`; exit 0. |
| Theme nine-patch | `Overall Summary: 5 test cases \| 0 errors \| 0 failures \| 0 flaky \| 0 skipped \| 0 orphans \|`; exit 0. |
| Exporter | Three runs: first artwork, final padding adjustment, unchanged rerun. Each printed `Exported 35 SVG icons at 24 and 64 px`; exit 0. All 58 existing PNGs remained byte-identical. |
| Idempotence | SHA-256 comparison: all 71 manifest/PNG files byte-identical between the final export and rerun; `git status --porcelain=v1 -uall` also identical. The working tree intentionally remains dirty for review because Git writes are prohibited. |
| Asset contracts | Six valid 64×64 SVGs, permitted shape elements and palette fill only; six manifest entries with both exports; 12 correctly sized RGBA PNGs, each with alpha extrema `(0, 255)` and nonempty bounds. All 15 intent and 84 intent/command binary-mask comparisons differ, supplementing visual inspection. |
| Whitespace | `git diff --check` passed. |

Full logs are under `/tmp/codex-icons/logs/`: `import.log`, `export-first.log`, `export-final.log`, `export-rerun.log`, `test-intent-icons.log`, `test-command-actions.log`, `test-theme.log`, and `asset-validation.log`. The temporary comparison/composition scripts are `/tmp/codex-icons/check_assets.py` and `/tmp/codex-icons/make_contact_sheet.py`.

## Open questions and deviations

- Owner approval is still pending; no intent assignment, planner behavior, prose, HUD wiring, theme token, or lore decisions were made.
- Initial import exited 0 but reported errors in unchanged seed/Pandora/PhantomCamera files and resource-leak diagnostics; no out-of-scope fixes were attempted.
- Export runs exited 0 after writing every PNG, then reported unresolved `LOAD_GAME`/`SETTINGS` members in unchanged `ui/screens/main_menu.gd` and shutdown resource leaks. Test runs reported shutdown leaks after passing assertions and exiting 0.
- Verification used the four focused suites above; the remaining unit tree was not run, per the memory constraint.
- Newly generated import/test sidecars were removed from the handoff to retain the exact requested file scope; existing UIDs were untouched. No Git writes or GitHub actions were performed.
