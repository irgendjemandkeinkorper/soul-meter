class_name BattleInterface
extends Control

const InjuryNoticeScript := preload("res://ui/hud/injury_notice.gd")
## The breakdown popover is one compact, scrolling panel; it never docks or grows past this.
const POPOVER_HEIGHT := 560.0

## Emitted when the controller refuses an aimed press; the bar's message window prints it.
signal refusal_pulsed(message: String)
## Emitted when the breakdown popover opens or closes (the bar's toggle mirrors it).
signal breakdown_visibility_changed(visible_now: bool)

## Combat presentation on the field (owner 2026-11-01, "one bar, both modes"):
## - consume_event(CombatEvent) fans immutable presentation snapshots to every region.
## - bind_scheduler(TurnScheduler) gives the turn strip the scheduler's own peek_order arithmetic.
## - forecast_context is passed to the forecast panel, whose only calculator is Resolution.resolve().
## - the stage receives tile/weather state only through CombatEvent payloads.
## The map stays full-screen underneath: the only chrome is the thin turn strip at the top,
## the combat bar (hosted by the field HUD's bottom bar) and, on demand, the breakdown popover.
@onready var stage: BattleStageRegion = %Stage
@onready var turn_strip: PanelContainer = %TurnStrip
@onready var turn_timeline: CTTimelineRegion = %TurnTimeline
@onready var weather_chip: WeatherChipRegion = %WeatherChip
@onready var tactical_popover: PanelContainer = %TacticalPopover
@onready var act_target_panel: ForecastPanelRegion = %ActTargetPanel
@onready var tactical_data: TacticalDataRegion = %TacticalData
@onready var combat_bar: CombatBar = %CombatBar
@onready var active_unit_plate: UnitPlateRegion = %ActiveUnitPlate
@onready var injury_notice: InjuryNoticeScript = %InjuryNotice
@onready var injury_inspector: InjuryNoticeScript = %InjuryInspector
@onready var vignette: TextureRect = %Vignette
## The cell/target readout line at the head of the bar's message window.
var cursor_readout: Label
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
var _inset_top := 0.0
var _inset_bottom := 0.0
var _vignette_tween: Tween


func _ready() -> void:
	cursor_readout = combat_bar.cursor_readout
	stage.tile_selected.connect(_on_tile_selected)
	stage.tile_hovered.connect(_on_tile_selected)
	stage.tile_hovered.connect(_on_tile_hovered)
	stage.pointer_pressed.connect(_on_pointer_pressed)
	stage.pointer_cleared.connect(_on_pointer_cleared)
	act_target_panel.aim_selected.connect(select_aim)
	act_target_panel.details_pinned = true
	act_target_panel.compact_aim = true
	active_unit_plate.injury_selected.connect(_inspect_injury)
	active_unit_plate.resized.connect(_position_injury_inspector)
	# #473: the plate and the strip read the field's presented beats, not the live stream.
	active_unit_plate.follow_presented_beats(stage.beat_presented)
	turn_timeline.follow_presented_beats(stage.beat_presented)
	stage.beat_presented.connect(func(_event: CombatEvent) -> void: _refresh_injury_inspector())
	combat_bar.bind(self)
	combat_bar.host_aim_row(act_target_panel.aim_row)
	vignette.texture = _vignette_texture()
	tactical_popover.visible = false


func consume_event(event: CombatEvent) -> void:
	injury_notice.consume_event(event)
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
	tactical_data.consume_event(event)
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


# --- breakdown popover (owner 2026-11-01: closed by default, one compact popover) ---------


## Opens or closes the breakdown popover (accuracy/power breakdown, attunement wheel and
## tactical data). Returns its new visibility.
func toggle_breakdown() -> bool:
	set_breakdown_visible(not tactical_popover.visible)
	return tactical_popover.visible


func set_breakdown_visible(visible_now: bool) -> void:
	if tactical_popover.visible == visible_now:
		return
	tactical_popover.visible = visible_now
	active_unit_plate.set_details_visible(visible_now)
	breakdown_visibility_changed.emit(visible_now)


func breakdown_visible() -> bool:
	return tactical_popover.visible


func _unhandled_input(event: InputEvent) -> void:
	if event.is_action_pressed(&"combat_breakdown"):
		toggle_breakdown()
		get_viewport().set_input_as_handled()
	elif event.is_action_pressed(&"combat_end_turn"):
		if end_turn_allowed():
			combat_bar.press_end_turn()
		get_viewport().set_input_as_handled()
	else:
		# Keys 1–8 fire the hotbar slots (owner 2026-11-01), under Space's guards.
		for slot: int in CombatBar.HOTBAR_SIZE:
			if event.is_action_pressed(StringName("combat_slot_%d" % (slot + 1))):
				if end_turn_allowed():
					combat_bar.press_slot(slot)
				get_viewport().set_input_as_handled()
				return


## Space ends the turn, and keys 1–8 fire hotbar slots, only on the player's turn and never
## while a text field or the breakdown popover holds focus (owner 2026-11-01).
func end_turn_allowed() -> bool:
	if _controller == null or _controller.state != CombatController.State.ALLY_TURN:
		return false
	if not Battle.session_active or Battle.ended or combat_bar.outcome_shown():
		return false
	var focus := get_viewport().gui_get_focus_owner()
	if focus is LineEdit or focus is TextEdit:
		return false
	if focus != null and tactical_popover.is_ancestor_of(focus):
		return false
	return true


# --- layout around the field HUD's bar ------------------------------------------------------


## The field HUD tells the interface how much of the viewport its bar and the turn strip
## cover, so visibility checks, the target tooltip and the notices stay in the open window.
func set_hud_insets(top: float, bottom: float) -> void:
	_inset_top = top
	_inset_bottom = bottom
	stage.set_hud_insets(top, bottom)
	injury_notice.offset_top = -(bottom + DS.SPACE_6)
	injury_notice.offset_bottom = injury_notice.offset_top
	tactical_popover.offset_bottom = -(bottom + DS.SPACE_5)
	tactical_popover.offset_top = tactical_popover.offset_bottom - POPOVER_HEIGHT
	_position_injury_inspector()


func strip_height() -> float:
	return turn_strip.size.y


# --- entry cue (owner 2026-11-01: bar change plus a short cue, under 0.5 s) ----------------


## A brief edge vignette on combat start. Skipped entirely under reduced motion.
func play_entry_cue(reduced_motion: bool) -> void:
	if reduced_motion:
		vignette.visible = false
		return
	if _vignette_tween != null and _vignette_tween.is_valid():
		_vignette_tween.kill()
	vignette.modulate = Color(1, 1, 1, 0)
	vignette.visible = true
	_vignette_tween = create_tween()
	_vignette_tween.tween_property(vignette, "modulate:a", 1.0, DS.DUR_INSTANT)
	_vignette_tween.tween_property(vignette, "modulate:a", 0.0, DS.DUR_SLOW - DS.DUR_INSTANT)
	_vignette_tween.tween_callback(vignette.hide)


func _vignette_texture() -> GradientTexture2D:
	var gradient := Gradient.new()
	gradient.offsets = PackedFloat32Array([0.55, 1.0])
	gradient.colors = PackedColorArray([Color(DS.CINDER_1, 0.0), Color(DS.CINDER_1, 0.55)])
	var texture := GradientTexture2D.new()
	texture.gradient = gradient
	texture.fill = GradientTexture2D.FILL_RADIAL
	texture.fill_from = Vector2(0.5, 0.5)
	texture.fill_to = Vector2(1.0, 0.5)
	texture.width = 256
	texture.height = 256
	return texture


# --- controller binding ---------------------------------------------------------------------


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


## The plate sits in the bottom bar, so the inspector opens above it, not below.
func _position_injury_inspector() -> void:
	if not is_instance_valid(injury_inspector) or not is_instance_valid(active_unit_plate):
		return
	var above := active_unit_plate.global_position - Vector2(0, injury_inspector.size.y + DS.SPACE_4)
	injury_inspector.position = get_global_transform().affine_inverse() * above


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
	cursor_readout.text = cell_readout(tile)


## #281 G8: the strip names the cell, its height, who stands on it, and only the charge and
## note fields the tile actually carries; an uncharged tile prints no empty element slot.
func cell_readout(tile: Dictionary) -> String:
	var cell := Vector2i(int(tile.get("x", 0)), int(tile.get("y", 0)))
	var parts := PackedStringArray([
		"(%d,%d)" % [cell.x, cell.y],
		"HEIGHT %d" % int(tile.get("height_delta", tile.get("height", 0))),
	])
	var occupant_id := stage._actor_at(cell)
	if not occupant_id.is_empty() and _controller != null:
		var occupant := _controller.actor_by_id(occupant_id)
		if occupant != null:
			parts.append(occupant.display_name.to_upper())
	var element := str(tile.get("charge_element_id", "")).strip_edges()
	var charge := int(tile.get("charge_level", 0))
	if charge > 0:
		parts.append("%s %d" % [element.to_upper() if not element.is_empty() else "CHARGE", charge])
	var note := str(tile.get("note", "")).strip_edges()
	if not note.is_empty():
		parts.append(note)
	return " · ".join(parts)


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
	# Hovered move quote is display-only: the stage renders the controller's move_query pricing
	# in the active economy (#473: CT and the banked charge left under charge time, else AP).
	else:
		_clear_target_preview()
		var move_quote := stage.hovered_move_quote()
		if not move_quote.is_empty():
			cursor_readout.text += " · MOVE " + move_quote


## HP as the field presents it (#473): the presented snapshot's row, else the live actor.
func presented_hp(actor: BattleActor) -> Vector2i:
	var event := stage.presented_event()
	if event != null:
		var snapshot: Dictionary = event.data.get("snapshot", {})
		for side: String in ["allies", "enemies"]:
			for row: Variant in snapshot.get(side, []):
				if row is Dictionary and StringName(str((row as Dictionary).get("id", ""))) == actor.combat_id:
					return Vector2i(
						int((row as Dictionary).get("hp", actor.hp)),
						int((row as Dictionary).get("max_hp", actor.max_hp)),
					)
	return Vector2i(actor.hp, actor.max_hp)


## Hovering a target quotes it in a small tooltip beside the creature: name, HP, hit chance
## and the damage forecast (owner 2026-11-01, "detail on hover"). Every number is the
## controller's own forecast; the full breakdown stays in the popover.
func _show_target_forecast(action: CombatAction, target: BattleActor) -> void:
	var options := _action_options(action)
	var payload := _controller.forecast_action(action, target, options)
	var context := _controller.forecast_context(_controller.active_actor(), target, action, options)
	# Combat polish 2026-11-02: out of reach, the quote is the walk-in order, priced from the
	# cell the unit would act from, with the path drawn ("preview, then refuse").
	var approach := {} if bool(payload.get("allowed", false)) else _controller.approach_query(action, target, options)
	if bool(approach.get("allowed", false)):
		payload = approach["forecast"]
		context = approach["context"]
	act_target_panel.show_action_forecast(payload, context)
	_append_cast_forecast(action, payload)
	act_target_panel.show_aim_forecast(payload, _aim_location, _controller.rules.use_charge_time)
	var quote := target_quote(payload, context, target)
	if not approach.is_empty():
		quote = "%s\n%s" % [quote, approach_line(approach, action)]
		stage.show_approach_path(approach.get("path_cells", []), bool(approach.get("allowed", false)))
	else:
		stage.clear_approach_path()
	stage.show_target_preview(target.combat_id, target.display_name, quote)


## The walk-in line under a target quote: "WALK IN · MOVE 3 + STRIKE 2 = 5 AP" when the order
## is affordable, else the refusal ("Move 3 + Strike 2 = 5 AP; 4 AP left.").
func approach_line(approach: Dictionary, action: CombatAction) -> String:
	if not bool(approach.get("allowed", false)):
		return str(approach.get("message", ""))
	return tr("WALK IN · MOVE %d + %s %d = %d AP") % [
		int(approach.get("move_ap", 0)), action.display_name.to_upper(),
		int(approach.get("action_ap", 0)), int(approach.get("total_ap", 0)),
	]


## The tooltip's quote lines: "HP a / b" then "PART · HIT n% · d DMG" (or UNAVAILABLE with
## the controller's reason), then the injury odds when the aim carries any.
func target_quote(payload: Dictionary, context: Dictionary, target: BattleActor) -> String:
	var hp := presented_hp(target)
	var lines := PackedStringArray([tr("HP %d / %d") % [hp.x, hp.y]])
	var part := tr("ORDINARY")
	if not _aim_location.is_empty():
		var anatomy: Dictionary = target.anatomy.get(String(_aim_location), {})
		part = str(anatomy.get("display_name", _aim_location)).to_upper()
	if not bool(payload.get("allowed", false)):
		lines.append("%s · %s" % [part, tr("UNAVAILABLE")])
		var reason := str(payload.get("message", "")).strip_edges()
		if not reason.is_empty():
			lines.append(reason)
		return "\n".join(lines)
	var resolution: Dictionary = payload.get("resolution", {})
	var accuracy: Dictionary = resolution.get("accuracy_breakdown", {})
	var hit := int(accuracy.get("effective_hit_chance", resolution.get("hit_chance", 100)))
	var damage := str(payload.get("damage_on_hit", payload.get("damage", 0)))
	var landed := Resolution.preview_on_hit(context)
	if not (landed.get("hidden_draw", {}) as Dictionary).is_empty() and not bool(resolution.get("reveal", false)):
		damage = "?"
	lines.append(tr("%s · HIT %d%% · %s DMG") % [part, hit, damage])
	var injury: Dictionary = payload.get("injury_forecast", {})
	if bool(injury.get("eligible", false)):
		lines.append(tr("INJURY %d%% ON HIT · %d%% OVERALL") % [
			int(injury.get("chance_on_hit", 0)), int(injury.get("overall_chance", 0)),
		])
	return "\n".join(lines)


func _clear_target_preview() -> void:
	_aim_target = null
	stage.clear_target_preview()
	stage.clear_approach_path()


func _refuse(message: String) -> void:
	act_target_panel.pulse_refusal(message)
	refusal_pulsed.emit(message)


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
			return
		# Out of reach: walk in and act as one order, or refuse with the walk-in totals.
		var approach := _controller.approach_query(action, target, options)
		if bool(approach.get("allowed", false)):
			_clear_target_preview()
			_controller.submit_approach(_selected_action_id, target, options)
		elif not approach.is_empty():
			_refuse(str(approach.get("message", "Action blocked.")))
		else:
			_refuse(str(payload.get("message", "Action blocked.")))
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
			_refuse("Touch the enemy to bind first, then pick the field.")
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
		_refuse(str(payload.get("message", "Action blocked.")))
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
	cursor_readout.text = ""
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
