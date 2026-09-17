extends GdUnitTestSuite
## Live forecast/submit coverage for K3, T2, H3, Z3, Z4 and Hold Note's lifecycle.

const NO_FIZZLE := {"fizzle": {"harmonic_accord": 100.0, "pitch": 10}}


func test_hold_light_freezes_duration_and_pays_once_per_turn() -> void:
	var b := _battle()
	var c: CombatController = b.controller
	var caster: BattleActor = b.caster
	var field: Dictionary = c.light.create_field(caster.combat_id, Vector2i(2, 1), 1, c.round_number).field
	var options := {"field_id": int(field.id)}
	var outcome := _cast(b, &"hold-note", options)
	assert_int(caster.breath).is_equal(59)
	assert_int(caster.action_points).is_equal(7)
	assert_dict(outcome.object.upkeep).is_equal({"ap": 1, "ct": 30, "breath": 1, "timing": "turn_start"})
	assert_bool(c.submit_action(&"guard").allowed).is_true()
	assert_int(_count(b, &"hold_upkeep_paid")).is_equal(0)
	_end_round(b)
	assert_int(int(c.light.field_by_id(int(field.id)).remaining_checkpoints)).is_equal(2)
	assert_int(caster.breath).is_equal(58)
	assert_int(caster.action_points).is_equal(7)
	assert_int(_count(b, &"hold_upkeep_paid")).is_equal(1)
	assert_bool(c.release_hold(String(caster.combat_id))).is_true()
	_end_round(b)
	assert_int(int(c.light.field_by_id(int(field.id)).remaining_checkpoints)).is_equal(1)
	assert_int(caster.breath).is_equal(58)


func test_hold_firebreak_freezes_only_the_line_not_burning_or_wet() -> void:
	var b := _battle()
	var c: CombatController = b.controller
	var line: Dictionary = c.fire.create_line(b.caster.combat_id, [Vector2i(2, 0)], c.round_number).line
	_cast(b, &"hold-note", {"line_id": int(line.id)})
	c._apply_burning(b.ally, b.caster.combat_id)
	FireField.apply_soaked(b.caster)
	_end_round(b)
	assert_int(int(c.fire.line_by_id(int(line.id)).remaining_checkpoints)).is_equal(2)
	assert_int(b.ally.hp).is_equal(97)
	assert_int(int(b.caster.impositions.soaked.remaining_checkpoints)).is_equal(1)
	assert_int(_count(b, &"burn_tick")).is_equal(1)


func test_hold_shroud_survives_a_jam_on_a_separate_deferred_working() -> void:
	var b := _battle()
	var c: CombatController = b.controller
	var field: Dictionary = c.light.create_shroud(b.caster.combat_id, Vector2i(2, 1), 1, c.round_number).field
	_cast(b, &"hold-note", {"field_id": int(field.id)})
	c.enqueue_deferred({"source_id": String(b.caster.combat_id), "target_id": String(b.enemy.combat_id), "delay_rounds": 2, "effect": {"writes": [{"kind": "dot", "amount": 1}]}})
	var jam: Dictionary = c.request_cancel(b.ally.combat_id, b.caster.combat_id, &"deferred")
	assert_bool(jam.allowed).is_true()
	assert_int(c.snapshot().holds.size()).is_equal(1)
	_end_round(b)
	assert_int(int(c.light.field_by_id(int(field.id)).remaining_checkpoints)).is_equal(2)


func test_one_sustain_slot_refuses_before_costs_and_release_frees_it() -> void:
	var b := _battle()
	var c: CombatController = b.controller
	var first := _aftertone(b, b.caster)
	var second := _aftertone(b, b.ally)
	_cast(b, &"hold-note", first)
	_refused(b, &"hold-note", second, "sustain_slot")
	assert_bool(c.release_hold(String(b.caster.combat_id))).is_true()
	assert_bool(bool(b.caster.aftertones[0].held)).is_false()
	_cast(b, &"hold-note", second)
	assert_bool(bool(b.ally.aftertones[0].held)).is_true()


func test_hold_rejects_unowned_missing_moving_and_out_of_reach_notes_without_payment() -> void:
	var b := _battle()
	var c: CombatController = b.controller
	var hostile := _aftertone(b, b.enemy, b.enemy)
	_refused(b, &"hold-note", hostile, "not_owned")
	_refused(b, &"hold-note", {"aftertone": {"target_id": String(b.enemy.combat_id), "index": 99}}, "no_target")
	c.place_material("stone", Vector2i(2, 0), MaterialField.KIND_STONE)
	_refused(b, &"hold-note", {"object_id": "stone"}, "no_target")
	var moving: Dictionary = c.light.create_shroud(b.caster.combat_id, Vector2i(1, 1), 2, 1, 1, true).field
	_refused(b, &"hold-note", {"field_id": int(moving.id)}, "ineligible_note")
	var far: Dictionary = c.light.create_field(b.caster.combat_id, Vector2i(6, 1), 1, 1).field
	_refused(b, &"hold-note", {"field_id": int(far.id)}, "blocked_by_range")
	assert_int(_count(b, &"note_held")).is_equal(0)


func test_missing_breath_or_ap_upkeep_releases_without_partial_payment() -> void:
	var b := _battle()
	var c: CombatController = b.controller
	_cast(b, &"hold-note", _aftertone(b, b.ally))
	b.caster.breath = 0
	_end_round(b)
	assert_int(c.snapshot().holds.size()).is_equal(0)
	assert_int(b.caster.action_points).is_equal(8)
	assert_bool(bool(b.ally.aftertones[0].held)).is_false()
	b.caster.breath = 10
	_cast(b, &"hold-note", {"aftertone": {"target_id": String(b.ally.combat_id), "index": 0}})
	b.caster.action_points = 0
	c._pay_hold_upkeep(b.caster)
	assert_int(b.caster.breath).is_equal(9)
	assert_int(c.snapshot().holds.size()).is_equal(0)
	assert_int(_count(b, &"hold_upkeep_paid")).is_equal(0)


func test_leaving_sustain_reach_releases_and_duration_resumes() -> void:
	var b := _battle()
	var c: CombatController = b.controller
	var options := _aftertone(b, b.enemy)
	_cast(b, &"hold-note", options)
	assert_bool(b.grid.displace(b.enemy, Vector2i(6, 2)).allowed).is_true()
	c._tick_actor_aftertones()
	assert_int(c.snapshot().holds.size()).is_equal(0)
	assert_int(int(b.enemy.aftertones[0].remaining_rounds)).is_equal(2)
	assert_bool(bool(b.enemy.aftertones[0].held)).is_false()


func test_holder_death_releases_immediately_through_the_hp_write_path() -> void:
	var b := _battle()
	var c: CombatController = b.controller
	_cast(b, &"hold-note", _aftertone(b, b.ally))
	c._apply_resolution_writes(b.enemy, b.caster, {"writes": [{"kind": "hp", "after": 0}]})
	assert_int(c.snapshot().holds.size()).is_equal(0)
	assert_bool(bool(b.ally.aftertones[0].held)).is_false()
	assert_int(_count(b, &"hold_released")).is_equal(1)
	_assert_lethal_aftertone_write_cannot_restore_a_released_hold()


func _assert_lethal_aftertone_write_cannot_restore_a_released_hold() -> void:
	var b := _battle()
	var c: CombatController = b.controller
	var selected := _aftertone(b, b.enemy)
	_cast(b, &"anchor", selected)
	_cast(b, &"hold-note", selected)
	b.enemy.hp = 1
	var outcome: Dictionary = c.submit_action(&"kindle", b.enemy, NO_FIZZLE)
	assert_bool(outcome.allowed).is_true()
	assert_int(b.enemy.hp).is_equal(0)
	assert_int(c.snapshot().holds.size()).is_equal(0)
	for aftertone: Dictionary in b.enemy.aftertones:
		assert_bool(bool(aftertone.get("held", false))).is_false()
		assert_bool(aftertone.has("held_by")).is_false()


func test_k3_anchor_then_hold_stacks_and_does_not_hold_an_unselected_note() -> void:
	var b := _battle()
	var selected := _aftertone(b, b.enemy)
	_aftertone(b, b.caster)
	_cast(b, &"anchor", selected)
	var held := _cast(b, &"hold-note", selected)
	assert_bool(bool(held.object.anchored)).is_true()
	assert_bool(bool(held.object.held)).is_true()
	assert_bool(bool(held.object.consumable)).is_false()
	assert_bool(bool(b.caster.aftertones[0].held)).is_false()
	_end_round(b)
	assert_int(int(b.enemy.aftertones[0].remaining_rounds)).is_equal(3)
	var c: CombatController = b.controller
	assert_bool(c.release_hold(String(b.caster.combat_id))).is_true()
	_end_round(b)
	assert_bool(bool(b.enemy.aftertones[0].anchored)).is_true()
	assert_int(int(b.enemy.aftertones[0].remaining_rounds)).is_equal(2)
	_end_round(b)
	_end_round(b)
	assert_array(b.enemy.aftertones).is_empty()


func test_t2_anchor_alone_preserves_remaining_duration_and_expires_normally() -> void:
	var b := _battle()
	var selected := _aftertone(b, b.ally)
	_cast(b, &"anchor", selected)
	assert_int(int(b.ally.aftertones[0].remaining_rounds)).is_equal(3)
	for remaining: int in [2, 1]:
		_end_round(b)
		assert_bool(bool(b.ally.aftertones[0].anchored)).is_true()
		assert_bool(bool(b.ally.aftertones[0].held)).is_false()
		assert_int(int(b.ally.aftertones[0].remaining_rounds)).is_equal(remaining)
	_end_round(b)
	assert_array(b.ally.aftertones).is_empty()


func test_t2_hold_then_anchor_one_friendly_aftertone_and_no_other() -> void:
	var b := _battle()
	var selected := _aftertone(b, b.enemy)
	_aftertone(b, b.enemy)
	_cast(b, &"hold-note", selected)
	var anchored := _cast(b, &"anchor", selected)
	assert_bool(bool(anchored.object.held)).is_true()
	assert_bool(bool(anchored.object.anchored)).is_true()
	var c: CombatController = b.controller
	assert_bool(bool(c.snapshot().holds[String(b.caster.combat_id)].anchored)).is_true()
	assert_bool(bool(b.enemy.aftertones[1].anchored)).is_false()
	assert_int(int(b.enemy.aftertones[0].remaining_rounds)).is_equal(3)
	_refused(b, &"anchor", _aftertone(b, b.ally, b.enemy), "not_friendly")


func test_t2_anchor_refuses_held_non_aftertones_before_breath_and_ap() -> void:
	var b := _battle()
	var c: CombatController = b.controller
	var field: Dictionary = c.light.create_field(b.caster.combat_id, Vector2i(2, 1), 1, 1).field
	_cast(b, &"hold-note", {"field_id": int(field.id)})
	_refused(b, &"anchor", {"hold_of": String(b.caster.combat_id)}, "not_aftertone")
	assert_int(_count(b, &"aftertone_anchored")).is_equal(0)


func test_h3_khash_consumes_unanchored_held_aftertone_and_stops_upkeep() -> void:
	var b := _battle()
	var c: CombatController = b.controller
	_cast(b, &"hold-note", _aftertone(b, b.enemy))
	var preview: Dictionary = c.forecast_action(c.action_by_id(&"kindle"), b.enemy, NO_FIZZLE)
	var outcome: Dictionary = c.submit_action(&"kindle", b.enemy, NO_FIZZLE)
	assert_bool(outcome.allowed).is_true()
	assert_bool(outcome.resolution.fizzled).is_false()
	assert_int(int(outcome.damage)).is_equal(int(preview.damage))
	assert_int(c.snapshot().holds.size()).is_equal(0)
	assert_int(_count(b, &"aftertone_consumed")).is_equal(1)
	assert_int(_count(b, &"hold_released")).is_equal(1)
	assert_str(String(b.enemy.aftertones[0].owner_id)).is_equal(String(b.caster.combat_id))
	_end_round(b)
	assert_int(_count(b, &"hold_upkeep_paid")).is_equal(0)


func test_h3_anchored_held_aftertone_refuses_consumption_but_attack_still_lands() -> void:
	var b := _battle()
	var c: CombatController = b.controller
	var selected := _aftertone(b, b.enemy)
	_cast(b, &"anchor", selected)
	_cast(b, &"hold-note", selected)
	var preview: Dictionary = c.forecast_action(c.action_by_id(&"kindle"), b.enemy, NO_FIZZLE)
	var outcome: Dictionary = c.submit_action(&"kindle", b.enemy, NO_FIZZLE)
	assert_bool(outcome.allowed).is_true()
	assert_bool(outcome.resolution.fizzled).is_false()
	assert_int(int(outcome.damage)).is_equal(int(preview.damage))
	assert_int(_count(b, &"aftertone_consumed")).is_equal(0)
	assert_int(c.snapshot().holds.size()).is_equal(1)
	assert_bool(bool(b.enemy.aftertones[0].anchored)).is_true()
	assert_bool(bool(b.enemy.aftertones[0].held)).is_true()


func test_z3_z4_sever_ends_each_held_note_and_anchored_aftertones_without_refund() -> void:
	for kind: String in ["light", "shroud", "line", "aftertone"]:
		var b := _battle()
		var c: CombatController = b.controller
		var options: Dictionary
		match kind:
			"light":
				options = {"field_id": int(c.light.create_field(b.caster.combat_id, Vector2i(2, 1), 1, 1).field.id)}
			"shroud":
				options = {"field_id": int(c.light.create_shroud(b.caster.combat_id, Vector2i(2, 1), 1, 1).field.id)}
			"line":
				options = {"line_id": int(c.fire.create_line(b.caster.combat_id, [Vector2i(2, 1)], 1).line.id)}
			"aftertone":
				options = _aftertone(b, b.enemy)
				_cast(b, &"anchor", options)
		_cast(b, &"hold-note", options)
		var breath_before: int = b.caster.breath
		var ap_before: int = b.caster.action_points
		var severed := _cast(b, &"sever", {"hold_of": String(b.caster.combat_id)})
		assert_bool(bool(severed.severed)).is_true()
		assert_int(b.caster.breath).is_equal(breath_before - 6)
		assert_int(b.caster.action_points).is_equal(ap_before - 3)
		assert_int(c.snapshot().holds.size()).is_equal(0)
		assert_bool(c.light.is_empty()).is_true()
		assert_bool(c.fire.is_empty()).is_true()
		assert_array(b.enemy.aftertones).is_empty()
		b.caster.action_points = 8
		var another := _aftertone(b, b.ally)
		_cast(b, &"anchor", another)
		var direct := _cast(b, &"sever", another)
		assert_bool(bool(direct.severed)).is_true()
		assert_array(b.ally.aftertones).is_empty()


func test_hold_tracks_aftertone_array_shifts_and_save_round_trip_and_legacy_clear() -> void:
	var b := _battle()
	var c: CombatController = b.controller
	_aftertone(b, b.enemy)
	var selected := _aftertone(b, b.enemy)
	_cast(b, &"anchor", selected)
	_cast(b, &"hold-note", selected)
	var consumed: Dictionary = c.submit_action(&"kindle", b.enemy, NO_FIZZLE)
	assert_bool(consumed.allowed).is_true()
	assert_bool(consumed.resolution.fizzled).is_false()
	assert_int(int(c.snapshot().holds[String(b.caster.combat_id)].index)).is_equal(0)
	assert_int(_count(b, &"hold_released")).is_equal(0)
	var saved: Dictionary = JSON.parse_string(JSON.stringify(c.class_resources_to_dict()))
	var restored := _battle()
	var target: BattleActor = restored.enemy
	# Aftertones belong to the actor save, restored before the class-resource section.
	var actor_data: Array = JSON.parse_string(JSON.stringify(b.enemy.aftertones))
	target.aftertones.assign(actor_data)
	var restored_c: CombatController = restored.controller
	restored_c.restore_class_resources(saved)
	var round_tripped: Dictionary = JSON.parse_string(JSON.stringify(restored_c.class_resources_to_dict()))
	assert_dict(round_tripped["__holds__"]).is_equal(saved["__holds__"])
	assert_bool(bool(target.aftertones[0].anchored)).is_true()
	_end_round(restored)
	assert_int(int(target.aftertones[0].remaining_rounds)).is_equal(3)
	assert_int(_count(restored, &"hold_upkeep_paid")).is_equal(1)
	restored_c.restore_class_resources({})
	assert_bool(restored_c.class_resources_to_dict().has("__holds__")).is_false()
	assert_bool(bool(target.aftertones[0].held)).is_false()
	_end_round(restored)
	assert_bool(bool(target.aftertones[0].anchored)).is_true()
	assert_int(int(target.aftertones[0].remaining_rounds)).is_equal(2)


func test_ct_upkeep_costs_thirty_once_while_recharging_for_the_next_action() -> void:
	var b := _battle(true)
	var c: CombatController = b.controller
	var field: Dictionary = c.light.create_field(b.caster.combat_id, Vector2i(2, 1), 1, 1).field
	var outcome := _cast(b, &"hold-note", {"field_id": int(field.id)})
	assert_int(int(outcome.ct_spent)).is_equal(30)
	for attempt: int in 12:
		if c.active_actor() == b.caster and _count(b, &"hold_upkeep_paid") > 0:
			break
		assert_bool(c.end_turn()).is_true()
	assert_object(c.active_actor()).is_same(b.caster)
	assert_int(_count(b, &"hold_upkeep_paid")).is_equal(1)
	assert_int(b.caster.breath).is_equal(58)
	assert_bool(c.scheduler.can_act(b.caster).allowed).is_true()
	assert_int(int(c.light.field_by_id(int(field.id)).remaining_checkpoints)).is_equal(2)


func _cast(b: Dictionary, action_id: StringName, selection: Dictionary) -> Dictionary:
	var c: CombatController = b.controller
	var options := selection.duplicate(true)
	options.merge(NO_FIZZLE)
	var before: Dictionary = c.snapshot()
	var preview: Dictionary = c.forecast_action(c.action_by_id(action_id), null, options)
	assert_bool(preview.allowed).override_failure_message(str(preview)).is_true()
	assert_dict(c.snapshot()).is_equal(before)
	var outcome: Dictionary = c.submit_action(action_id, null, options)
	assert_bool(outcome.allowed).override_failure_message(str(outcome)).is_true()
	assert_bool(bool(outcome.get("fizzled", true))).is_false()
	if preview.has("object") and outcome.has("object"):
		assert_dict(outcome.object).is_equal(preview.object)
	return outcome


func _refused(b: Dictionary, action_id: StringName, selection: Dictionary, reason: String) -> void:
	var c: CombatController = b.controller
	var breath_before: int = b.caster.breath
	var ap_before: int = b.caster.action_points
	var preview: Dictionary = c.forecast_action(c.action_by_id(action_id), null, selection)
	var outcome: Dictionary = c.submit_action(action_id, null, selection)
	assert_bool(outcome.allowed).is_false()
	assert_str(String(outcome.blocked_by)).is_equal(reason)
	assert_str(String(preview.blocked_by)).is_equal(reason)
	assert_int(b.caster.breath).is_equal(breath_before)
	assert_int(b.caster.action_points).is_equal(ap_before)


func _aftertone(b: Dictionary, carrier: BattleActor, owner: BattleActor = null) -> Dictionary:
	carrier.aftertones.append({
		"owner_id": String((owner if owner != null else b.caster).combat_id),
		"element": "sul", "remaining_rounds": 3, "held": false, "anchored": false,
	})
	return {"aftertone": {"target_id": String(carrier.combat_id), "index": carrier.aftertones.size() - 1}}


func _count(b: Dictionary, event_type: StringName) -> int:
	return (b.events as Array[StringName]).count(event_type)


func _end_round(b: Dictionary) -> void:
	var c: CombatController = b.controller
	for attempt: int in 4:
		assert_bool(c.end_turn()).is_true()
		if c.active_actor() == b.caster:
			return
	assert_bool(false).override_failure_message("Round did not return to the caster.").is_true()


func _battle(ct: bool = false) -> Dictionary:
	var rules := (load("res://data/combat/combat_rules.tres") as CombatRules).duplicate(true) as CombatRules
	rules.use_charge_time = ct
	rules.base_action_points = 8
	var grid := GridBattlefieldModel.new()
	grid.configure(rules)
	grid.build_grid(_grid_ground())
	var caster := _actor("Caster", 12, 4)
	var ally := _actor("Second", 8, 3)
	var enemy := _actor("Dummy", 1, 1)
	assert_bool(grid.configure_initial_cells({caster: Vector2i(0, 1), ally: Vector2i(0, 0), enemy: Vector2i(4, 2)}).allowed).is_true()
	var c := CombatController.new()
	c.configure(CombatActionCatalog.all(), grid, rules)
	var events: Array[StringName] = []
	c.event_emitted.connect(func(event: CombatEvent) -> void: events.append(event.type))
	c.start([caster, ally], [enemy], &"matrix-step2")
	return {"controller": c, "caster": caster, "ally": ally, "enemy": enemy, "grid": grid, "events": events}


func _actor(label: String, attack: int, alacrity: int) -> BattleActor:
	var actor := BattleActor.new()
	actor.display_name = label
	actor.hp = 100
	actor.max_hp = 100
	actor.attack = attack
	actor.breath = 60
	actor.attributes = {"harmony": 0, "alacrity": alacrity}
	actor.defining_effects = {"hit": true}
	var member := PartyMember.new()
	member.id = label.to_lower()
	member.patron = "Kero"
	member.breath_max = 60
	actor.source_member = member
	return actor


func _grid_ground() -> TileMapLayer:
	var tile_set := TileSet.new()
	tile_set.tile_size = Vector2i(64, 32)
	var source := TileSetAtlasSource.new()
	source.texture = ImageTexture.create_from_image(Image.create(64, 32, false, Image.FORMAT_RGBA8))
	source.texture_region_size = Vector2i(64, 32)
	source.create_tile(Vector2i.ZERO)
	tile_set.add_source(source, 0)
	var layer := auto_free(TileMapLayer.new()) as TileMapLayer
	layer.tile_set = tile_set
	for x: int in 7:
		for y: int in 3:
			layer.set_cell(Vector2i(x, y), 0, Vector2i.ZERO)
	return layer
