class_name EncounterCatalog
extends RefCounted
## Runtime adapter for Pandora-authored encounter data. The generator resolves
## combatant IDs into complete enemy rows, so battle code never depends on
## Pandora itself and exported builds only need the committed JSON artifact.

const DATA_PATH := "res://data/generated/encounters.json"
const _FIELD_GRID_DATA := {
	"bog-wight": {"dimensions": Vector2i(2, 4)},
	"loam-boar": {"dimensions": Vector2i(2, 4)},
	"dorthkor-vanguard": {"dimensions": Vector2i(2, 4)},
	"dorthkor-muster": {"dimensions": Vector2i(2, 4)},
	"jawbrace-empty-post": {"dimensions": Vector2i(2, 4)},
	"phase2-demon": {"dimensions": Vector2i(2, 4)},
	"phase2-undead": {"dimensions": Vector2i(2, 4)},
	"phase2-mixed-whipsaw": {"dimensions": Vector2i(2, 4)},
	"phase2-speech-winnable": {"dimensions": Vector2i(2, 4)},
	"phase2-stabilizer-showcase": {"dimensions": Vector2i(2, 4)},
}
## #209: per-encounter authored weather element (Wheel id → the battle's Weather).
## Deliberately EMPTY: which encounters get which weather is an owner balance
## decision (`tools/combat_number_sweep.gd` delta must accompany any entry — see the
## issue's acceptance checks). The mechanism is live; the authoring is not decided here.
const _WEATHER_DEFAULTS: Dictionary = {}
## PROVISIONAL — first-pass encounter loot, pending a dedicated balance sweep.
## This authored registry keeps generated Pandora artifacts untouched.
const _SPOILS: Dictionary = {
	&"bog-wight": [ItemIds.MATERIALS_GRAVE_SALT, ItemIds.CONSUMABLES_BITTERLEAF_POULTICE],
	&"loam-boar": [ItemIds.MATERIALS_LOAMROOT_SPRIG, ItemIds.CONSUMABLES_LOAM_BREAD],
	&"dorthkor-vanguard": [ItemIds.MATERIALS_IRON_RIVETS, ItemIds.MATERIALS_BINDING_THREAD],
	&"dorthkor-muster": [ItemIds.MATERIALS_IRON_RIVETS, ItemIds.MATERIALS_BINDING_THREAD],
	&"jawbrace-empty-post": [ItemIds.MATERIALS_IRON_RIVETS, ItemIds.CONSUMABLES_LOAM_BREAD],
	&"phase2-demon": [ItemIds.MATERIALS_CINDER_INK_VIAL, ItemIds.MATERIALS_GRAVE_SALT],
	&"phase2-undead": [ItemIds.MATERIALS_GRAVE_SALT, ItemIds.MATERIALS_BINDING_THREAD],
	&"phase2-mixed-whipsaw": [ItemIds.MATERIALS_GRAVE_SALT, ItemIds.MATERIALS_IRON_RIVETS],
	&"phase2-speech-winnable": [ItemIds.CONSUMABLES_LOAM_BREAD, ItemIds.MATERIALS_BINDING_THREAD],
	&"phase2-stabilizer-showcase": [ItemIds.MATERIALS_LOAMROOT_SPRIG, ItemIds.MATERIALS_CINDER_INK_VIAL],
}
const _SPOILS_STREAM_OFFSET := 7_000_019

static var _definitions: Dictionary = {}


static func definition(encounter_id: StringName) -> Dictionary:
	_ensure_loaded()
	var row: Variant = _definitions.get(String(encounter_id), {})
	var result: Dictionary = row.duplicate(true) if row is Dictionary else {}
	var grid: Variant = _FIELD_GRID_DATA.get(String(encounter_id), {})
	if grid is Dictionary and not grid.is_empty():
		result["grid"] = grid.duplicate(true)
	var authored_weather := str(_WEATHER_DEFAULTS.get(String(encounter_id), ""))
	if not authored_weather.is_empty():
		result["weather_default"] = authored_weather
	return result


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
		actor.archetype_id = StringName(row.get("id", ""))
		actor.display_name = str(row.get("display_name", "Enemy"))
		actor.max_hp = int(row.get("max_hp", 10))
		actor.hp = actor.max_hp
		actor.attack = int(row.get("attack", 5))
		actor.defense = int(row.get("defense", 2))
		actor.balance_affinity = int(row.get("balance_affinity", 0))
		actor.balance_pressure = int(row.get("balance_pressure", 12))
		actor.element_id = StringName(row.get("element_id", ""))
		actor.attributes[&"edge"] = int(row.get("edge", 0))
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


static func loss(encounter_id: StringName) -> Dictionary:
	var row := definition(encounter_id)
	var authored: Variant = row.get("loss", {})
	if authored is Dictionary and not authored.is_empty():
		return authored.duplicate(true)
	return {
		"faction": row.get("loss_faction", ""),
		"delta": row.get("loss_delta", 0.0),
		"cause": row.get("loss_cause", ""),
	}


static func default_outcome(encounter_id: StringName) -> StringName:
	return StringName(definition(encounter_id).get("default_outcome", "slain"))


static func roll_spoils(encounter_id: StringName) -> Array[Dictionary]:
	var item_ids: Array = _SPOILS.get(encounter_id, [])
	if item_ids.is_empty():
		return []
	var rng := RandomNumberGenerator.new()
	rng.seed = int(String(encounter_id).hash()) + _SPOILS_STREAM_OFFSET
	var result: Array[Dictionary] = [{
		"item_id": String(item_ids[0]),
		"quantity": rng.randi_range(1, 2),
	}]
	if item_ids.size() > 1 and rng.randf() < 0.5:
		result.append({
			"item_id": String(item_ids[1]),
			"quantity": rng.randi_range(1, 2),
		})
	return result


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
