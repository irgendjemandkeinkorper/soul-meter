# A1 handoff — issue #215 tactical casting

## Status

GREEN. CAST is a player command resolved and forecast through the same deterministic `Resolution` result. It pays Breath before Soul overreach, refuses atomically on insufficient Soul, fizzles deterministically, commits HP/resource/tile writes once, and exposes cost/fizzle/refusal information in battle UI.

## Changed files

- Command/data model: `globals/jobs/ability_definition.gd`, `globals/combat_action.gd`, `globals/battle_actor.gd`, `data/combat/actions/90_cast_seam.tres`.
- Resolution/runtime: `globals/combat/resolution.gd`, `globals/combat/combat_controller.gd`, `globals/battle.gd`.
- Element/UI: `globals/elements/element_wheel.gd`, `ui/screens/battle.gd`, `ui/hud/battle_interface.gd`.
- Contracts: `test/unit/test_ability_definition.gd`, `test/unit/test_element_wheel.gd`, `test/unit/test_combat_identity.gd`, `test/combat_resolution/test_resolution.gd`, `test/integration/test_combat_controller.gd`, `test/integration/test_battle_interface.gd`, `test/integration/test_gate_t1_clearability.gd`, `test/integration/test_field_room.gd`.

## Test evidence

- Final gdUnit4 run under Xvfb: **187/187 suites, 1,221/1,221 cases; 0 errors, 0 failures, 0 flaky, 0 skipped, 0 orphans** (`reports/report_26/results.xml`). Xvfb was required because the requested editor-mode runner cannot initialize a display directly in this headless worktree.
- Four salvaged contracts plus Element Wheel: **5/5 suites, 60/60 cases**, all green; includes the 64× identical-context determinism contract.
- Combat lab: **2/2 suites, 16/16 cases**, all green. Gate T-2 subprocess: **1/1** green.
- `combat_number_sweep.gd`: status 0 and emitted both the sweep start and `END SWEEP` markers. No quest/dialogue was touched, and no new `class_name` script was added, so quest audit and re-import were not applicable.

## Risks

- The generated tactical ability table currently supplies no action-slot ability rows. The CAST command and injection seam are live and tested, but an authored player spell must arrive through the existing generator before CAST is usable in shipped combat; this branch does not hand-edit `data/generated/*`.
- The owner-ratified fizzle residue element is Wheel-opposite. Its charge amount remains the explicitly **PROVISIONAL** landed-cast value (`+1`). Mundane attacks retain their prior non-mutating tile behavior; CAST commits the new residue writes.

## Open questions

- A4/owner still owns Breath pool sizing, Aqua/Molm restoration values, and the authored player ability rows.
- Owner follow-up is required only if fizzle residue should use a charge amount other than the provisional landed-cast amount.
