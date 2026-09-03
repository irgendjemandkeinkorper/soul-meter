# HANDOFF-BW1

Branch: `feat/b-wave-class-resources-1`
Commits: `6510239f`, `1b75820d`, `bb28a93c`, `e3b6974d`, `051de11c`

## Issue #224 — B1 Mirrorblade Balance

- Files: `globals/combat/class_resources/maiiam_balance.gd`, registry entry, Wave B unit tests.
- Hooks: `on_action`, `on_cast_forecast`; alternating `strike`/`guard` is Balanced, repeated side reaches Unbalanced, forecast applies damage scale and fizzle-integrity penalty.
- PROVISIONAL numbers: streak threshold 2, damage multiplier 1.25, integrity penalty 15.0; B11 owns tuning.
- Tests: `test_mirrorblade_balance_alternation_and_forecast_hooks`, registry lookup, save coverage.
- Contract gaps: none for the implemented channels.

## Issue #225 — B2 Flamebinder Instructive Failure

- Files: `globals/combat/class_resources/vicoar_instructive_failure.gd`, registry entry, Wave B unit tests.
- Hooks: `on_fizzle`, `on_cast_forecast`, `on_action`; fizzle tokens bank, `spend_token()` arms a one-shot window, and resolved actions consume it.
- PROVISIONAL numbers: token cap 3; B11 owns tuning.
- Tests: `test_flamebinder_fizzle_spend_and_action_hooks`, registry lookup, save coverage.
- Contract gap: Resolution has no direct `fizzle_percent = 0` override. Existing `mastery=true` only guarantees Note/Phrase, so general casts are not fully guaranteed until the seam exposes that channel.

## Issue #226 — B3 Ironbrand Scars

- Files: existing `ironbrand_scars.gd` exercised by new Wave B tests; generic unit-plate snapshot readout in `ui/hud/regions/unit_plate/`.
- Hooks: `on_damage_taken`, `on_cast_forecast`, `on_action`; guaranteed-hit window remains the existing B0 worked example.
- PROVISIONAL numbers: existing Scars cap 5; B11 owns tuning.
- Tests: `test_ironbrand_scars_damage_forecast_action_and_save_hooks`, existing B0 controller/save tests.
- Contract gaps: guaranteed-crit remains unavailable because Resolution has no crit channel, as documented by B0.

## Issue #227 — B4 Husk-bearer Hunger

- Files: `globals/combat/class_resources/vhorr_hunger.gd`, registry entry, Wave B unit tests.
- Hooks: defensive `on_action` handling for a future `dot` write and `on_kill` handling for `cause == dot`; state is exposed in the snapshot and serialized.
- PROVISIONAL numbers: Hunger cap 5 and pending Soul refund 1.0; B11 owns tuning.
- Tests: `test_husk_bearer_dot_write_and_kill_hooks`, registry lookup, save coverage.
- Contract gaps: B0 emits no DoT write kind and no Soul-refund hook. The implementation stores pending refunds but cannot apply them without changing the seam.

## Issue #228 — B5 River-Mother Name-Ledger

- Files: `globals/combat/class_resources/haeren_name_ledger.gd`, registry entry, `data/combat/actions/11_record_name.tres`, Wave B unit tests.
- Hooks/API: `record_name()` deduplicates names per resource/battle state and banks pending refund state; snapshot and save round-trip are covered.
- PROVISIONAL numbers: Soul refund 1.0; action AP/CT 2/2 copied from the nearest PASS-compatible action; B11/B13 own final values.
- Tests: `test_river_mother_records_each_name_once_and_round_trips`, action resource assertions, registry lookup.
- Contract gaps: the seam has no command-effect hook for applying the action, no battle-event payload hook for fallen/saved ally names, and no Soul-refund hook. The action is authored and the model API is ready, but controller wiring remains outside the frozen seam.

## Verification

- Re-import completed after adding all `class_name` scripts.
- Focused Wave B + B0 seam suites: `18 test cases | 0 errors | 0 failures`.
- Full headless fallback: `1267 test cases | 0 errors | 1 failure`; unrelated failure: `test_combat_identity.gd:44` (`test_mundane_action_pulls_order_and_chaos_values_toward_generated_center`).
- The requested addon wrapper reproduced the documented sandbox abort before statistics (`tcp://127.0.0.1:0`, signal 11/exit 134).
- Quest audit not run: no quests or dialogue were touched.
- No push performed; worktree is clean.

Overall Summary: Wave B class resources #224–#228 implemented within the frozen B0 seam; focused tests green, full suite has one unrelated pre-existing failure, and three seam gaps are documented above.

## Fix pass

- Preserved full `unit`/`fizzle` forecast sub-dictionaries under shallow seam merge; Vicoar now consumes the armed window only on CAST resolution and refunds it on fizzles.
- Disabled the unimplemented Record Name action, hid inert Hunger from the unit plate, and removed string-valued snapshot maxima for Balance and Name-Ledger.
- Added controller-level forecast context coverage and updated Wave B regression tests.

## Wiring pass

- Flamebinder now uses seam v2 `fizzle_percent_override = 0.0` for every armed cast.
- Hunger now queues/requeues `dot` writes by live stack count and queues `soul_refund` on DoT kills; pending state and deferred entries remain serializable.
- Name-Ledger now routes `Record Name` through the generic `on_command(action_id, target_id)` hook, watches ally deaths/final enemy defeat through `on_any_action`, and emits one refund per recorded actor.
- `Record Name` is player-available with `center_pull = 10`; Mirrorblade and Ironbrand remain unchanged and their deep-merge/forecast tests pass.
- Verification: requested suites passed — `7 + 14 + 4 + 44 = 69 test cases | 0 errors | 0 failures | 0 flaky | 0 skipped | 0 orphans`.
- No push performed.

## Fix pass 2

- Name-Ledger refunds now require an `hp`/`dot` write targeting a recorded actor; enemy deaths and
  ally CT/breath writes do not refund. Record Name requires an explicit living ally and dispatches
  only to the owner's resource.
- Hunger stacks on every successful player strike/cast, keeps one pending self-re-queuing DoT chain
  per target, stops the chain on kill, and serializes pending targets. DoT kill refunds land on the
  live `GameState` Soul meter through the deferred write path.
- Documented the two host methods, provisional fall/end refund paths, and Hunger hit/deferred-tick
  behavior. Added controller dispatch and Wave B regression coverage.
- Verification: `test_wave_b_class_resources.gd` 9 cases, `test_class_resource.gd` 11 cases,
  `test_combat_identity.gd` 4 cases, `test_combat_controller.gd` 45 cases; all passed with zero
  errors/failures. No push performed.
