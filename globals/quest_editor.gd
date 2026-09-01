extends Node
## Debug-only in-game authoring surface for campaign quest packages.

const QUEST_EDITOR_SCENE_PATH: String = "res://ui/debug/quest_editor.tscn"
const TOGGLE_HOTKEY: Key = KEY_F6
const ENVIRONMENT_VARIABLE: String = "SOUL_METER_QUEST_EDITOR"
const CAMPAIGNS_ROOT: String = "user://campaigns"

var campaigns_root_for_tests: String = ""
var force_enabled_for_tests: bool = false:
	set(value):
		force_enabled_for_tests = value
		_refresh_activation()

var _enabled: bool = false
var _overlay_layer: CanvasLayer = null
var _registered_rows: Array[Dictionary] = []


func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	set_process_unhandled_key_input(false)
	_refresh_activation()


func _exit_tree() -> void:
	_shutdown()


func _unhandled_key_input(event: InputEvent) -> void:
	if not _enabled or not event is InputEventKey:
		return
	var key_event: InputEventKey = event as InputEventKey
	if not key_event.pressed or key_event.echo:
		return
	if key_event.physical_keycode != TOGGLE_HOTKEY and key_event.keycode != TOGGLE_HOTKEY:
		return
	if _overlay_layer == null:
		open_overlay()
	else:
		close_overlay()
	get_viewport().set_input_as_handled()


func is_enabled() -> bool:
	return _enabled


func open_overlay() -> void:
	if not _enabled or _overlay_layer != null:
		return
	var overlay_scene: PackedScene = load(QUEST_EDITOR_SCENE_PATH) as PackedScene
	if overlay_scene == null:
		push_warning("QuestEditor: could not load the editor overlay scene.")
		return
	_overlay_layer = CanvasLayer.new()
	_overlay_layer.name = "QuestEditorLayer"
	_overlay_layer.layer = 1175
	_overlay_layer.process_mode = Node.PROCESS_MODE_ALWAYS
	add_child(_overlay_layer)
	var overlay: Control = overlay_scene.instantiate() as Control
	overlay.name = "QuestEditorOverlay"
	overlay.process_mode = Node.PROCESS_MODE_ALWAYS
	_overlay_layer.add_child(overlay)
	overlay.call("configure", self)


func close_overlay() -> void:
	if not _enabled:
		return
	_close_overlay()


func campaign_ids() -> Array[String]:
	var result: Array[String] = []
	if not _enabled:
		return result
	var root: String = _campaigns_root()
	var absolute_root: String = ProjectSettings.globalize_path(root)
	if not DirAccess.dir_exists_absolute(absolute_root):
		return result
	var directory_names: PackedStringArray = DirAccess.get_directories_at(root)
	for directory_name: String in directory_names:
		if _campaign_id_is_safe(directory_name):
			result.append(directory_name)
	result.sort()
	return result


func campaign_summaries() -> Array[Dictionary]:
	var summaries: Array[Dictionary] = []
	if not _enabled:
		return summaries
	for campaign_id: String in campaign_ids():
		var package_path: String = _package_path(campaign_id)
		var campaign: Dictionary = _read_json_object(package_path.path_join("campaign.json"))
		summaries.append({
			"id": campaign_id,
			"title": str(campaign.get("title", campaign_id)),
			"entry_location": str(campaign.get("entry_location", "")),
		})
	return summaries


func campaign_draft(campaign_id: String) -> Dictionary:
	if not _enabled or not _campaign_id_is_safe(campaign_id):
		return {}
	var package_path: String = _package_path(campaign_id)
	var campaign: Dictionary = _read_json_object(package_path.path_join("campaign.json"))
	var quests: Array[Dictionary] = []
	var quest_directory: String = package_path.path_join("quests")
	if DirAccess.dir_exists_absolute(ProjectSettings.globalize_path(quest_directory)):
		for file_path: String in _quest_json_files(quest_directory):
			var quest: Dictionary = _read_json_object(file_path)
			if not quest.is_empty():
				quests.append(quest)
	var loaded: Dictionary = CampaignQuestLoader.load_package(package_path, false)
	return {
		"campaign": campaign,
		"quests": quests,
		"errors": loaded.get("errors", []),
		"package_path": package_path,
	}


func validate_draft(campaign: Dictionary, quests: Array[Dictionary]) -> Dictionary:
	if not _enabled:
		return {}
	var campaign_id: String = str(campaign.get("id", ""))
	var package_path: String = _package_path(campaign_id)
	var documents: Array[Dictionary] = _quest_documents(package_path, quests)
	return CampaignQuestLoader.validate_package_data(package_path, campaign, documents)


func save_campaign(
	campaign: Dictionary,
	quests: Array[Dictionary],
	force: bool = false,
	authorized_conflict_identities: Array[String] = []
) -> Dictionary:
	if not _enabled:
		return {}
	var campaign_id: String = str(campaign.get("id", ""))
	var validation: Dictionary = validate_draft(campaign, quests)
	var validation_errors: Array = validation.get("errors", [])
	if not validation_errors.is_empty():
		validation["saved"] = false
		validation["written_files"] = (
			_package_json_files(_package_path(campaign_id))
			if _campaign_id_is_safe(campaign_id)
			else []
		)
		return validation

	if not _campaign_id_is_safe(campaign_id):
		return {}
	var package_path: String = _package_path(campaign_id)
	var quest_directory: String = package_path.path_join("quests")
	var make_error: Error = DirAccess.make_dir_recursive_absolute(
		ProjectSettings.globalize_path(quest_directory)
	)
	if make_error != OK and make_error != ERR_ALREADY_EXISTS:
		return _write_failure(
			validation, package_path, package_path, "Could not create the campaign package."
		)

	var campaign_path: String = package_path.path_join("campaign.json")
	var serialized_files: Dictionary = {
		campaign_path: JSON.stringify(campaign, "  ") + "\n",
	}
	for quest: Dictionary in quests:
		var quest_id: String = str(quest.get("quest_id", ""))
		var file_name: String = quest_id + ".json"
		var quest_path: String = quest_directory.path_join(file_name)
		serialized_files[quest_path] = JSON.stringify(quest, "  ") + "\n"

	var transaction: Dictionary = _replace_package_files(
		package_path, quest_directory, serialized_files
	)
	if not bool(transaction.get("ok", false)):
		return _write_failure(
			validation,
			package_path,
			str(transaction.get("file", package_path)),
			str(transaction.get("message", "Could not replace the campaign package."))
		)

	var loaded: Dictionary = _load_and_register(
		package_path, force, authorized_conflict_identities
	)
	loaded["saved"] = (loaded.get("errors", []) as Array).is_empty()
	loaded["written_files"] = _package_json_files(package_path)
	return loaded


func reload_campaign(
	campaign_id: String,
	force: bool = false,
	authorized_conflict_identities: Array[String] = []
) -> Dictionary:
	if not _enabled or not _campaign_id_is_safe(campaign_id):
		return {}
	return _load_and_register(
		_package_path(campaign_id), force, authorized_conflict_identities
	)


func registered_view() -> Array[Dictionary]:
	if not _enabled:
		return []
	return _registered_rows.duplicate(true)


func location_ids() -> Array[String]:
	var result: Array[String] = []
	if not _enabled:
		return result
	for row: Dictionary in WorldMapRegistry.all_locations():
		result.append(str(row.get("id", "")))
	result.sort()
	return result


func giver_actor_ids() -> Array[String]:
	var result: Array[String] = []
	if not _enabled:
		return result
	for row: Dictionary in NpcRoster.all():
		var actor_id: String = str(row.get("id", ""))
		if not actor_id.is_empty():
			result.append(actor_id)
	result.sort()
	return result


func dialogue_titles() -> Array[String]:
	if not _enabled:
		return []
	return CampaignQuestLoader.routed_dialogue_titles()


func faction_ids() -> Array[String]:
	var lookup: Dictionary = {}
	if not _enabled:
		return []
	for faction_value: Variant in Reputation.all_standings().keys():
		lookup[str(faction_value)] = true
	for row: Dictionary in NpcRoster.all():
		var faction_id: String = str(row.get("faction_id", ""))
		if not faction_id.is_empty():
			lookup[faction_id] = true
	for quest: DomSideQuest in QuestRegistry.DOM_SIDE_QUESTS:
		for faction_id: String in quest.outcome_faction_ids:
			if not faction_id.is_empty():
				lookup[faction_id] = true
	for quest: DomSideQuest in QuestRegistry.runtime_quests():
		for faction_id: String in quest.outcome_faction_ids:
			if not faction_id.is_empty():
				lookup[faction_id] = true
	var result: Array[String] = []
	for faction_value: Variant in lookup.keys():
		result.append(str(faction_value))
	result.sort()
	return result


func _load_and_register(
	package_path: String,
	force: bool = false,
	authorized_conflict_identities: Array[String] = []
) -> Dictionary:
	var loaded: Dictionary = CampaignQuestLoader.load_package(package_path, false)
	loaded["registered"] = false
	loaded["registration_conflicts"] = []
	var errors: Array = loaded.get("errors", [])
	if not errors.is_empty():
		return loaded
	var conflicts: Array[Dictionary] = _runtime_progress_conflicts()
	if (
		not conflicts.is_empty()
		and (not force or _has_unauthorized_conflict(conflicts, authorized_conflict_identities))
	):
		loaded["registration_conflicts"] = conflicts
		return loaded
	var quests: Array[DomSideQuest] = []
	quests.assign(loaded.get("quests", []))
	if not QuestRegistry.register_runtime_quests(quests):
		errors.append({
			"file": package_path,
			"field": "quests",
			"expected": "runtime quests with unique reserved ids",
			"code": "runtime_registration_failed",
			"message": "QuestRegistry refused the validated runtime quest set.",
		})
		loaded["errors"] = errors
		return loaded
	_registered_rows = _quest_rows(quests)
	loaded["registered"] = true
	return loaded


func _has_unauthorized_conflict(
	conflicts: Array[Dictionary], authorized_conflict_identities: Array[String]
) -> bool:
	var authorized: Dictionary = {}
	for identity: String in authorized_conflict_identities:
		authorized[identity] = true
	for conflict: Dictionary in conflicts:
		var identity: String = str(conflict.get("identity", ""))
		if not authorized.has(identity):
			return true
	return false


func _runtime_progress_conflicts() -> Array[Dictionary]:
	var conflicts: Array[Dictionary] = []
	for quest: DomSideQuest in QuestRegistry.runtime_quests():
		var state: String = ""
		if QuestRegistry.is_done(quest):
			state = "completed"
		elif QuestRegistry.is_active(quest):
			state = "active"
		if state.is_empty():
			continue
		conflicts.append({
			"identity": quest.stable_id,
			"name": quest.quest_name,
			"state": state,
		})
	return conflicts


func _quest_rows(quest_values: Array) -> Array[Dictionary]:
	var rows: Array[Dictionary] = []
	for quest_value: Variant in quest_values:
		if not quest_value is DomSideQuest:
			continue
		var quest: DomSideQuest = quest_value as DomSideQuest
		rows.append({
			"identity": quest.stable_id,
			"runtime_id": quest.id,
			"name": quest.quest_name,
			"giver_actor_id": quest.giver_actor_id,
			"dialogue_title": quest.dialogue_title,
			"outcome_count": quest.outcome_ids.size(),
		})
	return rows


func _quest_documents(package_path: String, quests: Array[Dictionary]) -> Array[Dictionary]:
	var documents: Array[Dictionary] = []
	var quest_directory: String = package_path.path_join("quests")
	for index: int in quests.size():
		var quest: Dictionary = quests[index]
		var quest_id: String = str(quest.get("quest_id", ""))
		var file_name: String = "draft-%d.json" % index
		if _campaign_id_is_safe(quest_id):
			file_name = quest_id + ".json"
		documents.append({
			"file": quest_directory.path_join(file_name),
			"data": quest,
		})
	return documents


func _replace_package_files(
	package_path: String, quest_directory: String, serialized_files: Dictionary
) -> Dictionary:
	var desired_paths: Dictionary = {}
	var target_paths: Array[String] = []
	for target_value: Variant in serialized_files.keys():
		var target_path: String = str(target_value)
		desired_paths[target_path] = true
		target_paths.append(target_path)
	target_paths.sort()

	var stale_paths: Array[String] = []
	for existing_path: String in _quest_json_files(quest_directory):
		if not desired_paths.has(existing_path):
			stale_paths.append(existing_path)

	var temp_paths: Array[String] = []
	for target_path: String in target_paths:
		if not _path_is_inside_package(package_path, target_path):
			_cleanup_files(temp_paths)
			return _transaction_failure(
				target_path, "Refusing to write a package file outside the campaign package."
			)
		var parent_path: String = target_path.get_base_dir()
		var make_parent_error: Error = DirAccess.make_dir_recursive_absolute(
			ProjectSettings.globalize_path(parent_path)
		)
		if make_parent_error != OK and make_parent_error != ERR_ALREADY_EXISTS:
			_cleanup_files(temp_paths)
			return _transaction_failure(
				parent_path, "Could not create a package file directory before saving."
			)
		var temp_path: String = target_path + ".tmp"
		temp_paths.append(temp_path)
		if FileAccess.file_exists(temp_path):
			var remove_temp_error: Error = DirAccess.remove_absolute(
				ProjectSettings.globalize_path(temp_path)
			)
			if remove_temp_error != OK:
				_cleanup_files(temp_paths)
				return _transaction_failure(
					temp_path, "Could not remove an earlier staged file before saving."
				)
		if not _write_text(temp_path, str(serialized_files[target_path])):
			_cleanup_files(temp_paths)
			return _transaction_failure(
				temp_path, "Could not write the staged package file for '%s'." % target_path
			)

	var protected_paths: Array[String] = []
	for target_path: String in target_paths:
		if FileAccess.file_exists(target_path):
			protected_paths.append(target_path)
	protected_paths.append_array(stale_paths)
	protected_paths.sort()
	for protected_path: String in protected_paths:
		var backup_path: String = protected_path + ".bak"
		if FileAccess.file_exists(backup_path):
			var remove_backup_error: Error = DirAccess.remove_absolute(
				ProjectSettings.globalize_path(backup_path)
			)
			if remove_backup_error != OK:
				_cleanup_files(temp_paths)
				return _transaction_failure(
					backup_path, "Could not replace the previous package backup."
				)

	var moved_backups: Array[String] = []
	for protected_path: String in protected_paths:
		var backup_error: Error = DirAccess.rename_absolute(
			ProjectSettings.globalize_path(protected_path),
			ProjectSettings.globalize_path(protected_path + ".bak")
		)
		if backup_error != OK:
			var backups_restored: bool = _restore_backups(moved_backups)
			_cleanup_files(temp_paths)
			var backup_message: String = "Could not protect '%s' before replacing the package." % protected_path
			if not backups_restored:
				backup_message += " Restoring an earlier package file also failed."
			return _transaction_failure(protected_path, backup_message)
		moved_backups.append(protected_path)

	var promoted_paths: Array[String] = []
	for target_path: String in target_paths:
		var promote_error: Error = DirAccess.rename_absolute(
			ProjectSettings.globalize_path(target_path + ".tmp"),
			ProjectSettings.globalize_path(target_path)
		)
		if promote_error != OK:
			var package_restored: bool = _rollback_package(promoted_paths, moved_backups)
			_cleanup_files(temp_paths)
			var promote_message: String = "Could not promote the staged file for '%s'." % target_path
			if not package_restored:
				promote_message += " Restoring the previous package also failed."
			return _transaction_failure(target_path, promote_message)
		promoted_paths.append(target_path)

	return {"ok": true, "package_path": package_path}


func _rollback_package(promoted_paths: Array[String], moved_backups: Array[String]) -> bool:
	var restored: bool = true
	for index: int in range(promoted_paths.size() - 1, -1, -1):
		var promoted_path: String = promoted_paths[index]
		var remove_error: Error = DirAccess.remove_absolute(
			ProjectSettings.globalize_path(promoted_path)
		)
		if remove_error != OK:
			restored = false
	if not _restore_backups(moved_backups):
		restored = false
	return restored


func _restore_backups(moved_backups: Array[String]) -> bool:
	var restored: bool = true
	for index: int in range(moved_backups.size() - 1, -1, -1):
		var original_path: String = moved_backups[index]
		var restore_error: Error = DirAccess.rename_absolute(
			ProjectSettings.globalize_path(original_path + ".bak"),
			ProjectSettings.globalize_path(original_path)
		)
		if restore_error != OK:
			restored = false
	return restored


func _cleanup_files(file_paths: Array[String]) -> void:
	for file_path: String in file_paths:
		if FileAccess.file_exists(file_path):
			DirAccess.remove_absolute(ProjectSettings.globalize_path(file_path))


func _package_json_files(package_path: String) -> Array[String]:
	var files: Array[String] = []
	var campaign_path: String = package_path.path_join("campaign.json")
	if FileAccess.file_exists(campaign_path):
		files.append(campaign_path)
	var quest_directory: String = package_path.path_join("quests")
	if not DirAccess.dir_exists_absolute(ProjectSettings.globalize_path(quest_directory)):
		return files
	files.append_array(_quest_json_files(quest_directory))
	return files


static func _quest_json_files(directory_path: String) -> Array[String]:
	var result: Array[String] = []
	var directory: DirAccess = DirAccess.open(directory_path)
	if directory == null:
		return result
	var file_names: PackedStringArray = directory.get_files()
	file_names.sort()
	for file_name: String in file_names:
		if not directory.is_link(file_name) and file_name.get_extension().to_lower() == "json":
			result.append(directory_path.path_join(file_name))
	var directory_names: PackedStringArray = directory.get_directories()
	directory_names.sort()
	for directory_name: String in directory_names:
		if not directory.is_link(directory_name):
			result.append_array(_quest_json_files(directory_path.path_join(directory_name)))
	return result


static func _path_is_inside_package(package_path: String, target_path: String) -> bool:
	var absolute_package: String = ProjectSettings.globalize_path(package_path).replace(
		"\\", "/"
	).simplify_path().trim_suffix("/")
	var absolute_target: String = ProjectSettings.globalize_path(target_path).replace(
		"\\", "/"
	).simplify_path()
	return absolute_target.begins_with(absolute_package + "/")


func _write_failure(
	base_result: Dictionary, package_path: String, file_path: String, message: String
) -> Dictionary:
	var result: Dictionary = base_result.duplicate(true)
	var errors: Array = result.get("errors", [])
	errors.append({
		"file": file_path,
		"field": "$",
		"expected": "writable runtime package file",
		"code": "quest_editor_write_failed",
		"message": message,
	})
	result["errors"] = errors
	result["saved"] = false
	result["written_files"] = _package_json_files(package_path)
	return result


static func _transaction_failure(file_path: String, message: String) -> Dictionary:
	return {"ok": false, "file": file_path, "message": message}


func _refresh_activation() -> void:
	if not is_inside_tree():
		return
	var should_enable: bool = OS.is_debug_build() and (
		OS.get_environment(ENVIRONMENT_VARIABLE) == "1" or force_enabled_for_tests
	)
	if should_enable == _enabled:
		return
	_enabled = should_enable
	set_process_unhandled_key_input(_enabled)
	if not _enabled:
		_shutdown()


func _shutdown() -> void:
	_close_overlay()
	_registered_rows.clear()


func _close_overlay() -> void:
	if _overlay_layer == null:
		return
	var layer: CanvasLayer = _overlay_layer
	_overlay_layer = null
	remove_child(layer)
	layer.queue_free()


static func _campaign_id_is_safe(campaign_id: String) -> bool:
	return (
		StableIds.is_valid(StableIds.QUEST, campaign_id)
		and not campaign_id.contains("/")
		and not campaign_id.contains("\\")
	)


func _package_path(campaign_id: String) -> String:
	return _campaigns_root().path_join(campaign_id)


func _campaigns_root() -> String:
	if (
		force_enabled_for_tests
		and campaigns_root_for_tests.begins_with("user://")
		and not campaigns_root_for_tests.contains("\\")
		and not campaigns_root_for_tests.contains("..")
	):
		return campaigns_root_for_tests.trim_suffix("/")
	return CAMPAIGNS_ROOT


static func _read_json_object(file_path: String) -> Dictionary:
	if not FileAccess.file_exists(file_path):
		return {}
	var parsed: Variant = JSON.parse_string(FileAccess.get_file_as_string(file_path))
	return (parsed as Dictionary).duplicate(true) if parsed is Dictionary else {}


static func _write_text(file_path: String, text: String) -> bool:
	var file: FileAccess = FileAccess.open(file_path, FileAccess.WRITE)
	if file == null:
		return false
	file.store_string(text)
	var write_error: Error = file.get_error()
	file.close()
	return write_error == OK
