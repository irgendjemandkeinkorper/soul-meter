extends Screen
## Full-screen party combat view. Battle owns the rules; this screen is the
## presentation layer and submits action IDs to the autoload.

const BATTLE_STAGE := preload("res://ui/screens/battle_stage.gd")
const BATTLE_HUD_SCENE := preload("res://ui/hud/battle_hud.tscn")
const COMBAT_AUDIO := preload("res://audio/combat_audio.gd")

var _stage: Control
var _party_box: VBoxContainer
var _enemy_lbl: Label
var _enemy_hp_bar: ProgressBar
var _enemy_hp_lbl: Label
var _balance_lbl: Label
var _balance_bar: ProgressBar
var _log_lbl: Label
var _actions_box: GridContainer
var _target_button: Button
var _outcome_box: VBoxContainer
var _action_buttons: Array[Button] = []
var _battle_hud: BattleHUD
var _combat_audio: Node


func _build() -> void:
	_stage = BATTLE_STAGE.new()
	_stage.set_anchors_preset(Control.PRESET_FULL_RECT)
	add_child(_stage)

	var safe_frame := MarginContainer.new()
	safe_frame.set_anchors_preset(Control.PRESET_FULL_RECT)
	safe_frame.theme_type_variation = "BattleSafeFrame"
	add_child(safe_frame)

	var layout := VBoxContainer.new()
	layout.theme_type_variation = "BattleLayout"
	layout.size_flags_vertical = Control.SIZE_EXPAND_FILL
	safe_frame.add_child(layout)
	layout.add_child(_make_header())
	_battle_hud = BATTLE_HUD_SCENE.instantiate() as BattleHUD
	layout.add_child(_battle_hud)
	Battle.combat_event.connect(_battle_hud.consume_event)
	Battle.replay_combat_events(_battle_hud.consume_event)
	_combat_audio = COMBAT_AUDIO.new() as Node
	add_child(_combat_audio)
	Battle.combat_event.connect(Callable(_combat_audio, "consume_event"))

	# The stage occupies the breathing room between the title rail and command rail.
	var stage_space := Control.new()
	stage_space.size_flags_vertical = Control.SIZE_EXPAND_FILL
	layout.add_child(stage_space)
	layout.add_child(_make_command_rail())

	Battle.turn_resolved.connect(_refresh)
	Battle.balance_changed.connect(func(_value: int) -> void: _refresh())
	Battle.battle_ended.connect(_on_battle_ended)
	_refresh()


func _make_header() -> Control:
	var header := HBoxContainer.new()
	header.custom_minimum_size = Vector2(0, 60)
	header.theme_type_variation = "BattleHeader"

	var title_stack := VBoxContainer.new()
	title_stack.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	var title := Label.new()
	title.text = "SOUL METER  //  ENGAGEMENT"
	title.theme_type_variation = "TitleLabel"
	title_stack.add_child(title)
	var subtitle := Label.new()
	subtitle.text = "THE FIELD HAS CHOSEN ITS SIDES"
	subtitle.theme_type_variation = "EyebrowLabel"
	title_stack.add_child(subtitle)
	header.add_child(title_stack)

	var round_label := Label.new()
	round_label.text = "ROUND-BASED\nTACTICS"
	round_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
	round_label.theme_type_variation = "EyebrowLabel"
	header.add_child(round_label)

	var balance_stack := VBoxContainer.new()
	balance_stack.custom_minimum_size = Vector2(240, 0)
	_balance_lbl = Label.new()
	_balance_lbl.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_balance_lbl.theme_type_variation = "EyebrowLabel"
	balance_stack.add_child(_balance_lbl)
	_balance_bar = ProgressBar.new()
	_balance_bar.min_value = Battle.BALANCE_MIN
	_balance_bar.max_value = Battle.BALANCE_MAX
	_balance_bar.show_percentage = false
	_balance_bar.custom_minimum_size = Vector2(0, 12)
	balance_stack.add_child(_balance_bar)
	header.add_child(balance_stack)

	var target_panel := PanelContainer.new()
	target_panel.custom_minimum_size = Vector2(265, 0)
	var target_margin := MarginContainer.new()
	target_margin.theme_type_variation = "BattleHeaderMargin"
	target_panel.add_child(target_margin)
	var target_stack := VBoxContainer.new()
	target_margin.add_child(target_stack)
	var eyebrow := Label.new()
	eyebrow.text = "CURRENT FOE"
	eyebrow.theme_type_variation = "EyebrowLabel"
	target_stack.add_child(eyebrow)
	_enemy_lbl = Label.new()
	_enemy_lbl.theme_type_variation = "HeadingLabel"
	target_stack.add_child(_enemy_lbl)
	_enemy_hp_lbl = Label.new()
	_enemy_hp_lbl.theme_type_variation = "StatLabel"
	target_stack.add_child(_enemy_hp_lbl)
	_enemy_hp_bar = _make_meter(DS.METER_HEALTH_B)
	_enemy_hp_bar.custom_minimum_size = Vector2(0, 10)
	target_stack.add_child(_enemy_hp_bar)
	header.add_child(target_panel)

	return header


func _make_command_rail() -> Control:
	var rail := HBoxContainer.new()
	rail.custom_minimum_size = Vector2(0, 276)
	rail.theme_type_variation = "BattleRail"
	rail.size_flags_vertical = Control.SIZE_SHRINK_END

	var command_panel := PanelContainer.new()
	command_panel.custom_minimum_size = Vector2(350, 0)
	rail.add_child(command_panel)
	var command_margin := _panel_margin(command_panel)
	var command_column := VBoxContainer.new()
	command_column.theme_type_variation = "BattleColumn"
	command_margin.add_child(command_column)
	var command_title := Label.new()
	command_title.text = "COMMAND"
	command_title.theme_type_variation = "HeadingLabel"
	command_column.add_child(command_title)
	var acting := Label.new()
	acting.text = "CHOOSE AN ACTION FOR THE ACTIVE PARTY MEMBER"
	acting.theme_type_variation = "EyebrowLabel"
	command_column.add_child(acting)
	_actions_box = GridContainer.new()
	_actions_box.columns = 2
	_actions_box.theme_type_variation = "BattleActionGrid"
	_actions_box.size_flags_vertical = Control.SIZE_EXPAND_FILL
	command_column.add_child(_actions_box)
	_target_button = _menu_button(command_column, "", Battle.select_next_enemy)
	_target_button.custom_minimum_size = Vector2(0, 32)
	_target_button.theme_type_variation = "BronzeButton"
	for action in Battle.available_actions():
		var button := _menu_button(_actions_box, _short_action_text(action), _use_action.bind(action.id))
		button.custom_minimum_size = Vector2(155, 42)
		button.tooltip_text = _action_tooltip(action)
		button.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
		_action_buttons.append(button)
	var flee := _menu_button(command_column, "WITHDRAW", Battle.flee)
	flee.custom_minimum_size = Vector2(0, 32)
	flee.theme_type_variation = "DangerButton"

	var log_panel := PanelContainer.new()
	log_panel.custom_minimum_size = Vector2(310, 0)
	log_panel.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	rail.add_child(log_panel)
	var log_margin := _panel_margin(log_panel)
	var log_column := VBoxContainer.new()
	log_column.theme_type_variation = "BattleColumn"
	log_margin.add_child(log_column)
	var log_title := Label.new()
	log_title.text = "BATTLE LOG"
	log_title.theme_type_variation = "HeadingLabel"
	log_column.add_child(log_title)
	_log_lbl = Label.new()
	_log_lbl.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	_log_lbl.size_flags_vertical = Control.SIZE_EXPAND_FILL
	_log_lbl.theme_type_variation = "QuoteLabel"
	log_column.add_child(_log_lbl)
	_outcome_box = VBoxContainer.new()
	_outcome_box.visible = false
	log_column.add_child(_outcome_box)

	var party_panel := PanelContainer.new()
	party_panel.custom_minimum_size = Vector2(410, 0)
	party_panel.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	rail.add_child(party_panel)
	var party_margin := _panel_margin(party_panel)
	var party_column := VBoxContainer.new()
	party_column.theme_type_variation = "BattleColumn"
	party_margin.add_child(party_column)
	var party_title := Label.new()
	party_title.text = "PARTY STATUS"
	party_title.theme_type_variation = "HeadingLabel"
	party_column.add_child(party_title)
	_party_box = VBoxContainer.new()
	_party_box.theme_type_variation = "BattleTightColumn"
	_party_box.size_flags_vertical = Control.SIZE_EXPAND_FILL
	party_column.add_child(_party_box)

	return rail


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
	Battle.use_action(action_id)


func _refresh() -> void:
	if not is_instance_valid(_stage):
		return
	_stage.set_battle_state(Battle.allies, Battle.enemies, Battle.target_enemy_index, Battle.current_ally(), Battle.balance)
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


func _update_enemy_status() -> void:
	var target := Battle.current_target()
	if target == null:
		_enemy_lbl.text = "NO TARGET"
		_enemy_hp_lbl.text = "—"
		_enemy_hp_bar.value = 0
		return
	_enemy_lbl.text = target.display_name.to_upper()
	_enemy_hp_lbl.text = "HP  %d / %d" % [target.hp, target.max_hp]
	_enemy_hp_bar.max_value = target.max_hp
	_enemy_hp_bar.value = target.hp


func _update_party_status() -> void:
	for child in _party_box.get_children():
		child.free()
	for actor in Battle.allies:
		var card := PanelContainer.new()
		card.custom_minimum_size = Vector2(0, 52)
		_party_box.add_child(card)
		var margin := MarginContainer.new()
		margin.theme_type_variation = "BattlePartyMargin"
		card.add_child(margin)
		var row := HBoxContainer.new()
		row.theme_type_variation = "BattlePartyRow"
		margin.add_child(row)
		var marker := Label.new()
		marker.text = "▶" if actor == Battle.current_ally() and actor.is_alive() else "·"
		marker.custom_minimum_size = Vector2(12, 0)
		marker.theme_type_variation = "EyebrowLabel"
		row.add_child(marker)
		var name_stack := VBoxContainer.new()
		name_stack.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		row.add_child(name_stack)
		var name_label := Label.new()
		name_label.text = actor.display_name.to_upper()
		name_stack.add_child(name_label)
		var member_index := actor.party_index
		var class_name_text := "ACTIVE TURN" if actor == Battle.current_ally() else "READY"
		if member_index >= 0 and member_index < GameState.party.size():
			class_name_text = GameState.party[member_index].char_class.to_upper()
		var role := Label.new()
		role.text = "FALLEN" if not actor.is_alive() else class_name_text
		role.theme_type_variation = "EyebrowLabel"
		name_stack.add_child(role)
		var stat_stack := VBoxContainer.new()
		stat_stack.custom_minimum_size = Vector2(112, 0)
		row.add_child(stat_stack)
		var hp := Label.new()
		hp.text = "HP %d / %d" % [actor.hp, actor.max_hp]
		hp.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
		hp.theme_type_variation = "StatLabel"
		stat_stack.add_child(hp)
		var bar := _make_meter(DS.METER_HEALTH_B)
		bar.max_value = actor.max_hp
		bar.value = actor.hp
		bar.custom_minimum_size = Vector2(112, 8)
		stat_stack.add_child(bar)


func _short_action_text(action: CombatAction, reason: String = "") -> String:
	var text := action.display_name.to_upper()
	if action.soul_cost > 0.0:
		text += "\nSOUL %d" % int(action.soul_cost)
	if not reason.is_empty() and action.kind == CombatAction.Kind.RESOLUTION:
		text += "\nLOCKED"
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
