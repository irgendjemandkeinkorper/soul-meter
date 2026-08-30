extends GdUnitTestSuite
## Integration tests for world/test_room.tscn using gdUnit4's SceneRunner: it
## simulates real input events and steps real physics frames, so these tests
## exercise the actual scene the player sees instead of calling gameplay code
## directly. See docs/testing.md ("Automated tests") for when to reach for
## this vs. a plain unit test suite like test/unit/test_reputation.gd.

func test_wave_aa_dressing_contract() -> void:
	var field_room: Node = auto_free(
		(load("res://world/test_room.tscn") as PackedScene).instantiate()
	)
	add_child(field_room)
	await get_tree().process_frame

	assert_bool((field_room as Node2D).y_sort_enabled) \
		.override_failure_message("TestRoom root must y-sort actors with props.") \
		.is_true()
	var dressing := field_room.get_node_or_null("FieldRoomDressing")
	assert_object(dressing).is_not_null()
	if dressing == null:
		return
	assert_int(dressing.get_child_count()) \
		.override_failure_message("FieldRoomDressing must contain exactly the three contract layers.") \
		.is_equal(3)
	for layer_name: String in ["GroundDetails", "SoftDetails", "SolidProps"]:
		var layer := dressing.get_node_or_null(layer_name)
		assert_object(layer) \
			.override_failure_message("FieldRoomDressing must keep the %s layer." % layer_name) \
			.is_not_null()
		if layer != null:
			assert_int(layer.get_child_count()).is_greater_equal(1)
	assert_int((dressing.get_node("GroundDetails") as Node2D).z_index).is_equal(-2)
	assert_bool((dressing.get_node("SoftDetails") as Node2D).y_sort_enabled).is_true()
	assert_bool((dressing.get_node("SolidProps") as Node2D).y_sort_enabled).is_true()

	var solid_props := dressing.get_node_or_null("SolidProps")
	if solid_props != null:
		var bodies_with_shapes := 0
		for prop: Node in solid_props.get_children():
			if prop is StaticBody2D and prop.get_node_or_null("CollisionShape2D") != null:
				bodies_with_shapes += 1
		assert_int(bodies_with_shapes).is_greater_equal(3)

	var breathing: Array[Node] = []
	_collect_breathing(dressing, breathing)
	assert_int(breathing.size()) \
		.override_failure_message("At least one Loamroot prop must run WOUND_BREATH.") \
		.is_greater_equal(1)
	if breathing.is_empty():
		return
	var bloom := breathing[0] as Sprite2D
	var base_modulate := bloom.modulate
	var moved := false
	for _frame: int in range(240):
		await get_tree().process_frame
		if bloom.modulate != base_modulate:
			moved = true
			break
	assert_bool(moved) \
		.override_failure_message("WOUND_BREATH never changed the Loamroot prop modulate.") \
		.is_true()


func test_player_moves_right_when_holding_move_right() -> void:
	var runner := scene_runner("res://world/test_room.tscn")
	var player: Node2D = runner.find_child("Player", true, false)
	var ground := runner.find_child("IsometricGround", true, false) as TileMapLayer
	var followers := runner.find_child("PartyFollowers", true, false) as PartyFollowers
	var start_x: float = player.global_position.x
	var start_cell: Vector2i = ground.local_to_map(ground.to_local(player.global_position))
	var start_center: Vector2 = ground.to_global(ground.map_to_local(start_cell))

	assert_object(followers).is_not_null()
	assert_vector(followers.trail_target_for(0)).is_equal(start_center)

	runner.simulate_action_press("move_right")
	await runner.simulate_frames(30)
	runner.simulate_action_release("move_right")
	# Releasing input completes the in-flight step before coming to rest.
	await runner.simulate_frames(30)

	assert_float(player.global_position.x).is_greater(start_x)
	var resting_cell: Vector2i = ground.local_to_map(ground.to_local(player.global_position))
	var resting_center: Vector2 = ground.to_global(ground.map_to_local(resting_cell))
	assert_vector(player.global_position).is_equal(resting_center)


func test_holding_sprint_moves_the_player_materially_faster() -> void:
	var sample_frames := 8

	var walk_runner := scene_runner("res://world/test_room.tscn")
	var walk_player: CharacterBody2D = walk_runner.find_child("Player", true, false)
	var walk_start_x: float = walk_player.global_position.x
	walk_runner.simulate_action_press("move_right")
	await walk_runner.simulate_frames(sample_frames)
	walk_runner.simulate_action_release("move_right")
	var walk_distance: float = walk_player.global_position.x - walk_start_x
	walk_runner.scene().queue_free()
	await get_tree().process_frame

	var sprint_runner := scene_runner("res://world/test_room.tscn")
	var sprint_player: CharacterBody2D = sprint_runner.find_child("Player", true, false)
	var sprint_start_x: float = sprint_player.global_position.x
	sprint_runner.simulate_action_press("sprint")
	sprint_runner.simulate_action_press("move_right")
	await sprint_runner.simulate_frames(sample_frames)
	sprint_runner.simulate_action_release("move_right")
	sprint_runner.simulate_action_release("sprint")
	var sprint_distance: float = sprint_player.global_position.x - sprint_start_x

	# 2.0x nominal; >=1.5x tolerates headless frame jitter without false greens.
	assert_float(sprint_distance).is_greater(walk_distance * 1.5)


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
	runner.simulate_action_release("move_left")
	# Wave Q: at a physics wall the nav grid doesn't know about, held movement
	# cycles wedge-recovery (advance, stall, snap back to the step origin). How
	# many frames the last cycle needs to settle is machine-speed-dependent
	# (CI flake on 4596ee3: a late snap-back moved an already-captured "settled"
	# position), so wait for observed stability instead of a fixed window.
	var stable_frames := 0
	var last_position: Vector2 = player.global_position
	for _i in 600:
		await get_tree().physics_frame
		if player.global_position.distance_to(last_position) < 0.01:
			stable_frames += 1
			if stable_frames >= 30:
				break
		else:
			stable_frames = 0
			last_position = player.global_position

	# Derive the legal center position from the actual scene colliders instead of
	# baking in dimensions that change when the blockout or player art changes.
	var wall_face_x := left_wall.global_position.x + wall_shape.size.x / 2.0
	var player_half_width := player_rect.size.x / 2.0
	var legal_min_x := wall_face_x + player_half_width
	# The wall is never clipped through — including by wedge-recovery snaps.
	assert_float(player.global_position.x).is_greater_equal(legal_min_x - 1.0)
	# And the player comes to a genuine rest instead of jittering forever.
	var settled_position: Vector2 = player.global_position
	await runner.simulate_frames(30)
	assert_vector(player.global_position).is_equal(settled_position)


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


func _collect_breathing(node: Node, found: Array[Node]) -> void:
	var script := node.get_script() as GDScript
	if node is Sprite2D and script != null \
			and script.resource_path.ends_with("ambient_prop_motion.gd") \
			and int(node.get("motion_kind")) == AmbientPropMotion.MotionKind.WOUND_BREATH:
		found.append(node)
	for child: Node in node.get_children():
		_collect_breathing(child, found)


func test_wedged_keyboard_step_recovers_to_the_origin_cell_center() -> void:
	var runner := scene_runner("res://world/test_room.tscn")
	var player := runner.find_child("Player", true, false) as Node2D
	var ground := runner.find_child("IsometricGround", true, false) as TileMapLayer
	# Let the deferred rest_on_grid normalization land before sampling the origin.
	await runner.simulate_frames(3)
	var origin_cell: Vector2i = ground.local_to_map(ground.to_local(player.global_position))
	var origin_center: Vector2 = ground.to_global(ground.map_to_local(origin_cell))

	# A physics-only obstacle the nav grid knows nothing about (not painted, not a
	# nav_blocker): resolve_step_cell will approve the step, then collision holds
	# the body short of the target center — the wedge the recovery exists for.
	var wall := StaticBody2D.new()
	var shape := CollisionShape2D.new()
	var rectangle := RectangleShape2D.new()
	rectangle.size = Vector2(16.0, 220.0)
	shape.shape = rectangle
	wall.add_child(shape)
	wall.global_position = origin_center + Vector2(28.0, 0.0)
	runner.scene().add_child(wall)
	await runner.simulate_frames(1)

	runner.simulate_action_press("move_right")
	await runner.simulate_frames(90)
	runner.simulate_action_release("move_right")
	# Any in-flight wedge cycle needs one stuck-threshold window to recover.
	await runner.simulate_frames(60)

	assert_bool(bool(player.get("_has_keyboard_step_target"))).is_false()
	assert_vector(player.global_position).is_equal(origin_center)
	wall.queue_free()


func test_rest_on_grid_never_normalizes_through_a_physics_only_wall() -> void:
	var runner := scene_runner("res://world/test_room.tscn")
	var player := runner.find_child("Player", true, false) as Node2D
	var ground := runner.find_child("IsometricGround", true, false) as TileMapLayer
	await runner.simulate_frames(3)
	var cell: Vector2i = ground.local_to_map(ground.to_local(player.global_position))
	var center: Vector2 = ground.to_global(ground.map_to_local(cell))

	# A thin physics-only wall between an off-center stored position and its
	# nearest cell center — the grid believes the center is open.
	var stored_position: Vector2 = center + Vector2(-24.0, 0.0)
	var wall := StaticBody2D.new()
	var shape := CollisionShape2D.new()
	var rectangle := RectangleShape2D.new()
	rectangle.size = Vector2(6.0, 120.0)
	shape.shape = rectangle
	wall.add_child(shape)
	wall.global_position = center + Vector2(-12.0, 0.0)
	runner.scene().add_child(wall)
	await runner.simulate_frames(1)
	player.global_position = stored_position

	player.call("rest_on_grid")

	# The stored legal position wins over normalizing across the wall.
	assert_vector(player.global_position).is_equal(stored_position)
	wall.queue_free()


func test_keyboard_steps_are_bounded_but_can_always_re_enter_bounds() -> void:
	var runner := scene_runner("res://world/test_room.tscn")
	var player := runner.find_child("Player", true, false) as Node2D
	await runner.simulate_frames(3)

	# Strand the player far outside both the camera bounds and the painted map's
	# world extent — the void that lattice-open movement could previously walk
	# into forever through a boundary-collider gap.
	player.global_position = Vector2(12000.0, 600.0)
	await runner.simulate_frames(2)
	var stranded_position: Vector2 = player.global_position

	# Deeper into the void: refused, the player does not move.
	runner.simulate_action_press("move_right")
	await runner.simulate_frames(40)
	runner.simulate_action_release("move_right")
	await runner.simulate_frames(10)
	assert_vector(player.global_position).is_equal(stranded_position)

	# Back toward bounds: the escape valve allows strictly-approaching steps, so
	# an out-of-bounds body is never permanently stranded.
	runner.simulate_action_press("move_left")
	await runner.simulate_frames(40)
	runner.simulate_action_release("move_left")
	await runner.simulate_frames(30)
	assert_float(player.global_position.x).is_less(stranded_position.x)
