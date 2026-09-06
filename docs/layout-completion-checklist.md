# F10 layout editor completion checklist

Scope confirmed by the owner on 2026-09-05: complete the full planned Weftlumin suite, including quests, characters, encounters, and new maps, before requesting owner testing. The completed F10 safety pass below is one prerequisite, not the finish line. The architecture's dependencies and frozen-file restrictions remain binding.

1. [x] Recovery: closing/reopening F10 retains unsaved edits and history; successful save clears dirty status; failed replacement retains the previous file. Atomic recovery checkpoints recreate unsaved edits on a fresh scene; stale checkpoints cannot overwrite newer manual saves.
2. [x] Reversible editing: undo/redo covers property changes, grouped drags, placement, duplication, and deletion. Redo invalidation, detached-node cleanup, dead live targets, and teardown during a drag have regression coverage.
3. [x] Fidelity: duplicate/save/reload preserves sprite geometry, canvas settings, and supported body/collision settings; unsupported compound props/materials are refused visibly. Transform/footprint/flip/grayscale controls remain covered.
4. [x] Input: buttons expose common actions; real viewport tests prove typing→world click→nudge/undo routing and block gameplay-menu hotkeys. Panel movement/scrolling remains viewport-bounded; errors are visible in the status bar.
5. [x] Safety-pass evidence: 1,372 tests across 194 suites passed; 41 focused tests also passed in the primary checkout. Quest audit: zero errors (existing 19 warnings/7 info). Independent review findings resolved; 800×600 and 640×480 rendered checks pass. One software-renderer native crash occurred during verification; the complete rendered rerun passed with LP_NUM_THREADS=1. User testing is not requested until the full suite is complete.

Implementation order: recovery/history model first, then editor integration; fidelity work can run independently in LayoutOverrides. All persistence remains scratch-only. No canonical scenes or gameplay/combat/character-creation code are changed.

## Remaining full-suite gates

1. [ ] E0/E1 foundations: interface contracts, safe bake and surgical patcher, canon readers/migrations, kind registry, persisted day/seed, spawn/accord contracts. Existing PRs #354, #358, #359, and #362 require review; #312 and #329 have unresolved architecture/scope questions.
2. [ ] E2 unified shell, commands, sandbox ownership, and existing-panel migration. Blocked by the architecture's requirement that #281 and #283 merge; both were verified open on 2026-09-05.
3. [ ] E3 scene tree, multi-selection/free camera, tiles, actors, and new-map creation, using the ratified FieldMap and surgical-bake contracts.
4. [ ] E4–E6 spawn tables/runtime, character and encounter authoring, Harmonic Accord surfaces. Respect the issue-specific #281/#282/#283 dependencies and separately owned numeric design.
5. [ ] E7 shared UI/CLI replay, validation, bake/PR workflow, documentation, complete automated/runtime acceptance, and owner-ready handoff. Human review remains the canonical merge gate. Do not request owner testing of a partial milestone.

The implementation order and allowed files are defined by `docs/handoff-weftlumin-codex.md` and issue #311; this checklist tracks delivery, not a replacement design or permission to cross a freeze.
