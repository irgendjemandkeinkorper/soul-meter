extends GdUnitTestSuite
## Painted map walls (2026-11-03): the blocking layer of every map in
## SolidFootprints.PAINTED_MAPS holds exactly the ground cells its solid bodies stand on, and
## the walk and fight grid built from it honours them. Before, seven maps had nothing painted, so
## a fight walked through a facade or off the map. When the first test fails after a map edit,
## run `godot --headless --path . --script res://tools/paint_blocking.gd`.

const KESSELFORD := "res://world/kesselford.tscn"
const TRIAL_HALL := "res://world/interiors/lower_trial_hall.tscn"
const WOUND_LIP := "res://world/wound_lip.tscn"
## Scene coordinates on Kesselford: the Wayhouse front, and ground beyond the north border wall.
const WAYHOUSE_FRONT := Vector2(1150, 700)
const BEYOND_NORTH_WALL := Vector2(1500, -120)
const SKILL_DOOR_FLAG := "tutorial_skill_door_open"

var _saved_state: Dictionary


func before_test() -> void:
	_saved_state = GameState.to_dict().duplicate(true)


func after_test() -> void:
	GameState.from_dict(_saved_state)


func test_every_painted_map_holds_exactly_its_solids_cells() -> void:
	for scene_path: String in SolidFootprints.PAINTED_MAPS:
		var root := (load(scene_path) as PackedScene).instantiate()
		var ground := SolidFootprints.find_ground(root)
		var layer := root.get_node_or_null(SolidFootprints.PAINTED_MAPS[scene_path]) as TileMapLayer
		assert_object(layer).override_failure_message("%s has no blocking layer" % scene_path).is_not_null()
		if layer == null or ground == null:
			root.free()
			continue
		var expected := SolidFootprints.ground_cells(root, ground)
		var painted := {}
		for cell: Vector2i in layer.get_used_cells():
			painted[cell] = true
		var missing: Array = expected.keys().filter(func(cell: Vector2i) -> bool: return not painted.has(cell))
		var extra: Array = painted.keys().filter(func(cell: Vector2i) -> bool: return not expected.has(cell))
		assert_bool(missing.is_empty() and extra.is_empty()).override_failure_message(
			"%s paint is stale: %d solid cells unpainted (%s), %d painted cells with no solid (%s). Run tools/paint_blocking.gd."
			% [scene_path, missing.size(), str(missing.slice(0, 4)), extra.size(), str(extra.slice(0, 4))]
		).is_true()
		assert_bool(expected.is_empty()).override_failure_message("%s has no solids at all" % scene_path).is_false()
		root.free()


func test_kesselford_grid_stops_at_a_facade_and_at_the_border() -> void:
	var scene := await _load_map(KESSELFORD)
	var grid := (scene.find_child("FieldMap", true, false) as FieldMap).iso_grid()
	assert_object(grid).is_not_null()
	var facade := grid.world_to_cell(WAYHOUSE_FRONT)
	assert_bool(grid.is_blocked_for(facade)).override_failure_message(
		"the Wayhouse front %s is open on the grid" % str(facade)
	).is_true()
	var player := scene.find_child("Player", true, false) as Node2D
	var start := grid.world_to_cell(player.global_position)
	var beyond := grid.world_to_cell(BEYOND_NORTH_WALL)
	assert_bool(grid.is_in_bounds(beyond)).override_failure_message("no ground beyond the wall").is_true()
	assert_int(grid.path_cells(start, beyond).size()).override_failure_message(
		"a path leaves the map through the north wall"
	).is_equal(0)
	await _unload(scene)


func test_a_trial_hall_gate_opens_its_cells_with_the_gate() -> void:
	var scene := await _load_map(TRIAL_HALL)
	var grid := (scene.find_child("FieldMap", true, false) as FieldMap).iso_grid()
	var door := scene.get_node("SkillDoor/CollisionShape2D") as CollisionShape2D
	# Points along the door; the walk grid's one-cell clearance keeps those beside the counter.
	var line: Array[Vector2i] = []
	for x in range(-840, 841, 40):
		line.append(grid.world_to_cell(door.global_position + Vector2(x, 0)))
	var shut := _blocked(grid, line)
	assert_int(shut).override_failure_message("the shut skill door blocks %d of %d" % [shut, line.size()]).is_equal(line.size())
	# Where the door meets the east wall the wall keeps the cell.
	var wall_end := grid.world_to_cell(door.global_position + Vector2(930, 0))
	assert_bool(grid.is_blocked_for(wall_end)).is_true()
	GameState.set_flag(SKILL_DOOR_FLAG, true)
	await get_tree().process_frame
	var open := _blocked(grid, line)
	assert_int(open).override_failure_message("the open skill door still blocks %d of %d" % [open, line.size()]).is_less(line.size() / 2)
	assert_bool(grid.is_blocked_for(wall_end)).override_failure_message("opening the door opened the wall").is_true()
	GameState.set_flag(SKILL_DOOR_FLAG, false)
	await get_tree().process_frame
	assert_int(_blocked(grid, line)).override_failure_message("the door did not shut again").is_equal(line.size())
	await _unload(scene)


func test_the_wound_lip_guard_stands_on_the_grid() -> void:
	var scene := await _load_map(WOUND_LIP)
	var grid := (scene.find_child("FieldMap", true, false) as FieldMap).iso_grid()
	for name: String in ["CleanedGuard", "GuardKit", "Player"]:
		var body := scene.find_child(name, true, false) as Node2D
		var cell := grid.world_to_cell(body.global_position)
		assert_bool(grid.is_in_bounds(cell)).override_failure_message("%s is off the grid" % name).is_true()
	await _unload(scene)


func _blocked(grid: IsoGrid, cells: Array[Vector2i]) -> int:
	return cells.filter(func(cell: Vector2i) -> bool: return grid.is_blocked_for(cell)).size()


func _load_map(map_path: String) -> Node:
	var scene := (load(map_path) as PackedScene).instantiate()
	add_child(scene)
	await get_tree().process_frame
	await get_tree().process_frame
	return scene


func _unload(scene: Node) -> void:
	scene.queue_free()
	await get_tree().process_frame
