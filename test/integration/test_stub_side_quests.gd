extends GdUnitTestSuite
## S8 (#302): side quests 5–10 ship VISIBLE and unfinished.
##
## Owner ruling 2026-09-04 (`docs/ship-plan-2026-10.md`): four of ten side
## quests are complete for gold and the other six are signposted rather than
## cut. The property that matters most here is the negative one — a stub must
## not be able to write a ledger row — so most of these cases are about what
## does NOT happen.

const STUB_DIALOGUE := "res://dialogue/dom_side_quest_stubs.dialogue"

var _flags_backup: Dictionary = {}
var _soul_backup: float = 0.0
var _reputation_backup: Dictionary = {}
var _quests_backup: Dictionary = {}


func before_test() -> void:
	_flags_backup = GameState.flags.duplicate(true)
	_soul_backup = GameState.soul_meter
	_reputation_backup = Reputation.to_dict().duplicate(true)
	_quests_backup = QuestRegistry.to_dict().duplicate(true)
	QuestRegistry.reset()


func after_test() -> void:
	GameState.flags.clear()
	GameState.soul_meter = _soul_backup
	GameState.flags = _flags_backup
	Reputation.from_dict(_reputation_backup)
	QuestRegistry.reset()
	QuestRegistry.from_dict(_quests_backup)


func _open(stub: StubSideQuest) -> void:
	QuestRegistry.offer(stub)
	GameState.set_flag(stub.required_flags[0], true)


# --- Shape --------------------------------------------------------------------


func test_six_stubs_ship_and_every_one_is_a_valid_stub() -> void:
	assert_int(QuestRegistry.STUB_SIDE_QUESTS.size()).is_equal(6)
	for stub: StubSideQuest in QuestRegistry.STUB_SIDE_QUESTS:
		assert_bool(stub.is_valid_stub()).override_failure_message(
			"'%s' is not a valid stub" % stub.stable_id
		).is_true()


func test_a_stub_carries_no_outcome_a_ledger_write_could_use() -> void:
	# Not "has no outcome we call" — has none at all, so the write is
	# structurally unreachable rather than merely unused.
	for stub: StubSideQuest in QuestRegistry.STUB_SIDE_QUESTS:
		assert_int(stub.outcome_count()).is_equal(0)
		assert_dict(stub.outcome_for("to-be-continued")).is_empty()
		assert_dict(stub.outcome_for("")).is_empty()


func test_stubs_stay_out_of_the_resolvable_side_quest_count() -> void:
	# `ui/screens/chapter_complete.gd` renders "RESOLVED n / DOM_SIDE_QUESTS.size()".
	# Six unfinishable threads in that denominator would report the player failed
	# six quests they were never given a way to finish.
	assert_int(QuestRegistry.DOM_SIDE_QUESTS.size()).is_equal(10)
	for stub: StubSideQuest in QuestRegistry.STUB_SIDE_QUESTS:
		assert_bool(QuestRegistry.DOM_SIDE_QUESTS.has(stub)).override_failure_message(
			"stub '%s' leaked into the resolvable side-quest count" % stub.stable_id
		).is_false()


func test_every_stub_has_a_distinct_giver_id_and_resume_flag() -> void:
	var givers: Dictionary = {}
	var flags: Dictionary = {}
	var ids: Dictionary = {}
	for stub: StubSideQuest in QuestRegistry.STUB_SIDE_QUESTS:
		assert_bool(givers.has(stub.giver_actor_id)).override_failure_message(
			"two stubs share the giver '%s'" % stub.giver_actor_id
		).is_false()
		assert_bool(flags.has(stub.resume_flag)).override_failure_message(
			"two stubs share the resume flag '%s'" % stub.resume_flag
		).is_false()
		assert_bool(ids.has(stub.id)).override_failure_message(
			"two stubs share the quest id %d" % stub.id
		).is_false()
		givers[stub.giver_actor_id] = true
		flags[stub.resume_flag] = true
		ids[stub.id] = true


func test_no_stub_giver_is_already_a_real_side_quest_giver() -> void:
	var taken: Dictionary = {}
	for quest: DomSideQuest in QuestRegistry.DOM_SIDE_QUESTS:
		taken[quest.giver_actor_id] = quest.stable_id
	for stub: StubSideQuest in QuestRegistry.STUB_SIDE_QUESTS:
		assert_bool(taken.has(stub.giver_actor_id)).override_failure_message(
			"stub '%s' would shadow '%s' on giver '%s'"
			% [stub.stable_id, taken.get(stub.giver_actor_id, ""), stub.giver_actor_id]
		).is_false()


# --- The signpost -------------------------------------------------------------


func test_each_giver_routes_to_the_stub_dialogue_file() -> void:
	# The whole point of "visible in-world": walking up to the giver has to
	# reach the stub, not the generated neutral townsfolk fallback.
	for stub: StubSideQuest in QuestRegistry.STUB_SIDE_QUESTS:
		var route: Dictionary = QuestRegistry.dialogue_route_for_actor(
			stub.giver_actor_id, "res://dialogue/dom_townsfolk.dialogue", "dom_fallback"
		)
		assert_str(str(route["error"])).override_failure_message(
			"'%s' has no readable route" % stub.giver_actor_id
		).is_empty()
		assert_str(str(route["title"])).is_equal(stub.dialogue_title)
		assert_str(str(route["source"])).is_equal(STUB_DIALOGUE)


func test_every_stub_title_and_suspension_title_exists_in_the_dialogue_file() -> void:
	# A route to a missing title is silent at runtime, which looks exactly like
	# an NPC who has nothing to say.
	var file: FileAccess = FileAccess.open(STUB_DIALOGUE, FileAccess.READ)
	assert_object(file).is_not_null()
	var text: String = file.get_as_text()
	file.close()

	for stub: StubSideQuest in QuestRegistry.STUB_SIDE_QUESTS:
		assert_bool(text.contains("~ %s" % stub.dialogue_title)).override_failure_message(
			"'%s' routes to missing title '%s'" % [stub.stable_id, stub.dialogue_title]
		).is_true()
		assert_bool(text.contains("do QuestRegistry.suspend_stub")).is_true()


func test_stub_for_giver_finds_each_one_and_nothing_else() -> void:
	for stub: StubSideQuest in QuestRegistry.STUB_SIDE_QUESTS:
		assert_object(QuestRegistry.stub_for_giver(stub.giver_actor_id)).is_same(stub)
	assert_object(QuestRegistry.stub_for_giver("sella-varn")).is_null()
	assert_object(QuestRegistry.stub_for_giver("")).is_null()


# --- Suspension ---------------------------------------------------------------


func test_suspending_a_stub_completes_it_and_sets_the_resume_flag() -> void:
	var stub: StubSideQuest = QuestRegistry.STUB_SIDE_QUESTS[0]
	_open(stub)

	assert_bool(QuestRegistry.suspend_stub(stub)).is_true()

	assert_bool(QuestRegistry.is_done(stub)).is_true()
	assert_bool(bool(GameState.get_flag(stub.resume_flag, false))).override_failure_message(
		"the resume flag is what a post-launch update keys on; it was not set"
	).is_true()


func test_suspending_writes_no_reputation_row() -> void:
	var stub: StubSideQuest = QuestRegistry.STUB_SIDE_QUESTS[1]
	var before: int = Reputation.event_count()
	_open(stub)

	QuestRegistry.suspend_stub(stub)

	assert_int(Reputation.event_count()).override_failure_message(
		"a stub wrote a consequence row; stubs must not touch the ledger"
	).is_equal(before)


func test_suspending_spends_or_grants_no_soul() -> void:
	var stub: StubSideQuest = QuestRegistry.STUB_SIDE_QUESTS[2]
	var before: float = GameState.soul_meter
	_open(stub)

	QuestRegistry.suspend_stub(stub)

	assert_float(GameState.soul_meter).is_equal(before)


func test_suspending_sets_no_resolution_flag() -> void:
	# A resolution flag says which outcome was chosen. Nothing was chosen.
	var stub: StubSideQuest = QuestRegistry.STUB_SIDE_QUESTS[3]
	_open(stub)

	QuestRegistry.suspend_stub(stub)

	assert_str(stub.resolution_flag).is_empty()


func test_a_stub_cannot_be_resolved_through_the_real_side_quest_path() -> void:
	# `resolve_side_quest()` is the only faction-ledger write Dom side quests
	# use, and a stub reaches its empty-outcome guard before the write.
	var stub: StubSideQuest = QuestRegistry.STUB_SIDE_QUESTS[4]
	var before: int = Reputation.event_count()
	_open(stub)

	assert_bool(QuestRegistry.resolve_side_quest(stub, &"to-be-continued")).is_false()
	assert_bool(QuestRegistry.resolve_side_quest(stub, &"halt-the-water")).is_false()

	assert_int(Reputation.event_count()).is_equal(before)
	assert_bool(QuestRegistry.is_done(stub)).is_false()


func test_suspending_twice_does_not_republish_or_double_complete() -> void:
	var stub: StubSideQuest = QuestRegistry.STUB_SIDE_QUESTS[5]
	_open(stub)
	assert_bool(QuestRegistry.suspend_stub(stub)).is_true()

	assert_bool(QuestRegistry.suspend_stub(stub)).override_failure_message(
		"a suspended stub was suspendable again; a re-enterable stub reads as a bug"
	).is_false()


func test_a_stub_cannot_be_suspended_before_its_beat_is_reached() -> void:
	var stub: StubSideQuest = QuestRegistry.STUB_SIDE_QUESTS[0]
	QuestRegistry.offer(stub)

	assert_bool(QuestRegistry.suspend_stub(stub)).is_false()
	assert_bool(bool(GameState.get_flag(stub.resume_flag, false))).is_false()


func test_a_stub_that_was_never_offered_cannot_be_suspended() -> void:
	var stub: StubSideQuest = QuestRegistry.STUB_SIDE_QUESTS[1]
	GameState.set_flag(stub.required_flags[0], true)

	assert_bool(QuestRegistry.suspend_stub(stub)).is_false()


func test_an_unregistered_stub_is_refused() -> void:
	# Guards the runtime/campaign path: a stub that is not in the shipped array
	# must not be able to complete itself through this method.
	var stray: StubSideQuest = StubSideQuest.new()
	stray.id = 9001
	stray.stable_id = "dom/side/stray"
	stray.giver_actor_id = "nobody"
	stray.dialogue_title = "dom_stub_stray"
	stray.resume_flag = "dom_stray_resume"

	assert_bool(stray.is_valid_stub()).is_true()
	assert_bool(QuestRegistry.suspend_stub(stray)).is_false()


func test_a_stub_authored_with_an_outcome_is_refused_rather_than_half_priced() -> void:
	var dishonest: StubSideQuest = StubSideQuest.new()
	dishonest.stable_id = "dom/side/dishonest-stub"
	dishonest.giver_actor_id = "nobody"
	dishonest.dialogue_title = "dom_stub_dishonest"
	dishonest.resume_flag = "dom_dishonest_stub_resume"
	dishonest.outcome_ids = PackedStringArray(["take-the-money"])

	assert_bool(dishonest.is_valid_stub()).override_failure_message(
		"a stub carrying an outcome passed validation"
	).is_false()


func test_a_stub_without_a_resume_flag_is_refused() -> void:
	# Shipping visible is only worth anything if the save records what was opened.
	var flagless: StubSideQuest = StubSideQuest.new()
	flagless.stable_id = "dom/side/flagless"
	flagless.giver_actor_id = "nobody"
	flagless.dialogue_title = "dom_stub_flagless"

	assert_bool(flagless.is_valid_stub()).is_false()


func test_every_stub_records_what_the_update_is_meant_to_open() -> void:
	# The continuation note exists so the resumed quest is written against a
	# recorded intention rather than a reconstruction of one.
	for stub: StubSideQuest in QuestRegistry.STUB_SIDE_QUESTS:
		assert_str(stub.continuation_note.strip_edges()).override_failure_message(
			"'%s' ships unfinished with no note on what finishes it" % stub.stable_id
		).is_not_empty()
