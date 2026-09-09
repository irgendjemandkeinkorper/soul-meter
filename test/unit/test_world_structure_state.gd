extends GdUnitTestSuite

const StructureState := preload("res://globals/world_structure_state.gd")
var state


func before_test() -> void:
	state = StructureState.new()


func test_damage_keeps_partial_integrity_and_registration_never_repairs() -> void:
	assert_bool(state.register_structure("dom/test-gate", 10, 4)).is_true()
	assert_bool(state.damage("dom/test-gate", 3, 2)).is_true()
	assert_int(state.structure("dom/test-gate")["integrity"]).is_equal(7)
	assert_str(state.structure("dom/test-gate")["state"]).is_equal("damaged")
	assert_bool(state.register_structure("dom/test-gate", 10, 4)).is_true()
	assert_int(state.structure("dom/test-gate")["integrity"]).is_equal(7)
	assert_bool(state.register_structure("dom/test-gate", 20, 4)).is_false()


func test_maintained_structure_restores_only_at_its_deadline() -> void:
	state.register_structure("dom/test-gate", 10, 4)
	state.damage("dom/test-gate", 100, 2)
	assert_str(state.structure("dom/test-gate")["state"]).is_equal("ruined")
	state.advance(2)
	assert_str(state.structure("dom/test-gate")["state"]).is_equal("ruined")
	state.advance(5)
	assert_str(state.structure("dom/test-gate")["state"]).is_equal("rebuilding")
	assert_int(state.structure("dom/test-gate")["integrity"]).is_zero()
	state.advance(6)
	assert_int(state.structure("dom/test-gate")["integrity"]).is_equal(10)
	assert_str(state.structure("dom/test-gate")["state"]).is_equal("intact")


func test_abandoned_structure_stays_ruined_after_many_days() -> void:
	state.register_structure("wilds/test-temple", 10)
	state.damage("wilds/test-temple", 10, 0)
	state.advance(4000)
	assert_str(state.structure("wilds/test-temple")["state"]).is_equal("ruined")
	assert_int(state.structure("wilds/test-temple")["rebuild_at"]).is_equal(-1)


func test_occupied_structure_waits_until_safe_without_advancing_time() -> void:
	state.register_structure("dom/test-gate", 10, 2)
	state.damage("dom/test-gate", 10, 0)
	var occupied: Array[String] = ["dom/test-gate"]
	state.advance(2, occupied)
	assert_str(state.structure("dom/test-gate")["state"]).is_equal("rebuilding")
	state.advance(2)
	assert_str(state.structure("dom/test-gate")["state"]).is_equal("intact")


func test_invalid_damage_does_not_create_or_mutate_structures() -> void:
	assert_bool(state.register_structure("", 10)).is_false()
	assert_bool(state.register_structure("bad", 0)).is_false()
	assert_bool(state.register_structure("bad", 10, -1)).is_false()
	state.register_structure("gate", 10)
	assert_bool(state.damage("unknown", 3, 0)).is_false()
	assert_bool(state.damage("gate", -3, 0)).is_false()
	assert_bool(state.damage("gate", 3, -1)).is_false()
	assert_int(state.structure("gate")["integrity"]).is_equal(10)


func test_story_restoration_is_explicit_and_event_replay_cannot_rebuild_twice() -> void:
	state.register_structure("temple", 10)
	state.damage("temple", 10, 0)
	assert_bool(state.begin_rebuild("temple", 4, 3, "quest:restore-temple")).is_true()
	assert_bool(state.begin_rebuild("temple", 4, 5, "quest:restore-temple")).is_false()
	assert_int(state.structure("temple")["rebuild_at"]).is_equal(7)
	state.advance(7)
	state.damage("temple", 10, 8)
	assert_bool(state.begin_rebuild("temple", 4, 8, "quest:restore-temple")).is_false()
	state.advance(100)
	assert_str(state.structure("temple")["state"]).is_equal("ruined")


func test_damage_during_rebuilding_replaces_the_old_deadline() -> void:
	state.register_structure("gate", 10, 4)
	state.damage("gate", 10, 0)
	state.advance(2)
	assert_bool(state.damage("gate", 1, 2)).is_true()
	assert_int(state.structure("gate")["rebuild_at"]).is_equal(6)
	state.advance(4)
	assert_int(state.structure("gate")["integrity"]).is_zero()
	state.advance(6)
	assert_int(state.structure("gate")["integrity"]).is_equal(10)


func test_save_round_trip_is_detached_and_queries_never_advance_repair() -> void:
	state.register_structure("gate", 10, 4)
	state.damage("gate", 10, 0)
	var saved: Dictionary = state.to_dict()
	var restored = StructureState.new()
	assert_bool(restored.from_dict(saved)).is_true()
	saved["structures"]["gate"]["integrity"] = 9
	var view: Dictionary = restored.structure("gate")
	view["integrity"] = 8
	assert_int(restored.structure("gate")["integrity"]).is_zero()
	assert_str(restored.structure("gate")["state"]).is_equal("ruined")
	restored.advance(4)
	assert_str(restored.structure("gate")["state"]).is_equal("intact")
	assert_str(state.structure("gate")["state"]).is_equal("ruined")


func test_corrupt_state_is_rejected_atomically_and_empty_legacy_state_is_valid() -> void:
	state.register_structure("gate", 10, 4)
	state.damage("gate", 10, 0)
	var before: Dictionary = state.to_dict()
	for bad_value: Variant in [-1, 11, 1.5, "10", null]:
		var corrupt: Dictionary = before.duplicate(true)
		corrupt["structures"]["gate"]["integrity"] = bad_value
		assert_bool(state.from_dict(corrupt)).is_false()
		assert_dict(state.to_dict()).is_equal(before)
	assert_bool(state.from_dict({"structures": []})).is_false()
	assert_bool(state.from_dict({})).is_true()
	assert_dict(state.structure("gate")).is_empty()
