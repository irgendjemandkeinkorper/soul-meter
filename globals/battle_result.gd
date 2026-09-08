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


func succeeded() -> bool:
	return state == State.VICTORY


func fled() -> bool:
	return state == State.FLED
