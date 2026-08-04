class_name CombatActionCatalog
extends RefCounted
## Loads authored action Resources by directory. Adding an action is a data-only
## operation; the resolver changes only when a genuinely new effect pipeline exists.

const ACTION_DIRECTORY := "res://data/combat/actions"


static func all() -> Array[CombatAction]:
	var actions: Array[CombatAction] = []
	var files := DirAccess.get_files_at(ACTION_DIRECTORY)
	files.sort()
	for file_name in files:
		if file_name.get_extension() != "tres":
			continue
		var resource := load(ACTION_DIRECTORY.path_join(file_name))
		if resource is CombatAction:
			actions.append(resource.duplicate(true) as CombatAction)
	return actions


static func player_actions() -> Array[CombatAction]:
	var result: Array[CombatAction] = []
	for action in all():
		if action.player_available:
			result.append(action)
	return result


static func by_id(action_id: StringName) -> CombatAction:
	for action in all():
		if action.id == action_id:
			return action
	return null
