extends GdUnitTestSuite

const CampaignQuestLoaderScript := preload("res://globals/campaign_quest_loader.gd")

var _original_quests: Dictionary
var _original_flags: Dictionary


func before_test() -> void:
	_original_quests = QuestRegistry.to_dict().duplicate(true)
	_original_flags = GameState.flags.duplicate(true)
	QuestRegistry.clear_runtime_quests()
	QuestRegistry.reset()


func after_test() -> void:
	GameState.flags = _original_flags
	QuestRegistry.clear_runtime_quests()
	QuestRegistry.reset()
	QuestRegistry.from_dict(_original_quests)


func test_quest_only_replacement_is_atomic_and_legacy_clear_still_clears_both() -> void:
	var original: DomSideQuest = _runtime_quest("campaign/atomic-original")
	assert_bool(QuestRegistry.replace_runtime_quests([original])).is_true()
	assert_bool(EncounterCatalog.register_runtime_encounters({"unrelated": {"display_name": "Keep"}})).is_true()
	QuestRegistry.offer(original)
	original.current_stage = 1
	var invalid: DomSideQuest = _runtime_quest("campaign/atomic-invalid")
	invalid.id = 1
	assert_bool(QuestRegistry.replace_runtime_quests([invalid])).is_false()
	assert_object(QuestRegistry.runtime_quests()[0]).is_same(original)
	assert_bool(QuestRegistry.is_active(original)).is_true()
	assert_int(original.current_stage).is_equal(1)
	assert_str(EncounterCatalog.definition(&"unrelated").display_name).is_equal("Keep")
	QuestRegistry.clear_runtime_quests_only()
	assert_array(QuestRegistry.runtime_quests()).is_empty()
	assert_str(EncounterCatalog.definition(&"unrelated").display_name).is_equal("Keep")
	QuestRegistry.clear_runtime_quests()
	assert_dict(EncounterCatalog.definition(&"unrelated")).is_empty()


func test_runtime_quest_survives_registry_save_round_trip() -> void:
	var quest: DomSideQuest = _runtime_quest("campaign/save-round-trip")
	assert_bool(QuestRegistry.register_runtime_quests([quest])).is_true()
	QuestRegistry.offer(quest)
	GameState.set_flag("campaign_runtime_progress", true)
	QuestSystem.update_quest(quest)
	var saved: Dictionary = QuestRegistry.to_dict().duplicate(true)

	QuestRegistry.reset()
	assert_int(quest.current_stage).is_equal(0)
	QuestRegistry.from_dict(saved)

	assert_bool(QuestRegistry.is_active(quest)).is_true()
	assert_int(quest.current_stage).is_equal(1)
	assert_bool(quest.objective_completed).is_true()


func test_missing_runtime_quest_save_row_warns_and_is_skipped() -> void:
	var quest: DomSideQuest = _runtime_quest("campaign/missing-after-save")
	assert_bool(QuestRegistry.register_runtime_quests([quest])).is_true()
	QuestRegistry.offer(quest)
	var saved: Dictionary = QuestRegistry.to_dict().duplicate(true)
	QuestRegistry.clear_runtime_quests()

	await assert_error(QuestRegistry.from_dict.bind(saved)).is_push_warning(
		"QuestRegistry: save row references missing quest id %d in active pool; skipping." % quest.id
	)
	assert_bool(QuestSystem.get_active_quests().is_empty()).is_true()


func test_colliding_runtime_save_identity_warns_and_skips_the_wrong_quest() -> void:
	var saved_identity := "campaign/q-fwuvvs-1j60dje"
	var replacement_identity := "campaign/q-wczx8f-1at7dj4"
	var saved_quest: DomSideQuest = _runtime_quest(saved_identity)
	var replacement_quest: DomSideQuest = _runtime_quest(replacement_identity)
	assert_int(saved_quest.id).is_equal(1_266_710_378)
	assert_int(replacement_quest.id).is_equal(saved_quest.id)
	assert_bool(QuestRegistry.register_runtime_quests([saved_quest])).is_true()
	QuestRegistry.offer(saved_quest)
	GameState.set_flag("campaign_runtime_progress", true)
	QuestSystem.update_quest(saved_quest)
	var saved: Dictionary = QuestRegistry.to_dict().duplicate(true)

	assert_bool(QuestRegistry.register_runtime_quests([replacement_quest])).is_true()
	await assert_error(QuestRegistry.from_dict.bind(saved)).is_push_warning(
		(
			"QuestRegistry: save row identity '%s' does not match registered quest identity "
			+ "'%s' for id %d in active pool; skipping."
		)
		% [saved_identity, replacement_identity, saved_quest.id]
	)

	assert_bool(QuestRegistry.is_active(replacement_quest)).is_false()
	assert_int(replacement_quest.current_stage).is_equal(0)
	assert_bool(replacement_quest.objective_completed).is_false()


func test_runtime_registration_rejects_id_not_derived_from_stable_identity() -> void:
	var quest: DomSideQuest = _runtime_quest("campaign/non-derived-id")
	var derived_id: int = quest.id
	quest.id = derived_id + 1 if derived_id < StableIds.RUNTIME_QUEST_ID_MAX \
		else derived_id - 1

	assert_bool(QuestRegistry.register_runtime_quests([quest])).is_false()
	assert_bool(QuestRegistry.runtime_quests().is_empty()).is_true()


func test_runtime_registration_rejects_id_above_reserved_range() -> void:
	var quest: DomSideQuest = _runtime_quest("campaign/id-above-runtime-range")
	quest.id = StableIds.RUNTIME_QUEST_ID_MAX + 1

	assert_bool(QuestRegistry.register_runtime_quests([quest])).is_false()
	assert_bool(QuestRegistry.runtime_quests().is_empty()).is_true()


func test_production_quest_consumers_use_runtime_aware_registry_accessor() -> void:
	var consumer_paths: PackedStringArray = [
		"res://ui/screens/journal.gd",
		"res://ui/screens/debug_menu.gd",
		"res://globals/dev_console.gd",
	]
	for file_path: String in consumer_paths:
		var file: FileAccess = FileAccess.open(file_path, FileAccess.READ)
		assert_object(file).is_not_null()
		if file == null:
			continue
		var source: String = file.get_as_text()
		file.close()
		assert_bool(not source.contains("QuestRegistry.ALL_QUESTS")) \
			.override_failure_message("%s still hides runtime quests." % file_path) \
			.is_true()


func test_reset_clears_runtime_quest_pool_membership_and_progress() -> void:
	var quest: DomSideQuest = _runtime_quest("campaign/reset")
	assert_bool(QuestRegistry.register_runtime_quests([quest])).is_true()
	QuestRegistry.offer(quest)
	quest.current_stage = 1
	quest.objective_completed = true

	QuestRegistry.reset()

	assert_bool(QuestRegistry.is_active(quest)).is_false()
	assert_bool(quest.objective_completed).is_false()
	assert_int(quest.current_stage).is_equal(0)
	assert_bool(QuestRegistry.all_quests().has(quest)).is_true()


func test_chapter_one_ledger_counts_only_committed_side_quests() -> void:
	# Chapter One's ledger renders "RESOLVED <completed> / <DOM_SIDE_QUESTS.size()>".
	# The denominator is deliberately committed-only so a loaded campaign cannot
	# move Chapter One's goalpost — which means the NUMERATOR has to be
	# committed-only too. completed_side_quests() reports the runtime-aware
	# universe, so a resolved campaign quest would otherwise render "11 / 10".
	var quest: DomSideQuest = _runtime_quest("campaign/ledger-inflation")
	assert_bool(QuestRegistry.register_runtime_quests([quest])).is_true()
	QuestRegistry.offer(quest)
	GameState.set_flag("campaign_runtime_progress", true)
	QuestSystem.update_quest(quest)
	QuestSystem.complete_quest(quest)

	assert_array(QuestRegistry.completed_side_quests()) \
		.override_failure_message("precondition: the runtime quest must be reported as completed") \
		.contains([quest])

	# Assert the RENDERED ledger, not the helper. Calling _committed_only()
	# directly would still pass if the production call site stopped using it,
	# which is the bug this guards against.
	var screen: Node = auto_free(preload("res://ui/screens/chapter_complete.tscn").instantiate())
	var ledger: String = screen.call("_side_quest_ledger_text")

	assert_str(ledger) \
		.override_failure_message(
			"Chapter One's ledger must not count a campaign quest; got:\n%s" % ledger
		) \
		.contains("RESOLVED  0 / %d" % QuestRegistry.DOM_SIDE_QUESTS.size())
	assert_str(ledger) \
		.override_failure_message("a campaign quest must not appear in Chapter One's readbacks") \
		.not_contains(quest.quest_name.to_upper())


func _runtime_quest(identity: String) -> DomSideQuest:
	var quest: DomSideQuest = DomSideQuest.new()
	quest.id = CampaignQuestLoaderScript.runtime_id_for(identity)
	quest.stable_id = identity
	quest.quest_name = identity
	quest.required_flags = PackedStringArray(["campaign_runtime_progress"])
	quest.objectives = PackedStringArray(["Complete runtime progress."])
	quest.outcome_ids = PackedStringArray(["first", "second"])
	quest.outcome_labels = PackedStringArray(["First", "Second"])
	quest.outcome_faction_ids = PackedStringArray(["faction-a", "faction-b"])
	quest.outcome_reputation_deltas = PackedFloat32Array([1.0, -1.0])
	quest.outcome_causes = PackedStringArray(["First", "Second"])
	quest.outcome_readbacks = PackedStringArray(["First", "Second"])
	return quest
