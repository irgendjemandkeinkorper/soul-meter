# Quest system sprint (2026-11-26)

An overnight run on the quest system, asked for in session ("focus on the quest system"). The
backend was already in good shape when it opened: the audit (`tools/quest_audit.gd`) reported 0
errors and 10 warnings, with main and side read-back both at 100 %. Content is gated elsewhere:
the six stub dispositions (R11) and the eight Kesselford/Ashlaren proposals wait on the owner in
PR #646. So this sprint works on what the player sees and on the audit, and authors no quest
content, prose, or canon.

## What was wrong when the sprint opened

1. **The journal never says how a quest ended.** A completed quest prints its *last step*. A
   resolved Living Tag reads "Return to Droma Flintjaw and decide the armor's fate." in the
   "Quests entered" column, long after the armor's fate was decided.
2. **Accepting a quest or finishing one of its steps says nothing in the field.** Completion
   gets the reward reveal; acceptance and progress only change a line in the journal.
3. **The player cannot choose what the HUD follows.** The objective line always shows the
   chapter thread. `QuestRegistry.tracked_quest()` exists but nothing calls it, and
   `FlagQuest.destination_scene` was left "for future HUD/compass work".
4. **Audit noise.** Eight flag-grammar warnings and one written-never-read flag.

## Steps

| Step | Outcome | Owner input needed |
|---|---|---|
| Q1 | The journal shows the outcome of every completed quest that records one: the choice as its line, the read-back in its tooltip. Active quests list main thread first, then commissions, then companions. | No. Every string shown is already authored and approved. |
| Q2 | Field notices for a quest taken up and for each new step, never on load, and never for a step that completes the quest in the same moment. | Copy review only (see below). |
| Q3 | Track a quest: a toggle on each active journal entry; the HUD line follows the tracked quest, with GO TO only when its place is in another area. Nothing tracked keeps today's chapter thread. Saved; older saves load with nothing tracked. | Keep or drop the feature (see below). |
| Q4 | Audit cleanup: fix false positives, register the hub domains, and resolve the orphaned flag without inventing content. | No, unless the orphan turns out to need a read-back. |

Each step is its own commit, with its own tests.

## Constraints kept

- U3 (2026-11-02): a journal entry is its title, one line and one who/where line. Q1 swaps the
  stale step for the outcome; it adds no lines. The read-back goes into the tooltip.
- U2: the objective is one line; GO TO appears only when the target is in another area.
- Field notices outside a conversation stay non-numeric (2026-11-01).
- Saves: the tracked quest is an optional key in the existing `quests` section. No schema bump;
  a missing or unknown id loads as nothing tracked.
- DS: theme type variations only; no per-node overrides.

## Q1 as built

Captures: `docs/qa/quest-sprint-2026-11-26/q1-journal-*.jpg` (`test/manual/quest_journal_capture.gd`).

- `QuestRegistry.resolution_record(quest)` answers "how did this end" from the resolver's own
  write: a side quest's outcome label (tooltip: its read-back), the Broken Muster ruling line
  (now held once in `BROKEN_MUSTER_RULING_LINES`, which the chapter recap also reads), the Roar
  ruling's ledger cause, and the field-debt reward title (tooltip: its consequence). The bell
  quest, the Loamroot fetch and the companion bonds record no choice, so they get no line.
- A suspended stub's state reads **TO BE CONTINUED**, not COMPLETED, and has no line.
- **Bug found and fixed: stubs were lost on load.** Save restore looked quests up through
  `all_quests()`, which leaves the six stubs out on purpose (no quest XP, no force-complete). A
  stub the player had taken up was dropped with a "missing quest id" warning and its giver offered
  it again; `reset()` also left a stub's progress from the previous run. `known_quests()` (the
  completable quests plus the stubs) now backs save restore, `reset()` and the journal, which
  had never listed a stub. `ALL_QUESTS` and `all_quests()` are unchanged, so the XP sweep, the
  e2e "every quest reachable" check and the debug menu are unaffected.
- Order: main thread, commissions (stubs among them), companions; by name within each.

## New UI copy (for owner review)

| Where | Text | Note |
|---|---|---|
| Journal state, suspended stub | TO BE CONTINUED | The phrase the stub's own reward reveal already uses. |
