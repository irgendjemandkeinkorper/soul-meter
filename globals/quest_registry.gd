extends Node
## QuestRegistry — the reachable-by-expression surface for quest content.
## Dialogue Manager `do`/`if` lines can't preload() a .tres inline, so named
## quest resources live here as consts (same reason Reputation/GameState are
## autoloads). QuestSystem stays the actual pool/state authority; this just
## keeps dialogue lines readable and keeps fetch-quest progress live as the
## inventory changes.

const LOAMROOT_SPRIGS: FetchQuest = preload("res://quests/loamroot_sprigs.tres")


func _ready() -> void:
	GameState.inventory_changed.connect(_on_inventory_changed)


func offer(quest: Quest) -> void:
	QuestSystem.mark_quest_as_available(quest)
	QuestSystem.start_quest(quest)


func is_active(quest: Quest) -> bool:
	return QuestSystem.is_quest_active(quest)


func is_done(quest: Quest) -> bool:
	return QuestSystem.is_quest_completed(quest)


func turn_in(quest: Quest, resolution: String = "returned", grant_default_reward: bool = true) -> void:
	QuestSystem.update_quest(quest)
	if not quest.objective_completed:
		return
	QuestSystem.complete_quest(quest, {
		"resolution": resolution,
		"grant_default_reward": grant_default_reward,
	})
	if is_done(quest) and quest is FetchQuest:
		GameState.remove_items(quest.item_id, quest.required_amount)


func _on_inventory_changed() -> void:
	for quest in QuestSystem.get_active_quests():
		if quest is FetchQuest:
			QuestSystem.update_quest(quest)
