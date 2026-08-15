extends GdUnitTestSuite
## Dedicated value-object coverage for ReputationEvent.


func test_new_event_has_typed_zero_value_fields() -> void:
	var event := ReputationEvent.new()

	assert_str(event.actor).is_empty()
	assert_str(event.faction).is_empty()
	assert_float(event.delta).is_equal(0.0)
	assert_str(event.cause).is_empty()
	assert_str(event.scene).is_empty()
	assert_int(event.at).is_equal(0)
	assert_int(event.order).is_equal(0)


func test_fields_retain_complete_ledger_entry() -> void:
	var event := _event()

	assert_str(event.actor).is_equal("player")
	assert_str(event.faction).is_equal("mirror-choir")
	assert_float(event.delta).is_equal(-7.5)
	assert_str(event.cause).is_equal("Broke the concord")
	assert_str(event.scene).is_equal("res://world/starting_town.tscn")
	assert_int(event.at).is_equal(1_725_000_000)
	assert_int(event.order).is_equal(12)


func test_dictionary_round_trip_preserves_every_field() -> void:
	var original := _event()
	var restored := ReputationEvent.from_dict(original.to_dict())

	assert_str(restored.actor).is_equal(original.actor)
	assert_str(restored.faction).is_equal(original.faction)
	assert_float(restored.delta).is_equal(original.delta)
	assert_str(restored.cause).is_equal(original.cause)
	assert_str(restored.scene).is_equal(original.scene)
	assert_int(restored.at).is_equal(original.at)
	assert_int(restored.order).is_equal(original.order)


func test_from_dict_coerces_values_and_supplies_safe_defaults() -> void:
	var event := ReputationEvent.from_dict({
		"actor": &"player", "faction": &"registry", "delta": 4,
		"at": 25.0, "order": 3.0,
	})

	assert_str(event.actor).is_equal("player")
	assert_str(event.faction).is_equal("registry")
	assert_float(event.delta).is_equal(4.0)
	assert_str(event.cause).is_empty()
	assert_str(event.scene).is_empty()
	assert_int(event.at).is_equal(25)
	assert_int(event.order).is_equal(3)


func test_equivalent_events_keep_identity_equality_semantics() -> void:
	var first := _event()
	var second := ReputationEvent.from_dict(first.to_dict())

	assert_object(first).is_same(first)
	assert_bool(first == second).is_false()


func test_serialized_snapshot_is_isolated_from_the_event() -> void:
	var event := _event()
	var snapshot := event.to_dict()

	snapshot["delta"] = 1000.0
	snapshot["cause"] = "Rewritten"

	assert_float(event.delta).is_equal(-7.5)
	assert_str(event.cause).is_equal("Broke the concord")


func _event() -> ReputationEvent:
	var event := ReputationEvent.new()
	event.actor = "player"
	event.faction = "mirror-choir"
	event.delta = -7.5
	event.cause = "Broke the concord"
	event.scene = "res://world/starting_town.tscn"
	event.at = 1_725_000_000
	event.order = 12
	return event
