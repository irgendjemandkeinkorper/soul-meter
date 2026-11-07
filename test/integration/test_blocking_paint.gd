extends GdUnitTestSuite
## Painted map walls (2026-11-03): the blocking layer of every map in
## SolidFootprints.PAINTED_MAPS holds exactly the ground cells its solid bodies stand on, and
## the walk and fight grid built from it honours them. Before, seven maps had nothing painted, so
## a fight walked through a facade or off the map. Since 2026-11-03 each prop's shape is the base
## of its art (`ArtBases`). When the first two tests fail after a map edit, run
## `godot --headless --path . --script res://tools/paint_blocking.gd`.

const KESSELFORD := "res://world/kesselford.tscn"
const TRIAL_HALL := "res://world/interiors/lower_trial_hall.tscn"
const WOUND_LIP := "res://world/wound_lip.tscn"
## Scene coordinates on Kesselford: a cell of the walk-in Wayhouse's front wall (tavern layout cell
## (3, 12)), one of its front doorway cells ((5, 12); item 35), and ground beyond the north border wall.
const WAYHOUSE_FRONT := Vector2(796, 500)
const WAYHOUSE_DOORWAY := Vector2(860, 532)
const BEYOND_NORTH_WALL := Vector2(1500, -120)
const SKILL_DOOR_FLAG := "tutorial_skill_door_open"
## Instanced scenes that are not a place someone must be able to walk to.
const NOT_DESTINATIONS: Array[String] = [
	"res://actors/player/player.tscn",
	"res://actors/party_followers/party_followers.tscn",
	"res://ui/hud/field_hud.tscn",
	"res://world/interiors/building_interior.tscn",
	"res://actors/accord_zone/accord_zone.tscn",
]
## How close the walk must come: into a trigger area (a door's range, an exit, a chest) grown
## by about half a cell, or near a spot that has none (an arrival point, a person).
const AREA_SLACK_PX := 32.0
const SPOT_REACH_PX := 96.0
## The trial hall's gates all stand open once the opening is complete.
const HALL_OPEN_FLAG := "tutorial_gauntlet_complete"

var _saved_state: Dictionary
var _saved_clock: Dictionary


func before_test() -> void:
	_saved_state = GameState.to_dict().duplicate(true)
	# Routine NPCs stand where their WorldClock phase puts them, and the clock is an autoload
	# that earlier suites can leave in any phase. Every map is checked at the default phase.
	_saved_clock = WorldClock.to_dict()
	WorldClock.reset()


func after_test() -> void:
	GameState.from_dict(_saved_state)
	WorldClock.from_dict(_saved_clock)


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


func test_every_based_prop_stands_on_its_art_base() -> void:
	for scene_path: String in SolidFootprints.PAINTED_MAPS:
		var root := (load(scene_path) as PackedScene).instantiate()
		var wrong: Array[String] = []
		for sprite: Sprite2D in ArtBases.based_sprites(root):
			var holder: Node = ArtBases.body_of(sprite)
			if holder == null:
				holder = sprite.get_node_or_null(ArtBases.BASE_BODY)
			var expected: Array[PackedVector2Array] = ArtBases.polygons_for(sprite)
			if holder == null or not _holds_polygons(holder, expected):
				wrong.append(str(root.get_path_to(sprite)))
		assert_bool(wrong.is_empty()).override_failure_message(
			"%s: %d props do not stand on their art base (%s). Run tools/paint_blocking.gd."
			% [scene_path, wrong.size(), ", ".join(wrong.slice(0, 4))]
		).is_true()
		root.free()


## Bigger bases must not wall anyone in: from where the player arrives, the walk reaches every
## arrival point, door, exit, chest and person on the map (the trial hall with its gates open).
func test_every_arrival_door_and_person_can_be_reached() -> void:
	for scene_path: String in SolidFootprints.PAINTED_MAPS:
		var scene := await _load_map(scene_path)
		if scene_path == TRIAL_HALL:
			GameState.set_flag(HALL_OPEN_FLAG, true)
			await get_tree().process_frame
		var grid := (scene.find_child("FieldMap", true, false) as FieldMap).iso_grid()
		var player := scene.find_child("Player", true, false) as Node2D
		var walked := _walked_points(grid, grid.world_to_cell(player.global_position))
		var cut_off: Array[String] = []
		for target: Node2D in _destinations(scene):
			if not _reaches(target, walked):
				cut_off.append("%s %s" % [scene.get_path_to(target), target.global_position])
		assert_bool(cut_off.is_empty()).override_failure_message(
			"%s: the walk from the player's arrival cannot reach %s"
			% [scene_path, ", ".join(cut_off)]
		).is_true()
		await _unload(scene)


## Routine people move with the WorldClock (FR-504a). In every other phase, each one present on a
## painted map is still reached by the walk from the player's arrival. (2026-11-07: the Long Verge
## paymaster's afternoon spot stood on blocked ground south of the Split Stone.)
func test_every_routine_person_can_be_reached_in_every_phase() -> void:
	for phase: StringName in WorldClock.PHASES:
		if phase == WorldClock.DEFAULT_PHASE:
			continue
		assert_bool(WorldClock.set_phase(phase, "test")).is_true()
		for scene_path: String in SolidFootprints.PAINTED_MAPS:
			var scene := await _load_map(scene_path)
			var grid := (scene.find_child("FieldMap", true, false) as FieldMap).iso_grid()
			var player := scene.find_child("Player", true, false) as Node2D
			var walked := _walked_points(grid, grid.world_to_cell(player.global_position))
			var cut_off: Array[String] = []
			for target: Node2D in _destinations(scene):
				var person := target as NPC
				if person == null or not person.visible or not NpcRoutines.has_routine(person._stable_actor_id()):
					continue
				if not _reaches(person, walked):
					cut_off.append("%s %s" % [scene.get_path_to(person), person.global_position])
			assert_bool(cut_off.is_empty()).override_failure_message(
				"%s in the %s: the walk from the player's arrival cannot reach %s"
				% [scene_path, phase, ", ".join(cut_off)]
			).is_true()
			await _unload(scene)


func test_kesselford_grid_stops_at_a_facade_and_at_the_border() -> void:
	var scene := await _load_map(KESSELFORD)
	var grid := (scene.find_child("FieldMap", true, false) as FieldMap).iso_grid()
	assert_object(grid).is_not_null()
	var facade := grid.world_to_cell(WAYHOUSE_FRONT)
	assert_bool(grid.is_blocked_for(facade)).override_failure_message(
		"the Wayhouse front %s is open on the grid" % str(facade)
	).is_true()
	var doorway := grid.world_to_cell(WAYHOUSE_DOORWAY)
	assert_bool(grid.is_blocked_for(doorway)).override_failure_message(
		"the Wayhouse doorway %s is shut on the grid" % str(doorway)
	).is_false()
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


func _holds_polygons(holder: Node, expected: Array[PackedVector2Array]) -> bool:
	var shapes: Array[CollisionShape2D] = []
	for child: Node in holder.get_children():
		if child is CollisionPolygon2D:
			return false
		if child is CollisionShape2D:
			shapes.append(child as CollisionShape2D)
	if shapes.size() != expected.size():
		return false
	for index in shapes.size():
		var shape := shapes[index].shape as ConvexPolygonShape2D
		if shape == null or shapes[index].position != Vector2.ZERO:
			return false
		if shape.points.size() != expected[index].size():
			return false
		for corner in shape.points.size():
			if shape.points[corner].distance_to(expected[index][corner]) > 0.02:
				return false
	return true


## The centres of every cell the walk reaches from `start`, stepping round walls (people move,
## so they do not count), bucketed by 128 px square for the reach checks.
func _walked_points(grid: IsoGrid, start: Vector2i) -> Dictionary:
	var walked := {start: true}
	var queue: Array[Vector2i] = [start]
	while not queue.is_empty():
		var cell: Vector2i = queue.pop_back()
		for offset: Vector2i in grid.neighbor_offsets():
			var next := cell + offset
			if walked.has(next) or not grid.is_in_bounds(next) or grid.is_wall(next):
				continue
			if grid.is_edge_walled(cell, next):
				continue
			walked[next] = true
			queue.append(next)
	var buckets := {}
	for cell: Vector2i in walked:
		var point := grid.cell_to_world(cell)
		var key := Vector2i((point / 128.0).floor())
		# A packed array is copied out of a Dictionary, so write the grown copy back.
		var bucket: PackedVector2Array = buckets.get(key, PackedVector2Array())
		bucket.append(point)
		buckets[key] = bucket
	return buckets


## Whether a walked point lies in one of the target's trigger areas (grown by AREA_SLACK_PX), or
## within SPOT_REACH_PX of the target when it has no area.
func _reaches(target: Node2D, walked: Dictionary) -> bool:
	var zones: Array[Rect2] = []
	var areas: Array[Node] = target.find_children("*", "Area2D", true, false)
	if target is Area2D:
		areas.append(target)
	for area: Node in areas:
		for child: Node in area.get_children():
			var shape_node := child as CollisionShape2D
			if shape_node == null or shape_node.shape == null or shape_node.disabled:
				continue
			var box := shape_node.global_transform * shape_node.shape.get_rect()
			zones.append(box.grow(AREA_SLACK_PX))
	if zones.is_empty():
		zones.append(Rect2(target.global_position, Vector2.ZERO).grow(SPOT_REACH_PX))
	for zone: Rect2 in zones:
		var low := Vector2i((zone.position / 128.0).floor())
		var high := Vector2i((zone.end / 128.0).floor())
		for y in range(low.y, high.y + 1):
			for x in range(low.x, high.x + 1):
				for point: Vector2 in walked.get(Vector2i(x, y), PackedVector2Array()):
					if zone.has_point(point):
						return true
	return false


func _destinations(scene: Node) -> Array[Node2D]:
	var found: Array[Node2D] = []
	for node: Node in scene.find_children("*", "Node2D", true, false):
		var spot := node as Node2D
		if _inside_instance(spot, scene):
			continue
		if spot is Marker2D:
			found.append(spot)
		elif spot.scene_file_path == "" or spot == scene:
			continue
		elif not spot.scene_file_path in NOT_DESTINATIONS:
			found.append(spot)
	return found


func _inside_instance(node: Node, scene: Node) -> bool:
	var current := node.get_parent()
	while current != null and current != scene:
		if current.scene_file_path != "":
			return true
		current = current.get_parent()
	return false


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
