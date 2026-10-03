# Called shots: throat injury and vocal actions (task 8) — 2026-09-19

Task 8 in [the combat expansion checklist](../../tasks/called-shots-and-injuries.md) wires explicit vocal eligibility through action queries and the existing hold lifecycle.

## Contract as built

- `CombatAction.requires_voice` is authored delivery metadata. Spell or element classification never implies it.
- Minor throat rule: a record with `vocal_accuracy_pp` adds `Injury: Throat (voice)` to voice-tagged actions that roll to hit. The lab's `throat-bruised` authors −10 pp (provisional). A voice-tagged action without a to-hit roll receives no minor penalty; that gap is noted below.
- Severe throat rule: a record with `voice_blocked` makes `query_action` refuse any `requires_voice` action with `voice_required` before anything is spent. Nonvocal actions are unaffected, so an injured actor always keeps its ordinary actions.
- Interruption rule (accepted for this slice): when a voice-blocking injury is applied by a real hit, the controller releases the target's held Note through `release_hold(..., "voice_lost")`. Paid upkeep stays paid, the release settles once, and Aftertones, Soul, anchored fields, and deferred entries are untouched. A minor injury never interrupts. A committed-but-unreleased action keeps its commit; the refusal reaches only the next vocal query.
- Muted is not read or written. Injury records leave Tempo, Alacrity, and `impositions` unchanged.
- Lab: the called-shot fixture now also installs `lab-vocal-call`, a voice-tagged twin of the aimed shot with identical numbers.

## Evidence

- `test/integration/test_injuries.gd` (+3): vocal-only penalty with Tempo/Alacrity/Muted untouched; `voice_required` refusal with no payment and a permitted nonvocal action; live throat hit releases the held Note once with an unrelated Aftertone intact, replay is a no-op, minor injury does not release.
- `test/unit/test_combat_lab.gd` (+1): the lab vocal twin pays the throat term and the aimed shot does not.
- Regression suites green: called shots, combat lab, combat controller, battle interface, combat session, resolution, save game, elemental casts, aftertones/triads, element integrity, AP scheduler, reaction matrix. 240 tests, 0 failures, across two runs.

## Not covered / open

- No production action is voice-tagged yet (task 11 content). The HUD shows the controller's refusal text but was not recaptured for this task.
- Minor throat penalty on vocal actions that do not roll to hit (pure utility workings) has no authored effect; needs a design ruling before content authoring.
- Serious throat injuries have no recovery until task 10 and no persistence until task 9.
