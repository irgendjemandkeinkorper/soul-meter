extends Node
## QuestRegistry — the reachable-by-expression surface for quest content.
## Dialogue Manager `do`/`if` lines can't preload() a .tres inline, so named
## quest resources live here as consts (same reason Reputation/GameState are
## autoloads). QuestSystem stays the actual pool/state authority; this just
## keeps dialogue lines readable and keeps fetch-quest progress live as the
## inventory changes.

const LOAMROOT_SPRIGS: FetchQuest = preload("res://quests/loamroot_sprigs.tres")
const DORTHKOR_ROAD: FlagQuest = preload("res://quests/dorthkor_road.tres")
const DEEP_TRIAL: FlagQuest = preload("res://quests/deep_trial.tres")
const ALL_QUESTS: Array[Quest] = [LOAMROOT_SPRIGS, DORTHKOR_ROAD, DEEP_TRIAL]
const STORY_QUESTS: Array[Quest] = [DEEP_TRIAL, DORTHKOR_ROAD]


func _ready() -> void:
	GameState.inventory_changed.connect(_on_inventory_changed)
	GameState.flag_changed.connect(_on_flag_changed)


func offer(quest: Quest) -> void:
	var newly_started := not is_active(quest) and not is_done(quest)
	QuestSystem.mark_quest_as_available(quest)
	QuestSystem.start_quest(quest)
	QuestSystem.update_quest(quest)
	if not newly_started:
		return
	if quest == DORTHKOR_ROAD:
		GameState.set_flag("chapter_dorthkor_commissioned", true)
		SaveGame.request_checkpoint(SaveGame.Checkpoint.COMMISSION)
	elif quest == DEEP_TRIAL:
		GameState.set_flag("deep_trial_open", true)
		SaveGame.request_autosave("deep-trial-accepted")


func is_active(quest: Quest) -> bool:
	return QuestSystem.is_quest_active(quest)


func is_done(quest: Quest) -> bool:
	return QuestSystem.is_quest_completed(quest)


func turn_in(
	quest: Quest, resolution: String = "returned", grant_default_reward: bool = true
) -> void:
	QuestSystem.update_quest(quest)
	if quest is FlagQuest:
		quest.objective_completed = flags_met(quest)
	if not quest.objective_completed:
		return
	(
		QuestSystem
		. complete_quest(
			quest,
			{
				"resolution": resolution,
				"grant_default_reward": grant_default_reward,
			}
		)
	)
	if is_done(quest) and quest is FetchQuest:
		GameState.remove_items(quest.item_id, quest.required_amount)
	if is_done(quest):
		SaveGame.request_autosave("quest-completed")


func _on_inventory_changed() -> void:
	for quest in QuestSystem.get_active_quests():
		if quest is FetchQuest:
			QuestSystem.update_quest(quest)


func _on_flag_changed(_flag: String, _value: Variant) -> void:
	for quest in QuestSystem.get_active_quests():
		if quest is FlagQuest:
			QuestSystem.update_quest(quest)


func objective_for(quest: Quest) -> String:
	return quest.current_objective() if quest is FlagQuest else quest.quest_objective


func flags_met(quest: FlagQuest) -> bool:
	for flag in quest.required_flags:
		if not bool(GameState.get_flag(flag, false)):
			return false
	return true


func tracked_quest() -> Quest:
	for quest in STORY_QUESTS:
		if is_active(quest):
			return quest
	var active: Array[Quest] = QuestSystem.get_active_quests()
	return active[0] if not active.is_empty() else null


func to_dict() -> Dictionary:
	return {
		"available": _serialize_pool(QuestSystem.get_available_quests()),
		"active": _serialize_pool(QuestSystem.get_active_quests()),
		"completed": _serialize_pool(QuestSystem.completed.get_all_quests()),
	}


func from_dict(data: Dictionary) -> void:
	QuestSystem.available.reset()
	QuestSystem.active.reset()
	QuestSystem.completed.reset()
	_restore_pool(QuestSystem.available, data.get("available", []))
	_restore_pool(QuestSystem.active, data.get("active", []))
	_restore_pool(QuestSystem.completed, data.get("completed", []))


func reset() -> void:
	QuestSystem.available.reset()
	QuestSystem.active.reset()
	QuestSystem.completed.reset()
	for quest in ALL_QUESTS:
		quest.objective_completed = false


func _serialize_pool(quests: Array[Quest]) -> Array[Dictionary]:
	var rows: Array[Dictionary] = []
	for quest in quests:
		rows.append({"id": quest.id, "data": quest.serialize()})
	return rows


func _restore_pool(pool: BaseQuestPool, rows: Array) -> void:
	for row in rows:
		if not row is Dictionary:
			continue
		var quest := _quest_by_id(int(row.get("id", -1)))
		if quest:
			quest.deserialize(row.get("data", {}))
			pool.add_quest(quest)


func _quest_by_id(id: int) -> Quest:
	for quest in ALL_QUESTS:
		if quest.id == id:
			return quest
	return null
