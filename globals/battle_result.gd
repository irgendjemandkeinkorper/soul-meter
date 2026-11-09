class_name BattleResult
extends Resource
## Typed handoff from combat to the field/UI. `outcome_id` distinguishes a
## victory, defeat, or retreat without teaching callers combat rules.

enum State { VICTORY, DEFEAT, FLED }

var state: State = State.DEFEAT
var encounter_id: StringName = &""
var outcome_id: StringName = &""
var message := ""
var cause := ""
var spoils: Array[Dictionary] = []
## #285: XP earned by this victory, and {member_id: new_level} for anyone it
## levelled. Both stay zero/empty on a defeat, a retreat, and on re-entering a
## fight the party has already resolved.
var xp_awarded: int = 0
var levels_gained: Dictionary = {}
## SR7 (owner, 2026-11-08): what a lost ambient fight cost. `coin_lost` is the gp taken, and
## `wake_hub_id` is the discovered fast-travel hub the party comes to at (GameFlow travels
## there once the outcome is dismissed). Both stay zero/empty for every other result.
var coin_lost: int = 0
var wake_hub_id: StringName = &""


func succeeded() -> bool:
	return state == State.VICTORY


func fled() -> bool:
	return state == State.FLED
