extends GdUnitTestSuite

## Wave 0 symptom capture. This is intentionally evidence-only: it does not
## alter scenes, actors, assets, or production state.

const CAPTURE_SIZE := Vector2i(1920, 1080)
const TOWN_SCENE := "res://world/starting_town.tscn"
const TAVERN_SCENE := "res://world/interiors/dom_tavern.tscn"
const BUILDINGS: Array[Dictionary] = [
	{"id": "FourArmsTavern", "origin": Vector2(1700, 1800)},
	{"id": "TownHall", "origin": Vector2(2400, 1100)},
	{"id": "TrialHall", "origin": Vector2(1000, 500)},
]
const TEST_OFFSETS: Array[Dictionary] = [
	{"id": "front_40", "offset": Vector2(0, -40)},
	{"id": "front_120", "offset": Vector2(0, -120)},
	{"id": "front_250", "offset": Vector2(0, -250)},
	{"id": "left_120", "offset": Vector2(-200, -120)},
	{"id": "right_120", "offset": Vector2(200, -120)},
]


func before() -> void:
	get_tree().root.size = CAPTURE_SIZE
	DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path("user://qa/wave0"))


func test_capture_field_ux_wave0() -> void:
	var town_runner := scene_runner(TOWN_SCENE)
	var town := town_runner.scene() as Node2D
	await town_runner.simulate_frames(40)
	assert_object(town).is_not_null()
	if town == null:
		return

	var player := town.find_child("Player", true, false) as Player
	assert_object(player).is_not_null()
	if player == null:
		return
	var player_sprite := player.get_node_or_null("Sprite2D") as Sprite2D
	assert_object(player_sprite).is_not_null()
	if player_sprite == null:
		return

	var boot_scene := town.get_tree().current_scene
	if boot_scene != null and boot_scene != town:
		boot_scene.hide()
	_suppress_reward_reveal()

	for building_data: Dictionary in BUILDINGS:
		var building_id := str(building_data["id"])
		var origin := building_data["origin"] as Vector2
		var building := town.get_node_or_null(building_id) as Node2D
		assert_object(building).override_failure_message(building_id).is_not_null()
		if building == null:
			continue
		var facade := building.get_node_or_null("Facade") as Sprite2D
		assert_object(facade).override_failure_message(building_id).is_not_null()
		if facade == null:
			continue

		for offset_data: Dictionary in TEST_OFFSETS:
			var offset_id := str(offset_data["id"])
			var requested := origin + (offset_data["offset"] as Vector2)
			player.global_position = requested
			if player.has_method("rest_on_grid"):
				player.call("rest_on_grid")
			await town_runner.simulate_frames(3)
			var camera := player.get_node_or_null("Camera2D") as Camera2D
			if camera != null:
				camera.reset_smoothing()
			await town_runner.simulate_frames(1)
			var actual := player.global_position
			var alpha := _facade_alpha_at(facade, actual)
			var sprite_screen_rect := _canvas_rect(player_sprite)
			var intersects_opaque := _screen_rect_intersects_opaque(
				player_sprite, facade, sprite_screen_rect
			)
			var under_facade := actual.y < building.global_position.y
			var shot_name := "town_%s_%s" % [building_id.to_snake_case(), offset_id]
			var row := {
				"shot": shot_name,
				"building": building_id,
				"requested": _vector_text(requested),
				"actual": _vector_text(actual),
				"building_y": building.global_position.y,
				"player_y": actual.y,
				"ordering": "under_facade" if under_facade else "on_top_of_facade",
				"player_sprite_visible": player_sprite.visible,
				"player_sprite_modulate": _color_text(player_sprite.modulate),
				"player_z_index": player.z_index,
				"facade_z_index": facade.z_index,
				"facade_texture_size": _vector_text(facade.texture.get_size()),
				"facade_offset": _vector_text(facade.offset),
				"feet_texture_pixel": _facade_texture_pixel(facade, actual),
				"feet_alpha": alpha,
				"screen_rect": _rect_text(sprite_screen_rect),
				"screen_rect_intersects_facade_opaque": intersects_opaque,
			}
			print("WAVE0_TOWN_ROW %s" % JSON.stringify(row))
			await _capture(town_runner, town, shot_name)

	var tavern_door := town.find_child("TavernDoor", true, false) as Node
	assert_object(tavern_door).is_not_null()
	var tavern_destination := GameFlow.TAVERN_SCENE
	var tavern_spawn: StringName = &"entry"
	if tavern_door is TavernDoor:
		tavern_destination = GameFlow.TAVERN_SCENE
		tavern_spawn = &"entry"
	print(
		"WAVE0_TAVERN_DOOR node=%s type=%s destination=%s spawn=%s transition_id=n/a"
		% [tavern_door.name if tavern_door != null else "missing", tavern_door.get_class() if tavern_door != null else "missing", tavern_destination, tavern_spawn]
	)

	SaveGame.has_pending_player_position = false
	SaveGame.pending_spawn_id = tavern_spawn
	var tavern_runner := scene_runner(TAVERN_SCENE)
	var tavern := tavern_runner.scene() as Node2D
	assert_object(tavern).is_not_null()
	if tavern == null:
		return
	SaveGame.apply_pending_location(tavern)
	await tavern_runner.simulate_frames(40)
	var tavern_player := tavern.find_child("Player", true, false) as Player
	var tavern_sprite := tavern_player.get_node_or_null("Sprite2D") as Sprite2D if tavern_player != null else null
	var floor := tavern.get_node_or_null("Floor") as Polygon2D
	var tavern_position := tavern_player.global_position if tavern_player != null else Vector2.INF
	var floor_contains := false
	if floor != null and tavern_player != null:
		floor_contains = Geometry2D.is_point_in_polygon(floor.to_local(tavern_position), floor.polygon)
	var overlap_rows := _interior_overlap_rows(tavern, tavern_position)
	var interior_row := {
		"shot": "interior_dom_tavern_entry",
		"requested_spawn_id": String(tavern_spawn),
		"destination": tavern_destination,
		"player_global_position": _vector_text(tavern_position),
		"player_sprite_visible": tavern_sprite.visible if tavern_sprite != null else false,
		"player_sprite_modulate": _color_text(tavern_sprite.modulate) if tavern_sprite != null else "missing",
		"player_z_index": tavern_player.z_index if tavern_player != null else -1,
		"sprite_z_index": tavern_sprite.z_index if tavern_sprite != null else -1,
		"floor_polygon": _polygon_text(floor.polygon) if floor != null else "missing",
		"position_inside_floor": floor_contains,
		"overlaps_in_draw_order": overlap_rows,
	}
	print("WAVE0_INTERIOR_ROW %s" % JSON.stringify(interior_row))
	await _capture(tavern_runner, tavern, "interior_dom_tavern_entry")


func _capture(runner: GdUnitSceneRunner, scene: Node, shot_name: String) -> void:
	_suppress_reward_reveal()
	var boot_scene := scene.get_tree().current_scene
	if boot_scene != null and boot_scene != scene:
		boot_scene.hide()
	await runner.simulate_frames(3)
	RenderingServer.force_draw()
	if DisplayServer.get_name() != "headless":
		await RenderingServer.frame_post_draw
	var viewport_texture := scene.get_viewport().get_texture()
	if viewport_texture == null:
		print("WAVE0_PNG_UNAVAILABLE display_server=%s" % DisplayServer.get_name())
		return
	var image: Image = viewport_texture.get_image()
	if image == null:
		print("WAVE0_PNG_UNAVAILABLE image=unavailable display_server=%s" % DisplayServer.get_name())
		return
	assert_object(image.get_size()).is_equal(CAPTURE_SIZE)
	var path := "user://qa/wave0/%s.png" % shot_name
	assert_int(image.save_png(path)).is_equal(OK)
	print("WAVE0_PNG %s" % ProjectSettings.globalize_path(path))


func _suppress_reward_reveal() -> void:
	var reveal := UIManager.get_node_or_null("RewardReveal")
	if reveal is CanvasItem:
		(reveal as CanvasItem).visible = false


func _facade_alpha_at(facade: Sprite2D, world_point: Vector2) -> float:
	if facade.texture == null:
		return -1.0
	var texture := facade.texture as Texture2D
	var image := texture.get_image()
	var texture_point := facade.to_local(world_point) - facade.offset + Vector2(image.get_size()) * 0.5
	var pixel := Vector2i(floor(texture_point.x), floor(texture_point.y))
	if pixel.x < 0 or pixel.y < 0 or pixel.x >= image.get_width() or pixel.y >= image.get_height():
		return -1.0
	return image.get_pixelv(pixel).a


func _facade_texture_pixel(facade: Sprite2D, world_point: Vector2) -> String:
	if facade.texture == null:
		return "missing"
	var image := (facade.texture as Texture2D).get_image()
	var texture_point := facade.to_local(world_point) - facade.offset + Vector2(image.get_size()) * 0.5
	return "(%d,%d)" % [floor(texture_point.x), floor(texture_point.y)]


func _canvas_rect(item: CanvasItem) -> Rect2:
	var local_rect: Rect2 = item.get_rect()
	var transform := item.get_global_transform_with_canvas()
	var corners := [
		transform * local_rect.position,
		transform * Vector2(local_rect.end.x, local_rect.position.y),
		transform * Vector2(local_rect.position.x, local_rect.end.y),
		transform * local_rect.end,
	]
	var minimum := corners[0] as Vector2
	var maximum := minimum
	for corner_variant: Variant in corners:
		var corner := corner_variant as Vector2
		minimum.x = minf(minimum.x, corner.x)
		minimum.y = minf(minimum.y, corner.y)
		maximum.x = maxf(maximum.x, corner.x)
		maximum.y = maxf(maximum.y, corner.y)
	return Rect2(minimum, maximum - minimum)


func _screen_rect_intersects_opaque(
	player_sprite: Sprite2D, facade: Sprite2D, screen_rect: Rect2
) -> bool:
	var viewport_rect := Rect2(Vector2.ZERO, Vector2(CAPTURE_SIZE))
	var sample_rect := screen_rect.intersection(viewport_rect)
	if sample_rect.size.x <= 0.0 or sample_rect.size.y <= 0.0:
		return false
	var inverse_canvas := player_sprite.get_canvas_transform().affine_inverse()
	for y: int in range(floori(sample_rect.position.y), ceili(sample_rect.end.y)):
		for x: int in range(floori(sample_rect.position.x), ceili(sample_rect.end.x)):
			var world_point := inverse_canvas * Vector2(x + 0.5, y + 0.5)
			if _facade_alpha_at(facade, world_point) > 0.01:
				return true
	return false


func _interior_overlap_rows(interior: Node2D, player_position: Vector2) -> Array[String]:
	var rows: Array[Dictionary] = []
	for node_name: String in ["Walls", "ExitDoorSprite", "Title"]:
		var node := interior.get_node_or_null(node_name) as CanvasItem
		if node == null:
			rows.append({"node": node_name, "present": false})
			continue
		var overlaps := false
		if node is Sprite2D:
			overlaps = (node as Sprite2D).get_rect().has_point((node as Sprite2D).to_local(player_position))
		elif node is Label:
			var local_point := node.get_global_transform().affine_inverse() * player_position
			overlaps = (node as Label).get_rect().has_point(local_point)
		else:
			# Walls is a collision-only StaticBody2D; its CollisionShape2D children
			# are tested so the report distinguishes physics from drawn content.
			for child: Node in node.get_children():
				if child is CollisionShape2D and (child as CollisionShape2D).shape is RectangleShape2D:
					var shape := (child as CollisionShape2D).shape as RectangleShape2D
					var local_point := (child as CollisionShape2D).to_local(player_position)
					overlaps = overlaps or Rect2(-shape.size * 0.5, shape.size).has_point(local_point)
		rows.append({
			"node": node_name,
			"present": true,
			"overlaps_player_position": overlaps,
			"z_index": node.z_index,
			"tree_index": node.get_index(),
			"drawn": node is Sprite2D or node is Polygon2D or node is Label,
		})
	rows.sort_custom(func(a: Dictionary, b: Dictionary) -> bool:
		if int(a.get("z_index", 0)) == int(b.get("z_index", 0)):
			return int(a.get("tree_index", 0)) < int(b.get("tree_index", 0))
		return int(a.get("z_index", 0)) < int(b.get("z_index", 0))
	)
	var result: Array[String] = []
	for row: Dictionary in rows:
		result.append(JSON.stringify(row))
	return result


func _vector_text(value: Vector2) -> String:
	return "(%s,%s)" % [snappedf(value.x, 0.01), snappedf(value.y, 0.01)]


func _rect_text(value: Rect2) -> String:
	return "(%s,%s,%s,%s)" % [
		snappedf(value.position.x, 0.01), snappedf(value.position.y, 0.01),
		snappedf(value.size.x, 0.01), snappedf(value.size.y, 0.01),
	]


func _color_text(value: Color) -> String:
	return "(%s,%s,%s,%s)" % [value.r, value.g, value.b, value.a]


func _polygon_text(value: PackedVector2Array) -> String:
	var points: Array[String] = []
	for point: Vector2 in value:
		points.append(_vector_text(point))
	return "[" + ",".join(points) + "]"
