extends GdUnitTestSuite
## Unit tests for the renown ledger (globals/renown.gd) — see test_reputation.gd
## for why these instantiate the script fresh instead of touching the shared
## `Renown` autoload.

const RenownScript := preload("res://globals/renown.gd")

## Untyped on purpose: renown.gd has no `class_name` — see test_reputation.gd.
var renown


func before_test() -> void:
	renown = auto_free(RenownScript.new())


func test_gain_reputation_returns_event_with_expected_fields() -> void:
	var e: RenownEvent = renown.gain_reputation("player", 5.0, "Defeated a Bog Wight", "test_room")

	assert_str(e.actor).is_equal("player")
	assert_str(e.kind).is_equal("reputation")
	assert_float(e.delta).is_equal(5.0)
	assert_str(e.cause).is_equal("Defeated a Bog Wight")
	assert_str(e.scene).is_equal("test_room")


func test_gain_infamy_returns_event_with_expected_fields() -> void:
	var e: RenownEvent = renown.gain_infamy("player", 5.0, "Threatened a grove-tender", "test_room")

	assert_str(e.kind).is_equal("infamy")
	assert_float(e.delta).is_equal(5.0)


func test_reputation_and_infamy_accumulate_independently() -> void:
	renown.gain_reputation("player", 10.0, "first", "test_room")
	renown.gain_infamy("player", 4.0, "second", "test_room")
	renown.gain_reputation("player", 3.0, "third", "test_room")

	assert_float(renown.reputation()).is_equal_approx(13.0, 0.001)
	assert_float(renown.infamy()).is_equal_approx(4.0, 0.001)


func test_why_returns_newest_first_and_respects_limit_and_kind() -> void:
	renown.gain_reputation("player", 1.0, "first", "test_room")
	renown.gain_infamy("player", 1.0, "infamous act", "test_room")
	renown.gain_reputation("player", 1.0, "second", "test_room")
	renown.gain_reputation("player", 1.0, "third", "test_room")

	var recent: Array = renown.why(&"reputation", 2)

	assert_int(recent.size()).is_equal(2)
	assert_str(recent[0].cause).is_equal("third")
	assert_str(recent[1].cause).is_equal("second")


func test_recording_emits_renown_changed() -> void:
	monitor_signals(renown)

	renown.gain_reputation("player", 5.0, "Signal check", "test_room")

	await assert_signal(renown).is_emitted("renown_changed", &"reputation", 5.0, any())


func test_to_dict_from_dict_round_trip_preserves_totals() -> void:
	renown.gain_reputation("player", 10.0, "Returned the lost relic", "test_room")
	renown.gain_infamy("player", 6.0, "Threatened a grove-tender", "test_room")

	var reloaded = auto_free(RenownScript.new())
	reloaded.from_dict(renown.to_dict())

	assert_float(reloaded.reputation()).is_equal_approx(10.0, 0.001)
	assert_float(reloaded.infamy()).is_equal_approx(6.0, 0.001)
