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


## The field grid's cell at an authored ground cell's centre: the cell itself on squares, the hex
## there on hexes (hex slice H3b). The cells below are test_room ground cells.
func _on_grid(field: FieldMap, ground_cell: Vector2i) -> Vector2i:
	return field.iso_grid().cell_at_square(ground_cell)

## Seats a hostile on a named cell of the live field, so its battlefield position is the cell
## the scene put it on rather than a default column seat. A `group_id` names the encounter the
## ledger pays out for; a test that passes one must clear that group's `defeated_*` flag first,
## or the hostile retires itself in `_ready` and the returned node is already freed.
func _hostile(
	field: FieldMap, node_name: String, cell: Vector2i,
	unit_id: StringName = &"bog-wight", group_id: StringName = &""
) -> Hostile:
	var hostile := (load(HOSTILE_SCENE) as PackedScene).instantiate() as Hostile
	hostile.name = node_name
	hostile.unit_id = unit_id
	hostile.group_id = group_id
	hostile.realert_cooldown = 0.0
	field.get_parent().add_child(hostile)
	hostile.global_position = field.iso_grid().cell_to_world(_on_grid(field, cell))
	hostile.sync_cell()
	return hostile


## Drives the live session until it ends or `guard` steps pass. On the party's turn it strikes
## `target` when one is given and the strike is legal, otherwise it guards; every other state
## just advances the clock. A refused strike falls back to guarding, never to waiting (#479):
## FR-102a refuses a third consecutive wait, and the party never moves here, so a foe that is
## still out of reach after two waits would leave the loop refusing the same strike and the
## same wait until the guard ran out. Guarding is a committed action that resets the streak and
## hands the clock back to the foe, which is the one closing the distance.
## With `require_end`, a guard that runs out (or a controller that disappears) before the battle
## ends fails the test with a full diagnosis instead of a later null `last_result` (#479).
func _drive_until_ended(
	target: BattleActor = null, guard: int = 400, require_end: bool = true
) -> bool:
	var steps := 0
	var refusals: Array[String] = []
	while steps < guard and not Battle.ended and Battle.controller != null:
		steps += 1
		if Battle.controller.state == CombatController.State.ALLY_TURN:
			var action := &"strike" if target != null and target.is_alive() else &"guard"
			var submitted: Dictionary = Battle.controller.submit_action(action, target)
			if not bool(submitted.get("allowed", false)) and action != &"guard":
				refusals.append("step %d %s: %s" % [steps, action, _refusal_text(submitted)])
				action = &"guard"
				submitted = Battle.controller.submit_action(action)
			if not bool(submitted.get("allowed", false)):
				refusals.append("step %d %s: %s" % [steps, action, _refusal_text(submitted)])
				if not Battle.controller.end_turn():
					refusals.append(
						"step %d end_turn: %s" % [steps, _refusal_text(Battle.controller.last_refusal)]
					)
		elif not Battle.controller.end_turn():
			refusals.append("step %d end_turn outside ALLY_TURN" % steps)
	if Battle.ended:
		return true
	if require_end:
		fail(_drive_diagnosis(steps, guard, target, refusals))
	return false


func _refusal_text(refusal: Dictionary) -> String:
	return "%s: %s" % [
		str(refusal.get("blocked_by", refusal.get("reason", "?"))), str(refusal.get("message", "")),
	]


## Everything needed to tell a non-ending loop apart: who could not reach whom, why every
## action was refused, and what the scheduler and event log last said.
func _drive_diagnosis(
	steps: int, guard: int, target: BattleActor, refusals: Array[String]
) -> String:
	var lines: Array[String] = [
		"the battle did not end after %d of %d steps (Battle.ended=%s, session_active=%s)"
		% [steps, guard, Battle.ended, Battle.session_active],
	]
	var controller := Battle.controller
	if controller == null:
		lines.append("Battle.controller is null")
		return "\n".join(lines)
	lines.append("controller state=%s round=%d active=%s" % [
		CombatController.State.keys()[controller.state], controller.round_number,
		controller.active_actor().display_name if controller.active_actor() != null else "<none>",
	])
	lines.append("scheduler=%s" % JSON.stringify(controller.scheduler.to_dict()))
	var grid := controller.battlefield
	for actor: BattleActor in controller.allies + controller.enemies:
		lines.append("%s %s [%s] hp=%d/%d atk=%d def=%d ct_speed=%d guarding=%s cell=%s" % [
			actor.side, actor.display_name, actor.combat_id, actor.hp, actor.max_hp,
			actor.attack, actor.defense,
			controller.rules.charge_speed_for(actor) if controller.rules != null else -1,
			actor.guarding, str(grid.cell_of(actor)),
		])
	if target != null and not controller.allies.is_empty():
		var ally_cell: Variant = grid.cell_of(controller.allies[0])
		var foe_cell: Variant = grid.cell_of(target)
		if ally_cell is Vector2i and foe_cell is Vector2i:
			var delta: Vector2i = (foe_cell as Vector2i) - (ally_cell as Vector2i)
			lines.append("ally->target delta=%s chebyshev=%d manhattan=%d" % [
				delta, maxi(absi(delta.x), absi(delta.y)), absi(delta.x) + absi(delta.y),
			])
	var field := Battle._session_field
	if is_instance_valid(field):
		for hostile: Hostile in field.hostiles():
			lines.append("field hostile %s state=%s pos=%s cell=%s cooldown=%s" % [
				hostile.name, Hostile.State.keys()[hostile.state], hostile.global_position,
				hostile.cell, hostile.alert_cooldown_active(),
			])
	lines.append("last refusals (%d total):" % refusals.size())
	lines.append_array(refusals.slice(maxi(0, refusals.size() - 6)))
	var tail: Array[String] = []
	Battle.replay_combat_events(func(event: CombatEvent) -> void:
		var data := event.data.duplicate()
		data.erase("snapshot")
		tail.append("#%d %s %s->%s %s" % [
			event.sequence, event.type, event.actor_id, event.target_id,
			JSON.stringify(data).left(320),
		])
	)
	lines.append("event log tail (%d events):" % tail.size())
	lines.append_array(tail.slice(maxi(0, tail.size() - 16)))
	return "\n".join(lines)


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
	assert_that(opened["first_cell"]).is_equal(_on_grid(field, Vector2i(30, 30)))
	assert_bool(distinct.has(_on_grid(field, Vector2i(30, 30)))).override_failure_message(
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


func test_ambient_hud_updates_without_the_legacy_stage() -> void:
	var field := await _field()
	var hostile := _hostile(field, "OverlayWight", Vector2i(30, 30))
	var opened := Battle.start_session(field, hostile)
	assert_bool(opened.get("allowed", false)).is_true()
	# The field HUD stays up and grows its bar (owner 2026-11-01); no screen opens.
	var hud := field.field_hud()
	assert_bool(hud.visible).is_true()
	hud.enter_combat(field)
	var bar := hud.combat_bar
	assert_object(bar).is_not_null()
	assert_str((bar.get("_enemy_lbl") as Label).text).contains("BOG WIGHT")
	assert_int((bar.get("_party_box") as VBoxContainer).get_child_count()).is_greater(0)
	assert_object(field.combat_overlay()).is_not_null()
	assert_bool(hud.battle_interface.stage._backdrop.visible).is_false()
	hud.exit_combat()
	Battle._end_session(null)
	field.get_parent().queue_free()
	await get_tree().process_frame


func test_full_command_catalog_leaves_the_live_battlefield_visible() -> void:
	get_tree().root.size = Vector2i(1920, 1080)
	var field := await _field()
	var hostile := _hostile(field, "LayoutWight", Vector2i(30, 30))
	assert_bool(Battle.start_session(field, hostile).get("allowed", false)).is_true()
	var hud := field.field_hud()
	hud.enter_combat(field)
	await get_tree().create_timer(DS.DUR_BASE + 0.1).timeout
	await get_tree().process_frame
	var bar := hud.bar()
	var viewport := get_tree().root.get_visible_rect()
	assert_float(bar.size.y).override_failure_message("Commands must not push the field off-screen").is_less(viewport.size.y * 0.35)
	var open_window := hud.battle_interface.stage.open_window()
	assert_float(open_window.size.y).is_greater(viewport.size.y * 0.5)
	var combat_bar := hud.combat_bar
	assert_int((combat_bar.get("_action_buttons") as Array).size()).is_equal(Battle.available_actions().size())
	var scroll := combat_bar.find_child("ActionScroll", true, false) as ScrollContainer
	assert_object(scroll).is_not_null()
	var buttons: Array = combat_bar.get("_action_buttons")
	# Ready commands read at full label width; MORE lists the rest, scrolling inside the bar
	# rather than growing it.
	var first_ready := combat_bar.ready_buttons()[0]
	assert_float(first_ready.size.x).is_greater_equal(first_ready.get_combined_minimum_size().x - 0.5)
	combat_bar.set_show_all(true)
	await get_tree().process_frame
	# The MORE list sits under the ready flow; its last locked row is the farthest command.
	var last_button: Button = null
	for button: Button in buttons:
		if button.is_visible_in_tree() and button.disabled:
			last_button = button
	assert_object(last_button).is_not_null()
	scroll.ensure_control_visible(last_button)
	await get_tree().process_frame
	await get_tree().process_frame
	assert_int(scroll.scroll_vertical).override_failure_message(
		"MORE list must scroll to %s: scroll %s, stack %s, bar max %s, button %s" % [
			last_button.text, scroll.size, (scroll.get_child(0) as Control).size,
			scroll.get_v_scroll_bar().max_value, last_button.get_global_rect(),
		]
	).is_greater(0)
	assert_bool(scroll.get_global_rect().intersects(last_button.get_global_rect())).is_true()
	hud.exit_combat()
	Battle._end_session(null)
	field.get_parent().queue_free()
	await get_tree().process_frame


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
	# Reach exactly one hop: hop1 from hop0, hop2 from hop1, never hop2 from hop0. Hex centres
	# are not evenly spaced along a row of ground cells, so the longer hop sets the reach.
	var one_hop := maxf(
		hop0.global_position.distance_to(hop1.global_position),
		hop1.global_position.distance_to(hop2.global_position)
	) + 1.0
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


## Task 9 hostile slice: the Hostile node owns its BattleActor for the field's lifetime, so a
## serious injury taken in one session is still there when the same hostile opens the next.
func test_a_hostiles_serious_injury_survives_to_the_next_session_on_this_map() -> void:
	var field := await _field()
	var wight := _hostile(field, "Wight", Vector2i(30, 30))
	assert_bool(Battle.start_session(field, wight)["allowed"]).is_true()
	var actor := wight.battle_actor()
	actor.injuries["throat"] = {"injury_id": "throat-crushed", "location_id": "throat", "severity": "serious", "effects": {"voice_blocked": true}}
	actor.injuries["arm"] = {"injury_id": "arm-strained", "location_id": "arm", "severity": "minor", "effects": {}}
	Battle._end_session(null)
	Battle._release_field_grid()
	Battle.controller = null
	Battle.ended = true
	wight.state = Hostile.State.IDLE
	assert_array(wight.battle_actor().injuries.keys()).is_equal(["throat"])
	var reopened := Battle.start_session(field, wight)
	assert_bool(reopened["allowed"]).override_failure_message(str(reopened)).is_true()
	assert_bool(bool(Battle.enemies[0].injuries["throat"]["effects"]["voice_blocked"])).is_true()
	assert_bool(CombatInjury.voice_block(Battle.enemies[0]).is_empty()).is_false()


## F1 step 7 (D7): the ledger fires per `group_id` the moment that group's last member goes
## down, and the field hostile is left DOWNED so it never alerts again.
func test_downing_the_last_of_a_group_fires_its_ledger_and_marks_the_hostile_downed() -> void:
	var reputation_before := Reputation.to_dict().duplicate(true)
	GameState.set_flag("defeated_bog_wight", false)
	var field := await _field()
	var wight := _hostile(field, "Wight", Vector2i(30, 30), &"bog-wight", &"bog-wight")
	assert_bool(Battle.start_session(field, wight).get("allowed", false)).is_true()
	var foe := wight.battle_actor()
	foe.hp = 1
	var events_before := Reputation.event_count()

	if not _drive_until_ended(foe):
		return
	assert_bool(Battle.ended).override_failure_message("the session never resolved").is_true()
	assert_int(Battle.last_result.state).is_equal(BattleResult.State.VICTORY)
	assert_bool(GameState.flag_is_true("defeated_bog_wight")).override_failure_message(
		"the group's defeated_flag must be written when its last member falls"
	).is_true()
	assert_int(wight.state).is_equal(Hostile.State.DOWNED)
	assert_int(Reputation.event_count()).override_failure_message(
		"exactly one reputation entry per resolved group"
	).is_equal(events_before + 1)
	assert_str(Reputation.history(1)[0].faction).is_equal("ssae-seeders")
	assert_int(Battle.last_result.xp_awarded).is_greater(0)
	assert_bool(Battle.session_active).is_false()
	Reputation.from_dict(reputation_before)


func test_a_group_resolves_when_its_last_member_falls_while_the_session_continues() -> void:
	var reputation_before := Reputation.to_dict().duplicate(true)
	GameState.set_flag("defeated_bog_wight", false)
	GameState.set_flag("defeated_loam_boar", false)
	var field := await _field()
	var wight := _hostile(field, "Wight", Vector2i(30, 30), &"bog-wight", &"bog-wight")
	var boar := _hostile(field, "Boar", Vector2i(33, 30), &"loam-maddened-boar", &"loam-boar")
	assert_bool(Battle.start_session(field, wight).get("allowed", false)).is_true()
	assert_bool(Battle.admit(boar).get("allowed", false)).is_true()
	var foe := wight.battle_actor()
	foe.hp = 1
	boar.battle_actor().hp = 999
	boar.battle_actor().max_hp = 999

	var seen_live_resolution := [false]
	Battle.combat_event.connect(
		func(_event: CombatEvent) -> void:
			if Battle.session_active and GameState.flag_is_true("defeated_bog_wight"):
				seen_live_resolution[0] = true
	)
	# Drive only until the wight falls. Left longer, the 999-HP boar can overrun the party and
	# end the session, which is not what this test is about.
	for _step: int in 60:
		if wight.state == Hostile.State.DOWNED or Battle.ended:
			break
		_drive_until_ended(foe, 1, false)

	assert_bool(seen_live_resolution[0]).override_failure_message(
		"the bog-wight group must resolve while the boar keeps the session alive"
	).is_true()
	assert_int(wight.state).is_equal(Hostile.State.DOWNED)
	assert_bool(GameState.flag_is_true("defeated_loam_boar")).is_false()
	assert_int(boar.state).is_equal(Hostile.State.IN_COMBAT)
	Reputation.from_dict(reputation_before)


## D7 flee rule (ratified 2026-10-22, #506): `Battle.FLEE_MEASURES` full measures with no party
## member inside `alert_radius × Battle.FLEE_RADIUS_FACTOR` of any living hostile ends the session FLED. Survivors go back to
## IDLE at full HP and the ledger writes nothing.
func test_session_ends_fled_after_two_measures_with_no_party_in_reach() -> void:
	var reputation_before := Reputation.to_dict().duplicate(true)
	GameState.set_flag("defeated_bog_wight", false)
	var field := await _field()
	var wight := _hostile(field, "Wight", Vector2i(30, 30), &"bog-wight", &"bog-wight")
	assert_bool(Battle.start_session(field, wight).get("allowed", false)).is_true()
	var foe := wight.battle_actor()
	foe.hp = foe.max_hp - 1
	var events_before := Reputation.event_count()
	field.player().global_position = wight.global_position + Vector2(wight.alert_radius * 4.0, 0)
	for follower: Node2D in field.party_followers().followers():
		follower.global_position = field.player().global_position

	if not _drive_until_ended(null, 200):
		return
	assert_bool(Battle.ended).is_true()
	assert_int(Battle.last_result.state).is_equal(BattleResult.State.FLED)
	assert_int(wight.state).is_equal(Hostile.State.IDLE)
	assert_int(foe.hp).override_failure_message("a fled hostile heals to full").is_equal(foe.max_hp)
	assert_bool(GameState.flag_is_true("defeated_bog_wight")).is_false()
	assert_int(Reputation.event_count()).is_equal(events_before)
	assert_bool(Battle.session_active).is_false()
	Reputation.from_dict(reputation_before)


## #506: the flee rule is the ambient path's. A set piece under the same geometry (party far
## outside every body's reach) stays committed; the flee counter never moves.
func test_a_set_piece_cannot_be_fled_by_distance() -> void:
	var field := await _field()
	var opened := Battle.start_set_piece(field, &"dorthkor-vanguard")
	assert_bool(opened.get("allowed", false)).override_failure_message(
		"the set-piece must open: %s" % opened.get("message", "")
	).is_true()
	var far := Vector2.ZERO
	for body: Hostile in Battle._spawned_hostiles:
		far = far.max(body.global_position + Vector2(body.alert_radius * 4.0, 0))
	field.player().global_position = far
	for follower: Node2D in field.party_followers().followers():
		follower.global_position = far

	# The per-measure check runs with the party out of every body's reach: an ambient session
	# would end FLED after FLEE_MEASURES calls; a set piece must ignore it.
	for i in Battle.FLEE_MEASURES + 1:
		Battle._check_session_flee()
	assert_int(Battle._measures_out_of_reach).override_failure_message(
		"a set piece must not count measures toward a flight"
	).is_equal(0)
	assert_bool(Battle.ended).override_failure_message(
		"a set piece ended on the flee check"
	).is_false()
	assert_bool(Battle.session_active).is_true()

	_drive_until_ended(null, Battle.FLEE_MEASURES * 40, false)
	if Battle.ended:
		assert_int(Battle.last_result.state).override_failure_message(
			"a set piece ended FLED by distance"
		).is_not_equal(BattleResult.State.FLED)


## A field torn down under a live session (save load, fixture teardown) must not leave Battle
## holding a session that points at freed nodes; the fight ends as a flight instead.
func test_unloading_the_field_under_a_live_session_ends_it_as_a_flight() -> void:
	var field := await _field()
	var hostile := _hostile(field, "Wight", Vector2i(30, 30))
	var result: Dictionary = Battle.start_session(field, hostile)
	assert_bool(bool(result.get("allowed", false))).is_true()
	assert_bool(Battle.session_active).is_true()

	field.get_parent().free()
	await get_tree().process_frame

	assert_bool(Battle.session_active).is_false()
	assert_bool(Battle.ended).is_true()
	assert_int(Battle.last_result.state).is_equal(BattleResult.State.FLED)


## #281 D5: a set-piece has no authored field nodes, so Battle spawns one Hostile per encounter
## enemy. Each body must stand in for the actor `start()` already built (not a second one) and
## stand on the cell the battlefield model seated that actor on.
func test_a_set_piece_spawns_one_body_per_enemy_on_its_seated_cell() -> void:
	var field := await _field()
	var opened := Battle.start_set_piece(field, &"dorthkor-vanguard")
	assert_bool(opened.get("allowed", false)).override_failure_message(
		"the set-piece must open: %s" % opened.get("message", "")
	).is_true()
	assert_bool(Battle.session_active).is_true()
	assert_int(Battle.enemies.size()).is_equal(2)
	assert_int(Battle._spawned_hostiles.size()).is_equal(Battle.enemies.size())

	var model := Battle.controller.battlefield as GridBattlefieldModel
	assert_object(model).is_not_null()
	var seen: Dictionary = {}
	for ally: BattleActor in Battle.allies:
		seen[model.cell_of(ally)] = true
	for index in Battle.enemies.size():
		var actor := Battle.enemies[index]
		var body := Battle._spawned_hostiles[index]
		assert_object(body.battle_actor()).override_failure_message(
			"a set-piece body adopts the encounter's actor; it must not build its own"
		).is_same(actor)
		assert_int(body.state).is_equal(Hostile.State.IN_COMBAT)
		assert_str(String(body.combat_id)).is_equal(String(actor.combat_id))
		var seated: Variant = model.cell_of(actor)
		assert_bool(seated is Vector2i).is_true()
		assert_that(body.sync_cell()).override_failure_message(
			"the body must stand on the cell combat seated its actor on"
		).is_equal(seated)
		assert_bool(seen.has(seated)).override_failure_message(
			"no two combatants may share cell %s" % [seated]
		).is_false()
		seen[seated] = true


## The bodies exist only for the fight: ending the session frees them and leaves nothing in
## Battle pointing at them. Authored hostiles are not in this list and are not freed.
func test_ending_a_set_piece_frees_the_bodies_it_spawned_and_no_others() -> void:
	var field := await _field()
	var authored := _hostile(field, "Authored", Vector2i(30, 30))
	var opened := Battle.start_set_piece(field, &"dorthkor-vanguard")
	assert_bool(opened.get("allowed", false)).is_true()
	var bodies: Array[Hostile] = Battle._spawned_hostiles.duplicate()
	assert_int(bodies.size()).is_equal(2)

	Battle._end_session(null)
	await get_tree().process_frame
	await get_tree().process_frame

	assert_bool(Battle.session_active).is_false()
	assert_int(Battle._spawned_hostiles.size()).is_equal(0)
	for body: Variant in bodies:
		assert_bool(is_instance_valid(body)).override_failure_message(
			"a set-piece body must not outlive its session"
		).is_false()
	assert_bool(is_instance_valid(authored)).override_failure_message(
		"an authored hostile is the scene's, not the set-piece's, and must survive"
	).is_true()


## A set-piece body is exempt from the `defeated_*` retirement an authored hostile makes in
## `_ready`: its actor is already in the controller, so a retired body would leave the fight
## with an enemy nobody can see.
func test_a_set_piece_body_is_not_retired_by_its_encounters_defeated_flag() -> void:
	var field := await _field()
	var flag := EncounterCatalog.defeated_flag(&"dorthkor-vanguard")
	if not flag.is_empty():
		GameState.set_flag(flag, true)
	var opened := Battle.start_set_piece(field, &"dorthkor-vanguard")
	if not bool(opened.get("allowed", false)):
		# The composition builder may refuse a beaten encounter outright; then there is no
		# fight and so nothing to keep visible.
		assert_int(Battle._spawned_hostiles.size()).is_equal(0)
		return
	await get_tree().process_frame
	assert_int(Battle._spawned_hostiles.size()).is_equal(Battle.enemies.size())
	for body: Hostile in Battle._spawned_hostiles:
		assert_bool(is_instance_valid(body) and not body.is_queued_for_deletion()).is_true()


## An authored encounter is placed by design, so it opens inside a no-combat interior where an
## ambient alert is refused (F0 ruling 2 binds ambient sessions only).
func test_a_set_piece_opens_inside_a_no_combat_zone() -> void:
	var scene: Node = (load(INTERIOR_SCENE) as PackedScene).instantiate()
	add_child(scene)
	await get_tree().process_frame
	var field := scene.find_child("FieldMap", true, false) as FieldMap
	assert_bool(field.no_combat_zone()).is_true()
	assert_bool(Battle.can_fight_here(field).get("allowed", true)).is_false()
	assert_bool(Battle.can_fight_here(field, true).get("allowed", false)).is_true()


## #345: a spawn-slot group is a day-stamped slot id, not an `EncounterCatalog` encounter. Its
## last member falling must resolve through the same F0 ledger hook (XP, no `defeated_*` flag to
## write) and clear the slot, without the hook ever treating the slot id as an encounter.
func test_a_spawn_slot_group_resolves_through_the_ledger_and_clears_its_slot() -> void:
	var clock_before := WorldClock.to_dict()
	var field := await _field()
	var anchor := Marker2D.new()
	anchor.name = "SpawnSlotLedgerTest"
	field.get_parent().add_child(anchor)
	anchor.global_position = field.iso_grid().cell_to_world(_on_grid(field, Vector2i(30, 30)))
	SpawnDirector.set_tables_for_testing({TEST_ROOM_SCENE: [{
		"schema": SpawnDirector.TABLE_SCHEMA,
		"id": "ledger-test",
		"scene_path": TEST_ROOM_SCENE,
		"slots": [{
			"id": "solo",
			"anchor": "SpawnSlotLedgerTest",
			"respawn_days": 1,
			"entries": [{"archetype_id": "bog-wight", "weight": 1}],
			"pack_size": {"min": 1, "max": 1},
		}],
	}]})
	WorldClock.phase_count = 4 * WorldClock.PHASES.size()
	var director := SpawnDirector.new()
	var spawned := director.populate(field.get_parent(), {
		"world_seed": 7, "day_index": 4, "respawn_policy": "wilderness",
		"thinning_tier": 0, "zhavar_rung_index": 0,
	})
	assert_int(spawned.size()).is_equal(1)
	var wight := spawned[0]
	wight.realert_cooldown = 0.0
	wight.sync_cell()
	assert_bool(Battle.start_session(field, wight).get("allowed", false)).is_true()
	var foe := wight.battle_actor()
	foe.hp = 1

	if not _drive_until_ended(foe):
		SpawnDirector.set_tables_for_testing({}, true)
		WorldClock.from_dict(clock_before)
		return
	assert_int(Battle.last_result.state).is_equal(BattleResult.State.VICTORY)
	assert_int(wight.state).is_equal(Hostile.State.DOWNED)
	assert_int(Battle.last_result.xp_awarded).is_greater(0)
	var slot := director.slot_state("ledger-test", "solo")
	assert_array(slot["members"]).is_empty()
	assert_int(int(slot["cleared_day"])).is_equal(4)
	SpawnDirector.set_tables_for_testing({}, true)
	WorldClock.from_dict(clock_before)


## #479: with the party seated one cell further out, the wight is still two cells away when the
## party's third turn comes round (Vex charges at 5, the wight at 6 and walks three cells per
## 60-CT move). The old drive loop answered every refused strike with a wait, hit FR-102a's
## two-wait cap, and then refused the same strike and the same wait until its guard ran out:
## the CI hang. The loop must commit an action instead, so the wight gets the clock back.
func test_the_drive_loop_outlasts_the_wait_cap_when_the_foe_is_still_out_of_reach() -> void:
	var field := await _field()
	field.player().global_position = field.iso_grid().cell_to_world(_on_grid(field, Vector2i(35, 36)))
	var wight := _hostile(field, "Wight", Vector2i(30, 30))
	var opened := Battle.start_session(field, wight)
	assert_bool(opened.get("allowed", false)).is_true()
	assert_that(opened["seats"][0]).is_equal(_on_grid(field, Vector2i(35, 36)))
	var foe := wight.battle_actor()
	foe.hp = 1

	if not _drive_until_ended(foe, 40):
		return
	assert_int(Battle.last_result.state).is_equal(BattleResult.State.VICTORY)


## SR7 (owner, 2026-11-08): losing an ambient fight is not a game over. HP is halved as built,
## a PROVISIONAL share of coin is lost, the beating group's authored loss stake writes ONE
## Reputation entry, and the result names the nearest discovered hub to wake at. The field
## gets no checkpoint: GameFlow requests the session's one checkpoint at the hub.
func test_losing_an_ambient_fight_costs_coin_and_standing_and_names_the_wake_hub() -> void:
	var reputation_before := Reputation.to_dict().duplicate(true)
	var autosave_before := SaveGame._pending_autosave_reason
	SaveGame._pending_autosave_reason = ""
	GameState.set_flag("defeated_bog_wight", false)
	GameState.discover_fast_travel_hub(&"dom")
	GameState.discover_fast_travel_hub(&"kesselford")
	GameState.set_gp(205)
	var field := await _field()
	var wight := _hostile(field, "Wight", Vector2i(30, 30), &"bog-wight", &"bog-wight")
	assert_bool(Battle.start_session(field, wight).get("allowed", false)).is_true()
	var lead: PartyMember = GameState.party[0]
	var events_before := Reputation.event_count()

	Battle.controller.force_finish(CombatController.ResultState.DEFEAT, Battle.OUTCOME_DEFEAT)
	await get_tree().process_frame

	var result: BattleResult = Battle.last_result
	assert_int(result.state).is_equal(BattleResult.State.DEFEAT)
	assert_bool(Battle.session_active).is_false()
	assert_int(lead.hp).is_equal(maxi(1, ceili(lead.max_hp * 0.5)))
	assert_int(result.coin_lost).override_failure_message("10% of 205 gp, rounded down").is_equal(20)
	assert_int(GameState.gp).is_equal(185)
	assert_int(Reputation.event_count()).override_failure_message(
		"an ambient defeat writes exactly one reputation entry"
	).is_equal(events_before + 1)
	assert_str(Reputation.history(1)[0].faction).is_equal("ssae-seeders")
	assert_float(Reputation.history(1)[0].delta).is_equal(-3.0)
	# test_room is the Wilds: Dom is 8 steps away, Kesselford 18.
	assert_str(String(result.wake_hub_id)).is_equal("dom")
	assert_int(result.xp_awarded).is_equal(0)
	assert_bool(GameState.flag_is_true("defeated_bog_wight")).is_false()
	assert_str(SaveGame._pending_autosave_reason).override_failure_message(
		"the field must not be checkpointed under the beaten party"
	).is_equal("")
	Reputation.from_dict(reputation_before)
	SaveGame._pending_autosave_reason = autosave_before
