extends GdUnitTestSuite
## Dedicated coverage for globals/quest_registry.gd (issue #67). test_dom_side_quests.gd and
## test_chapter_one_progress.gd already exercise QuestRegistry indirectly through content and
## chapter-progression contracts; this suite targets QuestRegistry's own methods directly.

var original_flags: Dictionary
var original_reputation: Dictionary
var original_renown: Dictionary
var original_quests: Dictionary
var original_soul_meter: float
var original_autosave_reason: String


func before_test() -> void:
	original_flags = GameState.flags.duplicate(true)
	original_reputation = Reputation.to_dict().duplicate(true)
	original_renown = Renown.to_dict().duplicate(true)
	original_quests = QuestRegistry.to_dict().duplicate(true)
	original_soul_meter = GameState.soul_meter
	original_autosave_reason = SaveGame._pending_autosave_reason
	GameState.flags.clear()
	Reputation.from_dict({})
	Renown.from_dict({})
	QuestRegistry.reset()
	SaveGame._pending_autosave_reason = ""


func after_test() -> void:
	QuestRegistry.reset()
	QuestRegistry.from_dict(original_quests)
	GameState.flags = original_flags
	GameState.soul_meter = original_soul_meter
	Reputation.from_dict(original_reputation)
	Renown.from_dict(original_renown)
	SaveGame._pending_autosave_reason = original_autosave_reason


func test_offer_writes_the_named_bootstrap_side_effects_per_quest() -> void:
	QuestRegistry.offer(QuestRegistry.BELLHOUSE_REPAIR)
	assert_bool(GameState.get_flag("dom_bell_quest_open")).is_true()
	assert_bool(QuestRegistry.is_active(QuestRegistry.BELLHOUSE_REPAIR)).is_true()

	QuestRegistry.offer(QuestRegistry.FIELD_DEBT)
	assert_bool(GameState.get_flag("field_debt_open")).is_true()
	assert_bool(GameState.get_flag("tutorial_road_open")).is_true()


func test_offer_is_a_no_op_the_second_time_a_quest_is_already_active() -> void:
	QuestRegistry.offer(QuestRegistry.BELLHOUSE_REPAIR)
	GameState.set_flag("dom_bell_quest_open", false)

	# Second offer must not re-run the bootstrap side effect because the quest
	# is already active/not newly started.
	QuestRegistry.offer(QuestRegistry.BELLHOUSE_REPAIR)
	assert_bool(GameState.get_flag("dom_bell_quest_open")).is_false()
	assert_bool(QuestRegistry.is_active(QuestRegistry.BELLHOUSE_REPAIR)).is_true()


func test_turn_in_fetch_quest_removes_the_required_items_on_completion() -> void:
	# Bind the shared singleton resource to a local var: reading a mutable
	# property straight off a chained `Autoload.CONST.property` expression can
	# observe the property's static default instead of its live value (a
	# GDScript constant-folding quirk on chained const property reads) — see
	# the report at the end of this suite.
	var quest: FetchQuest = QuestRegistry.LOAMROOT_SPRIGS
	QuestRegistry.offer(quest)
	for i in 3:
		GameState.inventory.create_and_add_item(ItemIds.MATERIALS_LOAMROOT_SPRIG)
	quest.update()

	assert_bool(quest.objective_completed).is_true()
	QuestRegistry.turn_in(quest)

	assert_bool(QuestRegistry.is_done(quest)).is_true()
	assert_int(GameState.item_count(ItemIds.MATERIALS_LOAMROOT_SPRIG)).is_equal(0)


func test_turn_in_refuses_to_complete_an_unfinished_objective() -> void:
	QuestRegistry.offer(QuestRegistry.LOAMROOT_SPRIGS)
	# No sprigs granted, so the fetch objective cannot be satisfied.
	QuestRegistry.turn_in(QuestRegistry.LOAMROOT_SPRIGS)

	assert_bool(QuestRegistry.is_done(QuestRegistry.LOAMROOT_SPRIGS)).is_false()
	assert_bool(QuestRegistry.is_active(QuestRegistry.LOAMROOT_SPRIGS)).is_true()


func test_resolve_field_debt_grants_the_selected_reward_exactly_once() -> void:
	QuestRegistry.offer(QuestRegistry.FIELD_DEBT)
	for flag in QuestRegistry.FIELD_DEBT.required_flags:
		GameState.set_flag(flag, true)

	assert_bool(QuestRegistry.resolve_field_debt(&"balance")).is_true()
	assert_bool(QuestRegistry.is_done(QuestRegistry.FIELD_DEBT)).is_true()
	assert_str(GameState.get_flag("field_debt_reward")).is_equal("balance")

	var companies_events := Reputation.events_for("iron-companies")
	var seeders_events := Reputation.events_for("ssae-seeders")
	var registry_events := Reputation.events_for("the-registry")
	assert_int(companies_events.size()).is_equal(1)
	assert_int(seeders_events.size()).is_equal(1)
	assert_int(registry_events.size()).is_equal(1)
	assert_float(companies_events[0].delta).is_equal_approx(5.0, 0.001)
	assert_float(Renown.reputation()).is_equal_approx(6.0, 0.001)

	# A second attempt must not double-grant the reward or ledger events.
	assert_bool(QuestRegistry.resolve_field_debt(&"balance")).is_false()
	assert_int(Reputation.events_for("iron-companies").size()).is_equal(1)


func test_field_debt_publishes_one_complete_reward_summary_after_all_ledger_writes() -> void:
	QuestRegistry.offer(QuestRegistry.FIELD_DEBT)
	for flag in QuestRegistry.FIELD_DEBT.required_flags:
		GameState.set_flag(flag, true)
	var summaries: Array[Dictionary] = []
	QuestRegistry.quest_rewards_granted.connect(
		func(summary: Dictionary) -> void: summaries.append(summary), CONNECT_ONE_SHOT
	)

	assert_bool(QuestRegistry.resolve_field_debt(&"balance")).is_true()

	assert_int(summaries.size()).is_equal(1)
	var summary := summaries[0]
	assert_str(summary.get("quest_name", "")).is_equal(QuestRegistry.FIELD_DEBT.quest_name)
	assert_str(summary.get("resolution_id", "")).is_equal("balance")
	assert_str(summary.get("resolution_label", "")).is_equal("Split the credit honestly")
	var entries: Array = summary.get("entries", [])
	assert_int(entries.size()).is_equal(4)
	assert_array(entries).contains([
		{
			"kind": "faction",
			"id": "iron-companies",
			"delta": 5.0,
			"detail": "Chose the Split the credit honestly reward for the field debt",
		},
		{
			"kind": "faction",
			"id": "ssae-seeders",
			"delta": 5.0,
			"detail": "Chose the Split the credit honestly reward for the field debt",
		},
		{
			"kind": "faction",
			"id": "the-registry",
			"delta": 5.0,
			"detail": "Chose the Split the credit honestly reward for the field debt",
		},
		{
			"kind": "renown",
			"id": "renown",
			"delta": 6.0,
			"detail": "Returned proof from the first field commission",
		},
	])


## NOTE (found while writing this suite, not fixed here per task scope):
## resolve_field_debt()'s unknown-reward guard is `if not reward is Dictionary: return false`,
## but `FIELD_DEBT_REWARDS.get(reward_id, {})` always returns a Dictionary (the {} default on a
## miss), so the guard can never trip. Unlike resolve_broken_muster(), which additionally checks
## `.is_empty()`, resolve_field_debt() has no such check — an unrecognized reward id silently
## completes the quest with no reputation ledger writes and stores the garbage id verbatim in
## the `field_debt_reward` flag. Left unexercised here rather than asserting the buggy behavior
## as correct; see globals/quest_registry.gd resolve_field_debt().


func test_resolve_broken_muster_gates_hold_both_on_a_centered_soul() -> void:
	_prepare_dorthkor_road_for_ruling()
	GameState.soul_meter = 90.0

	assert_bool(QuestRegistry.resolve_broken_muster(&"hold-both")).is_false()
	assert_bool(QuestRegistry.is_done(QuestRegistry.DORTHKOR_ROAD)).is_false()
	assert_str(GameState.get_flag("chapter_one_resolution", "")).is_equal("")

	GameState.soul_meter = 50.0
	assert_bool(QuestRegistry.resolve_broken_muster(&"hold-both")).is_true()
	assert_bool(QuestRegistry.is_done(QuestRegistry.DORTHKOR_ROAD)).is_true()
	assert_str(GameState.get_flag("chapter_one_resolution")).is_equal("hold-both")

	var companies_events := Reputation.events_for("iron-companies")
	var sentinels_events := Reputation.events_for("ironbrand-sentinels")
	assert_int(companies_events.size()).is_equal(1)
	assert_float(companies_events[0].delta).is_equal_approx(7.0, 0.001)
	assert_int(sentinels_events.size()).is_equal(1)
	assert_float(Renown.reputation()).is_equal_approx(14.0, 0.001)


func test_resolve_broken_muster_rejects_an_unregistered_ruling() -> void:
	_prepare_dorthkor_road_for_ruling()

	assert_bool(QuestRegistry.resolve_broken_muster(&"not-a-real-ruling")).is_false()
	assert_bool(QuestRegistry.is_done(QuestRegistry.DORTHKOR_ROAD)).is_false()


func test_resolve_broken_muster_requires_bloodbellow_reported_first() -> void:
	QuestRegistry.offer(QuestRegistry.DORTHKOR_ROAD)
	for flag in QuestRegistry.DORTHKOR_ROAD.required_flags:
		GameState.set_flag(flag, true)
	# Deliberately omit reported_bloodbellow.

	assert_bool(QuestRegistry.resolve_broken_muster(&"demons-first")).is_false()
	assert_bool(QuestRegistry.is_done(QuestRegistry.DORTHKOR_ROAD)).is_false()


func test_dialogue_route_for_actor_routes_marshal_side_quest_and_fallback() -> void:
	var marshal_route := QuestRegistry.dialogue_route_for_actor(
		"branek-coiljaw", "res://fallback.dialogue", "fallback_title"
	)
	assert_str(marshal_route["path"]).is_equal(QuestRegistry.MARSHAL_DIALOGUE_PATH)
	assert_str(marshal_route["title"]).is_equal("start")

	var side_quest := QuestRegistry.DOM_SIDE_QUESTS[0]
	var side_route := QuestRegistry.dialogue_route_for_actor(
		side_quest.giver_actor_id, "res://fallback.dialogue", "fallback_title"
	)
	assert_str(side_route["path"]).is_equal(QuestRegistry.DOM_SIDE_QUEST_DIALOGUE_PATH)
	assert_str(side_route["title"]).is_equal(side_quest.dialogue_title)

	var fallback_route := QuestRegistry.dialogue_route_for_actor(
		"nobody-in-particular", "res://fallback.dialogue", "fallback_title"
	)
	assert_str(fallback_route["path"]).is_equal("res://fallback.dialogue")
	assert_str(fallback_route["title"]).is_equal("fallback_title")


func test_to_dict_from_dict_round_trip_restores_active_and_completed_pools() -> void:
	# See the note in test_turn_in_fetch_quest_removes_the_required_items_on_completion():
	# bind the shared singletons once and read mutable properties off the local
	# var, not off a fresh `QuestRegistry.CONST.property` chain expression.
	var dorthkor: FlagQuest = QuestRegistry.DORTHKOR_ROAD
	var field_debt: FlagQuest = QuestRegistry.FIELD_DEBT

	QuestRegistry.offer(dorthkor)
	GameState.set_flag("chapter_dorthkor_reached", true)
	QuestSystem.update_quest(dorthkor)
	assert_int(dorthkor.current_stage).is_equal(1)

	QuestRegistry.offer(field_debt)
	for flag in field_debt.required_flags:
		GameState.set_flag(flag, true)
	QuestRegistry.turn_in(field_debt)
	assert_bool(QuestRegistry.is_done(field_debt)).is_true()

	var saved := QuestRegistry.to_dict().duplicate(true)
	QuestRegistry.reset()
	assert_bool(QuestRegistry.is_active(dorthkor)).is_false()
	assert_int(dorthkor.current_stage).is_equal(0)

	QuestRegistry.from_dict(saved)
	assert_bool(QuestRegistry.is_active(dorthkor)).is_true()
	assert_int(dorthkor.current_stage).is_equal(1)
	assert_bool(QuestRegistry.is_done(field_debt)).is_true()


func test_reset_clears_pools_and_progress_for_every_registered_quest() -> void:
	var dorthkor: FlagQuest = QuestRegistry.DORTHKOR_ROAD
	QuestRegistry.offer(dorthkor)
	GameState.set_flag("chapter_dorthkor_reached", true)
	QuestSystem.update_quest(dorthkor)
	assert_int(dorthkor.current_stage).is_equal(1)

	QuestRegistry.reset()

	for quest in QuestRegistry.ALL_QUESTS:
		assert_bool(QuestRegistry.is_active(quest)).is_false()
		assert_bool(QuestRegistry.is_done(quest)).is_false()
		assert_bool(quest.objective_completed).is_false()
		if quest is FlagQuest:
			assert_int(quest.current_stage).is_equal(0)


func test_tracked_quest_prioritizes_story_quests_over_other_active_quests() -> void:
	assert_object(QuestRegistry.tracked_quest()).is_null()

	QuestRegistry.offer_side_quest(QuestRegistry.DOM_SIDE_QUESTS[0])
	assert_object(QuestRegistry.tracked_quest()).is_same(QuestRegistry.DOM_SIDE_QUESTS[0])

	QuestRegistry.offer(QuestRegistry.DORTHKOR_ROAD)
	assert_object(QuestRegistry.tracked_quest()).is_same(QuestRegistry.DORTHKOR_ROAD)


func test_flags_met_is_vacuously_true_for_a_quest_with_no_required_flags() -> void:
	var quest: FlagQuest = auto_free(FlagQuest.new())
	assert_bool(QuestRegistry.flags_met(quest)).is_true()


func test_objective_for_uses_current_objective_for_flag_quests_and_raw_objective_otherwise() -> void:
	assert_str(QuestRegistry.objective_for(QuestRegistry.DORTHKOR_ROAD)).is_equal(
		QuestRegistry.DORTHKOR_ROAD.current_objective()
	)
	assert_str(QuestRegistry.objective_for(QuestRegistry.LOAMROOT_SPRIGS)).is_equal(
		QuestRegistry.LOAMROOT_SPRIGS.quest_objective
	)


func test_offer_side_quest_refuses_a_quest_that_is_already_active() -> void:
	var quest: DomSideQuest = QuestRegistry.DOM_SIDE_QUESTS[0]
	assert_bool(QuestRegistry.offer_side_quest(quest)).is_true()
	assert_bool(QuestRegistry.offer_side_quest(quest)).is_false()


func test_side_quest_readback_is_empty_before_the_quest_resolves() -> void:
	var quest: DomSideQuest = QuestRegistry.DOM_SIDE_QUESTS[0]
	assert_str(QuestRegistry.side_quest_readback(quest)).is_equal("")


func test_active_and_completed_side_quest_helpers_reflect_pool_membership() -> void:
	var quest: DomSideQuest = QuestRegistry.DOM_SIDE_QUESTS[0]
	assert_bool(QuestRegistry.active_side_quests().is_empty()).is_true()
	assert_bool(QuestRegistry.completed_side_quests().is_empty()).is_true()

	QuestRegistry.offer_side_quest(quest)
	assert_array(QuestRegistry.active_side_quests()).contains_exactly([quest])

	for flag in quest.required_flags:
		GameState.set_flag(flag, true)
	QuestRegistry.resolve_side_quest(quest, quest.outcome_ids[0])
	assert_bool(QuestRegistry.active_side_quests().is_empty()).is_true()
	assert_array(QuestRegistry.completed_side_quests()).contains_exactly([quest])


func _prepare_dorthkor_road_for_ruling() -> void:
	QuestRegistry.offer(QuestRegistry.DORTHKOR_ROAD)
	for flag in QuestRegistry.DORTHKOR_ROAD.required_flags:
		GameState.set_flag(flag, true)
	GameState.set_flag("reported_bloodbellow", true)


func test_resolve_field_debt_rejects_an_unknown_reward_id() -> void:
	# Regression: `FIELD_DEBT_REWARDS.get(id, {})` returns a Dictionary on a
	# MISS, so an `is Dictionary` test alone could never reject a bad id. The
	# quest completed and wrote nothing to the ledgers — a dead consequence.
	var quest: FlagQuest = QuestRegistry.FIELD_DEBT
	QuestRegistry.offer(quest)
	for flag in quest.required_flags:
		GameState.set_flag(flag, true)

	var accepted := QuestRegistry.resolve_field_debt(&"not_a_real_reward_id")

	assert_bool(accepted).is_false()
	assert_bool(QuestRegistry.is_done(quest)).is_false()
