extends Screen
## Journal — a read-only account of quest state and remembered consequences.
## QuestRegistry and the two append-only ledgers remain the authorities; this
## screen only asks their derived read APIs what the world currently knows.

const StandingScreen := preload("res://ui/screens/standing.gd")
const RECENT_CONSEQUENCE_LIMIT := 6


func _build() -> void:
	var vbox := _make_window("Journal", Vector2(920, 620))

	var thread := _section("Current thread  ·  " + ChapterOneProgress.title())
	vbox.add_child(thread)
	var next := Label.new()
	next.name = "NextObjective"
	next.text = "NEXT OBJECTIVE\n" + ChapterOneProgress.objective()
	next.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	next.theme_type_variation = "HeadingLabel"
	vbox.add_child(next)
	var explanation := Label.new()
	explanation.text = "The record changes only when the world does. This page changes nothing."
	explanation.theme_type_variation = "MutedLabel"
	explanation.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	vbox.add_child(explanation)
	vbox.add_child(HSeparator.new())

	var quest_row := HBoxContainer.new()
	quest_row.name = "QuestColumns"
	quest_row.theme_type_variation = "MirrorPairRow"
	quest_row.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	vbox.add_child(quest_row)
	_add_quest_column(quest_row, "ActiveQuests", "Quests in motion", _active_quests(), false)
	_add_quest_column(
		quest_row, "CompletedQuests", "Quests entered", _completed_quests(), true
	)

	vbox.add_child(HSeparator.new())
	vbox.add_child(_section("What the world remembers"))
	var consequence_note := Label.new()
	consequence_note.text = (
		"The newest entries from faction standing, Renown, and Infamy — "
		+ "what changed, why it changed, and where it was entered."
	)
	consequence_note.theme_type_variation = "MutedLabel"
	consequence_note.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	vbox.add_child(consequence_note)

	var recent := VBoxContainer.new()
	recent.name = "RecentConsequences"
	recent.theme_type_variation = "LedgerHistory"
	recent.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	vbox.add_child(recent)
	_add_recent_consequences(recent)

	var standing_button := _menu_button(
		vbox, "Standing and every recorded reason", _open_standing
	)
	standing_button.name = "OpenStandingButton"
	standing_button.theme_type_variation = "BronzeButton"
	_add_back_button(vbox)


func _add_quest_column(
	row: HBoxContainer,
	column_name: String,
	heading: String,
	quests: Array[Quest],
	completed: bool
) -> void:
	var panel := PanelContainer.new()
	panel.name = column_name + "Panel"
	panel.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	panel.size_flags_stretch_ratio = 1.0
	row.add_child(panel)

	var column := VBoxContainer.new()
	column.name = column_name
	column.theme_type_variation = "LedgerColumn"
	column.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	panel.add_child(column)
	column.add_child(_section(heading))

	if quests.is_empty():
		var empty := Label.new()
		empty.text = (
			"Nothing has been completed yet."
			if completed
			else "No active commissions. Follow the next objective above."
		)
		empty.theme_type_variation = "MutedLabel"
		empty.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
		column.add_child(empty)
		return

	for quest: Quest in quests:
		_add_quest(column, quest)


func _add_quest(box: VBoxContainer, quest: Quest) -> void:
	var entry := VBoxContainer.new()
	entry.name = "Quest%d" % quest.id
	entry.theme_type_variation = "LedgerColumn"
	entry.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	box.add_child(entry)

	var state := quest_state(quest)
	var state_label := Label.new()
	state_label.text = state
	state_label.theme_type_variation = (
		"PositiveLabel" if state == "ACTIVE" or state == "READY TO REPORT" else "MutedLabel"
	)
	entry.add_child(state_label)

	var title := Label.new()
	title.text = quest.quest_name
	title.theme_type_variation = "HeadingLabel"
	title.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	entry.add_child(title)

	var objective := Label.new()
	objective.text = "OBJECTIVE  ·  " + QuestRegistry.objective_for(quest)
	objective.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	entry.add_child(objective)

	var context := Label.new()
	context.text = "GIVEN BY  ·  %s\nWHERE  ·  %s\nSTATE  ·  %s" % [
		quest_giver(quest), quest_location(quest), state.capitalize()
	]
	context.theme_type_variation = "EyebrowLabel"
	context.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	entry.add_child(context)

	var description := Label.new()
	description.text = quest.quest_description
	description.theme_type_variation = "QuoteLabel"
	description.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	entry.add_child(description)


func _add_recent_consequences(container: VBoxContainer) -> void:
	var rows := recent_consequences(RECENT_CONSEQUENCE_LIMIT)
	if rows.is_empty():
		var empty := Label.new()
		empty.text = "No consequence has yet been entered against your name."
		empty.theme_type_variation = "MutedLabel"
		empty.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
		container.add_child(empty)
		return

	for row: Dictionary in rows:
		var event_label := Label.new()
		event_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
		var event: Variant = row["event"]
		if row["ledger"] == &"faction":
			var reputation_event := event as ReputationEvent
			event_label.text = StandingScreen.format_event(reputation_event)
			event_label.theme_type_variation = StandingScreen.delta_theme_type(
				reputation_event.delta
			)
		else:
			var renown_event := event as RenownEvent
			event_label.text = StandingScreen.format_renown_event(renown_event)
			event_label.theme_type_variation = StandingScreen.delta_theme_type(
				renown_event.delta
			)
		container.add_child(event_label)


func _open_standing() -> void:
	UIManager.open(UIManager.STANDING)


static func recent_consequences(limit: int = RECENT_CONSEQUENCE_LIMIT) -> Array[Dictionary]:
	var rows: Array[Dictionary] = []
	var factions: Array[String] = []
	for faction_value: Variant in Reputation.all_standings().keys():
		factions.append(str(faction_value))
	factions.sort()
	for faction: String in factions:
		for event: ReputationEvent in Reputation.why(faction, limit):
			rows.append(
				{
					"ledger": &"faction",
					"event": event,
					"at": event.at,
					"order": event.order,
					"tie_breaker": faction,
				}
			)
	for kind: StringName in [&"reputation", &"infamy"]:
		for event: RenownEvent in Renown.why(kind, limit):
			rows.append(
				{
					"ledger": &"renown",
					"event": event,
					"at": event.at,
					"order": event.order,
					"tie_breaker": String(kind),
				}
			)
	rows.sort_custom(_recent_before)
	if rows.size() > limit:
		rows.resize(limit)
	return rows


static func quest_state(quest: Quest) -> String:
	if QuestRegistry.is_done(quest):
		return "COMPLETED"
	if QuestRegistry.is_active(quest):
		return "READY TO REPORT" if quest.objective_completed else "ACTIVE"
	return "UNTRACKED"


static func quest_giver(quest: Quest) -> String:
	if quest is FlagQuest:
		var flag_quest := quest as FlagQuest
		return flag_quest.quest_giver if not flag_quest.quest_giver.is_empty() else "Unentered"
	if quest is FetchQuest:
		var fetch_quest := quest as FetchQuest
		return fetch_quest.quest_giver if not fetch_quest.quest_giver.is_empty() else "Unentered"
	return "Unentered"


static func quest_location(quest: Quest) -> String:
	if quest is FlagQuest:
		var flag_quest := quest as FlagQuest
		return flag_quest.quest_location if not flag_quest.quest_location.is_empty() else "Unentered"
	if quest is FetchQuest:
		var fetch_quest := quest as FetchQuest
		return fetch_quest.quest_location if not fetch_quest.quest_location.is_empty() else "Unentered"
	return "Unentered"


func _active_quests() -> Array[Quest]:
	var quests: Array[Quest] = []
	for quest: Quest in QuestRegistry.ALL_QUESTS:
		if QuestRegistry.is_active(quest):
			quests.append(quest)
	quests.sort_custom(_quest_name_before)
	return quests


func _completed_quests() -> Array[Quest]:
	var quests: Array[Quest] = []
	for quest: Quest in QuestRegistry.ALL_QUESTS:
		if QuestRegistry.is_done(quest):
			quests.append(quest)
	quests.sort_custom(_quest_name_before)
	return quests


static func _quest_name_before(left: Quest, right: Quest) -> bool:
	return left.quest_name.naturalnocasecmp_to(right.quest_name) < 0


static func _recent_before(left: Dictionary, right: Dictionary) -> bool:
	var left_at := int(left["at"])
	var right_at := int(right["at"])
	if left_at != right_at:
		return left_at > right_at
	var left_order := int(left["order"])
	var right_order := int(right["order"])
	if left_order != right_order:
		return left_order > right_order
	return str(left["tie_breaker"]) < str(right["tie_breaker"])
