# Called shots: atomic injury treatment (task 10A) — 2026-09-19

Task 10A in [the combat expansion checklist](../../tasks/called-shots-and-injuries.md): one shared query/commit helper cures one serious injury exactly once, using the durable owners already in place.

## Contract as built

- `globals/injury_treatment.gd` (`InjuryTreatment`, Systems layer, no autoload). `quote()` reads only; `commit()` re-quotes, refuses a changed price with the fresh cost, debits once through `spend_gp` / `remove_items`, cures once, and restores the debit when application fails. `party_changed` fires only after a coherent completed state. No RNG, no `SkillCheck.resolve()`, no Soul change, HP untouched.
- Identity: `CombatInjury.apply` now stamps `instance_id` (`injury@location|provenance`); `applications` is the revision. A replacement wound at the same location is a different instance; a refresh moves the revision. Both reject an old quote (`injury_missing`, `injury_changed`). Identity round-trips through `PartyMember` serialization.
- Refusals before payment: `combat_active`, `unknown_card`, `unknown_patient`, `patient_down`, `injury_missing`, `injury_changed`, `not_treatable` (minor), `unsupported_injury`, `invalid_access` (wrong provider), `insufficient_gp`, `unknown_practitioner`, `practitioner_down`, `unqualified`, `practitioner_injured`, `insufficient_supply`, `price_changed`, `apply_failed`.
- Cards are test fixtures, not balance: `service-test` (provider `test-healer`, 20 GP) and `field-test` (Trained Mending, one `materials/loamroot_sprig`, practitioner needs an unhurt arm; a throat injury does not block it). Self-treatment is allowed when the card's requirements are met.
- Lab fixture: dev console `treat <member_id> <location> [card] [practitioner_id]` drives the real quote/commit path.

## Evidence

- `test/integration/test_injury_treatment.gd` (7 tests, isolated `GameState` instance): exact pure quote then pay-and-cure once with one notification; duplicate intent refused without payment; stale quote against a replacement or worsened wound; every refusal leaves GP and the wound untouched; field card consumes the last supply unit and checks tier/limb/self rules; injected apply failure rolls back GP and supply; completed state round-trips and HP care leaves the injury; a real aimed hit through `submit_action` yields a treatable instance.
- `test/unit/test_dev_console_commands.gd` (+1): `treat` refuses with no wound and with 5 GP, cures with 20 GP.
- Regression suites green: injuries, called shots, battle, combat session, save game, inventory, combat controller, combat lab, party member, dev console. 204 tests, 0 failures, across two runs.

## Not covered / open

- No production provider, party-screen, or field interaction yet (10B, 10C). Production prices and the supply item are Pandora content (task 11); Bitterleaf is not assumed to be the supply.
- Hostile injuries have no treatment route; none is required by the contract.
