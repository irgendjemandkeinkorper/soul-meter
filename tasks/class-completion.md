# Complete the ten patron-class gameplay loops

User priority, 2026-09-09: finish classes before continuing environmental systems.
Use the existing ten-class roster, resource implementations, combat controller,
action catalog, and forecast/commit path. Class identity stays separate from DRAMGID.

1. [x] Audit each existing class's usable loop and reconcile player descriptions with
   ratified runtime rules; retain explicit boundaries for unimplemented signatures.
2. [x] Refuse empty, already-armed, duplicate or invalid class commands before charging
   AP, CT or Soul. Preserve pure previews and save/restore behavior.
3. [x] Complete supported class-action routing and authoring for missing commands,
   with explicit target requirements, deterministic effects and resource limits.
4. [x] Verify all ten classes through gameplay-facing paths; run relevant regression
   suites and publish a compact class-by-class implementation matrix.

Sources: `docs/game-identity.md`, `docs/class-resources.md`, `ClassCatalog`, current
resource implementations, and the vault's `systems/ten-patron-classes.md`.
The 2026-09-08 Soul-income ruling supersedes older Soul-refund class prose.
Balance proposals in `docs/class-resources-numbers.md` remain unapplied proposals.
Do not invent a critical-hit system or a new CombatAction.Kind while closing the
existing class-resource paths. No UI redesign or campaign content reassignment.

## Evidence and handoff

Implementation matrix: `docs/class-completion.md`. Shared command/lifecycle contract:
`docs/class-resources.md`. New authored actions: File Sentence, Jam the Gears, Bind Hostility.

Focused verification: **172/172 passed**, `reports/report_1405/results.xml`. Coverage includes
the ten classes, real cast forecast/commit parity, AP/CT refusal safety, save round-trip,
public Battle routing, contract preservation and target death, Hunger cancellation/reapplication,
earned Breath settlement, and the forecast-panel scene.

First full regression (`report_1402`): the same nine failed assertions in three existing suites
as the pre-class run (`report_1386`) and isolated baseline worktree.
Final regression (`reports/report_1406/results.xml`): **1,957 executed cases**, the same nine
assertions in the same three baseline tests, zero XML error entries. The full run is not green;
it also emits engine diagnostics from the larger suite. No additional test failures were found.
Known baseline suites: townsfolk placement/dialogue, interior population/dialogue, field sprint.

Review: shared command targets/payloads use the existing action and deferred-effect seams;
no new action kind, Resolution formula, generated-data edits, or UI layout changes.
`git diff --check` passes. Tests preserve the global Soul/husking flags they exercise.

Balance risk: the three new command costs/effects are provisional. Broader named signatures,
critical hits, progression and class art remain separate work; the player-facing catalog marks
unimplemented signatures as Planned. No B11 balance proposals were applied and no class grants Soul.

Next bounded action: review the signature-boundary column in `docs/class-completion.md` to
choose the next class behavior requiring authored acceptance criteria.
