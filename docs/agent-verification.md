# Agent-owned verification

Agents run routine tests and runtime checks themselves. Human playtesting is for feel, judgment, and explicitly human acceptance gates; it is not the default handoff after a code change.

## Choose evidence for the changed behavior

| Change | Agent-owned evidence |
|---|---|
| Documentation or instructions | Check links, paths, consistency, and affected configuration; no gameplay sweep unless behavior changed. |
| Isolated gameplay logic | A relevant regression test and the affected observable behavior; cover meaningful edge cases. |
| Scene, UI, input, or rendering | Load the scene, run the relevant integration/visual suite under Xvfb or an available display, and inspect the rendered result when relevant. Headless-only output does not establish visual or pointer-input correctness. |
| Save/load, shared state, or combat effects | Relevant round trips and compatibility cases, representative consumers, and the live action path. New combat state needs a submit-action-path check that proves an effect is consumed. |
| Release or broad shared-system change | The affected checks plus required project/CI/release gates. Retain external-test and real-hardware gates explicitly required by the project. |

Use an existing check when it answers the question. Add targeted coverage for uncovered behavior that needs a repeatable regression check. Do not add tests that only restate implementation or create a new testing framework for a small edit. Batch related edits before rerunning their checks; repeat a passing check only after relevant changes or new uncertainty.

## Run from the repository root

Use `scripts/test.sh`, not the vendor convenience wrapper. The project wrapper avoids its Godot TCP-port incompatibility, isolates `XDG_DATA_HOME`, seeds a usable window resolution, and defaults to Xvfb for input/rendered checks. Pass `GODOT_BIN` for the installed engine. Give each independent test run its own `SOUL_METER_TEST_DATA_DIR`; the default shared temporary path is unsuitable for simultaneous runs.

Focused example using an existing suite:

```bash
GODOT_BIN="$HOME/.local/bin/godot" LP_NUM_THREADS=1 \
  SOUL_METER_TEST_DATA_DIR="$(mktemp -d /tmp/soul-meter-test.XXXXXX)" \
  bash scripts/test.sh -a test/unit/test_reputation.gd
```

Use the same command with the affected suite path. Add `SOUL_METER_HEADLESS=1` only for checks compatible with headless execution. Input-dependent and rendered suites need Xvfb/display. Some executable visual checks live under `test/manual`; their directory name alone does not make them human-only. Whole-tree runs exclude those unless explicitly selected.

When a full run is required:

```bash
GODOT_BIN="$HOME/.local/bin/godot" LP_NUM_THREADS=1 \
  SOUL_METER_TEST_DATA_DIR="$(mktemp -d /tmp/soul-meter-test.XXXXXX)" \
  timeout 5400 bash scripts/test.sh -a test
```

The recorded full-suite runtime was over 50 minutes; do not rerun it after every small edit. CI's required checks remain in `.github/workflows/test.yml`; the local release gate is `scripts/acceptance_gate.sh`. Use `docs/testing.md` for generated-data and dialogue-specific checks. Agent execution must still respect actual sandbox/network restrictions.

## Isolate and diagnose

Use disposable test data, never real player saves. The wrapper isolates the Godot user-data directory; this does not prove that every future test lacks network access or external effects. Check unfamiliar test setup before granting that assumption. Save-rotation tests have explicit fixture-path rules in `testing.md`.

Re-import after new `class_name` scripts or dialogue-resource changes, following `DEPENDENCIES.md`. A missing import can look like a cluster of unrelated failures. gdUnit4 can stop a suite after a failure: rerun that affected suite after fixing the cause. Handle Variant inference with the repository's explicit typing conventions.

A crash or nonzero exit is a failure to investigate. If assertions completed before an engine teardown crash, report both facts; do not silently turn a crash into a pass. Distinguish historical environment issues from evidence collected in this run.

## Finish with evidence, not a testing assignment

Report the command/suite, observed outcome, relevant screenshot or log artifact when useful, and any unverified behavior. Inspect screenshots or runtime output yourself before declaring a visual check complete. If a check cannot run, name the missing capability and complete independent checks.

Ask the user only for a bounded judgment or a check that actually requires their hardware/access. Supply a ready build/scene, short steps, and the exact question. Game feel, readability preferences, outside testers in the playtest protocol, and the real-hardware performance runbook remain legitimate human work. Do not claim automation proves the game is enjoyable.
