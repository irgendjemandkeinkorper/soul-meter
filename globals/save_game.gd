extends Node
## Owns the chapter save slot. The payload is versioned and written through a
## temporary file so an interrupted save cannot destroy the previous one.

signal saved
signal loaded
signal load_requested(destination: LoadDestination)
signal save_failed(message: String)
signal autosave_finished(reason: String, succeeded: bool)
signal spawn_marker_diagnostic(severity: String, marker_name: String, scene_path: String)
signal save_diagnostic(severity: String, message: String)

const SAVE_PATH := "user://chapter_one.save"
const TEMP_PATH := "user://chapter_one.save.tmp"
const BACKUP_PATH := "user://chapter_one.save.bak"
const FORMAT_VERSION := 2
const SCHEMA_VERSION := SaveMigrations.CURRENT_SCHEMA_VERSION
const ZHAVAR_RUNGS := ["low", "rising", "tolling", "ringing", "unprecedented"]

# Instance paths keep the production slot as the default while allowing tests
# to exercise disk-level rotation without touching a developer's real save.
var save_path := SAVE_PATH
var temp_path := TEMP_PATH
var backup_path := BACKUP_PATH

enum Checkpoint {
	NEW_GAME,
	PARTY_FORMED,
	COMMISSION,
	LOCATION_ARRIVAL,
	ENCOUNTER_RESOLUTION,
	RULING,
	FREE_ROAM_UNLOCK,
}

const CHECKPOINT_NAMES := {
	Checkpoint.NEW_GAME: "initial-spawn",
	Checkpoint.PARTY_FORMED: "party-formed",
	Checkpoint.COMMISSION: "commission-accepted",
	Checkpoint.LOCATION_ARRIVAL: "arrived",
	Checkpoint.ENCOUNTER_RESOLUTION: "encounter",
	Checkpoint.RULING: "ruling",
	Checkpoint.FREE_ROAM_UNLOCK: "free-roam-unlocked",
}

var pending_player_position := Vector2.ZERO
var has_pending_player_position := false
var pending_spawn_id: StringName = &"default"

var _pending_autosave_reason := ""
var _run_started_unix := 0
var _elapsed_before_load := 0
var ng_plus: Dictionary = NGPlus.default_block()
var zhavar: Dictionary = {}
var last_error := ""

## Tactical-layer per-unit state (issue #141), persisted as the `tactical` envelope
## section from schema 6 on.
##
## PROVISIONAL HOME. This state conceptually belongs beside the party in GameState, but
## globals/game_state.gd is owned by another workstream right now, so the roster is
## parked on the save owner — the one module that already has to build and validate it.
## It is deliberately NOT read by combat yet; moving it to GameState is a follow-up and
## needs no schema change, since the payload shape is the same either way.
var unit_roster := UnitRoster.new()


func has_save() -> bool:
	return FileAccess.file_exists(save_path)


func save() -> bool:
	var file := FileAccess.open(temp_path, FileAccess.WRITE)
	if file == null:
		return _fail("Could not open the save file for writing.")
	file.store_var(_build_payload())
	file.close()

	var absolute_temp_path := ProjectSettings.globalize_path(temp_path)
	var absolute_save_path := ProjectSettings.globalize_path(save_path)
	var absolute_backup_path := ProjectSettings.globalize_path(backup_path)
	var moved_previous_save := false
	if FileAccess.file_exists(save_path):
		# Keep the last known-good payload around after a successful save. The
		# next save replaces this backup only after the current save is moved.
		if FileAccess.file_exists(backup_path):
			DirAccess.remove_absolute(absolute_backup_path)
		var backup_err := DirAccess.rename_absolute(absolute_save_path, absolute_backup_path)
		if backup_err != OK:
			DirAccess.remove_absolute(absolute_temp_path)
			return _fail("Could not protect the previous save before writing.")
		moved_previous_save = true
	var err := DirAccess.rename_absolute(absolute_temp_path, absolute_save_path)
	if err != OK:
		DirAccess.remove_absolute(absolute_temp_path)
		if moved_previous_save and FileAccess.file_exists(backup_path):
			DirAccess.rename_absolute(absolute_backup_path, absolute_save_path)
		return _fail("Could not finish writing the save file.")
	saved.emit()
	return true


func request_autosave(reason: String) -> void:
	_pending_autosave_reason = reason
	call_deferred("flush_pending_autosave")


func request_checkpoint(checkpoint: Checkpoint, detail: String = "") -> void:
	if not CHECKPOINT_NAMES.has(checkpoint):
		push_warning("Unknown save checkpoint: %s" % checkpoint)
		return
	var reason: String = CHECKPOINT_NAMES[checkpoint]
	if not detail.is_empty():
		reason += "-" + detail
	request_autosave(reason)


func flush_pending_autosave() -> bool:
	if _pending_autosave_reason.is_empty() or not _in_gameplay_scene():
		return false
	var reason := _pending_autosave_reason
	_pending_autosave_reason = ""
	var succeeded := save()
	autosave_finished.emit(reason, succeeded)
	return succeeded


func elapsed_seconds() -> int:
	if _run_started_unix <= 0:
		return _elapsed_before_load
	return _elapsed_before_load + maxi(0, int(Time.get_unix_time_from_system()) - _run_started_unix)


func load_save() -> bool:
	var source_path := save_path
	var prepared := _prepare_for_load(_read_payload(source_path))
	if not bool(prepared.get("ok", false)):
		# A save is intentionally recoverable: a failed write or interrupted
		# replacement should fall back to the persistent last-known-good copy.
		source_path = backup_path
		prepared = _prepare_for_load(_read_payload(source_path))
	if not bool(prepared.get("ok", false)):
		return _fail("Could not load save: %s" % prepared.get("error", "corrupt payload"))
	if source_path == backup_path:
		_warn("Primary save was invalid; loading the backup save instead.")
	var payload: Dictionary = prepared["payload"]
	var game_state_backup := GameState.to_dict()
	var reputation_backup := Reputation.to_dict()
	var renown_backup := Renown.to_dict()
	var quests_backup := QuestRegistry.to_dict()
	var ng_plus_backup := ng_plus.duplicate(true)
	var zhavar_backup := zhavar.duplicate(true)
	var skill_check_backup := SkillCheck.to_dict()
	var unit_roster_backup := unit_roster.to_dict()
	if not GameState.from_dict(payload.get("game_state", {})):
		_restore_runtime_state(game_state_backup, reputation_backup, renown_backup, quests_backup, ng_plus_backup, zhavar_backup, skill_check_backup, unit_roster_backup)
		return _fail("The game_state section in this save file is invalid.")
	_apply_runtime_feature_flags()
	Reputation.from_dict(payload.get("reputation", {}))
	Renown.from_dict(payload.get("renown", {}))
	QuestRegistry.from_dict(payload.get("quests", {}))
	ng_plus = NGPlus.normalize(payload.get("ng_plus", {}))
	zhavar = payload.get("zhavar", {}).duplicate(true)
	SkillCheck.from_dict(payload.get("skill_check", {}))
	# _prepare_for_load already proved this parses; the migration guarantees the key.
	var loaded_roster := UnitRoster.from_dict(payload.get("tactical", {}))
	unit_roster = loaded_roster if loaded_roster != null else UnitRoster.new()
	var destination := _destination_from_payload(payload)
	if destination == null:
		_restore_runtime_state(
			game_state_backup,
			reputation_backup,
			renown_backup,
			quests_backup,
			ng_plus_backup,
			zhavar_backup,
			skill_check_backup,
			unit_roster_backup
		)
		return _fail("The save destination is invalid.")
	_set_pending_destination(destination)
	_elapsed_before_load = int(payload.get("elapsed_seconds", 0))
	_run_started_unix = int(Time.get_unix_time_from_system())
	loaded.emit()
	load_requested.emit(destination)
	return true


func validate_payload(payload: Variant) -> bool:
	var prepared := _prepare_for_load(payload)
	return bool(prepared.get("ok", false))


func _prepare_for_load(payload: Variant) -> Dictionary:
	var migration := SaveMigrations.prepare(payload)
	if not bool(migration.get("ok", false)):
		return migration
	var migrated: Dictionary = migration["payload"]
	for section in ["game_state", "reputation", "renown", "quests"]:
		if not migrated.get(section) is Dictionary:
			return _load_failure("Save section '%s' is not a dictionary." % section)
	if not GameState.validate_save_data(migrated["game_state"]):
		return _load_failure("Save game_state data is corrupt.")
	if not _validate_ledger(migrated["reputation"], "reputation"):
		return _load_failure("Save reputation ledger is corrupt.")
	if not _validate_ledger(migrated["renown"], "renown"):
		return _load_failure("Save renown ledger is corrupt.")
	if not _validate_quests(migrated["quests"]):
		return _load_failure("Save quest data is corrupt.")
	if migrated.has("player_position") and not migrated.get("player_position") is Vector2:
		return _load_failure("Save player_position is corrupt.")
	if migrated.has("spawn_id"):
		# Bound the length as well as the type (PR #107): a spawn id is a scene
		# marker name, so anything long is malformed or hostile, not a real save.
		var spawn_id: Variant = migrated.get("spawn_id")
		if not spawn_id is String or (spawn_id as String).length() > 64:
			return _load_failure("Save spawn_id is corrupt.")
	if migrated.has("elapsed_seconds"):
		var elapsed: Variant = migrated.get("elapsed_seconds")
		if not (elapsed is int or elapsed is float):
			return _load_failure("Save elapsed_seconds is corrupt.")
	if migrated.has("zhavar") and not _validate_zhavar(migrated["zhavar"]):
		return _load_failure("Save Zhavar data is corrupt.")
	if migrated.has("ng_plus") and not _validate_ng_plus(migrated["ng_plus"]):
		return _load_failure("Save ng_plus data is corrupt.")
	if migrated.has("id_schemas") and migrated["id_schemas"] != StableIds.schema_manifest():
		return _load_failure("Save stable-ID schema manifest is incompatible.")
	if migrated.has("tactical") and UnitRoster.from_dict(migrated["tactical"]) == null:
		# UnitRoster.from_dict rejects rather than clamps: an attunement value outside
		# -3 .. +3, an element outside the Wheel of Ten, or a per-unit row with no unit
		# fails the whole payload instead of being quietly repaired.
		return _load_failure("Save tactical data is corrupt.")
	if migrated.has("location_id"):
		var location_id: Variant = migrated.get("location_id")
		if not location_id is String or (location_id as String).length() > 64:
			return _load_failure("Save location_id is corrupt.")
	var destination := _destination_from_payload(migrated)
	if destination == null:
		return _load_failure("Save scene is not a gameplay scene.")
	# Schema 5 originally persisted only scene paths. Canonicalize those payloads
	# to the stable registry id without changing their schema version.
	migrated["location_id"] = String(destination.location_id)
	migrated["spawn_id"] = String(destination.spawn_id)
	return {"ok": true, "payload": migrated, "error": ""}


func _destination_from_payload(payload: Dictionary) -> LoadDestination:
	var scene_path := str(payload.get("scene", ""))
	var location_id := StringName(payload.get("location_id", ""))
	var location := LocationRegistry.resolve(scene_path, location_id)
	var spawn_id := StringName(payload.get("spawn_id", "default"))
	var position: Vector2 = payload.get("player_position", Vector2.ZERO)
	if location == null:
		if not GameFlow.GAMEPLAY_SCENES.has(scene_path):
			return null
		return LoadDestination.new(
			&"", spawn_id, position, payload.has("player_position"), scene_path
		)
	if not location.allowed_gameplay:
		return null
	spawn_id = location.resolve_spawn(spawn_id)
	return LoadDestination.new(location.id, spawn_id, position, payload.has("player_position"))


func _set_pending_destination(destination: LoadDestination) -> void:
	pending_spawn_id = destination.spawn_id
	pending_player_position = destination.position
	has_pending_player_position = destination.has_position


func _load_failure(message: String) -> Dictionary:
	return {"ok": false, "payload": {}, "error": message}


func _validate_zhavar(value: Variant) -> bool:
	if not value is Dictionary:
		return false
	for zone_id: Variant in value:
		# Zone keys are ids: bounded in length and spelled the way StableIds says.
		# is_valid() constrains the character set but not the size, so both matter.
		if zone_id == null or not _is_bounded_text(zone_id, 64):
			return false
		if not StableIds.is_valid(StableIds.ZONE, String(zone_id)):
			return false
		var rung: Variant = value[zone_id]
		if not rung is String or rung not in ZHAVAR_RUNGS:
			return false
	return true


func _validate_ledger(value: Dictionary, _label: String) -> bool:
	if value.has("log") and not value["log"] is Array:
		return false
	for row: Variant in value.get("log", []):
		if not row is Dictionary:
			return false
		# Bound the free-text fields so an untrusted save cannot exhaust memory.
		# Ids stay short; cause/scene are prose and scene paths, so they get more room.
		if not _is_bounded_text(row.get("actor"), 64):
			return false
		if not _is_bounded_text(row.get("faction"), 64):
			return false
		if not _is_bounded_text(row.get("kind"), 64):
			return false
		if not _is_bounded_text(row.get("cause"), 256):
			return false
		if not _is_bounded_text(row.get("scene"), 256):
			return false
	return true


## True when `value` is absent, or is text within `max_length`.
## StringName counts as text: RenownEvent.kind is a StringName (&"reputation" /
## &"infamy") and serializes as one, and `StringName is String` is false in
## GDScript — checking only for String would reject every real renown row and
## make any save carrying renown history unloadable. Both ledgers' from_dict()
## coerce with str(), so accepting either type here loses no safety; the length
## bound is what does the work.
func _is_bounded_text(value: Variant, max_length: int) -> bool:
	if value == null:
		return true
	if not (value is String or value is StringName):
		return false
	return String(value).length() <= max_length


func _validate_quests(value: Dictionary) -> bool:
	for pool_name in ["available", "active", "completed"]:
		if value.has(pool_name) and not value[pool_name] is Array:
			return false
		for row: Variant in value.get(pool_name, []):
			if not row is Dictionary or not row.get("data", {}) is Dictionary:
				return false
	return true


func _validate_ng_plus(value: Variant) -> bool:
	if not value is Dictionary:
		return false
	var normalized := NGPlus.normalize(value)
	return (
		typeof(value.get("style_points", 0)) == TYPE_INT
		and value.get("purchased_carry_overs", []) is Array
		and value.get("completion_metadata", {}) is Dictionary
		and normalized["purchased_carry_overs"].size() == value.get("purchased_carry_overs", []).size()
	)


func _restore_runtime_state(
	game_state_data: Dictionary,
	reputation_data: Dictionary,
	renown_data: Dictionary,
	quests_data: Dictionary,
	ng_plus_data: Dictionary,
	zhavar_data: Dictionary,
	skill_check_data: Dictionary,
	unit_roster_data: Dictionary
) -> void:
	GameState.from_dict(game_state_data)
	Reputation.from_dict(reputation_data)
	Renown.from_dict(renown_data)
	QuestRegistry.from_dict(quests_data)
	ng_plus = ng_plus_data.duplicate(true)
	zhavar = zhavar_data.duplicate(true)
	SkillCheck.from_dict(skill_check_data)
	var restored := UnitRoster.from_dict(unit_roster_data)
	unit_roster = restored if restored != null else UnitRoster.new()


func new_game() -> void:
	GameState.flags.clear()
	_apply_runtime_feature_flags()
	GameState.soul_meter = 50.0
	GameState._seed_demo_data()
	Reputation.from_dict({})
	Renown.from_dict({})
	QuestRegistry.reset()
	ng_plus = NGPlus.default_block()
	zhavar = {}
	SkillCheck.from_dict({})
	unit_roster = UnitMigration.roster_from_party(GameState.party)
	var destination := LoadDestination.new(
		LocationRegistry.DOM.id,
		LocationRegistry.DOM.resolve_spawn(&"new_game")
	)
	_set_pending_destination(destination)
	_elapsed_before_load = 0
	_run_started_unix = int(Time.get_unix_time_from_system())
	_pending_autosave_reason = CHECKPOINT_NAMES[Checkpoint.NEW_GAME]
	load_requested.emit(destination)


func apply_pending_location(scene: Node) -> void:
	var player := scene.find_child("Player", true, false) as Node2D
	if player == null:
		return
	if has_pending_player_position:
		player.global_position = pending_player_position
	else:
		var marker_name := "Spawn" + _pascal_case(String(pending_spawn_id))
		var marker := _resolve_spawn_marker(scene, marker_name)
		if marker:
			player.global_position = marker.global_position
	has_pending_player_position = false
	pending_spawn_id = &"default"


func apply_pending_position(scene: Node) -> void:
	apply_pending_location(scene)


func _resolve_spawn_marker(scene: Node, marker_name: String) -> Marker2D:
	var marker := scene.find_child(marker_name, true, false) as Marker2D
	if marker:
		return marker
	var scene_path := _scene_label(scene)
	push_warning(
		"Missing spawn marker '%s' in scene '%s'; falling back to SpawnDefault."
		% [marker_name, scene_path]
	)
	spawn_marker_diagnostic.emit("warning", marker_name, scene_path)
	marker = scene.find_child("SpawnDefault", true, false) as Marker2D
	if marker == null:
		push_error(
			"Missing SpawnDefault marker in scene '%s'; player position was not applied."
			% scene_path
		)
		spawn_marker_diagnostic.emit("error", "SpawnDefault", scene_path)
	return marker


func _build_payload() -> Dictionary:
	var tree := get_tree() if is_inside_tree() else null
	var scene := tree.current_scene if tree else null
	var location: LocationDefinition = LocationRegistry.DOM
	var payload := {
		"version": FORMAT_VERSION,
		"schema_version": SCHEMA_VERSION,
		"id_schemas": StableIds.schema_manifest(),
		"saved_at": int(Time.get_unix_time_from_system()),
		"game_state": GameState.to_dict(),
		"reputation": Reputation.to_dict(),
		"renown": Renown.to_dict(),
		"quests": QuestRegistry.to_dict(),
		"zhavar": zhavar.duplicate(true),
		"ng_plus": NGPlus.normalize(ng_plus),
		"elapsed_seconds": elapsed_seconds(),
		"spawn_id": String(pending_spawn_id),
		"skill_check": SkillCheck.to_dict(),
		"tactical": _snapshot_unit_roster(),
	}
	if scene:
		var current_location := LocationRegistry.by_scene(scene.scene_file_path)
		if current_location != null and current_location.allowed_gameplay:
			location = current_location
		elif GameFlow.GAMEPLAY_SCENES.has(scene.scene_file_path):
			location = null
		var player := scene.find_child("Player", true, false) as Node2D
		if player:
			payload["player_position"] = player.global_position
	payload["location_id"] = String(location.id) if location != null else ""
	payload["scene"] = location.scene_path if location != null else scene.scene_file_path
	return payload


## Reconciles the roster against the live party before serializing it, so a party
## change made since the last load is reflected without any caller having to remember
## to do it. Surviving units keep their JP, mastery, attunement and loadout.
func _snapshot_unit_roster() -> Dictionary:
	unit_roster = UnitMigration.reconcile(unit_roster, GameState.party)
	return unit_roster.to_dict()


func _fail(message: String) -> bool:
	last_error = message
	_warn(message)
	save_failed.emit(message)
	return false


func _warn(message: String) -> void:
	push_warning(message)
	save_diagnostic.emit("warning", message)


func _read_payload(path: String) -> Variant:
	var file := FileAccess.open(path, FileAccess.READ)
	if file == null:
		return null
	# SECURITY: Pass false explicitly to deny deserialization of arbitrary objects/resources.
	var payload: Variant = file.get_var(false)
	file.close()
	return payload


func apply_ng_plus_to_new_game(initial_state: Dictionary, block: Dictionary) -> Dictionary:
	return NGPlus.apply_to_new_game(initial_state, block)


func apply_carry_over(initial_state: Dictionary, block: Dictionary) -> Dictionary:
	return apply_ng_plus_to_new_game(initial_state, block)


func _scene_label(scene: Node) -> String:
	if not scene.scene_file_path.is_empty():
		return scene.scene_file_path
	return scene.name


func _in_gameplay_scene() -> bool:
	if not is_inside_tree():
		return false
	var scene := get_tree().current_scene
	return scene != null and GameFlow.GAMEPLAY_SCENES.has(scene.scene_file_path)


func _pascal_case(value: String) -> String:
	var result := ""
	for part in value.replace("-", "_").split("_", false):
		result += part.capitalize().replace(" ", "")
	return result


func _apply_runtime_feature_flags() -> void:
	# The Deep Trial follow-up chain (dialogue/marshal_coiljaw.dialogue,
	# quests/deep_trial.tres, world/wound_lip.tscn) is built and covered by
	# test/e2e/test_first_chapter_journey.gd; this flag no longer gates WIP
	# content, so it defaults on. --no-extended-content forces it off for
	# playtesting the Chapter 1 stopping point on purpose.
	var enabled := not OS.get_cmdline_user_args().has("no-extended-content")
	GameState.set_flag("prototype_extended_content", enabled)
