class_name CombatActionCatalog
extends RefCounted
## Loads authored action Resources by directory. Adding an action is a data-only
## operation; the resolver changes only when a genuinely new effect pipeline exists.

const ACTION_DIRECTORY := "res://data/combat/actions"

## The loaded Resources, held so the ResourceLoader cache keeps them. Without a holder each
## call re-read every file from disk (about 9 ms per call). Callers still get deep copies.
static var _prototypes: Array[CombatAction] = []


static func all() -> Array[CombatAction]:
	var actions: Array[CombatAction] = []
	for prototype in _loaded():
		actions.append(prototype.duplicate(true) as CombatAction)
	return actions


static func player_actions() -> Array[CombatAction]:
	var result: Array[CombatAction] = []
	for prototype in _loaded():
		if prototype.player_available:
			result.append(prototype.duplicate(true) as CombatAction)
	return result


static func by_id(action_id: StringName) -> CombatAction:
	for prototype in _loaded():
		if prototype.id == action_id:
			return prototype.duplicate(true) as CombatAction
	return null


static func _loaded() -> Array[CombatAction]:
	if _prototypes.is_empty():
		var files := DirAccess.get_files_at(ACTION_DIRECTORY)
		files.sort()
		for file_name in files:
			if file_name.get_extension() != "tres":
				continue
			var resource := load(ACTION_DIRECTORY.path_join(file_name))
			if resource is CombatAction:
				_prototypes.append(resource as CombatAction)
	return _prototypes
