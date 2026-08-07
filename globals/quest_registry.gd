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
const DISHONEST_CASKS: DomSideQuest = preload("res://quests/dom_dishonest_casks.tres")
const LIVING_TAG: DomSideQuest = preload("res://quests/dom_living_tag.tres")
const UNCLAIMED_BED: DomSideQuest = preload("res://quests/dom_unclaimed_bed.tres")
const COLD_BOWL: DomSideQuest = preload("res://quests/dom_cold_bowl.tres")
const RAINBOUND_REGISTER: DomSideQuest = preload("res://quests/dom_rainbound_register.tres")
const LAST_SAFE_COURSE: DomSideQuest = preload("res://quests/dom_last_safe_course.tres")
const FIFTH_ECHO: DomSideQuest = preload("res://quests/dom_fifth_echo.tres")
const MARCHING_KNOTS: DomSideQuest = preload("res://quests/dom_marching_knots.tres")
const ASH_IN_THE_RAIN: DomSideQuest = preload("res://quests/dom_ash_in_the_rain.tres")
const SMOOTHED_WEIGHTS: DomSideQuest = preload("res://quests/dom_smoothed_weights.tres")
const DOM_SIDE_QUEST_DIALOGUE_PATH := "res://dialogue/dom_side_quests.dialogue"
const MARSHAL_DIALOGUE_PATH := "res://dialogue/marshal_coiljaw.dialogue"
const DOM_SIDE_QUESTS: Array[DomSideQuest] = [
	DISHONEST_CASKS,
	LIVING_TAG,
	UNCLAIMED_BED,
	COLD_BOWL,
	RAINBOUND_REGISTER,
	LAST_SAFE_COURSE,
	FIFTH_ECHO,
	MARCHING_KNOTS,
	ASH_IN_THE_RAIN,
	SMOOTHED_WEIGHTS,
]
const ALL_QUESTS: Array[Quest] = [
	LOAMROOT_SPRIGS,
	DORTHKOR_ROAD,
	DEEP_TRIAL,
	BELLHOUSE_REPAIR,
	FIELD_DEBT,
	DISHONEST_CASKS,
	LIVING_TAG,
	UNCLAIMED_BED,
	COLD_BOWL,
	RAINBOUND_REGISTER,
	LAST_SAFE_COURSE,
	FIFTH_ECHO,
	MARCHING_KNOTS,
	ASH_IN_THE_RAIN,
	SMOOTHED_WEIGHTS,
]
const STORY_QUESTS: Array[Quest] = [DEEP_TRIAL, DORTHKOR_ROAD]

const BROKEN_MUSTER_RULINGS := {
	"demons-first": {
		"reputation": [
			{
				"faction": "iron-companies",
				"delta": 12.0,
				"cause": "Called Dom to meet the demon vanguard first",
			},
			{
				"faction": "ironbrand-sentinels",
				"delta": -2.0,
				"cause": "Put the dead muster behind the immediate breach",
			},
		],
		"renown": 10.0,
		"renown_cause": "Brought Dom proof of the broken muster",
	},
	"dead-first": {
		"reputation": [
			{
				"faction": "ironbrand-sentinels",
				"delta": 12.0,
				"cause": "Recognized the dead muster as Dom's deeper threat",
			},
			{
				"faction": "iron-companies",
				"delta": -2.0,
				"cause": "Diverted soldiers from the immediate demon road",
			},
		],
		"renown": 10.0,
		"renown_cause": "Brought Dom proof of the broken muster",
	},
	"hold-both": {
		"requires_centered_soul": true,
		"reputation": [
			{
				"faction": "iron-companies",
				"delta": 7.0,
				"cause": "Persuaded Dom to hold both advancing fronts",
			},
			{
				"faction": "ironbrand-sentinels",
				"delta": 7.0,
				"cause": "Persuaded Dom to hold both advancing fronts",
			},
		],
		"renown": 14.0,
		"renown_cause": "Made Dom bear the honest cost of two fronts",
	},
}

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
	elif quest is DomSideQuest:
		SaveGame.request_autosave("dom-side-quest-accepted")


func is_active(quest: Quest) -> bool:
	return QuestSystem.is_quest_active(quest)


func is_done(quest: Quest) -> bool:
	return QuestSystem.is_quest_completed(quest)


func turn_in(
	quest: Quest, resolution: String = "returned", grant_default_reward: bool = true
) -> void:
	# The chapter ruling is one atomic operation. Refuse a bare quest completion
	# so a caller cannot leave a save with The Broken Muster completed but no
	# ruling flag (and therefore no dialogue route that can finish the chapter).
	if (
		quest == DORTHKOR_ROAD
		and (
			not BROKEN_MUSTER_RULINGS.has(resolution)
			or str(GameState.get_flag("chapter_one_resolution", "")) != resolution
		)
	):
		return
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


func resolve_broken_muster(ruling_id: StringName) -> bool:
	## Completes the chapter quest, ruling flag, and consequence ledgers as one
	## synchronous operation. Dialogue calls this seam instead of ordering those
	## writes itself, preventing a completed-quest/no-ruling soft lock.
	var ruling_key := String(ruling_id)
	var ruling_value: Variant = BROKEN_MUSTER_RULINGS.get(ruling_key, {})
	if (
		not ruling_value is Dictionary
		or (ruling_value as Dictionary).is_empty()
		or not is_active(DORTHKOR_ROAD)
		or not flags_met(DORTHKOR_ROAD)
		or not bool(GameState.get_flag("reported_bloodbellow", false))
		or not str(GameState.get_flag("chapter_one_resolution", "")).is_empty()
	):
		return false
	var ruling := ruling_value as Dictionary
	if (
		bool(ruling.get("requires_centered_soul", false))
		and (GameState.soul_meter < 40.0 or GameState.soul_meter > 60.0)
	):
		return false

	var active_quest: Quest = null
	for quest: Quest in QuestSystem.get_active_quests():
		if quest.id == DORTHKOR_ROAD.id:
			active_quest = quest
			break
	if active_quest == null:
		return false

	# Set the ruling first so turn_in() can enforce the invariant. Both calls are
	# synchronous; the checkpoint remains deferred until the full outcome lands.
	GameState.set_flag("chapter_one_resolution", ruling_key)
	active_quest.objective_completed = true
	turn_in(active_quest, ruling_key, false)
	if not is_done(DORTHKOR_ROAD):
		GameState.set_flag("chapter_one_resolution", "")
		return false

	for row_value: Variant in ruling.get("reputation", []):
		if not row_value is Dictionary:
			continue
		var row := row_value as Dictionary
		Reputation.record(
			"player",
			str(row.get("faction", "")),
			float(row.get("delta", 0.0)),
			str(row.get("cause", "")),
			"dom"
		)
	Renown.gain_reputation(
		"player",
		float(ruling.get("renown", 0.0)),
		str(ruling.get("renown_cause", "")),
		"dom"
	)
	SaveGame.request_checkpoint(SaveGame.Checkpoint.RULING, ruling_key)
	return true


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


func offer_side_quest(quest: DomSideQuest) -> bool:
	if not DOM_SIDE_QUESTS.has(quest) or is_active(quest) or is_done(quest):
		return false
	offer(quest)
	return is_active(quest)


func resolve_side_quest(quest: DomSideQuest, outcome_id: StringName) -> bool:
	## Apply one authored choice exactly once. Dialogue supplies the choice, but
	## this method owns completion, the durable resolution flag, and the only
	## faction-ledger write used by Dom side quests.
	if not DOM_SIDE_QUESTS.has(quest) or not is_active(quest) or not flags_met(quest):
		return false
	var outcome: Dictionary = quest.outcome_for(String(outcome_id))
	if outcome.is_empty():
		return false
	var active_quest: DomSideQuest = null
	for candidate: Quest in QuestSystem.get_active_quests():
		if candidate.id == quest.id and candidate is DomSideQuest:
			active_quest = candidate
			break
	if active_quest == null:
		return false
	active_quest.objective_completed = true
	turn_in(active_quest, str(outcome["id"]), false)
	if not is_done(quest):
		return false
	Reputation.record(
		"player",
		str(outcome["faction_id"]),
		float(outcome["reputation_delta"]),
		str(outcome["cause"]),
		"dom"
	)
	GameState.set_flag(quest.resolution_flag, str(outcome["id"]))
	SaveGame.request_autosave("dom-side-quest-resolved")
	return true


func side_quest_for_giver(actor_id: String) -> DomSideQuest:
	for quest in DOM_SIDE_QUESTS:
		if quest.giver_actor_id == actor_id:
			return quest
	return null


func dialogue_route_for_actor(
	actor_id: String, fallback_path: String, fallback_title: String
) -> Dictionary:
	if actor_id == "branek-coiljaw":
		return {"path": MARSHAL_DIALOGUE_PATH, "title": "start"}
	## Generated roster prose remains the fallback for every townsfolk. The ten
	## authored givers route through their quest resources at interaction time so
	## generated data stays untouched and the quests cannot be orphaned by a stale
	## roster dialogue title.
	var side_quest := side_quest_for_giver(actor_id)
	if side_quest != null:
		return {
			"path": DOM_SIDE_QUEST_DIALOGUE_PATH,
			"title": side_quest.dialogue_title,
		}
	return {"path": fallback_path, "title": fallback_title}


func side_quest_readback(quest: DomSideQuest) -> String:
	var outcome_id := str(GameState.get_flag(quest.resolution_flag, ""))
	var outcome := quest.outcome_for(outcome_id)
	return str(outcome.get("readback", ""))


func active_side_quests() -> Array[DomSideQuest]:
	var result: Array[DomSideQuest] = []
	for quest: DomSideQuest in DOM_SIDE_QUESTS:
		if is_active(quest):
			result.append(quest)
	return result


func completed_side_quests() -> Array[DomSideQuest]:
	var result: Array[DomSideQuest] = []
	for quest: DomSideQuest in DOM_SIDE_QUESTS:
		if is_done(quest):
			result.append(quest)
	return result


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
		if quest is FlagQuest:
			quest.current_stage = 0


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
