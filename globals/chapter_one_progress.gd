class_name ChapterOneProgress
extends RefCounted
## Derived chapter-one progression. The save stores facts (party, quest pools,
## encounter outcomes, and the final ruling), never a duplicate stage counter.

enum Stage {
	RECRUIT,
	REPORT,
	SECURE_ROAD,
	RETURN,
	COMPLETE,
	DEEP_TRIAL_OFFER,
	DEEP_TRIAL,
	DEEP_TRIAL_RETURN,
	DEEP_TRIAL_COMPLETE,
	FREE_ROAM,
}

const STAGE_MAP = {
	"RECRUIT": Stage.RECRUIT,
	"REPORT": Stage.REPORT,
	"SECURE_ROAD": Stage.SECURE_ROAD,
	"RETURN": Stage.RETURN,
	"COMPLETE": Stage.COMPLETE,
	"DEEP_TRIAL_OFFER": Stage.DEEP_TRIAL_OFFER,
	"DEEP_TRIAL": Stage.DEEP_TRIAL,
	"DEEP_TRIAL_RETURN": Stage.DEEP_TRIAL_RETURN,
	"DEEP_TRIAL_COMPLETE": Stage.DEEP_TRIAL_COMPLETE,
	"FREE_ROAM": Stage.FREE_ROAM,
}

const FactRequirementScript := preload("res://globals/fact_requirement.gd")
const ChapterStageDefinitionScript := preload("res://globals/chapter_stage_definition.gd")
const ChapterDefinitionScript := preload("res://globals/chapter_definition.gd")

static var _definition: Resource = null


static func get_definition() -> Resource:
	if _definition != null:
		return _definition

	var def: Resource = ChapterDefinitionScript.new()
	def.id = "chapter_one"
	def.default_title = "THE BROKEN MUSTER"
	def.completion_stage_id = "COMPLETE"
	def.follow_up_condition_flag = "prototype_extended_content"

	# Create standard stages in chronological order
	var recruit: Resource = _create_stage("RECRUIT", "THE BROKEN MUSTER", "Enter the Four Arms and choose exactly two companions.", [], null, "The Four Arms in Dom", "Choose exactly two companions.")

	var report_req: Resource = _create_req(FactRequirementScript.Type.COMPANIONS_SELECTED)
	var report: Resource = _create_stage("REPORT", "THE BROKEN MUSTER", "Report to Marshal Coiljaw at the Trial Hall.", [report_req], null, "Trial Council Hall in Dom", "Speak with Marshal Coiljaw.")

	var secure_req: Resource = _create_req(FactRequirementScript.Type.QUEST_ACTIVE, QuestRegistry.DORTHKOR_ROAD)
	var secure_road: Resource = _create_stage("SECURE_ROAD", "THE BROKEN MUSTER", "", [secure_req], QuestRegistry.DORTHKOR_ROAD, "North Road → Dorthkor", "Break the demon vanguard, then face the dead muster.")

	var return_req_active: Resource = _create_req(FactRequirementScript.Type.QUEST_ACTIVE, QuestRegistry.DORTHKOR_ROAD)
	var return_req_flags: Resource = _create_req(FactRequirementScript.Type.QUEST_FLAGS_MET, QuestRegistry.DORTHKOR_ROAD)
	var return_stage: Resource = _create_stage("RETURN", "THE BROKEN MUSTER", "Return to Marshal Coiljaw and rule on Dom's response.", [return_req_active, return_req_flags], null, "Trial Council Hall in Dom", "Choose a ruling after both encounters.")

	var complete_req: Resource = _create_req(FactRequirementScript.Type.FLAG_NON_EMPTY, null, "chapter_one_resolution")
	var complete: Resource = _create_stage("COMPLETE", "THE BROKEN MUSTER", "Review the consequence ledger for The Broken Muster.", [complete_req], null, "Chapter recap", "Review the ledger, then continue exploring.")

	var free_roam_req: Resource = _create_req(FactRequirementScript.Type.FLAG_TRUE, null, "chapter_one_free_roam")
	var free_roam: Resource = _create_stage("FREE_ROAM", "THE BROKEN MUSTER", "Free roam: the Loamroot grove is now open east of Dom.", [free_roam_req], null, "East Road → Loamroot Grove", "Explore freely or take the next available quest.")

	# Assign standard stages explicitly to the typed array
	var standard_stages: Array[Resource] = []
	standard_stages.append(recruit)
	standard_stages.append(report)
	standard_stages.append(secure_road)
	standard_stages.append(return_stage)
	standard_stages.append(complete)
	standard_stages.append(free_roam)
	def.stages = standard_stages

	# Create follow-up stages in chronological order
	var offer_req: Resource = _create_req(FactRequirementScript.Type.QUEST_DONE, QuestRegistry.DORTHKOR_ROAD)
	var deep_trial_offer: Resource = _create_stage("DEEP_TRIAL_OFFER", "THE BROKEN MUSTER", "Ask Marshal Coiljaw what follows the broken muster.", [offer_req])

	var dt_active: Resource = _create_req(FactRequirementScript.Type.QUEST_ACTIVE, QuestRegistry.DEEP_TRIAL)
	var deep_trial: Resource = _create_stage("DEEP_TRIAL", "THE DEEP TRIAL", "", [dt_active], QuestRegistry.DEEP_TRIAL)

	var dt_flags: Resource = _create_req(FactRequirementScript.Type.QUEST_FLAGS_MET, QuestRegistry.DEEP_TRIAL)
	var deep_trial_return: Resource = _create_stage("DEEP_TRIAL_RETURN", "THE DEEP TRIAL", "Return to Marshal Coiljaw with proof from the first ledge.", [dt_active, dt_flags])

	var dt_done: Resource = _create_req(FactRequirementScript.Type.QUEST_DONE, QuestRegistry.DEEP_TRIAL)
	var dt_res: Resource = _create_req(FactRequirementScript.Type.FLAG_NON_EMPTY, null, "deep_trial_resolution")

	# Model complete condition as two separate stages evaluated in reverse order to simulate 'OR'
	var deep_trial_complete_done: Resource = _create_stage("DEEP_TRIAL_COMPLETE", "THE DEEP TRIAL", "Review the consequence ledger for The Deep Trial.", [dt_done])
	var deep_trial_complete_res: Resource = _create_stage("DEEP_TRIAL_COMPLETE", "THE DEEP TRIAL", "Review the consequence ledger for The Deep Trial.", [dt_res])

	# Assign follow-up stages explicitly to the typed array
	var follow_stages: Array[Resource] = []
	follow_stages.append(deep_trial_offer)
	follow_stages.append(deep_trial)
	follow_stages.append(deep_trial_return)
	follow_stages.append(deep_trial_complete_done)
	follow_stages.append(deep_trial_complete_res)
	def.follow_up_stages = follow_stages

	_definition = def
	return _definition


static func current_stage() -> Stage:
	var def: Resource = get_definition()
	var stage_def: Resource = def.get_current_stage()
	if stage_def == null:
		return Stage.RECRUIT
	return STAGE_MAP.get(stage_def.id, Stage.RECRUIT)


static func objective() -> String:
	var def: Resource = get_definition()
	var stage_def: Resource = def.get_current_stage()
	return def.get_objective(stage_def)


static func destination() -> String:
	var def: Resource = get_definition()
	return def.get_destination(def.get_current_stage())


static func action_hint() -> String:
	var def: Resource = get_definition()
	return def.get_action_hint(def.get_current_stage())


static func title() -> String:
	var def: Resource = get_definition()
	var stage_def: Resource = def.get_current_stage()
	return def.get_title(stage_def)


static func dorthkor_unlocked() -> bool:
	return (
		QuestRegistry.is_active(QuestRegistry.DORTHKOR_ROAD)
		or QuestRegistry.is_done(QuestRegistry.DORTHKOR_ROAD)
	)


static func loamroot_unlocked() -> bool:
	return bool(GameState.get_flag("chapter_one_free_roam"))


static func _create_stage(
	id: String,
	title_text: String,
	objective_text: String,
	reqs: Array[Resource],
	dynamic_quest: Quest = null,
	destination_hint: String = "",
	action_hint: String = ""
) -> Resource:
	var stage: Resource = ChapterStageDefinitionScript.new()
	stage.id = id
	stage.title = title_text
	stage.objective = objective_text
	stage.destination_hint = destination_hint
	stage.action_hint = action_hint
	var requirements_typed: Array[Resource] = []
	for r in reqs:
		requirements_typed.append(r)
	stage.requirements = requirements_typed
	stage.dynamic_objective_quest = dynamic_quest
	return stage


static func _create_req(type: int, quest: Quest = null, flag: String = "") -> Resource:
	var req: Resource = FactRequirementScript.new()
	req.type = type
	req.target_quest = quest
	req.target_flag = flag
	return req
