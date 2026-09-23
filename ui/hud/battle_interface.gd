class_name BattleInterface
extends Control

const InjuryNoticeScript := preload("res://ui/hud/injury_notice.gd")

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
@onready var injury_notice: InjuryNoticeScript = %InjuryNotice
@onready var injury_inspector: InjuryNoticeScript = %InjuryInspector
var _controller: CombatController
var _selected_action_id: StringName = &"strike"
var _selected_ability_id := ""
## Cell working in progress: cells picked so far, and the creature a contract card bound.
var _pending_cells: Array[Vector2i] = []
var _pending_target: BattleActor = null
## Anatomical aim armed for the selected action; empty means ordinary aim. It is a mode,
## not a per-target choice: the next enemy press submits with it, and the controller
## refuses (without cost) when that target cannot take the location.
var _aim_location: StringName = &""
var _aim_target: BattleActor = null
var _inspected_unit_id := ""
var _inspected_location := ""
var _inspected_unit: Dictionary = {}


func _ready() -> void:
	stage.tile_selected.connect(_on_tile_selected)
	stage.tile_hovered.connect(_on_tile_selected)
	stage.tile_hovered.connect(_on_tile_hovered)
	stage.pointer_pressed.connect(_on_pointer_pressed)
	stage.pointer_cleared.connect(_on_pointer_cleared)
	act_target_panel.aim_selected.connect(select_aim)
	active_unit_plate.injury_selected.connect(_inspect_injury)
	active_unit_plate.resized.connect(_position_injury_inspector)


func consume_event(event: CombatEvent) -> void:
	injury_notice.consume_event(event)
	active_unit_plate.consume_event(event)
	_refresh_injury_inspector()
	var snapshot_value: Variant = event.data.get("snapshot", {})
	if snapshot_value is Dictionary and (snapshot_value as Dictionary).has("state"):
		stage.set_pointer_turn_available(
			int((snapshot_value as Dictionary).get("state")) == CombatController.State.ALLY_TURN
		)
	stage.consume_event(event)
	weather_chip.consume_event(event)
	act_target_panel.consume_event(event)
	turn_timeline.consume_event(event)
	if event.type in [&"action_resolved", &"turn_started", &"battle_finished"]:
		_clear_target_preview()
	if _controller != null and _aim_target != null:
		if _controller.state != CombatController.State.ALLY_TURN or not _aim_target.is_alive():
			act_target_panel.clear_aim_options()
			_clear_target_preview()
		elif event.data.has("forecast_context") or (
			snapshot_value is Dictionary and (snapshot_value as Dictionary).has("forecast_context")
		):
			_show_target_forecast(_controller.action_by_id(_selected_action_id), _aim_target)


func bind_scheduler(scheduler: TurnScheduler) -> void:
	turn_timeline.bind_scheduler(scheduler)


func bind_controller(controller: CombatController) -> void:
	_controller = controller
	_clear_target_preview()
	# Binding follows event replay in the production screen; old injuries are not new hits.
	injury_notice.clear_notices()
	injury_inspector.hide()
	if controller != null and controller.scheduler != null:
		bind_scheduler(controller.scheduler)
	stage._set_movement(controller.snapshot().get("movement", {}) if controller != null else {})
	stage.set_pointer_turn_available(
		controller != null and controller.state == CombatController.State.ALLY_TURN
	)


func _inspect_injury(location: String) -> void:
	var unit := active_unit_plate.unit_snapshot()
	_inspected_unit_id = str(unit.get("id", ""))
	_inspected_location = location
	_inspected_unit = unit.duplicate(true)
	injury_inspector.inspect_injury(unit, location)
	_position_injury_inspector()


func _refresh_injury_inspector() -> void:
	if not injury_inspector.visible:
		return
	var unit := active_unit_plate.unit_snapshot()
	if str(unit.get("id", "")) != _inspected_unit_id or not (unit.get("injuries", {}) as Dictionary).has(_inspected_location):
		injury_inspector.hide()
		return
	# Re-render only when the inspected record or its labels change, not each HP/CT update.
	for key: String in ["injuries", "anatomy", "name", "display_name"]:
		if unit.get(key) != _inspected_unit.get(key):
			_inspected_unit = unit.duplicate(true)
			injury_inspector.inspect_injury(unit, _inspected_location)
			break


func _position_injury_inspector() -> void:
	injury_inspector.position = get_global_transform().affine_inverse() * (
		active_unit_plate.global_position + Vector2(DS.SPACE_8, active_unit_plate.size.y + DS.SPACE_6)
	)


func select_pointer_action(action_id: StringName, ability_id: String = "") -> void:
	_selected_action_id = action_id
	_selected_ability_id = ability_id
	_aim_location = &""
	_clear_target_preview()
	act_target_panel.clear_aim_options()
	_clear_pending()


## Arms (or with an empty location, cancels) an anatomical aim for the selected action.
func select_aim(location: StringName) -> void:
	var action := _controller.action_by_id(_selected_action_id) if _controller != null else null
	if action == null or (not location.is_empty() and not action.aim_profiles.has(location)):
		return
	_aim_location = location
	act_target_panel.mark_aim_selected(location)
	# Selecting an aim quotes the inspected target immediately, without another map hover.
	if _aim_target != null and _controller.state == CombatController.State.ALLY_TURN:
		_show_target_forecast(action, _aim_target)


func aim_location() -> StringName:
	return _aim_location


## Options the controller needs for the armed action: the cast ability and any armed aim.
func _action_options(action: CombatAction) -> Dictionary:
	var options: Dictionary = {}
	if action != null and action.kind == CombatAction.Kind.CAST:
		options["ability_id"] = _selected_ability_id
	if not _aim_location.is_empty():
		options["aim_location"] = String(_aim_location)
	return options


## Quotes every authored location on `action` against `target` through the real forecast
## gate, so the aim row disables exactly what the controller would refuse.
func _refresh_aim_options(action: CombatAction, target: BattleActor) -> void:
	if action == null or action.aim_profiles.is_empty():
		act_target_panel.clear_aim_options()
		return
	var quotes: Dictionary = {}
	for key: Variant in action.aim_profiles.keys():
		var location := StringName(str(key))
		var options := _action_options(action)
		options["aim_location"] = String(location)
		quotes[location] = _controller.forecast_action(action, target, options)
	act_target_panel.show_aim_options(action, target, quotes, _aim_location)


func pending_cells() -> Array[Vector2i]:
	return _pending_cells.duplicate()


func _clear_pending() -> void:
	_pending_cells.clear()
	_pending_target = null
	stage.set_pending_cells([])


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
	var action := _controller.action_by_id(_selected_action_id)
	if action != null and action.targets_cells():
		_hover_cell_working(action, cell)
		return
	var target := _target_for(action, stage._actor_at(cell))
	if target != null:
		_aim_target = target
		_refresh_aim_options(action, target)
		_show_target_forecast(action, target)
	# Hovered move quote is display-only (AP compatibility: gate T-10 — the AP
	# number comes verbatim from the controller's move_query pricing).
	else:
		_clear_target_preview()
		if stage.hovered_ap_cost() >= 0:
			cursor_readout.text += " · MOVE %d AP" % stage.hovered_ap_cost()


func _show_target_forecast(action: CombatAction, target: BattleActor) -> void:
	var options := _action_options(action)
	var payload := _controller.forecast_action(action, target, options)
	act_target_panel.show_action_forecast(
		payload, _controller.forecast_context(_controller.active_actor(), target, action, options)
	)
	_append_cast_forecast(action, payload)
	act_target_panel.show_aim_forecast(payload, _aim_location, _controller.rules.use_charge_time)
	var part := tr("ORDINARY")
	if not _aim_location.is_empty():
		var anatomy: Dictionary = target.anatomy.get(String(_aim_location), {})
		part = str(anatomy.get("display_name", _aim_location)).to_upper()
	var chance := tr("UNAVAILABLE")
	if bool(payload.get("allowed", false)):
		var resolution: Dictionary = payload.get("resolution", {})
		var accuracy: Dictionary = resolution.get("accuracy_breakdown", {})
		chance = tr("HIT %d%%") % int(accuracy.get("effective_hit_chance", resolution.get("hit_chance", 100)))
	stage.show_target_preview(target.combat_id, target.display_name, "%s · %s" % [part, chance])


func _clear_target_preview() -> void:
	_aim_target = null
	stage.clear_target_preview()


func _on_pointer_pressed(tile: Dictionary, actor_id: StringName) -> void:
	if (
		_controller == null
		or _controller.state != CombatController.State.ALLY_TURN
		or not stage.pointer_input_available()
	):
		return
	var cell := Vector2i(int(tile.get("x", 0)), int(tile.get("y", 0)))
	var action := _controller.action_by_id(_selected_action_id)
	if action != null and action.targets_cells():
		_press_cell_working(action, cell, actor_id)
		return
	var target := _target_for(action, actor_id)
	if target != null:
		var options := _action_options(action)
		var payload := _controller.forecast_action(action, target, options)
		if bool(payload.get("allowed", false)):
			_controller.submit_action(_selected_action_id, target, options)
		else:
			act_target_panel.pulse_refusal(str(payload.get("message", "Action blocked.")))
		return
	var destination := stage.destination_for_cell(cell)
	if destination != &"":
		_controller.submit_action(&"move", null, {"destination": destination})


## The creature a pointer press means for the armed card: enemies for strikes, allies for
## ally-side cards (Veil), either side for "any" cards (Douse). Null when the press is a cell.
func _target_for(action: CombatAction, actor_id: StringName) -> BattleActor:
	if actor_id == &"" or _controller == null or action == null:
		return null
	var candidate := _controller.actor_by_id(actor_id)
	if candidate == null or not candidate.is_alive():
		return null
	if action.targets_any_side():
		return candidate
	if action.requires_ally_target():
		return candidate if _controller.allies.has(candidate) else null
	return candidate if _controller.enemies.has(candidate) else null


func _enemy_by_id(actor_id: StringName) -> BattleActor:
	if actor_id == &"" or _controller == null:
		return null
	for enemy: BattleActor in _controller.enemies:
		if enemy.combat_id == actor_id and enemy.is_alive():
			return enemy
	return null


# --- cell workings (Firebreak, Crown of Embers, Witness Light, the kit tiers) ------------


func _cell_count(action: CombatAction) -> int:
	return maxi(1, int(action.effect_payload.get("cell_count", 3)))


func _cell_options(cells: Array[Vector2i]) -> Dictionary:
	return {"cells": FireField.cells_to_data(cells)}


## A press either binds the contract creature (cards with `contract_target`) or picks one
## more cell. The working is quoted and submitted the moment the last cell lands.
func _press_cell_working(action: CombatAction, cell: Vector2i, actor_id: StringName) -> void:
	if bool(action.effect_payload.get("contract_target", false)) and _pending_target == null:
		var bound := _enemy_by_id(actor_id)
		if bound == null:
			act_target_panel.pulse_refusal("Touch the enemy to bind first, then pick the field.")
			return
		_pending_target = bound
		act_target_panel.forecast.text = "BOUND %s · pick %d cell%s" % [
			bound.display_name.to_upper(), _cell_count(action), "s" if _cell_count(action) > 1 else "",
		]
		return
	if _pending_cells.has(cell):
		_pending_cells.erase(cell)
		stage.set_pending_cells(_pending_cells)
		return
	_pending_cells.append(cell)
	stage.set_pending_cells(_pending_cells)
	if _pending_cells.size() < _cell_count(action):
		cursor_readout.text += " · CELL %d/%d" % [_pending_cells.size(), _cell_count(action)]
		return
	var options := _cell_options(_pending_cells)
	var payload := _controller.forecast_action(action, _pending_target, options)
	if bool(payload.get("allowed", false)):
		_controller.submit_action(_selected_action_id, _pending_target, options)
	else:
		act_target_panel.pulse_refusal(str(payload.get("message", "Action blocked.")))
	_clear_pending()


## Hovering the cell that would complete the shape quotes the working before it is committed.
func _hover_cell_working(action: CombatAction, cell: Vector2i) -> void:
	var preview := _pending_cells.duplicate()
	if not preview.has(cell):
		preview.append(cell)
	if preview.size() != _cell_count(action):
		cursor_readout.text += " · CELL %d/%d" % [_pending_cells.size(), _cell_count(action)]
		return
	var payload := _controller.forecast_action(action, _pending_target, _cell_options(preview))
	act_target_panel.show_action_forecast(payload, payload.get("context", {}))
	if bool(payload.get("allowed", false)):
		act_target_panel.forecast.text = "%s · %s" % [action.display_name.to_upper(), action.description]
		_append_cast_forecast(action, payload)


func _on_pointer_cleared() -> void:
	cursor_readout.text = "CURSOR —"
	_clear_target_preview()
	_clear_pending()


func _append_cast_forecast(action: CombatAction, payload: Dictionary) -> void:
	if action == null or (action.kind != CombatAction.Kind.CAST and not action.spell):
		return
	act_target_panel.forecast.text += "\nBREATH %d · SOUL %d" % [
		int(payload.get("breath_cost", 0)),
		int(payload.get("soul_cost", 0.0)),
	]
	if action.kind != CombatAction.Kind.CAST:
		# Loadout casts already carry the panel's own fizzle line; authored cards add theirs.
		act_target_panel.forecast.text += " · FIZZLE %d%%" % int(payload.get("fizzle_percent", 0.0))
