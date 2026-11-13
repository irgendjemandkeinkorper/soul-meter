extends GdUnitTestSuite

const SCENE_PATH := "res://world/interiors/lower_trial_hall.tscn"
const DIALOGUE_PATH := "res://dialogue/lower_trial_hall.dialogue"
const ROOMS_DIALOGUE_PATH := "res://dialogue/lower_trial_hall_rooms.dialogue"
const CHARGE := "tools/blasting_charge"
## Each gate and the doorway cell of the rooms' plan it shuts.
const GATES := {
	"InteractionGate": Vector2i(23, 20),
	"SkillDoor": Vector2i(16, 12),
	"StoreDoor": Vector2i(11, 20),
	"BlastDoor": Vector2i(9, 8),
	"KeeperGate": Vector2i(4, 5),
}

var _original_party: Array[PartyMember]


func before_test() -> void:
	_original_party = GameState.party.duplicate(true)
	GameState.flags.clear()
	GameState.party.clear()
	GameState._seed_demo_data()
	SkillCheck._check_log.clear()


func after_test() -> void:
	if not Battle.ended:
		Battle._finish(BattleResult.State.FLED, &"fled")
	GameState.remove_items(CHARGE, GameState.item_count(CHARGE))
	GameState.flags.clear()
	GameState.party = _original_party


func test_scene_loads_with_every_gauntlet_beat() -> void:
	var hall: Node = auto_free((load(SCENE_PATH) as PackedScene).instantiate())
	add_child(hall)

	assert_object(hall.get_node("EntranceAide")).is_not_null()
	assert_object(hall.get_node("InteractionSwitch")).is_not_null()
	assert_object(hall.get_node("WardenTrigger")).is_not_null()
	assert_object(hall.get_node("TrialDoorKey")).is_not_null()
	assert_object(hall.get_node("SkillDoorExaminer")).is_not_null()
	assert_object(hall.get_node("TrialKeeper")).is_not_null()
	assert_object(hall.get_node("ExitToDom")).is_not_null()
	assert_str(hall.get_node("ExitToDom").required_flag).is_equal(
		"tutorial_gauntlet_complete"
	)


## Owner rulings 2026-11-04 ("Extend Lower Trial Hall", "Medium: ~10 rooms"): the hall is one
## plan of ten rooms laid on its walk grid cell for cell, and every room is reachable.
func test_the_hall_is_ten_rooms_on_its_walk_grid() -> void:
	var hall: Node = auto_free((load(SCENE_PATH) as PackedScene).instantiate())
	add_child(hall)
	var rooms := hall.get_node("TrialRooms") as WalkInBuilding
	var plan := rooms.plan()

	assert_array(Array(plan.problems())).is_empty()
	assert_int(plan.room_count).is_equal(10)
	var ground := hall.get_node("IsometricGround") as TileMapLayer
	assert_that(ground.get("map_size")).is_equal(plan.size)
	assert_bool(rooms.roofed).is_false()
	assert_object(rooms.get_node_or_null("WallBody")).is_not_null()
	for cell: Vector2i in GATES.values():
		assert_str(plan.at(cell)).is_equal(BuildingPlan.DOOR)


## Each gate shuts exactly its doorway cell on the walk grid, and lifts it when its beat opens.
func test_each_gate_seals_its_doorway_until_its_beat_opens() -> void:
	var hall: Node = auto_free((load(SCENE_PATH) as PackedScene).instantiate())
	add_child(hall)
	var ground := hall.get_node("IsometricGround") as TileMapLayer
	var blocking := hall.get_node("Blocking") as TileMapLayer
	for gate: String in GATES:
		var shape := hall.get_node("%s/CollisionShape2D" % gate) as CollisionShape2D
		assert_array(SolidFootprints.shape_cells(shape, hall, ground)).is_equal([GATES[gate]])
		assert_int(blocking.get_cell_source_id(GATES[gate])).override_failure_message(
			"%s must be painted shut" % gate
		).is_not_equal(-1)

	GameState.set_flag("tutorial_gauntlet_complete", true)
	await get_tree().physics_frame
	for gate: String in GATES:
		var shape := hall.get_node("%s/CollisionShape2D" % gate) as CollisionShape2D
		assert_bool(shape.disabled).override_failure_message("%s must open" % gate).is_true()
		assert_int(blocking.get_cell_source_id(GATES[gate])).is_equal(-1)


func test_a_quiet_pick_opens_the_store_without_waking_it() -> void:
	var hall: Node = auto_free((load(SCENE_PATH) as PackedScene).instantiate())
	add_child(hall)
	_configure_skill("slip", 95.0)
	SkillCheck.random_number_generator.seed = _successful_seed()
	var resource := load(ROOMS_DIALOGUE_PATH) as DialogueResource
	var response: DialogueResponse = await _response_containing(
		resource, "trial_store_door", "Lift the latch"
	)

	await DialogueManager.get_next_dialogue_line(resource, response.next_id)
	await get_tree().physics_frame

	assert_bool(GameState.flag_is_true("trial_store_door_open")).is_true()
	assert_bool(GameState.flag_is_true("trial_store_alarm")).is_false()
	assert_bool((hall.get_node("StoreDoor/CollisionShape2D") as CollisionShape2D).disabled).is_true()
	for warden: Hostile in _wardens(hall, "StoreWardens"):
		assert_bool(warden.is_unlocked()).is_false()


func test_forcing_the_store_door_wakes_the_store() -> void:
	var hall: Node = auto_free((load(SCENE_PATH) as PackedScene).instantiate())
	add_child(hall)
	var resource := load(ROOMS_DIALOGUE_PATH) as DialogueResource
	var response: DialogueResponse = await _response_containing(
		resource, "trial_store_door", "Put your shoulder"
	)

	await DialogueManager.get_next_dialogue_line(resource, response.next_id)

	assert_bool(GameState.flag_is_true("trial_store_door_open")).is_true()
	assert_bool(GameState.flag_is_true("trial_store_alarm")).is_true()
	for warden: Hostile in _wardens(hall, "StoreWardens"):
		assert_bool(warden.is_unlocked()).is_true()


## The user's ask (2026-11-04): "you have to use an explosive to get past one of the doors".
func test_only_a_blasting_charge_opens_the_blast_door_after_its_fuse() -> void:
	var hall: Node = auto_free((load(SCENE_PATH) as PackedScene).instantiate())
	add_child(hall)
	var resource := load(ROOMS_DIALOGUE_PATH) as DialogueResource
	var line: DialogueLine = await DialogueManager.get_next_dialogue_line(resource, "trial_blast_seam")
	assert_bool(line.responses.any(
		func(r: DialogueResponse) -> bool:
			return r.is_allowed and r.text.contains("Set the blasting charge")
	)).override_failure_message("no charge, no way to set one").is_false()

	GameState.inventory.create_and_add_item(CHARGE)
	var response: DialogueResponse = await _response_containing(
		resource, "trial_blast_seam", "Set the blasting charge"
	)
	await DialogueManager.get_next_dialogue_line(resource, response.next_id)

	assert_int(GameState.item_count(CHARGE)).is_equal(0)
	assert_bool(GameState.flag_is_true("trial_blast_charge_set")).is_true()
	assert_bool(GameState.flag_is_true("trial_blast_door_open")).override_failure_message(
		"the door goes when the cord has burned, not when it is lit"
	).is_false()
	await get_tree().create_timer(hall.BLAST_FUSE_SECONDS + 0.2).timeout
	await get_tree().physics_frame
	assert_bool(GameState.flag_is_true("trial_blast_door_open")).is_true()
	assert_bool((hall.get_node("BlastDoor/CollisionShape2D") as CollisionShape2D).disabled).is_true()


func test_a_charge_set_before_a_load_has_gone_off() -> void:
	GameState.set_flag("trial_blast_charge_set", true)
	var hall: Node = auto_free((load(SCENE_PATH) as PackedScene).instantiate())
	add_child(hall)

	assert_bool(GameState.flag_is_true("trial_blast_door_open")).is_true()


func test_a_side_room_stays_cleared_once_its_pair_is_down() -> void:
	var hall: Node = auto_free((load(SCENE_PATH) as PackedScene).instantiate())
	add_child(hall)
	var wardens := _wardens(hall, "WestWardens")
	assert_int(wardens.size()).is_equal(2)

	wardens[0].mark_downed()
	assert_bool(GameState.flag_is_true("trial_west_cleared")).is_false()
	wardens[1].mark_downed()
	assert_bool(GameState.flag_is_true("trial_west_cleared")).is_true()

	var again: Node = auto_free((load(SCENE_PATH) as PackedScene).instantiate())
	add_child(again)
	await get_tree().process_frame
	assert_bool(again.has_node("WestWardens")).is_false()
	assert_bool(again.has_node("StoreWardens")).is_true()


## The side rooms wake on the fight path only: the aide's skip leaves the west room and the store
## asleep, so a talked-through gauntlet stays peaceful on the way to the stair.
func test_the_side_rooms_sleep_until_their_beats() -> void:
	var hall: Node = auto_free((load(SCENE_PATH) as PackedScene).instantiate())
	add_child(hall)
	for warden: Hostile in _wardens(hall, "WestWardens") + _wardens(hall, "StoreWardens"):
		assert_bool(warden.is_unlocked()).is_false()

	GameState.set_flag("tutorial_gauntlet_complete", true)
	for warden: Hostile in _wardens(hall, "WestWardens") + _wardens(hall, "StoreWardens"):
		assert_bool(warden.is_unlocked()).is_false()
	GameState.set_flag("tutorial_warden_cleared", true)
	for warden: Hostile in _wardens(hall, "WestWardens"):
		assert_bool(warden.is_unlocked()).is_true()


## Each pair hears the party only in its own room: with a 128 px ear, no floor cell of another
## room is in reach (an iso wall puts the next room's cells close on screen).
func test_side_room_pairs_cannot_hear_through_their_walls() -> void:
	var hall: Node = auto_free((load(SCENE_PATH) as PackedScene).instantiate())
	add_child(hall)
	var rooms := hall.get_node("TrialRooms") as WalkInBuilding
	var plan := rooms.plan()
	var ground := hall.get_node("IsometricGround") as TileMapLayer
	for group: String in ["WestWardens", "StoreWardens", "AnnexWardens"]:
		var wardens := _wardens(hall, group)
		var home: Array[int] = plan.rooms_of(rooms.layout_cell_at(wardens[0].global_position))
		for j in plan.size.y:
			for i in plan.size.x:
				var cell := Vector2i(i, j)
				if plan.at(cell) != BuildingPlan.FLOOR or plan.rooms_of(cell) == home:
					continue
				if group == "WestWardens" and _is_beyond_the_west_room(plan, cell):
					continue
				var at := ground.to_global(ground.map_to_local(cell))
				for warden: Hostile in wardens:
					assert_float(warden.global_position.distance_to(at)).override_failure_message(
						"%s/%s hears %s through a wall" % [group, warden.name, cell]
					).is_greater(warden.alert_radius)


func test_entrance_speech_skip_success_unlocks_exit() -> void:
	_configure_skill("undertone", 95.0)
	SkillCheck.random_number_generator.seed = _successful_seed()
	var resource := load(DIALOGUE_PATH) as DialogueResource
	var response: DialogueResponse = await _response_containing(
		resource, "trial_aide", "Read the trial's intent"
	)

	await DialogueManager.get_next_dialogue_line(resource, response.next_id)

	assert_bool(GameState.flag_is_true("tutorial_gauntlet_complete")).is_true()
	var hall: Node = auto_free((load(SCENE_PATH) as PackedScene).instantiate())
	add_child(hall)
	assert_bool(hall.get_node("ExitToDom")._is_unlocked()).is_true()


func test_warden_trigger_starts_once_and_victory_opens_the_next_beat() -> void:
	var hall: Node = auto_free((load(SCENE_PATH) as PackedScene).instantiate())
	add_child(hall)
	var starts: Array[StringName] = []
	hall.trial_encounter_started.connect(func(id: StringName) -> void: starts.append(id))

	hall.request_warden_encounter()
	hall.request_warden_encounter()

	assert_array(starts).is_equal([&"trial-warden"])
	assert_str(Battle.encounter_id).is_equal("trial-warden")
	Battle._finish(BattleResult.State.VICTORY, &"slain")
	assert_bool(GameState.flag_is_true("tutorial_warden_cleared")).is_true()


func test_fled_warden_encounter_can_be_retried() -> void:
	var hall: Node = auto_free((load(SCENE_PATH) as PackedScene).instantiate())
	add_child(hall)
	var starts: Array[StringName] = []
	hall.trial_encounter_started.connect(func(id: StringName) -> void: starts.append(id))

	hall.request_warden_encounter()
	Battle._finish(BattleResult.State.FLED, &"fled")

	assert_bool(GameState.flag_is_true("tutorial_warden_started")).is_false()
	assert_bool(GameState.flag_is_true("tutorial_warden_cleared")).is_false()
	hall.request_warden_encounter()
	assert_array(starts).is_equal([&"trial-warden", &"trial-warden"])
	assert_str(Battle.encounter_id).is_equal("trial-warden")


func test_keeper_talk_success_completes_gauntlet() -> void:
	_configure_skill("sway", 95.0)
	SkillCheck.random_number_generator.seed = _successful_seed()
	var resource := load(DIALOGUE_PATH) as DialogueResource
	var response: DialogueResponse = await _response_containing(
		resource, "trial_keeper", "No blood is needed"
	)

	await DialogueManager.get_next_dialogue_line(resource, response.next_id)

	assert_bool(GameState.flag_is_true("tutorial_gauntlet_complete")).is_true()


func test_keeper_fight_starts_authored_battle_and_victory_completes_gauntlet() -> void:
	var hall: Node = auto_free((load(SCENE_PATH) as PackedScene).instantiate())
	add_child(hall)
	var resource := load(DIALOGUE_PATH) as DialogueResource
	var response: DialogueResponse = await _response_containing(
		resource, "trial_keeper", "Fight me"
	)

	await DialogueManager.get_next_dialogue_line(resource, response.next_id)
	await get_tree().process_frame

	assert_str(Battle.encounter_id).is_equal("trial-keeper")
	Battle._finish(BattleResult.State.VICTORY, &"slain")
	assert_bool(GameState.flag_is_true("tutorial_gauntlet_complete")).is_true()


func _response_containing(
	resource: DialogueResource, title: String, response_text: String
) -> DialogueResponse:
	var line: DialogueLine = await DialogueManager.get_next_dialogue_line(resource, title)
	assert_object(line).is_not_null()
	if line == null:
		return null
	for response: DialogueResponse in line.responses:
		if response.text.contains(response_text):
			assert_bool(response.is_allowed).is_true()
			return response
	fail("No response containing '%s' at dialogue title '%s'." % [response_text, title])
	return null


func _wardens(hall: Node, group: String) -> Array[Hostile]:
	var found: Array[Hostile] = []
	for child: Node in hall.get_node(group).get_children():
		if child is Hostile:
			found.append(child as Hostile)
	return found


## The quiet rooms lie past the west room's own door: the party reaches them only through it.
func _is_beyond_the_west_room(plan: BuildingPlan, cell: Vector2i) -> bool:
	return plan.rooms_of(cell) == plan.rooms_of(Vector2i(2, 16))


func _configure_skill(skill: String, advancement: float) -> void:
	var member: PartyMember = GameState.protagonist()
	assert_object(member).is_not_null()
	for attribute: String in member.attributes:
		member.attributes[attribute] = 0
	member.skill_tiers[skill] = "untrained"
	member.skill_percentages[skill] = advancement


func _successful_seed() -> int:
	var probe := RandomNumberGenerator.new()
	for candidate: int in range(1, 1000):
		probe.seed = candidate
		if probe.randi_range(1, 100) <= 95:
			return candidate
	return 1


## #281 D5: the trial fights are set-pieces fought in the hall itself. The warden must be a
## session on the hall's own field with a body standing in the room, and the body must leave
## with the fight.
func test_warden_fight_is_a_session_in_the_hall_with_a_spawned_body() -> void:
	var hall: Node = auto_free((load(SCENE_PATH) as PackedScene).instantiate())
	add_child(hall)

	hall.request_warden_encounter()

	assert_bool(Battle.session_active).override_failure_message(
		"the trial fight must open as a same-map session, interior or not"
	).is_true()
	assert_int(Battle.enemies.size()).is_greater(0)
	assert_int(Battle._spawned_hostiles.size()).is_equal(Battle.enemies.size())
	var bodies: Array[Hostile] = Battle._spawned_hostiles.duplicate()
	for body: Hostile in bodies:
		assert_bool(hall.is_ancestor_of(body)).override_failure_message(
			"the warden's body must stand in the hall, not in another scene"
		).is_true()
		assert_object(body.battle_actor()).is_same(Battle.enemies[bodies.find(body)])

	Battle._finish(BattleResult.State.VICTORY, &"slain")
	await get_tree().process_frame
	await get_tree().process_frame
	for body: Variant in bodies:
		assert_bool(is_instance_valid(body)).is_false()
