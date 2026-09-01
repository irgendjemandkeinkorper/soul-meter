class_name BuildingDoor
extends StaticBody2D
## Reusable press-to-enter doorway. Destinations and gates come from exported
## values or a BuildingTransitionDefinition; scene changes always use GameFlow.

signal travel_requested(scene_path: String, spawn_id: StringName)

@export var transition_id: StringName = &""
@export_file("*.tscn") var destination_scene: String = ""
@export var destination_location_id: StringName = &""
@export var spawn_id: StringName = &"default"
@export var prompt_text: String = "E — ENTER"
@export var required_flag: String = ""
@export var reputation_faction: String = ""
@export var minimum_reputation_band: StringName = &""
@export var locked_message: String = "This door is locked."
@export_range(32.0, 240.0, 1.0) var interaction_radius: float = 100.0

var _player_in_range := false
var _gate_configuration_valid := true
var _location: LocationDefinition

@onready var _range: Area2D = $InteractionRange
@onready var _range_shape: CollisionShape2D = $InteractionRange/CollisionShape2D
@onready var _prompt: Label = $Prompt


func _ready() -> void:
	_apply_registry_transition()
	_validate_gate_configuration()
	_location = LocationRegistry.resolve(destination_scene, destination_location_id)
	if _location == null:
		push_error(
			"BuildingDoor '%s' has no registered gameplay destination: %s"
			% [name, destination_scene]
		)
	var circle := _range_shape.shape as CircleShape2D
	if circle != null:
		circle.radius = interaction_radius
	_range.body_entered.connect(_on_body.bind(true))
	_range.body_exited.connect(_on_body.bind(false))
	if not required_flag.is_empty():
		GameState.flag_changed.connect(_on_flag_changed)
	if not reputation_faction.is_empty():
		Reputation.reputation_changed.connect(_on_reputation_changed)
	_refresh_lock()


func _apply_registry_transition() -> void:
	if transition_id.is_empty():
		return
	var transition := BuildingTransitionRegistry.by_id(transition_id)
	if transition == null:
		push_error("BuildingDoor '%s' has unknown transition id: %s" % [name, transition_id])
		destination_scene = ""
		return
	destination_scene = transition.destination_scene
	destination_location_id = transition.destination_location_id
	spawn_id = transition.spawn_id
	prompt_text = transition.prompt_text
	required_flag = transition.required_flag
	reputation_faction = transition.reputation_faction
	minimum_reputation_band = transition.minimum_reputation_band
	locked_message = transition.locked_message


func _validate_gate_configuration() -> void:
	var has_faction := not reputation_faction.is_empty()
	var has_band := not minimum_reputation_band.is_empty()
	if has_faction != has_band:
		_gate_configuration_valid = false
		push_error(
			"BuildingDoor '%s' requires both a reputation faction and minimum band." % name
		)
	elif has_band and not Reputation.BAND_RANK.has(minimum_reputation_band):
		_gate_configuration_valid = false
		push_error(
			"BuildingDoor '%s' has unknown reputation band: %s"
			% [name, minimum_reputation_band]
		)


func _on_body(body: Node2D, entered: bool) -> void:
	if body is Player:
		_player_in_range = entered
		_prompt.visible = entered
		_refresh_lock()


func _unhandled_input(event: InputEvent) -> void:
	if not _player_in_range or not event.is_action_pressed("interact") or get_tree().paused:
		return
	get_viewport().set_input_as_handled()
	_try_travel()


func _try_travel() -> bool:
	if not _can_attempt_travel():
		_refresh_lock()
		return false
	var resolved_spawn := _location.resolve_spawn(spawn_id)
	var accepted := false
	if reputation_faction.is_empty():
		accepted = GameFlow.travel(_location.scene_path, resolved_spawn)
	else:
		accepted = GameFlow.request_area_access(
			transition_id, _location.scene_path, resolved_spawn
		)
	if not accepted:
		_refresh_lock()
		return false
	travel_requested.emit(_location.scene_path, resolved_spawn)
	return true


func _can_attempt_travel() -> bool:
	if not _gate_configuration_valid or _location == null:
		return false
	return required_flag.is_empty() or GameState.flag_is_true(required_flag)


func _is_unlocked() -> bool:
	# Presentation preview only. The actual reputation-gated travel decision is
	# made by GameFlow's statechart in request_area_access().
	if not _can_attempt_travel():
		return false
	if not reputation_faction.is_empty():
		if not Reputation.band_at_least(reputation_faction, minimum_reputation_band):
			return false
	return true


func _on_flag_changed(flag: String, _value: Variant) -> void:
	if flag == required_flag:
		_refresh_lock()


func _on_reputation_changed(
	faction: String, _standing: float, _event: ReputationEvent
) -> void:
	if faction == reputation_faction:
		_refresh_lock()


func _refresh_lock() -> void:
	var unlocked := _is_unlocked()
	_prompt.text = prompt_text if unlocked else "LOCKED — " + locked_message
	_prompt.visible = _player_in_range
	modulate = Color.WHITE if unlocked else Color(0.65, 0.65, 0.65, 1.0)
