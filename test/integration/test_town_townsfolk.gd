extends GdUnitTestSuite
## Runtime acceptance coverage for Dom's data-driven outdoor population.

const SpriteCatalog := preload("res://assets/generated/sprites/isometric_sprite_catalog.gd")
const ROSTER_PATH := "res://data/generated/dom_npc_roster.json"
const PLACEMENTS_PATH := "res://data/generated/dom_npc_placements.json"
const TOWN_SCENE_PATH := "res://world/starting_town.tscn"


func test_thirty_outdoor_townsfolk_spawn_from_generated_placements() -> void:
	var roster: Dictionary = _json(ROSTER_PATH)["npcs"]
	var placements: Dictionary = _json(PLACEMENTS_PATH)["placements"]
	var runner := scene_runner(TOWN_SCENE_PATH)
	await runner.simulate_frames(3)
	var spawner := runner.find_child("OutdoorTownsfolk", true, false) as TownNpcSpawner
	assert_object(spawner).is_not_null()
	var spawned := spawner.spawned_npcs()
	assert_int(spawned.size()).is_equal(30)

	var expected_ids := PackedStringArray()
	for npc_id: String in placements:
		if placements[npc_id]["scene"] == TOWN_SCENE_PATH:
			expected_ids.append(npc_id)
	expected_ids.sort()
	assert_int(expected_ids.size()).is_equal(30)

	var used_models := {}
	for npc: NPC in spawned:
		var npc_id := str(npc.get_meta(&"npc_id", ""))
		assert_array(Array(expected_ids)).contains(npc_id)
		var row: Dictionary = roster[npc_id]
		var placement: Dictionary = placements[npc_id]
		var anchor := runner.find_child(placement["anchor"], true, false) as Node2D
		assert_object(anchor).is_not_null()
		var offset: Array = placement["offset"]
		var expected_position := anchor.position + Vector2(float(offset[0]), float(offset[1]))
		assert_bool(npc.position.is_equal_approx(expected_position)).is_true()
		assert_str(npc.npc_name).is_equal(row["display_name"])
		assert_str(npc.dialogue_path).is_equal(row["dialogue"]["path"])
		assert_str(npc.dialogue_start).is_equal(row["dialogue"]["title"])
		assert_str(str(npc.get_meta(&"portrait_id", ""))).is_equal(row["portrait"]["id"])
		assert_bool(npc.is_in_group(TownNpcSpawner.GENERATED_GROUP)).is_true()

		var sprite := npc.get_node("Sprite2D") as Sprite2D
		var model_name := str(npc.get_meta(&"sprite_model", ""))
		var expected_sprite_path := SpriteCatalog.texture_path("mini-characters", model_name)
		assert_object(sprite.texture).is_not_null()
		assert_str(sprite.texture.resource_path).is_equal(expected_sprite_path)
		assert_bool(sprite.region_enabled).is_false()
		assert_bool(sprite.scale == Vector2.ONE).is_true()
		assert_bool(sprite.offset.is_equal_approx(SpriteCatalog.SPRITE_PIVOT_OFFSET)).is_true()
		var areas := npc.find_children("*", "Area2D", true, false)
		assert_int(areas.size()).is_equal(1)
		var range_shapes := areas[0].find_children(
			"*", "CollisionShape2D", true, false
		)
		assert_int(range_shapes.size()).is_equal(1)
		var range_shape := range_shapes[0] as CollisionShape2D
		var range_circle := range_shape.shape as CircleShape2D
		assert_float(range_circle.radius).is_equal(TownNpcSpawner.GENERATED_INTERACTION_RADIUS)
		used_models[model_name] = true
	assert_int(used_models.size()).is_equal(26)


func test_every_pre_authored_and_generated_townsfolk_uses_an_isometric_render() -> void:
	var runner := scene_runner(TOWN_SCENE_PATH)
	await runner.simulate_frames(3)
	var spawner := runner.find_child("OutdoorTownsfolk", true, false) as TownNpcSpawner
	var town := spawner.get_parent()
	var townsfolk: Array[NPC] = []
	for node: Node in town.find_children("*", "StaticBody2D", true, false):
		if node is NPC:
			townsfolk.append(node as NPC)
	assert_int(townsfolk.size()).is_equal(34)
	for npc: NPC in townsfolk:
		var sprite := npc.get_node("Sprite2D") as Sprite2D
		assert_bool(sprite.region_enabled).is_false()
		assert_str(sprite.texture.resource_path).starts_with(
			"res://assets/generated/sprites/mini-characters/"
		)


func test_water_backdrop_and_nature_sprites_finish_the_north_and_east_edges() -> void:
	var packed := load(TOWN_SCENE_PATH) as PackedScene
	var town := packed.instantiate() as Node2D
	auto_free(town)
	var water_backdrop := town.find_child("WaterBackdrop", true, false) as Polygon2D
	assert_object(water_backdrop).is_not_null()
	var bounds := Rect2(water_backdrop.polygon[0], Vector2.ZERO)
	for point: Vector2 in water_backdrop.polygon:
		bounds = bounds.expand(point)
	assert_float(bounds.position.x).is_less_equal(-640.0)
	assert_float(bounds.position.y).is_less_equal(-360.0)
	assert_float(bounds.end.x).is_greater_equal(2240.0)
	assert_float(bounds.end.y).is_greater_equal(1360.0)

	var north_edge := town.find_children("NorthEdge*", "Sprite2D", true, false)
	var east_edge := town.find_children("EastEdge*", "Sprite2D", true, false)
	assert_int(north_edge.size()).is_equal(10)
	assert_int(east_edge.size()).is_equal(7)
	for sprite: Sprite2D in north_edge + east_edge:
		assert_str(sprite.texture.resource_path).starts_with(
			"res://assets/generated/sprites/nature-kit/"
		)


func _json(path: String) -> Dictionary:
	var parsed: Variant = JSON.parse_string(FileAccess.get_file_as_string(path))
	assert_bool(parsed is Dictionary).is_true()
	return parsed as Dictionary
