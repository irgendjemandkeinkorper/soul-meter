class_name CombatBar
extends HBoxContainer
## The bar's combat parts (owner 2026-11-01, "one bar, both modes"): the active member's
## plate, the message window, the command grid, the party readout and the turn controls.
## Authored inside battle_interface.tscn and hosted in the field HUD's bottom bar while a
## fight is on. The logic is the former command dock's (ui/screens/battle.gd): every button
## routes to the same Battle / controller commands, and nothing here resolves combat.

const LOG_LINE_LIMIT := 40

@onready var active_unit_plate: UnitPlateRegion = %ActiveUnitPlate

var cursor_readout: Label
var log_scroll: ScrollContainer
var log_list: VBoxContainer
var _enemy_lbl: Label
var _balance_lbl: Label
var _balance_bar: ProgressBar
var _party_box: VBoxContainer
var _actions_box: GridContainer
var _action_scroll: ScrollContainer
var _aim_host: HBoxContainer
var _target_button: Button
var _end_turn_button: Button
var _withdraw_button: Button
var _breakdown_button: Button
var _outcome_box: VBoxContainer
var _action_buttons: Array[Button] = []
var _interface: BattleInterface
var _weakness_dialog: Window
var _weakness_picker: OptionButton
var _weakness_forecast: Label
var _selected_weakness_id: StringName = &""
var _refresh_queued := false
## #473: the result waits here until the field has presented the beats that led to it.
var _pending_result: BattleResult
var _built := false


func _ready() -> void:
	_build()
	_refresh()


## The field HUD reparents the bar out of the interface and into its own bar, which leaves
## and re-enters the tree; the Battle wiring follows the tree membership, not `_ready`.
func _enter_tree() -> void:
	if not Battle.turn_resolved.is_connected(_queue_refresh):
		Battle.turn_resolved.connect(_queue_refresh)
	if not Battle.balance_changed.is_connected(_on_balance_changed):
		Battle.balance_changed.connect(_on_balance_changed)
	if not Battle.battle_ended.is_connected(_on_battle_ended):
		Battle.battle_ended.connect(_on_battle_ended)
	if _built:
		_queue_refresh()


func _exit_tree() -> void:
	if Battle.turn_resolved.is_connected(_queue_refresh):
		Battle.turn_resolved.disconnect(_queue_refresh)
	if Battle.balance_changed.is_connected(_on_balance_changed):
		Battle.balance_changed.disconnect(_on_balance_changed)
	if Battle.battle_ended.is_connected(_on_battle_ended):
		Battle.battle_ended.disconnect(_on_battle_ended)


## The interface owns pointer aiming and the breakdown popover; the bar only routes to it.
func bind(interface: BattleInterface) -> void:
	_interface = interface
	if not interface.refusal_pulsed.is_connected(_on_refusal):
		interface.refusal_pulsed.connect(_on_refusal)
	if not interface.breakdown_visibility_changed.is_connected(_on_breakdown_visibility_changed):
		interface.breakdown_visibility_changed.connect(_on_breakdown_visibility_changed)
	if not interface.stage.beat_presented.is_connected(_on_beat_presented):
		interface.stage.beat_presented.connect(_on_beat_presented)
	_refresh()


## The aim row (called shots) is a command, so it lives on the bar under the action grid
## even though the forecast panel that builds it sits in the breakdown popover.
func host_aim_row(row: Control) -> void:
	if row.get_parent() == _aim_host:
		return
	row.reparent(_aim_host, false)
	row.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_aim_host.visible = row.visible
	row.visibility_changed.connect(func() -> void: _aim_host.visible = row.visible)


## Left to right, Fallout 2's reading order: who acts, what happened, what you can do, who
## is with you, and the turn controls. The SoulGauge stays the bar's rightmost element and
## belongs to the field HUD itself.
func _build() -> void:
	add_child(_rule())

	var log_column := VBoxContainer.new()
	log_column.name = "LogColumn"
	log_column.theme_type_variation = "HudBarColumn"
	log_column.custom_minimum_size = Vector2(280, 0)
	log_column.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	add_child(log_column)
	cursor_readout = Label.new()
	cursor_readout.name = "CursorReadout"
	cursor_readout.theme_type_variation = "HeadingLabel"
	cursor_readout.text = "CURSOR —"
	cursor_readout.text_overrun_behavior = TextServer.OVERRUN_TRIM_ELLIPSIS
	log_column.add_child(cursor_readout)
	var balance_row := HBoxContainer.new()
	balance_row.name = "BalanceRow"
	balance_row.theme_type_variation = "HudBarRow"
	log_column.add_child(balance_row)
	_balance_bar = ProgressBar.new()
	_balance_bar.name = "BalanceBar"
	_balance_bar.min_value = Battle.BALANCE_MIN
	_balance_bar.max_value = Battle.BALANCE_MAX
	_balance_bar.show_percentage = false
	_balance_bar.custom_minimum_size = Vector2(0, 6)
	_balance_bar.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_balance_bar.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	balance_row.add_child(_balance_bar)
	_balance_lbl = Label.new()
	_balance_lbl.name = "BalanceLabel"
	_balance_lbl.theme_type_variation = "EyebrowLabel"
	_balance_lbl.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
	balance_row.add_child(_balance_lbl)
	log_scroll = ScrollContainer.new()
	log_scroll.name = "MessageLog"
	log_scroll.size_flags_vertical = Control.SIZE_EXPAND_FILL
	log_scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	log_column.add_child(log_scroll)
	log_list = VBoxContainer.new()
	log_list.name = "Lines"
	log_list.theme_type_variation = "HudBarColumn"
	log_list.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	log_scroll.add_child(log_list)

	add_child(_rule())

	var command_column := VBoxContainer.new()
	command_column.name = "CommandColumn"
	command_column.theme_type_variation = "HudBarColumn"
	command_column.custom_minimum_size = Vector2(560, 0)
	add_child(command_column)
	var command_title := Label.new()
	command_title.text = "COMMAND"
	command_title.theme_type_variation = "EyebrowLabel"
	command_column.add_child(command_title)
	# The action catalog grows with the class kits. Scroll its rows inside the bar so every
	# command remains reachable without growing the bar.
	_action_scroll = ScrollContainer.new()
	_action_scroll.name = "ActionScroll"
	_action_scroll.custom_minimum_size = Vector2(0, 84)
	_action_scroll.size_flags_vertical = Control.SIZE_EXPAND_FILL
	_action_scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	_action_scroll.follow_focus = true
	command_column.add_child(_action_scroll)
	_actions_box = GridContainer.new()
	_actions_box.name = "Actions"
	_actions_box.columns = 4
	_actions_box.theme_type_variation = "HudActionGrid"
	_actions_box.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_action_scroll.add_child(_actions_box)
	for action in Battle.available_actions():
		var button := _button(_actions_box, _short_action_text(action), _use_action.bind(action.id))
		# No autowrap: single-line labels keep the grid two rows tall.
		button.theme_type_variation = "HudActionButton"
		button.custom_minimum_size = Vector2(0, 26)
		button.clip_text = true
		button.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		button.tooltip_text = _action_tooltip(action)
		_action_buttons.append(button)
	_outcome_box = VBoxContainer.new()
	_outcome_box.name = "Outcome"
	_outcome_box.theme_type_variation = "HudBarColumn"
	_outcome_box.visible = false
	command_column.add_child(_outcome_box)
	_aim_host = HBoxContainer.new()
	_aim_host.name = "AimRow"
	_aim_host.theme_type_variation = "HudBarRow"
	_aim_host.visible = false
	command_column.add_child(_aim_host)
	var aim_title := Label.new()
	aim_title.text = tr("AIM")
	aim_title.theme_type_variation = "EyebrowLabel"
	_aim_host.add_child(aim_title)
	var command_footer := HBoxContainer.new()
	command_footer.name = "CommandFooter"
	command_footer.theme_type_variation = "HudBarRow"
	command_column.add_child(command_footer)
	_enemy_lbl = Label.new()
	_enemy_lbl.name = "FoeReadout"
	_enemy_lbl.theme_type_variation = "StatLabel"
	_enemy_lbl.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_enemy_lbl.text_overrun_behavior = TextServer.OVERRUN_TRIM_ELLIPSIS
	command_footer.add_child(_enemy_lbl)
	_target_button = _button(command_footer, "", Battle.select_next_enemy)
	_target_button.name = "TargetButton"
	_target_button.theme_type_variation = "HudActionButton"
	_target_button.custom_minimum_size = Vector2(180, 26)

	add_child(_rule())

	var party_column := VBoxContainer.new()
	party_column.name = "PartyColumn"
	party_column.theme_type_variation = "HudBarColumn"
	party_column.custom_minimum_size = Vector2(220, 0)
	add_child(party_column)
	var party_title := Label.new()
	party_title.text = "PARTY"
	party_title.theme_type_variation = "EyebrowLabel"
	party_column.add_child(party_title)
	_party_box = VBoxContainer.new()
	_party_box.name = "PartyRows"
	_party_box.theme_type_variation = "BattleTightColumn"
	_party_box.size_flags_vertical = Control.SIZE_EXPAND_FILL
	party_column.add_child(_party_box)

	add_child(_rule())

	var controls := VBoxContainer.new()
	controls.name = "TurnControls"
	controls.theme_type_variation = "HudBarColumn"
	controls.custom_minimum_size = Vector2(124, 0)
	add_child(controls)
	_end_turn_button = _button(controls, "END TURN", Battle.end_turn)
	_end_turn_button.name = "EndTurnButton"
	_end_turn_button.custom_minimum_size = Vector2(124, 40)
	_end_turn_button.theme_type_variation = "BronzeButton"
	_withdraw_button = _button(controls, "WITHDRAW", Battle.flee)
	_withdraw_button.name = "WithdrawButton"
	_withdraw_button.custom_minimum_size = Vector2(124, 28)
	_withdraw_button.theme_type_variation = "DangerButton"
	_breakdown_button = _button(controls, tr("BREAKDOWN"), _toggle_breakdown)
	_breakdown_button.name = "BreakdownButton"
	_breakdown_button.custom_minimum_size = Vector2(124, 28)
	_breakdown_button.toggle_mode = true
	_breakdown_button.tooltip_text = tr("Accuracy and power breakdown, attunement and tactical data (B).")
	_built = true


func _rule() -> VSeparator:
	var rule := VSeparator.new()
	rule.theme_type_variation = "HudBarRule"
	return rule


func _button(box: Container, text: String, cb: Callable) -> Button:
	var button := Button.new()
	button.text = text
	button.mouse_default_cursor_shape = Control.CURSOR_POINTING_HAND
	button.pressed.connect(cb)
	box.add_child(button)
	return button


func _make_meter() -> ProgressBar:
	var meter := ProgressBar.new()
	meter.show_percentage = false
	meter.theme_type_variation = "HealthProgressBar"
	return meter


# --- the message window ------------------------------------------------------------------


## Appends one narration line. Lines come from the event stream (`message`), turn cues and
## refusals; the bar never writes prose of its own.
func append_log(text: String, variation: String = "HudLogLine") -> void:
	if text.strip_edges().is_empty():
		return
	var line := Label.new()
	line.text = text
	line.theme_type_variation = variation
	line.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	line.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	log_list.add_child(line)
	while log_list.get_child_count() > LOG_LINE_LIMIT:
		var oldest := log_list.get_child(0)
		log_list.remove_child(oldest)
		oldest.queue_free()
	_scroll_log_to_end.call_deferred()


func append_cue(text: String) -> void:
	append_log(text, "HudLogCue")


func log_lines() -> PackedStringArray:
	var lines := PackedStringArray()
	for child: Node in log_list.get_children():
		lines.append((child as Label).text)
	return lines


func _scroll_log_to_end() -> void:
	if is_instance_valid(log_scroll):
		log_scroll.scroll_vertical = int(log_scroll.get_v_scroll_bar().max_value)


func _on_refusal(message: String) -> void:
	append_log(message, "HudLogRefusal")


## #473: the log follows the field's presented beats, so a sequenced enemy phase narrates
## in the order the player sees it. Turn cues come from the event type; narration from the
## event's own `message`.
func _on_beat_presented(event: CombatEvent) -> void:
	if event.type in [&"turn_started", &"enemy_turn_started"]:
		var actor_name := _actor_name(event)
		if not actor_name.is_empty():
			append_cue(tr("TURN  ·  %s") % actor_name.to_upper())
	if event.data.has("message"):
		append_log(str(event.data["message"]))
	_queue_refresh()


func _actor_name(event: CombatEvent) -> String:
	if event.actor_id.is_empty():
		return ""
	var row: Dictionary = _presented_rows().get(event.actor_id, {})
	if not row.is_empty():
		return str(row.get("display_name", row.get("name", "")))
	if Battle.controller != null:
		var actor := Battle.controller.actor_by_id(event.actor_id)
		if actor != null:
			return actor.display_name
	return ""


# --- commands ----------------------------------------------------------------------------


func _use_action(action_id: StringName) -> void:
	var action: CombatAction = null
	for candidate: CombatAction in Battle.available_actions():
		if candidate.id == action_id:
			action = candidate
			break
	if action != null and action.kind == CombatAction.Kind.DEFINING_STRIKE:
		_open_weakness_dialog()
		return
	if action != null and is_instance_valid(_interface):
		if action.targets_cells() or action.targets_any_side() or (
			action.class_resource_action.is_empty() and action.target_side == "ally"
		):
			# Cell workings and creature-side cards are aimed on the stage; the button only arms.
			_interface.select_pointer_action(action_id)
			return
		if action.requires_enemy_target():
			_interface.select_pointer_action(action_id)
	Battle.use_action(action_id)


func _open_weakness_dialog() -> void:
	var weaknesses := Battle.available_weaknesses()
	if weaknesses.is_empty():
		return
	_ensure_weakness_dialog()
	_weakness_picker.clear()
	for weakness: Dictionary in weaknesses:
		_weakness_picker.add_item(str(weakness.get("display_name", weakness.get("id", "Weakness"))))
		_weakness_picker.set_item_metadata(
			_weakness_picker.item_count - 1, StringName(weakness.get("id", ""))
		)
	_selected_weakness_id = StringName(_weakness_picker.get_item_metadata(0))
	_update_weakness_forecast(0)
	_weakness_dialog.popup_centered(Vector2i(520, 280))


func _ensure_weakness_dialog() -> void:
	if is_instance_valid(_weakness_dialog):
		return
	_weakness_dialog = Window.new()
	_weakness_dialog.name = "DefiningStrikeDialog"
	_weakness_dialog.title = "Defining Strike"
	_weakness_dialog.transient = true
	_weakness_dialog.exclusive = true
	_weakness_dialog.unresizable = true
	_weakness_dialog.close_requested.connect(_weakness_dialog.hide)
	add_child(_weakness_dialog)

	var margin := MarginContainer.new()
	margin.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	margin.theme_type_variation = "BattlePanelMargin"
	_weakness_dialog.add_child(margin)
	var column := VBoxContainer.new()
	margin.add_child(column)
	var instruction := Label.new()
	instruction.text = "Choose a discovered weakness to name."
	column.add_child(instruction)
	_weakness_picker = OptionButton.new()
	_weakness_picker.name = "WeaknessPicker"
	_weakness_picker.item_selected.connect(_update_weakness_forecast)
	column.add_child(_weakness_picker)
	_weakness_forecast = Label.new()
	_weakness_forecast.name = "WeaknessForecast"
	_weakness_forecast.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	_weakness_forecast.size_flags_vertical = Control.SIZE_EXPAND_FILL
	column.add_child(_weakness_forecast)
	var buttons := HBoxContainer.new()
	buttons.alignment = BoxContainer.ALIGNMENT_END
	column.add_child(buttons)
	var cancel := _button(buttons, "CANCEL", _weakness_dialog.hide)
	cancel.custom_minimum_size = Vector2(96, 30)
	var confirm := _button(buttons, "CONFIRM STRIKE", _confirm_weakness)
	confirm.name = "ConfirmDefiningStrike"
	confirm.custom_minimum_size = Vector2(156, 34)
	confirm.theme_type_variation = "BronzeButton"


func _update_weakness_forecast(index: int) -> void:
	if not is_instance_valid(_weakness_picker) or index < 0 or index >= _weakness_picker.item_count:
		return
	_selected_weakness_id = StringName(_weakness_picker.get_item_metadata(index))
	var forecast := Battle.defining_strike_forecast(_selected_weakness_id)
	if not bool(forecast.get("allowed", false)):
		_weakness_forecast.text = str(forecast.get("message", "Strike unavailable."))
		return
	var effect_name := str(forecast.get("effect_id", "")).replace("_", " ").capitalize()
	var resolution: Dictionary = forecast.get("resolution", {})
	var accuracy: Dictionary = resolution.get("accuracy_breakdown", {})
	_weakness_forecast.text = (
		"COST %d AP  ·  KNOWLEDGE %.0f%%  ·  HIT %d%%\nFORECAST %d DAMAGE ON HIT\n%s requires a successful knowledge check and a hit."
		% [
			int(forecast.get("ap_cost", 0)),
			float(forecast.get("chance", 0.0)),
			int(accuracy.get("effective_hit_chance", resolution.get("hit_chance", 100))),
			int(forecast.get("damage_on_hit", forecast.get("damage", 0))),
			effect_name if not effect_name.is_empty() else "No additional effect",
		]
	)


func _confirm_weakness() -> void:
	if _selected_weakness_id.is_empty():
		return
	_weakness_dialog.hide()
	Battle.use_defining_strike(_selected_weakness_id)


func _toggle_breakdown() -> void:
	if not is_instance_valid(_interface):
		return
	_interface.toggle_breakdown()


func _on_breakdown_visibility_changed(visible_now: bool) -> void:
	if is_instance_valid(_breakdown_button):
		_breakdown_button.set_pressed_no_signal(visible_now)


func _on_balance_changed(_value: int) -> void:
	_queue_refresh()


# --- refresh -----------------------------------------------------------------------------


## The controller resolves a whole enemy phase inside one frame, and nothing is drawn between
## its events, so the bar refreshes once per frame instead of once per event (#282: with 100
## hostiles that was 6 ms a turn, every turn). The deferred call still lands before the frame
## draws. Battle end and setup refresh directly.
func _queue_refresh() -> void:
	if _refresh_queued:
		return
	_refresh_queued = true
	_flush_refresh.call_deferred()


func _flush_refresh() -> void:
	_refresh_queued = false
	_refresh()


func _refresh() -> void:
	if not _built:
		return
	_balance_bar.value = Battle.balance
	_balance_lbl.text = _balance_text()
	_update_enemy_status()
	_update_party_status()

	var actions := Battle.available_actions()
	var cell_battlefield := _battlefield_has_cells()
	for i in _action_buttons.size():
		if i >= actions.size():
			_action_buttons[i].disabled = true
			continue
		# #473: on a cell battlefield a move is a click on a cell; the zone MOVE cards
		# (FRONT/BACK/FLANK, and the destination-less MOVE) have nothing to aim at there.
		_action_buttons[i].visible = not (
			cell_battlefield and actions[i].kind == CombatAction.Kind.MOVE
		)
		var reason := Battle.action_lock_reason(actions[i])
		var forecast := (
			Battle.action_forecast(actions[i])
			if actions[i].kind == CombatAction.Kind.CAST and reason.is_empty()
			else {}
		)
		_action_buttons[i].disabled = not reason.is_empty()
		_action_buttons[i].tooltip_text = _action_tooltip(actions[i], reason, forecast)
		_action_buttons[i].text = _short_action_text(actions[i], reason, forecast)

	var target := Battle.current_target()
	_target_button.text = "TARGET  •  %s  〉" % (target.display_name if target else "NONE")
	_target_button.disabled = Battle.living_enemies().size() <= 1

	if is_instance_valid(_interface):
		var forecast_ctx := Battle.forecast_context()
		if not forecast_ctx.is_empty():
			_interface.set_forecast_context(forecast_ctx)
		_breakdown_button.set_pressed_no_signal(_interface.breakdown_visible())


func _battlefield_has_cells() -> bool:
	if Battle.controller == null or Battle.controller.battlefield == null:
		return false
	return bool(Battle.controller.battlefield.capabilities().get("cells", false))


## #473: the actor rows of the snapshot the field currently presents, by combat id. Empty
## before the first presented event; callers then fall back to the live actor.
func _presented_rows() -> Dictionary:
	var rows: Dictionary = {}
	if not is_instance_valid(_interface):
		return rows
	var event := _interface.stage.presented_event()
	if event == null:
		return rows
	var snapshot: Dictionary = event.data.get("snapshot", {})
	for side: String in ["allies", "enemies"]:
		for row: Variant in snapshot.get(side, []):
			if row is Dictionary:
				rows[StringName(str((row as Dictionary).get("id", "")))] = row
	return rows


## HP as the field presents it: the presented snapshot's row, else the live actor.
func _presented_hp(actor: BattleActor, rows: Dictionary) -> Vector2i:
	var row: Dictionary = rows.get(actor.combat_id, {})
	if row.is_empty():
		return Vector2i(actor.hp, actor.max_hp)
	return Vector2i(int(row.get("hp", actor.hp)), int(row.get("max_hp", actor.max_hp)))


func _update_enemy_status() -> void:
	var target := Battle.current_target()
	if target == null:
		_enemy_lbl.text = "FOE  —"
		return
	var hp := _presented_hp(target, _presented_rows())
	_enemy_lbl.text = "FOE  %s  ·  HP %d / %d" % [target.display_name.to_upper(), hp.x, hp.y]


## One slim entry per ally — name and HP on a line, a thin meter under it; the bar is a
## readout, not a card stack, and the unit plate carries the active member's detail.
## Entry children: [0] the name row (marker, name, HP label), [1] the meter.
func _update_party_status() -> void:
	for child in _party_box.get_children():
		child.free()
	var rows := _presented_rows()
	for actor in Battle.allies:
		var hp_now := _presented_hp(actor, rows)
		var entry := VBoxContainer.new()
		entry.theme_type_variation = "HudBarColumn"
		_party_box.add_child(entry)
		var row := HBoxContainer.new()
		row.name = "NameRow"
		row.theme_type_variation = "BattlePartyRow"
		entry.add_child(row)
		var marker := Label.new()
		marker.text = "▶" if actor == Battle.current_ally() and hp_now.x > 0 else "·"
		marker.custom_minimum_size = Vector2(12, 0)
		marker.theme_type_variation = "EyebrowLabel"
		row.add_child(marker)
		var name_label := Label.new()
		name_label.text = actor.display_name.to_upper()
		if hp_now.x <= 0:
			name_label.text += "  ·  FALLEN"
		name_label.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		name_label.text_overrun_behavior = TextServer.OVERRUN_TRIM_ELLIPSIS
		name_label.theme_type_variation = "StatLabel"
		row.add_child(name_label)
		# Second row: the HP readout beside its meter, so the name above keeps the
		# column's full width (Fallout's party cards read name first, then health).
		var hp_row := HBoxContainer.new()
		hp_row.name = "HPRow"
		hp_row.theme_type_variation = "BattlePartyRow"
		entry.add_child(hp_row)
		var hp := Label.new()
		hp.name = "HP"
		hp.text = "HP %d / %d" % [hp_now.x, hp_now.y]
		hp.custom_minimum_size = Vector2(92, 0)
		hp.theme_type_variation = "StatLabel"
		hp_row.add_child(hp)
		var bar := _make_meter()
		bar.name = "Meter"
		bar.max_value = hp_now.y
		bar.value = hp_now.x
		bar.custom_minimum_size = Vector2(0, 6)
		bar.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		bar.size_flags_vertical = Control.SIZE_SHRINK_CENTER
		hp_row.add_child(bar)


## AP round economy: every command label surfaces its AP cost (ratified
## `docs/fallout2-adoption-spec.md` Wave 1) — this is the shipped scheduler's
## live cost display, not a Gate T-10 compatibility remnant.
func _short_action_text(
	action: CombatAction, reason: String = "", forecast: Dictionary = {}
) -> String:
	var text := "%s · %d AP" % [action.display_name.to_upper(), action.ap_cost]
	if action.kind == CombatAction.Kind.CAST and not forecast.is_empty():
		text += " · BREATH %d · SOUL %d" % [
			int(forecast.get("breath_cost", 0)), int(forecast.get("soul_cost", 0.0))
		]
	elif action.soul_cost > 0.0:
		text += " · SOUL %d" % int(action.soul_cost)
	if not reason.is_empty() and action.kind == CombatAction.Kind.RESOLUTION:
		text += " · LOCKED"
	return text


func _action_tooltip(
	action: CombatAction, reason: String = "", forecast: Dictionary = {}
) -> String:
	var text := action.summary()
	if action.kind == CombatAction.Kind.CAST and not forecast.is_empty():
		text += "\nBreath %d · Soul %d · Fizzle %.0f%%" % [
			int(forecast.get("breath_cost", 0)),
			int(forecast.get("soul_cost", 0.0)),
			float(forecast.get("fizzle_percent", 0.0)),
		]
	if not reason.is_empty():
		text += "\nLocked: " + reason
	return text


func _balance_text() -> String:
	if Battle.balance <= -Battle.EXTREME_THRESHOLD:
		return "CHAOS  %d" % Battle.balance
	if Battle.balance >= Battle.EXTREME_THRESHOLD:
		return "ORDER  +%d" % Battle.balance
	return "CHAOS  ◀  %s  ▶  ORDER" % ("+%d" % Battle.balance if Battle.balance > 0 else str(Battle.balance))


# --- outcome -----------------------------------------------------------------------------


## The model resolves the finishing blow in the frame of the command; the field presents it
## over the next beats. The result is shown once the field has presented them (#473).
func _on_battle_ended(result: BattleResult) -> void:
	_refresh()
	_pending_result = result
	if is_instance_valid(_interface) and _interface.stage.is_presenting_beats():
		set_process(true)
		return
	_show_outcome()


func _process(_delta: float) -> void:
	if _pending_result == null:
		set_process(false)
		return
	if is_instance_valid(_interface) and _interface.stage.is_presenting_beats():
		return
	set_process(false)
	_refresh()
	_show_outcome()


func outcome_shown() -> bool:
	return is_instance_valid(_outcome_box) and _outcome_box.visible


func _show_outcome() -> void:
	var result := _pending_result
	_pending_result = null
	if result == null or outcome_shown():
		return
	_action_scroll.visible = false
	_aim_host.visible = false
	_target_button.visible = false
	_end_turn_button.disabled = true
	_withdraw_button.disabled = true
	append_log(result.message)
	if not result.cause.is_empty():
		append_log(result.cause)
	_outcome_box.visible = true
	var outcome := Label.new()
	outcome.text = "ENCOUNTER RESOLVED"
	outcome.theme_type_variation = "EyebrowLabel"
	_outcome_box.add_child(outcome)
	var continue_button := _button(_outcome_box, "CONTINUE", _continue_after_battle.bind(result))
	continue_button.name = "ContinueButton"
	continue_button.custom_minimum_size = Vector2(220, 36)
	continue_button.theme_type_variation = "BronzeButton"


func _continue_after_battle(result: BattleResult) -> void:
	if not result.succeeded() or result.spoils.is_empty():
		GameFlow.send_event("battle_end")
		return
	var panel := UIManager.open(UIManager.LOOT_PANEL) as LootPanel
	panel.configure("BATTLE SPOILS", result.spoils)
	panel.dismissed.connect(
		func(_remaining: Array[Dictionary]) -> void: GameFlow.send_event("battle_end"),
		CONNECT_ONE_SHOT,
	)
