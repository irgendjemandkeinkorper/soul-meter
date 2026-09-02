extends CanvasLayer
## Field HUD — the bottom bar. Per the DS layout rules: pinned to the bottom edge with a
## 2px bronze top rule; the SoulGauge is always the rightmost element in it.


func _ready() -> void:
	var bar: Control = $Bar
	bar.theme = UIManager.ui_theme  # CanvasLayer children don't inherit the root Window theme
	bar.draw.connect(
		func() -> void:
			# the 2px bronze top rule
			bar.draw_rect(Rect2(0, 0, bar.size.x, DS.BORDER_TRIM_W), DS.BRONZE_1)
			# stone fill under the bar, slightly scrimmed so the field reads through
			bar.draw_rect(
				Rect2(0, DS.BORDER_TRIM_W, bar.size.x, bar.size.y), Color(DS.STONE_0, 0.82)
			)
	)
	bar.queue_redraw()
	# The objective is two lines when a destination is set — lay the bar out as a
	# column (right edge reserved for the SoulGauge) instead of absolute positions,
	# so the second objective line can never sit on top of the party readout.
	var column := VBoxContainer.new()
	column.name = "BarColumn"
	column.set_anchors_preset(Control.PRESET_FULL_RECT)
	column.offset_left = 24.0
	column.offset_top = float(DS.BORDER_TRIM_W) + 6.0
	column.offset_right = -270.0
	column.offset_bottom = -4.0
	column.add_theme_constant_override("separation", 2)
	column.mouse_filter = Control.MOUSE_FILTER_IGNORE
	bar.add_child(column)
	var objective := Label.new()
	objective.name = "Objective"
	objective.theme_type_variation = "HUDLabel"
	objective.text_overrun_behavior = TextServer.OVERRUN_TRIM_ELLIPSIS
	column.add_child(objective)
	var party_status := Label.new()
	party_status.name = "PartyStatus"
	party_status.theme_type_variation = "StatLabel"
	party_status.text_overrun_behavior = TextServer.OVERRUN_TRIM_ELLIPSIS
	column.add_child(party_status)

	var tutorial := Label.new()
	tutorial.name = "Tutorial"
	tutorial.position = Vector2(24, 20)
	tutorial.size = Vector2(760, 72)
	tutorial.theme_type_variation = "EyebrowLabel"
	tutorial.text = (
		"WASD  MOVE    SHIFT  SPRINT    E  INTERACT    I  INVENTORY    P  PARTY    "
		+ "Q  JOURNAL    R  STANDINGS    ESC  PAUSE"
	)
	add_child(tutorial)

	var autosave := Label.new()
	autosave.name = "AutosaveStatus"
	autosave.set_anchors_preset(Control.PRESET_TOP_RIGHT)
	autosave.position = Vector2(-310, 20)
	autosave.size = Vector2(280, 30)
	autosave.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
	autosave.theme_type_variation = "EyebrowLabel"
	autosave.focus_mode = Control.FOCUS_NONE
	autosave.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(autosave)
	QuestSystem.quest_accepted.connect(
		func(quest: Quest) -> void:
			_bind_quest(quest, objective)
			_refresh_objective(objective)
	)
	QuestSystem.quest_completed.connect(func(_quest: Quest) -> void: _refresh_objective(objective))
	GameState.flag_changed.connect(
		func(_flag: String, _value: Variant) -> void: _refresh_objective(objective)
	)
	GameState.party_changed.connect(
		func() -> void:
			_refresh_objective(objective)
			_refresh_party(party_status)
	)
	SaveGame.autosave_finished.connect(
		func(_reason: String, succeeded: bool) -> void:
			autosave.text = "AUTOSAVED" if succeeded else "AUTOSAVE FAILED"
			_fade_status(autosave)
	)
	for quest in QuestSystem.get_active_quests():
		_bind_quest(quest, objective)
	_refresh_objective(objective)
	_refresh_party(party_status)


func _bind_quest(quest: Quest, label: Label) -> void:
	if not quest.updated.is_connected(_refresh_objective.bind(label)):
		quest.updated.connect(_refresh_objective.bind(label))


func _refresh_objective(label: Label) -> void:
	var text := "NEXT OBJECTIVE  ·  %s  —  %s" % [
		ChapterOneProgress.title(), ChapterOneProgress.objective()
	]
	var destination := ChapterOneProgress.destination()
	if not destination.is_empty():
		text += "\nGO TO  ·  " + destination
	var action_hint := ChapterOneProgress.action_hint()
	if not action_hint.is_empty():
		text += "  ·  " + action_hint
	label.text = text


func _refresh_party(label: Label) -> void:
	var rows: PackedStringArray = []
	for member in GameState.party:
		rows.append(
			"%s  HP %d/%d  BREATH %d/%d"
			% [member.display_name, member.hp, member.max_hp, member.breath, member.breath_max]
		)
	label.text = "   •   ".join(rows)


func _fade_status(label: Label) -> void:
	label.modulate.a = 1.0
	var tween := create_tween()
	tween.tween_interval(1.5)
	tween.tween_property(label, "modulate:a", 0.0, 0.5)
