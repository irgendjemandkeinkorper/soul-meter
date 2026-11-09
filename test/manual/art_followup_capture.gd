extends GdUnitTestSuite
## Rendered evidence for the populated inventory and the live same-map battle.
## Run explicitly with scripts/test.sh -a test/manual/art_followup_capture.gd.

var _saved_state: Dictionary
var _boot_visible := true
## Canvas items _isolate() hid, restored after each test.
var _hidden: Array[CanvasItem] = []
var _hidden_layers: Array[CanvasLayer] = []


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
	for item: CanvasItem in _hidden:
		if is_instance_valid(item):
			item.show()
	for layer: CanvasLayer in _hidden_layers:
		if is_instance_valid(layer):
			layer.show()
	_hidden.clear()
	_hidden_layers.clear()
	var boot := get_tree().current_scene as CanvasItem
	if boot != null:
		boot.visible = _boot_visible


## The harness leaves the boot menu (and whatever else it mounted) in the tree; production
## frees it on travel. CanvasLayers do not inherit a hidden parent's visibility, so hide
## them too. Shows `target` alone; with `keep`, every layer but `keep` is hidden, the
## target's own layers included (the live-field shot keeps only the field HUD).
func _isolate(target: Node, keep: CanvasLayer = null) -> void:
	for child: Node in get_tree().root.get_children():
		if child == target or child.is_ancestor_of(target):
			continue
		if child is CanvasItem and (child as CanvasItem).visible:
			(child as CanvasItem).hide()
			_hidden.append(child as CanvasItem)
	for node: Node in get_tree().root.find_children("*", "CanvasLayer", true, false):
		var layer := node as CanvasLayer
		var shown := layer == keep or layer.is_ancestor_of(target)
		if keep != null:
			shown = shown or keep.is_ancestor_of(layer)
		else:
			shown = shown or target.is_ancestor_of(layer)
		if shown or not layer.visible:
			continue
		layer.hide()
		_hidden_layers.append(layer)


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
	for member: PartyMember in GameState.party:
		member.equipped_slots.clear()
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
	_isolate(screen)
	await runner.simulate_frames(2)
	await _capture("inventory-followup")


func test_live_field_battle() -> void:
	var runner := scene_runner("res://world/test_room.tscn")
	var root := runner.scene() as Node2D
	await runner.simulate_frames(3)
	var field := root.find_child("FieldMap", true, false) as FieldMap
	# The Wilds' authored Bog Wight stands on the battlefield; a fixed spawn cell does not
	# survive edits to the room's ground.
	GameState.set_flag("defeated_bog_wight", false)
	var hostile := root.find_child("BogWight", true, false) as Hostile
	assert_object(hostile).override_failure_message("test_room must author BogWight").is_not_null()
	hostile.alert_radius = 0.0
	hostile.sync_cell()
	var opened := Battle.start_session(field, hostile)
	assert_bool(opened.get("allowed", false)).override_failure_message(str(opened)).is_true()
	# One bar, both modes (owner 2026-11-01): on a live field the field's own HUD grows its
	# combat parts, as GameFlow._on_battle_entered() does; no full-screen battle screen opens.
	var field_hud := field.field_hud()
	field.set_combat_mode(true)
	field_hud.enter_combat(field)
	_isolate(root, field_hud)
	var camera := field.player().get_node("Camera2D") as Camera2D
	camera.enabled = true
	camera.make_current()
	camera.reset_smoothing()
	await runner.simulate_frames(5)
	assert_bool(field_hud.combat_active()).is_true()
	assert_object(field_hud.combat_bar).is_not_null()
	assert_object(field.combat_overlay()).is_not_null()
	await _capture("battle-live-followup")
	field_hud.exit_combat()
	field.set_combat_mode(false)
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
