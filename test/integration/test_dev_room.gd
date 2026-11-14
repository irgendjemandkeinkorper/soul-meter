extends GdUnitTestSuite
## Real title -> SceneLoader -> field -> pause/title, plus editable fixture behavior.

const Bootstrap := preload("res://dev/dev_room_bootstrap.gd")
const Preset := preload("res://dev/dev_room_preset.gd")
const ROOM := "res://dev/dev_room.tscn"
const TITLE := "StateChart/Root/Menus/Title"
const ACTIVE := "StateChart/Root/Playing/Active"

var _snapshot: Dictionary
var _original_scene: Node
var _target_before: String
var _spawn_before: StringName
var _pending_before: String
var _save_paths_before: Array[String]


func before_test() -> void:
	_snapshot = SaveGame.capture_runtime_state()
	_original_scene = get_tree().current_scene
	_target_before = GameFlow._target_scene
	_spawn_before = SaveGame.pending_spawn_id
	_pending_before = SaveGame._pending_autosave_reason
	_save_paths_before = [SaveGame.save_path, SaveGame.temp_path, SaveGame.backup_path]
	SaveGame.save_path = "user://dev-room-test-%d.save" % Time.get_ticks_usec()
	SaveGame.temp_path = SaveGame.save_path + ".tmp"
	SaveGame.backup_path = SaveGame.save_path + ".bak"
	# SceneLoader owns current_scene; preserve the test runner outside that slot.
	get_tree().current_scene = null
	await _return_to_title()
	GameFlow._on_title_entered()
	assert_bool(await _wait_for_scene(GameFlow.MAIN_MENU_SCENE)).is_true()


func after_test() -> void:
	UIManager.close_all()
	await _return_to_title()
	await _wait_for_scene(GameFlow.MAIN_MENU_SCENE)
	var loaded_scene := get_tree().current_scene
	get_tree().current_scene = _original_scene if is_instance_valid(_original_scene) else null
	if is_instance_valid(loaded_scene) and loaded_scene != _original_scene:
		loaded_scene.queue_free()
	SaveGame.restore_runtime_state(_snapshot)
	SaveGame.pending_spawn_id = _spawn_before
	SaveGame._pending_autosave_reason = _pending_before
	for path: String in _save_hashes():
		if FileAccess.file_exists(path):
			DirAccess.remove_absolute(ProjectSettings.globalize_path(path))
	SaveGame.save_path = _save_paths_before[0]
	SaveGame.temp_path = _save_paths_before[1]
	SaveGame.backup_path = _save_paths_before[2]
	GameFlow._target_scene = _target_before
	GameFlow._restore_travel_plan()
	await get_tree().process_frame


func test_title_launch_showcases_travel_and_return() -> void:
	var menu := get_tree().current_scene
	var button := menu.find_child("DevRoomButton", true, false) as Button
	assert_object(button).is_not_null()
	if button == null:
		return
	assert_str(button.text).is_equal("DEV ROOM")
	await _capture("01-title")
	assert_bool(SaveGame.save()).is_true()
	for slot: int in range(1, SaveGame.MANUAL_SLOT_COUNT + 1):
		assert_bool(SaveGame.save_to_slot(slot)).is_true()
	var saves_before := _save_hashes()
	var before := SaveGame.capture_runtime_state()
	button.pressed.emit()
	assert_bool(await _wait_for_scene(ROOM)).is_true()
	assert_bool(bool(GameFlow.get_node(ACTIVE).get("active"))).is_true()
	var preset: Resource = load(Bootstrap.PRESET_PATH)
	assert_str(GameState.protagonist().display_name).is_equal(preset.display_name)
	assert_int(GameState.party.size()).is_equal(1 + preset.companion_ids.size())
	assert_int(GameState.gp).is_equal(int(preset.silver))
	for item_id: String in preset.items:
		assert_int(GameState.item_count(item_id)).is_equal(int(preset.items[item_id]))
	assert_bool(GameState.has_created_character()).is_true()
	assert_bool(SaveGame.runtime_sandbox_is_armed()).is_true()
	assert_bool(SaveGame.save()).is_false()
	for slot: int in range(1, SaveGame.MANUAL_SLOT_COUNT + 1):
		assert_bool(SaveGame.save_to_slot(slot)).is_false()
	assert_dict(_save_hashes()).is_equal(saves_before)
	var room := get_tree().current_scene
	var field := room.get_node("FieldMap") as FieldMap
	assert_object(field.iso_grid()).is_not_null()
	assert_bool(field.no_combat_zone()).is_false()
	await _capture("02-room")
	_check_showcases(room)
	# Open actual panels through the field input handlers, then close normally.
	var vendor := room.get_node("Vendor") as SMInteractable
	vendor._player_in_range = true
	vendor._unhandled_input(_interact())
	assert_bool(_has_screen("res://ui/screens/shop.tscn")).is_true()
	await _capture("03-shop")
	UIManager.close_all()
	var chest := room.get_node("LootChest") as Chest
	chest._player_in_range = true
	chest._unhandled_input(_interact())
	assert_bool(_has_screen("res://ui/screens/loot_panel/loot_panel.tscn")).is_true()
	UIManager.close_all()
	var trigger := room.get_node("CombatTrigger") as SMInteractable
	trigger._player_in_range = true
	trigger._unhandled_input(_interact())
	assert_str(String(Battle.encounter_id)).is_equal("bog-wight")
	assert_bool(Battle.session_active).is_true()
	assert_object(Battle._current_field_map()).is_same(field)
	for _step: int in range(3):
		GameFlow.send_event("deployment_next")
	GameFlow.send_event("accept_slate")
	await get_tree().process_frame
	assert_bool(bool(GameFlow.get_node("StateChart/Root/Playing/Battle").get("active"))).is_true()
	assert_bool(field.combat_mode_active()).is_true()
	assert_object(get_tree().current_scene).is_same(room)
	await _capture("04-combat")
	Battle._finish(BattleResult.State.FLED, &"fled")
	GameFlow.send_event("battle_end")
	await get_tree().process_frame
	# Walk-over exit uses the existing TravelExit -> GameFlow.travel -> SceneLoader path.
	(room.get_node("DoorBoard/Dom") as TravelExit)._on_body_entered(field.player())
	assert_bool(await _wait_for_scene(GameFlow.TOWN_SCENE)).is_true()
	assert_bool(SaveGame.runtime_sandbox_is_armed()).is_true()
	SaveGame.request_autosave("dev-room-arrival-test")
	assert_bool(SaveGame.flush_pending_autosave()).is_false()
	assert_bool(SaveGame.save_to_slot(1)).is_false()
	assert_dict(_save_hashes()).is_equal(saves_before)
	GameFlow.send_event("pause")
	await get_tree().process_frame
	assert_bool(get_tree().paused).is_true()
	assert_bool(_has_screen("res://ui/screens/pause_menu.tscn")).is_true()
	GameFlow.send_event("to_main_menu")
	assert_bool(await _wait_for_scene(GameFlow.MAIN_MENU_SCENE)).is_true()
	assert_bool(get_tree().paused).is_false()
	assert_bool(SaveGame.runtime_sandbox_is_armed()).is_false()
	assert_object(LocationRegistry.by_id(&"dev-room")).is_null()
	assert_dict(SaveGame.capture_runtime_state()).is_equal(before)


func test_editable_preset_uses_public_progression_and_stack_limits() -> void:
	var preset := Preset.new()
	preset.companion_ids = PackedStringArray(["ressa-quickfingers"])
	preset.items = {ItemIds.CONSUMABLES_BITTERLEAF_POULTICE: 12}
	preset.silver = 731
	preset.level = 3
	preset.xp = 17
	preset.soul = 65.0
	preset.flags = PackedStringArray(["dev-preset-example"])
	var session: Node = auto_free(Bootstrap.new())
	assert_bool(session.begin(ROOM, preset)).is_true()
	assert_int(GameState.party.size()).is_equal(2)
	assert_str(GameState.party[1].id).is_equal("ressa-quickfingers")
	assert_int(GameState.protagonist().level).is_equal(3)
	assert_int(GameState.protagonist().xp).is_equal(17)
	assert_int(GameState.gp).is_equal(731)
	assert_float(GameState.soul_meter).is_equal(65.0)
	assert_bool(GameState.flag_is_true("dev-preset-example")).is_true()
	assert_int(GameState.item_count(ItemIds.CONSUMABLES_BITTERLEAF_POULTICE)).is_equal(12)
	for item: InventoryItem in GameState.inventory.get_items():
		assert_int(item.get_stack_size()).is_less_equal(item.get_max_stack_size())
	session.finish()
	# Refusal happens before the state/sandbox changes.
	var before := SaveGame.capture_runtime_state()
	preset.items = {"missing/item": 1}
	assert_str(preset.validation_error()).is_not_empty()
	assert_bool(SaveGame.runtime_sandbox_is_armed()).is_false()
	assert_dict(SaveGame.capture_runtime_state()).is_equal(before)


func test_quit_to_title_from_paused_combat_discards_the_session() -> void:
	GameFlow.send_event("dev_room")
	assert_bool(await _wait_for_scene(ROOM)).is_true()
	var room := get_tree().current_scene
	var trigger := room.get_node("CombatTrigger") as SMInteractable
	trigger._apply_interaction()
	for _step: int in range(3):
		GameFlow.send_event("deployment_next")
	GameFlow.send_event("accept_slate")
	await get_tree().process_frame
	GameFlow.send_event("pause")
	await get_tree().process_frame
	assert_bool(Battle.session_active).is_true()
	GameFlow.send_event("to_main_menu")
	assert_bool(await _wait_for_scene(GameFlow.MAIN_MENU_SCENE)).is_true()
	assert_bool(Battle.session_active).is_false()
	assert_object(Battle.controller).is_null()
	assert_bool(SaveGame.runtime_sandbox_is_armed()).is_false()


func _check_showcases(room: Node) -> void:
	var lock := room.get_node("LockedChest") as Chest
	assert_bool(DramgidSchema.is_skill(lock.lock_skill)).is_true()
	assert_str(lock.container_id).starts_with("dev-")
	_seed_success()
	assert_bool(lock.attempt_skill_lock().get("success", false)).is_true()
	var loot := room.get_node("LootChest") as Chest
	assert_bool(LootTableRegistry.has_table(loot.loot_table_id)).is_true()
	assert_str(loot.container_id).starts_with("dev-")
	assert_array(GameState.loot_container_contents(loot.container_id)).is_not_empty()
	var pocket := room.get_node("PocketNPC") as NPC
	assert_bool(pocket.has_pocket()).is_true()
	assert_bool(pocket.attempt_pickpocket([1]).get("success", false)).is_true()
	var object := room.get_node("SkillObject") as SMInteractable
	assert_bool(DramgidSchema.is_skill(object.lock_skill)).is_true()
	_seed_success()
	assert_bool(object.attempt_skill_lock().get("success", false)).is_true()
	object._player_in_range = true
	object._unhandled_input(_interact())
	assert_bool(GameState.flag_is_true(object.interaction_flag)).is_true()
	assert_str((room.get_node("Vendor") as SMInteractable).shop_type).is_equal("equipment")
	var trigger: Node = room.get_node("CombatTrigger")
	assert_dict(EncounterCatalog.definition(trigger.encounter_id)).is_not_empty()
	var doors := room.get_node("DoorBoard")
	assert_int(doors.get_child_count()).is_equal(8)
	for door: TravelExit in doors.get_children():
		assert_bool(LocationRegistry.is_gameplay_scene(door.target_scene)).is_true()
		assert_bool(ResourceLoader.exists(door.target_scene)).is_true()


func _interact() -> InputEventAction:
	var event := InputEventAction.new()
	event.action = &"interact"
	event.pressed = true
	return event


func _seed_success() -> void:
	var rng := RandomNumberGenerator.new()
	for seed_value: int in range(10000):
		rng.seed = seed_value
		if rng.randi_range(1, 100) == 1:
			SkillCheck.random_number_generator.seed = seed_value
			return


func _save_hashes() -> Dictionary:
	var result := {}
	var paths: Array[String] = [SaveGame.save_path, SaveGame.temp_path, SaveGame.backup_path]
	for slot: int in range(1, SaveGame.MANUAL_SLOT_COUNT + 1):
		var path := SaveGame.manual_slot_path(slot)
		paths.append_array([path, path + ".tmp", path + ".bak"])
	for path: String in paths:
		result[path] = FileAccess.get_sha256(path) if FileAccess.file_exists(path) else "absent"
	return result


func _has_screen(path: String) -> bool:
	for child: Node in UIManager.get_children():
		if child.scene_file_path == path:
			return true
	return false


func _wait_for_scene(path: String) -> bool:
	var deadline := Time.get_ticks_msec() + 20000
	while Time.get_ticks_msec() < deadline:
		var scene := get_tree().current_scene
		if scene != null and scene.scene_file_path == path and not GameFlow._waiting_for_level:
			await get_tree().process_frame
			return true
		await get_tree().process_frame
	return false


func _return_to_title() -> void:
	UIManager.close_all()
	if bool(GameFlow.get_node(TITLE).get("active")):
		return
	GameFlow.send_event("level_ready")
	GameFlow.send_event("pause")
	await get_tree().process_frame
	GameFlow.send_event("to_main_menu")
	await get_tree().process_frame


func _capture(file_name: String) -> void:
	var directory := OS.get_environment("SOUL_METER_DEV_CAPTURE_DIR")
	if directory.is_empty() or DisplayServer.get_name() == "headless":
		return
	await RenderingServer.frame_post_draw
	var screenshot := get_viewport().get_texture().get_image()
	assert_int(screenshot.save_png(directory.path_join(file_name + ".png"))).is_equal(OK)
