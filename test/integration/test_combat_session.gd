extends GdUnitTestSuite
## F1 steps 4-5: an ambient same-map session, opened by an alert on the loaded field.
##
## Covers the two owner rulings this handoff turned on. Ruling 4: the party fights from where
## it is standing, the player anchors, overlapping members are spread, and a refusal leaves the
## field exactly as it was. Ruling 5: chain alerts spread one hop per `measure_started` and
## never at session start, so the party always gets a window before the first reinforcement.

const TEST_ROOM_SCENE := "res://world/test_room.tscn"
const HOSTILE_SCENE := "res://actors/hostile/hostile.tscn"
const INTERIOR_SCENE := "res://world/interiors/building_interior.tscn"

var _game_state_before: Dictionary


func before_test() -> void:
	_game_state_before = GameState.to_dict().duplicate(true)


func after_test() -> void:
	# Battle is an autoload; a suite that leaves a session live poisons every suite after it.
	if Battle.session_active:
		Battle._end_session(null)
	Battle.controller = null
	Battle.ended = true
	GameState.from_dict(_game_state_before)


## Grows GameState.party to `size` without touching the tavern flow. The scene's followers do
## not resync inside one frame, so every extra member arrives stacked on the player — which is
## exactly the input ruling 4 exists to resolve.
func _stack_party(size: int) -> void:
	while GameState.party.size() < size and not GameState.party.is_empty():
		var extra := GameState.party[0].duplicate(true) as PartyMember
		extra.id = StringName("stacked-%d" % GameState.party.size())
		extra.display_name = "Stacked %d" % GameState.party.size()
		GameState.party.append(extra)


func _field() -> FieldMap:
	var scene: Node = (load(TEST_ROOM_SCENE) as PackedScene).instantiate()
	add_child(scene)
	await get_tree().process_frame
	return scene.find_child("FieldMap", true, false) as FieldMap


## Seats a hostile on a named cell of the live field, so its battlefield position is the cell
## the scene put it on rather than a default column seat.
func _hostile(field: FieldMap, node_name: String, cell: Vector2i) -> Hostile:
	var hostile := (load(HOSTILE_SCENE) as PackedScene).instantiate() as Hostile
	hostile.name = node_name
	hostile.unit_id = &"bog-wight"
	hostile.realert_cooldown = 0.0
	field.get_parent().add_child(hostile)
	hostile.global_position = field.iso_grid().cell_to_world(cell)
	hostile.sync_cell()
	return hostile


## Three party members, one field cell between them: arrival and teleport reset both stack the
## companions on the player, so this is what ambient entry actually looks like.
func test_start_session_seats_a_stacked_party_on_distinct_cells() -> void:
	var field := await _field()
	_stack_party(3)
	var wight := _hostile(field, "Wight", Vector2i(30, 30))
	var anchor := field.party_cells()[0]

	var opened := Battle.start_session(field, wight)
	assert_bool(opened.get("allowed", false)).override_failure_message(
		"the session must open: %s" % opened.get("message", "")
	).is_true()
	assert_bool(Battle.session_active).is_true()
	assert_int(wight.state).is_equal(Hostile.State.IN_COMBAT)
	assert_str(String(wight.combat_id)).is_not_empty()

	var seats: Array = opened["seats"]
	assert_int(seats.size()).override_failure_message(
		"every party member needs a seat"
	).is_equal(Battle.allies.size())
	assert_that(seats[0]).override_failure_message(
		"the player is the anchor and is never relocated"
	).is_equal(anchor)
	var distinct: Dictionary = {}
	for seat: Vector2i in seats:
		assert_bool(distinct.has(seat)).override_failure_message(
			"two party members were seated on %s" % seat
		).is_false()
		distinct[seat] = true
	# The hostile keeps the cell the scene authored; the party is spread around it, never
	# through it. Read from the opening result: positions move as soon as the clock runs.
	assert_that(opened["first_cell"]).is_equal(Vector2i(30, 30))
	assert_bool(distinct.has(Vector2i(30, 30))).override_failure_message(
		"a party member was seated on the hostile's cell"
	).is_false()

	# One occupant per cell at all times, party and hostile alike.
	var seen: Dictionary = {}
	for actor: BattleActor in Battle.allies + Battle.enemies:
		var handle := String(Battle.controller.battlefield.position_of(actor))
		assert_str(handle).override_failure_message(
			"%s was never seated" % actor.display_name
		).is_not_empty()
		assert_bool(seen.has(handle)).override_failure_message(
			"two combatants share cell %s" % handle
		).is_false()
		seen[handle] = true


func test_admitting_the_same_hostile_twice_is_idempotent() -> void:
	var field := await _field()
	var first := _hostile(field, "First", Vector2i(30, 30))
	var second := _hostile(field, "Second", Vector2i(31, 30))
	assert_bool(Battle.start_session(field, first).get("allowed", false)).is_true()

	var admitted := Battle.admit(second)
	assert_bool(admitted.get("allowed", false)).override_failure_message(
		"%s" % admitted.get("message", "")
	).is_true()
	var enemy_count := Battle.enemies.size()

	var again := Battle.admit(second)
	assert_bool(again.get("allowed", false)).is_true()
	assert_bool(again.get("already_admitted", false)).is_true()
	assert_int(Battle.enemies.size()).override_failure_message(
		"a repeated alert must not seat the same hostile twice"
	).is_equal(enemy_count)


## Ruling 5's cadence, asserted on the tick a hop lands rather than on the final state: a test
## that only checks "everyone ended up alerted" would pass just as happily if the whole chain
## fired in one frame, which is the bug the ruling exists to prevent.
func test_chain_alerts_spread_one_hop_per_measure_and_none_at_session_start() -> void:
	var field := await _field()
	var hop0 := _hostile(field, "Hop0", Vector2i(30, 30))
	var hop1 := _hostile(field, "Hop1", Vector2i(32, 30))
	var hop2 := _hostile(field, "Hop2", Vector2i(34, 30))
	# Reach exactly one hop: hop1 from hop0, hop2 from hop1, never hop2 from hop0.
	var one_hop := hop0.global_position.distance_to(hop1.global_position) + 1.0
	assert_float(hop0.global_position.distance_to(hop2.global_position)).is_greater(one_hop)
	for hostile: Hostile in [hop0, hop1, hop2]:
		hostile.chain_radius = one_hop

	assert_bool(Battle.start_session(field, hop0).get("allowed", false)).is_true()
	# Nothing propagates on the opening frame: hop 0 is admitted, the party gets its window.
	assert_int(hop1.state).override_failure_message(
		"a chain hop must not land at session start"
	).is_equal(Hostile.State.IDLE)
	assert_int(hop2.state).is_equal(Hostile.State.IDLE)

	# The measure counter is read after each drive step rather than inside the event handler:
	# Battle re-emits combat_event before it runs propagation, so a listener sees the state as
	# it was one instant before the hop lands.
	var measures := [0]
	Battle.combat_event.connect(
		func(event: CombatEvent) -> void:
			if event.type == &"measure_started":
				measures[0] = int(measures[0]) + 1
	)

	var hop1_measure := -1
	var hop2_measure := -1
	var guard := 0
	while guard < 400 and hop2_measure < 0:
		guard += 1
		if Battle.ended or Battle.controller == null:
			break
		if Battle.controller.state == CombatController.State.ALLY_TURN:
			if not bool(Battle.controller.submit_action(&"guard").get("allowed", false)):
				Battle.controller.end_turn()
		else:
			Battle.controller.end_turn()
		if hop1_measure < 0 and hop1.state != Hostile.State.IDLE:
			hop1_measure = int(measures[0])
		if hop2_measure < 0 and hop2.state != Hostile.State.IDLE:
			hop2_measure = int(measures[0])

	assert_int(hop1_measure).override_failure_message(
		"hop 1 was never pulled in (measures crossed: %d)" % int(measures[0])
	).is_greater_equal(1)
	assert_int(hop2_measure).override_failure_message(
		"hop 2 was never pulled in (measures crossed: %d)" % int(measures[0])
	).is_greater_equal(1)
	assert_int(hop2_measure).override_failure_message(
		"one hop per measure: hop 2 is two hops out, so it cannot arrive on the same "
		+ "measure as hop 1 (hop1 at measure %d, hop2 at measure %d)"
		% [hop1_measure, hop2_measure]
	).is_greater(hop1_measure)


func test_a_session_without_a_field_is_refused_and_leaves_the_hostile_idle() -> void:
	var field := await _field()
	var wight := _hostile(field, "Wight", Vector2i(30, 30))
	var blocked := Battle.start_session(null, wight)
	assert_bool(blocked.get("allowed", true)).is_false()
	assert_bool(Battle.session_active).is_false()
	assert_int(wight.state).override_failure_message(
		"a refused session must leave the hostile exactly as it was"
	).is_equal(Hostile.State.IDLE)


## F0 ruling 2: Dom interiors are combat-free. The zone rule has to short-circuit both ends —
## a session cannot open there, and a chain hop cannot land there either.
func test_a_no_combat_zone_refuses_both_session_start_and_propagation() -> void:
	var scene: Node = (load(INTERIOR_SCENE) as PackedScene).instantiate()
	add_child(scene)
	await get_tree().process_frame
	var field := scene.find_child("FieldMap", true, false) as FieldMap
	assert_object(field).is_not_null()
	assert_bool(field.no_combat_zone()).override_failure_message(
		"%s must be a no-combat zone for this test to mean anything" % INTERIOR_SCENE
	).is_true()

	var wight := (load(HOSTILE_SCENE) as PackedScene).instantiate() as Hostile
	wight.unit_id = &"bog-wight"
	wight.realert_cooldown = 0.0
	scene.add_child(wight)

	var blocked := Battle.start_session(field, wight)
	assert_bool(blocked.get("allowed", true)).is_false()
	assert_str(str(blocked["blocked_by"])).is_equal("no_combat_zone")
	assert_bool(Battle.session_active).is_false()
	assert_int(wight.state).is_equal(Hostile.State.IDLE)

	# Even with a live IN_COMBAT source standing next to it, nothing spreads in here.
	var neighbour := (load(HOSTILE_SCENE) as PackedScene).instantiate() as Hostile
	neighbour.unit_id = &"bog-wight"
	scene.add_child(neighbour)
	neighbour.state = Hostile.State.IN_COMBAT
	field.propagate_alerts()
	assert_int(wight.state).override_failure_message(
		"a chain hop must not land inside a no-combat zone"
	).is_equal(Hostile.State.IDLE)


func test_admit_without_a_live_session_is_refused() -> void:
	var field := await _field()
	var wight := _hostile(field, "Wight", Vector2i(30, 30))
	var refused := Battle.admit(wight)
	assert_bool(refused.get("allowed", true)).is_false()
	assert_str(str(refused["nearest_unblock"]["type"])).is_equal("live_session")
