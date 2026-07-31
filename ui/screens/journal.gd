extends Screen


func _build() -> void:
	var vbox := _make_window("Journal", Vector2(680, 500))
	var active := QuestSystem.get_active_quests()
	if active.is_empty():
		var empty := Label.new()
		empty.text = "No active commissions."
		vbox.add_child(empty)
	else:
		vbox.add_child(_section("Active"))
		for quest in active:
			_add_quest(vbox, quest, false)
	var completed: Array[Quest] = QuestSystem.completed.get_all_quests()
	if not completed.is_empty():
		vbox.add_child(HSeparator.new())
		vbox.add_child(_section("Completed"))
		for quest in completed:
			_add_quest(vbox, quest, true)
	_add_back_button(vbox)


func _add_quest(box: VBoxContainer, quest: Quest, done: bool) -> void:
	var title := Label.new()
	title.text = ("✓ " if done else "◆ ") + quest.quest_name
	title.theme_type_variation = "HeadingLabel"
	box.add_child(title)
	var objective := Label.new()
	objective.text = quest.quest_description if done else QuestRegistry.objective_for(quest)
	objective.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	box.add_child(objective)
