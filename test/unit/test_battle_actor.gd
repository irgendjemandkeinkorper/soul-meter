extends GdUnitTestSuite
## Dedicated value-object coverage for BattleActor.


func test_new_actor_has_combat_ready_defaults() -> void:
	var actor := BattleActor.new()

	assert_str(actor.display_name).is_empty()
	assert_int(actor.hp).is_equal(10)
	assert_int(actor.max_hp).is_equal(10)
	assert_int(actor.attack).is_equal(5)
	assert_int(actor.defense).is_equal(2)
	assert_bool(actor.is_alive()).is_true()
	assert_int(actor.party_index).is_equal(-1)
	assert_bool(actor.guarding).is_false()
	assert_float(actor.attack_scale).is_equal(1.0)
	assert_bool(actor.attributes.is_empty()).is_true()
	assert_bool(actor.discovered_weakness_ids.is_empty()).is_true()
	assert_bool(actor.defining_effects.is_empty()).is_true()


func test_assigned_fields_retain_their_types_and_values() -> void:
	var actor := BattleActor.new()
	actor.display_name = "Bog Wight"
	actor.hp = 17
	actor.max_hp = 24
	actor.attack = 8
	actor.defense = 3
	actor.attributes = {"might": 6}
	actor.archetype_id = &"bog-wight"
	actor.element_id = &"loam"
	actor.defeated_flag = "bog_wight_defeated"
	actor.party_index = 2
	actor.combat_id = &"enemy-0"
	actor.side = &"enemy"

	assert_str(actor.display_name).is_equal("Bog Wight")
	assert_int(actor.hp).is_equal(17)
	assert_int(actor.max_hp).is_equal(24)
	assert_int(actor.attack).is_equal(8)
	assert_int(actor.defense).is_equal(3)
	assert_int(actor.attribute_value(&"might")).is_equal(6)
	assert_str(String(actor.archetype_id)).is_equal("bog-wight")
	assert_str(String(actor.element_id)).is_equal("loam")
	assert_str(actor.defeated_flag).is_equal("bog_wight_defeated")
	assert_int(actor.party_index).is_equal(2)
	assert_str(String(actor.combat_id)).is_equal("enemy-0")
	assert_str(String(actor.side)).is_equal("enemy")


func test_equivalent_actors_keep_identity_equality_semantics() -> void:
	var first := BattleActor.new()
	first.display_name = "Twin"
	var second := BattleActor.new()
	second.display_name = "Twin"

	assert_object(first).is_same(first)
	assert_bool(first == second).is_false()


func test_mutable_defaults_are_isolated_between_instances() -> void:
	var first := BattleActor.new()
	var second := BattleActor.new()

	first.attributes["might"] = 9
	first.discovered_weakness_ids.append(&"exposed-to-spark")
	first.defining_effects["attack_delta"] = 3

	assert_bool(second.attributes.is_empty()).is_true()
	assert_bool(second.discovered_weakness_ids.is_empty()).is_true()
	assert_bool(second.defining_effects.is_empty()).is_true()


func test_balance_effects_are_deep_copied_at_the_assignment_boundary() -> void:
	var actor := BattleActor.new()
	var authored_effects := {"modifiers": {"attack_delta": 2}}

	actor.apply_balance_band(&"order", authored_effects)
	authored_effects["modifiers"]["attack_delta"] = 99

	assert_str(String(actor.balance_band_id)).is_equal("order")
	assert_int(actor.balance_effects["modifiers"]["attack_delta"]).is_equal(2)
