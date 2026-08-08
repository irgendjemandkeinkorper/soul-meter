extends GdUnitTestSuite
## FR-105a seam (architecture doc §1, amendment §2.3, issue #164).
##
## Proves the widened BattlefieldModel interface: capabilities() reports honest
## defaults, the new query methods degrade safely on the base class, the zone
## model inherits those defaults unchanged, and create_default() switches on
## CombatRules.use_grid_battlefield rather than a hardcoded path.


func _rules() -> CombatRules:
	return CombatRules.new()


func _actor(id: String) -> BattleActor:
	var actor := BattleActor.new()
	actor.display_name = id
	actor.combat_id = StringName(id)
	actor.hp = 10
	actor.max_hp = 10
	actor.attributes = {&"edge": 4}
	return actor


func test_create_default_returns_zone_model_when_flag_is_false() -> void:
	var rules := _rules()
	assert_bool(rules.use_grid_battlefield).is_false()
	var model := BattlefieldModel.create_default(rules)
	assert_str(model.get_script().resource_path).is_equal(
		"res://globals/combat/zone_battlefield_model.gd"
	)


func test_base_capabilities_report_no_spatial_features() -> void:
	var model := BattlefieldModel.new()
	var caps := model.capabilities()
	assert_bool(caps.get("cells", true)).is_false()
	assert_bool(caps.get("elevation", true)).is_false()
	assert_bool(caps.get("facing", true)).is_false()
	assert_bool(caps.get("occupancy", true)).is_false()
	assert_bool(caps.get("line_of_sight", true)).is_false()
	assert_bool(caps.get("path_cost", true)).is_false()


func test_zone_model_inherits_base_capabilities_unchanged() -> void:
	var model := BattlefieldModel.create_default(_rules())
	var caps := model.capabilities()
	for key: String in ["cells", "elevation", "facing", "occupancy", "line_of_sight", "path_cost"]:
		assert_bool(bool(caps.get(key, true))).override_failure_message(
			"zone model must not claim capability: %s" % key
		).is_false()


func test_describe_position_defaults_to_empty_dictionary() -> void:
	var model := BattlefieldModel.new()
	assert_dict(model.describe_position(&"front")).is_empty()


func test_reachable_positions_defaults_to_empty_array() -> void:
	var model := BattlefieldModel.new()
	assert_array(model.reachable_positions(_actor("a"), 100)).is_empty()


func test_path_query_returns_refusal_shape_on_base_class() -> void:
	var model := BattlefieldModel.new()
	var result := model.path_query(_actor("a"), &"front")
	assert_bool(result.get("allowed", true)).is_false()
	assert_str(String(result.get("blocked_by", &""))).is_equal("position")
	assert_str(String(result.get("message", ""))).is_not_empty()
	assert_dict(result.get("nearest_unblock", {})).is_empty()


func test_facing_defaults_to_empty_and_set_facing_is_refused() -> void:
	var model := BattlefieldModel.new()
	var actor := _actor("a")
	assert_str(String(model.facing_of(actor))).is_equal("")
	var result := model.set_facing(actor, &"north")
	assert_bool(result.get("allowed", true)).is_false()
	assert_str(String(result.get("blocked_by", &""))).is_equal("facing")


func test_line_of_sight_defaults_to_allowed_on_base_class() -> void:
	var model := BattlefieldModel.new()
	var result := model.line_of_sight(_actor("a"), _actor("b"))
	assert_bool(result.get("allowed", false)).is_true()


func test_occupant_of_defaults_to_null() -> void:
	var model := BattlefieldModel.new()
	assert_object(model.occupant_of(&"front")).is_null()


func test_elevation_delta_defaults_to_zero() -> void:
	var model := BattlefieldModel.new()
	assert_int(model.elevation_delta(_actor("a"), _actor("b"))).is_equal(0)


func test_zone_model_new_methods_behave_as_documented_defaults() -> void:
	var model := BattlefieldModel.create_default(_rules())
	var allies: Array[BattleActor] = [_actor("ally")]
	var enemies: Array[BattleActor] = [_actor("enemy")]
	model.setup(allies, enemies)

	assert_dict(model.describe_position(model.position_of(allies[0]))).is_empty()
	assert_array(model.reachable_positions(allies[0], 100)).is_empty()
	assert_bool(model.path_query(allies[0], &"back").get("allowed", true)).is_false()
	assert_str(String(model.facing_of(allies[0]))).is_equal("")
	assert_bool(model.set_facing(allies[0], &"north").get("allowed", true)).is_false()
	assert_bool(model.line_of_sight(allies[0], enemies[0]).get("allowed", false)).is_true()
	assert_object(model.occupant_of(&"front")).is_null()
	assert_int(model.elevation_delta(allies[0], enemies[0])).is_equal(0)


func test_the_flag_selects_the_grid_model_and_false_selects_the_zone_model() -> void:
	# This test previously asserted a FALLBACK, because grid_battlefield_model.gd
	# did not exist yet and flipping the flag would have crashed on a null script.
	# #137 landed, so the real selection is now assertable. The fallback in
	# create_default() is kept as defence: amendment §8.1 requires the zone model
	# to stay reachable, and a missing script must degrade loudly, not crash.
	var zone_rules := CombatRules.new()
	zone_rules.use_grid_battlefield = false
	var zone_model := BattlefieldModel.create_default(zone_rules)
	assert_bool(
		zone_model.get_script().resource_path.ends_with("zone_battlefield_model.gd")
	).is_true()

	var grid_rules := CombatRules.new()
	grid_rules.use_grid_battlefield = true
	var grid_model := BattlefieldModel.create_default(grid_rules)
	assert_bool(
		grid_model.get_script().resource_path.ends_with("grid_battlefield_model.gd")
	).is_true()

	# The abort path §8.1 depends on: setting the flag back must restore zones.
	assert_bool(zone_model.get_script() != grid_model.get_script()).is_true()
