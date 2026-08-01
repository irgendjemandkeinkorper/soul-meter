extends Screen
## Party combat view. Battle owns the rules; this screen only renders state
## and submits action IDs.

var _party_lbl: Label
var _enemy_lbl: Label
var _balance_lbl: Label
var _balance_bar: ProgressBar
var _log_lbl: Label
var _actions_box: VBoxContainer
var _target_button: Button
var _outcome_box: VBoxContainer
var _action_buttons: Array[Button] = []
var _sfx: AudioStreamPlayer

func _build() -> void:
	var vbox := _make_window("Battle", Vector2(680, 560))
	var help := Label.new()
	help.text = (
		"Defining pushes +25 Order. Paradox pushes -25 Chaos. Stabilize pulls 30 toward "
		+ "center. Matching extremes (±60) empower aligned strikes."
	)
	help.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	help.theme_type_variation = "MutedLabel"
	vbox.add_child(help)
	_party_lbl = Label.new()
	_party_lbl.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	vbox.add_child(_party_lbl)
	vbox.add_child(HSeparator.new())
	_enemy_lbl = Label.new()
	_enemy_lbl.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	vbox.add_child(_enemy_lbl)
	vbox.add_child(HSeparator.new())

	_balance_lbl = Label.new()
	_balance_lbl.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	vbox.add_child(_balance_lbl)
	_balance_bar = ProgressBar.new()
	_balance_bar.min_value = Battle.BALANCE_MIN
	_balance_bar.max_value = Battle.BALANCE_MAX
	_balance_bar.show_percentage = false
	_balance_bar.custom_minimum_size = Vector2(0, 22)
	vbox.add_child(_balance_bar)

	_log_lbl = Label.new()
	_log_lbl.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	_log_lbl.custom_minimum_size = Vector2(0, 52)
	vbox.add_child(_log_lbl)

	_actions_box = VBoxContainer.new()
	vbox.add_child(_actions_box)
	_target_button = _menu_button(_actions_box, "", Battle.select_next_enemy)
	for action in Battle.available_actions():
		var button := _menu_button(_actions_box, _action_text(action), _use_action.bind(action.id))
		button.tooltip_text = _action_tooltip(action)
		button.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
		_action_buttons.append(button)
	_menu_button(_actions_box, "Flee", Battle.flee)

	_outcome_box = VBoxContainer.new()
	_outcome_box.visible = false
	vbox.add_child(_outcome_box)
	Battle.turn_resolved.connect(_refresh)
	Battle.balance_changed.connect(func(_value: int) -> void: _refresh())
	Battle.battle_ended.connect(_on_battle_ended)
	_sfx = AudioStreamPlayer.new()
	_sfx.bus = "SFX"
	add_child(_sfx)
	_refresh()


func _use_action(action_id: StringName) -> void:
	if Battle.use_action(action_id):
		_sfx.stream = load("res://assets/kenney/ui/ui-pack/Sounds/tap-a.ogg")
		_sfx.play()


func _refresh() -> void:
	_party_lbl.text = "PARTY\n" + _actor_summary(Battle.allies, Battle.current_ally())
	_enemy_lbl.text = "OPPOSITION\n" + _actor_summary(Battle.enemies)
	var target := Battle.current_target()
	_target_button.text = "Target: %s  (change)" % (target.display_name if target else "None")
	_target_button.disabled = Battle.living_enemies().size() <= 1
	_balance_bar.value = Battle.balance
	_balance_lbl.text = _balance_text()
	_log_lbl.text = Battle.last_message
	var actions := Battle.available_actions()
	for i in _action_buttons.size():
		if i >= actions.size():
			_action_buttons[i].disabled = true
			continue
		var reason := Battle.action_lock_reason(actions[i])
		_action_buttons[i].disabled = not reason.is_empty()
		_action_buttons[i].tooltip_text = _action_tooltip(actions[i], reason)
		_action_buttons[i].text = _action_text(actions[i], reason)


func _action_text(action: CombatAction, reason: String = "") -> String:
	var text := action.display_name + "  —  " + action.summary()
	if not reason.is_empty() and action.kind == CombatAction.Kind.RESOLUTION:
		text += "  —  LOCKED: " + reason
	return text


func _action_tooltip(action: CombatAction, reason: String = "") -> String:
	var text := action.summary()
	if not reason.is_empty():
		text += "\nLocked: " + reason
	return text


func _actor_summary(actors: Array[BattleActor], active: BattleActor = null) -> String:
	var lines: PackedStringArray = []
	for actor in actors:
		var marker := "▶ " if actor == active else "  "
		var state := "FALLEN" if not actor.is_alive() else "%d/%d HP" % [actor.hp, actor.max_hp]
		var affinity := ""
		if actor.balance_affinity < 0:
			affinity = "  [CHAOS-PRESSURED]"
		elif actor.balance_affinity > 0:
			affinity = "  [ORDER-PRESSURED]"
		lines.append("%s%s — %s%s" % [marker, actor.display_name, state, affinity])
	return "\n".join(lines)


func _balance_text() -> String:
	if Battle.balance <= -Battle.EXTREME_THRESHOLD:
		return "CHAOS ASCENDANT   %d" % Battle.balance
	if Battle.balance >= Battle.EXTREME_THRESHOLD:
		return "ORDER ASCENDANT   +%d" % Battle.balance
	return (
		"CHAOS  ←   EQUILIBRIUM %s   →  ORDER"
		% ("+%d" % Battle.balance if Battle.balance > 0 else str(Battle.balance))
	)


func _on_battle_ended(result: BattleResult) -> void:
	_refresh()
	_actions_box.visible = false
	_log_lbl.text = result.message
	if not result.cause.is_empty():
		_log_lbl.text += "\n" + result.cause
	_sfx.stream = load("res://assets/kenney/ui/ui-pack/Sounds/switch-b.ogg")
	_sfx.play()
	_outcome_box.visible = true
	_menu_button(_outcome_box, "Continue", func() -> void: GameFlow.send_event("battle_end"))


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
