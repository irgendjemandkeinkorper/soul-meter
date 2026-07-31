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
	var objective := Label.new()
	objective.name = "Objective"
	objective.position = Vector2(24, 12)
	objective.size = Vector2(1050, 30)
	objective.theme_type_variation = "HUDLabel"
	bar.add_child(objective)
	var party_status := Label.new()
	party_status.name = "PartyStatus"
	party_status.position = Vector2(24, 43)
	party_status.size = Vector2(1300, 28)
	party_status.theme_type_variation = "StatLabel"
	bar.add_child(party_status)

	var tutorial := Label.new()
	tutorial.name = "Tutorial"
	tutorial.position = Vector2(24, 20)
	tutorial.size = Vector2(760, 72)
	tutorial.theme_type_variation = "EyebrowLabel"
	tutorial.text = (
		"WASD  MOVE    E  INTERACT    I  INVENTORY    P  PARTY    "
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
	label.text = "%s  —  %s" % [ChapterOneProgress.title(), ChapterOneProgress.objective()]


func _refresh_party(label: Label) -> void:
	var rows: PackedStringArray = []
	for member in GameState.party:
		rows.append("%s  %d/%d" % [member.display_name, member.hp, member.max_hp])
	label.text = "   •   ".join(rows)


func _fade_status(label: Label) -> void:
	label.modulate.a = 1.0
	var tween := create_tween()
	tween.tween_interval(1.5)
	tween.tween_property(label, "modulate:a", 0.0, 0.5)
