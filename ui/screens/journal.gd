extends Screen
## Journal — a read-only account of quest state and remembered consequences.
## QuestRegistry and the two append-only ledgers remain the authorities; this
## screen only asks their derived read APIs what the world currently knows.

const StandingScreen := preload("res://ui/screens/standing.gd")
const RECENT_CONSEQUENCE_LIMIT := 6


func _uses_ledger_style() -> bool:
	return true


func _build() -> void:
	# Journal reads over the live scene; cover it like every other full-page screen.
	_add_opaque_backdrop()
	var shell := _make_shell_window("Journal")
	# The ledger shell does not scroll on its own; the journal's record can outgrow a page.
	var scroll := ScrollContainer.new()
	scroll.name = "JournalScroll"
	# The first focusable is the Standing button at the foot of the record; following focus
	# would open the journal scrolled past its own thread.
	scroll.follow_focus = false
	scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	scroll.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	scroll.size_flags_vertical = Control.SIZE_EXPAND_FILL
	shell.add_child(_ledger_panel(scroll, "JournalLedger"))
	var vbox := VBoxContainer.new()
	vbox.name = "JournalColumn"
	vbox.theme_type_variation = "LedgerColumn"
	vbox.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	scroll.add_child(vbox)

	# U3: the thread reads like a quest entry, its title and one objective line. It used to
	# carry a "Current thread" header and a "NEXT OBJECTIVE" header over the same two facts.
	vbox.add_child(_section(ChapterOneProgress.title()))
	var next := Label.new()
	next.name = "NextObjective"
	next.text = ChapterOneProgress.objective()
	next.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	vbox.add_child(next)
	var explanation := Label.new()
	explanation.text = "The record changes only when the world does. This page changes nothing."
	explanation.theme_type_variation = "MutedLabel"
	explanation.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	vbox.add_child(explanation)

	var quest_row := HBoxContainer.new()
	quest_row.name = "QuestColumns"
	quest_row.theme_type_variation = "MirrorPairRow"
	quest_row.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	vbox.add_child(quest_row)
	_add_quest_column(quest_row, "ActiveQuests", "Quests in motion", _active_quests(), false)
	_add_quest_column(
		quest_row, "CompletedQuests", "Quests entered", _completed_quests(), true
	)

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
	standing_button.size_flags_horizontal = Control.SIZE_SHRINK_BEGIN
	_add_back_button(shell)


func _add_quest_column(
	row: HBoxContainer,
	column_name: String,
	heading: String,
	quests: Array[Quest],
	completed: bool
) -> void:
	var panel := PanelContainer.new()
	panel.name = column_name + "Panel"
	panel.theme_type_variation = "LedgerInset"
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


## U3: an entry is its title, one objective line and one who/where line. The state shows
## only when it is not ACTIVE (it used to print twice, as a badge and as "STATE · Active"),
## and the authored description waits on the title's tooltip.
func _add_quest(box: VBoxContainer, quest: Quest) -> void:
	var entry := VBoxContainer.new()
	entry.name = "Quest%d" % quest.id
	entry.theme_type_variation = "JournalEntry"
	entry.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	box.add_child(entry)

	var head := HBoxContainer.new()
	head.theme_type_variation = "LedgerRow"
	entry.add_child(head)
	var title := Label.new()
	title.name = "QuestTitle"
	title.text = quest.quest_name
	title.theme_type_variation = "HeadingLabel"
	title.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	title.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	title.tooltip_text = quest.quest_description
	title.mouse_filter = Control.MOUSE_FILTER_PASS
	head.add_child(title)
	var state := quest_state(quest)
	if state != "ACTIVE":
		var state_label := Label.new()
		state_label.name = "QuestState"
		state_label.text = state
		state_label.theme_type_variation = (
			"PositiveLabel" if state == "READY TO REPORT" else "MutedLabel"
		)
		head.add_child(state_label)

	var objective := Label.new()
	objective.name = "QuestObjective"
	objective.text = QuestRegistry.objective_for(quest)
	objective.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	entry.add_child(objective)

	var context := Label.new()
	context.name = "QuestContext"
	context.text = "%s  ·  %s" % [quest_giver(quest), quest_location(quest)]
	context.theme_type_variation = "EyebrowLabel"
	context.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	entry.add_child(context)


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
	# Dom side quests name their giver by NPC stable id rather than repeating the
	# display name, so resolve through the authored roster — one source of truth
	# for who a person is. Checked before FlagQuest because DomSideQuest extends it.
	if quest is DomSideQuest:
		var dom_quest := quest as DomSideQuest
		var row := NpcRoster.get_npc(dom_quest.giver_actor_id)
		if not row.is_empty():
			return str(row.get("display_name", "Unentered"))
	if quest is FlagQuest:
		var flag_quest := quest as FlagQuest
		return flag_quest.quest_giver if not flag_quest.quest_giver.is_empty() else "Unentered"
	if quest is FetchQuest:
		var fetch_quest := quest as FetchQuest
		return fetch_quest.quest_giver if not fetch_quest.quest_giver.is_empty() else "Unentered"
	return "Unentered"


static func quest_location(quest: Quest) -> String:
	if quest is DomSideQuest:
		var dom_quest := quest as DomSideQuest
		var row := NpcRoster.get_npc(dom_quest.giver_actor_id)
		if not row.is_empty():
			# Where the giver is found: their building if they have one, else their district.
			var home := str(row.get("home", ""))
			if not home.is_empty():
				return home
			var district := str(row.get("district", ""))
			if not district.is_empty():
				return district
	if quest is FlagQuest:
		var flag_quest := quest as FlagQuest
		return flag_quest.quest_location if not flag_quest.quest_location.is_empty() else "Unentered"
	if quest is FetchQuest:
		var fetch_quest := quest as FetchQuest
		return fetch_quest.quest_location if not fetch_quest.quest_location.is_empty() else "Unentered"
	return "Unentered"


func _active_quests() -> Array[Quest]:
	var quests: Array[Quest] = []
	for quest: Quest in QuestRegistry.all_quests():
		if QuestRegistry.is_active(quest):
			quests.append(quest)
	quests.sort_custom(_quest_name_before)
	return quests


func _completed_quests() -> Array[Quest]:
	var quests: Array[Quest] = []
	for quest: Quest in QuestRegistry.all_quests():
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
