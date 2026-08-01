extends Screen


func _build() -> void:
	var vbox := _make_window("Journal", Vector2(720, 560))
	var thread := _section("Current thread  ·  " + ChapterOneProgress.title())
	vbox.add_child(thread)
	var next := Label.new()
	next.text = "NEXT OBJECTIVE\n" + ChapterOneProgress.objective()
	next.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	next.theme_type_variation = "HeadingLabel"
	vbox.add_child(next)
	var explanation := Label.new()
	explanation.text = "The objective is derived from the facts the world currently remembers."
	explanation.theme_type_variation = "MutedLabel"
	explanation.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	vbox.add_child(explanation)
	vbox.add_child(HSeparator.new())
	var active: Array[Quest] = QuestSystem.get_active_quests()
	if active.is_empty():
		var empty := Label.new()
		empty.text = "No active commissions. Follow the next objective above."
		vbox.add_child(empty)
	else:
		vbox.add_child(_section("Active commissions"))
		for quest in active:
			_add_quest(vbox, quest, false)
	var completed: Array[Quest] = QuestSystem.completed.get_all_quests()
	if not completed.is_empty():
		vbox.add_child(HSeparator.new())
		vbox.add_child(_section("Completed — consequences recorded"))
		for quest in completed:
			_add_quest(vbox, quest, true)
	_add_back_button(vbox)


func _add_quest(box: VBoxContainer, quest: Quest, done: bool) -> void:
	var title := Label.new()
	title.text = ("✓ " if done else "◆ ") + quest.quest_name
	title.theme_type_variation = "HeadingLabel"
	box.add_child(title)
	var objective := Label.new()
	objective.text = (
		quest.quest_description
		if done
		else "CURRENT STEP  ·  " + QuestRegistry.objective_for(quest)
	)
	objective.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	box.add_child(objective)
