class_name EncounterCatalog
extends RefCounted
## Runtime adapter for Pandora-authored encounter data. The generator resolves
## combatant IDs into complete enemy rows, so battle code never depends on
## Pandora itself and exported builds only need the committed JSON artifact.

const DATA_PATH := "res://data/generated/encounters.json"

static var _definitions: Dictionary = {}


static func definition(encounter_id: StringName) -> Dictionary:
	_ensure_loaded()
	var row: Variant = _definitions.get(String(encounter_id), {})
	return row.duplicate(true) if row is Dictionary else {}


static func make_actors(encounter_id: StringName) -> Array[BattleActor]:
	var encounter := definition(encounter_id)
	var actors: Array[BattleActor] = []
	if encounter.is_empty():
		push_error("Unknown encounter ID: %s" % encounter_id)
		return actors

	var enemy_rows: Variant = encounter.get("enemies", [])
	if not enemy_rows is Array:
		push_error("Encounter '%s' has invalid enemy data." % encounter_id)
		return actors
	for row: Variant in enemy_rows:
		if not row is Dictionary:
			continue
		var actor := BattleActor.new()
		actor.display_name = str(row.get("display_name", "Enemy"))
		actor.max_hp = int(row.get("max_hp", 10))
		actor.hp = actor.max_hp
		actor.attack = int(row.get("attack", 5))
		actor.defense = int(row.get("defense", 2))
		actor.balance_affinity = int(row.get("balance_affinity", 0))
		actor.balance_pressure = int(row.get("balance_pressure", 12))
		actors.append(actor)

	if not actors.is_empty():
		_apply_outcome(encounter, actors[0])
	return actors


static func defeated_flag(encounter_id: StringName) -> String:
	return str(definition(encounter_id).get("defeated_flag", ""))


static func context_actions(encounter_id: StringName) -> Array[Dictionary]:
	var result: Array[Dictionary] = []
	var rows: Variant = definition(encounter_id).get("context_actions", [])
	if rows is Array:
		for row in rows:
			if row is Dictionary:
				result.append(row.duplicate(true))
	return result


static func outcome(encounter_id: StringName, outcome_id: StringName) -> Dictionary:
	var outcomes: Variant = definition(encounter_id).get("outcomes", {})
	if outcomes is Dictionary:
		var row: Variant = outcomes.get(String(outcome_id), {})
		if row is Dictionary:
			return row.duplicate(true)
	return {}


static func default_outcome(encounter_id: StringName) -> StringName:
	return StringName(definition(encounter_id).get("default_outcome", "slain"))


static func clear_cache() -> void:
	_definitions.clear()


static func _apply_outcome(encounter: Dictionary, actor: BattleActor) -> void:
	actor.defeated_flag = str(encounter.get("defeated_flag", ""))
	actor.win_faction = str(encounter.get("win_faction", ""))
	actor.win_delta = float(encounter.get("win_delta", 0.0))
	actor.win_cause = str(encounter.get("win_cause", ""))
	actor.loss_faction = str(encounter.get("loss_faction", ""))
	actor.loss_delta = float(encounter.get("loss_delta", 0.0))
	actor.loss_cause = str(encounter.get("loss_cause", ""))


static func _ensure_loaded() -> void:
	if not _definitions.is_empty():
		return
	var text := FileAccess.get_file_as_string(DATA_PATH)
	var parsed: Variant = JSON.parse_string(text)
	if parsed is Dictionary:
		_definitions = parsed
	else:
		push_error("Could not load generated encounter data from %s." % DATA_PATH)
