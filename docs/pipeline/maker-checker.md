# The Maker/Checker adversarial validation loop

**Status:** the working procedure for delegated changes in this repo. Closes #40.
**Related:** [octo-escalation.md](octo-escalation.md) (#41), [skill-extraction-criteria.md](skill-extraction-criteria.md) (#45).

Everything described here exists today and was verified against `CLAUDE.md`, `docs/testing.md`,
and `.github/workflows/` on 2026-08-06 at `main` @ `36ba4ad`. Where something is *not* yet
automated, this document says so rather than implying a gate that would not actually stop a bad
change. That distinction is the point of the doc.

## Why the loop exists

The recurring failure in this repo is not bad code — it is **unverified claims about code**.
A worker reports "all tests passed"; the suite was never run, or was run on one suite in
isolation, or was run on a branch whose base was already red. The loop below is built so that no
claim of correctness is load-bearing: the objective gate is a command anyone can re-run, and the
adversarial pass reads the diff rather than the report.

Two concrete precedents, both recorded:

- Across three Codex runs (2026-08-04), Codex exhausted its budget mid-implementation and
  self-verified in **zero** of three cases — delivering a tool with a syntax error, a change with
  2 failing tests, and an audit whose headline metric was silently meaningless.
- PR #130 (2026-08-06) reported "All tests passed" in its own description while its CI was red,
  and separately shipped a save-breaking regression that no single-suite run could have caught.

## The three roles

**Maker** — Codex, Jules, or a fresh Claude session. Implements against a bounded brief.
Explicitly does **not** make design decisions (per the global role policy); if the brief requires
one, the Maker stops and escalates rather than choosing.

**Objective gate** — the test suite. Not a person, not a judgement. Passes or fails.

**Checker** — a *second, independent* Claude pass that did not write the change. Reads the diff
against the repo's stated rules. Independence is the whole mechanism: an author checking their
own diff reproduces the reasoning that produced the bug.

## The loop

### 1. Brief the Maker

A bounded brief carries: objective, repo/branch, allowed scope, deliverables, acceptance checks,
and an explicit **"do not decide"** boundary. The issue bodies in this repo are already written
this way — problem statement, acceptance criteria, and a "do not" clause — so for a filed issue
the brief *is* the issue.

Delegation is non-recursive by default: a Maker does not spawn further Makers.

### 2. Run the objective gate

Locally:

```bash
GODOT_BIN=~/.local/bin/godot bash addons/gdUnit4/runtest.sh -a test
```

CI runs the same suite through `scripts/test.sh` (which adds `--headless` or wraps in `xvfb-run`).
`.github/workflows/test.yml` runs, in order: engine cache → import (failing on any
`Parse|Compile Error`) → `scripts/acceptance_gate.sh` → `scripts/check_generated_data.sh`
(Pandora drift) → the gdUnit4 suite → a Windows export. A separate `Conflict Detection`
workflow scans PRs for overlapping file changes.

Three rules about the gate, each learned the hard way:

- **Run the FULL suite, not the touched suite.** `Reputation`, `Renown`, and `GameState` are
  autoloads that accumulate state across a run. A suite passing alone can fail in a full run —
  and did, for PR #130, where an empty ledger made the validation bug invisible in isolation.
- **Re-run against current `main` before believing a red result.** A stale base can be red for
  reasons that have nothing to do with the change. Merge `main` in, re-run, then judge.
- **Never gate on a tool script's raw exit code.** Per `CLAUDE.md`, `godot --headless --script`
  aborts with exit 134 at teardown 20–30% of the time here, even for a trivial script. Judge the
  output, not the code.

Also: after adding any script with a `class_name`, re-run `--import` or the new global type will
not be registered and every referencing script will fail to parse in a way that looks like broken
code and is not.

### 3. Checker pass — read the diff, not the report

The Checker reads the actual diff against `CLAUDE.md`'s **Do NOT** list. Concretely:

- [ ] No `change_scene_to_file()` in game code — scene moves send a `GameFlow` event.
- [ ] Reputation/Renown writes go only through `record()` / `gain_reputation()` / `gain_infamy()`;
      the ledgers stay append-only.
- [ ] Nothing under `addons/` edited (except our own `addons/soul_meter_tools`).
- [ ] No hand-edits to `data/generated/*` — regenerate instead.
- [ ] Theme changes are type variations, not per-node overrides.
- [ ] No open canon question resolved and no `[CANON]` overridden without a human ruling.
- [ ] No reformatting or renaming outside the task's scope.
- [ ] Claims in the PR description match what the diff and the suite output actually show.

That last one is not a formality. It is the check that would have caught #130.

### 4. Merge

Open the PR only after 2 and 3 both pass. On the far side: the vault log and session note, and
durable standards to MuninnDB.

## What is automated and what is not

| Step | Enforced by | Automated? |
|---|---|---|
| Parse/compile errors | `test.yml` import step | **Yes** |
| Test suite | `test.yml` gdUnit4 step | **Yes** |
| Generated-data drift | `check_generated_data.sh` | **Yes** |
| Acceptance artifacts | `acceptance_gate.sh` | **Yes** |
| Windows export builds | `test.yml` package job | **Yes** |
| Overlapping PR changes | `Conflict Detection` | **Yes** |
| Quest flag/outcome integrity | `tools/quest_audit.gd` | **Partly** — reporting-only unless `SOUL_METER_QUEST_AUDIT_STRICT=1`; read its header limitations before trusting a green result |
| **The Checker pass itself** | a human or a second Claude session | **No — entirely manual** |
| **Base-commit-is-green check** | judgement | **No** |
| **Full-suite-not-single-suite** | judgement | **No** |

The bottom three rows are where every incident so far has actually occurred. Nothing in CI
enforces them, and this table exists so nobody mistakes a green check mark for having done them.

## Known limitation

The Checker is currently the same Claude session that orchestrates the Maker, which weakens the
independence the loop depends on. Genuine independence requires a fresh session with no memory of
writing the change. When a change is high-stakes enough that this matters, escalate per
[octo-escalation.md](octo-escalation.md) rather than pretending the self-check is adversarial.
