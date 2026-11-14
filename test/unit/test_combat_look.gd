extends GdUnitTestSuite
## One look per tone and a flourish per class (combat polish slice 5, owner 2026-11-02). Every
## tone on the Wheel and every class has its own look; a class command plays its class's
## flourish at the actor, a strike or a tone cast does not, and reduced motion plays none.

const CombatLookScript := preload("res://ui/hud/combat_look.gd")

var _reduced_before: Variant = false


func before_test() -> void:
	_reduced_before = GameState.get_setting("accessibility", "reduced_motion", false)
	GameState.set_setting("accessibility", "reduced_motion", false)


func after_test() -> void:
	GameState.set_setting("accessibility", "reduced_motion", _reduced_before)


func test_every_tone_and_every_class_has_its_own_look() -> void:
	var tone_looks: Array[String] = []
	for entry: Dictionary in DS.WHEEL:
		var look := CombatLookScript.tone_look(str(entry["id"]))
		assert_array(look).override_failure_message("tone %s" % entry["id"]).is_not_empty()
		tone_looks.append(JSON.stringify(look))
	assert_int(_distinct(tone_looks)).is_equal(DS.WHEEL.size())
	var class_looks: Array[String] = []
	for row: Dictionary in ClassCatalog.ALL:
		var look := CombatLookScript.class_look(str(row["id"]))
		assert_array(look).override_failure_message("class %s" % row["id"]).is_not_empty()
		class_looks.append(JSON.stringify(look))
	assert_int(_distinct(class_looks)).is_equal(ClassCatalog.ALL.size())


func test_a_class_flourish_takes_its_majors_colours_or_bronze_without_one() -> void:
	var ironbrand := CombatLookScript.class_colors("ironbrand")
	var major := str(ClassCatalog.by_id("ironbrand")["suggested_major"])
	for entry: Dictionary in DS.WHEEL:
		if str(entry["id"]) == major:
			assert_that(ironbrand[0]).is_equal(entry["color"])
	assert_that(CombatLookScript.class_colors("locksmirk")[0]).is_equal(CombatLookScript.FALLBACK_COLOR)


func test_the_class_tiles_and_the_flourish_agree_on_what_a_class_command_is() -> void:
	for action: CombatAction in CombatActionCatalog.all():
		var authored := not action.class_resource_action.is_empty() or action.effect_payload.has("requires_patron")
		assert_bool(KitGate.is_class_command(action)).override_failure_message(String(action.id)).is_equal(authored)


func test_a_class_command_plays_its_flourish_and_a_strike_does_not() -> void:
	var overlay := _overlay()
	overlay.consume_event(_action(&"jam-the-gears", "fickah"))
	var flourish := overlay.get_node_or_null("ClassFlourish")
	assert_object(flourish).is_not_null()
	await _await_presented(overlay)
	await get_tree().create_timer(0.9).timeout
	assert_object(overlay.get_node_or_null("ClassFlourish")).override_failure_message("it frees itself").is_null()

	overlay.consume_event(_action(&"strike", "fickah"))
	assert_object(overlay.get_node_or_null("ClassFlourish")).is_null()


func test_reduced_motion_plays_no_flourish() -> void:
	GameState.set_setting("accessibility", "reduced_motion", true)
	var overlay := _overlay()
	overlay.consume_event(_action(&"jam-the-gears", "fickah"))
	assert_object(overlay.get_node_or_null("ClassFlourish")).is_null()


func _distinct(values: Array[String]) -> int:
	var seen := {}
	for value: String in values:
		seen[value] = true
	return seen.size()


func _overlay() -> CombatOverlay:
	var tiles := TileSet.new()
	tiles.tile_size = Vector2i(64, 32)
	tiles.tile_shape = TileSet.TILE_SHAPE_ISOMETRIC
	var source := TileSetAtlasSource.new()
	source.texture = ImageTexture.create_from_image(Image.create(64, 32, false, Image.FORMAT_RGBA8))
	source.texture_region_size = tiles.tile_size
	source.create_tile(Vector2i.ZERO)
	tiles.add_source(source, 0)
	var ground := auto_free(TileMapLayer.new()) as TileMapLayer
	ground.tile_set = tiles
	ground.set_cell(Vector2i.ZERO, 0, Vector2i.ZERO)
	ground.set_cell(Vector2i(1, 0), 0, Vector2i.ZERO)
	add_child(ground)
	var grid := IsoGrid.new()
	grid.build(ground)
	var overlay := auto_free(CombatOverlay.new()) as CombatOverlay
	add_child(overlay)
	overlay.bind_grid(grid, ground)
	for id: StringName in [&"ally", &"enemy"]:
		var body := auto_free(Node2D.new()) as Node2D
		add_child(body)
		overlay.bind_actor(id, body)
	return overlay


func _action(action_id: StringName, patron_id: String) -> CombatEvent:
	var event := CombatEvent.new()
	event.type = &"action_resolved"
	event.actor_id = &"ally"
	event.target_id = &"enemy"
	event.data = {"action_id": String(action_id), "snapshot": {
		"allies": [{"id": &"ally", "position": &"c:0,0,0", "hp": 30, "max_hp": 30,
			"class_resource": {"patron_id": patron_id}}],
		"enemies": [{"id": &"enemy", "position": &"c:1,0,0", "hp": 30, "max_hp": 30,
			"class_resource": {"patron_id": ""}}],
	}}
	return event


func _await_presented(overlay: CombatOverlay, limit_ms: int = 4000) -> void:
	var deadline := Time.get_ticks_msec() + limit_ms
	while Time.get_ticks_msec() < deadline and overlay.is_presenting():
		await get_tree().process_frame
