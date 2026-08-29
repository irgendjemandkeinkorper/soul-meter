extends Node2D
## Coordinates the Lower Trial Hall tutorial beats while leaving interaction,
## dialogue, battle, and travel behavior in their existing shared actors.

signal trial_encounter_started(encounter_id: StringName)

const OPENING_COMPLETE_FLAG := "opening_gauntlet_complete"
const INTERACTION_GATE_FLAG := "trial_interaction_gate_open"
const WARDEN_STARTED_FLAG := "trial_warden_started"
const WARDEN_CLEARED_FLAG := "trial_warden_cleared"
const SKILL_DOOR_FLAG := "trial_skill_door_open"
const KEEPER_FIGHT_REQUESTED_FLAG := "trial_keeper_fight_requested"
const KEEPER_STARTED_FLAG := "trial_keeper_started"
const WARDEN_ENCOUNTER_ID := &"trial-warden"
const KEEPER_ENCOUNTER_ID := &"trial-keeper"

var _active_trial_encounter: StringName = &""

@onready var _interaction_gate_shape: CollisionShape2D = $InteractionGate/CollisionShape2D
@onready var _interaction_gate_visual: Polygon2D = $InteractionGate/Visual
@onready var _warden_trigger: Area2D = $WardenTrigger
@onready var _skill_door_shape: CollisionShape2D = $SkillDoor/CollisionShape2D
@onready var _skill_door_visual: Polygon2D = $SkillDoor/Visual
@onready var _keeper_gate_shape: CollisionShape2D = $KeeperGate/CollisionShape2D
@onready var _keeper_gate_visual: Polygon2D = $KeeperGate/Visual


func _ready() -> void:
	GameState.flag_changed.connect(_on_flag_changed)
	Battle.battle_ended.connect(_on_battle_ended)
	_warden_trigger.body_entered.connect(_on_warden_trigger_body_entered)
	_refresh_progression()
	if GameState.flag_is_true(KEEPER_FIGHT_REQUESTED_FLAG):
		request_keeper_encounter()


func _exit_tree() -> void:
	if GameState.flag_changed.is_connected(_on_flag_changed):
		GameState.flag_changed.disconnect(_on_flag_changed)
	if Battle.battle_ended.is_connected(_on_battle_ended):
		Battle.battle_ended.disconnect(_on_battle_ended)


func request_warden_encounter() -> void:
	if (
		GameState.flag_is_true(OPENING_COMPLETE_FLAG)
		or GameState.flag_is_true(WARDEN_STARTED_FLAG)
	):
		return
	GameState.set_flag(WARDEN_STARTED_FLAG, true)
	_start_trial_encounter(WARDEN_ENCOUNTER_ID)


func request_keeper_encounter() -> void:
	if (
		GameState.flag_is_true(OPENING_COMPLETE_FLAG)
		or GameState.flag_is_true(KEEPER_STARTED_FLAG)
	):
		return
	GameState.set_flag(KEEPER_STARTED_FLAG, true)
	_start_trial_encounter(KEEPER_ENCOUNTER_ID)


func _start_trial_encounter(encounter_id: StringName) -> void:
	_active_trial_encounter = encounter_id
	Battle.start(encounter_id)
	if Battle.ended:
		_active_trial_encounter = &""
		return
	trial_encounter_started.emit(encounter_id)
	GameFlow.send_event("enter_battle")


func _on_warden_trigger_body_entered(body: Node2D) -> void:
	if body is Player:
		request_warden_encounter()


func _on_battle_ended(result: BattleResult) -> void:
	if result.encounter_id != _active_trial_encounter:
		return
	var resolved_encounter: StringName = _active_trial_encounter
	_active_trial_encounter = &""
	if not result.succeeded():
		if resolved_encounter == WARDEN_ENCOUNTER_ID:
			GameState.set_flag(WARDEN_STARTED_FLAG, false)
		elif resolved_encounter == KEEPER_ENCOUNTER_ID:
			GameState.set_flag(KEEPER_STARTED_FLAG, false)
			GameState.set_flag(KEEPER_FIGHT_REQUESTED_FLAG, false)
		return
	if resolved_encounter == WARDEN_ENCOUNTER_ID:
		GameState.set_flag(WARDEN_CLEARED_FLAG, true)
	elif resolved_encounter == KEEPER_ENCOUNTER_ID:
		GameState.set_flag(OPENING_COMPLETE_FLAG, true)


func _on_flag_changed(flag: String, value: Variant) -> void:
	if flag == KEEPER_FIGHT_REQUESTED_FLAG and bool(value):
		request_keeper_encounter()
	if flag in [
		OPENING_COMPLETE_FLAG,
		INTERACTION_GATE_FLAG,
		WARDEN_STARTED_FLAG,
		SKILL_DOOR_FLAG,
	]:
		_refresh_progression()


func _refresh_progression() -> void:
	var completed: bool = GameState.flag_is_true(OPENING_COMPLETE_FLAG)
	_set_gate_open(
		_interaction_gate_shape,
		_interaction_gate_visual,
		completed or GameState.flag_is_true(INTERACTION_GATE_FLAG),
	)
	_set_gate_open(
		_skill_door_shape,
		_skill_door_visual,
		completed or GameState.flag_is_true(SKILL_DOOR_FLAG),
	)
	_set_gate_open(_keeper_gate_shape, _keeper_gate_visual, completed)
	_warden_trigger.set_deferred(
		"monitoring",
		not completed and not GameState.flag_is_true(WARDEN_STARTED_FLAG),
	)
	if GameState.flag_is_true(SKILL_DOOR_FLAG) and has_node("TrialDoorKey"):
		get_node("TrialDoorKey").queue_free()


func _set_gate_open(shape: CollisionShape2D, visual: Polygon2D, is_open: bool) -> void:
	shape.set_deferred("disabled", is_open)
	visual.modulate = Color(1.0, 1.0, 1.0, 0.18 if is_open else 1.0)
