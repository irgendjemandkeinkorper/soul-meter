extends "res://addons/gdUnit4/src/GdUnitTestSuite.gd"

const Reputation = preload("res://globals/reputation.gd")
const RepEvent = preload("res://globals/reputation_event.gd")

var _reputation: Node

func before_test() -> void:
	_reputation = Reputation.new()

func after_test() -> void:
	_reputation.free()

func test_record_basic() -> void:
	var event = _reputation.record("player", "mirror-choir", 10.0, "Donated to the choir")

	assert_str(event.actor).is_equal("player")
	assert_str(event.faction).is_equal("mirror-choir")
	assert_float(event.delta).is_equal(10.0)
	assert_str(event.cause).is_equal("Donated to the choir")
	assert_int(event.order).is_equal(0)
	assert_int(event.at).is_greater(0)

	assert_float(_reputation.standing("mirror-choir")).is_equal(10.0)
	assert_int(_reputation.event_count()).is_equal(1)

func test_reputation_band() -> void:
	_reputation.record("player", "hostile-faction", -50.0, "Attacked")
	assert_str(String(_reputation.band("hostile-faction"))).is_equal("hostile")

	_reputation.record("player", "cold-faction", -20.0, "Stole")
	assert_str(String(_reputation.band("cold-faction"))).is_equal("cold")

	_reputation.record("player", "neutral-faction", 5.0, "Helped")
	assert_str(String(_reputation.band("neutral-faction"))).is_equal("neutral")

	_reputation.record("player", "warm-faction", 20.0, "Donated")
	assert_str(String(_reputation.band("warm-faction"))).is_equal("warm")

	_reputation.record("player", "allied-faction", 50.0, "Saved")
	assert_str(String(_reputation.band("allied-faction"))).is_equal("allied")

func test_record_multiple_events() -> void:
	_reputation.record("player", "mirror-choir", 10.0, "Donated")
	_reputation.record("player", "mirror-choir", -5.0, "Stole from the choir")

	assert_float(_reputation.standing("mirror-choir")).is_equal(5.0)
	assert_int(_reputation.event_count()).is_equal(2)

	var why = _reputation.why("mirror-choir")
	assert_int(why.size()).is_equal(2)
	assert_str(why[0].cause).is_equal("Stole from the choir") # Newest first
	assert_str(why[1].cause).is_equal("Donated")

func test_record_different_factions() -> void:
	_reputation.record("player", "mirror-choir", 10.0, "Donated")
	_reputation.record("player", "the-registry", 20.0, "Registered")

	assert_float(_reputation.standing("mirror-choir")).is_equal(10.0)
	assert_float(_reputation.standing("the-registry")).is_equal(20.0)
	assert_int(_reputation.event_count()).is_equal(2)

func test_record_scene_parameter() -> void:
	var event_with_scene = _reputation.record("player", "mirror-choir", 10.0, "Donated", "res://world/test_room.tscn")
	assert_str(event_with_scene.scene).is_equal("res://world/test_room.tscn")
