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
const BELLHOUSE_REPAIR: FlagQuest = preload("res://quests/bellhouse_repair.tres")
const FIELD_DEBT: FlagQuest = preload("res://quests/field_debt.tres")
const ALL_QUESTS: Array[Quest] = [
	LOAMROOT_SPRIGS, DORTHKOR_ROAD, DEEP_TRIAL, BELLHOUSE_REPAIR, FIELD_DEBT
]
const STORY_QUESTS: Array[Quest] = [DEEP_TRIAL, DORTHKOR_ROAD]

const FIELD_DEBT_REWARDS := {
	"companies": {
		"title": "Iron Companies contract",
		"consequence": "Iron Companies +12  ·  Registry -3",
		"reputation": [{"faction": "iron-companies", "delta": 12.0}, {"faction": "the-registry", "delta": -3.0}],
	},
	"seeders": {
		"title": "Ssae-Seeder field rite",
		"consequence": "Ssae-Seeders +10  ·  Iron Companies -2",
		"reputation": [{"faction": "ssae-seeders", "delta": 10.0}, {"faction": "iron-companies", "delta": -2.0}],
	},
	"registry": {
		"title": "Registry classification",
		"consequence": "Registry +10  ·  Ssae-Seeders -4",
		"reputation": [{"faction": "the-registry", "delta": 10.0}, {"faction": "ssae-seeders", "delta": -4.0}],
	},
	"balance": {
		"title": "Split the credit honestly",
		"consequence": "Iron Companies +5  ·  Ssae-Seeders +5  ·  Registry +5",
		"reputation": [
			{"faction": "iron-companies", "delta": 5.0},
			{"faction": "ssae-seeders", "delta": 5.0},
			{"faction": "the-registry", "delta": 5.0},
		],
	},
}


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
	elif quest == BELLHOUSE_REPAIR:
		GameState.set_flag("dom_bell_quest_open", true)
		SaveGame.request_autosave("bellhouse-repair-accepted")
	elif quest == FIELD_DEBT:
		GameState.set_flag("field_debt_open", true)
		GameState.set_flag("tutorial_road_open", true)
		SaveGame.request_autosave("field-debt-accepted")


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
	elif is_done(quest) and quest == FIELD_DEBT:
		GameState.remove_items("materials/loamroot_sprig", 1)
	if is_done(quest):
		SaveGame.request_autosave("quest-completed")


func resolve_field_debt(reward_id: StringName) -> bool:
	## Completes the tutorial commission exactly once, then records the selected
	## faction consequences. Dialogue calls this single method so a double-click
	## cannot grant two rewards.
	# The dialogue guard is fact-based, so it remains correct after loading a
	# save or returning from a scene transition.
	if not is_active(FIELD_DEBT) or not flags_met(FIELD_DEBT):
		return false
	var active_quest: Quest = null
	for quest in QuestSystem.get_active_quests():
		if quest.id == FIELD_DEBT.id:
			active_quest = quest
			break
	if active_quest == null:
		return false
	active_quest.objective_completed = true
	var reward: Variant = FIELD_DEBT_REWARDS.get(String(reward_id), {})
	if not reward is Dictionary:
		return false
	turn_in(active_quest, String(reward_id), false)
	if not is_done(FIELD_DEBT):
		return false
	for row: Variant in reward.get("reputation", []):
		if row is Dictionary:
			var faction := str(row.get("faction", ""))
			if not faction.is_empty():
				Reputation.record(
					"player", faction, float(row.get("delta", 0.0)),
					"Chose the %s reward for the field debt" % reward.get("title", "field debt"), "field"
				)
	GameState.set_flag("field_debt_reward", String(reward_id))
	Renown.gain_reputation("player", 6.0, "Returned proof from the first field commission", "field")
	SaveGame.request_autosave("field-debt-rewarded")
	return true


func _on_inventory_changed() -> void:
	for quest in QuestSystem.get_active_quests():
		if quest is FetchQuest:
			# The active pool is already authoritative here; update the resource
			# directly so inventory changes remain live even while a scene is being
			# replaced during a travel transition.
			quest.update()


func _on_flag_changed(_flag: String, _value: Variant) -> void:
	for quest in QuestSystem.get_active_quests():
		if quest is FlagQuest:
			quest.update()


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
