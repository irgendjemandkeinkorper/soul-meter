class_name BattleInterface
extends Control

## Six-region battle overlay contract:
## - consume_event(CombatEvent) fans immutable presentation snapshots to A-E.
## - bind_scheduler(TurnScheduler) gives region E the scheduler's own peek_order arithmetic.
## - forecast_context is passed to region D, whose only calculator is Resolution.resolve().
## - region B receives tile/weather state only through CombatEvent payloads.
@onready var active_unit_plate: UnitPlateRegion = %ActiveUnitPlate
@onready var stage: BattleStageRegion = %Stage
@onready var weather_chip: WeatherChipRegion = %WeatherChip
@onready var act_target_panel: ForecastPanelRegion = %ActTargetPanel
@onready var turn_timeline: CTTimelineRegion = %TurnTimeline
@onready var cursor_readout: Label = %CursorReadout
var _controller: CombatController
var _selected_action_id: StringName = &"strike"


func _ready() -> void:
	stage.tile_selected.connect(_on_tile_selected)
	stage.tile_hovered.connect(_on_tile_selected)
	stage.tile_hovered.connect(_on_tile_hovered)
	stage.pointer_pressed.connect(_on_pointer_pressed)
	stage.pointer_cleared.connect(_on_pointer_cleared)


func consume_event(event: CombatEvent) -> void:
	active_unit_plate.consume_event(event)
	var snapshot_value: Variant = event.data.get("snapshot", {})
	if snapshot_value is Dictionary and (snapshot_value as Dictionary).has("state"):
		stage.set_pointer_turn_available(
			int((snapshot_value as Dictionary).get("state")) == CombatController.State.ALLY_TURN
		)
	stage.consume_event(event)
	weather_chip.consume_event(event)
	act_target_panel.consume_event(event)
	turn_timeline.consume_event(event)


func bind_scheduler(scheduler: TurnScheduler) -> void:
	turn_timeline.bind_scheduler(scheduler)


func bind_controller(controller: CombatController) -> void:
	_controller = controller
	if controller != null and controller.scheduler != null:
		bind_scheduler(controller.scheduler)
	stage._set_movement(controller.snapshot().get("movement", {}) if controller != null else {})
	stage.set_pointer_turn_available(
		controller != null and controller.state == CombatController.State.ALLY_TURN
	)


func select_pointer_action(action_id: StringName) -> void:
	_selected_action_id = action_id


func set_forecast_context(context: Dictionary) -> void:
	act_target_panel.set_forecast_context(context)


func _on_tile_selected(tile: Dictionary) -> void:
	cursor_readout.text = "(%d,%d) · HEIGHT %d · %s %d · %s" % [int(tile.get("x", 0)), int(tile.get("y", 0)), int(tile.get("height_delta", tile.get("height", 0))), str(tile.get("charge_element_id", "UNCHARGED")).to_upper(), int(tile.get("charge_level", 0)), str(tile.get("note", ""))]


func _on_tile_hovered(tile: Dictionary) -> void:
	if (
		_controller == null
		or _controller.state != CombatController.State.ALLY_TURN
		or not stage.pointer_input_available()
	):
		return
	var cell := Vector2i(int(tile.get("x", 0)), int(tile.get("y", 0)))
	var target := _enemy_by_id(stage._actor_at(cell))
	if target != null:
		var action := _controller.action_by_id(_selected_action_id)
		var payload := _controller.forecast_action(action, target)
		act_target_panel.show_action_forecast(
			payload, _controller.forecast_context(_controller.active_actor(), target, action)
		)
	# Hovered move quote is display-only (AP compatibility: gate T-10 — the AP
	# number comes verbatim from the controller's move_query pricing).
	elif stage.hovered_ap_cost() >= 0:
		cursor_readout.text += " · MOVE %d AP" % stage.hovered_ap_cost()


func _on_pointer_pressed(tile: Dictionary, actor_id: StringName) -> void:
	if (
		_controller == null
		or _controller.state != CombatController.State.ALLY_TURN
		or not stage.pointer_input_available()
	):
		return
	var target := _enemy_by_id(actor_id)
	if target != null:
		var action := _controller.action_by_id(_selected_action_id)
		var payload := _controller.forecast_action(action, target)
		if bool(payload.get("allowed", false)):
			_controller.submit_action(_selected_action_id, target)
		else:
			act_target_panel.pulse_refusal(str(payload.get("message", "Action blocked.")))
		return
	var cell := Vector2i(int(tile.get("x", 0)), int(tile.get("y", 0)))
	var destination := stage.destination_for_cell(cell)
	if destination != &"":
		_controller.submit_action(&"move", null, {"destination": destination})


func _enemy_by_id(actor_id: StringName) -> BattleActor:
	if actor_id == &"" or _controller == null:
		return null
	for enemy: BattleActor in _controller.enemies:
		if enemy.combat_id == actor_id and enemy.is_alive():
			return enemy
	return null


func _on_pointer_cleared() -> void:
	cursor_readout.text = "CURSOR —"
