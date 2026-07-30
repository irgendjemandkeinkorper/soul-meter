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


func turn_in(quest: Quest) -> void:
	QuestSystem.update_quest(quest)
	QuestSystem.complete_quest(quest)


func _on_inventory_changed() -> void:
	for quest in QuestSystem.get_active_quests():
		if quest is FetchQuest:
			QuestSystem.update_quest(quest)
