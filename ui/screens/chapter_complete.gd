extends Screen
## Offline playtest handoff and chapter consequence ledger.

var _summary := ""


func _build() -> void:
	allow_back = false
	var vbox := _make_window("Chapter One Complete — The Broken Muster", Vector2(820, 700))
	var verdict := Label.new()
	verdict.text = _verdict_text()
	verdict.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	verdict.theme_type_variation = "QuoteLabel"
	vbox.add_child(verdict)

	var ledger := Label.new()
	ledger.text = _ledger_text()
	ledger.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	ledger.theme_type_variation = "StatLabel"
	vbox.add_child(ledger)

	vbox.add_child(_section("Dom threads carried into the ruling"))
	var side_ledger := Label.new()
	side_ledger.name = "SideQuestLedger"
	side_ledger.text = _side_quest_ledger_text()
	side_ledger.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	side_ledger.theme_type_variation = "QuoteLabel"
	vbox.add_child(side_ledger)

	vbox.add_child(_section("Playtest handoff"))
	_summary = _playtest_summary()
	var summary_box := TextEdit.new()
	summary_box.text = _summary
	summary_box.editable = false
	summary_box.custom_minimum_size = Vector2(0, 150)
	summary_box.wrap_mode = TextEdit.LINE_WRAPPING_BOUNDARY
	vbox.add_child(summary_box)
	_menu_button(
		vbox, "Copy Playtest Summary", func() -> void: DisplayServer.clipboard_set(_summary)
	)

	var prompts := Label.new()
	prompts.text = (
		"AFTER PLAYING\n"
		+ "1. Where did the next objective become unclear?\n"
		+ "2. Which combat choice felt most meaningful, and why?\n"
		+ "3. What stopped this from feeling ready for another 20 minutes?"
	)
	prompts.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	vbox.add_child(prompts)

	var continue_button := _menu_button(vbox, "Continue Exploring — Open Loamroot", _continue)
	continue_button.theme_type_variation = "BronzeButton"
	_menu_button(vbox, "Return to Title", _return_to_title)


func _continue() -> void:
	GameState.set_flag("chapter_one_free_roam", true)
	SaveGame.request_checkpoint(SaveGame.Checkpoint.FREE_ROAM_UNLOCK)
	GameFlow.send_event("continue_exploring")


func _return_to_title() -> void:
	SaveGame.save()
	GameFlow.send_event("to_main_menu")


func _ledger_text() -> String:
	var companion_names: PackedStringArray = []
	for companion in GameState.companions():
		companion_names.append(companion.display_name)
	return (
		"COMPANY  Vex + %s\n" % " + ".join(companion_names)
		+ "BLOODBELLOW  %s\n" % _outcome_label()
		+ "RULING  %s\n" % _ruling_label()
		+ "SOUL  %d / 100\n" % roundi(GameState.soul_meter)
		+ (
			"IRON COMPANIES  %+d    IRONBRAND SENTINELS  %+d\n"
			% [
				roundi(Reputation.standing("iron-companies")),
				roundi(Reputation.standing("ironbrand-sentinels")),
			]
		)
		+ "ELAPSED  %s" % _format_time(SaveGame.elapsed_seconds())
	)


func _verdict_text() -> String:
	return "%s %s" % [_outcome_sentence(), _ruling_sentence()]


func _side_quest_ledger_text() -> String:
	var completed := QuestRegistry.completed_side_quests()
	var lines := PackedStringArray(
		[
			"RESOLVED  %d / %d"
			% [completed.size(), QuestRegistry.DOM_SIDE_QUESTS.size()]
		]
	)
	if completed.is_empty():
		lines.append("No Dom side commission was resolved before the road ruling.")
	else:
		for quest: DomSideQuest in completed:
			lines.append(
				"%s  ·  %s" % [quest.quest_name.to_upper(), QuestRegistry.side_quest_readback(quest)]
			)
	var active := QuestRegistry.active_side_quests()
	if not active.is_empty():
		lines.append("OPEN THREADS")
		for quest: DomSideQuest in active:
			lines.append("%s  ·  %s" % [quest.quest_name.to_upper(), QuestRegistry.objective_for(quest)])
	return "\n".join(lines)


func _outcome_label() -> String:
	match str(GameState.get_flag("dorthkor_muster_outcome", "slain")):
		"named":
			return "BINDING NAMED AND BROKEN"
		"released":
			return "BOUND SOLDIER RELEASED"
	return "DESTROYED BY FORCE"


func _outcome_sentence() -> String:
	match str(GameState.get_flag("dorthkor_muster_outcome", "slain")):
		"named":
			return "Vex spoke the stolen muster-name and broke the binding."
		"released":
			return "Vex held the field at equilibrium long enough to release the bound soldier."
	return "Vex ended the Mustered Bloodbellow by force."


func _ruling_label() -> String:
	match str(GameState.get_flag("chapter_one_resolution", "")):
		"demons-first":
			return "FORTIFY THE DEMON ROAD"
		"dead-first":
			return "SENTINELS TAKE COMMAND"
		"hold-both":
			return "HOLD BOTH LINES"
	return "UNRECORDED"


func _ruling_sentence() -> String:
	match str(GameState.get_flag("chapter_one_resolution", "")):
		"demons-first":
			return "Coiljaw turns Dom's shield toward the Breach first."
		"dead-first":
			return "The Ironbrand Sentinels take the deeper investigation."
		"hold-both":
			return "Dom accepts the cost of holding both fronts."
	return ""


func _playtest_summary() -> String:
	return (
		"Soul Meter prototype complete | Company: %s | Bloodbellow: %s | Ruling: %s | Soul: %d | Time: %s"
		% [
			_ledger_company(),
			_outcome_label(),
			_ruling_label(),
			roundi(GameState.soul_meter),
			_format_time(SaveGame.elapsed_seconds()),
		]
	)


func _ledger_company() -> String:
	var names: PackedStringArray = [GameState.PROTAGONIST_NAME]
	for companion in GameState.companions():
		names.append(companion.display_name)
	return ", ".join(names)


func _format_time(seconds: int) -> String:
	return "%02d:%02d" % [seconds / 60, seconds % 60]
