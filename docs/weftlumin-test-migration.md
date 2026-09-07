# Weftlumin test migration — E1.9 (#330)

Status: migration plan plus a skipped skeleton. No existing test is deleted or weakened.
Sources: `docs/architecture-in-game-editor.md` §2 row 3, §4.5.1, §4.12, §4.14;
the interface contract at `8e0e5fbe`; and the test sources listed below.

## Inventory and count

Matching the six singleton names **or their script paths** finds exactly 13 files:
`LayoutMode|DevConsole|CombatLab|DialogueLab|ConsequenceTimeline|QuestEditor`
and `globals/{layout_mode,dev_console,combat_lab,dialogue_lab,consequence_timeline,quest_editor}.gd`.
A name-only search finds 10; it misses `test_campaign_quest_registry.gd`,
`test_quest_editor.gd`, and `test_combat_lab.gd`. Include preload paths when repeating the inventory.

The architecture describes seven tool surfaces (§0): these six globals plus pause-menu
god mode. The source tree contains **six corresponding inert suites**, not seven.
God mode has separate coverage in `test/integration/test_debug_menu.gd` and
`test/unit/test_debug_force_complete.gd`; those remain in place. The reference to
`debug_menu.gd` in row 1 also remains covered. This plan does not resolve the
architecture's “one suite replaces seven” count by deleting or inventing a suite.

## File-to-behavior mapping

Targets below are architecture roles or existing operation names, not new API signatures.
E2/E3 define concrete panel entrypoints; #312's shell and support types remain empty.

| # | Existing test file | Pinned behavior to retain | Target panel / command boundary |
|---|---|---|---|
| 1 | `test/unit/test_campaign_quest_registry.gd` | Runtime identity/range validation; atomic registration; save round trip and missing/colliding saved rows; runtime-aware consumer source scan; reset; committed-only ledger denominator | Quest kind and existing runtime registry; update the consumer source scan when the console/god-mode consumer actually moves (§4.8, §4.12) |
| 2 | `test/unit/test_dev_console_commands.gd` | Public-API command effects; bad-argument refusal; tagged provenance; tamper marker; history; recorder events; completed-quest and untagged-completion refusal | Console interpreter and live-state commands (§4.4, §4.12) |
| 3 | `test/unit/test_quest_editor.gd` | Validation; transactional scratch writes and rollback; containment; exact authored bytes/fields; reload/register; explicit progress-conflict authorization | Quest panel and package/quest-kind operations (§4.2, §4.8) |
| 4 | `test/unit/test_dialogue_lab.gd` | Disk-derived dialogue choices; setup UI; capture/restore of runtime surfaces; restart re-arm; disarm; autosave suppression; refusal during production battle/dialogue; combat-lab exclusion | Dialogue panel, shared sandbox `arm`/`disarm`, production-owner refusal (§4.5.6, §4.8) |
| 5 | `test/unit/test_combat_lab.gd` | Catalog choices; weather-source reporting; matching-target forecast/resolution comparison; markdown export; authored-data and progression containment; disabled/live-battle refusal; restart ownership | Combat panel and sandbox-owned battle session (§4.9; retain #281/#283 dependencies) |
| 6 | `test/unit/test_campaign_encounters.gd` | Encounter schema/numeric validation; runtime overlay lifecycle; package registration; lab lists and starts runtime encounters | Encounter kind and combat panel (§4.9); future schema changes require their own reviewed migration |
| 7 | `test/unit/test_consequence_timeline.gd` | Read-only observation of both ledgers; arrival order; debug classification; retention; independent-history backfill; load resynchronization | Timeline bottom tab/model (§4.12) |
| 8 | `test/integration/test_quest_editor_inert.gd` | Disabled public entrypoints cannot create children, process input, connect signals, or write files | Shared bootstrap inert suite; retain authoring-entrypoint refusal coverage when panel replaces host (§4.14) |
| 9 | `test/integration/test_layout_mode_inert.gd` | Disabled host/gameplay scene inertness; F10 opens/closes overlay and restores pause | Shared bootstrap inert suite; scene/dressing panel and toggle ownership tests (§4.5, §4.6) |
| 10 | `test/integration/test_combat_lab_inert.gd` | Disabled host and Battle-signal inertness; F3 overlay lifecycle; recorder event | Shared bootstrap inert suite; combat panel lifecycle and recorder compatibility (§4.4, §4.9) |
| 11 | `test/integration/test_consequence_timeline_inert.gd` | Disabled host, input, ledger-connection inertness and entrypoint refusal | Shared bootstrap inert suite; timeline entrypoint refusal (§4.12, §4.14) |
| 12 | `test/integration/test_dialogue_lab_inert.gd` | Disabled host/input/DialogueManager-connection inertness; replay-entrypoint refusal | Shared bootstrap inert suite; dialogue replay refusal (§4.8, §4.14) |
| 13 | `test/integration/test_dev_console_inert.gd` | Disabled host/input/connections; F1 overlay lifecycle; unknown-command error visibility | Shared bootstrap inert suite; console lifecycle and command-error presentation (§4.12, §4.14) |

E2.5b migrates the old host tests alongside their implementations. The new bootstrap
suite does not replace command effects, sandbox containment, panel lifecycle, recorder,
or visible-error assertions. Existing suites continue running until their corresponding
coverage and implementation have moved. This issue authorizes no deletion.
God mode stays separate until the cause-bearing completion seam required by §4.12 exists;
its existing tests migrate only with that later implementation.

## Skipped inert skeleton

`test/integration/test_weftlumin_inert.gd` has a literal gdUnit4 suite gate:
`before(do_skip: bool = true, skip_reason: String = "...")`.
The installed `GdUnitTestSuiteScanner` reads these arguments from `before()`.
This is a visible skip until E2.1, not evidence that an absent bootstrap passes.

One parameterized test covers two meaningful cases: initially disabled and
enabled-then-disabled. Both require zero bootstrap children, disabled unhandled-key
processing, no `weftlumin_toggle`, no `user://weftlumin`, and no outgoing production
signal connected to a Weftlumin callable. The second case also verifies that enabling
actually registers the action before comparing the resulting disabled state.

Signal inspection walks production nodes' outgoing connections and classifies targets by
`res://addons/weftlumin/` or `res://weftlumin/` script paths. This also detects callbacks
to detached RefCounted helpers; checking only bootstrap incoming connections would miss
them. It does not load panels or assume any shell method.

E2.1 activation prerequisites:

1. Register the real `/root/WeftluminBootstrap` autoload and implement the specified
   `force_enabled_for_tests` setter/`_refresh_activation()` seam (§4.5.1).
2. Implement action registration/removal and disabled cleanup on that real bootstrap.
3. Run in an isolated, initially clean user-data root. The test never removes existing
   scratch data, and test-side deletion is not accepted as proof of inertness.
4. Change the literal `do_skip` default to `false`, retain the diagnostic reason, and
   verify both parameter rows execute. Environment presence/value and the original
   activation override are restored by the fixture.
5. Add panel-opening/production-chart lifecycle coverage with the later E2 shell work.
   This skeleton exercises activation only and does not invent #312 shell APIs.

## Validation

Verified with Godot 4.7.1 on 2026-09-06: import completes without script errors, and
the focused suite visibly skips both parameter rows with the E2.1 diagnostic reason.
The full rendered run through the repository's isolated `scripts/test.sh` wrapper
executes 1,343 of 1,345 cases across 192 suites: zero errors, failures, flaky cases,
or orphans; only the two planned bootstrap cases are skipped. Quest audit reports
zero errors, 19 existing warnings, and 7 informational findings.

This verifies compilation and the gate. It does not claim that bootstrap behavior
has passed; those assertions must execute after E2.1 supplies the implementation.
