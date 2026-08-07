# Delivery Pipeline

This page is the map for Soul Meter's multi-agent delivery process. It keeps
the durable agreements in one place and links to the detailed documents rather
than repeating them.

## Octopus installation status

The repository's fleet workflows and delegation conventions are checked in,
but provider credentials and external fleet services remain environment-owned.
Confirm the local toolchain and authentication before dispatching work. The
project architecture and routing boundaries are documented in
[`docs/godot-architecture.md`](godot-architecture.md) and the repository-wide
test expectations are in [`docs/testing.md`](testing.md).

## Maker / Checker loop

Every delegated change follows a bounded brief, implementation, adversarial
review, and acceptance verification. The full procedure and evidence behind it
are in [`docs/pipeline/maker-checker.md`](pipeline/maker-checker.md).

The short version is:

1. Define the objective, allowed scope, acceptance checks, and do-not-decide
   boundary.
2. Let one worker implement the bounded slice.
3. Review the diff against the brief and challenge its assumptions.
4. Run focused tests, then the broader gate proportionate to risk.
5. Record changed files, evidence, risks, and open questions before merge.

## Obsidian pact

Obsidian is the human-readable narrative handoff layer. It records reviewed
decisions, project snapshots, and the next recommended action; it does not
replace tests, issue state, or source code. The push-hook and skill-extraction
expectations are documented in
[`docs/pipeline/obsidian-hook-skill-nudge.md`](pipeline/obsidian-hook-skill-nudge.md).

## Related pipeline references

- [`Maker / Checker`](pipeline/maker-checker.md) — implementation and review loop.
- [`Octopus escalation`](pipeline/octo-escalation.md) — when to use consensus or
  a Claude-native decision.
- [`Skill extraction criteria`](pipeline/skill-extraction-criteria.md) — when a
  repeated pattern deserves a reusable skill.
- [`CONTRIBUTING.md`](../CONTRIBUTING.md) — delegation labels and contributor
  workflow.
