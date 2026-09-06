class_name EncounterCatalog
extends RefCounted
## Runtime adapter for Pandora-authored encounter data. The generator resolves
## combatant IDs into complete enemy rows, so battle code never depends on
## Pandora itself and exported builds only need the committed JSON artifact.

const DATA_PATH := "res://data/generated/encounters.json"
## PROVISIONAL — Wave R first-pass board balance; every dimension and terrain cell
## remains subject to encounter playtesting. Deployment columns intentionally stay clear.
const _FIELD_GRID_DATA := {
	"bog-wight": {
		"dimensions": Vector2i(7, 5),
		# Contestable tussocks around low hummocks in the bog's center.
		"cover": [Vector2i(2, 1), Vector2i(2, 2), Vector2i(3, 2), Vector2i(4, 3)],
		"elevation": {Vector2i(3, 1): 1, Vector2i(4, 2): 2},
	},
	"loam-boar": {
		"dimensions": Vector2i(7, 6),
		"cover": [Vector2i(2, 2), Vector2i(3, 2), Vector2i(4, 3)],
		"elevation": {Vector2i(2, 3): 1, Vector2i(3, 4): 1, Vector2i(5, 2): 2},
	},
	"dorthkor-vanguard": {
		"dimensions": Vector2i(9, 6),
		# Broken wagon cover below the Dorthkor Road embankment.
		"cover": [Vector2i(3, 1), Vector2i(3, 2), Vector2i(4, 2), Vector2i(5, 4)],
		"elevation": {Vector2i(5, 1): 1, Vector2i(6, 1): 2, Vector2i(6, 2): 2},
	},
	"dorthkor-muster": {
		"dimensions": Vector2i(8, 6),
		"cover": [Vector2i(2, 1), Vector2i(3, 1), Vector2i(4, 3), Vector2i(5, 3), Vector2i(5, 4)],
		"elevation": {Vector2i(2, 4): 1, Vector2i(3, 4): 2},
	},
	"jawbrace-empty-post": {
		"dimensions": Vector2i(8, 5),
		# Paired Jawbrace barricades leave a contested center lane.
		"cover": [Vector2i(2, 1), Vector2i(2, 2), Vector2i(5, 2), Vector2i(5, 3)],
		"elevation": {Vector2i(3, 3): 1},
	},
	"phase2-demon": {
		"dimensions": Vector2i(9, 5),
		"cover": [Vector2i(3, 1), Vector2i(4, 1), Vector2i(5, 3)],
		"elevation": {Vector2i(4, 2): 3, Vector2i(5, 2): 2, Vector2i(6, 3): 1},
	},
	"phase2-undead": {
		"dimensions": Vector2i(8, 5),
		"cover": [Vector2i(2, 1), Vector2i(3, 2), Vector2i(4, 2), Vector2i(5, 3)],
		"elevation": {Vector2i(3, 1): 1, Vector2i(4, 3): 2},
	},
	"phase2-mixed-whipsaw": {
		"dimensions": Vector2i(9, 6),
		"cover": [Vector2i(2, 2), Vector2i(3, 2), Vector2i(5, 3), Vector2i(6, 3), Vector2i(4, 4)],
		"elevation": {
			Vector2i(4, 1): 1,
			Vector2i(4, 2): 2,
			Vector2i(4, 3): 3,
			Vector2i(4, 4): 1,
		},
	},
	"phase2-speech-winnable": {
		"dimensions": Vector2i(7, 5),
		"cover": [Vector2i(2, 1), Vector2i(3, 2)],
		"elevation": {},
	},
	"phase2-stabilizer-showcase": {
		"dimensions": Vector2i(8, 6),
		"cover": [Vector2i(2, 3), Vector2i(3, 3), Vector2i(4, 2), Vector2i(5, 2)],
		"elevation": {Vector2i(3, 1): 1, Vector2i(4, 1): 1, Vector2i(5, 4): 2},
	},
	"trial-warden": {
		"dimensions": Vector2i(7, 6),
		# Trial-hall pillars frame the center dais without blocking deployment.
		"cover": [Vector2i(2, 1), Vector2i(2, 4), Vector2i(4, 1), Vector2i(4, 4)],
		"elevation": {Vector2i(3, 2): 1, Vector2i(3, 3): 1},
	},
	"trial-keeper": {
		"dimensions": Vector2i(9, 5),
		"cover": [Vector2i(2, 1), Vector2i(2, 3), Vector2i(4, 2), Vector2i(6, 1), Vector2i(6, 3)],
		"elevation": {Vector2i(4, 1): 1, Vector2i(4, 3): 2, Vector2i(5, 2): 1},
	},
}
## #209: PROVISIONAL per-encounter authored weather (Wheel id → battle Weather).
## Wave R sweep evidence (2026-08-29): before/after reports were byte-identical
## (SHA-256 3f7d412f...e21b9a1; multiplier, TTK, wager deltas all 0). The current
## tools/combat_number_sweep.gd is a static facing/elevation/wheel-distance sweep and
## does not read EncounterCatalog, so it has no per-encounter rows to change.
const _WEATHER_DEFAULTS: Dictionary = {
	"bog-wight": "mozh",
	"loam-boar": "tham",
	"phase2-demon": "khash",
}
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
	&"trial-warden": [ItemIds.MATERIALS_IRON_RIVETS],
	&"trial-keeper": [ItemIds.MATERIALS_BINDING_THREAD],
}
const _SPOILS_STREAM_OFFSET := 7_000_019

static var _definitions: Dictionary = {}
static var _runtime_definitions: Dictionary = {}


static func definition(encounter_id: StringName) -> Dictionary:
	_ensure_loaded()
	var runtime_row: Variant = _runtime_definitions.get(String(encounter_id))
	if _runtime_definitions.has(String(encounter_id)) and runtime_row is Dictionary:
		return (runtime_row as Dictionary).duplicate(true)
	var row: Variant = _definitions.get(String(encounter_id), {})
	var result: Dictionary = row.duplicate(true) if row is Dictionary else {}
	var grid: Variant = _FIELD_GRID_DATA.get(String(encounter_id), {})
	if grid is Dictionary and not grid.is_empty():
		result["grid"] = grid.duplicate(true)
	var authored_weather := str(_WEATHER_DEFAULTS.get(String(encounter_id), ""))
	if not authored_weather.is_empty():
		result["weather_default"] = authored_weather
	return result


## An encounter may locally override its containing location without changing
## the LocationDefinition authored for every other encounter in that scene.
static func agreement_integrity(encounter_id: StringName, fallback: float) -> float:
	var encounter := definition(encounter_id)
	var value: Variant = encounter.get("agreement_integrity", fallback)
	if typeof(value) not in [TYPE_INT, TYPE_FLOAT]:
		return clampf(fallback, 0.0, 100.0)
	return clampf(float(value), 0.0, 100.0)


static func register_runtime_encounters(definitions: Dictionary) -> bool:
	_ensure_loaded()
	var replacement: Dictionary = {}
	for encounter_value: Variant in definitions.keys():
		var encounter_id: String = str(encounter_value)
		var definition_value: Variant = definitions[encounter_value]
		if encounter_id.is_empty() or _definitions.has(encounter_id):
			return false
		if not definition_value is Dictionary:
			return false
		replacement[encounter_id] = (definition_value as Dictionary).duplicate(true)
	_runtime_definitions = replacement
	return true


static func clear_runtime_encounters() -> void:
	_runtime_definitions.clear()


static func has_committed(encounter_id: String) -> bool:
	_ensure_loaded()
	return _definitions.has(encounter_id)


static func committed_archetype(archetype_id: String) -> Dictionary:
	_ensure_loaded()
	for definition_value: Variant in _definitions.values():
		if not definition_value is Dictionary:
			continue
		var enemy_values: Variant = (definition_value as Dictionary).get("enemies", [])
		if not enemy_values is Array:
			continue
		for enemy_value: Variant in enemy_values:
			if enemy_value is Dictionary and str((enemy_value as Dictionary).get("id", "")) == archetype_id:
				return (enemy_value as Dictionary).duplicate(true)
	return {}


static func all_ids() -> Array[StringName]:
	_ensure_loaded()
	var result: Array[StringName] = []
	for encounter_value: Variant in _definitions.keys():
		result.append(StringName(str(encounter_value)))
	for encounter_value: Variant in _runtime_definitions.keys():
		result.append(StringName(str(encounter_value)))
	result.sort()
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
	if _runtime_definitions.has(String(encounter_id)):
		return _runtime_spoils(encounter_id)
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


static func _runtime_spoils(encounter_id: StringName) -> Array[Dictionary]:
	var result: Array[Dictionary] = []
	var spoils_value: Variant = definition(encounter_id).get("spoils", [])
	if not spoils_value is Array:
		return result
	for spoil_value: Variant in spoils_value:
		if spoil_value is Dictionary:
			var row: Dictionary = (spoil_value as Dictionary).duplicate(true)
			if not row.has("quantity"):
				row["quantity"] = 1
			result.append(row)
		elif spoil_value is String:
			result.append({"item_id": spoil_value, "quantity": 1})
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
