extends Screen
## Battle screen — menu-driven Attack/Defend/Flee against Battle's current
## encounter. Opened by GameFlow as a flow-owned, paused overlay (see
## game_flow.gd's Battle state handlers), the same way Pause is.

var _player_lbl: Label
var _player_bar: ProgressBar
var _enemy_lbl: Label
var _enemy_bar: ProgressBar
var _log_lbl: Label
var _actions_box: VBoxContainer
var _outcome_box: VBoxContainer


func _build() -> void:
	var vbox := _make_window("Battle: %s" % Battle.enemy.display_name, Vector2(560, 420))

	_player_lbl = Label.new()
	vbox.add_child(_player_lbl)
	_player_bar = ProgressBar.new()
	_player_bar.show_percentage = false
	_player_bar.custom_minimum_size = Vector2(0, 18)
	vbox.add_child(_player_bar)

	vbox.add_child(HSeparator.new())

	_enemy_lbl = Label.new()
	vbox.add_child(_enemy_lbl)
	_enemy_bar = ProgressBar.new()
	_enemy_bar.show_percentage = false
	_enemy_bar.custom_minimum_size = Vector2(0, 18)
	vbox.add_child(_enemy_bar)

	vbox.add_child(HSeparator.new())

	_log_lbl = Label.new()
	_log_lbl.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	_log_lbl.custom_minimum_size = Vector2(0, 40)
	vbox.add_child(_log_lbl)

	_actions_box = VBoxContainer.new()
	vbox.add_child(_actions_box)
	_menu_button(_actions_box, "Attack", func() -> void:
		_log_lbl.text = "%s attacks!" % _player_name()
		Battle.player_attack())
	_menu_button(_actions_box, "Defend", func() -> void:
		_log_lbl.text = "%s braces for the next blow." % _player_name()
		Battle.player_defend())
	_menu_button(_actions_box, "Flee", func() -> void:
		_log_lbl.text = "%s flees!" % _player_name()
		Battle.flee())

	_outcome_box = VBoxContainer.new()
	_outcome_box.visible = false
	vbox.add_child(_outcome_box)

	Battle.turn_resolved.connect(_refresh)
	Battle.battle_ended.connect(_on_battle_ended)

	_refresh()


func _player_name() -> String:
	return Battle.player.display_name if Battle.player else "You"


func _refresh() -> void:
	if Battle.player == null or Battle.enemy == null:
		return
	_player_lbl.text = "%s   HP  %d / %d" % [Battle.player.display_name, Battle.player.hp, Battle.player.max_hp]
	_player_bar.max_value = Battle.player.max_hp
	_player_bar.value = Battle.player.hp
	_enemy_lbl.text = "%s   HP  %d / %d" % [Battle.enemy.display_name, Battle.enemy.hp, Battle.enemy.max_hp]
	_enemy_bar.max_value = Battle.enemy.max_hp
	_enemy_bar.value = Battle.enemy.hp


func _on_battle_ended(won: bool, fled: bool) -> void:
	_refresh()
	_actions_box.visible = false

	if won:
		_log_lbl.text = "%s is defeated." % Battle.enemy.display_name
		if not Battle.enemy.defeated_flag.is_empty():
			GameState.set_flag(Battle.enemy.defeated_flag, true)
	elif fled:
		_log_lbl.text = "You disengage and fall back."
	else:
		_log_lbl.text = "%s falls. The fight is over." % _player_name()

	_outcome_box.visible = true
	_menu_button(_outcome_box, "Continue", func() -> void:
		GameFlow.send_event("battle_end"))
