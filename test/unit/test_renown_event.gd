extends GdUnitTestSuite
## Dedicated value-object coverage for RenownEvent.


func test_new_event_has_typed_zero_value_fields() -> void:
	var event := RenownEvent.new()

	assert_str(event.actor).is_empty()
	assert_str(String(event.kind)).is_empty()
	assert_float(event.delta).is_equal(0.0)
	assert_str(event.cause).is_empty()
	assert_str(event.scene).is_empty()
	assert_int(event.at).is_equal(0)
	assert_int(event.order).is_equal(0)


func test_fields_retain_complete_ledger_entry() -> void:
	var event := _event()

	assert_str(event.actor).is_equal("player")
	assert_str(String(event.kind)).is_equal("infamy")
	assert_float(event.delta).is_equal(6.25)
	assert_str(event.cause).is_equal("Threatened a grove-tender")
	assert_str(event.scene).is_equal("res://world/test_room.tscn")
	assert_int(event.at).is_equal(1_725_000_001)
	assert_int(event.order).is_equal(9)


func test_dictionary_round_trip_preserves_every_field() -> void:
	var original := _event()
	var restored := RenownEvent.from_dict(original.to_dict())

	assert_str(restored.actor).is_equal(original.actor)
	assert_str(String(restored.kind)).is_equal(String(original.kind))
	assert_float(restored.delta).is_equal(original.delta)
	assert_str(restored.cause).is_equal(original.cause)
	assert_str(restored.scene).is_equal(original.scene)
	assert_int(restored.at).is_equal(original.at)
	assert_int(restored.order).is_equal(original.order)


func test_from_dict_normalizes_kind_and_supplies_safe_defaults() -> void:
	var infamy := RenownEvent.from_dict({"kind": "infamy", "delta": 2})
	var unsupported := RenownEvent.from_dict({"kind": "unknown"})
	var missing := RenownEvent.from_dict({})

	assert_str(String(infamy.kind)).is_equal("infamy")
	assert_float(infamy.delta).is_equal(2.0)
	assert_str(String(unsupported.kind)).is_equal("reputation")
	assert_str(String(missing.kind)).is_equal("reputation")
	assert_str(missing.actor).is_empty()
	assert_int(missing.order).is_equal(0)


func test_equivalent_events_keep_identity_equality_semantics() -> void:
	var first := _event()
	var second := RenownEvent.from_dict(first.to_dict())

	assert_object(first).is_same(first)
	assert_bool(first == second).is_false()


func test_serialized_snapshot_is_isolated_from_the_event() -> void:
	var event := _event()
	var snapshot := event.to_dict()

	snapshot["delta"] = 1000.0
	snapshot["cause"] = "Rewritten"

	assert_float(event.delta).is_equal(6.25)
	assert_str(event.cause).is_equal("Threatened a grove-tender")


func _event() -> RenownEvent:
	var event := RenownEvent.new()
	event.actor = "player"
	event.kind = &"infamy"
	event.delta = 6.25
	event.cause = "Threatened a grove-tender"
	event.scene = "res://world/test_room.tscn"
	event.at = 1_725_000_001
	event.order = 9
	return event
