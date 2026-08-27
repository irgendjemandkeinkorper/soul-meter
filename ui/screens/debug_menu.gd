extends Screen
## Playtest god mode. Debug builds only (the pause-menu entry is gated on
## OS.is_debug_build()). Every quest skip routes through
## QuestRegistry.debug_force_complete(), which grants what the quest still
## needs and then runs the same resolver real play uses — the resulting save
## is indistinguishable from an earned one.

var _content: VBoxContainer
var _status: Label


func _build() -> void:
	_add_opaque_backdrop()
	_content = _make_shell_window("Debug — Playtest Tools")
	_refresh()


func _refresh() -> void:
	for child in _content.get_children():
		child.queue_free()

	_status = Label.new()
	_status.name = "DebugStatus"
	_status.theme_type_variation = "EyebrowLabel"
	_status.text = (
		"GP %d  ·  SOUL %d  ·  RENOWN %d  ·  INFAMY %d"
		% [GameState.gp, int(GameState.soul_meter), int(Renown.reputation()), int(Renown.infamy())]
	)
	_content.add_child(_status)

	_content.add_child(_section("State"))
	var state_row := HBoxContainer.new()
	_content.add_child(state_row)
	_menu_button(state_row, "GP +500", func() -> void:
		GameState.earn_gp(500)
		_refresh())
	_menu_button(state_row, "Soul → 50", func() -> void:
		GameState.set_soul_meter(50.0)
		_refresh())
	_menu_button(state_row, "Renown +10", func() -> void:
		Renown.gain_reputation("player", 10.0, "Playtest grant", "debug")
		_refresh())
	var item_row := HBoxContainer.new()
	_content.add_child(item_row)
	_menu_button(item_row, "Grant 1× every item", func() -> void:
		for item_id: String in _all_item_ids():
			GameState.inventory.create_and_add_item(item_id)
		_refresh())
	_menu_button(item_row, "Loamroot Sprig +3", func() -> void:
		for _i in 3:
			GameState.inventory.create_and_add_item(ItemIds.MATERIALS_LOAMROOT_SPRIG)
		_refresh())

	_content.add_child(_section("Quests"))
	var complete_all := _menu_button(_content, "Complete every remaining quest", func() -> void:
		var completed := 0
		for quest: Quest in QuestRegistry.ALL_QUESTS:
			if QuestRegistry.debug_force_complete(quest):
				completed += 1
		_refresh())
	complete_all.name = "CompleteAllQuests"
	for quest: Quest in QuestRegistry.ALL_QUESTS:
		_add_quest_row(quest)

	_add_back_button(_content)


func _add_quest_row(quest: Quest) -> void:
	var row := HBoxContainer.new()
	row.name = "QuestRow%d" % quest.id
	_content.add_child(row)
	var label := Label.new()
	label.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	var state := "—"
	if QuestRegistry.is_done(quest):
		state = "DONE"
	elif QuestRegistry.is_active(quest):
		state = "ACTIVE"
	label.text = "%s  [%s]" % [quest.quest_name, state]
	row.add_child(label)
	if not QuestRegistry.is_done(quest):
		var button := _menu_button(row, "Force complete", func() -> void:
			QuestRegistry.debug_force_complete(quest)
			_refresh())
		button.name = "ForceComplete%d" % quest.id


func _all_item_ids() -> Array[String]:
	var ids: Array[String] = []
	var constants := (ItemIds as Script).get_script_constant_map()
	for value: Variant in constants.values():
		if value is String:
			ids.append(value)
	return ids
