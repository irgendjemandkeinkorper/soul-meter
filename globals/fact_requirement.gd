class_name FactRequirement
extends Resource
## FactRequirement — a lore-agnostic, serializable check for a single global fact.

enum Type {
	COMPANIONS_SELECTED,
	QUEST_ACTIVE,
	QUEST_DONE,
	QUEST_FLAGS_MET,
	FLAG_TRUE,
	FLAG_NON_EMPTY
}

@export var type: Type = Type.COMPANIONS_SELECTED
@export var target_quest: Quest = null
@export var target_flag: String = ""


func is_met() -> bool:
	if not is_valid():
		return false
	match type:
		Type.COMPANIONS_SELECTED:
			return GameState.has_selected_companions()
		Type.QUEST_ACTIVE:
			return QuestRegistry.is_active(target_quest)
		Type.QUEST_DONE:
			return QuestRegistry.is_done(target_quest)
		Type.QUEST_FLAGS_MET:
			return QuestRegistry.flags_met(target_quest)
		Type.FLAG_TRUE:
			return bool(GameState.get_flag(target_flag))
		Type.FLAG_NON_EMPTY:
			return not str(GameState.get_flag(target_flag, "")).is_empty()
	return false


func is_valid() -> bool:
	match type:
		Type.QUEST_ACTIVE, Type.QUEST_DONE, Type.QUEST_FLAGS_MET:
			return target_quest != null
		Type.FLAG_TRUE, Type.FLAG_NON_EMPTY:
			return target_flag != ""
		Type.COMPANIONS_SELECTED:
			return true
	return false
