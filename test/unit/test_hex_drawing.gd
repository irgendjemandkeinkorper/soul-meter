extends GdUnitTestSuite
## Hex slice H3 (owner item 34; docs/design/hex-grid-plan-2026-11-03.md): what the field draws on
## hexes. Hex outlines and their shared edges, the reach ring, the reach a command draws, and the
## floor grid's strength in and out of a fight. The hex setting is restored after each test.

var _setting_before: Variant
var _exploring_before: Variant


func before_test() -> void:
	_setting_before = ProjectSettings.get_setting(IsoGrid.HEX_SETTING, false)
	_exploring_before = GameState.get_setting(
		FieldGridLayer.SETTING_SECTION, FieldGridLayer.SETTING_KEY, false
	)


func after_test() -> void:
	ProjectSettings.set_setting(IsoGrid.HEX_SETTING, _setting_before)
	GameState.set_setting(FieldGridLayer.SETTING_SECTION, FieldGridLayer.SETTING_KEY, _exploring_before)


func test_each_hex_edge_is_shared_with_the_neighbour_it_names() -> void:
	var layout := HexLayout.new(Vector2(40, 30))
	for hex: Vector2i in [Vector2i.ZERO, Vector2i(3, -2), Vector2i(-4, 5)]:
		var corners := layout.corners(hex)
		var center := layout.hex_to_world(hex)
		for edge: int in corners.size():
			var neighbour := hex + HexMath.DIRECTIONS[HexLayout.EDGE_NEIGHBOR[edge]]
			var midpoint := (corners[edge] + corners[(edge + 1) % corners.size()]) * 0.5
			var halfway := (center + layout.hex_to_world(neighbour)) * 0.5
			assert_float(midpoint.distance_to(halfway)).override_failure_message(
				"edge %d of %s is not shared with %s" % [edge, hex, neighbour]
			).is_less(0.01)


func test_a_cell_outline_is_the_diamond_on_squares_and_the_hex_on_hexes() -> void:
	var ground := _ground(6, 6)
	var square := IsoGrid.new()
	square.hex_mode = false
	square.build(ground)
	var diamond := square.cell_outline(Vector2i(2, 3))
	assert_int(diamond.size()).is_equal(4)
	var center := square.cell_to_world(Vector2i(2, 3))
	assert_vector(diamond[0]).is_equal(center + Vector2(0, -16))
	assert_vector(diamond[1]).is_equal(center + Vector2(32, 0))
	var hexes := IsoGrid.new()
	hexes.hex_mode = true
	hexes.build(ground)
	var hex := hexes.cell_at_square(Vector2i(2, 3))
	var outline := hexes.cell_outline(hex)
	assert_int(outline.size()).is_equal(6)
	var sum := Vector2.ZERO
	for point: Vector2 in outline:
		sum += point
	assert_float((sum / 6.0).distance_to(hexes.cell_to_world(hex))).is_less(0.01)
	# Pointy-top: the first corner is straight above the centre.
	assert_float(outline[0].x).is_equal_approx(hexes.cell_to_world(hex).x, 0.01)


func test_a_reach_ring_closes_around_its_hexes() -> void:
	var ground := _ground(10, 10)
	var grid := IsoGrid.new()
	grid.hex_mode = true
	grid.build(ground)
	var overlay := auto_free(CombatOverlay.new()) as CombatOverlay
	add_child(overlay)
	overlay.bind_grid(grid, ground)
	var center := grid.cell_at_square(Vector2i(5, 5))
	for steps: int in [1, 2, 3]:
		var inside: Dictionary = {}
		for hex: Vector2i in HexMath.within(center, steps):
			inside[hex] = true
		var segments: PackedVector2Array = overlay.call("_hex_boundary", inside)
		# A hex ring of radius n has 6(2n + 1) outer edges.
		assert_int(segments.size()).is_equal(2 * 6 * (2 * steps + 1))


func test_a_command_draws_its_reach_in_steps_of_the_grid() -> void:
	var strike := CombatAction.new()
	strike.target_profile = &"melee"
	strike.target_side = "enemy"
	var bolt := CombatAction.new()
	bolt.target_profile = &"ranged"
	bolt.target_side = "enemy"
	bolt.effect_payload = {"range": 4}
	var sight := CombatAction.new()
	sight.target_profile = &"ranged"
	sight.target_side = "enemy"
	var guard := CombatAction.new()
	guard.kind = CombatAction.Kind.GUARD
	guard.target_profile = &"self"
	ProjectSettings.set_setting(IsoGrid.HEX_SETTING, false)
	assert_int(strike.reach_steps()).is_equal(1)
	assert_int(bolt.reach_steps()).is_equal(4)
	ProjectSettings.set_setting(IsoGrid.HEX_SETTING, true)
	assert_int(strike.reach_steps()).is_equal(1)
	assert_int(bolt.reach_steps()).is_equal(8)
	assert_int(sight.reach_steps()).is_equal(0)
	assert_int(guard.reach_steps()).is_equal(0)


func test_the_floor_grid_shows_in_fights_and_faintly_while_exploring_only_when_asked() -> void:
	ProjectSettings.set_setting(IsoGrid.HEX_SETTING, true)
	GameState.set_setting(FieldGridLayer.SETTING_SECTION, FieldGridLayer.SETTING_KEY, false)
	var field := _field(true)
	var layer := field.grid_layer()
	assert_float(layer.target_alpha()).is_equal(0.0)
	assert_bool(layer.visible).is_false()
	field.set_combat_mode(true)
	assert_float(layer.target_alpha()).is_equal(FieldGridLayer.COMBAT_ALPHA)
	assert_bool(layer.visible).is_true()
	await await_millis(int((DS.DUR_SLOW + 0.15) * 1000.0))
	assert_float(layer.modulate.a).is_equal_approx(FieldGridLayer.COMBAT_ALPHA, 0.001)
	assert_int(layer.chunk_count()).is_greater(0)
	var segments := 0
	for chunk: Node in layer.get_children():
		segments += (chunk.get("segments") as PackedVector2Array).size()
	assert_int(segments).is_greater(0)
	field.set_combat_mode(false)
	await await_millis(int((DS.DUR_SLOW + 0.15) * 1000.0))
	assert_float(layer.modulate.a).is_equal(0.0)
	assert_bool(layer.visible).is_false()
	GameState.set_setting(FieldGridLayer.SETTING_SECTION, FieldGridLayer.SETTING_KEY, true)
	assert_float(layer.target_alpha()).is_equal(FieldGridLayer.EXPLORE_ALPHA)
	assert_bool(layer.visible).is_true()


func test_the_square_grid_draws_no_floor_grid() -> void:
	ProjectSettings.set_setting(IsoGrid.HEX_SETTING, false)
	GameState.set_setting(FieldGridLayer.SETTING_SECTION, FieldGridLayer.SETTING_KEY, true)
	var field := _field(false)
	field.set_combat_mode(true)
	assert_float(field.grid_layer().target_alpha()).is_equal(0.0)
	assert_bool(field.grid_layer().visible).is_false()
	assert_int(field.grid_layer().chunk_count()).is_equal(0)


func test_a_wall_hex_gets_no_lines() -> void:
	ProjectSettings.set_setting(IsoGrid.HEX_SETTING, true)
	var field := _field(true, [Vector2i(4, 4)])
	field.set_combat_mode(true)
	var layer := field.grid_layer()
	var grid := field.iso_grid()
	var wall := grid.cell_at_square(Vector2i(4, 4))
	assert_bool(grid.is_wall(wall)).is_true()
	var wall_center := layer.to_local(grid.cell_to_world(wall))
	for chunk: Node in layer.get_children():
		var segments := chunk.get("segments") as PackedVector2Array
		for index: int in range(0, segments.size(), 2):
			var midpoint := (segments[index] + segments[index + 1]) * 0.5
			# No drawn edge runs through the middle of a wall hex.
			assert_float(midpoint.distance_to(wall_center)).is_greater(4.0)


func test_settings_offer_the_exploring_grid_only_on_hexes() -> void:
	GameState.set_setting(FieldGridLayer.SETTING_SECTION, FieldGridLayer.SETTING_KEY, false)
	ProjectSettings.set_setting(IsoGrid.HEX_SETTING, false)
	var squares := auto_free(load("res://ui/screens/settings.tscn").instantiate()) as Node
	add_child(squares)
	await get_tree().process_frame
	assert_object(squares.find_child("HexGridExploring", true, false)).is_null()
	ProjectSettings.set_setting(IsoGrid.HEX_SETTING, true)
	var hexes := auto_free(load("res://ui/screens/settings.tscn").instantiate()) as Node
	add_child(hexes)
	await get_tree().process_frame
	var toggle := hexes.find_child("HexGridExploring", true, false) as CheckButton
	assert_object(toggle).is_not_null()
	assert_bool(toggle.button_pressed).override_failure_message("off by default").is_false()
	toggle.button_pressed = true
	assert_bool(FieldGridLayer.exploring_grid_enabled()).is_true()
	toggle.button_pressed = false
	assert_bool(FieldGridLayer.exploring_grid_enabled()).is_false()


class _GridField extends FieldMap:
	var layer: TileMapLayer
	var grid: IsoGrid

	func ground() -> TileMapLayer:
		return layer

	func iso_grid() -> IsoGrid:
		return grid

	func player() -> Player:
		return null

	func party_followers() -> PartyFollowers:
		return null


func _field(hex: bool, walls: Array[Vector2i] = []) -> _GridField:
	var ground := _ground(10, 10)
	var blocking: TileMapLayer = null
	if not walls.is_empty():
		blocking = _ground(0, 0)
		for cell: Vector2i in walls:
			blocking.set_cell(cell, 0, Vector2i.ZERO)
	var field := auto_free(_GridField.new()) as _GridField
	field.layer = ground
	field.grid = IsoGrid.new()
	field.grid.hex_mode = hex
	field.grid.build(ground, blocking)
	add_child(field)
	return field


func _ground(width: int, height: int) -> TileMapLayer:
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
	for y in height:
		for x in width:
			ground.set_cell(Vector2i(x, y), 0, Vector2i.ZERO)
	add_child(ground)
	return ground
