extends GdUnitTestSuite
## Ashlaren dressed with the Kesselford kit (lived-in maps M6, owner 2026-11-02: "Kesselford,
## then roll out"). The generated dressing loads with the map; its solid pieces block the grid
## that walking and combat share; spawns, exits and townsfolk stay clear; the ground is calmed;
## and the map's old props stand at their height class against the 112 px adult (M2).

const SCENE := "res://world/ashlaren.tscn"
## Old Ashlaren props rescaled to the M2 height classes (`PropScale.HEIGHT_PX`), by node name.
const OLD_PROP_CLASSES := {
	"GrainCart": "head",
	"YardBrazier": "waist",
	"SealedSackCrates": "head",
	"YardCrates": "head",
	"WeighingBoard": "tall",
	"GrassTuft01": "knee",
	"FlowerCluster01": "knee",
}
## How far a rescaled prop may sit from its class height (scales are rounded to two places).
const CLASS_TOLERANCE := 0.12

var _saved_state: Dictionary


func before_test() -> void:
	_saved_state = GameState.to_dict().duplicate(true)
	if GameState.party.is_empty():
		GameState._seed_demo_data()


func after_test() -> void:
	UIManager.close_all()
	GameState.from_dict(_saved_state)


func test_the_dressing_loads_and_its_solid_pieces_block_the_shared_grid() -> void:
	var runner := scene_runner(SCENE)
	var root := runner.scene() as Node
	await runner.simulate_frames(6)
	var lived_in := root.find_child("LivedIn", true, false) as LivedIn
	assert_object(lived_in).is_not_null()
	assert_int(lived_in.get_node("Props").get_child_count()).is_greater(80)
	assert_int(lived_in.get_node("GroundDetails").get_child_count()).is_greater(100)
	assert_int(lived_in.blocked_cells.size()).is_greater(0)
	var blocking := root.find_child("Blocking", true, false) as TileMapLayer
	var grid := (root.find_child("FieldMap", true, false) as FieldMap).iso_grid()
	var ground := root.find_child("IsometricGround", true, false) as TileMapLayer
	for cell: Vector2i in lived_in.blocked_cells:
		assert_int(blocking.get_cell_source_id(cell)).override_failure_message("painted %s" % cell).is_equal(0)
		var walk_cell := grid.world_to_cell(ground.to_global(ground.map_to_local(cell)))
		assert_bool(grid.is_point_solid(walk_cell)).override_failure_message("solid for paths %s" % cell).is_true()
	var terrain := root.find_child("Terrain", true, false) as TileMapLayer
	for cell: Vector2i in lived_in.cover_cells:
		assert_vector(Vector2(terrain.get_cell_atlas_coords(cell))).is_equal(Vector2(1, 0))


func test_spawns_exits_and_townsfolk_stay_clear() -> void:
	var runner := scene_runner(SCENE)
	var root := runner.scene() as Node
	await runner.simulate_frames(6)
	var lived_in := root.find_child("LivedIn", true, false) as LivedIn
	var points: Array[Vector2] = []
	for marker: Node in root.find_children("*", "Marker2D", true, false):
		points.append((marker as Node2D).global_position)
	for area: Node in root.find_children("*", "Area2D", true, false):
		if not lived_in.is_ancestor_of(area):
			points.append((area as Node2D).global_position)
	var townsfolk := root.find_children("*", "NPC", true, false)
	assert_int(townsfolk.size()).override_failure_message("the townsfolk spawn with a party").is_greater(0)
	var ground := root.find_child("IsometricGround", true, false) as TileMapLayer
	for point: Vector2 in points:
		var cell := ground.local_to_map(ground.to_local(point))
		assert_bool(lived_in.blocked_cells.has(cell)).override_failure_message("blocked at %s" % point).is_false()
	for sprite: Node in lived_in.get_node("Props").get_children():
		for point: Vector2 in points:
			assert_float((sprite as Node2D).global_position.distance_to(point)).override_failure_message(
				"%s crowds %s" % [sprite.name, point]).is_greater(40.0)


## The generated road band replaces the stamped grain-road paving, and the painted ground is
## calmed (owner 2026-11-02, "calm the ground first"; M6 gives every Dom-backdrop map the same).
func test_the_ground_is_calmed_and_the_paving_stamps_give_way_to_the_road_band() -> void:
	var runner := scene_runner(SCENE)
	var root := runner.scene() as Node
	await runner.simulate_frames(2)
	var material := (root.get_node("TerrainBackdrop") as Sprite2D).material as ShaderMaterial
	assert_object(material).is_not_null()
	assert_str(material.shader.resource_path).is_equal("res://world/dressing/ground_calm.gdshader")
	var stamps := root.find_children("PavingGrainRoad*", "Sprite2D", true, false)
	assert_int(stamps.size()).is_greater(0)
	for stamp: Node in stamps:
		assert_bool((stamp as CanvasItem).visible).override_failure_message("%s still shows" % stamp.name).is_false()


func test_old_props_stand_at_their_height_class() -> void:
	var runner := scene_runner(SCENE)
	var root := runner.scene() as Node
	await runner.simulate_frames(2)
	for prop_name: String in OLD_PROP_CLASSES:
		var node := root.find_child(prop_name, true, false) as Node2D
		assert_object(node).override_failure_message("missing %s" % prop_name).is_not_null()
		var sprite := node as Sprite2D
		if sprite == null:
			var found := node.find_children("*", "Sprite2D", true, false)
			sprite = null if found.is_empty() else found[0] as Sprite2D
		assert_object(sprite).override_failure_message("no sprite under %s" % prop_name).is_not_null()
		var opaque := DressingShadows.opaque_bounds(sprite.texture).size.y
		var on_screen := opaque * absf(sprite.get_global_transform().get_scale().y)
		var expected := PropScale.height_px(str(OLD_PROP_CLASSES[prop_name]))
		assert_float(on_screen).override_failure_message("%s stands %.0f px, its class is %.0f px" % [
			prop_name, on_screen, expected]).is_between(expected * (1.0 - CLASS_TOLERANCE), expected * (1.0 + CLASS_TOLERANCE))


func test_standing_props_cast_contact_shadows_and_facades_do_not() -> void:
	var runner := scene_runner(SCENE)
	var root := runner.scene() as Node
	await runner.simulate_frames(6)
	var shadows := root.find_child("DressingShadows", true, false) as DressingShadows
	assert_object(shadows).is_not_null()
	var props := root.find_child("LivedIn", true, false).get_node("Props").get_child_count()
	assert_int(shadows.shadow_count()).is_greater_equal(props)
	for rect: Rect2 in shadows.shadow_rects():
		assert_float(rect.size.x).override_failure_message("a facade cast a shadow").is_less(DressingShadows.MAX_HEIGHT_PX * 1.2)
