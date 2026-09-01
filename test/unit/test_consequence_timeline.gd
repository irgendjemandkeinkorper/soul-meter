extends GdUnitTestSuite

const TimelineScript := preload("res://globals/consequence_timeline.gd")

var _reputation_before: Dictionary
var _renown_before: Dictionary
var _timeline: Node


func before_test() -> void:
	_reputation_before = Reputation.to_dict().duplicate(true)
	_renown_before = Renown.to_dict().duplicate(true)
	Reputation.from_dict({"log": [], "next_order": 0})
	Renown.from_dict({"log": [], "next_order": 0})
	_timeline = auto_free(TimelineScript.new()) as Node
	add_child(_timeline)
	_timeline.set("force_enabled_for_tests", true)


func after_test() -> void:
	if _timeline != null:
		_timeline.set("force_enabled_for_tests", false)
	Reputation.from_dict(_reputation_before)
	Renown.from_dict(_renown_before)


func test_observing_both_ledgers_never_adds_events() -> void:
	Reputation.record("player", "mirror-choir", 4.0, "Gameplay faction choice", "test_room")
	Renown.gain_reputation("player", 2.0, "Gameplay renown choice", "test_room")

	var rows: Array[Dictionary] = _timeline.call("rows")
	assert_int(Reputation.event_count()).is_equal(1)
	assert_int(Renown.history().size()).is_equal(1)
	assert_int(rows.size()).is_equal(2)
	assert_str(str(rows[0]["ledger"])).is_equal("RENOWN")
	assert_str(str(rows[1]["ledger"])).is_equal("REPUTATION")


func test_live_arrival_order_wins_over_independent_ledger_order() -> void:
	Reputation.record("player", "mirror-choir", 1.0, "reputation order zero", "test_room")
	Reputation.record("player", "mirror-choir", 1.0, "reputation order one", "test_room")
	Renown.gain_infamy("player", 3.0, "renown order zero but later", "test_room")

	var rows: Array[Dictionary] = _timeline.call("rows")
	assert_str(str(rows[0]["cause"])).is_equal("renown order zero but later")
	assert_int(int(rows[0]["source_order"])).is_equal(0)
	assert_str(str(rows[1]["cause"])).is_equal("reputation order one")
	assert_int(int(rows[1]["source_order"])).is_equal(1)
	assert_int(int(rows[0]["arrival"])).is_greater(int(rows[1]["arrival"]))


func test_debug_provenance_is_classified_from_dev_console_prefix() -> void:
	Reputation.record(
		"player", "the-registry", 1.0,
		DevConsole.DEBUG_CAUSE_PREFIX + "console-authored consequence", "test_room"
	)
	Renown.gain_reputation("player", 1.0, "genuine gameplay consequence", "test_room")

	var rows: Array[Dictionary] = _timeline.call("rows")
	assert_bool(bool(rows[0]["debug_injected"])).is_false()
	assert_bool(bool(rows[1]["debug_injected"])).is_true()


func test_retained_rows_are_capped_newest_first() -> void:
	var cap: int = TimelineScript.MAX_RETAINED_ROWS
	for index: int in range(cap + 5):
		Reputation.record(
			"player", "mirror-choir", 1.0, "event %d" % index, "test_room"
		)

	var rows: Array[Dictionary] = _timeline.call("rows")
	assert_int(rows.size()).is_equal(cap)
	assert_str(str(rows[0]["cause"])).is_equal("event %d" % (cap + 4))
	assert_str(str(rows[cap - 1]["cause"])).is_equal("event 5")


func test_backfill_is_restored_and_uses_each_ledgers_own_history() -> void:
	_timeline.set("force_enabled_for_tests", false)
	Reputation.record("player", "mirror-choir", 5.0, "older faction event", "test_room")
	Reputation.record("player", "mirror-choir", -2.0, "newer faction event", "test_room")
	Renown.gain_infamy("player", 7.0, "restored infamy", "test_room")
	_timeline.set("force_enabled_for_tests", true)

	var rows: Array[Dictionary] = _timeline.call("rows")
	assert_int(rows.size()).is_equal(3)
	for row: Dictionary in rows:
		assert_bool(bool(row["restored"])).is_true()
	var faction_rows: Array[Dictionary] = []
	for row: Dictionary in rows:
		if str(row["ledger"]) == "REPUTATION":
			faction_rows.append(row)
	assert_str(str(faction_rows[0]["cause"])).is_equal("newer faction event")
	assert_float(float(faction_rows[0]["resulting"])).is_equal_approx(3.0, 0.001)
	assert_float(float(faction_rows[1]["resulting"])).is_equal_approx(5.0, 0.001)


func test_history_accessors_are_newest_first_and_respect_limits() -> void:
	Reputation.record("player", "mirror-choir", 1.0, "rep first", "test_room")
	Reputation.record("player", "the-registry", 1.0, "rep second", "test_room")
	Renown.gain_reputation("player", 1.0, "renown first", "test_room")
	Renown.gain_infamy("player", 1.0, "renown second", "test_room")

	var reputation_history: Array[ReputationEvent] = Reputation.history(1)
	var renown_history: Array[RenownEvent] = Renown.history(1)
	assert_int(reputation_history.size()).is_equal(1)
	assert_str(reputation_history[0].cause).is_equal("rep second")
	assert_int(renown_history.size()).is_equal(1)
	assert_str(renown_history[0].cause).is_equal("renown second")
	assert_int(Reputation.history().size()).is_equal(2)
	assert_int(Renown.history().size()).is_equal(2)


func test_the_feed_resyncs_when_a_load_replaces_the_ledgers() -> void:
	# Gate finding 2: the timeline is enabled at startup, BEFORE a player loads a
	# save. SaveGame replaces both ledgers through from_dict(), which emits no
	# change signal, so a purely signal-fed feed would keep showing the previous
	# game's consequences and never acquire the loaded ones.
	Reputation.record("player", "mirror-choir", 3.0, "from the ABANDONED run", "test_room")
	assert_int(_timeline.call("rows").size()).is_equal(1)

	# A load: both ledgers replaced wholesale, no ledger signal emitted.
	Reputation.from_dict({
		"log": [{
			"actor": "player", "faction": "the-registry", "delta": 7.0,
			"cause": "from the LOADED save", "scene": "test_room", "at": 100, "order": 0,
		}],
		"next_order": 1,
	})
	Renown.from_dict({"log": [], "next_order": 0})
	# Demonstrate the staleness explicitly: the feed still shows the abandoned
	# run here, because from_dict() emitted nothing. Asserting the size alone
	# would pass whether or not the bug was present.
	var stale_rows: Array[Dictionary] = _timeline.call("rows")
	assert_str(str(stale_rows[0]["cause"])).is_equal("from the ABANDONED run")

	# The wiring contract, asserted directly. Emitting SaveGame.load_requested for
	# real would also run GameFlow's production listener, which would try to route
	# a scene load from a unit test — so assert the connection exists, then drive
	# only OUR handler.
	assert_bool(SaveGame.load_requested.is_connected(Callable(_timeline, "_on_load_requested"))) \
		.override_failure_message("An enabled timeline must subscribe to the load resync seam") \
		.is_true()
	_timeline.call("_on_load_requested", null)

	var rows: Array[Dictionary] = _timeline.call("rows")
	assert_int(rows.size()).is_equal(1)
	assert_str(str(rows[0]["cause"])) \
		.override_failure_message("After a load the feed must show the LOADED history, not the abandoned run's") \
		.is_equal("from the LOADED save")
