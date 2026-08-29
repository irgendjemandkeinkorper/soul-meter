extends GdUnitTestSuite

const EnemyScript := preload("res://actors/enemy/enemy.gd")
const NpcScript := preload("res://actors/npc/npc.gd")
const TILE_SIZE := Vector2i(64, 32)


func _make_tile_set() -> TileSet:
	var tile_set := TileSet.new()
	tile_set.tile_size = TILE_SIZE
	tile_set.tile_shape = TileSet.TILE_SHAPE_ISOMETRIC
	tile_set.tile_layout = TileSet.TILE_LAYOUT_DIAMOND_DOWN
	var image := Image.create(TILE_SIZE.x, TILE_SIZE.y, false, Image.FORMAT_RGBA8)
	var texture := ImageTexture.create_from_image(image)
	var source := TileSetAtlasSource.new()
	source.texture = texture
	source.texture_region_size = TILE_SIZE
	source.create_tile(Vector2i.ZERO)
	tile_set.add_source(source, 0)
	return tile_set


func _make_world(blocked_cells: Array[Vector2i] = []) -> Node2D:
	var world := auto_free(Node2D.new()) as Node2D
	world.name = "GridPlacementFixture"
	var ground := TileMapLayer.new()
	ground.name = "IsometricGround"
	ground.tile_set = _make_tile_set()
	for y: int in 5:
		for x: int in 5:
			ground.set_cell(Vector2i(x, y), 0, Vector2i.ZERO)
	world.add_child(ground)
	if not blocked_cells.is_empty():
		var blocking := TileMapLayer.new()
		blocking.name = "Blocking"
		blocking.tile_set = ground.tile_set
		for cell: Vector2i in blocked_cells:
			blocking.set_cell(cell, 0, Vector2i.ZERO)
		world.add_child(blocking)
	get_tree().root.add_child(world)
	return world


func _cell_center(ground: TileMapLayer, world_position: Vector2) -> Vector2:
	var cell: Vector2i = ground.local_to_map(ground.to_local(world_position))
	return ground.to_global(ground.map_to_local(cell))


func test_npc_ready_snaps_authored_position_to_cell_center() -> void:
	var world := _make_world()
	var ground := world.get_node("IsometricGround") as TileMapLayer
	var authored_position: Vector2 = (
		ground.to_global(ground.map_to_local(Vector2i(2, 2))) + Vector2(2.0, 1.0)
	)
	var npc := NpcScript.new() as NPC
	npc.add_child(Sprite2D.new())
	npc.get_child(0).name = "Sprite2D"
	npc.global_position = authored_position

	world.add_child(npc)

	assert_vector(npc.global_position).is_equal(_cell_center(ground, authored_position))


func test_enemy_ready_snaps_authored_position_to_cell_center() -> void:
	var world := _make_world()
	var ground := world.get_node("IsometricGround") as TileMapLayer
	var authored_position: Vector2 = (
		ground.to_global(ground.map_to_local(Vector2i(3, 2))) + Vector2(-2.0, 1.0)
	)
	var enemy := EnemyScript.new() as Enemy
	enemy.encounter_id = &"bog-wight"
	enemy.add_child(Sprite2D.new())
	enemy.get_child(0).name = "Sprite2D"
	enemy.global_position = authored_position

	world.add_child(enemy)

	assert_bool(is_instance_valid(enemy)).is_true()
	assert_vector(enemy.global_position).is_equal(_cell_center(ground, authored_position))


func test_npc_ready_uses_nearest_walkable_center_when_authored_cell_is_blocked() -> void:
	var blocked_cell := Vector2i(2, 2)
	var world := _make_world([blocked_cell] as Array[Vector2i])
	var ground := world.get_node("IsometricGround") as TileMapLayer
	var authored_position: Vector2 = ground.to_global(ground.map_to_local(blocked_cell))
	var npc := NpcScript.new() as NPC
	npc.add_child(Sprite2D.new())
	npc.get_child(0).name = "Sprite2D"
	npc.global_position = authored_position

	world.add_child(npc)

	var snapped_cell: Vector2i = ground.local_to_map(ground.to_local(npc.global_position))
	assert_vector(snapped_cell).is_not_equal(blocked_cell)
	assert_vector(npc.global_position).is_equal(
		ground.to_global(ground.map_to_local(snapped_cell))
	)


func test_routine_position_is_snapped_only_when_applied() -> void:
	var world := _make_world()
	var ground := world.get_node("IsometricGround") as TileMapLayer
	var row: Dictionary = NpcRoutines.placement("sella-varn", &"morning")
	var authored_routine: Vector2 = row["position"]
	var npc := NpcScript.new() as NPC
	npc.add_child(Sprite2D.new())
	npc.get_child(0).name = "Sprite2D"
	world.add_child(npc)
	# An off-center position inside the fixture grid stands in for the routine's
	# authored coordinates (which target Dom, far outside this 5x5 fixture).
	var applied_position: Vector2 = (
		ground.to_global(ground.map_to_local(Vector2i(1, 1))) + Vector2(5.0, 3.0)
	)

	GridPlacement.snap_to_walkable_cell(npc, applied_position)

	var snapped_cell: Vector2i = ground.local_to_map(ground.to_local(npc.global_position))
	assert_vector(npc.global_position).is_equal(
		ground.to_global(ground.map_to_local(snapped_cell))
	)
	var unchanged_row: Dictionary = NpcRoutines.placement("sella-varn", &"morning")
	assert_vector(unchanged_row["position"]).is_equal(authored_routine)


func test_snap_keeps_authored_position_when_no_open_cell_is_within_reach() -> void:
	var all_cells: Array[Vector2i] = []
	for y: int in 5:
		for x: int in 5:
			all_cells.append(Vector2i(x, y))
	var world := _make_world(all_cells)
	var ground := world.get_node("IsometricGround") as TileMapLayer
	var npc := NpcScript.new() as NPC
	npc.add_child(Sprite2D.new())
	npc.get_child(0).name = "Sprite2D"
	world.add_child(npc)
	var authored_position: Vector2 = (
		ground.to_global(ground.map_to_local(Vector2i(2, 2))) + Vector2(4.0, 2.0)
	)

	GridPlacement.snap_to_walkable_cell(npc, authored_position)

	# Snapping is a correction, not a relocation: with every nearby cell blocked
	# the authored stand wins over teleporting to a distant open cell.
	assert_vector(npc.global_position).is_equal(authored_position)


func test_scene_without_grid_preserves_authored_position() -> void:
	var world := auto_free(Node2D.new()) as Node2D
	get_tree().root.add_child(world)
	var npc := NpcScript.new() as NPC
	npc.add_child(Sprite2D.new())
	npc.get_child(0).name = "Sprite2D"
	var authored_position := Vector2(19.0, 23.0)
	npc.global_position = authored_position

	world.add_child(npc)

	assert_vector(npc.global_position).is_equal(authored_position)
