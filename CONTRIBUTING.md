# Contributing to Soul Meter

Soul Meter uses short, reviewable changes with explicit ownership. Before
starting work, check the issue's labels and its acceptance criteria. Labels are
routing signals; they do not replace a written brief or review.

## Delegation matrix

| Label | Meaning | Typical work | Owner / handoff |
| --- | --- | --- | --- |
| `jules` | Auto-triggers a Jules task on this issue | Boilerplate, bounded research, test generation or triage, and first-pass visual exploration | Jules produces an advisory handoff; the repository owner reviews it before merge |
| `delegated-to-claude` | Architecture/planning task routed to Claude | Product direction, UX decisions, architecture, scope, and final synthesis | Claude owns the decision and acceptance criteria |
| `delegated-to-codex` | Implementation task routed to Codex (Workhorse) | Core functionality, backend/data, algorithms, integrations, bug fixes, refactors, and reliability | Codex implements the approved brief and reports changed files, tests, risks, and open questions |
| `documentation` | Improvements or additions to documentation | Guides, decisions, runbooks, and repository process docs | The assigned worker updates the source of truth and verifies links/examples |

When an issue has both a work-type label and a delegation label, the
delegation label identifies the first worker and the issue body remains the
authority for scope. Do not change labels, assignees, architecture, or product
behavior as an incidental part of implementation.

## Worked routing example

The pipeline issue batch uses the same split in practice:

- Pipeline policy and architecture questions go to `delegated-to-claude`.
- Core runtime or integration changes go to `delegated-to-codex`.
- Bounded research, fixtures, and test-generation tasks go to `jules`.
- A documentation issue such as this one is completed by updating the checked-in
  document and validating that its label descriptions match GitHub.

## Before opening a pull request

1. Keep the change focused on one issue or one cohesive slice.
2. Add or update regression coverage for behavior changes.
3. Run the narrowest relevant test first, then the repository acceptance gate
   when practical.
4. Summarize changed files, validation, risks, and anything intentionally left
   untouched.

