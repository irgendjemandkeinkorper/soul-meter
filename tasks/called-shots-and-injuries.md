# Called-shot expansion — implementation checklist

**Status:** Accuracy foundation (task 2) verified 2026-09-18; lab aimed attack (task 3) and HUD aim selection (task 4) and line-of-fire/exposure (task 5), physical visibility (task 6), bounded location injury (task 7), throat/vocal integration (task 8), persistent serious injuries (task 9), and the atomic treatment operation (task 10A) implemented 2026-09-19; Checkpoint B reached. Treatment interactions (10B/10C), content, and AI remain planned.

**Confirmed decisions, 2026-09-17:** The user chose separate combat design/task files and serious injuries that persist until treated. Persistence and treatment tasks are required.

**Confirmed decision, 2026-09-18:** Qualified Mending can cure serious injuries outside combat. Task 10C is required; exact qualification thresholds, costs, and success rules remain proposals.

**Additional confirmed decisions, 2026-09-18:** Visible anatomy is freely targetable; hidden/supernatural weaknesses retain discovery. Aimed attacks use an extra action cost plus an accuracy penalty, with AP and CT surcharges authored separately. Exact values remain provisional.

**2026-09-18 progress:** Treatment/recovery contracts drafted; task 10 split into transaction, healer, and field-treatment slices. Task 2 is complete without adding new balance terms. [Verification evidence](../docs/qa/combat-accuracy-2026-09-18.md). Next implementation: task 3's lab fixture; unresolved injury tuning does not block that slice.

**2026-09-19 progress:** Task 3 landed: `CalledShot` legality/pricing, controller aim query at forecast and commit, lab fixture with synthetic anatomy, and 9 aimed-action tests under both schedulers (`test/integration/test_called_shots.gd`, `test/unit/test_combat_lab.gd`). A JSON-replayed aim context now logs identically to the live one. The lab panel was not inspected rendered; Checkpoint A's third item is covered only by the hidden-result assertions from task 2. Task 4 landed the same day: forecast-panel aim row, interface aim mode, controller-quoted disabled reasons, rendered capture. [Evidence](../docs/qa/called-shot-hud-2026-09-19.md). Task 5 landed: authored obstacles refuse `blocked_by_obstacle`, low cover hides cover-hidden anatomy (`aim_cover`) unless seen over from height, legacy cover mitigation retained without a second charge. [Evidence](../docs/qa/called-shot-exposure-2026-09-19.md). Task 6 landed: per-cell clear/dim/obscured composed worst-of, ranged-only applicability, Blinded reconciled to its facing restriction, provisional −10/−25 pp, live forecast refresh. [Evidence](../docs/qa/called-shot-visibility-2026-09-19.md). Task 7 landed: `CombatInjury` records on `BattleActor.injuries` (one per location, refresh on repeat, replay no-op), injury eligibility decided after mitigation, arm injury as a named −10 pp attack modifier that leaves Alacrity and spells alone, HUD/lab quotes with on-hit and overall chance. [Evidence](../docs/qa/called-shot-injury-2026-09-19.md). Task 8 landed: `CombatAction.requires_voice` delivery metadata, minor throat as a voice-only accuracy term, severe throat (`voice_blocked`) refusing `voice_required` before payment, and a voice-blocking hit releasing the target's held Note once through `release_hold`. Muted is untouched. [Evidence](../docs/qa/called-shot-vocal-2026-09-19.md). Task 9 landed: `PartyMember.injuries` serialized as an optional key (old saves load empty, malformed records dropped, unknown record keys kept), mirrored into `BattleActor`, written back by `Battle` at victory/defeat/flee with minor records dropped; hostile records live on the Hostile node's actor for the field's lifetime. No schema bump. [Evidence](../docs/qa/called-shot-persistence-2026-09-19.md). Task 10A landed: `InjuryTreatment` quote/commit coordinator over `PartyMember.injuries`, `spend_gp`, and `remove_items`; records carry `instance_id` + revision; test cards (20 GP service, one-supply field with Trained Mending); dev-console `treat` fixture. [Evidence](../docs/qa/called-shot-treatment-2026-09-19.md). Next implementation: task 10B (healer service interaction).

**Architecture:** [Called shots, accuracy, and injuries](../docs/ideas/called-shots-and-injuries.md). Existing `tasks/plan.md` and `tasks/todo.md` remain owned by their current work.

Each task targets one focused session. Estimates are engineering planning ranges, including focused verification, not delivery commitments. New helper and test filenames below are proposals. UID files and documentation updates accompany their owning slice. Split a task further if discovery expands it beyond about five substantive files.

## Phase 1 — explain and aim

### 1. Record the gameplay contracts — 30–60 minutes

**Scope:** Settle the rule changes needed before gameplay implementation; record accepted versus deferred choices in the architecture proposal and relevant existing requirements.

**Acceptance:**
- [x] Ordinary anatomy and discovered Defining Strike eligibility are explicit; FR103's menu restriction is reconciled.
- [ ] Aim costs, delivery tags, injury eligibility/stacking, and accuracy modifier order have a reviewable contract; provisional values are labeled.
- [ ] Recovery contract specifies treatment access, costs, outcomes, and minor-injury duration; serious injuries persist until treated as already confirmed.

**Verification:** Cross-check class cards, martial proposal, existing statuses, and save ownership. No gameplay suite needed for this documentation task.

**Dependencies:** None. **Likely files:** architecture proposal, `docs/prd-chapter-one.md`, `docs/ideas/martial-combat-rules.md`, relevant class-card rules. **Size:** M.

### 2. Explain an ordinary attack without changing its result — 60–120 minutes

**Scope:** Produce a typed/validated accuracy breakdown through the existing resolver and forecast boundary.

**Acceptance:**
- [x] Current ordinary attacks retain hit chances, cost, and deterministic outcomes for fixed fixtures, including legacy non-to-hit paths.
- [x] Forecast exposes named percentage-point modifiers and existing illegal-shot reasons without advancing RNG or action sequencing.
- [x] Existing Defining Strike consequences cannot apply after a physical miss; add a focused regression for the real submit path.

**Implemented boundary:** `Resolution.accuracy_breakdown()` exposes the existing curve. Additive `damage_on_hit` quotes use the same resolver and controller mitigation; raw `damage`/`resolution` remain deterministic compatibility payloads. HUD presents conditional damage and risk, masks hidden draw rows, and excludes upcoming hit-roll labels. AP/CT costs and existing damage/accuracy balance are unchanged.

**Verification:** Focused resolution/controller tests: front/side/back, height, clamp boundaries, miss-effect gating, repeated previews.

**Dependencies:** 1. **Likely files:** `globals/combat/resolution.gd`, `globals/combat/combat_controller.gd`, proposed `globals/combat/accuracy_breakdown.gd`, affected resolution test, `test/integration/test_combat_controller.gd`. **Size:** M.

### 3. Submit one aimed attack in the combat lab — 60–120 minutes

**Scope:** Add optional location intent and a minimal fixture anatomy profile; exercise torso/arm/throat queries without building the full injury catalog.

**Acceptance:**
- [x] A lab action can select torso, arm, or throat with a visible location penalty and explicitly authored AP/CT surcharge.
- [x] Missing or blocked locations and insufficient resources reject before spending; a committed miss pays its legitimate cost.
- [x] Old actions default to ordinary aim and serialize/replay without requiring new fields.

**Verification:** Action round trips and submit tests under both scheduler implementations; fixture target without a throat.

**Dependencies:** 2. **Likely files:** `globals/combat_action.gd`, `globals/combat/combat_controller.gd`, proposed `globals/combat/anatomy_profile.gd`, `globals/combat_lab.gd`, focused aimed-action test. **Size:** M.

### Checkpoint A

- [x] Ordinary-attack parity and aim legality/cost tests pass.
- [x] A lab action reaches the actual controller submit path with its chosen location.
- [ ] No hidden knowledge or extra random rolls are revealed by previewing.

## Phase 2 — expose the tactical choice

### 4. Select an aim in the real HUD — 60–120 minutes

**Scope:** Render the controller's available locations and forecast through existing HUD regions.

**Acceptance:**
- [x] Player can select, inspect, cancel, and submit a location with mouse and existing keyboard/controller navigation.
- [x] The panel shows hit chance, active-scheduler cost, possible consequence, and disabled reason from controller data.
- [x] Changing target/action clears stale aim state; localized labels and DS styling follow existing conventions.

**Verification:** Rendered input integration under Xvfb/display, inspected screenshot, cancellation and target-switch checks.

**Dependencies:** 3. **Likely files:** `ui/hud/battle_hud.gd`, `ui/hud/battle_interface.gd`, existing forecast region, proposed aim-selection region, corresponding UI integration test. **Size:** M. Split scene assembly if it exceeds this boundary.

### 5. Distinguish a blocked shot from partial exposure — 60–120 minutes

**Scope:** Extend the battlefield query with line-of-fire and location-exposure results, consumed by aiming.

**Acceptance:**
- [x] Solid obstacle, elevation occlusion, and existing intervening-actor blockers are explicit fixtures; blocked shots cannot use the minimum chance.
- [x] A low-cover fixture exposes the appropriate regions while hiding others; facing/elevation changes produce consistent results.
- [x] Migrate the fixture's cover profile without accidentally applying the same generic cover as both hit penalty and damage reduction.

**Verification:** Grid tests plus query/submit cases; inspect the low-cover fixture in the running lab.

**Dependencies:** 3. **Likely files:** `globals/combat/grid_battlefield_model.gd`, `globals/combat/combat_controller.gd`, fixture profile, `test/unit/test_grid_battlefield_model.gd`, aimed-action integration test. **Size:** M.

### 6. Make one environmental condition affect the shot — 60–120 minutes

**Scope:** Introduce authored physical visibility input, initially clear/dim/obscured, and refresh forecasts when it changes.

**Acceptance:**
- [x] An applicable ranged shot changes chance with physical visibility; unsupported action types remain unaffected.
- [x] Overlapping visibility causes have explicit composition, and existing Blinded behavior is reconciled without duplicate penalties.
- [x] Elemental Weather, Witness Light, and Shroud remain separate unless an approved adapter explicitly connects them.

**Verification:** Controlled environment fixtures, modifier arithmetic, observer masking, and live forecast refresh.

**Dependencies:** 2, 5. **Likely files:** proposed physical visibility adapter, battlefield query, resolver, combat-lab fixture, focused visibility tests. **Size:** M.

### Checkpoint B

- [x] Real HUD shows and submits torso/arm/throat aim with clear explanations.
- [x] Clear, dim, partially covered, and fully blocked cases agree between forecast and execution.
- [x] Existing reaction, fizzle, and cost checks affected by these changes remain green.

## Phase 3 — resolve and recover

### 7. Apply a bounded location injury — 60–120 minutes

**Scope:** Add minimal injury records and conditional outcome resolution for an isolated fixture, initially using combat-local state. This is an intermediate test slice; serious injuries cannot ship with combat-only storage.

**Acceptance:**
- [x] Injury eligibility is evaluated after hit/mitigation; misses and ineligible zero-damage hits produce no injury.
- [x] Arm injury affects eligible attacks without changing base Alacrity; duplicate application obeys the accepted bound/refresh rule.
- [x] Preview probabilities distinguish on-hit and overall injury chance; replay remains deterministic and applies the result once.

**Verification:** Submit-path injury application and consumption, severity/stacking boundaries, deterministic replay, and preview purity.

**Dependencies:** 1, 3. **Likely files:** proposed injury-state helper, `globals/battle_actor.gd`, resolver, controller, focused injury integration test. **Size:** M.

### 8. Make throat injury affect vocal actions — 60–120 minutes

**Scope:** Wire explicit vocal eligibility through action queries and the existing working/hold lifecycle.

**Acceptance:**
- [x] A voice-tagged action receives the accepted injury restriction/penalty; an otherwise equivalent nonvocal action does not.
- [x] Pending/held/sustained actions use an explicit interruption rule, preserving costs and once-only settlement without deleting unrelated effects.
- [x] Muted retains its Tempo meaning, and an injured actor has a viable permitted action.

**Verification:** Live throat attack followed by vocal/nonvocal submissions; targeted reaction/hold/Anchor regressions affected by the integration.

**Dependencies:** 7 and accepted vocal-action tags. **Likely files:** action metadata/catalog, controller, affected working lifecycle module, vocal fixture, throat integration test. **Size:** M.

### 9. Persist serious injuries — 60–120 minutes per state-owner slice

**Scope:** Preserve serious injuries until explicit treatment, using the existing durable party and hostile state owners. Keep temporary elemental statuses on their existing lifecycle.

**Acceptance:**
- [x] Serious injuries survive combat exit, retreat, travel, and save/load; death/revival follows an explicit contract without accidental clearing during actor reconstruction.
- [x] Old saves load safely; stable IDs survive data renames and unknown records follow a documented compatibility policy.
- [x] Hostile injury lifetime follows the existing authoritative actor lifecycle without new global persistence or corpse-policy changes.

**Verification:** Isolated old/new save round trips, actual battle exit/reentry, and same-map hostile continuity. If party and hostile paths require distinct stores, split this task before implementation.

**Dependencies:** 7 and the recovery/lifecycle contract from 1; persistence is already confirmed. **Likely files:** `globals/party_member.gd`, `globals/battle.gd`, existing hostile state owner, `globals/save_migrations.gd`, injury lifecycle integration test. **Size:** M per state-owner slice; split if larger.

### Checkpoint C

- [ ] Arm and throat outcomes are applied by real attacks and consumed by later actions.
- [ ] Reactions and elemental statuses retain their accepted semantics.
- [ ] Injury lifetime is proven; persistent disabling injuries remain unavailable in production content until treatment is ready.

## Phase 4 — finish the playable system

### 10A. Cure one injury through an atomic treatment operation — 60–120 minutes

**Scope:** Required. Add the shared query/commit helper using durable injuries and existing inventory/GP methods. Prove the operation through a lab fixture before attaching production interactions.

**Acceptance:**
- [x] Quote identifies one injury instance/revision and exact cost; stale injury, changed price, invalid access, and combat-active state reject without payment.
- [x] Valid treatment pays and cures exactly once; injected application failure rolls back payment, and duplicate intent cannot pay again or cure a later injury at the same location.
- [x] Completed state round-trips coherently through saves; ordinary HP healing leaves serious injuries intact and treatment grants no Soul.

**Verification:** Focused integration tests with 20 GP and one-supply test fixtures, insufficient resources, last-item stack, stale quote, duplicate submission, re-injury, and injected rollback. Use a real injury from the attack submit path for the lifecycle check.

**Dependencies:** 9 and accepted shared recovery contract from 1. **Likely files:** proposed `globals/injury_treatment.gd`, `globals/game_state.gd`, injury lifecycle helper, combat-lab fixture, proposed treatment integration suite. **Size:** M.

### 10B. Make a healer treatment accessible in the encounter — 60–120 minutes

**Scope:** Required. Connect one authored provider interaction to the shared operation and its displayed quote. Author the recovery access needed by the first disabling-injury encounter.

**Acceptance:**
- [ ] Player selects an injury, sees an exact GP quote, commits through the interaction, and immediately regains the corresponding permitted actions.
- [ ] Provider supplies are included in the fee; lack of party Mending does not block the route, and invalid/changed quotes cannot charge silently.
- [ ] Encounter has a verified recovery path for no cash, no party Mending, and an injured practitioner; author the access solution without a new global free-healing mechanic.

**Verification:** Rendered provider interaction; attack → injury → retreat → provider → cure → save/reload; inspect the receipt and restrictions. Check reputation/access changes and the authored no-cash route.

**Dependencies:** 8, 10A and accepted provider/access design. **Likely files:** existing interaction adapter, provider/encounter source data, injury detail UI, treatment integration suite. **Size:** M. Provider identity/location must be selected from authorized content before writing narrative.

### Recovery checkpoint

- [ ] A party without Mending can complete the persistent injury/recovery loop.
- [ ] Transaction, save, and rendered interaction checks pass; neither failure nor duplicate submission loses resources.
- [ ] A guaranteed treatment consumes no SkillCheck RNG or Expert reroll.

### 10C. Offer qualified field treatment — 60–120 minutes

**Scope:** Required by the confirmed field-cure decision. Expose the shared operation in the party injury UI using authored Mending/limb prerequisites and a matching supply. Temporary combat relief remains a separate later combat-item extension.

**Acceptance:**
- [ ] A qualified, conscious practitioner can cure one supported injury outside combat using the displayed supply quantity; ineligible self-treatment gives a precise reason.
- [ ] Field treatment uses the same quote/commit/notification rules as provider treatment and rejects if combat begins before commitment.
- [ ] Cure removes only the selected injury; HP, other injuries, elemental effects, Soul, and ultimate flags follow their independent contracts.

**Verification:** Rendered party treatment, practitioner switch, injured hands versus nonvocal care, last supply unit, cancel/reopen, and combat-start race.

**Dependencies:** 10A, accepted qualification/success rules and production supply card; field-cure capability is already confirmed. **Likely files:** party injury UI, treatment helper, Pandora treatment supply source, catalog adapter, treatment integration suite. **Size:** M.

### 11. Author production anatomy and injury content — 60–120 minutes per catalog slice

**Scope:** Extend the Pandora export/validation path, promote the minimal profiles, then add legs and head/eyes as individually verified content slices.

**Acceptance:**
- [ ] Humanoid and non-humanoid profiles validate stable IDs, absent parts, delivery requirements, costs, and outcome references.
- [ ] Production catalogs regenerate reproducibly; no generated artifact is hand-edited.
- [ ] Each newly enabled region has a useful bounded effect, accurate forecast, and serious-injury persistence/recovery consistent with the confirmed rule.

**Verification:** Generator validation, catalog loading, missing-reference rejection, and one submit-path fixture per newly enabled region.

**Dependencies:** 5–9; 10A–10C before persistent disabling profiles ship. **Likely files:** existing Pandora schema/export owner, `globals/combat/combat_identity_catalog.gd`, authored catalog source, generated output via exporter, catalog test. **Size:** M per slice. Locate the authoring owner first; do not create a competing source of truth.

### 12. Make AI choose useful called shots — 60–120 minutes

**Scope:** Use the shared query result to compare ordinary attacks and a bounded set of legal aim options.

**Acceptance:**
- [ ] AI can prefer a useful throat/arm shot and still choose ordinary damage when its expected value is better.
- [ ] AI sees only observable anatomy/conditions and known weaknesses; it never reads future rolls.
- [ ] Candidate generation is bounded and respects injury restrictions, costs, and legal target exposure.

**Verification:** Deterministic tactical fixtures for a vocal opponent, already-disabled limb, low hit chance, and hidden target.

**Dependencies:** 8, 11. **Likely files:** existing combat AI policy, controller query adapter if needed, tactical fixture, focused AI tests. **Size:** M.

### Checkpoint D — integration and readiness

- [ ] Run affected unit/integration suites and inspect the rendered combat encounter; fix regressions caused by this work.
- [ ] Compare ordinary-versus-aimed decisions, save compatibility, both schedulers, and replay against the accepted contracts.
- [ ] Measure query/AI cost on a representative ~100-actor map versus baseline; document hardware and observed timings. Obtain a bounded human judgment of tactical usefulness and readability.

## Verification execution

The implementing agent owns automated and rendered checks. Use [agent verification](../docs/agent-verification.md) and [testing](../docs/testing.md), with isolated test data. Existing affected suites include `test/unit/test_combat_action.gd`, `test/unit/test_grid_battlefield_model.gd`, and `test/integration/test_combat_controller.gd`; add focused suites only for behavior they do not cover.

Example runner, substituting the relevant suite for each slice:

```bash
GODOT_BIN="$HOME/.local/bin/godot" LP_NUM_THREADS=1 \
  SOUL_METER_TEST_DATA_DIR="$(mktemp -d /tmp/soul-meter-called-shots.XXXXXX)" \
  bash scripts/test.sh -a test/integration/test_combat_controller.gd
```

Use headless mode only for compatible logic tests. Rendered/input checks require the wrapper's Xvfb/display path. Preserve required CI/release gates; avoid running the full suite after every small slice. Implementation and publication are not authorized by this planning document alone.
