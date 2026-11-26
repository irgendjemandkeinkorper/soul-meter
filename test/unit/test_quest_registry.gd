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
var original_party: Array[PartyMember] = []
var original_zhavar: Dictionary = {}


func before_test() -> void:
	original_party = GameState.party.duplicate()
	original_flags = GameState.flags.duplicate(true)
	original_reputation = Reputation.to_dict().duplicate(true)
	original_renown = Renown.to_dict().duplicate(true)
	original_quests = QuestRegistry.to_dict().duplicate(true)
	original_soul_meter = GameState.soul_meter
	original_autosave_reason = SaveGame._pending_autosave_reason
	# resolve_broken_muster() raises the wilds Zhavar rung (FR-308) and a rung never
	# lowers, so the suite starts from the quiet ladder and hands back what it inherited;
	# otherwise every later suite in a whole-tree run meets a tolling wilds (the Dom
	# rumor-carriers rewire onto dom_zhavar_rumors.dialogue, test_town_townsfolk).
	original_zhavar = SaveGame.zhavar.duplicate(true)
	SaveGame.zhavar.clear()
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
	SaveGame.zhavar = original_zhavar.duplicate(true)
	GameState.party = original_party
	# Granting quest rewards queues a full-screen reward reveal on UIManager; drop it so it
	# cannot swallow a later suite's focus or clicks.
	UIManager.reset_reward_reveals()


## #285 / game-identity ruling 9: XP comes from combat AND quests. Before this,
## `PartyMember.xp` had no writer anywhere in the codebase.
func test_completing_a_quest_awards_the_party_xp() -> void:
	var hero := PartyMember.new()
	hero.id = "test-quest-hero"
	GameState.party = [hero]

	var quest: FetchQuest = QuestRegistry.LOAMROOT_SPRIGS
	QuestRegistry.offer(quest)
	for _sprig in 3:
		GameState.inventory.create_and_add_item(ItemIds.MATERIALS_LOAMROOT_SPRIG)
	quest.update()
	QuestRegistry.turn_in(quest)

	assert_bool(QuestRegistry.is_done(quest)).is_true()
	assert_int(hero.xp + (hero.level - 1) * Advancement.XP_BASE).override_failure_message(
		"a completed quest paid no XP"
	).is_greater(0)


## Gated on `not was_done`, the same guard the reward summary uses. A re-entrant
## turn-in that paid again would make every quest a repeatable XP faucet.
func test_turning_a_quest_in_twice_pays_xp_once() -> void:
	var hero := PartyMember.new()
	hero.id = "test-quest-hero-twice"
	GameState.party = [hero]

	var quest: FetchQuest = QuestRegistry.LOAMROOT_SPRIGS
	QuestRegistry.offer(quest)
	for _sprig in 3:
		GameState.inventory.create_and_add_item(ItemIds.MATERIALS_LOAMROOT_SPRIG)
	quest.update()
	QuestRegistry.turn_in(quest)
	var banked := hero.xp
	var level := hero.level

	QuestRegistry.turn_in(quest)

	assert_int(hero.xp).override_failure_message(
		"a second turn-in paid again; the quest is an XP faucet"
	).is_equal(banked)
	assert_int(hero.level).is_equal(level)


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
	var marshal_route: Dictionary = QuestRegistry.dialogue_route_for_actor(
		"branek-coiljaw", QuestRegistry.COUNCIL_ELDER_DIALOGUE_PATH, "start"
	)
	var marshal_resource: DialogueResource = marshal_route.get("resource") as DialogueResource
	var expected_marshal: DialogueResource = ResourceLoader.load(
		QuestRegistry.MARSHAL_DIALOGUE_PATH
	) as DialogueResource
	assert_bool(marshal_resource == expected_marshal).is_true()
	assert_str(marshal_route["title"]).is_equal("start")

	var side_quest: DomSideQuest = QuestRegistry.DOM_SIDE_QUESTS[0]
	var side_route: Dictionary = QuestRegistry.dialogue_route_for_actor(
		side_quest.giver_actor_id, QuestRegistry.COUNCIL_ELDER_DIALOGUE_PATH, "start"
	)
	var side_resource: DialogueResource = side_route.get("resource") as DialogueResource
	var expected_side: DialogueResource = ResourceLoader.load(
		QuestRegistry.DOM_SIDE_QUEST_DIALOGUE_PATH
	) as DialogueResource
	assert_bool(side_resource == expected_side).is_true()
	assert_str(side_route["title"]).is_equal(side_quest.dialogue_title)

	var fallback_route: Dictionary = QuestRegistry.dialogue_route_for_actor(
		"nobody-in-particular", QuestRegistry.COUNCIL_ELDER_DIALOGUE_PATH, "start"
	)
	var fallback_resource: DialogueResource = fallback_route.get("resource") as DialogueResource
	var expected_fallback: DialogueResource = ResourceLoader.load(
		QuestRegistry.COUNCIL_ELDER_DIALOGUE_PATH
	) as DialogueResource
	assert_bool(fallback_resource == expected_fallback).is_true()
	assert_str(fallback_route["title"]).is_equal("start")
	# Pin the WHOLE key set, not just the absence of "path". Asserting one banned
	# key only bans that spelling: a later change added "path" back alongside a
	# second "campaign_source", and a has("path") check would have caught the
	# first while waving the second through. The route carries a resource, a
	# title, an error, and one diagnostic-only source. Nothing else.
	var fallback_keys: Array = fallback_route.keys()
	fallback_keys.sort()
	assert_array(fallback_keys).contains_exactly(["error", "resource", "source", "title"])


func test_dialogue_route_for_ordinary_npc_resolves_committed_resource() -> void:
	var route: Dictionary = QuestRegistry.dialogue_route_for_actor(
		"ordinary-npc-without-a-quest",
		QuestRegistry.DOM_SIDE_QUEST_DIALOGUE_PATH,
		"dom_side_dishonest_casks"
	)
	var resource: DialogueResource = route.get("resource") as DialogueResource

	assert_object(resource).is_not_null()
	assert_bool(resource.get_cues().has("dom_side_dishonest_casks")).is_true()
	assert_str(str(route.get("title", ""))).is_equal("dom_side_dishonest_casks")


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


## Q1 (docs/design/quest-system-sprint-2026-11-26.md): the journal asks the registry how a quest
## ended. Each resolver's own write is the source, driven through the resolver real play uses.
func test_resolution_record_reads_the_choice_each_resolver_wrote() -> void:
	var empty := {"label": "", "detail": ""}
	var side: DomSideQuest = QuestRegistry.LIVING_TAG
	assert_dict(QuestRegistry.resolution_record(side)).is_equal(empty)
	assert_bool(QuestRegistry.offer_side_quest(side)).is_true()
	for flag in side.required_flags:
		GameState.set_flag(flag, true)
	# Active with every step met is still not an outcome.
	assert_dict(QuestRegistry.resolution_record(side)).is_equal(empty)
	assert_bool(QuestRegistry.resolve_side_quest(side, &"restore-the-name")).is_true()
	assert_dict(QuestRegistry.resolution_record(side)).is_equal(
		{"label": side.outcome_labels[1], "detail": side.outcome_readbacks[1]}
	)

	var stub: StubSideQuest = QuestRegistry.STUB_CADENCE
	assert_bool(QuestRegistry.offer_side_quest(stub)).is_true()
	for flag in stub.required_flags:
		GameState.set_flag(flag, true)
	assert_bool(QuestRegistry.suspend_stub(stub)).is_true()
	# A suspended stub chose nothing; the journal says "TO BE CONTINUED" in its state instead.
	assert_dict(QuestRegistry.resolution_record(stub)).is_equal(empty)

	assert_bool(QuestRegistry.debug_force_complete(QuestRegistry.FIELD_DEBT)).is_true()
	assert_dict(QuestRegistry.resolution_record(QuestRegistry.FIELD_DEBT)).is_equal(
		{
			"label": "Split the credit honestly.",
			"detail": QuestRegistry.FIELD_DEBT_REWARDS["balance"]["consequence"],
		}
	)

	_prepare_dorthkor_road_for_ruling()
	assert_bool(QuestRegistry.resolve_broken_muster(&"dead-first")).is_true()
	assert_str(QuestRegistry.resolution_record(QuestRegistry.DORTHKOR_ROAD)["label"]).is_equal(
		"The Ironbrand Sentinels take the deeper investigation."
	)

	QuestRegistry.offer(QuestRegistry.UNANSWERED_ROAR)
	GameState.set_flag("chapter_roar_measured", true)
	QuestRegistry.UNANSWERED_ROAR.update()
	assert_bool(QuestRegistry.resolve_unanswered_roar(&"carry-it-yourself")).is_true()
	assert_str(QuestRegistry.resolution_record(QuestRegistry.UNANSWERED_ROAR)["label"]).is_equal(
		"Carried the shortfall alone, where no one would see it."
	)


## A quest that records no choice has no outcome line, rather than one read off its turn-in step.
func test_resolution_record_is_empty_for_quests_that_record_no_choice() -> void:
	var empty := {"label": "", "detail": ""}
	for quest: Quest in [
		QuestRegistry.BELLHOUSE_REPAIR, QuestRegistry.LOAMROOT_SPRIGS, QuestRegistry.SERAI_LUN_QUEST
	]:
		assert_bool(QuestRegistry.debug_force_complete(quest)).is_true()
		assert_dict(QuestRegistry.resolution_record(quest)).override_failure_message(
			"%s recorded an outcome it never chose" % quest.quest_name
		).is_equal(empty)
	assert_dict(QuestRegistry.resolution_record(null)).is_equal(empty)


# --- Q2: quest news -----------------------------------------------------------

var _taken_up: Array[Quest] = []
var _steps: Array[String] = []


func _listen_for_quest_news() -> void:
	_taken_up.clear()
	_steps.clear()
	QuestRegistry.quest_taken_up.connect(_on_taken_up)
	QuestRegistry.quest_step_reached.connect(_on_step)


func _stop_listening() -> void:
	QuestRegistry.quest_taken_up.disconnect(_on_taken_up)
	QuestRegistry.quest_step_reached.disconnect(_on_step)


func _on_taken_up(quest: Quest) -> void:
	_taken_up.append(quest)


func _on_step(quest: Quest, objective: String) -> void:
	_steps.append("%s|%s" % [quest.quest_name, objective])


func _settle() -> void:
	await get_tree().process_frame
	await get_tree().process_frame


## Quests advance only while the registry hears GameState. A suite that disconnects it must hand
## the connection back (test_interactive_props.gd did not until 2026-11-26); in a whole-tree run
## this names that leak instead of leaving a later step that silently never advances.
func test_the_registry_listens_to_flag_and_inventory_changes() -> void:
	assert_bool(GameState.flag_changed.is_connected(QuestRegistry._on_flag_changed)).override_failure_message(
		"QuestRegistry is not listening to GameState.flag_changed: an earlier suite disconnected it"
	).is_true()
	assert_bool(
		GameState.inventory_changed.is_connected(QuestRegistry._on_inventory_changed)
	).override_failure_message(
		"QuestRegistry is not listening to GameState.inventory_changed: an earlier suite disconnected it"
	).is_true()


func test_taking_up_a_quest_is_announced_once() -> void:
	_listen_for_quest_news()
	QuestRegistry.offer(QuestRegistry.LIVING_TAG)
	QuestRegistry.offer(QuestRegistry.LIVING_TAG)
	await _settle()
	QuestRegistry.offer(QuestRegistry.LIVING_TAG)
	await _settle()
	_stop_listening()
	assert_array(_taken_up).contains_exactly([QuestRegistry.LIVING_TAG])
	assert_array(_steps).is_empty()


func test_reaching_a_step_announces_the_new_objective() -> void:
	QuestRegistry.offer(QuestRegistry.DORTHKOR_ROAD)
	await _settle()
	_listen_for_quest_news()
	GameState.set_flag("chapter_dorthkor_reached", true)
	await _settle()
	# A flag that changes nothing about the quest says nothing.
	GameState.set_flag("some_unrelated_flag", true)
	await _settle()
	_stop_listening()
	assert_array(_steps).contains_exactly(["The Broken Muster|Break the demon vanguard."])


## The step that finishes a quest is the turn-in itself; the reward reveal already speaks for it.
func test_a_step_that_completes_the_quest_in_the_same_moment_is_not_announced() -> void:
	var companion := QuestRegistry.SERAI_LUN_QUEST
	QuestRegistry.offer(companion)
	await _settle()
	_listen_for_quest_news()
	assert_bool(
		QuestRegistry.resolve_companion_quest("serai-lun", companion, 6.0, "Held the line with her")
	).is_true()
	await _settle()
	_stop_listening()
	assert_array(_steps).is_empty()


## Loading restores flags before quest pools, and GameState.from_dict() emits party_changed, which
## offers companion quests against the pools the load is about to replace. None of it is news.
func test_loading_a_save_announces_nothing() -> void:
	var road := QuestRegistry.DORTHKOR_ROAD
	QuestRegistry.offer(road)
	await _settle()
	road.current_stage = 2
	var saved := {"active": [{"id": road.id, "data": road.serialize()}]}
	road.current_stage = 0
	_listen_for_quest_news()
	# What a load does, in the order SaveGame.load does it, in one frame.
	GameState.set_flag("chapter_dorthkor_reached", true)
	GameState.set_flag("defeated_breach_hound", true)
	QuestRegistry.offer(QuestRegistry.SERAI_LUN_QUEST)
	QuestRegistry.from_dict(saved)
	await _settle()
	_stop_listening()
	assert_array(_taken_up).is_empty()
	assert_array(_steps).is_empty()
	assert_int(road.current_stage).is_equal(2)

