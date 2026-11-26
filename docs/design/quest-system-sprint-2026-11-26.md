# Quest system sprint (2026-11-26)

An overnight run on the quest system, asked for in session ("focus on the quest system"); draft PR
#672, owner item 52. The
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

## Q2 as built

- `QuestRegistry.quest_taken_up(quest)` and `quest_step_reached(quest, objective)` publish one
  idle frame after the change. The field's `ConsequenceNotices` show them; a conversation
  pauses the tree, so news from one waits and shows when it closes.
- Nothing is announced on load. `SaveGame.load()` restores flags before quest pools, and
  `GameState.from_dict()` emits `party_changed`, which re-offers companion quests against the
  pools about to be replaced; `from_dict()` drops that queued news and re-baselines every
  restored step.
- A step that finishes the quest in the same moment (a companion bond sets its flag and
  completes at once) is not announced; the reward reveal speaks for it. The turn-in step
  ("Return to Droma Flintjaw…") is announced, since the quest is still waiting on the player.
- Checked against the e2e chapter journey and every suite that reads the notice stack.

## Q3 as built

Captures: `q3-journal-tracking-1920x1080.jpg`, `q3-field-tracked-in-dom.jpg`,
`q3-field-tracked-elsewhere-new-quest.jpg` (the last also shows a Q2 notice).

- `QuestRegistry.pin(quest)` / `unpin()` / `pinned_quest()` and `pinned_quest_changed`. Only an
  active quest can be tracked; completing it lets go. One quest at a time.
- Journal: each active entry has a **Track** toggle on its title row (plain `Button`; Bronze stays
  the one ceremonial control, the Standing button). It reads **Tracking** while on. No extra line.
- Field HUD: with a quest tracked, the one objective line is `QUEST NAME · its step`, plus
  `GO TO <place>` only when the place is in another area (U2). With nothing tracked, the line is
  the chapter thread, unchanged.
- `QuestRegistry.destination_for(quest)`: a side quest's place is its giver's area (from the NPC
  placement; Droma in Dom's town hall gives "Dom"), never the building, because a step can send
  the player to another participant in the same hub. Main and fetch quests use their authored
  `quest_location`. A companion's quest has none: it goes where the party goes.
- Save: optional `quests.pinned` (a quest id), written only while something is tracked, so a
  save with nothing tracked has exactly the old shape. A missing, junk, or inactive id loads as
  nothing tracked; tracking never fails a load. No schema bump.
- `tracked_quest()` (unused by the game) now prefers the tracked quest.
- A disk round trip of a tracked stub is in `test_save_game.gd`.

## Q4 as built

Audit before: 0 errors, 10 warnings. After: 0 errors, 0 warnings, 1 info. Flags read 81 → 82 of
82 written; read-back still 9/9 main, 42/42 side. Strict mode exits 0.

- **False positive `f`.** `ui/dialogue/dialogue_choice_info.gd` quotes
  `GameState.get_flag("f") == "returned"` in a comment, and the scan read it as a flag. GDScript
  comments are now stripped before flag scanning (`strip_gd_comments`); a `#` inside a string is
  kept. No real flag was lost: 82 written before and after.
- **Domains.** `hollowmere` (a hub like `dom`; the stake quest, owner item 25) and `trial` (the
  Lower Trial Hall's rooms) were in use without being registered. Both are now registered, which
  clears the other seven grammar warnings. No flag was renamed, so no save is affected.
- **Orphan `trial_store_alarm`.** It is not one. The store wardens wait on it through
  `required_flag = "trial_store_alarm"` in `lower_trial_hall.tscn`, which `Hostile` reads with
  `flag_is_true`. The audit now counts a scene's `required_flag` as a read. No content needed.
- **Bell quest.** `bellhouse_repair` keeps one ending by owner ruling (item 10a, 2026-10-22). It
  is still reported, as `info` naming the ruling, so the warning list holds only undecided items,
  as the stubs already are. Any other single-outcome quest still warns.
- `test_production_zhavar_routes_are_all_written` pinned `quest_registry.gd:551`; Q1's
  `known_quests()` moved that line. It now finds both writer lines by their text.

## Found in CI: a test suite left QuestRegistry deaf

CI's first run of #672 failed three new cases, and only there: a quest's step never advanced
after its flag was set. `test/unit/test_interactive_props.gd` disconnects QuestRegistry from
`GameState.flag_changed` and `inventory_changed` so a prop cannot move a quest, and since
2026-08-09 it never reconnected them. In CI's one-process run, every suite after it had a
registry that ignored flag and inventory changes. The new notice and tracking tests were the
first to rely on the live signal. The suite now hands both connections back, and
`test_the_registry_listens_to_flag_and_inventory_changes` names the leak if it ever returns.
Reproduced locally (props suite, then the quest suites: red), then green with the fix.

## New UI copy (for owner review)

| Where | Text | Note |
|---|---|---|
| Journal state, suspended stub | TO BE CONTINUED | The phrase the stub's own reward reveal already uses. |
| Field notice, quest taken up | NEW QUEST — *The Living Tag* | Same shape as "WORD OF YOU SPREADS — …". |
| Field notice, new step | *THE BROKEN MUSTER* — *Break the demon vanguard.* | The step is the authored objective, unchanged. |
| Journal toggle | Track / Tracking | Tooltip: "Show this quest on the field's objective line." |
| HUD objective, tracked | *THE LIVING TAG* · *step* · GO TO *Dom* | Same shape as the chapter line. |

One existing line is now slightly off: the journal's "The record changes only when the world
does. This page changes nothing." The Track toggle changes the HUD, though nothing in the world.
Left as written; it is approved prose.
