# Combat Lab

Combat Lab is a debug-build encounter sandbox for playtesting provisional combat balance in the running game. It launches the existing Battle/GameFlow overlay and observes the same controller events as the shipped battle HUD.

## Enablement

Combat Lab is enabled only when both conditions are true:

- the executable is a debug build;
- `SOUL_METER_COMBAT_LAB=1` is present in the environment.

Press **F3** to open or hide it. The setup screen pauses the scene and restores the scene's previous pause state when it closes. The inspector runs with `PROCESS_MODE_ALWAYS` beside the paused battle overlay.

Without enablement, the `CombatLab` autoload is inert: it creates no nodes, connects no battle signals, processes no input, and creates no files. `force_enabled_for_tests` exists only as an automated-test seam.

## Setup screen

The encounter picker is populated from `EncounterCatalog._definitions` after the catalog's normal lazy-load path; encounter IDs are not copied into the lab. Party choices combine the current party and `GameState.recruitable_candidates()`, deduplicated by member ID, and are capped at `GameState.REQUIRED_COMPANIONS + 1`.

Weather starts from the encounter's authored `EncounterCatalog._WEATHER_DEFAULTS` value when present and otherwise starts at `CALM`. The control always labels whether the effective value is an authored default, the absence of a default, or an explicit lab override. Overrides may choose any `ElementWheel.ORDER` ID or `CALM`.

The tile seed selects a grid cell, Wheel element, and charge from zero through `TileState.MAX_CHARGE_LEVEL`. The seed is applied to the controller's runtime `TileState` after the encounter is constructed. A cell outside the encounter grid is ignored.

Starting uses the production sequence: `Battle.start(encounter_id)`, followed by `GameFlow.send_event("enter_battle")`. Combat Lab never changes scenes and never substitutes its own combat controller.

## Live resolution inspector

The dock is updated by `Battle.combat_event`, `Battle.turn_resolved`, `Battle.balance_changed`, and `Battle.battle_ended`. It does not poll. It shows:

- the scheduler's upcoming order, charge/tick projection, READY_AT threshold, and cached speed when charge-time scheduling supplies them;
- the pending allied strike's authoritative controller forecast context and damage;
- the matching `action_resolved` damage, with a prominent divergence warning;
- live Balance and band, Weather element and tick, and each combatant's controller-owned tile state;
- the live `CombatStylePoints.score_breakdown()` values;
- per-action session rows and the final outcome.

The frozen combat surface has no signal for “the player selected or previewed this action.” Consequently, the pending display uses `Battle.forecast_context()`'s defined active-ally/current-target strike context. Resolved non-strike actions are recorded, but cannot be announced as pending before selection without a new production signal.

### Forecast equals resolution

Issue #209 makes forecast damage equal to resolved damage an invariant. The lab stores the damage returned by the controller's existing forecast API and compares it with the later `action_resolved` payload. It does not run `Resolution` or reproduce damage arithmetic itself.

Any mismatch is labeled **FORECAST / RESOLUTION DIVERGENCE**. That means the production forecast and commit paths disagreed and should be treated as a combat correctness defect, not smoothed over as display variance.

## Restart and export

The inspector can restart the current setup with the same random seed or with a new seed. Each restart rebuilds the encounter through `Battle.start`.

**What the seed does and does not control.** It seeds `SkillCheck`'s own
`RandomNumberGenerator` — the one genuinely stochastic source a lab session can
reach. It does **not** vary combat damage: the controller derives each damage
seed deterministically from its internal `_sequence`, which is what makes
forecast==resolution provable in the first place. So "restart with new seed"
re-rolls skill checks and leaves damage identical, and that is correct rather
than a bug. Controlling combat's damage stream would require an RNG-injection
seam inside `globals/combat/`, which the lab is not permitted to add.

**Progression containment.** The lab snapshots and restores `GameState`,
`Reputation`, `Renown`, `SaveGame.ng_plus`, and `SkillCheck`. The last two
matter because a finished lab battle runs the *production* end-of-battle path:
it accrues combat style points into `ng_plus` and can consume persistent expert
rerolls, and `Battle` then requests a save checkpoint. Restoring before that
checkpoint flushes is what keeps sandbox progress out of the player's save.

**EXPORT .MD** writes `user://combat_lab/<timestamp>.md`. The plain-text report contains:

- encounter, party, seed, weather value and source, and tile seed;
- a table of actor/action, forecast damage, resolved damage, and parity for every resolved action;
- the battle result and outcome;
- an exact `EncounterCatalog._WEATHER_DEFAULTS["<encounter>"] = "<element>"` authoring candidate when weather was overridden.

If `PlaytestRecorder` exists and accepts events, each lab battle appends one `combat_lab_battle_started` event with its encounter ID and seed.

## Observes, never rewrites

Combat Lab configures only live controller objects and its private session state. It has no runtime write path to `EncounterCatalog._WEATHER_DEFAULTS`, `EncounterCatalog._SPOILS`, the element matrix, Pandora data, or generated artifacts. Exported authoring candidates are instructions for a human to evaluate and apply by hand; exporting never applies them.
