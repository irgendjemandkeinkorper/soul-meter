extends GdUnitTestSuite

const BattleStageScript := preload("res://ui/screens/battle_stage.gd")

var stage


func before_test() -> void:
	Juicee.accessibility.reduced_motion = false
	stage = auto_free(BattleStageScript.new())
	stage.size = Vector2(1280, 720)
	add_child(stage)
	stage.set_reduced_motion(false)


func after_test() -> void:
	Juicee.accessibility.reduced_motion = false


func test_damage_event_starts_hit_feedback_and_scaled_motion() -> void:
	stage.consume_event(_event(
		&"action_resolved",
		1,
		&"ally-0",
		&"enemy-0",
		{"damage": 6, "ap_cost": 2},
		_snapshot(30, 24),
	))

	assert_int(stage.feedback_count(&"hit")).is_equal(1)
	assert_str(stage.feedback_text(&"hit")).contains("6")
	assert_bool(stage.active_motion_count() > 0).is_true()


func test_defining_strike_has_a_distinct_cue_even_when_the_check_misses() -> void:
	stage.consume_event(_event(
		&"action_resolved",
		2,
		&"ally-0",
		&"enemy-0",
		{
			"damage": 0,
			"ap_cost": 4,
			"defining_strike": true,
			"weakness_name": "The oath that binds it",
		},
		_snapshot(),
	))

	assert_int(stage.feedback_count(&"defining_strike")).is_equal(1)
	assert_int(stage.feedback_count(&"hit")).is_equal(0)
	assert_str(stage.feedback_text(&"defining_strike")).contains("DEFINING STRIKE")
	assert_str(stage.feedback_text(&"defining_strike")).contains("OATH")


func test_balance_extreme_announces_that_the_whole_field_changed() -> void:
	stage.consume_event(_event(
		&"balance_band_changed",
		3,
		&"",
		&"",
		{
			"band_id": &"order_extreme",
			"effects": {"damage_bonus": 2},
			"affected_actor_ids": [&"ally-0", &"enemy-0"],
		},
		_snapshot(30, 30, &"front", 50),
	))

	assert_int(stage.feedback_count(&"balance_extreme")).is_equal(1)
	assert_str(stage.feedback_text(&"balance_extreme")).contains("ORDER EXTREME")
	assert_str(stage.feedback_text(&"balance_extreme")).contains("WHOLE FIELD")


func test_reduced_motion_suppresses_motion_but_keeps_damage_and_signature_information() -> void:
	stage.set_reduced_motion(true)
	stage.consume_event(_event(
		&"action_resolved",
		4,
		&"ally-0",
		&"enemy-0",
		{
			"damage": 9,
			"ap_cost": 4,
			"defining_strike": true,
			"weakness_name": "The knee",
		},
		_snapshot(30, 21),
	))

	assert_bool(stage.is_reduced_motion_enabled()).is_true()
	assert_bool(Juicee.accessibility.reduced_motion).is_true()
	assert_int(stage.active_motion_count()).is_equal(0)
	assert_str(stage.feedback_text(&"hit")).contains("9")
	assert_str(stage.feedback_text(&"defining_strike")).contains("THE KNEE")
	var static_information := stage.find_child("StaticCombatInformation", true, false) as Label
	assert_object(static_information).is_not_null()
	assert_str(static_information.text).contains("AP")


func test_turn_ap_zone_and_defeat_beats_are_all_event_driven() -> void:
	stage.consume_event(_event(
		&"battle_started", 5, &"", &"", {}, _snapshot()), false
	)
	stage.consume_event(_event(
		&"turn_started", 6, &"ally-0", &"", {}, _snapshot()
	))
	stage.consume_event(_event(
		&"action_resolved",
		7,
		&"ally-0",
		&"enemy-0",
		{"damage": 30, "ap_cost": 2, "from": &"front", "to": &"back"},
		_snapshot(30, 0, &"back"),
	))

	assert_int(stage.feedback_count(&"turn_started")).is_equal(1)
	assert_str(stage.feedback_text(&"turn_started")).contains("VEX")
	assert_int(stage.feedback_count(&"ap_spent")).is_equal(1)
	assert_int(stage.feedback_count(&"zone_moved")).is_equal(1)
	assert_str(stage.feedback_text(&"zone_moved")).contains("FRONT")
	assert_str(stage.feedback_text(&"zone_moved")).contains("BACK")
	assert_int(stage.feedback_count(&"defeated")).is_equal(1)
	assert_str(stage.feedback_text(&"defeated")).contains("DEFEATED")


func test_event_snapshot_selects_environment_combatant_art_and_occupied_zones() -> void:
	stage.consume_event(_event(
		&"battle_started",
		8,
		&"",
		&"",
		{},
		_snapshot(30, 30, &"front", 0, &"loam-maddened-boar", &"flank"),
	))

	assert_str(stage.environment_id()).is_equal("nature")
	assert_int(stage.environment_sprite_count()).is_equal(5)
	assert_int(stage.zone_marker_count()).is_equal(6)
	assert_str(stage.combatant_texture_path(&"ally-0")).contains(
		"units/vex/vex--idle--se--f00.png"
	)
	assert_str(stage.combatant_texture_path(&"enemy-0")).contains(
		"units/loam-maddened-boar/loam-maddened-boar--idle--se--f00.png"
	)
	assert_bool(stage.zone_is_occupied(&"ally", &"front")).is_true()
	assert_bool(stage.zone_is_occupied(&"enemy", &"flank")).is_true()
	assert_bool(stage.zone_is_occupied(&"enemy", &"front")).is_false()

	stage.consume_event(_event(
		&"battle_started",
		9,
		&"",
		&"",
		{},
		_snapshot(30, 30, &"back", 0, &"cleaned-jawbrace-guard", &"front"),
	))
	assert_str(stage.environment_id()).is_equal("castle")
	assert_str(stage.combatant_texture_path(&"enemy-0")).contains(
		"units/cleaned-jawbrace-guard/cleaned-jawbrace-guard--idle--se--f00.png"
	)

	stage.consume_event(_event(
		&"battle_started",
		10,
		&"",
		&"",
		{},
		_snapshot(30, 30, &"front", 0, &"mustered-bloodbellow", &"back"),
	))
	assert_str(stage.environment_id()).is_equal("fantasy-town")


func test_party_identity_and_enemy_archetype_are_stable_sprite_keys() -> void:
	stage.consume_event(_event(
		&"battle_started",
		11,
		&"",
		&"",
		{},
		_snapshot(30, 30, &"front", 0, &"bog-wight", &"front", "Vex the Unbowed"),
	))
	var vex_texture: String = stage.combatant_texture_path(&"ally-0")
	var wight_texture: String = stage.combatant_texture_path(&"enemy-0")

	stage.consume_event(_event(
		&"battle_started",
		12,
		&"",
		&"",
		{},
		_snapshot(30, 30, &"front", 0, &"gnaal-rift-scavenger", &"front", "Serai-Lun"),
	))
	assert_str(stage.combatant_texture_path(&"ally-0")).is_not_equal(vex_texture)
	assert_str(stage.combatant_texture_path(&"enemy-0")).is_not_equal(wight_texture)


func test_zone_markers_are_spatial_and_procedural_figures_are_gone() -> void:
	var ally_front: Vector2 = stage.zone_marker_position(&"ally", &"front")
	var ally_back: Vector2 = stage.zone_marker_position(&"ally", &"back")
	var ally_flank: Vector2 = stage.zone_marker_position(&"ally", &"flank")
	var enemy_front: Vector2 = stage.zone_marker_position(&"enemy", &"front")

	assert_bool(ally_front != ally_back).is_true()
	assert_bool(ally_front != ally_flank).is_true()
	assert_bool(ally_front.x < enemy_front.x).is_true()
	assert_bool(ally_flank.y < ally_front.y).is_true()
	assert_bool(ally_back.x < ally_front.x).is_true()

	var source := FileAccess.get_file_as_string("res://ui/screens/battle_stage.gd")
	for primitive in [
		"func _draw(",
		"draw_rect(",
		"draw_circle(",
		"draw_colored_polygon(",
		"draw_line(",
		"draw_arc(",
	]:
		assert_bool(source.contains(primitive)).is_false()


func test_presentation_source_has_no_direct_combat_domain_reads() -> void:
	var source := FileAccess.get_file_as_string("res://ui/screens/battle_stage.gd")
	var screen_source := FileAccess.get_file_as_string("res://ui/screens/battle.gd")

	assert_bool(source.contains("Battle.")).is_false()
	assert_bool(source.contains("controller.")).is_false()
	assert_bool(source.contains("EncounterCatalog")).is_false()
	assert_bool(source.contains("BattleActor")).is_false()
	assert_bool(source.contains("set_battle_state")).is_false()
	assert_bool(source.contains("func consume_event(event: CombatEvent")).is_true()
	assert_bool(source.contains("event.data.get(\"snapshot\"")).is_true()
	assert_bool(screen_source.contains("combat_event.connect(Callable(_stage")).is_true()
	assert_bool(screen_source.contains("stage_space.name = \"BattlefieldViewport\"")).is_true()
	assert_bool(screen_source.contains("_battle_hud.visible = false")).is_true()
	assert_bool(screen_source.contains("_stage.set_battle_state")).is_false()


func test_resolution_finishes_while_feedback_is_still_in_flight() -> void:
	var rules := load("res://data/combat/combat_rules.tres") as CombatRules
	var controller := CombatController.new()
	controller.configure(
		CombatActionCatalog.all(), BattlefieldModel.create_default(rules), rules
	)
	controller.event_emitted.connect(stage.consume_event)
	var ally := _actor("Vex", 30, 100, 0)
	var enemy := _actor("Frail Enemy", 1, 1, 0)

	controller.start([ally], [enemy])
	controller.submit_action(&"strike", enemy)

	assert_int(controller.state).is_equal(CombatController.State.FINISHED)
	assert_int(enemy.hp).is_equal(0)
	assert_bool(stage.active_motion_count() > 0).is_true()
	assert_int(stage.feedback_count(&"battle_finished")).is_equal(1)


func test_settings_screen_persists_and_broadcasts_the_reduced_motion_toggle() -> void:
	var settings_source := FileAccess.get_file_as_string("res://ui/screens/settings.gd")
	var state_source := FileAccess.get_file_as_string("res://globals/game_state.gd")

	assert_bool(settings_source.contains("ReducedMotion")).is_true()
	assert_bool(settings_source.contains("accessibility\", \"reduced_motion")).is_true()
	assert_bool(settings_source.contains("Juicee.accessibility.reduced_motion")).is_true()
	assert_bool(state_source.contains("signal setting_changed")).is_true()
	assert_bool(state_source.contains("setting_changed.emit")).is_true()


func _event(
	type: StringName,
	sequence: int,
	actor_id: StringName,
	target_id: StringName,
	data: Dictionary,
	snapshot: Dictionary,
) -> CombatEvent:
	var event := CombatEvent.new()
	event.type = type
	event.sequence = sequence
	event.actor_id = actor_id
	event.target_id = target_id
	event.data = data.duplicate(true)
	event.data["snapshot"] = snapshot.duplicate(true)
	return event


func _snapshot(
	ally_hp: int = 30,
	enemy_hp: int = 30,
	ally_zone: StringName = &"front",
	balance: int = 0,
	enemy_archetype: StringName = &"bog-wight",
	enemy_zone: StringName = &"front",
	ally_name: String = "Vex",
) -> Dictionary:
	return {
		"round": 1,
		"balance": balance,
		"active_actor_id": &"ally-0",
		"allies": [{
			"id": &"ally-0",
			"display_name": ally_name,
			"hp": ally_hp,
			"max_hp": 30,
			"ap": 4,
			"max_ap": 6,
			"position": ally_zone,
			"side": &"ally",
		}],
		"enemies": [{
			"id": &"enemy-0",
			"display_name": "Bog Wight",
			"hp": enemy_hp,
			"max_hp": 30,
			"ap": 3,
			"max_ap": 3,
			"position": enemy_zone,
			"side": &"enemy",
			"archetype_id": enemy_archetype,
		}],
	}


func _actor(name: String, hp: int, attack: int, defense: int) -> BattleActor:
	var actor := BattleActor.new()
	actor.display_name = name
	actor.hp = hp
	actor.max_hp = hp
	actor.attack = attack
	actor.defense = defense
	return actor
