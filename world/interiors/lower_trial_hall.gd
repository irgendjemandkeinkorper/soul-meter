extends Node2D
## Coordinates the Lower Trial Hall tutorial beats while leaving interaction,
## dialogue, battle, and travel behavior in their existing shared actors.
##
## The hall is ten rooms on one plan (owner rulings 2026-11-04): the entry and its lever, the
## warden's court, the key alcove, a west room and a store with side-room fights, the store's
## locked door (SLIP it quietly or force it and wake the store), a gallery with an annex, a
## blast door only a blasting charge opens, the keeper's hall and the stair out. A completed
## gauntlet (by fight, the aide's skip or the keeper's talk) opens every gate.

signal trial_encounter_started(encounter_id: StringName)

const OPENING_COMPLETE_FLAG := "tutorial_gauntlet_complete"
const INTERACTION_GATE_FLAG := "tutorial_interaction_gate_open"
const WARDEN_STARTED_FLAG := "tutorial_warden_started"
const WARDEN_CLEARED_FLAG := "tutorial_warden_cleared"
const SKILL_DOOR_FLAG := "tutorial_skill_door_open"
const KEEPER_FIGHT_REQUESTED_FLAG := "tutorial_keeper_fight_requested"
const KEEPER_STARTED_FLAG := "tutorial_keeper_started"
const STORE_DOOR_FLAG := "trial_store_door_open"
const STORE_ALARM_FLAG := "trial_store_alarm"
const BLAST_CHARGE_FLAG := "trial_blast_charge_set"
const BLAST_DOOR_FLAG := "trial_blast_door_open"
## PROVISIONAL OWNER-BALANCE SURFACE: the slow cord's burn once the charge is set.
const BLAST_FUSE_SECONDS := 3.0
## A side room's pair of wardens -> the flag that keeps them gone once both are down. Their
## encounter has no `defeated_flag` (it is the court's set-piece too), so the hall keeps it.
const ROOM_CLEARED_FLAGS := {
	"WestWardens": "trial_west_cleared",
	"StoreWardens": "trial_store_cleared",
	"AnnexWardens": "trial_annex_cleared",
}
const WARDEN_ENCOUNTER_ID := &"trial-warden"
const KEEPER_ENCOUNTER_ID := &"trial-keeper"

var _active_trial_encounter: StringName = &""
## Gate shape -> the blocking cells it fills while shut, as BlockingLayer footprint rows. The
## gates are painted shut (tools/paint_blocking.gd); an open gate lifts its cells, so the walk
## grid and the fights in this hall pass a gate only while it is open. Cells a wall also covers
## stay painted.
var _gate_tiles: Dictionary = {}
var _blocking: BlockingLayer

@onready var _interaction_gate_shape: CollisionShape2D = $InteractionGate/CollisionShape2D
@onready var _interaction_gate_visual: Polygon2D = $InteractionGate/Visual
@onready var _warden_trigger: Area2D = $WardenTrigger
@onready var _skill_door_shape: CollisionShape2D = $SkillDoor/CollisionShape2D
@onready var _skill_door_visual: Polygon2D = $SkillDoor/Visual
@onready var _keeper_gate_shape: CollisionShape2D = $KeeperGate/CollisionShape2D
@onready var _keeper_gate_visual: Polygon2D = $KeeperGate/Visual
@onready var _store_door_shape: CollisionShape2D = $StoreDoor/CollisionShape2D
@onready var _store_door_visual: Polygon2D = $StoreDoor/Visual
@onready var _blast_door_shape: CollisionShape2D = $BlastDoor/CollisionShape2D
@onready var _blast_door_visual: Polygon2D = $BlastDoor/Visual
@onready var _entrance_instruction: Label = $EntranceInstruction


func _ready() -> void:
	GameState.flag_changed.connect(_on_flag_changed)
	Battle.battle_ended.connect(_on_battle_ended)
	_warden_trigger.body_entered.connect(_on_warden_trigger_body_entered)
	_capture_gate_tiles()
	_bind_side_rooms()
	# A fuse does not survive a save: a charge set before the load has already gone off.
	if GameState.flag_is_true(BLAST_CHARGE_FLAG):
		GameState.set_flag(BLAST_DOOR_FLAG, true)
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


## The trial fights are set-pieces fought in the hall itself (#281 D5): Battle spawns the
## warden or keeper as a Hostile where the party stands, and the deployment slate still opens
## for them (F0 D3: deployment survives for scripted set-pieces).
func _start_trial_encounter(encounter_id: StringName) -> void:
	_active_trial_encounter = encounter_id
	# The fight is on this floor now; the hall's world-space prompt would sit on the fighters.
	_entrance_instruction.hide()
	var field := find_child("FieldMap", true, false) as FieldMap
	var opened: Dictionary = Battle.start_set_piece(field, encounter_id)
	if not bool(opened.get("allowed", false)):
		push_warning(
			"Trial encounter '%s' refused: %s" % [encounter_id, opened.get("message", "")]
		)
	if not bool(opened.get("allowed", false)) or Battle.ended:
		# A fight that never opened must not count as started, or the beat is lost for good.
		_active_trial_encounter = &""
		_entrance_instruction.show()
		if encounter_id == WARDEN_ENCOUNTER_ID:
			GameState.set_flag(WARDEN_STARTED_FLAG, false)
		elif encounter_id == KEEPER_ENCOUNTER_ID:
			GameState.set_flag(KEEPER_STARTED_FLAG, false)
		return
	trial_encounter_started.emit(encounter_id)
	# Owner 2026-11-02 (item 33): fights on a map start in place, with no deployment screens.
	GameFlow.send_event("enter_battle")


func _on_warden_trigger_body_entered(body: Node2D) -> void:
	if body is Player:
		request_warden_encounter()


func _on_battle_ended(result: BattleResult) -> void:
	# A side room's fight is an ambient session with no encounter id: not a trial beat.
	if _active_trial_encounter == &"" or result.encounter_id != _active_trial_encounter:
		return
	var resolved_encounter: StringName = _active_trial_encounter
	_active_trial_encounter = &""
	_entrance_instruction.show()
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
	if flag == BLAST_CHARGE_FLAG and bool(value) and not GameState.flag_is_true(BLAST_DOOR_FLAG):
		_light_fuse()
	if flag in [
		OPENING_COMPLETE_FLAG,
		INTERACTION_GATE_FLAG,
		WARDEN_STARTED_FLAG,
		SKILL_DOOR_FLAG,
		STORE_DOOR_FLAG,
		BLAST_DOOR_FLAG,
	]:
		_refresh_progression()


## The cord burns BLAST_FUSE_SECONDS, then the door goes. The seam glows while it burns.
func _light_fuse() -> void:
	var glow := create_tween()
	glow.tween_property(_blast_door_visual, "modulate", Color(1.6, 0.9, 0.5, 1.0), BLAST_FUSE_SECONDS)
	get_tree().create_timer(BLAST_FUSE_SECONDS).timeout.connect(
		func() -> void: GameState.set_flag(BLAST_DOOR_FLAG, true)
	)


## Retires a side room whose pair is already down, and otherwise watches the pair so the room
## stays cleared once both fall.
func _bind_side_rooms() -> void:
	for group_name: String in ROOM_CLEARED_FLAGS:
		var group := get_node_or_null(group_name)
		if group == null:
			continue
		if GameState.flag_is_true(ROOM_CLEARED_FLAGS[group_name]):
			group.queue_free()
			continue
		for hostile: Node in group.get_children():
			if hostile is Hostile:
				(hostile as Hostile).downed.connect(_on_side_warden_downed.bind(group_name))


func _on_side_warden_downed(_hostile: Hostile, group_name: String) -> void:
	var group := get_node_or_null(group_name)
	if group == null:
		return
	for hostile: Node in group.get_children():
		if hostile is Hostile and (hostile as Hostile).state != Hostile.State.DOWNED:
			return
	GameState.set_flag(ROOM_CLEARED_FLAGS[group_name], true)


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
	var store_open := completed or GameState.flag_is_true(STORE_DOOR_FLAG)
	_set_gate_open(_store_door_shape, _store_door_visual, store_open)
	var blast_open := completed or GameState.flag_is_true(BLAST_DOOR_FLAG)
	_set_gate_open(_blast_door_shape, _blast_door_visual, blast_open)
	if store_open and has_node("StoreDoorLatch"):
		get_node("StoreDoorLatch").queue_free()
	if blast_open and has_node("BlastSeam"):
		get_node("BlastSeam").queue_free()
	_warden_trigger.set_deferred(
		"monitoring",
		not completed and not GameState.flag_is_true(WARDEN_STARTED_FLAG),
	)
	if GameState.flag_is_true(SKILL_DOOR_FLAG) and has_node("TrialDoorKey"):
		get_node("TrialDoorKey").queue_free()


func _set_gate_open(shape: CollisionShape2D, visual: Polygon2D, is_open: bool) -> void:
	shape.set_deferred("disabled", is_open)
	if _blocking != null and _gate_tiles.has(shape):
		_blocking.set_structure_footprint(_gate_tiles[shape], not is_open)
	visual.modulate = Color(1.0, 1.0, 1.0, 0.18 if is_open else 1.0)


func _capture_gate_tiles() -> void:
	var field := find_child("FieldMap", true, false) as FieldMap
	if field == null:
		return
	_blocking = field.blocking() as BlockingLayer
	var ground := field.ground()
	if _blocking == null or ground == null:
		return
	var shapes: Array[CollisionShape2D] = [
		_interaction_gate_shape, _skill_door_shape, _keeper_gate_shape, _store_door_shape,
		_blast_door_shape,
	]
	var gates: Array = shapes.map(func(shape: CollisionShape2D) -> Node: return shape.get_parent())
	var walls := SolidFootprints.ground_cells(self, ground, gates)
	for shape: CollisionShape2D in shapes:
		var tiles := {}
		for cell: Vector2i in SolidFootprints.shape_cells(shape, self, ground):
			if walls.has(cell) or _blocking.get_cell_source_id(cell) == -1:
				continue
			tiles[cell] = [
				_blocking.get_cell_source_id(cell), _blocking.get_cell_atlas_coords(cell),
				_blocking.get_cell_alternative_tile(cell),
			]
		_gate_tiles[shape] = tiles
