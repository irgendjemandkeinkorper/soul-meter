# Gate T current evidence

**Audited:** 2026-08-28  
**Source of record:** `docs/prd-amendment-tactical-layer.md` §5  
**Overall result:** **NOT PASSED**

This ledger separates reproducible machine evidence from the two results that cannot
be manufactured by an agent: outside-player comprehension and reference-hardware
performance. Green gdUnit results do not override either requirement.

## Criterion ledger

| # | Criterion | Current status | Reproducible evidence |
|---|---|---|---|
| 1 | Five encounter archetypes × four build archetypes | Automated PASS | `test/integration/test_gate_t1_clearability.gd`; all four fixtures clear demon, undead, mixed-whipsaw, speech-winnable, and stabilizer-showcase encounters |
| 2 | Falsifiable positional depth | Automated PASS | `test/integration/test_gate_t2_positional_depth.gd`; final four-run record in `docs/gate-t2-evidence.md` |
| 3 | Defining Strike CT price, Balance/weather board bias, mid-queue speech | Automated PASS | `test/integration/test_wavec_tactical_gates.gd::test_gate_t3_defining_strike_weather_bias_and_mid_queue_speech_victory` |
| 4 | CT queue integrity with ≥8 combatants across ≥3 battles | Automated PASS | `test/integration/test_wavec_tactical_gates.gd::test_gate_t4_queue_integrity_across_three_large_battles` |
| 5 | Deterministic speech interrupt, no orphaned action/status, save/load identity | Automated PASS | Wave-C mid-queue event-order test plus `test/unit/test_combat_speech.gd::test_gate_t5_mid_queue_speech_result_survives_the_save_envelope`; the latter proves no committed action remains and restores the speech outcome, GameState, Reputation, and Renown through the production save envelope |
| 6 | Four-question comprehension | **NOT RUN — outside players required** | Run `docs/playtest-protocol.md` with `docs/playtest-packet.md`; 3–5 eligible outside testers, majority correct per question |
| 7 | Fixed-seed determinism and forecast/resolution parity | Automated PASS | Wave-C byte determinism and equal-cost-path tests plus `test/combat_resolution/test_resolution.gd` |
| 8 | Grid position, facing, elevation, CT, tile charge, weather survive round trip | Automated PASS | `test/integration/test_wavec_tactical_gates.gd::test_gate_t7_resolution_and_tactical_round_trip_are_byte_deterministic` (legacy test name; asserts the criterion-8 state set) |
| 9 | FR-904 rendered performance floor | **PROVISIONAL — reference run required** | Harness is healthy, but only three declared reference-hardware rendered runs can pass. See `docs/fr-904-runbook.md` and `docs/issue-evidence-175-gate-t9.md` |
| 10 | AP→CT migration completeness | Automated PASS | Wave-C compatibility characterization; remaining `action_points|ap_cost` paths are under the Gate T-10 compatibility shim and removal ticket #176 |

The focused Gate T integration command currently reports 10 tests and 0 failures:

```bash
GODOT_BIN=~/.local/bin/godot bash scripts/test.sh \
  -a test/integration/test_gate_t1_clearability.gd \
  -a test/integration/test_gate_t2_positional_depth.gd \
  -a test/integration/test_wavec_tactical_gates.gd
```

Gate T5's production save-envelope proof is separate:

```bash
GODOT_BIN=~/.local/bin/godot bash scripts/test.sh -a test/unit/test_combat_speech.gd
```

## Criterion 9 current machine evidence

The current Xvfb/WSL2 rendered populated-grid run completed with:

- `status: "ok"`, no harness errors;
- 600 post-settle samples after a 2,000 ms discard;
- battle HUD interactive in 355.566 ms;
- grid 8×4, 32 charged tiles, 3 allies, 2 enemies;
- draw-call p95 303;
- `TIME_PROCESS` p50 3.908 ms and p95 4.548 ms.

The report correctly declares `acceptance_evidence: false` and
`evidence_class: "provisional"`. Do not turn this into a pass or failure. The
reference-hardware runbook requires three valid rendered runs and uses the median of
their run-level p95 values against 16.67 ms.

Raw provisional report:
`reports/fr904-provisional/2026-08-28-codex-xvfb/run-1.json`.

The default field benchmark had drifted behind the mandatory deployment statechart.
`tools/performance_benchmark.gd` now traverses the ratified deployment events before
waiting for the battle HUD. Its runtime report is again `status: "ok"` with 600
samples and a 60.498 ms battle-event-to-interactive span in the current headless run.

## Stop condition

Region-content production remains paused. Criterion 6 and criterion 9 are not
satisfied by the current evidence. Run the outside-player packet and the declared
reference-hardware benchmark; preserve their raw evidence. Only after both pass may
Claude ratify Gate T and release M6/M7 content production.
