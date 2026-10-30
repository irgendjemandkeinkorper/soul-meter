extends GdUnitTestSuite
## Owner item 21 (2026-10-24): the Karma act table in docs/karma-acts-draft.md §2 is wired.
## These pin the table's numbers where they live in data and the two rules KarmaActs adds.

var _renown_before: Dictionary


func before_test() -> void:
	_renown_before = Renown.to_dict().duplicate(true)
	Renown.from_dict({})


func after_test() -> void:
	Renown.from_dict(_renown_before)


func _karma_events() -> Array[RenownEvent]:
	var events: Array[RenownEvent] = []
	for event: RenownEvent in Renown.history():
		if event.kind == &"karma":
			events.append(event)
	return events


func test_a_zero_base_writes_nothing() -> void:
	assert_object(KarmaActs.record(0.0, "Won a fight", "field")).is_null()
	assert_int(_karma_events().size()).is_zero()
	assert_object(KarmaActs.record(5.0, "Split the field credit honestly", "field")).is_not_null()
	assert_int(_karma_events().size()).is_equal(1)
	assert_float(_karma_events()[0].base).is_equal(5.0)


func test_petty_theft_is_capped_at_25_base_per_scene() -> void:
	for i in 7:
		KarmaActs.record_theft("Took goods from a crate %d" % i, "res://world/starting_town.tscn")
	assert_float(KarmaActs.theft_spent_in("res://world/starting_town.tscn")).is_equal(KarmaActs.THEFT_CAP_PER_SCENE)
	assert_int(_karma_events().size()).override_failure_message(
		"five thefts of 5 reach the cap; the sixth and seventh write nothing"
	).is_equal(5)

	KarmaActs.record_theft("Took goods from a barrel", "res://world/wilds.tscn")
	assert_float(KarmaActs.theft_spent_in("res://world/wilds.tscn")).is_equal(5.0)


func test_the_theft_cap_survives_a_save_round_trip() -> void:
	for i in 4:
		KarmaActs.record_theft("Took goods from a shelf %d" % i, "res://world/starting_town.tscn")
	Renown.from_dict(Renown.to_dict().duplicate(true))
	KarmaActs.record_theft("Took goods from a shelf 4", "res://world/starting_town.tscn")
	KarmaActs.record_theft("Took goods from a shelf 5", "res://world/starting_town.tscn")
	assert_float(KarmaActs.theft_spent_in("res://world/starting_town.tscn")).is_equal(25.0)


func test_side_quest_karma_matches_the_approved_table() -> void:
	var expected := {
		"dom_ash_in_the_rain": {"hospice-first": 5.0, "market-first": 0.0},
		"dom_cold_bowl": {"bring-them-home": 0.0, "release-the-roll": 5.0},
		"dom_dishonest_casks": {"halt-the-water": 5.0, "keep-the-roar": 0.0},
		"dom_fifth_echo": {"damp-the-echo": 0.0, "keep-the-warning": 5.0},
		"dom_last_safe_course": {"publish-the-course": 5.0, "guard-the-course": 0.0},
		"dom_living_tag": {"quarantine-the-plate": 0.0, "restore-the-name": 10.0},
		"dom_marching_knots": {"give-it-to-the-watch": 0.0, "hang-it-at-the-shrine": 5.0},
		"dom_rainbound_register": {"restore-the-entry": 5.0, "close-the-road-name": 0.0},
		"dom_smoothed_weights": {"void-the-trials": 10.0, "repeat-with-ranks-held": 0.0},
		"dom_unclaimed_bed": {"return-the-name": 0.0, "keep-the-confidence": 5.0},
	}
	for quest_name: String in expected:
		var quest := load("res://quests/%s.tres" % quest_name) as DomSideQuest
		assert_bool(quest.has_complete_outcome_schema()).override_failure_message(quest_name).is_true()
		for outcome_id: String in expected[quest_name]:
			assert_float(float(quest.outcome_for(outcome_id)["karma_base"])).override_failure_message(
				"%s / %s" % [quest_name, outcome_id]
			).is_equal(float(expected[quest_name][outcome_id]))


func test_karma_bases_outside_the_chapter_scale_or_misaligned_are_refused() -> void:
	var quest := (load("res://quests/dom_cold_bowl.tres") as DomSideQuest).duplicate(true) as DomSideQuest
	quest.outcome_karma_bases = PackedFloat32Array([0.0, 25.0])
	assert_bool(quest.has_complete_outcome_schema()).is_false()
	quest.outcome_karma_bases = PackedFloat32Array([5.0])
	assert_bool(quest.has_complete_outcome_schema()).is_false()
	quest.outcome_karma_bases = PackedFloat32Array()
	assert_bool(quest.has_complete_outcome_schema()).is_true()
	assert_float(float(quest.outcome_for("release-the-roll")["karma_base"])).is_equal(0.0)


func test_main_rulings_carry_the_approved_bases() -> void:
	var muster := QuestRegistry.BROKEN_MUSTER_RULINGS
	assert_float(float(muster["demons-first"].get("karma", 0.0))).is_equal(0.0)
	assert_float(float(muster["dead-first"].get("karma", 0.0))).is_equal(0.0)
	assert_float(float(muster["hold-both"]["karma"])).is_equal(10.0)
	var hook := QuestRegistry.ACT_ONE_HOOK_RULINGS
	assert_float(float(hook["sound-the-shortfall"]["karma"])).is_equal(10.0)
	assert_float(float(hook["seal-the-measure"]["karma"])).is_equal(-5.0)
	assert_float(float(hook["carry-it-yourself"]["karma"])).is_equal(15.0)
	assert_array(hook["carry-it-yourself"]["reputation"]).override_failure_message(
		"carry-it-yourself still writes no reputation; only Karma sees it"
	).is_empty()
	var debt := QuestRegistry.FIELD_DEBT_REWARDS
	assert_float(float(debt["balance"]["karma"])).is_equal(5.0)
	for reward_id: String in ["companies", "seeders", "registry"]:
		assert_float(float(debt[reward_id].get("karma", 0.0))).is_equal(0.0)


func test_dialogue_acts_write_karma_inline() -> void:
	var iris := FileAccess.get_file_as_string("res://dialogue/iris_illepah.dialogue")
	for line: String in [
		'Renown.gain_karma("player", -10.0, "Threatened a grove-tender',
		'Renown.gain_karma("player", 5.0, "Opened a vein to the Loam',
		'Renown.gain_karma("player", 5.0, "Brought back what was taken',
		'Renown.gain_karma("player", 10.0, "Paid of their own soul',
		'Renown.gain_karma("player", -10.0, "Seized living specimens',
	]:
		assert_str(iris).contains(line)
	var coiljaw := FileAccess.get_file_as_string("res://dialogue/marshal_coiljaw.dialogue")
	assert_int(coiljaw.count("Renown.gain_karma(")).override_failure_message(
		"only witnessed-descent carries Karma in the Deep Trial"
	).is_equal(1)


## Owner ruling 2026-10-25: Doctrine 5 writes Karma at 1.0x, so a thorough virtuous run
## reaches Upright from Doctrine 3. Summed from the data, so a retuned row moves this.
func test_upright_is_reachable_from_doctrine_three() -> void:
	var best := 0.0
	for rulings: Dictionary in [
		QuestRegistry.BROKEN_MUSTER_RULINGS,
		QuestRegistry.ACT_ONE_HOOK_RULINGS,
		QuestRegistry.FIELD_DEBT_REWARDS,
	]:
		var top := 0.0
		for ruling_id: String in rulings:
			top = maxf(top, float(rulings[ruling_id].get("karma", 0.0)))
		best += top
	for path: String in DirAccess.get_files_at("res://quests"):
		path = path.trim_suffix(".remap")
		if not path.ends_with(".tres"):
			continue
		var quest := load("res://quests/" + path) as DomSideQuest
		if quest == null:
			continue
		var top := 0.0
		for base: float in quest.outcome_karma_bases:
			top = maxf(top, base)
		best += top
	# Dialogue-only acts: witnessed-descent 5, Loamroot communion 10, Iris's vein 5.
	best += 20.0
	# 110 through item 24; the Hollowmere stake (item 25, 2026-10-30) adds its +5.
	assert_float(best).is_equal(115.0)
	var upright_floor := float(Renown.KARMA_TIER_FLOORS[Renown.KARMA_TIER_NAMES.find("Upright")])
	assert_float(best * 3.0 / Renown.KARMA_SCALE_DIVISOR).is_greater_equal(upright_floor)
	assert_float(Renown.KARMA_SCALE_DIVISOR).is_equal(float(DramgidSchema.ATTRIBUTE_CAP))
