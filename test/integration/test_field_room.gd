extends GdUnitTestSuite
## Integration tests for world/test_room.tscn using gdUnit4's SceneRunner: it
## simulates real input events and steps real physics frames, so these tests
## exercise the actual scene the player sees instead of calling gameplay code
## directly. See docs/testing.md ("Automated tests") for when to reach for
## this vs. a plain unit test suite like test/unit/test_reputation.gd.

func test_player_moves_right_when_holding_move_right() -> void:
	var runner := scene_runner("res://world/test_room.tscn")
	var player: Node2D = runner.find_child("Player", true, false)
	var start_x: float = player.global_position.x

	runner.simulate_action_press("move_right")
	await runner.simulate_frames(30)
	runner.simulate_action_release("move_right")

	assert_float(player.global_position.x).is_greater(start_x)


func test_player_stops_at_the_left_wall() -> void:
	var runner := scene_runner("res://world/test_room.tscn")
	var player: Node2D = runner.find_child("Player", true, false)
	var player_shape := player.find_child("CollisionShape2D", true, false) as CollisionShape2D
	var left_wall := runner.find_child("ColLeft", true, false) as CollisionShape2D
	var wall_shape := left_wall.shape as RectangleShape2D
	var player_rect := player_shape.shape as RectangleShape2D

	runner.simulate_action_press("move_left")
	# Long enough to reach the wall from the scene's starting position.
	await runner.simulate_frames(2000)
	var at_boundary := player.global_position.x
	await runner.simulate_frames(30)
	runner.simulate_action_release("move_left")

	# Derive the legal center position from the actual scene colliders instead of
	# baking in dimensions that change when the blockout or player art changes.
	var wall_face_x := left_wall.global_position.x + wall_shape.size.x / 2.0
	var player_half_width := player_rect.size.x / 2.0
	var legal_min_x := wall_face_x + player_half_width
	assert_float(player.global_position.x).is_greater_equal(legal_min_x - 1.0)
	assert_float(player.global_position.x).is_equal_approx(at_boundary, 1.0)


func test_npc_talk_prompt_only_shows_when_player_is_in_range() -> void:
	var runner := scene_runner("res://world/test_room.tscn")
	var npc: Node2D = runner.find_child("IrisIllepah", true, false)
	var player: Node2D = runner.find_child("Player", true, false)
	## NPC builds this Label in code (Label.new()), so Godot auto-names it
	## "@Label@<id>" rather than "Label" — match with a wildcard.
	var prompt: Label = npc.find_child("@Label@*", true, false)

	assert_bool(prompt.visible).is_false()

	# Iris starts ~380px from the player (out of her 120px talk range) — walk
	# the player over to her and let physics catch the Area2D overlap.
	player.global_position = npc.global_position
	await runner.simulate_frames(20)

	assert_bool(prompt.visible).is_true()


func test_open_inventory_screen() -> void:
	# Load the world/test_room.tscn (the field room scene)
	var runner := scene_runner("res://world/test_room.tscn")
	assert_object(runner).is_not_null()

	# Wait for a few frames to let everything initialize
	await runner.simulate_frames(10)

	# Assert that no screens are initially open
	assert_bool(UIManager.is_open()).is_false()

	# Open the inventory screen programmatically (as UI InputEvents are disabled in headless mode)
	UIManager.open(UIManager.INVENTORY, true)
	await runner.simulate_frames(10)

	# Assert that the inventory screen is now open
	assert_bool(UIManager.is_open()).is_true()

	# Find the inventory screen instance
	var inventory_screen: Node = null
	for child in UIManager.get_children():
		if child.name.to_lower().contains("inventory"):
			inventory_screen = child
			break

	assert_object(inventory_screen).is_not_null()

	# The bag is now a GLoot CtrlInventoryGrid bound directly to GameState.inventory.
	var bag_grid := inventory_screen.find_child("BagGrid", true, false) as CtrlInventoryGrid
	assert_object(bag_grid).is_not_null()
	assert_object(bag_grid.inventory).is_same(GameState.inventory)

	# All 6 starting items are present, with the seeded stack sizes intact.
	var items := GameState.inventory.get_items()
	assert_int(items.size()).is_equal(6)
	var titles: Array[String] = []
	var stacks := {}
	for item in items:
		titles.append(item.get_title())
		stacks[item.get_title()] = item.get_stack_size()
	assert_array(titles).contains_exactly_in_any_order([
		"Taubstummer Axe",
		"Captured Reflection",
		"Soul Gauge",
		"Loam Bread",
		"Cinder-Ink Vial",
		"QUINE Shard",
	])
	assert_int(int(stacks["Loam Bread"])).is_equal(5)
	assert_int(int(stacks["Cinder-Ink Vial"])).is_equal(2)

	# Programmatically close the screen
	UIManager.back()
	# The stack entry is removed immediately, but the node remains during its
	# exit transition so it cannot disappear mid-fade.
	assert_bool(is_instance_valid(inventory_screen)).is_true()
	await runner.simulate_frames(10)

	# Assert that it is closed
	assert_bool(UIManager.is_open()).is_false()


func test_autosave_status_is_visible_without_blocking_field_input() -> void:
	var runner := scene_runner("res://world/test_room.tscn")
	await runner.simulate_frames(10)
	var status := runner.find_child("AutosaveStatus", true, false) as Label
	var player: Node2D = runner.find_child("Player", true, false)
	assert_object(status).is_not_null()
	assert_int(status.focus_mode).is_equal(Control.FOCUS_NONE)
	assert_int(status.mouse_filter).is_equal(Control.MOUSE_FILTER_IGNORE)
	assert_bool(get_tree().paused).is_false()

	SaveGame.autosave_finished.emit("test-success", true)
	assert_str(status.text).is_equal("AUTOSAVED")
	SaveGame.autosave_finished.emit("test-failure", false)
	assert_str(status.text).is_equal("AUTOSAVE FAILED")
	assert_bool(status.text.contains("test-failure")).is_false()
	assert_bool(get_tree().paused).is_false()

	var start_x: float = player.global_position.x
	runner.simulate_action_press("move_right")
	await runner.simulate_frames(15)
	runner.simulate_action_release("move_right")
	assert_float(player.global_position.x).is_greater(start_x)


func test_pause_menu_shows_player_friendly_manual_save_failure() -> void:
	var runner := scene_runner("res://world/test_room.tscn")
	await runner.simulate_frames(10)
	var screen := UIManager.open(GameFlow.PAUSE_MENU, false, true)
	await runner.simulate_frames(5)
	var status := screen.find_child("SaveStatus", true, false) as Label
	assert_object(status).is_not_null()
	assert_str(status.theme_type_variation).is_equal("EyebrowLabel")

	SaveGame.save_failed.emit("Could not open the save file for writing.")
	assert_str(status.text).is_equal(
		"Could not save your progress. Please check your available storage and try again."
	)
	assert_bool(status.text.contains("Could not open")).is_false()

	UIManager.close_all()
	await runner.simulate_frames(5)


func test_pause_menu_confirms_manual_save_success() -> void:
	var original_save_path := SaveGame.save_path
	var original_temp_path := SaveGame.temp_path
	var original_backup_path := SaveGame.backup_path
	SaveGame.save_path = "user://gdunit_save_visibility.save"
	SaveGame.temp_path = "user://gdunit_save_visibility.save.tmp"
	SaveGame.backup_path = "user://gdunit_save_visibility.save.bak"
	_remove_manual_save_test_files()

	var runner := scene_runner("res://world/test_room.tscn")
	await runner.simulate_frames(10)
	var screen := UIManager.open(GameFlow.PAUSE_MENU, false, true)
	await runner.simulate_frames(5)
	var status := screen.find_child("SaveStatus", true, false) as Label
	var slot_button := screen.find_child("ManualSaveSlot1", true, false) as Button
	assert_object(status).is_not_null()
	assert_object(slot_button).is_not_null()

	slot_button.pressed.emit()
	assert_str(status.text).is_equal("Saved to slot 1.")
	var slot_path: String = SaveGame.manual_slot_path(1)
	assert_bool(FileAccess.file_exists(slot_path)).is_true()

	# FR-905: a second save into an occupied slot arms an overwrite confirm first.
	slot_button.pressed.emit()
	assert_str(status.text).is_equal("Slot 1 will be replaced.")
	slot_button.pressed.emit()
	assert_str(status.text).is_equal("Saved to slot 1.")

	UIManager.close_all()
	await runner.simulate_frames(5)
	_remove_manual_save_test_files()
	SaveGame.save_path = original_save_path
	SaveGame.temp_path = original_temp_path
	SaveGame.backup_path = original_backup_path


func _remove_manual_save_test_files() -> void:
	var paths: Array[String] = [SaveGame.save_path, SaveGame.temp_path, SaveGame.backup_path]
	for slot in range(1, SaveGame.MANUAL_SLOT_COUNT + 1):
		var slot_path: String = SaveGame.manual_slot_path(slot)
		paths.append(slot_path)
		paths.append(slot_path + ".tmp")
		paths.append(slot_path + ".bak")
	for path in paths:
		if FileAccess.file_exists(path):
			DirAccess.remove_absolute(ProjectSettings.globalize_path(path))


func _find_child_by_type(parent: Node, type_name: String) -> Node:
	for child in parent.get_children():
		if child.get_class() == type_name:
			return child
		var res := _find_child_by_type(child, type_name)
		if res != null:
			return res
	return null
