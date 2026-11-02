extends SceneTree
## Writes a location's generated lived-in dressing scene (lived-in maps M3, owner 2026-11-02).
##
##   godot --headless --path . --script tools/dress_location.gd -- \
##       --scene res://world/kesselford.tscn \
##       --batch res://assets/generated/sources/kesselford-greebles-2026-11-02/batch.json \
##       --out res://world/dressing/kesselford_lived_in.tscn --seed 1102
##
## It loads the map live (autoloads ready), reads its layout (playable area, static bodies,
## spawns, exits, doors, the main routes between them), runs `LivedInDresser`, and saves a
## fresh scene. It never writes the canonical map: the map instances the generated scene once.
## Only assets whose prepared sprite exists are used, so a partial batch dresses partially.

const LivedInScript := preload("res://world/dressing/lived_in.gd")
const DressingShadowsScript := preload("res://world/dressing/dressing_shadows.gd")
const DresserScript := preload("res://world/dressing/lived_in_dresser.gd")
const STANDING_OFFSET := Vector2(0.0, -112.0)
## Structures: a static body at least this wide is a building, and its front gets wall bases.
const STRUCTURE_MIN_WIDTH := 100.0
const CLEAR_MARGIN := Vector2(64.0, 36.0)


func _initialize() -> void:
	_run.call_deferred()


func _run() -> void:
	await process_frame
	var options := _options(OS.get_cmdline_user_args())
	for key: String in ["scene", "batch", "out"]:
		if not options.has(key):
			printerr("usage: -- --scene <res://map.tscn> --batch <res://batch.json> --out <res://out.tscn> [--seed n]")
			quit(2)
			return
	var seed_value := int(options.get("seed", "1102"))
	var scene := (load(str(options["scene"])) as PackedScene).instantiate()
	root.add_child(scene)
	await process_frame
	await process_frame
	var layout := read_layout(scene)
	if layout.is_empty():
		printerr("no IsometricGround in %s" % options["scene"])
		quit(3)
		return
	var catalog := read_catalog(str(options["batch"]))
	var result := DresserScript.dress(layout, catalog, seed_value)
	var dressed := build_scene(result, seed_value, str(options["batch"]))
	var packed := PackedScene.new()
	var error := packed.pack(dressed)
	if error == OK:
		DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path(str(options["out"]).get_base_dir()))
		error = ResourceSaver.save(packed, str(options["out"]))
	var placements: Array = result["placements"]
	var ground := placements.filter(func(row: Dictionary) -> bool: return row["layer"] == "ground").size()
	print("DRESSED %s: %d ground, %d standing (%d solid), %d blocked, %d cover, %d catalogue rows, %d corridor cells -> %s (%s)" % [
		options["scene"], ground, placements.size() - ground,
		placements.filter(func(row: Dictionary) -> bool: return row["solid"]).size(),
		(result["blocked"] as Array).size(), (result["cover"] as Array).size(), catalog.size(),
		(layout["corridor"] as Dictionary).size(), options["out"], error_string(error)])
	dressed.free()
	scene.queue_free()
	quit(0 if error == OK else 4)


static func read_layout(scene: Node) -> Dictionary:
	var ground := scene.find_child("IsometricGround", true, false) as TileMapLayer
	if ground == null:
		return {}
	var origin := ground.to_global(ground.map_to_local(Vector2i.ZERO))
	var step := ground.to_global(ground.map_to_local(Vector2i(1, 0))) - origin
	assert(step.is_equal_approx(Vector2(32, 16)), "expected a 64x32 diamond-down ground, got step %s" % step)
	var playable := _playable_rect(scene, ground)
	var cells := {}
	for cell: Vector2i in ground.get_used_cells():
		if playable.has_point(DresserScript.cell_center(origin, cell)):
			cells[cell] = true
	var occupied := {}
	var structures: Array[Rect2] = []
	for body: Node in scene.find_children("*", "StaticBody2D", true, false):
		if body.name == &"Walls":
			continue
		var bounds := Rect2()
		var has_bounds := false
		for shape_node: Node in body.find_children("*", "CollisionShape2D", true, false):
			var rect := _shape_rect(shape_node as CollisionShape2D)
			if rect.size == Vector2.ZERO:
				continue
			bounds = rect if not has_bounds else bounds.merge(rect)
			has_bounds = true
			_mark_cells(cells, origin, rect.grow(6.0), occupied)
		if has_bounds and bounds.size.x >= STRUCTURE_MIN_WIDTH:
			structures.append(bounds)
	var keep_clear: Array[Rect2] = []
	var route_points: Array[Vector2] = []
	var hub := Vector2.INF
	for marker: Node in scene.find_children("*", "Marker2D", true, false):
		var at := (marker as Node2D).global_position
		keep_clear.append(Rect2(at - CLEAR_MARGIN, CLEAR_MARGIN * 2.0))
		route_points.append(at)
		if marker.name == &"SpawnDefault":
			hub = at
	for area: Node in scene.find_children("*", "Area2D", true, false):
		var area_bounds := Rect2((area as Node2D).global_position - CLEAR_MARGIN, CLEAR_MARGIN * 2.0)
		for shape_node: Node in area.find_children("*", "CollisionShape2D", true, false):
			var rect := _shape_rect(shape_node as CollisionShape2D)
			if rect.size != Vector2.ZERO:
				area_bounds = area_bounds.merge(rect.grow_individual(CLEAR_MARGIN.x, CLEAR_MARGIN.y, CLEAR_MARGIN.x, CLEAR_MARGIN.y))
		keep_clear.append(area_bounds)
		route_points.append(area_bounds.get_center())
	for node: Node in scene.find_children("*Door*", "Node2D", true, false):
		var at := (node as Node2D).global_position
		keep_clear.append(Rect2(at - CLEAR_MARGIN * 1.5, CLEAR_MARGIN * 3.0))
	if hub == Vector2.INF and not route_points.is_empty():
		hub = route_points[0]
	var corridor := _corridor(cells, occupied, origin, hub, route_points)
	# A map's authored paving stamps (`Paving*` ground decals) mark where its road runs; the
	# generated road band follows them, and the map hides the stamps.
	var road: Array[Vector2] = []
	for node: Node in scene.find_children("Paving*", "Sprite2D", true, false):
		road.append((node as Node2D).global_position)
	road.sort_custom(func(a: Vector2, b: Vector2) -> bool: return a.x < b.x)
	var roads: Array = [road] if road.size() >= 2 else []
	# Likewise its ford-puddle stamps (`PuddleFord*`) mark a wet bank, run north to south.
	var ford: Array[Vector2] = []
	for node: Node in scene.find_children("PuddleFord*", "Sprite2D", true, false):
		ford.append((node as Node2D).global_position)
	ford.sort_custom(func(a: Vector2, b: Vector2) -> bool: return a.y < b.y)
	var fords: Array = [ford] if ford.size() >= 2 else []
	return {
		"origin": origin, "cells": cells, "occupied": occupied, "structures": structures,
		"keep_clear": keep_clear, "corridor": corridor, "playable": playable, "roads": roads,
		"fords": fords,
	}


static func read_catalog(batch_path: String) -> Array[Dictionary]:
	var batch: Dictionary = JSON.parse_string(FileAccess.get_file_as_string(batch_path))
	var rows: Array[Dictionary] = []
	for asset: Dictionary in batch["assets"]:
		var texture := "res://" + str(asset["output_path"])
		if not ResourceLoader.exists(texture):
			continue
		var content_height := 224.0
		var image := Image.load_from_file(ProjectSettings.globalize_path(texture))
		if image != null and not image.is_empty():
			content_height = float(image.get_used_rect().size.y)
		rows.append({
			"id": str(asset["id"]), "texture": texture, "category": str(asset["category"]),
			"placement": str(asset["placement"]), "height_class": str(asset.get("height_class", "")),
			"content_height": content_height,
		})
	return rows


static func build_scene(result: Dictionary, seed_value: int, batch_path: String) -> Node2D:
	var root := Node2D.new()
	root.name = "LivedIn"
	root.set_script(LivedInScript)
	root.y_sort_enabled = true
	root.set("blocked_cells", result["blocked"])
	root.set("cover_cells", result["cover"])
	root.set("dressing_seed", seed_value)
	root.set("source_batch", batch_path)
	var ground := Node2D.new()
	ground.name = "GroundDetails"
	ground.z_index = -2
	root.add_child(ground)
	var shadows := Node2D.new()
	shadows.name = "DressingShadows"
	shadows.set_script(DressingShadowsScript)
	shadows.z_index = -1
	root.add_child(shadows)
	var props := Node2D.new()
	props.name = "Props"
	props.y_sort_enabled = true
	root.add_child(props)
	var counts := {}
	for row: Dictionary in result["placements"]:
		var id := str(row["id"])
		counts[id] = int(counts.get(id, 0)) + 1
		var sprite := Sprite2D.new()
		sprite.name = "%s-%02d" % [id.trim_prefix("kf-"), counts[id]]
		sprite.texture = load(str(row["texture"])) as Texture2D
		sprite.position = row["position"]
		sprite.scale = Vector2.ONE * float(row["scale"])
		sprite.flip_h = bool(row["flip_h"])
		if row.has("alpha"):
			sprite.self_modulate = Color(1.0, 1.0, 1.0, float(row["alpha"]))
		if row["layer"] == "ground":
			ground.add_child(sprite)
		else:
			sprite.offset = STANDING_OFFSET
			props.add_child(sprite)
	for child: Node in root.find_children("*", "", true, false):
		child.owner = root
	return root


static func _options(args: PackedStringArray) -> Dictionary:
	var options := {}
	var index := 0
	while index < args.size():
		var arg := args[index]
		if arg.begins_with("--") and index + 1 < args.size():
			options[arg.trim_prefix("--")] = args[index + 1]
			index += 2
		else:
			index += 1
	return options


static func _playable_rect(scene: Node, ground: TileMapLayer) -> Rect2:
	var walls := scene.find_child("Walls", false, false) as StaticBody2D
	var rects: Array[Rect2] = []
	if walls != null:
		for shape_node: Node in walls.get_children():
			if shape_node is CollisionShape2D:
				var rect := _shape_rect(shape_node as CollisionShape2D)
				if rect.size != Vector2.ZERO:
					rects.append(rect)
	if rects.size() >= 4:
		var outer := rects[0]
		for rect: Rect2 in rects:
			outer = outer.merge(rect)
		var thickness := INF
		for rect: Rect2 in rects:
			thickness = minf(thickness, minf(rect.size.x, rect.size.y))
		return outer.grow(-thickness)
	var used := ground.get_used_rect()
	var corners := [
		ground.to_global(ground.map_to_local(used.position)),
		ground.to_global(ground.map_to_local(used.end)),
		ground.to_global(ground.map_to_local(Vector2i(used.position.x, used.end.y))),
		ground.to_global(ground.map_to_local(Vector2i(used.end.x, used.position.y))),
	]
	var bounds := Rect2(corners[0], Vector2.ZERO)
	for corner: Vector2 in corners:
		bounds = bounds.expand(corner)
	return bounds


static func _shape_rect(shape_node: CollisionShape2D) -> Rect2:
	if shape_node == null or shape_node.shape == null or shape_node.disabled:
		return Rect2()
	var local := shape_node.shape.get_rect()
	var transform := shape_node.get_global_transform()
	var bounds := Rect2(transform * local.position, Vector2.ZERO)
	for corner: Vector2 in [local.position, Vector2(local.end.x, local.position.y), local.end, Vector2(local.position.x, local.end.y)]:
		bounds = bounds.expand(transform * corner)
	return bounds


static func _mark_cells(cells: Dictionary, origin: Vector2, rect: Rect2, occupied: Dictionary) -> void:
	var first := DresserScript.cell_at(origin, rect.position)
	var last := DresserScript.cell_at(origin, rect.end)
	var corners := [first, last, DresserScript.cell_at(origin, Vector2(rect.end.x, rect.position.y)),
		DresserScript.cell_at(origin, Vector2(rect.position.x, rect.end.y))]
	var low: Vector2i = corners[0]
	var high := low
	for corner: Vector2i in corners:
		low = Vector2i(mini(low.x, corner.x), mini(low.y, corner.y))
		high = Vector2i(maxi(high.x, corner.x), maxi(high.y, corner.y))
	for y: int in range(low.y - 1, high.y + 2):
		for x: int in range(low.x - 1, high.x + 2):
			var cell := Vector2i(x, y)
			if cells.has(cell) and rect.has_point(DresserScript.cell_center(origin, cell)):
				occupied[cell] = true


## Main routes: shortest walkable paths from the hub to every spawn, exit and door point.
static func _corridor(cells: Dictionary, occupied: Dictionary, origin: Vector2, hub: Vector2,
		points: Array[Vector2]) -> Dictionary:
	var corridor := {}
	if hub == Vector2.INF or cells.is_empty():
		return corridor
	var keys: Array = cells.keys()
	var region := Rect2i(keys[0], Vector2i.ONE)
	for cell: Vector2i in keys:
		region = region.expand(cell).expand(cell + Vector2i.ONE)
	var astar := AStarGrid2D.new()
	astar.region = region
	astar.diagonal_mode = AStarGrid2D.DIAGONAL_MODE_ONLY_IF_NO_OBSTACLES
	astar.update()
	for y: int in range(region.position.y, region.end.y):
		for x: int in range(region.position.x, region.end.x):
			var cell := Vector2i(x, y)
			if not cells.has(cell) or occupied.has(cell):
				astar.set_point_solid(cell, true)
	var start := _nearest_open(astar, DresserScript.cell_at(origin, hub))
	for point: Vector2 in points:
		var goal := _nearest_open(astar, DresserScript.cell_at(origin, point))
		if start == Vector2i(-9999, -9999) or goal == Vector2i(-9999, -9999):
			continue
		for cell: Vector2i in astar.get_id_path(start, goal, true):
			corridor[cell] = true
	return corridor


static func _nearest_open(astar: AStarGrid2D, cell: Vector2i) -> Vector2i:
	for radius: int in 4:
		for dy: int in range(-radius, radius + 1):
			for dx: int in range(-radius, radius + 1):
				var probe := cell + Vector2i(dx, dy)
				if astar.is_in_boundsv(probe) and not astar.is_point_solid(probe):
					return probe
	return Vector2i(-9999, -9999)
