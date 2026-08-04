class_name CombatIdentityCatalog
extends RefCounted
## Runtime adapter for Pandora-authored Balance bands and Defining Strike
## weakness tables. Combat code consumes this generated artifact only.

const DATA_PATH := "res://data/generated/combat_identity.json"

static var _data: Dictionary = {}


static func balance_minimum() -> int:
	_ensure_loaded()
	return int(_balance_data().get("minimum", 0))


static func balance_maximum() -> int:
	_ensure_loaded()
	return int(_balance_data().get("maximum", 0))


static func balance_bands() -> Array[Dictionary]:
	_ensure_loaded()
	var result: Array[Dictionary] = []
	var rows: Variant = _balance_data().get("bands", [])
	if rows is Array:
		for row: Variant in rows:
			if row is Dictionary:
				result.append(row.duplicate(true))
	return result


static func balance_band(value: int) -> Dictionary:
	var bands := balance_bands()
	for band: Dictionary in bands:
		if value >= int(band.get("minimum", value)) and value <= int(band.get("maximum", value)):
			return band
	if bands.is_empty():
		return {}
	return bands[0] if value < int(bands[0].get("minimum", value)) else bands[-1]


static func balance_effects(value: int, suppressed: bool = false) -> Dictionary:
	var band := balance_band(value)
	# Stillpoint suppresses the global order/chaos hazards, while the authored
	# party-only centre reward remains active.
	if suppressed and bool(band.get("global", false)):
		return {}
	var effects: Variant = band.get("effects", {})
	return effects.duplicate(true) if effects is Dictionary else {}


static func archetype_ids() -> Array[StringName]:
	_ensure_loaded()
	var result: Array[StringName] = []
	for archetype_id: Variant in _archetype_tables():
		result.append(StringName(str(archetype_id)))
	result.sort()
	return result


static func weaknesses_for(archetype_id: StringName) -> Array[Dictionary]:
	_ensure_loaded()
	var result: Array[Dictionary] = []
	var rows: Variant = _archetype_tables().get(String(archetype_id), [])
	if rows is Array:
		for row: Variant in rows:
			if row is Dictionary:
				result.append(row.duplicate(true))
	return result


static func weakness(archetype_id: StringName, weakness_id: StringName) -> Dictionary:
	for row: Dictionary in weaknesses_for(archetype_id):
		if StringName(row.get("id", "")) == weakness_id:
			return row
	return {}


static func discovery_candidates(
	archetype_id: StringName, lore_percent: float, prior_encounters: int
) -> Array[Dictionary]:
	var result: Array[Dictionary] = []
	for row: Dictionary in weaknesses_for(archetype_id):
		var lore_minimum := float(row.get("lore_minimum", 0.0))
		var encounter_minimum := int(row.get("prior_encounters", 0))
		if lore_percent >= lore_minimum or prior_encounters >= encounter_minimum:
			result.append(row)
	return result


static func clear_cache() -> void:
	_data.clear()


static func _balance_data() -> Dictionary:
	var value: Variant = _data.get("balance", {})
	return value if value is Dictionary else {}


static func _archetype_tables() -> Dictionary:
	var strikes: Variant = _data.get("defining_strikes", {})
	if not strikes is Dictionary:
		return {}
	var value: Variant = strikes.get("archetypes", {})
	return value if value is Dictionary else {}


static func _ensure_loaded() -> void:
	if not _data.is_empty():
		return
	var text := FileAccess.get_file_as_string(DATA_PATH)
	var parsed: Variant = JSON.parse_string(text)
	if parsed is Dictionary:
		_data = parsed
	else:
		push_error("Could not load generated combat identity data from %s." % DATA_PATH)
