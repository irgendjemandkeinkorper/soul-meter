extends GdUnitTestSuite
## Rendered evidence for #652 gap 3 (owner item 48d, 2026-11-20): Dorthkor Road's rock outcrops
## are climbable high ground. The player stands on the Warn Rock; in the vanguard fight the acting
## ally climbs a rock's rim beside the hound, and the strike below carries the height advantage. Run explicitly with a display at 1920x1080:
##   SOUL_METER_HEADLESS=0 scripts/test.sh -a test/manual/rock_height_capture.gd
## Frames land in user://qa/rock-height/*.png. Frame 02 draws a QA-only overlay of the height
## cells; the game itself draws no height on a painted map.

const OUT_DIR := "user://qa/rock-height"
const MAP := "res://world/dorthkor_road.tscn"
const HOUND := "BreachHound"
const HOUND_NAME := "Breach"
const NO_CELL := Vector2i(-99999, -99999)

var _saved_state: Dictionary
var _saved_reputation: Dictionary


func before_test() -> void:
	_saved_state = GameState.to_dict().duplicate(true)
	_saved_reputation = Reputation.to_dict().duplicate(true)
	get_tree().root.size = Vector2i(1920, 1080)
	DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path(OUT_DIR))


func after_test() -> void:
	if Battle.session_active:
		Battle._end_session(null)
	Battle.controller = null
	Battle.ended = true
	UIManager.close_all()
	GameState.from_dict(_saved_state)
	Reputation.from_dict(_saved_reputation)


func _capture(name: String) -> void:
	RenderingServer.force_draw()
	await RenderingServer.frame_post_draw
	var image := get_viewport().get_texture().get_image()
	var path := "%s/%s.png" % [OUT_DIR, name]
	assert_int(image.save_png(path)).is_equal(OK)
	print("SHOT ", ProjectSettings.globalize_path(path))


func test_the_warn_rock_is_high_ground() -> void:
	GameState.flags.clear()
	if GameState.party.is_empty():
		GameState._seed_demo_data()
	var runner := scene_runner(MAP)
	var root := runner.scene() as Node2D
	await runner.simulate_frames(3)
	var boot_scene := get_tree().current_scene as CanvasItem
	if boot_scene != null and boot_scene != root:
		boot_scene.hide()
	var field := root.find_child("FieldMap", true, false) as FieldMap
	var grid := field.iso_grid()
	var terrain := root.find_child("Terrain", true, false) as CombatTerrainLayer
	var heights := {}
	for square: Vector2i in terrain.elevation_one_cells:
		for cell: Vector2i in grid.cells_on_square(square):
			heights[cell] = 1
	for square: Vector2i in terrain.elevation_two_cells:
		for cell: Vector2i in grid.cells_on_square(square):
			heights[cell] = 2
	var warn_rock := root.find_child("WarnRock", true, false) as Node2D
	var player := field.player()
	var camera := player.get_node("Camera2D") as Camera2D
	camera.enabled = true
	camera.make_current()

	# 1. Out of a fight the rock no longer stops the walk: the player stands on its top.
	# Left of the rock's middle: the warning post on its right would hide the player.
	var top := _open_cell_near(grid, heights, 2, warn_rock.global_position + Vector2(-70.0, 30.0))
	assert_bool(top != NO_CELL).override_failure_message("no open top cell").is_true()
	player.global_position = grid.cell_to_world(top)
	camera.reset_smoothing()
	await runner.simulate_frames(20, 16)
	await _capture("01-standing-on-the-warn-rock")

	# 2. QA overlay only: which cells are height 1 (amber) and 2 (red).
	var overlay := HeightOverlay.new()
	overlay.grid = grid
	overlay.heights = heights
	overlay.z_index = 4096
	root.add_child(overlay)
	await runner.simulate_frames(3, 16)
	await _capture("02-qa-height-cells")
	overlay.queue_free()

	# 3. The vanguard waits below the rim; the party stands on the rim and the fight opens there.
	var hound := root.find_child(HOUND, true, false) as Hostile
	var pair := _rim_beside_ground(grid, heights, warn_rock.global_position)
	assert_bool(pair.is_empty()).override_failure_message("no rim cell beside open ground").is_false()
	player.global_position = grid.cell_to_world(pair["rim"])
	hound.global_position = grid.cell_to_world(pair["ground"])
	# Frame 1 had no flow watching, so a sighting then left the hound alerted with no fight.
	hound.state = Hostile.State.IDLE
	camera.reset_smoothing()
	GameFlow.watch_field_hostiles()
	await runner.simulate_frames(3)
	hound.realert_cooldown = 0.0
	hound._refresh_lock()
	hound._set_sensor_enabled(true)
	hound._check_initial_overlap()
	for _frame: int in 60:
		if Battle.session_active:
			break
		await runner.simulate_frames(1)
	assert_bool(Battle.session_active).override_failure_message(
		"standing beside the hound must open the vanguard fight"
	).is_true()
	UIManager.close_all()
	var field_hud := field.field_hud()
	for layer: Node in root.find_children("*", "CanvasLayer", true, false):
		if layer != field_hud:
			(layer as CanvasLayer).hide()
	field.set_combat_mode(true)
	field_hud.enter_combat(field)
	for ally: BattleActor in Battle.allies:
		ally.max_hp = 999
		ally.hp = 999
	# Enemies pass their turns, so the hound stays below the rim. Other allies guard until the one
	# standing on the rim beside the hound has the turn.
	var model := Battle.controller.battlefield as GridBattlefieldModel
	var target := _enemy_named(HOUND_NAME)
	assert_object(target).override_failure_message("the hound is not in the fight").is_not_null()
	# Enemies pass their turns, so the hound stays below the rim; stop at the first ally turn.
	for _step: int in 40:
		if Battle.controller.state == CombatController.State.ALLY_TURN:
			break
		Battle.controller.end_turn()
		await runner.simulate_frames(10, 16)
	var ally := Battle.current_ally()
	var target_cell: Vector2i = model.cell_of(target)
	var ally_cell: Vector2i = model.cell_of(ally)
	# The fight seats the party a step back, so the acting ally climbs onto the rim beside the hound.
	if not (model.elevation_at(ally_cell) >= 1 and GridMetric.distance(ally_cell, target_cell) == 1):
		var climb := _climb_beside(model, ally, target_cell)
		assert_str(String(climb)).override_failure_message("no rim cell beside the hound").is_not_empty()
		var moved := Battle.controller.submit_action(&"move", null, {"destination": climb})
		print("MOVE ", ally.display_name, " to ", climb, " allowed=", moved.get("allowed", false),
			" ct=", moved.get("ct_cost", "?"))
		await runner.simulate_frames(40, 16)
	for _index: int in Battle.enemies.size():
		if Battle.current_target() == target:
			break
		Battle.select_next_enemy()
	await runner.simulate_frames(5, 16)
	var context := Battle.forecast_context()
	print("FORECAST ally=", ally.display_name, " ally_height=", model.elevation_at(model.cell_of(ally)),
		" target=", target.display_name, " target_height=", model.elevation_at(model.cell_of(target)),
		" height_advantage_steps=", context.get("height_advantage_steps", "?"))
	assert_int(int(context.get("height_advantage_steps", 0))).is_greater(0)
	var interfaces := field_hud.find_children("*", "BattleInterface", true, false)
	if not interfaces.is_empty():
		(interfaces[0] as BattleInterface).set_breakdown_visible(true)
	camera.reset_smoothing()
	await runner.simulate_frames(20, 16)
	await _capture("03-strike-from-the-rim")
	field_hud.exit_combat()


## The open cell of `height` nearest `near`, or NO_CELL.
func _open_cell_near(grid: IsoGrid, heights: Dictionary, height: int, near: Vector2) -> Vector2i:
	var best := NO_CELL
	var best_distance := INF
	for cell: Vector2i in heights:
		if int(heights[cell]) != height or grid.is_blocked_for(cell):
			continue
		var distance := grid.cell_to_world(cell).distance_to(near)
		if distance < best_distance:
			best = cell
			best_distance = distance
	return best


## An open height-1 cell of any outcrop with an open ground neighbour, the pair nearest the vanguard
## side (north-east of the rock): {"rim", "ground"}, or {} when there is none.
func _rim_beside_ground(grid: IsoGrid, heights: Dictionary, rock: Vector2) -> Dictionary:
	var toward := rock + Vector2(300.0, -200.0)
	var best := {}
	var best_distance := INF
	for cell: Vector2i in heights:
		if int(heights[cell]) != 1 or grid.is_blocked_for(cell):
			continue
		for offset: Vector2i in grid.neighbor_offsets():
			var ground := cell + offset
			if heights.has(ground) or not grid.is_in_bounds(ground) or grid.is_blocked_for(ground):
				continue
			var distance := grid.cell_to_world(ground).distance_to(toward)
			if distance < best_distance:
				best = {"rim": cell, "ground": ground}
				best_distance = distance
	return best


func _enemy_named(name: String) -> BattleActor:
	for enemy: BattleActor in Battle.living_enemies():
		if enemy.display_name.contains(name):
			return enemy
	return null


## A destination the ally can afford now: a raised cell beside `target_cell`, lowest first.
func _climb_beside(model: GridBattlefieldModel, ally: BattleActor, target_cell: Vector2i) -> StringName:
	var best: StringName = &""
	var best_height := 1 << 30
	for row: Dictionary in Battle.controller.reachable_for(ally):
		var handle := String(row["destination"])
		var parts := handle.trim_prefix("c:").split(",")
		if parts.size() < 2:
			continue
		var cell := Vector2i(int(parts[0]), int(parts[1]))
		var height := model.elevation_at(cell)
		if height >= 1 and height < best_height and GridMetric.distance(cell, target_cell) == 1:
			best = StringName(handle)
			best_height = height
	return best


## QA-only: outlines each height cell, amber for 1 and red for 2, with its height.
class HeightOverlay:
	extends Node2D

	var grid: IsoGrid
	var heights: Dictionary = {}

	func _draw() -> void:
		var font := ThemeDB.fallback_font
		for cell: Vector2i in heights:
			var height := int(heights[cell])
			var colour := Color(1.0, 0.65, 0.1) if height == 1 else Color(0.95, 0.15, 0.15)
			var points := PackedVector2Array()
			for point: Vector2 in grid.cell_outline(cell):
				points.append(to_local(point))
			var fill := colour
			fill.a = 0.28
			draw_colored_polygon(points, fill)
			var closed := points.duplicate()
			closed.append(points[0])
			draw_polyline(closed, colour, 1.5)
			var centre := to_local(grid.cell_to_world(cell))
			draw_string(font, centre + Vector2(-4, 5), str(height), HORIZONTAL_ALIGNMENT_LEFT, -1, 14, Color.WHITE)
