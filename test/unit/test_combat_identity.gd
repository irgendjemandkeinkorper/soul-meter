extends GdUnitTestSuite


func test_generated_balance_bands_cover_every_boundary_without_gaps() -> void:
	var bands := CombatIdentityCatalog.balance_bands()
	assert_bool(bands.is_empty()).is_false()
	assert_int(CombatIdentityCatalog.balance_minimum()).is_equal(int(bands[0]["minimum"]))
	assert_int(CombatIdentityCatalog.balance_maximum()).is_equal(int(bands[-1]["maximum"]))
	for index in bands.size():
		var band: Dictionary = bands[index]
		assert_str(CombatIdentityCatalog.balance_band(int(band["minimum"]))["id"]).is_equal(
			str(band["id"])
		)
		assert_str(CombatIdentityCatalog.balance_band(int(band["maximum"]))["id"]).is_equal(
			str(band["id"])
		)
		if index > 0:
			assert_int(int(bands[index - 1]["maximum"]) + 1).is_equal(int(band["minimum"]))


func test_mundane_action_pulls_order_and_chaos_values_toward_generated_center() -> void:
	var action := CombatActionCatalog.by_id(&"strike")
	var order_band := _band(&"orderward")
	var chaos_band := _band(&"chaosward")
	var order_start := int(order_band["maximum"])
	var chaos_start := int(chaos_band["minimum"])

	var order_controller := _controller()
	order_controller.shift_balance(order_start)
	order_controller.submit_action(action.id, order_controller.enemies[0])
	assert_int(order_controller.balance).is_equal(order_start - mini(order_start, action.center_pull))

	var chaos_controller := _controller()
	chaos_controller.shift_balance(chaos_start)
	chaos_controller.submit_action(action.id, chaos_controller.enemies[0])
	assert_int(chaos_controller.balance).is_equal(
		chaos_start + mini(abs(chaos_start), action.center_pull)
	)
	for player_action: CombatAction in CombatActionCatalog.player_actions():
		# CAST identity comes from the selected AbilityDefinition/composition at resolution time;
		# assigning a command-level shift here would invent a second, conflicting balance effect.
		if player_action.kind == CombatAction.Kind.CAST:
			continue
		assert_bool(player_action.balance_shift != 0 or player_action.center_pull > 0).is_true()


func test_each_generated_archetype_has_stable_weaknesses_covering_all_effect_types() -> void:
	var effect_ids := {}
	var archetype_ids := CombatIdentityCatalog.archetype_ids()
	assert_bool(archetype_ids.is_empty()).is_false()
	for archetype_id: StringName in archetype_ids:
		assert_bool(StableIds.is_valid(StableIds.ACTOR, String(archetype_id))).is_true()
		var rows := CombatIdentityCatalog.weaknesses_for(archetype_id)
		assert_bool(rows.is_empty()).is_false()
		for row: Dictionary in rows:
			assert_bool(
				StableIds.is_valid(StableIds.WORLD_FACT, str(row.get("id", "")))
			).is_true()
			effect_ids[str(row.get("effect_id", ""))] = true
	assert_int(effect_ids.size()).is_equal(4)
	for effect_id in ["bind_break", "cripple", "disarm", "reveal"]:
		assert_bool(effect_ids.has(effect_id)).is_true()


func test_discovery_expands_from_lore_or_prior_archetype_encounters() -> void:
	var archetype_id := CombatIdentityCatalog.archetype_ids()[0]
	var rows := CombatIdentityCatalog.weaknesses_for(archetype_id)
	var gated: Dictionary = {}
	for row: Dictionary in rows:
		if float(row.get("lore_minimum", 0.0)) > 0.0 and int(row.get("prior_encounters", 0)) > 0:
			gated = row
			break
	assert_bool(gated.is_empty()).is_false()
	var weakness_id := StringName(gated["id"])

	assert_bool(_has_candidate(archetype_id, weakness_id, 0.0, 0)).is_false()
	assert_bool(
		_has_candidate(archetype_id, weakness_id, float(gated["lore_minimum"]), 0)
	).is_true()
	assert_bool(
		_has_candidate(archetype_id, weakness_id, 0.0, int(gated["prior_encounters"]))
	).is_true()


func _controller() -> CombatController:
	var ally := _actor("Ally")
	var enemy := _actor("Enemy")
	var rules := load("res://data/combat/combat_rules.tres") as CombatRules
	var result := CombatController.new()
	result.configure(CombatActionCatalog.all(), BattlefieldModel.create_default(rules), rules)
	result.start([ally], [enemy])
	return result


func _actor(display_name: String) -> BattleActor:
	var actor := BattleActor.new()
	actor.display_name = display_name
	actor.hp = 100
	actor.max_hp = 100
	actor.attack = 5
	actor.defense = 1
	return actor


func _band(band_id: StringName) -> Dictionary:
	for band: Dictionary in CombatIdentityCatalog.balance_bands():
		if StringName(band.get("id", "")) == band_id:
			return band
	return {}


func _has_candidate(
	archetype_id: StringName, weakness_id: StringName, lore_percent: float, encounters: int
) -> bool:
	for row: Dictionary in CombatIdentityCatalog.discovery_candidates(
		archetype_id, lore_percent, encounters
	):
		if StringName(row.get("id", "")) == weakness_id:
			return true
	return false
