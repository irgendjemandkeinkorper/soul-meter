extends Screen
## Full-screen party combat view. Battle owns the rules; this screen is the
## presentation layer and submits action IDs to the autoload.

const BATTLE_STAGE_SCENE := preload("res://ui/screens/battle_stage.tscn")
const BATTLE_HUD_SCENE := preload("res://ui/hud/battle_hud.tscn")
const BATTLE_INTERFACE_SCENE := preload("res://ui/hud/battle_interface.tscn")
const COMBAT_AUDIO := preload("res://audio/combat_audio.gd")

var _stage: Control
var _party_box: VBoxContainer
var _enemy_lbl: Label
var _balance_lbl: Label
var _balance_bar: ProgressBar
var _log_lbl: Label
var _actions_box: GridContainer
var _target_button: Button
var _end_turn_button: Button
var _tactical_data_button: Button
var _outcome_box: VBoxContainer
var _action_buttons: Array[Button] = []
var _battle_hud: BattleHUD
var _battle_interface: BattleInterface
var _combat_audio: Node
var _weakness_dialog: Window
var _weakness_picker: OptionButton
var _weakness_forecast: Label
var _selected_weakness_id: StringName = &""


func _build() -> void:
	# Battle is an overlay screen: the paused gameplay scene (and its FieldHUD) keeps
	# rendering underneath, so the screen needs its own opaque ground.
	var backdrop := ColorRect.new()
	backdrop.name = "Backdrop"
	backdrop.color = DS.VOID_1
	backdrop.set_anchors_preset(Control.PRESET_FULL_RECT)
	backdrop.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(backdrop)

	var safe_frame := MarginContainer.new()
	safe_frame.set_anchors_preset(Control.PRESET_FULL_RECT)
	safe_frame.theme_type_variation = "BattleSafeFrame"
	add_child(safe_frame)

	var layout := VBoxContainer.new()
	layout.theme_type_variation = "BattleLayout"
	layout.size_flags_vertical = Control.SIZE_EXPAND_FILL
	safe_frame.add_child(layout)

	var stage_space := Control.new()
	stage_space.name = "BattlefieldViewport"
	stage_space.custom_minimum_size = Vector2(0, 230)
	stage_space.size_flags_vertical = Control.SIZE_EXPAND_FILL
	stage_space.clip_contents = true
	layout.add_child(stage_space)

	_stage = BATTLE_STAGE_SCENE.instantiate() as Control
	_stage.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	stage_space.add_child(_stage)
	Battle.combat_event.connect(Callable(_stage, "consume_event"))
	Battle.replay_combat_events(Callable(_stage, "consume_event").bind(false))

	_battle_interface = BATTLE_INTERFACE_SCENE.instantiate() as BattleInterface
	_battle_interface.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	_battle_interface.z_index = 4
	stage_space.add_child(_battle_interface)
	Battle.combat_event.connect(_battle_interface.consume_event)
	Battle.replay_combat_events(_battle_interface.consume_event)
	if Battle.controller != null and Battle.controller.scheduler != null:
		_battle_interface.bind_scheduler(Battle.controller.scheduler)

	_battle_hud = BATTLE_HUD_SCENE.instantiate() as BattleHUD
	_battle_hud.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	_battle_hud.z_index = 5
	_battle_hud.visible = false
	stage_space.add_child(_battle_hud)
	Battle.combat_event.connect(_battle_hud.consume_event)
	Battle.replay_combat_events(_battle_hud.consume_event)

	_combat_audio = COMBAT_AUDIO.new() as Node
	add_child(_combat_audio)
	Battle.combat_event.connect(Callable(_combat_audio, "consume_event"))

	layout.add_child(_make_command_dock())

	Battle.turn_resolved.connect(_refresh)
	Battle.balance_changed.connect(func(_value: int) -> void: _refresh())
	Battle.battle_ended.connect(_on_battle_ended)
	_refresh()


## #211 item 4: the old 60px header + 276px three-panel rail are unified into one
## compact dock so the six-region stage gets the rest of the screen. Everything
## the header carried lives on: balance strip and foe readout in the center
## column, TACTICAL DATA next to WITHDRAW.
func _make_command_dock() -> Control:
	var dock := HBoxContainer.new()
	dock.name = "CommandDock"
	dock.custom_minimum_size = Vector2(0, 172)
	dock.theme_type_variation = "BattleRail"
	dock.size_flags_vertical = Control.SIZE_SHRINK_END

	var command_panel := PanelContainer.new()
	command_panel.custom_minimum_size = Vector2(620, 0)
	dock.add_child(command_panel)
	var command_margin := _panel_margin(command_panel)
	var command_column := VBoxContainer.new()
	command_column.theme_type_variation = "BattleColumn"
	command_margin.add_child(command_column)
	var command_title := Label.new()
	command_title.text = "COMMAND"
	command_title.theme_type_variation = "EyebrowLabel"
	command_column.add_child(command_title)
	# Four columns keep the dock short — with two, the two-line action buttons
	# stacked the grid taller than the rail this dock replaced.
	_actions_box = GridContainer.new()
	_actions_box.columns = 4
	_actions_box.theme_type_variation = "BattleActionGrid"
	_actions_box.size_flags_vertical = Control.SIZE_EXPAND_FILL
	command_column.add_child(_actions_box)
	for action in Battle.available_actions():
		var button := _menu_button(_actions_box, _short_action_text(action), _use_action.bind(action.id))
		# No autowrap: single-line labels keep the grid two rows tall — wrapped
		# labels grew the dock past the rail it replaced.
		button.custom_minimum_size = Vector2(0, 26)
		button.tooltip_text = _action_tooltip(action)
		_action_buttons.append(button)
	var command_footer := HBoxContainer.new()
	command_column.add_child(command_footer)
	_target_button = _menu_button(command_footer, "", Battle.select_next_enemy)
	_target_button.custom_minimum_size = Vector2(0, 26)
	_target_button.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_target_button.theme_type_variation = "BronzeButton"
	_end_turn_button = _menu_button(command_footer, "END TURN", Battle.end_turn)
	_end_turn_button.name = "EndTurnButton"
	_end_turn_button.custom_minimum_size = Vector2(124, 32)
	_end_turn_button.theme_type_variation = "BronzeButton"
	var flee := _menu_button(command_footer, "WITHDRAW", Battle.flee)
	flee.custom_minimum_size = Vector2(96, 26)
	flee.theme_type_variation = "DangerButton"

	var log_panel := PanelContainer.new()
	log_panel.custom_minimum_size = Vector2(310, 0)
	log_panel.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	dock.add_child(log_panel)
	var log_margin := _panel_margin(log_panel)
	var log_column := VBoxContainer.new()
	log_column.theme_type_variation = "BattleColumn"
	log_margin.add_child(log_column)
	var status_row := HBoxContainer.new()
	log_column.add_child(status_row)
	_enemy_lbl = Label.new()
	_enemy_lbl.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_enemy_lbl.theme_type_variation = "EyebrowLabel"
	status_row.add_child(_enemy_lbl)
	_balance_lbl = Label.new()
	_balance_lbl.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
	_balance_lbl.theme_type_variation = "EyebrowLabel"
	status_row.add_child(_balance_lbl)
	_balance_bar = ProgressBar.new()
	_balance_bar.min_value = Battle.BALANCE_MIN
	_balance_bar.max_value = Battle.BALANCE_MAX
	_balance_bar.show_percentage = false
	_balance_bar.custom_minimum_size = Vector2(0, 8)
	log_column.add_child(_balance_bar)
	_log_lbl = Label.new()
	_log_lbl.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	_log_lbl.size_flags_vertical = Control.SIZE_EXPAND_FILL
	_log_lbl.theme_type_variation = "QuoteLabel"
	log_column.add_child(_log_lbl)
	_outcome_box = VBoxContainer.new()
	_outcome_box.visible = false
	log_column.add_child(_outcome_box)

	var party_panel := PanelContainer.new()
	party_panel.custom_minimum_size = Vector2(330, 0)
	dock.add_child(party_panel)
	var party_margin := _panel_margin(party_panel)
	var party_column := VBoxContainer.new()
	party_column.theme_type_variation = "BattleColumn"
	party_margin.add_child(party_column)
	var party_header := HBoxContainer.new()
	party_column.add_child(party_header)
	var party_title := Label.new()
	party_title.text = "PARTY"
	party_title.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	party_title.theme_type_variation = "EyebrowLabel"
	party_header.add_child(party_title)
	_tactical_data_button = _menu_button(
		party_header, "TACTICAL DATA", _toggle_tactical_data
	)
	_tactical_data_button.custom_minimum_size = Vector2(110, 24)
	_tactical_data_button.theme_type_variation = "BronzeButton"
	_party_box = VBoxContainer.new()
	_party_box.theme_type_variation = "BattleTightColumn"
	_party_box.size_flags_vertical = Control.SIZE_EXPAND_FILL
	party_column.add_child(_party_box)

	return dock


func _panel_margin(panel: PanelContainer) -> MarginContainer:
	var margin := MarginContainer.new()
	margin.theme_type_variation = "BattlePanelMargin"
	panel.add_child(margin)
	return margin


func _make_meter(fill_color: Color) -> ProgressBar:
	var meter := ProgressBar.new()
	meter.show_percentage = false
	meter.theme_type_variation = "HealthProgressBar" if fill_color == DS.METER_HEALTH_B else "ProgressBar"
	return meter


func _use_action(action_id: StringName) -> void:
	var action: CombatAction = null
	for candidate: CombatAction in Battle.available_actions():
		if candidate.id == action_id:
			action = candidate
			break
	if action != null and action.kind == CombatAction.Kind.DEFINING_STRIKE:
		_open_weakness_dialog()
		return
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
	var cancel := _menu_button(buttons, "CANCEL", _weakness_dialog.hide)
	cancel.custom_minimum_size = Vector2(96, 30)
	var confirm := _menu_button(buttons, "CONFIRM STRIKE", _confirm_weakness)
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
	var resolution: Dictionary = forecast.get("resolution", {})
	var effect_name := str(forecast.get("effect_id", "")).replace("_", " ").capitalize()
	_weakness_forecast.text = (
		"COST %d AP  ·  CHANCE %.0f%%\nFORECAST %d DAMAGE  ·  %s"
		% [
			int(forecast.get("ap_cost", 0)),
			float(forecast.get("chance", 0.0)),
			int(resolution.get("damage", 0)),
			effect_name if not effect_name.is_empty() else "No additional effect",
		]
	)


func _confirm_weakness() -> void:
	if _selected_weakness_id.is_empty():
		return
	_weakness_dialog.hide()
	Battle.use_defining_strike(_selected_weakness_id)


func _toggle_tactical_data() -> void:
	if not is_instance_valid(_battle_hud):
		return
	_battle_hud.visible = not _battle_hud.visible
	if is_instance_valid(_tactical_data_button):
		_tactical_data_button.text = (
			"CLOSE TACTICAL DATA" if _battle_hud.visible else "TACTICAL DATA"
		)


func _refresh() -> void:
	if not is_instance_valid(_stage):
		return
	_balance_bar.value = Battle.balance
	_balance_lbl.text = _balance_text()
	_update_enemy_status()
	_update_party_status()
	_log_lbl.text = Battle.last_message

	var actions := Battle.available_actions()
	for i in _action_buttons.size():
		if i >= actions.size():
			_action_buttons[i].disabled = true
			continue
		var reason := Battle.action_lock_reason(actions[i])
		_action_buttons[i].disabled = not reason.is_empty()
		_action_buttons[i].tooltip_text = _action_tooltip(actions[i], reason)
		_action_buttons[i].text = _short_action_text(actions[i], reason)

	var target := Battle.current_target()
	_target_button.text = "TARGET  •  %s  〉" % (target.display_name if target else "NONE")
	_target_button.disabled = Battle.living_enemies().size() <= 1

	if is_instance_valid(_battle_interface):
		var forecast_ctx := Battle.forecast_context()
		if not forecast_ctx.is_empty():
			_battle_interface.set_forecast_context(forecast_ctx)


func _update_enemy_status() -> void:
	var target := Battle.current_target()
	if target == null:
		_enemy_lbl.text = "FOE  —"
		return
	_enemy_lbl.text = "FOE  %s  ·  HP %d / %d" % [target.display_name.to_upper(), target.hp, target.max_hp]


## One slim row per ally — the dock is 172px, so party status is a readout,
## not a card stack; the unit plate region carries the active unit's detail.
func _update_party_status() -> void:
	for child in _party_box.get_children():
		child.free()
	for actor in Battle.allies:
		var row := HBoxContainer.new()
		row.theme_type_variation = "BattlePartyRow"
		_party_box.add_child(row)
		var marker := Label.new()
		marker.text = "▶" if actor == Battle.current_ally() and actor.is_alive() else "·"
		marker.custom_minimum_size = Vector2(12, 0)
		marker.theme_type_variation = "EyebrowLabel"
		row.add_child(marker)
		var name_label := Label.new()
		name_label.text = actor.display_name.to_upper()
		if not actor.is_alive():
			name_label.text += "  ·  FALLEN"
		name_label.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		name_label.theme_type_variation = "StatLabel"
		row.add_child(name_label)
		var hp := Label.new()
		hp.text = "HP %d / %d" % [actor.hp, actor.max_hp]
		hp.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
		hp.theme_type_variation = "StatLabel"
		row.add_child(hp)
		var bar := _make_meter(DS.METER_HEALTH_B)
		bar.max_value = actor.max_hp
		bar.value = actor.hp
		bar.custom_minimum_size = Vector2(96, 8)
		bar.size_flags_vertical = Control.SIZE_SHRINK_CENTER
		row.add_child(bar)


## AP round economy: every command label surfaces its AP cost (ratified
## `docs/fallout2-adoption-spec.md` Wave 1) — this is the shipped scheduler's
## live cost display, not a Gate T-10 compatibility remnant.
func _short_action_text(action: CombatAction, reason: String = "") -> String:
	var text := "%s · %d AP" % [action.display_name.to_upper(), action.ap_cost]
	if action.soul_cost > 0.0:
		text += " · SOUL %d" % int(action.soul_cost)
	if not reason.is_empty() and action.kind == CombatAction.Kind.RESOLUTION:
		text += " · LOCKED"
	return text


func _action_tooltip(action: CombatAction, reason: String = "") -> String:
	var text := action.summary()
	if not reason.is_empty():
		text += "\nLocked: " + reason
	return text


func _balance_text() -> String:
	if Battle.balance <= -Battle.EXTREME_THRESHOLD:
		return "CHAOS  %d" % Battle.balance
	if Battle.balance >= Battle.EXTREME_THRESHOLD:
		return "ORDER  +%d" % Battle.balance
	return "CHAOS  ◀  %s  ▶  ORDER" % ("+%d" % Battle.balance if Battle.balance > 0 else str(Battle.balance))


func _on_battle_ended(result: BattleResult) -> void:
	_refresh()
	_actions_box.visible = false
	_target_button.visible = false
	_log_lbl.text = result.message
	if not result.cause.is_empty():
		_log_lbl.text += "\n" + result.cause
	_outcome_box.visible = true
	var outcome := Label.new()
	outcome.text = "ENCOUNTER RESOLVED"
	outcome.theme_type_variation = "EyebrowLabel"
	_outcome_box.add_child(outcome)
	var continue_button := _menu_button(_outcome_box, "CONTINUE", func() -> void: GameFlow.send_event("battle_end"))
	continue_button.theme_type_variation = "BronzeButton"


static func format_attack(
	player_name: String,
	enemy_name: String,
	enemy_hp_before: int,
	enemy_hp_after: int,
	enemy_max_hp: int,
	player_hp_before: int,
	player_hp_after: int,
	player_max_hp: int
) -> String:
	var dmg_to_enemy := enemy_hp_before - enemy_hp_after
	var lines: Array[String] = []

	lines.append("%s attacks %s, dealing %d damage (%s HP: %d/%d)." % [
		player_name, enemy_name, dmg_to_enemy, enemy_name, enemy_hp_after, enemy_max_hp
	])

	if enemy_hp_after <= 0:
		lines.append("%s is defeated." % enemy_name)
	else:
		var dmg_to_player := player_hp_before - player_hp_after
		lines.append("%s counterattacks, dealing %d damage (%s HP: %d/%d)." % [
			enemy_name, dmg_to_player, player_name, player_hp_after, player_max_hp
		])
		if player_hp_after <= 0:
			lines.append("%s falls. The fight is over." % player_name)

	return "\n".join(lines)


static func format_defend(
	player_name: String,
	enemy_name: String,
	player_hp_before: int,
	player_hp_after: int,
	player_max_hp: int,
	enemy_attack: int,
	player_defense: int
) -> String:
	var dmg_taken := player_hp_before - player_hp_after
	var unmitigated := maxi(1, enemy_attack - player_defense)
	var mitigated_amount := unmitigated - dmg_taken

	var lines: Array[String] = []
	lines.append("%s braces! Mitigates incoming damage from %s." % [player_name, enemy_name])

	if mitigated_amount > 0:
		lines.append("%s takes %d damage (blocked %d) (%s HP: %d/%d)." % [
			player_name, dmg_taken, mitigated_amount, player_name, player_hp_after, player_max_hp
		])
	else:
		lines.append("%s takes %d damage (mitigated to minimum) (%s HP: %d/%d)." % [
			player_name, dmg_taken, player_name, player_hp_after, player_max_hp
		])

	if player_hp_after <= 0:
		lines.append("%s falls. The fight is over." % player_name)

	return "\n".join(lines)
