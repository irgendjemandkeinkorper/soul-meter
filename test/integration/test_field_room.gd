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

	# Find the slot grid inside the screen to verify items are visible
	var item_grid: GridContainer = _find_child_by_type(inventory_screen, "GridContainer")
	assert_object(item_grid).is_not_null()

	# Assert that all 6 starting items are visible as 64px inventory slots.
	assert_int(item_grid.get_child_count()).is_equal(6)
	assert_bool((item_grid.get_child(0) as Button).has_focus()).is_true()

	# Verify specific item names through each slot's full tooltip.
	var expected_titles := [
		"Taubstummer Axe",
		"Captured Reflection",
		"Soul Gauge",
		"Loam Bread  ×5",
		"Cinder-Ink Vial  ×2",
		"QUINE Shard"
	]

	for i in range(6):
		var slot: Button = item_grid.get_child(i)
		assert_str(slot.tooltip_text).is_equal(expected_titles[i])

	assert_str((item_grid.get_child(3) as Button).text).contains("×5")
	assert_str((item_grid.get_child(4) as Button).text).contains("×2")

	# Programmatically close the screen
	UIManager.back()
	await runner.simulate_frames(10)

	# Assert that it is closed
	assert_bool(UIManager.is_open()).is_false()


func _find_child_by_type(parent: Node, type_name: String) -> Node:
	for child in parent.get_children():
		if child.get_class() == type_name:
			return child
		var res := _find_child_by_type(child, type_name)
		if res != null:
			return res
	return null
