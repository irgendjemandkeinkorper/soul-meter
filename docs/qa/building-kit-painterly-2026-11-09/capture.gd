extends Node
## Isolated rendered QA: the real Kesselford ground and layouts, with a synthetic party
## position (cyan diamond). No player saves, map changes, NPCs, or new character art.
## Run as a temporary autoload with SOUL_METER_KIT_CAPTURE=before|after.

const OUT := "res://docs/qa/building-kit-painterly-2026-11-09/"
const MAP := "res://world/kesselford.tscn"
const NODES := ["Wayhouse", "Chandlery", "Cottage", "Warehouse"]
const LABELS := ["tavern", "shop", "cottage", "warehouse"]

var _view: SubViewport
var _stage: Node2D
var _ground: TileMapLayer
var _camera: Camera2D
var _actor: Node2D
var _phase: String
var _evidence: Array[Dictionary] = []


func _ready() -> void:
	_phase = OS.get_environment("SOUL_METER_KIT_CAPTURE")
	if _phase in ["before", "after"]:
		_run.call_deferred()


func _run() -> void:
	for frame in 10:
		await get_tree().process_frame
	_view = SubViewport.new()
	_view.size = Vector2i(1280, 900)
	_view.own_world_3d = true
	_view.world_2d = World2D.new()
	_view.render_target_update_mode = SubViewport.UPDATE_ALWAYS
	add_child(_view)
	_stage = Node2D.new()
	_stage.y_sort_enabled = true
	_view.add_child(_stage)
	# Extract the actual field ground, without running the town's unrelated systems.
	var source := (load(MAP) as PackedScene).instantiate()
	_ground = SolidFootprints.find_ground(source)
	_ground.get_parent().remove_child(_ground)
	_ground.owner = null
	_stage.add_child(_ground)
	_ground.z_index = -10
	var backdrop := source.get_node("TerrainBackdrop") as Sprite2D
	source.remove_child(backdrop)
	backdrop.owner = null
	_stage.add_child(backdrop)
	_camera = Camera2D.new()
	_camera.zoom = Vector2(1.15, 1.15)
	_stage.add_child(_camera)
	_actor = Node2D.new()
	_actor.add_to_group(&"player")
	_actor.position = Vector2(-10000, -10000)
	_stage.add_child(_actor)
	var marker := Line2D.new()
	marker.points = PackedVector2Array([Vector2(0, -6), Vector2(12, 0), Vector2(0, 6), Vector2(-12, 0), Vector2(0, -6)])
	marker.width = 1.5
	marker.default_color = Color(0.45, 0.82, 0.85)
	marker.z_index = 20
	_actor.add_child(marker)
	var ok := true
	for index in NODES.size():
		var original := source.get_node("KesselfordDressing/SolidProps/" + NODES[index]) as WalkInBuilding
		var building := WalkInBuilding.new()
		building.name = NODES[index]
		building.layout = original.layout
		building.origin_cell = original.origin_cell
		building.quarter_turns = original.quarter_turns
		_stage.add_child(building)
		var plan := building.plan()
		var middle := building.corner(float(plan.size.x) * 0.5, float(plan.size.y) * 0.5)
		_camera.position = middle - Vector2(0, 95)
		_actor.position = building.corner(float(plan.size.x) + 2.5, float(plan.size.y) + 2.5)
		await _settle()
		ok = building.current_look() == WalkInBuilding.Look.OUTSIDE and ok
		ok = await _save(LABELS[index] + "-outside") and ok
		# Additional diagnostic: roof hidden, all walls standing, identical camera.
		var roof := building.get_node("Roof") as Sprite2D
		roof.visible = false
		ok = await _save(LABELS[index] + "-walls-up") and ok
		roof.visible = true
		var target := _party_cell(plan)
		_actor.position = building.corner(target.x + 0.5, target.y + 0.5)
		await _settle()
		ok = building.current_look() == WalkInBuilding.Look.INSIDE and ok
		ok = building.open_rooms() == plan.rooms_of(target) and ok
		ok = await _save(LABELS[index] + "-inside") and ok
		_evidence.append({"layout": LABELS[index], "turns": building.quarter_turns,
			"origin_cell": [building.origin_cell.x, building.origin_cell.y],
			"party_cell": [target.x, target.y], "open_rooms": building.open_rooms(),
			"current_look": building.current_look()})
		building.free()
		_actor.position = Vector2(-10000, -10000)
		await get_tree().process_frame
	# Field-only plate for the labelled contact sheet; same painted ground as the layouts.
	_camera.position = backdrop.position
	ok = await _save("field-ground") and ok
	source.free()
	var report := FileAccess.open(OUT + _phase + "-states.json", FileAccess.WRITE)
	report.store_string(JSON.stringify(_evidence, "\t") + "\n")
	print("KIT-CAPTURE: %s (%s; 12 layout captures + field plate)" % ["PASS" if ok else "FAIL", _phase])
	get_tree().quit(0 if ok else 1)


func _party_cell(plan: BuildingPlan) -> Vector2i:
	# Front-most open floor in the largest room; do not change any layout or door.
	var counts: Dictionary = {}
	for cell: Vector2i in plan.footprint_cells():
		if plan.at(cell) != BuildingPlan.FLOOR:
			continue
		for room: int in plan.rooms_of(cell):
			counts[room] = int(counts.get(room, 0)) + 1
	var largest := -1
	for room: int in counts:
		if largest == -1 or int(counts[room]) > int(counts[largest]):
			largest = room
	var target := Vector2i.ZERO
	for cell: Vector2i in plan.footprint_cells():
		if plan.at(cell) == BuildingPlan.FLOOR and largest in plan.rooms_of(cell):
			if cell.x + cell.y > target.x + target.y:
				target = cell
	return target


func _settle() -> void:
	await get_tree().create_timer(0.35).timeout
	await RenderingServer.frame_post_draw


func _save(suffix: String) -> bool:
	await get_tree().process_frame
	await RenderingServer.frame_post_draw
	var result := _view.get_texture().get_image().save_png(OUT + _phase + "-" + suffix + ".png")
	print("KIT-CAPTURE: %s-%s %s" % [_phase, suffix, error_string(result)])
	return result == OK
