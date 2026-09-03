# Soul Meter Wave B handoff

Branch: `feat/b-wave-class-resources-2`

## Issue #229 — B6 Lensbearer Clarity

- Files: `globals/combat/class_resources/stuid_clarity.gd`, registry entry, generic unit-plate resource readout, `test/unit/test_class_resource.gd`.
- Tests: touched suite passed — `23 test cases | 0 errors | 0 failures` (includes registry, forecast/action hooks, save round-trip, and controller snapshot coverage).
- PROVISIONAL: `MAX_CLARITY = 3`, owned by B11.
- Contract gap: the seam carries `{"reveal": true}` through `on_cast_forecast`, but `Resolution` has no reveal-information channel; this is state/readout wiring only until that contract is extended.

## Issue #230 — B7 Oathclock Ledger

- Files: `globals/combat/class_resources/pazzah_ledger.gd`, registry entry, `test/unit/test_class_resource.gd`.
- Tests: touched suite passed — `23 test cases | 0 errors | 0 failures`.
- PROVISIONAL: `MAX_ENTRIES = 3`; turn delay is caller-authored; B11 owns tuning.
- Contract gap: `on_turn_start()` is owner-turn based and cannot fire a scheduler-side deferred entry while the caster is down or at an exact CT tick. `advance_ledger()` is exposed as the interim model hook. No `.tres` action was added because the seam has no deferred-resolution executor.

## Issue #231 — B8 Locksmirk Jam the Gears

- Files: `globals/combat/class_resources/fickah_rule_breaker.gd`, registry entry, `test/unit/test_class_resource.gd`.
- Tests: touched suite passed — `23 test cases | 0 errors | 0 failures`.
- PROVISIONAL: `FIZZLE_FLOOR_PERCENT = 5.0`; the existing `SkillCheckService` already enforces the same Fickah/Locksmirk floor; B11 owns the number.
- Contract gap: the seam has no scheduler cancellation hook or resource-owned action refusal/effect executor, so `jam_the_gears()` records a pending target but cannot cancel another actor’s queued/charging Song. No `.tres` action was added because it would not execute end-to-end without that contract.

## Issue #232 — B9 Stormbearer Attribution

- Files: `globals/combat/class_resources/ofshutje_attribution.gd`, registry entry, `test/unit/test_class_resource.gd`.
- Tests: touched suite passed — `23 test cases | 0 errors | 0 failures`.
- PROVISIONAL: three placeholder effects (`surge`, `fork`, `thunder`) with floors `1`, `2`, `3`; B11 owns the hidden table, strong floor, and variance.
- Contract gap: the seam does not expose a Resolution term for a seeded hidden effect draw. The resource provides a deterministic draw and records the committed seed for the snapshot, but does not alter damage/effect selection.

## Issue #233 — B10 Threadwalker Threads

- Files: `globals/combat/class_resources/izhakel_threads.gd`, registry entry, `test/unit/test_class_resource.gd`.
- Tests: touched suite passed — `23 test cases | 0 errors | 0 failures`.
- PROVISIONAL: `MAX_THREADS = 3`; B11 owns the cap and payoff tuning.
- Contract gap: the seam dispatches `on_action` only for the resource owner, not every actor, and has no delayed-payoff executor. The resource stores hidden condition/payoff data and marks matching owner-dispatched actions triggered; cross-field evaluation and payoff application remain pending seam work.

## Verification

- Required full runner attempted: `GODOT_BIN=~/.local/bin/godot xvfb-run -a bash addons/gdUnit4/runtest.sh -a test`.
- Full runner aborted before Statistics because this sandbox rejects gdUnit4's configured remote port `127.0.0.1:0`; no test result was emitted.
- Individual touched suite used the repository headless wrapper and passed with the Statistics line above.
- Re-import completed after adding class-name scripts. No quests/dialogue, generated data, or addons were modified.
- Commit note: the first local commit was created before the remaining class files were staged and includes the shared registry/test additions; subsequent commits could not be created because this worktree's Git metadata is outside the writable worktree (`.git/worktrees/bw2/index.lock: Read-only file system`). Nothing was pushed.

Overall Summary: Wave B class-resource implementations and snapshot/save tests are present; touched suite is green, full runner is sandbox-blocked before Statistics, four seam gaps are documented, and no changes were pushed.

## Fix pass

- Ledger resolutions now remain in `ready` until `drain_ready()`; the turn-hook regression advances once and verifies the ready entry.
- Fickah clears a jam only for an owner action carrying the matching `cancelled_action` marker.
- Clarity consumes only owner cast outcomes; Clarity, Fickah, and Ofshütje ignore other actors' action events.
- Hidden resource snapshots render as `ATTRIBUTION ??` on the unit plate.
- B6–B10 documentation records the state-only-until-seam-v2 boundary.
- Commits: `715ac824`, `a7f3fd21`, `7dc20319`, and `335a8d11`; the Fix pass append is present in the working tree but cannot be committed in this sandbox because the parent worktree metadata is read-only. Nothing was pushed.
- Verification via `SOUL_METER_HEADLESS=1 bash scripts/test.sh`:
  - `test/unit/test_class_resource.gd`: `23 test cases | 0 errors | 0 failures | 0 flaky | 0 skipped | 0 orphans |`
  - `test/test_unit_plate_region.gd`: `3 test cases | 0 errors | 0 failures | 0 flaky | 0 skipped | 0 orphans |`
  - `test/integration/test_combat_controller.gd`: `43 test cases | 0 errors | 0 failures | 0 flaky | 0 skipped | 0 orphans |`
