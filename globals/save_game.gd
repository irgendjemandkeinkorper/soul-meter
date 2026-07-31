extends Node
## Owns the chapter save slot. The payload is versioned and written through a
## temporary file so an interrupted save cannot destroy the previous one.

signal saved
signal loaded
signal save_failed(message: String)
signal autosave_finished(reason: String, succeeded: bool)

const SAVE_PATH := "user://chapter_one.save"
const TEMP_PATH := "user://chapter_one.save.tmp"
const BACKUP_PATH := "user://chapter_one.save.bak"
const FORMAT_VERSION := 2

var pending_player_position := Vector2.ZERO
var has_pending_player_position := false
var pending_spawn_id: StringName = &"default"

var _pending_autosave_reason := ""
var _run_started_unix := 0
var _elapsed_before_load := 0


func has_save() -> bool:
	return FileAccess.file_exists(SAVE_PATH)


func save() -> bool:
	var file := FileAccess.open(TEMP_PATH, FileAccess.WRITE)
	if file == null:
		return _fail("Could not open the save file for writing.")
	file.store_var(_build_payload())
	file.close()

	var temp_path := ProjectSettings.globalize_path(TEMP_PATH)
	var save_path := ProjectSettings.globalize_path(SAVE_PATH)
	var backup_path := ProjectSettings.globalize_path(BACKUP_PATH)
	if FileAccess.file_exists(BACKUP_PATH):
		DirAccess.remove_absolute(backup_path)
	if FileAccess.file_exists(SAVE_PATH):
		var backup_err := DirAccess.rename_absolute(save_path, backup_path)
		if backup_err != OK:
			DirAccess.remove_absolute(temp_path)
			return _fail("Could not protect the previous save before writing.")
	var err := DirAccess.rename_absolute(temp_path, save_path)
	if err != OK:
		DirAccess.remove_absolute(temp_path)
		if FileAccess.file_exists(BACKUP_PATH):
			DirAccess.rename_absolute(backup_path, save_path)
		return _fail("Could not finish writing the save file.")
	if FileAccess.file_exists(BACKUP_PATH):
		DirAccess.remove_absolute(backup_path)
	saved.emit()
	return true


func request_autosave(reason: String) -> void:
	_pending_autosave_reason = reason
	call_deferred("flush_pending_autosave")


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
	var file := FileAccess.open(SAVE_PATH, FileAccess.READ)
	if file == null:
		return _fail("No readable save file was found.")
	var payload: Variant = file.get_var()
	file.close()
	if not validate_payload(payload):
		return _fail("This save file uses an unsupported format.")
	var game_state_backup := GameState.to_dict()
	var reputation_backup := Reputation.to_dict()
	var renown_backup := Renown.to_dict()
	var quests_backup := QuestRegistry.to_dict()
	if not GameState.from_dict(payload.get("game_state", {})):
		GameState.from_dict(game_state_backup)
		Reputation.from_dict(reputation_backup)
		Renown.from_dict(renown_backup)
		QuestRegistry.from_dict(quests_backup)
		return _fail("The inventory in this save file is invalid.")
	_apply_runtime_feature_flags()
	Reputation.from_dict(payload.get("reputation", {}))
	Renown.from_dict(payload.get("renown", {}))
	QuestRegistry.from_dict(payload.get("quests", {}))
	GameFlow._target_scene = str(payload.get("scene", GameFlow.TOWN_SCENE))
	GameFlow._target_spawn_id = StringName(payload.get("spawn_id", "default"))
	pending_player_position = payload.get("player_position", Vector2.ZERO)
	has_pending_player_position = payload.has("player_position")
	pending_spawn_id = GameFlow._target_spawn_id
	_elapsed_before_load = int(payload.get("elapsed_seconds", 0))
	_run_started_unix = int(Time.get_unix_time_from_system())
	loaded.emit()
	return true


func validate_payload(payload: Variant) -> bool:
	if not payload is Dictionary or int(payload.get("version", -1)) != FORMAT_VERSION:
		return false
	for section in ["game_state", "reputation", "renown", "quests"]:
		if not payload.get(section) is Dictionary:
			return false
	if payload.has("player_position") and not payload.get("player_position") is Vector2:
		return false
	if payload.has("spawn_id") and not payload.get("spawn_id") is String:
		return false
	var scene := str(payload.get("scene", ""))
	return scene in GameFlow.GAMEPLAY_SCENES


func new_game() -> void:
	GameState.flags.clear()
	_apply_runtime_feature_flags()
	GameState.soul_meter = 50.0
	GameState._seed_demo_data()
	Reputation.from_dict({})
	Renown.from_dict({})
	QuestRegistry.reset()
	GameFlow._target_scene = GameFlow.TOWN_SCENE
	GameFlow._target_spawn_id = &"new_game"
	pending_spawn_id = &"new_game"
	has_pending_player_position = false
	_elapsed_before_load = 0
	_run_started_unix = int(Time.get_unix_time_from_system())
	_pending_autosave_reason = "initial-spawn"


func apply_pending_location(scene: Node) -> void:
	var player := scene.find_child("Player", true, false) as Node2D
	if player == null:
		return
	if has_pending_player_position:
		player.global_position = pending_player_position
	else:
		var marker_name := "Spawn" + _pascal_case(String(pending_spawn_id))
		var marker := scene.find_child(marker_name, true, false) as Marker2D
		if marker == null:
			marker = scene.find_child("SpawnDefault", true, false) as Marker2D
		if marker:
			player.global_position = marker.global_position
	has_pending_player_position = false
	pending_spawn_id = &"default"


func apply_pending_position(scene: Node) -> void:
	apply_pending_location(scene)


func _build_payload() -> Dictionary:
	var scene := get_tree().current_scene
	var scene_path: String = GameFlow.TOWN_SCENE
	var payload := {
		"version": FORMAT_VERSION,
		"saved_at": int(Time.get_unix_time_from_system()),
		"game_state": GameState.to_dict(),
		"reputation": Reputation.to_dict(),
		"renown": Renown.to_dict(),
		"quests": QuestRegistry.to_dict(),
		"elapsed_seconds": elapsed_seconds(),
		"spawn_id": String(GameFlow._target_spawn_id),
	}
	if scene and scene.scene_file_path in GameFlow.GAMEPLAY_SCENES:
		scene_path = scene.scene_file_path
		var player := scene.find_child("Player", true, false) as Node2D
		if player:
			payload["player_position"] = player.global_position
	payload["scene"] = scene_path
	return payload


func _fail(message: String) -> bool:
	push_warning(message)
	save_failed.emit(message)
	return false


func _in_gameplay_scene() -> bool:
	var scene := get_tree().current_scene
	return scene != null and scene.scene_file_path in GameFlow.GAMEPLAY_SCENES


func _pascal_case(value: String) -> String:
	var result := ""
	for part in value.replace("-", "_").split("_", false):
		result += part.capitalize().replace(" ", "")
	return result


func _apply_runtime_feature_flags() -> void:
	if OS.get_cmdline_user_args().has("extended-content"):
		GameState.set_flag("prototype_extended_content", true)
