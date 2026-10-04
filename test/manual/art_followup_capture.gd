extends GdUnitTestSuite
## Rendered evidence for the populated inventory and the live same-map battle.
## Run explicitly with scripts/test.sh -a test/manual/art_followup_capture.gd.

var _saved_state: Dictionary
var _boot_visible := true


func before_test() -> void:
	_saved_state = GameState.to_dict().duplicate(true)
	get_tree().root.size = Vector2i(1920, 1080)
	DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path("user://qa"))
	var boot := get_tree().current_scene as CanvasItem
	if boot != null:
		_boot_visible = boot.visible
		boot.hide()


func after_test() -> void:
	if Battle.session_active:
		Battle._end_session(null)
	Battle.controller = null
	Battle.ended = true
	Battle._release_field_grid()
	UIManager.close_all()
	GameState.from_dict(_saved_state)
	var boot := get_tree().current_scene as CanvasItem
	if boot != null:
		boot.visible = _boot_visible


func _capture(name: String) -> void:
	var reveal := UIManager.get_node_or_null("RewardReveal") as CanvasItem
	if reveal != null:
		reveal.hide()
	RenderingServer.force_draw()
	await RenderingServer.frame_post_draw
	var image := get_viewport().get_texture().get_image()
	assert_object(image.get_size()).is_equal(Vector2i(1920, 1080))
	assert_int(image.save_png("user://qa/%s.png" % name)).is_equal(OK)
	print("SHOT ", name)


func test_populated_inventory() -> void:
	GameState.inventory.clear()
	GameState.equipped_slots.clear()
	var grid := GameState.inventory.get_constraint(GridConstraint)
	if grid != null:
		grid.free()
	for id: String in [ItemIds.WEAPONS_FORGE_HAMMER, ItemIds.CONSUMABLES_HEARTHLOAF, ItemIds.MATERIALS_LOAMROOT_SPRIG, ItemIds.WEAPONS_TAUBSTUMMER_AXE]:
		GameState.inventory.create_and_add_item(id)
	var runner := scene_runner("res://ui/screens/inventory.tscn")
	var screen := runner.scene() as InventoryScreen
	screen.theme = ThemeBuilder.build()
	await runner.simulate_frames(4)
	screen._on_item_selected(GameState.inventory.get_items()[0])
	await runner.simulate_frames(2)
	await _capture("inventory-followup")


func test_live_field_battle() -> void:
	var runner := scene_runner("res://world/test_room.tscn")
	var root := runner.scene() as Node2D
	await runner.simulate_frames(3)
	var field := root.find_child("FieldMap", true, false) as FieldMap
	var hostile := load("res://actors/hostile/hostile.tscn").instantiate() as Hostile
	hostile.name = "ArtCaptureWight"
	hostile.unit_id = &"bog-wight"
	hostile.alert_radius = 0.0
	root.add_child(hostile)
	hostile.global_position = field.iso_grid().cell_to_world(Vector2i(30, 30))
	hostile.sync_cell()
	var opened := Battle.start_session(field, hostile)
	assert_bool(opened.get("allowed", false)).override_failure_message(str(opened)).is_true()
	# Production presents combat above the field; keep the field's actual camera.
	for layer: Node in root.find_children("*", "CanvasLayer", true, false):
		(layer as CanvasLayer).hide()
	var hud := CanvasLayer.new()
	hud.layer = 10
	root.add_child(hud)
	var screen := load("res://ui/screens/battle.tscn").instantiate() as Screen
	screen.theme = ThemeBuilder.build()
	hud.add_child(screen)
	var camera := field.player().get_node("Camera2D") as Camera2D
	camera.enabled = true
	camera.make_current()
	camera.reset_smoothing()
	await runner.simulate_frames(5)
	assert_object(screen.get("_stage")).is_null()
	assert_object(field.combat_overlay()).is_not_null()
	await _capture("battle-live-followup")
	screen.free()
	Battle._end_session(null)


func test_legacy_field_grid_battle() -> void:
	var runner := scene_runner("res://world/test_room.tscn")
	var root := runner.scene() as Node2D
	await runner.simulate_frames(3)
	Battle.start("trial-warden")
	for layer: Node in root.find_children("*", "CanvasLayer", true, false):
		(layer as CanvasLayer).hide()
	var hud := CanvasLayer.new()
	hud.layer = 10
	root.add_child(hud)
	var screen := load("res://ui/screens/battle.tscn").instantiate() as Screen
	screen.theme = ThemeBuilder.build()
	hud.add_child(screen)
	await runner.simulate_frames(5)
	assert_bool(Battle.session_active).is_false()
	await _capture("battle-grid-followup")
	screen.free()
