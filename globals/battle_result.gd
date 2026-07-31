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


func succeeded() -> bool:
	return state == State.VICTORY


func fled() -> bool:
	return state == State.FLED
