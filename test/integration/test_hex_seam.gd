extends GdUnitTestSuite
## Hex slice H3 (owner item 34; docs/design/hex-grid-plan-2026-11-03.md): the seam between
## exploring and fighting. When a fight opens on hexes, every body walks the last step onto its
## seat: sampled frame by frame, no frame moves a body more than one walking step, even through
## the long frame that sets the fight up. The floor grid fades in under the fighters and fades out
## when the fight ends.

const TEST_ROOM_SCENE := "res://world/test_room.tscn"
const HOSTILE_SCENE := "res://actors/hostile/hostile.tscn"
const SAMPLE_FRAMES := 240

var _saved_state: Dictionary
var _setting_before: Variant
var _exploring_before: Variant


func before_test() -> void:
	_saved_state = GameState.to_dict().duplicate(true)
	_setting_before = ProjectSettings.get_setting(IsoGrid.HEX_SETTING, false)
	_exploring_before = GameState.get_setting(
		FieldGridLayer.SETTING_SECTION, FieldGridLayer.SETTING_KEY, false
	)
	ProjectSettings.set_setting(IsoGrid.HEX_SETTING, true)
	GameState.set_setting(FieldGridLayer.SETTING_SECTION, FieldGridLayer.SETTING_KEY, false)
	get_tree().root.size = Vector2i(1920, 1080)


func after_test() -> void:
	if Battle.session_active:
		Battle._end_session(null)
	Battle.controller = null
	Battle.ended = true
	UIManager.close_all()
	ProjectSettings.set_setting(IsoGrid.HEX_SETTING, _setting_before)
	GameState.set_setting(FieldGridLayer.SETTING_SECTION, FieldGridLayer.SETTING_KEY, _exploring_before)
	GameState.from_dict(_saved_state)


## Ambient entry stacks the companions on the player (arrival and teleport both do); the fight
## then spreads them over distinct hexes. Each walks there.
func test_an_ambient_fight_walks_the_party_onto_its_hex_seats() -> void:
	if GameState.party.is_empty():
		GameState._seed_demo_data()
	_ensure_companions(2)
	var scene: Node = (load(TEST_ROOM_SCENE) as PackedScene).instantiate()
	add_child(scene)
	await get_tree().process_frame
	await get_tree().process_frame
	var field := scene.find_child("FieldMap", true, false) as FieldMap
	var grid := field.iso_grid()
	assert_bool(grid.hex_mode).override_failure_message("the room did not load on hexes").is_true()
	var bodies := _party_bodies(field)
	for index: int in bodies.size():
		bodies[index].global_position = field.player().global_position + Vector2(9.0 + index, 4.0)
	var hostile := (load(HOSTILE_SCENE) as PackedScene).instantiate() as Hostile
	hostile.name = "SeamWight"
	hostile.unit_id = &"bog-wight"
	hostile.realert_cooldown = 0.0
	scene.add_child(hostile)
	hostile.global_position = grid.cell_to_world(grid.cell_at_square(Vector2i(30, 30)))
	hostile.sync_cell()
	var start := _positions(bodies)

	assert_bool(Battle.start_session(field, hostile).get("allowed", false)).is_true()
	field.field_hud().enter_combat(field)
	var motion := await _sample(bodies, start)
	var walked := _assert_walked_onto_seats(bodies, start, motion, grid)
	assert_int(bodies.size()).override_failure_message("no companion bodies to seat").is_equal(3)
	assert_int(walked).override_failure_message("the stacked companions did not walk").is_greater_equal(2)
	assert_bool(field.grid_layer().visible).is_true()
	field.field_hud().exit_combat()
	Battle._end_session(null)
	scene.queue_free()
	await get_tree().process_frame


func test_the_trial_hall_fight_walks_onto_its_hexes_and_the_grid_fades_in_and_out() -> void:
	GameState.flags.clear()
	if GameState.party.is_empty():
		GameState._seed_demo_data()
	var runner := scene_runner(GameFlow.TRIAL_SCENE)
	var root := runner.scene() as Node2D
	await runner.simulate_frames(3)
	var field := root.find_child("FieldMap", true, false) as FieldMap
	var grid := field.iso_grid()
	assert_bool(grid.hex_mode).override_failure_message("the hall did not load on hexes").is_true()
	var layer := field.grid_layer()
	assert_bool(layer.visible).override_failure_message("no grid while exploring by default").is_false()
	var bodies := _party_bodies(field)
	for index: int in bodies.size():
		bodies[index].global_position += Vector2(9.0 + 2.0 * index, 4.0)
	var start := _positions(bodies)

	root.call("request_warden_encounter")
	assert_bool(Battle.session_active).is_true()
	UIManager.close_all()
	GameFlow._on_battle_entered()
	var motion := await _sample(bodies, start)
	var walked := _assert_walked_onto_seats(bodies, start, motion, grid)
	assert_int(walked).override_failure_message("nobody had a step to walk").is_greater(0)
	# The grid is up under the fighters, drawn, and at fight strength.
	assert_bool(layer.visible).is_true()
	assert_float(layer.modulate.a).is_equal_approx(FieldGridLayer.COMBAT_ALPHA, 0.001)
	assert_int(layer.chunk_count()).is_greater(0)
	assert_int(layer.z_index).is_equal(-1)
	# The fight ends: the grid fades out.
	field.set_combat_mode(false)
	assert_bool(layer.visible).is_true()
	await await_millis(int((DS.DUR_SLOW + 0.2) * 1000.0))
	assert_bool(layer.visible).is_false()
	assert_float(layer.modulate.a).is_equal(0.0)


## Gives the party `count` companions (copies of the lead under new ids), so the field spawns
## follower bodies for them.
func _ensure_companions(count: int) -> void:
	var members: Array[PartyMember] = []
	members.assign(GameState.party)
	while members.size() < count + 1:
		var extra := members[0].duplicate(true) as PartyMember
		extra.id = StringName("seam-companion-%d" % members.size())
		extra.display_name = "Seam Companion %d" % members.size()
		members.append(extra)
	GameState.set_party(members)


func _party_bodies(field: FieldMap) -> Array[Node2D]:
	var bodies: Array[Node2D] = [field.player()]
	var followers := field.party_followers()
	if followers != null:
		for follower: PartyFollower in followers.followers():
			bodies.append(follower)
	return bodies


func _positions(bodies: Array[Node2D]) -> Array[Vector2]:
	var positions: Array[Vector2] = []
	for body: Node2D in bodies:
		positions.append(body.global_position)
	return positions


## Each body's largest one-frame step and the number of frames it moved, over SAMPLE_FRAMES.
func _sample(bodies: Array[Node2D], start: Array[Vector2]) -> Dictionary:
	var largest: Array[float] = []
	var frames: Array[int] = []
	var last := start.duplicate()
	for index: int in bodies.size():
		largest.append(0.0)
		frames.append(0)
	for _frame in SAMPLE_FRAMES:
		await get_tree().process_frame
		for index: int in bodies.size():
			var now := bodies[index].global_position
			var step := now.distance_to(last[index])
			largest[index] = maxf(largest[index], step)
			if step > 0.01:
				frames[index] += 1
			last[index] = now
	return {"largest": largest, "frames": frames}


## Every party member with a body ends on its model hex. One that had more than 2 px to go never
## moved more than one walking step (FieldMap's pace over at most SEAT_WALK_MAX_FRAME) in a frame,
## and a walk longer than two steps took at least three frames. Returns how many walked.
func _assert_walked_onto_seats(
	bodies: Array[Node2D], start: Array[Vector2], motion: Dictionary, grid: IsoGrid
) -> int:
	var model := Battle.controller.battlefield as GridBattlefieldModel
	var walked := 0
	for index: int in mini(bodies.size(), Battle.allies.size()):
		var actor: BattleActor = Battle.allies[index]
		var seat := grid.cell_to_world(model.cell_of(actor) as Vector2i)
		assert_float(bodies[index].global_position.distance_to(seat)).override_failure_message(
			"%s stands %s, its seat is %s" % [actor.display_name, bodies[index].global_position, seat]
		).is_less(0.5)
		var distance := start[index].distance_to(seat)
		if distance < 2.0:
			continue
		walked += 1
		var speed := maxf(FieldMap.SEAT_WALK_SPEED, distance / FieldMap.SEAT_WALK_LONGEST)
		var walking_step := speed * FieldMap.SEAT_WALK_MAX_FRAME
		var largest := float((motion["largest"] as Array)[index])
		assert_float(largest).override_failure_message(
			"%s jumped %.1f px of a %.1f px walk in one frame" % [actor.display_name, largest, distance]
		).is_less_equal(walking_step + 0.05)
		if distance > 2.0 * walking_step:
			assert_int(int((motion["frames"] as Array)[index])).is_greater_equal(3)
		print("HEXSEAM %s walked %.1f px over %d frames, largest frame step %.1f px (cap %.1f)" % [
			actor.display_name, distance, int((motion["frames"] as Array)[index]), largest, walking_step,
		])
	return walked
