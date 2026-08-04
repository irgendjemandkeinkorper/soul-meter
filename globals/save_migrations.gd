class_name SaveMigrations
extends RefCounted
## Version transitions for the serialized save envelope.

const LEGACY_SCHEMA_VERSION := 2
const CURRENT_SCHEMA_VERSION := 4


static func prepare(payload: Variant) -> Dictionary:
	if not payload is Dictionary:
		return _failure("Save payload is not a dictionary.")
	var source: Dictionary = payload
	var source_version := _source_version(source)
	if source_version < 0:
		return _failure("Save payload has no valid schema_version.")
	if source_version > CURRENT_SCHEMA_VERSION:
		return _failure(
			"Save schema %d is newer than the supported schema %d."
			% [source_version, CURRENT_SCHEMA_VERSION]
		)
	if source_version < LEGACY_SCHEMA_VERSION:
		return _failure("Save schema %d is unsupported; refusing to load it." % source_version)

	var migrated := source.duplicate(true)
	if source_version == LEGACY_SCHEMA_VERSION:
		migrated = _migrate_v2_to_v3(migrated)
	if source_version <= 3:
		migrated = _migrate_v3_to_v4(migrated)
	migrated["schema_version"] = CURRENT_SCHEMA_VERSION
	return {"ok": true, "payload": migrated, "error": ""}


static func _source_version(source: Dictionary) -> int:
	if source.has("schema_version"):
		if typeof(source["schema_version"]) != TYPE_INT:
			return -1
		return int(source["schema_version"])
	if source.has("version") and typeof(source["version"]) == TYPE_INT:
		return int(source["version"])
	return -1


static func _migrate_v2_to_v3(source: Dictionary) -> Dictionary:
	var migrated := source.duplicate(true)
	var game_state: Dictionary = {}
	if migrated.get("game_state", {}) is Dictionary:
		game_state = migrated.get("game_state", {}).duplicate(true)
	game_state["skills"] = game_state.get("skills", {})
	game_state["var_harmony"] = game_state.get("var_harmony", {})
	migrated["game_state"] = game_state
	migrated["zhavar"] = migrated.get("zhavar", {})
	migrated["ng_plus"] = NGPlus.normalize(migrated.get("ng_plus", {}))
	migrated["id_schemas"] = StableIds.schema_manifest()
	return migrated


static func _migrate_v3_to_v4(source: Dictionary) -> Dictionary:
	var migrated := source.duplicate(true)
	var game_state: Dictionary = {}
	if migrated.get("game_state", {}) is Dictionary:
		game_state = migrated.get("game_state", {}).duplicate(true)
	game_state["combat_knowledge"] = game_state.get("combat_knowledge", {})
	migrated["game_state"] = game_state
	return migrated


static func _failure(message: String) -> Dictionary:
	return {"ok": false, "payload": {}, "error": message}
