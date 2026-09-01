extends GdUnitTestSuite
## Unit tests for the reputation ledger (globals/reputation.gd).
## Reference example for testing pure-logic autoloads: instantiate the script fresh
## per test instead of touching the shared `Reputation` autoload, so tests can't
## leak state into each other or into other test suites.

const ReputationScript := preload("res://globals/reputation.gd")

## Untyped on purpose: reputation.gd has no `class_name`, so a `Node`-typed var
## would hide record()/why()/etc. from the static analyzer's type inference.
var rep


func before_test() -> void:
	## auto_free() (not manual .free()) — monitor_signals() below also auto-frees
	## its target, and freeing the same object twice crashes the engine.
	rep = auto_free(ReputationScript.new())


func test_record_returns_event_with_expected_fields() -> void:
	var e: ReputationEvent = rep.record("player", "mirror-choir", 10.0, "Returned the lost relic", "test_room")

	assert_str(e.actor).is_equal("player")
	assert_str(e.faction).is_equal("mirror-choir")
	assert_float(e.delta).is_equal(10.0)
	assert_str(e.cause).is_equal("Returned the lost relic")
	assert_str(e.scene).is_equal("test_room")
	assert_int(e.order).is_equal(0)
	assert_int(e.at).is_greater(0)


func test_standing_is_the_sum_of_deltas() -> void:
	rep.record("player", "mirror-choir", 10.0, "Returned the lost relic", "test_room")
	rep.record("player", "mirror-choir", -3.0, "Was late to the meeting", "test_room")

	assert_float(rep.standing("mirror-choir")).is_equal_approx(7.0, 0.001)
	assert_int(rep.event_count()).is_equal(2)


func test_unknown_faction_defaults_to_neutral_zero() -> void:
	assert_float(rep.standing("no-such-faction")).is_equal(0.0)
	assert_str(rep.band("no-such-faction")).is_equal("neutral")


func test_band_allied_at_or_above_forty() -> void:
	rep.record("player", "the-registry", 45.0, "Test setup: allied", "test_room")
	assert_str(rep.band("the-registry")).is_equal("allied")


func test_band_warm_between_fifteen_and_forty() -> void:
	rep.record("player", "the-registry", 20.0, "Test setup: warm", "test_room")
	assert_str(rep.band("the-registry")).is_equal("warm")


func test_band_cold_at_or_below_negative_fifteen() -> void:
	rep.record("player", "the-registry", -20.0, "Test setup: cold", "test_room")
	assert_str(rep.band("the-registry")).is_equal("cold")


func test_band_hostile_at_or_below_negative_forty() -> void:
	rep.record("player", "the-registry", -50.0, "Test setup: hostile", "test_room")
	assert_str(rep.band("the-registry")).is_equal("hostile")


func test_why_returns_newest_first_and_respects_limit() -> void:
	rep.record("player", "mirror-choir", 1.0, "first", "test_room")
	rep.record("player", "mirror-choir", 1.0, "second", "test_room")
	rep.record("player", "mirror-choir", 1.0, "third", "test_room")

	var recent: Array = rep.why("mirror-choir", 2)

	assert_int(recent.size()).is_equal(2)
	assert_str(recent[0].cause).is_equal("third")
	assert_str(recent[1].cause).is_equal("second")


func test_events_for_only_returns_matching_faction() -> void:
	rep.record("player", "mirror-choir", 1.0, "choir event", "test_room")
	rep.record("player", "the-registry", 1.0, "registry event", "test_room")

	var choir_events: Array = rep.events_for("mirror-choir")

	assert_int(choir_events.size()).is_equal(1)
	assert_str(choir_events[0].cause).is_equal("choir event")


func test_recording_emits_reputation_changed() -> void:
	monitor_signals(rep)

	rep.record("player", "mirror-choir", 5.0, "Signal check", "test_room")

	## reputation_changed(faction, standing, event) — event is a fresh ReputationEvent
	## each call, so match it loosely with any() rather than by identity.
	await assert_signal(rep).is_emitted("reputation_changed", "mirror-choir", 5.0, any())


func test_to_dict_from_dict_round_trip_preserves_standings() -> void:
	rep.record("player", "mirror-choir", 10.0, "Returned the lost relic", "test_room")
	rep.record("player", "the-registry", -20.0, "Test setup: cold", "test_room")

	var reloaded = auto_free(ReputationScript.new())
	reloaded.from_dict(rep.to_dict())

	assert_float(reloaded.standing("mirror-choir")).is_equal_approx(10.0, 0.001)
	assert_str(reloaded.band("the-registry")).is_equal("cold")
	assert_int(reloaded.event_count()).is_equal(2)


func test_no_read_path_hands_out_a_writable_reference_to_the_log() -> void:
	# The class docstring calls a ReputationEvent "immutable" and the ledger's one
	# rule is that nothing writes except record(). Neither is enforced by GDScript:
	# events are RefCounted, so any accessor returning a STORED event lets a caller
	# rewrite history in place while the derived standing keeps the old total —
	# the log and the standing derived from it silently disagree, and the next
	# save serializes the rewritten past.
	rep.record("player", "mirror-choir", 5.0, "sided with the Backface", "test_room")
	var baseline_standing: float = rep.standing("mirror-choir")
	var baseline_serialized: Dictionary = rep.to_dict().duplicate(true)

	# Every way an event can leave the ledger.
	var returned: ReputationEvent = rep.record("player", "the-registry", 2.0, "paid the clerk", "test_room")
	var from_why: ReputationEvent = rep.why("mirror-choir", 1)[0]
	var from_history: ReputationEvent = rep.history(1)[0]
	var from_events_for: ReputationEvent = rep.events_for("mirror-choir")[0]
	var signalled: Array[ReputationEvent] = []
	rep.reputation_changed.connect(
		func(_f: String, _s: float, e: ReputationEvent) -> void: signalled.append(e)
	)
	rep.record("player", "mirror-choir", 1.0, "one more", "test_room")

	for escaped: ReputationEvent in [returned, from_why, from_history, from_events_for, signalled[0]]:
		escaped.delta = 9999.0
		escaped.cause = "REWRITTEN"

	# mirror-choir took 5.0 then 1.0; the tampering must not have moved it.
	assert_float(rep.standing("mirror-choir")) \
		.override_failure_message("Mutating an escaped event must not change a derived standing") \
		.is_equal_approx(baseline_standing + 1.0, 0.001)
	for row: Dictionary in rep.to_dict()["log"]:
		assert_str(str(row["cause"])) \
			.override_failure_message("Mutating an escaped event must not rewrite the serialized log") \
			.is_not_equal("REWRITTEN")
	assert_int(int(baseline_serialized["next_order"])).is_equal(1)
