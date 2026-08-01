extends GdUnitTestSuite

const FactRequirementScript := preload("res://globals/fact_requirement.gd")
const ChapterStageDefinitionScript := preload("res://globals/chapter_stage_definition.gd")
const ChapterDefinitionScript := preload("res://globals/chapter_definition.gd")

var original_flags: Dictionary
var original_quests: Dictionary
var original_party: Array[PartyMember]
var original_autosave_reason: String


func before_test() -> void:
	original_flags = GameState.flags.duplicate(true)
	original_quests = QuestRegistry.to_dict().duplicate(true)
	original_party = GameState.party.duplicate()
	original_autosave_reason = SaveGame._pending_autosave_reason
	GameState.flags.clear()
	QuestRegistry.reset()
	GameState._seed_demo_data()
	SaveGame._pending_autosave_reason = ""


func after_test() -> void:
	QuestRegistry.reset()
	QuestRegistry.from_dict(original_quests)
	GameState.flags = original_flags
	GameState.party = original_party
	SaveGame._pending_autosave_reason = original_autosave_reason


func test_critical_path_is_derived_from_party_quest_and_ruling_facts() -> void:
	assert_int(ChapterOneProgress.current_stage()).is_equal(ChapterOneProgress.Stage.RECRUIT)
	var candidates := GameState.recruitable_candidates()
	GameState.set_companions([candidates[0], candidates[1]])
	assert_int(ChapterOneProgress.current_stage()).is_equal(ChapterOneProgress.Stage.REPORT)

	QuestRegistry.offer(QuestRegistry.DORTHKOR_ROAD)
	assert_int(ChapterOneProgress.current_stage()).is_equal(ChapterOneProgress.Stage.SECURE_ROAD)
	for flag in QuestRegistry.DORTHKOR_ROAD.required_flags:
		GameState.set_flag(flag, true)
	QuestSystem.update_quest(QuestRegistry.DORTHKOR_ROAD)
	assert_int(ChapterOneProgress.current_stage()).is_equal(ChapterOneProgress.Stage.RETURN)

	GameState.set_flag("chapter_one_resolution", "hold-both")
	assert_int(ChapterOneProgress.current_stage()).is_equal(ChapterOneProgress.Stage.COMPLETE)
	GameState.set_flag("chapter_one_free_roam", true)
	assert_int(ChapterOneProgress.current_stage()).is_equal(ChapterOneProgress.Stage.FREE_ROAM)


func test_deep_trial_content_stays_dormant_in_the_external_playtest() -> void:
	QuestSystem.completed.add_quest(QuestRegistry.DORTHKOR_ROAD)
	GameState.set_flag("chapter_one_resolution", "dead-first")

	assert_int(ChapterOneProgress.current_stage()).is_equal(ChapterOneProgress.Stage.COMPLETE)
	assert_str(ChapterOneProgress.title()).is_equal("THE BROKEN MUSTER")


func test_extended_content_flag_continues_into_the_deep_trial() -> void:
	QuestSystem.completed.add_quest(QuestRegistry.DORTHKOR_ROAD)
	GameState.set_flag("chapter_one_resolution", "dead-first")
	GameState.set_flag("prototype_extended_content", true)

	assert_int(ChapterOneProgress.current_stage()).is_equal(
		ChapterOneProgress.Stage.DEEP_TRIAL_OFFER
	)
	QuestRegistry.offer(QuestRegistry.DEEP_TRIAL)
	assert_int(ChapterOneProgress.current_stage()).is_equal(ChapterOneProgress.Stage.DEEP_TRIAL)
	assert_str(ChapterOneProgress.title()).is_equal("THE DEEP TRIAL")
	assert_bool(GameState.get_flag("deep_trial_open")).is_true()

	for flag in QuestRegistry.DEEP_TRIAL.required_flags:
		GameState.set_flag(flag, true)
	assert_int(ChapterOneProgress.current_stage()).is_equal(
		ChapterOneProgress.Stage.DEEP_TRIAL_RETURN
	)


func test_free_roam_objective_opens_loamroot() -> void:
	GameState.set_flag("chapter_one_free_roam", true)

	assert_bool(ChapterOneProgress.loamroot_unlocked()).is_true()
	assert_str(ChapterOneProgress.objective()).contains("Free roam: the Loamroot grove is now open east of Dom.")
	assert_str(ChapterOneProgress.destination()).contains("Loamroot Grove")
	assert_str(ChapterOneProgress.action_hint()).contains("Explore")


## New progression tests for the extracted chapter progression contract:
## fresh run, Bloodbellow outcomes, Dom rulings, save/load reconstruction, and dormant extended content.

func test_fresh_run_default_state() -> void:
	# Clear out any companions to ensure a fresh state
	GameState.party.clear()
	assert_int(ChapterOneProgress.current_stage()).is_equal(ChapterOneProgress.Stage.RECRUIT)
	assert_str(ChapterOneProgress.objective()).is_equal("Enter the Four Arms and choose exactly two companions.")
	assert_str(ChapterOneProgress.title()).is_equal("THE BROKEN MUSTER")


func test_all_three_bloodbellow_outcomes() -> void:
	# Bloodbellow outcomes: named, released, slain.
	# These facts are set via 'dorthkor_muster_outcome'.

	# Scenario 1: named
	GameState.set_flag("dorthkor_muster_outcome", "named")
	assert_str(GameState.get_flag("dorthkor_muster_outcome")).is_equal("named")

	# Scenario 2: released
	GameState.set_flag("dorthkor_muster_outcome", "released")
	assert_str(GameState.get_flag("dorthkor_muster_outcome")).is_equal("released")

	# Scenario 3: slain
	GameState.set_flag("dorthkor_muster_outcome", "slain")
	assert_str(GameState.get_flag("dorthkor_muster_outcome")).is_equal("slain")


func test_all_three_dom_rulings() -> void:
	# Dom rulings: demons-first, dead-first, hold-both.
	# These rulings are set via 'chapter_one_resolution'.

	# 1. demons-first
	GameState.set_flag("chapter_one_resolution", "demons-first")
	assert_int(ChapterOneProgress.current_stage()).is_equal(ChapterOneProgress.Stage.COMPLETE)
	assert_str(ChapterOneProgress.objective()).is_equal("Review the consequence ledger for The Broken Muster.")

	# 2. dead-first
	GameState.set_flag("chapter_one_resolution", "dead-first")
	assert_int(ChapterOneProgress.current_stage()).is_equal(ChapterOneProgress.Stage.COMPLETE)

	# 3. hold-both
	GameState.set_flag("chapter_one_resolution", "hold-both")
	assert_int(ChapterOneProgress.current_stage()).is_equal(ChapterOneProgress.Stage.COMPLETE)


func test_save_load_reconstruction() -> void:
	# Progress chapter to RETURN
	var candidates := GameState.recruitable_candidates()
	GameState.set_companions([candidates[0], candidates[1]])
	QuestRegistry.offer(QuestRegistry.DORTHKOR_ROAD)
	for flag in QuestRegistry.DORTHKOR_ROAD.required_flags:
		GameState.set_flag(flag, true)
	QuestSystem.update_quest(QuestRegistry.DORTHKOR_ROAD)
	assert_int(ChapterOneProgress.current_stage()).is_equal(ChapterOneProgress.Stage.RETURN)

	# Serialize the state
	var saved_flags := GameState.flags.duplicate(true)
	var saved_quests := QuestRegistry.to_dict().duplicate(true)
	var saved_party := GameState.party.duplicate()

	# Clear live state to simulate loading/resets
	GameState.flags.clear()
	QuestRegistry.reset()
	GameState.party.clear()
	assert_int(ChapterOneProgress.current_stage()).is_equal(ChapterOneProgress.Stage.RECRUIT)

	# Restore state to simulate reconstruction
	GameState.flags = saved_flags
	QuestRegistry.from_dict(saved_quests)
	GameState.party = saved_party
	assert_int(ChapterOneProgress.current_stage()).is_equal(ChapterOneProgress.Stage.RETURN)


func test_unknown_or_incomplete_facts_safe_fallback() -> void:
	# Create an incomplete requirement (null quest reference)
	var incomplete_req: Resource = FactRequirementScript.new()
	incomplete_req.type = FactRequirementScript.Type.QUEST_ACTIVE
	incomplete_req.target_quest = null

	assert_bool(incomplete_req.is_valid()).is_false()
	assert_bool(incomplete_req.is_met()).is_false()

	# Test safe fallback in stage evaluation
	var definition: Resource = ChapterDefinitionScript.new()
	var stage: Resource = ChapterStageDefinitionScript.new()
	stage.id = "TEST_STAGE"
	var requirements_typed: Array[Resource] = []
	requirements_typed.append(incomplete_req)
	stage.requirements = requirements_typed

	assert_str(definition.get_objective(stage)).is_equal("Objective status unclear. Check journal.")


func test_generic_definition_dormant_extended_content() -> void:
	var def: Resource = ChapterDefinitionScript.new()
	def.id = "test_chapter"
	def.default_title = "DEFAULT TITLE"
	def.follow_up_condition_flag = "prototype_extended_content"

	var stage_std: Resource = ChapterStageDefinitionScript.new()
	stage_std.id = "STANDARD"
	stage_std.title = "STANDARD TITLE"
	stage_std.objective = "STANDARD OBJECTIVE"

	var req_ext: Resource = FactRequirementScript.new()
	req_ext.type = FactRequirementScript.Type.FLAG_TRUE
	req_ext.target_flag = "some_ext_flag"

	var stage_ext: Resource = ChapterStageDefinitionScript.new()
	stage_ext.id = "EXTENDED"
	stage_ext.title = "EXTENDED TITLE"
	stage_ext.objective = "EXTENDED OBJECTIVE"

	var reqs: Array[Resource] = []
	reqs.append(req_ext)
	stage_ext.requirements = reqs

	var std_stages: Array[Resource] = []
	std_stages.append(stage_std)
	def.stages = std_stages

	var ext_stages: Array[Resource] = []
	ext_stages.append(stage_ext)
	def.follow_up_stages = ext_stages

	# Scenario A: prototype_extended_content is FALSE (or not set)
	GameState.set_flag("prototype_extended_content", false)
	GameState.set_flag("some_ext_flag", true)
	var current_a: Resource = def.get_current_stage()
	assert_str(current_a.id).is_equal("STANDARD")
	assert_str(def.get_title(current_a)).is_equal("STANDARD TITLE")
	assert_str(def.get_objective(current_a)).is_equal("STANDARD OBJECTIVE")

	# Scenario B: prototype_extended_content is TRUE
	GameState.set_flag("prototype_extended_content", true)
	var current_b: Resource = def.get_current_stage()
	assert_str(current_b.id).is_equal("EXTENDED")
	assert_str(def.get_title(current_b)).is_equal("EXTENDED TITLE")
	assert_str(def.get_objective(current_b)).is_equal("EXTENDED OBJECTIVE")

	# Clean up test flags
	GameState.flags.erase("prototype_extended_content")
	GameState.flags.erase("some_ext_flag")
