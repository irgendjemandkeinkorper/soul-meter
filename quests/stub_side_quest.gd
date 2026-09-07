class_name StubSideQuest
extends DomSideQuest
## A side quest that ships VISIBLE and deliberately unfinished (#302, S8).
##
## Owner ruling 2026-09-04 (`docs/ship-plan-2026-10.md`): side quests 5–10 ship
## as stubs, and the stubs are visible in-world rather than cut. Four of ten are
## complete for gold; the other six are signposted, enterable, and end on an
## honest "to be continued" that a post-launch update resumes.
##
## The load-bearing property is that a stub CANNOT write a ledger row, and not
## because nobody calls the write. It carries no outcome arrays at all, so
## `outcome_for()` returns `{}` for every id, and `QuestRegistry.resolve_side_quest()`
## returns false on that empty dictionary before it reaches `Reputation.record()`.
## A stub authored with an outcome by mistake is refused by `is_valid_stub()`
## rather than quietly becoming a half-priced real quest.
##
## `resume_flag` is the whole point of shipping these visible. It is durable
## GameState, so a save made in Chapter 1 tells the update which threads this
## player actually opened — the update resumes them instead of re-offering them.
##
## Stubs are NOT in `QuestRegistry.DOM_SIDE_QUESTS`. That array is the ten
## resolvable Dom side quests and `ui/screens/chapter_complete.gd` renders
## "RESOLVED n / <its size>"; counting six unfinishable threads in that
## denominator would report the player failed six quests they were never
## offered a way to finish. They live in `STUB_SIDE_QUESTS` and join the routed
## set through `_registered_side_quests()`, which is what makes the giver's
## dialogue resolve.

## The resolution id a suspended stub completes under. Not an outcome id — no
## outcome exists — just the label the quest log and the reward summary show.
const TO_BE_CONTINUED := "to-be-continued"

## Durable flag set when the player reaches the stub's suspension beat. A
## post-launch update keys the resumed thread on this.
@export var resume_flag: String = ""

## One line of what the update is expected to open. Authoring note, shown
## nowhere: it exists so the resumed quest is written against a recorded
## intention rather than a reconstruction of one.
@export_multiline var continuation_note: String = ""


## A stub is only honest if it has no outcomes to apply and a flag to resume by.
func is_valid_stub() -> bool:
	return (
		outcome_count() == 0
		and outcome_labels.is_empty()
		and outcome_faction_ids.is_empty()
		and outcome_reputation_deltas.is_empty()
		and outcome_causes.is_empty()
		and outcome_readbacks.is_empty()
		and outcome_tags.is_empty()
		and outcome_soul_deltas.is_empty()
		and not resume_flag.strip_edges().is_empty()
		and not stable_id.strip_edges().is_empty()
		and not giver_actor_id.strip_edges().is_empty()
		and not dialogue_title.strip_edges().is_empty()
	)
