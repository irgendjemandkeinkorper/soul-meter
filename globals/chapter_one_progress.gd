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


static func current_stage() -> Stage:
	# Preserved follow-up content remains dormant in the external-playtest build.
	if bool(GameState.get_flag("prototype_extended_content")):
		if QuestRegistry.is_active(QuestRegistry.DEEP_TRIAL):
			if QuestRegistry.flags_met(QuestRegistry.DEEP_TRIAL):
				return Stage.DEEP_TRIAL_RETURN
			return Stage.DEEP_TRIAL
		if (
			QuestRegistry.is_done(QuestRegistry.DEEP_TRIAL)
			or not str(GameState.get_flag("deep_trial_resolution", "")).is_empty()
		):
			return Stage.DEEP_TRIAL_COMPLETE
		if QuestRegistry.is_done(QuestRegistry.DORTHKOR_ROAD):
			return Stage.DEEP_TRIAL_OFFER
	if bool(GameState.get_flag("chapter_one_free_roam")):
		return Stage.FREE_ROAM
	if not str(GameState.get_flag("chapter_one_resolution", "")).is_empty():
		return Stage.COMPLETE
	if QuestRegistry.is_active(QuestRegistry.DORTHKOR_ROAD):
		if QuestRegistry.flags_met(QuestRegistry.DORTHKOR_ROAD):
			return Stage.RETURN
		return Stage.SECURE_ROAD
	if GameState.has_selected_companions():
		return Stage.REPORT
	return Stage.RECRUIT


static func objective() -> String:
	match current_stage():
		Stage.RECRUIT:
			return "Enter the Four Arms and choose exactly two companions."
		Stage.REPORT:
			return "Report to Marshal Coiljaw at the Trial Hall."
		Stage.SECURE_ROAD:
			return QuestRegistry.objective_for(QuestRegistry.DORTHKOR_ROAD)
		Stage.RETURN:
			return "Return to Marshal Coiljaw and rule on Dom's response."
		Stage.COMPLETE:
			return "Review the consequence ledger for The Broken Muster."
		Stage.DEEP_TRIAL_OFFER:
			return "Ask Marshal Coiljaw what follows the broken muster."
		Stage.DEEP_TRIAL:
			return QuestRegistry.objective_for(QuestRegistry.DEEP_TRIAL)
		Stage.DEEP_TRIAL_RETURN:
			return "Return to Marshal Coiljaw with proof from the first ledge."
		Stage.DEEP_TRIAL_COMPLETE:
			return "Review the consequence ledger for The Deep Trial."
		Stage.FREE_ROAM:
			return "Free roam: the Loamroot grove is now open east of Dom."
	return ""


static func title() -> String:
	match current_stage():
		Stage.DEEP_TRIAL, Stage.DEEP_TRIAL_RETURN, Stage.DEEP_TRIAL_COMPLETE:
			return "THE DEEP TRIAL"
	return "THE BROKEN MUSTER"


static func dorthkor_unlocked() -> bool:
	return (
		QuestRegistry.is_active(QuestRegistry.DORTHKOR_ROAD)
		or QuestRegistry.is_done(QuestRegistry.DORTHKOR_ROAD)
	)


static func loamroot_unlocked() -> bool:
	return bool(GameState.get_flag("chapter_one_free_roam"))
