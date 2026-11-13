extends Screen
## FR-604 character sheet (#100), and since U3 (owner-approved plan, 2026-11-01) the one party
## screen: P opens it. The roster sits on the left. The selected person has two tabs:
## - Summary: condition, DRAMGID attributes, equipped kit, bio, a companion's personal
##   quest (FR-505), injuries, the portrait, the Wheel and perks.
## - Skills: the FR-205 derivation, the #98 point spend and the recent-check log.
## The separate Party screen it replaces repeated the roster with one HP bar and a bio.

const WheelWidgetScript := preload("res://ui/components/wheel_widget.gd")
const PartyMemberVisualsScript := preload("res://actors/party_followers/party_member_visuals.gd")
const TreatmentNoticeScene := preload("res://ui/components/treatment_notice.tscn")
const TreatmentNoticeScript := preload("res://ui/components/treatment_notice.gd")
const InventoryScreenScript := preload("res://ui/screens/inventory.gd")

const TAB_SUMMARY := &"summary"
const TAB_SKILLS := &"skills"

var _member_list: ItemList
var _sheet_header: VBoxContainer
var _tab_row: HBoxContainer
var _tab_buttons: Dictionary = {}
var _sheet_column: VBoxContainer
var _selected_member: PartyMember
var _treatment_notice: TreatmentNoticeScript
## The open tab survives a member switch and the rebuild a purchase or a pick triggers.
var _tab: StringName = TAB_SUMMARY


func _uses_ledger_style() -> bool:
	return true


func _build() -> void:
	_add_opaque_backdrop()
	var vbox := _make_shell_window("Register of Persons")
	_treatment_notice = TreatmentNoticeScene.instantiate() as TreatmentNoticeScript
	vbox.add_child(_treatment_notice)

	var row := HBoxContainer.new()
	row.theme_type_variation = "MirrorPairRow"
	row.size_flags_vertical = Control.SIZE_EXPAND_FILL
	vbox.add_child(row)

	_member_list = ItemList.new()
	_member_list.name = "MemberList"
	_member_list.mouse_default_cursor_shape = Control.CURSOR_POINTING_HAND
	# Wide enough for "Vex the Unbowed" beside its bust; the level moved to the tooltip
	# and the sheet's own identity line, so a long name is no longer cut off.
	_member_list.custom_minimum_size = Vector2(320, 0)
	_member_list.size_flags_vertical = Control.SIZE_EXPAND_FILL
	_member_list.fixed_icon_size = Vector2i(64, 64)
	_member_list.texture_filter = CanvasItem.TEXTURE_FILTER_LINEAR
	row.add_child(_ledger_panel(_member_list, "PartyLedger", true))
	_treatment_notice.dismissed.connect(_member_list.grab_focus)

	var person := VBoxContainer.new()
	person.name = "PersonColumn"
	person.theme_type_variation = "LedgerColumn"
	person.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	person.size_flags_vertical = Control.SIZE_EXPAND_FILL
	row.add_child(_ledger_panel(person, "PersonLedger"))

	_sheet_header = VBoxContainer.new()
	_sheet_header.name = "SheetHeader"
	_sheet_header.theme_type_variation = "JournalEntry"
	person.add_child(_sheet_header)

	_tab_row = HBoxContainer.new()
	_tab_row.name = "SheetTabs"
	_tab_row.theme_type_variation = "LedgerRow"
	person.add_child(_tab_row)
	var group := ButtonGroup.new()
	for tab: StringName in [TAB_SUMMARY, TAB_SKILLS]:
		var button := Button.new()
		button.name = "Tab_%s" % tab
		button.text = "SUMMARY" if tab == TAB_SUMMARY else "SKILLS"
		button.theme_type_variation = "SheetTab"
		button.toggle_mode = true
		button.button_group = group
		button.mouse_default_cursor_shape = Control.CURSOR_POINTING_HAND
		button.pressed.connect(_on_tab_pressed.bind(tab))
		_tab_row.add_child(button)
		_tab_buttons[tab] = button

	var scroll := ScrollContainer.new()
	scroll.follow_focus = true
	scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	scroll.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	scroll.size_flags_vertical = Control.SIZE_EXPAND_FILL
	person.add_child(scroll)

	_sheet_column = VBoxContainer.new()
	_sheet_column.name = "SheetColumn"
	_sheet_column.theme_type_variation = "LedgerColumn"
	_sheet_column.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	scroll.add_child(_sheet_column)

	for member in GameState.party:
		var index := _member_list.add_item(
			member.display_name, PartyMemberVisualsScript.bust_texture(member)
		)
		_member_list.set_item_tooltip(index, "Level %d" % member.level)
	_member_list.item_selected.connect(_on_selected)
	if GameState.party.size() > 0:
		_member_list.select(0)
		_on_selected(0)
	else:
		_tab_row.visible = false
		var empty := Label.new()
		empty.text = "(no party)"
		_sheet_column.add_child(empty)

	_add_back_button(vbox)


func select_member(member_id: String) -> void:
	for index in GameState.party.size():
		if GameState.party[index].id == member_id:
			_member_list.select(index)
			_on_selected(index)
			return


## Opens a tab by id (`&"summary"` / `&"skills"`), for callers that land on a page directly.
func show_tab(tab: StringName) -> void:
	if not _tab_buttons.has(tab):
		return
	_tab = tab
	_apply_tab()


func _on_tab_pressed(tab: StringName) -> void:
	show_tab(tab)


func _apply_tab() -> void:
	for tab: StringName in _tab_buttons:
		(_tab_buttons[tab] as Button).set_pressed_no_signal(tab == _tab)
	var summary := _sheet_column.get_node_or_null("SummaryPage") as Control
	var skills := _sheet_column.get_node_or_null("SkillsPage") as Control
	if summary != null:
		summary.visible = _tab == TAB_SUMMARY
	if skills != null:
		skills.visible = _tab == TAB_SKILLS
	_settle_content(_sheet_column)


func _on_selected(idx: int) -> void:
	if _selected_member != GameState.party[idx]:
		_treatment_notice.clear_notice()
	_selected_member = GameState.party[idx]
	_rebuild_sheet()
	_settle_content(_sheet_column)


func _rebuild_sheet() -> void:
	for box: VBoxContainer in [_sheet_header, _sheet_column]:
		for child in box.get_children():
			box.remove_child(child)
			child.queue_free()
	var member := _selected_member
	if member == null:
		return

	var name_label := Label.new()
	name_label.name = "SheetName"
	name_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	name_label.theme_type_variation = "HeadingLabel"
	name_label.text = (
		"%s, %s" % [member.display_name, member.epithet]
		if not member.epithet.is_empty() else member.display_name
	)
	_sheet_header.add_child(name_label)

	var identity := Label.new()
	identity.name = "SheetIdentity"
	identity.text = "%s  •  %s  •  Level %d" % [member.race, member.char_class, member.level]
	identity.theme_type_variation = "MutedLabel"
	identity.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	_sheet_header.add_child(identity)

	# The Skills tab says when there is something to spend, so the summary need not.
	(_tab_buttons[TAB_SKILLS] as Button).text = (
		"SKILLS  ·  %d TO SPEND" % member.advancement_points
		if member.advancement_points > 0 else "SKILLS"
	)

	var summary := VBoxContainer.new()
	summary.name = "SummaryPage"
	summary.theme_type_variation = "LedgerColumn"
	summary.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_sheet_column.add_child(summary)
	var skills := VBoxContainer.new()
	skills.name = "SkillsPage"
	skills.theme_type_variation = "LedgerColumn"
	skills.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_sheet_column.add_child(skills)

	_build_summary(summary, member)
	_build_skills(skills, member)
	_apply_tab()


func _build_summary(page: VBoxContainer, member: PartyMember) -> void:
	# Two columns: the portrait, the Wheel and the perks stand beside the person's record.
	var body := HBoxContainer.new()
	body.name = "SheetBody"
	body.theme_type_variation = "MirrorPairRow"
	body.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	page.add_child(body)
	var main_column := VBoxContainer.new()
	main_column.name = "SummaryColumn"
	main_column.theme_type_variation = "LedgerColumn"
	main_column.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	body.add_child(main_column)
	var side_column := VBoxContainer.new()
	side_column.theme_type_variation = "LedgerColumn"
	side_column.custom_minimum_size = Vector2(260, 0)
	body.add_child(side_column)
	var portrait_frame := PanelContainer.new()
	portrait_frame.theme_type_variation = "NpcPortraitFrame8"
	portrait_frame.custom_minimum_size = Vector2(256, 256)
	side_column.add_child(portrait_frame)
	var portrait := TextureRect.new()
	portrait.name = "MemberPortrait"
	portrait.texture = PartyMemberVisualsScript.ensure_portrait(member)
	portrait.tooltip_text = member.display_name
	portrait.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	portrait.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	portrait.texture_filter = CanvasItem.TEXTURE_FILTER_LINEAR
	portrait.mouse_filter = Control.MOUSE_FILTER_IGNORE
	portrait_frame.add_child(portrait)

	main_column.add_child(_condition(member))

	# --- Attributes (fixed after creation, owner 2026-08-24) ---
	if not member.attributes.is_empty():
		main_column.add_child(_section("Attributes"))
		var attribute_grid := GridContainer.new()
		attribute_grid.name = "AttributeGrid"
		attribute_grid.columns = 3
		attribute_grid.theme_type_variation = "LedgerGrid"
		for attribute_id: String in DramgidSchema.ATTRIBUTE_IDS:
			var cell := Label.new()
			# attribute_value() answers legacy-keyed rows through the rename aliases
			# until save schema 8 rewrites them.
			cell.text = "%s %d" % [
				DramgidSchema.attribute_label(attribute_id),
				member.attribute_value(StringName(attribute_id)),
			]
			cell.tooltip_text = ChargenData.attribute_hint(attribute_id)
			cell.size_flags_horizontal = Control.SIZE_EXPAND_FILL
			attribute_grid.add_child(cell)
		main_column.add_child(attribute_grid)

	var calling_bits: Array[String] = []
	for pair: Array in [
		["Discipline", member.discipline], ["Background", member.background],
		["Flaw", member.flaw], ["Mastery", member.starting_mastery],
	]:
		if not str(pair[1]).is_empty():
			calling_bits.append("%s: %s" % [pair[0], pair[1]])
	if not calling_bits.is_empty():
		var calling := Label.new()
		calling.name = "Calling"
		calling.text = "  •  ".join(calling_bits)
		calling.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
		calling.theme_type_variation = "MutedLabel"
		main_column.add_child(calling)

	_render_equipped(main_column, member)

	if not member.bio.is_empty():
		var bio := Label.new()
		bio.name = "MemberBio"
		bio.text = member.bio
		bio.theme_type_variation = "QuoteLabel"
		bio.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
		main_column.add_child(bio)

	# FR-505: a companion's personal quest is talked through here; there is no field NPC.
	var quest_button := Button.new()
	quest_button.name = "PersonalQuestButton"
	quest_button.text = "Talk to %s" % member.display_name
	quest_button.visible = not QuestRegistry.companion_quest_dialogue_for(member.id).is_empty()
	quest_button.size_flags_horizontal = Control.SIZE_SHRINK_BEGIN
	quest_button.mouse_default_cursor_shape = Control.CURSOR_POINTING_HAND
	quest_button.pressed.connect(_on_quest_button_pressed)
	main_column.add_child(quest_button)

	# --- Injuries (called-shots 10C): serious records and qualified field treatment ---
	_render_injuries(main_column, member)

	# --- The Wheel (FR-604) ---
	side_column.add_child(_section("The Wheel"))
	var wheel := WheelWidgetScript.new()
	wheel.name = "WheelWidget"
	wheel.set_elements(member.major_element, member.minor_element)
	side_column.add_child(wheel)
	if not member.major_element.is_empty() or not member.minor_element.is_empty():
		var wheel_caption := Label.new()
		wheel_caption.text = "Major: %s   Minor: %s" % [
			member.major_element.capitalize() if not member.major_element.is_empty() else "—",
			member.minor_element.capitalize() if not member.minor_element.is_empty() else "—",
		]
		wheel_caption.modulate = Color(1, 1, 1, 0.6)
		wheel_caption.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
		side_column.add_child(wheel_caption)

	# --- Perks (#285): picks at levels 2 / 4 / 6 ---
	_render_perks(side_column, member)


## HP and Breath as the field HUD shows them: a meter with its exact numbers beside it.
func _condition(member: PartyMember) -> GridContainer:
	var grid := GridContainer.new()
	grid.name = "Condition"
	grid.columns = 3
	grid.theme_type_variation = "LedgerGrid"
	for row: Array in [
		["HP", member.hp, member.max_hp, DS.METER_HEALTH_A, DS.METER_HEALTH_B],
		["Breath", member.breath, member.breath_max, DS.METER_BREATH_A, DS.METER_BREATH_B],
	]:
		var label := Label.new()
		label.text = str(row[0]).to_upper()
		label.theme_type_variation = "EyebrowLabel"
		grid.add_child(label)
		var meter := MeterBar.new()
		meter.name = "%sMeter" % row[0]
		meter.fill_start = row[3]
		meter.fill_end = row[4]
		meter.value = clampf(float(row[1]) / float(row[2]), 0.0, 1.0) if int(row[2]) > 0 else 0.0
		meter.custom_minimum_size.x = 320.0
		meter.size_flags_vertical = Control.SIZE_SHRINK_CENTER
		grid.add_child(meter)
		var numbers := Label.new()
		numbers.name = "%sNumbers" % row[0]
		numbers.text = "%d / %d" % [int(row[1]), int(row[2])]
		numbers.theme_type_variation = "StatLabel"
		grid.add_child(numbers)
	return grid


## What the person carries into a fight. The inventory's equipment rail is the hero's
## (`GameState.equipped_slots`); a class Kit names the ARMS skill it trains.
func _render_equipped(column: VBoxContainer, member: PartyMember) -> void:
	var lines: PackedStringArray = []
	if member.id == GameState.PROTAGONIST_ID:
		for slot_name: StringName in InventoryScreenScript.EQUIPMENT_SLOTS:
			var proto_id := str(GameState.equipped_slots.get(String(slot_name), ""))
			if not proto_id.is_empty():
				lines.append("%s  ·  %s" % [
					String(slot_name).to_upper(),
					ItemLocalization.text(proto_id, "name", proto_id.get_file().capitalize()),
				])
	if not member.kit_weapon_skill.is_empty():
		lines.append("KIT  ·  %s" % DramgidSchema.skill_label(member.kit_weapon_skill))
	if lines.is_empty():
		return
	column.add_child(_section("Equipped"))
	var equipped := Label.new()
	equipped.name = "Equipped"
	equipped.text = "\n".join(lines)
	equipped.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	column.add_child(equipped)


func _build_skills(page: VBoxContainer, member: PartyMember) -> void:
	var points_label := Label.new()
	points_label.name = "AdvancementPoints"
	points_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	points_label.text = (
		"Advancement points: %d   (granted at story milestones)" % member.advancement_points
	)
	page.add_child(points_label)

	# U3: the +5% column only exists while there is a point to spend; with none it was
	# twenty-odd dim buttons offering nothing. Each group is its own block, and the blocks
	# flow side by side, so the whole slate reads without scrolling past one long column.
	var can_spend := member.advancement_points > 0
	var flow := HFlowContainer.new()
	flow.name = "SkillGroups"
	flow.theme_type_variation = "LedgerFlow"
	flow.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	page.add_child(flow)
	for group: String in DramgidSchema.SKILL_GROUPS:
		var group_skills := _listed_skills(group, member)
		if group_skills.is_empty():
			continue
		var block := VBoxContainer.new()
		block.name = "SkillGroupBlock_%s" % group
		block.theme_type_variation = "JournalEntry"
		block.custom_minimum_size.x = 440.0 if can_spend else 300.0
		flow.add_child(block)
		var heading := Label.new()
		heading.name = "SkillGroup_%s" % group
		heading.theme_type_variation = "HeadingLabel"
		heading.text = DramgidSchema.group_label(group)
		block.add_child(heading)
		var skill_grid := GridContainer.new()
		skill_grid.name = "SkillGrid_%s" % group
		skill_grid.columns = 3 if can_spend else 2
		skill_grid.theme_type_variation = "LedgerGrid"
		block.add_child(skill_grid)

		for skill_id: String in group_skills:
			var label := Label.new()
			label.text = DramgidSchema.skill_label(skill_id)
			label.size_flags_horizontal = Control.SIZE_EXPAND_FILL
			skill_grid.add_child(label)

			var effective := SkillCheck.preview(skill_id, member, 0.0)
			var percent_label := Label.new()
			percent_label.name = "Percent_%s" % skill_id
			percent_label.theme_type_variation = "StatLabel"
			percent_label.text = "%d%%" % int(effective)
			# FR-205: the derivation is one hover away, in the ratified formula's own terms.
			percent_label.tooltip_text = _derivation_tooltip(member, skill_id, effective)
			skill_grid.add_child(percent_label)

			if not can_spend:
				continue
			var buy := Button.new()
			buy.name = "Buy_%s" % skill_id
			var cost := Advancement.step_cost(member, skill_id)
			if not Advancement.is_purchasable(member, skill_id):
				# A Tone the member does not hold is not theirs to raise. It only
				# appears here at all when it already carries progress, and then the
				# sheet has to show that progress without offering to add to it.
				buy.text = "not held"
				buy.disabled = true
			elif cost < 0:
				buy.text = "at cap"
				buy.disabled = true
			else:
				buy.text = "+5%%  (%d pt)" % cost
				buy.disabled = not Advancement.can_buy(member, skill_id)
			buy.mouse_default_cursor_shape = Control.CURSOR_POINTING_HAND
			buy.pressed.connect(_on_buy_pressed.bind(skill_id))
			skill_grid.add_child(buy)

	# --- Recent checks (FR-205, toggleable for Archivists) ---
	page.add_child(_section("Recent Checks"))
	var toggle := CheckButton.new()
	toggle.name = "CheckMathToggle"
	toggle.text = "Show check math"
	toggle.button_pressed = bool(GameState.get_setting("interface", "show_check_math", true))
	toggle.toggled.connect(_on_check_math_toggled)
	page.add_child(toggle)
	if toggle.button_pressed:
		var checks := SkillCheck.recent_checks()
		if checks.is_empty():
			var none := Label.new()
			none.text = "(no checks made yet)"
			none.modulate = Color(1, 1, 1, 0.5)
			page.add_child(none)
		else:
			var log_column := VBoxContainer.new()
			log_column.name = "CheckLog"
			page.add_child(log_column)
			for index in range(checks.size() - 1, -1, -1):
				var entry: Dictionary = checks[index]
				var line := Label.new()
				line.text = "%s — %s %d%% — rolled %d — %s%s" % [
					str(entry.get("subject", "")),
					str(entry.get("skill", "")).capitalize(),
					int(entry.get("effective_percent", 0)),
					int(entry.get("roll", 0)),
					"success" if bool(entry.get("success", false)) else "failure",
					"  (Expert reroll)" if bool(entry.get("rerolled", false)) else "",
				]
				line.modulate = (
					Color(1, 1, 1, 0.85) if bool(entry.get("success", false))
					else Color(1, 0.75, 0.75, 0.85)
				)
				line.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
				log_column.add_child(line)


## FR-505: opens the companion's personal-quest dialogue, mirroring how
## actors/npc/npc.gd opens the balloon for a field NPC.
func _on_quest_button_pressed() -> void:
	if _selected_member == null:
		return
	var dialogue_path := QuestRegistry.companion_quest_dialogue_for(_selected_member.id)
	if dialogue_path.is_empty():
		return
	var dialogue := load(dialogue_path) as DialogueResource
	if dialogue == null:
		push_error("Companion '%s' could not load dialogue '%s'." % [_selected_member.id, dialogue_path])
		return
	DialogueManager.show_dialogue_balloon(dialogue, "start")


const PRACTITIONER_REASONS: Array[String] = [
	"unknown_practitioner", "practitioner_down", "unqualified", "practitioner_injured",
]
var _practitioner_picks: Dictionary = {}
## Explicit practitioner choice per location; survives the rebuild a choice triggers.
var _practitioner_choice: Dictionary = {}
var _choice_owner: PartyMember
var _treatment_status: Label


## One row per serious injury on the sheet's member (the patient), with a practitioner pick
## and a field-treatment button carrying the exact supply cost from `InjuryTreatment.quote`.
## The pick defaults to the first qualified party member so the common case is one press.
func _render_injuries(column: VBoxContainer, patient: PartyMember) -> void:
	var rows := InjuryTreatment.treatable_rows(GameState).filter(
		func(row: Dictionary) -> bool: return row["member"] == patient
	)
	# U3: the summary names injuries only when there are some. The status line stays, hidden,
	# so a treatment receipt still has somewhere to land after the last injury is cured.
	var heading := _section("Injuries")
	heading.name = "InjuriesHeading"
	heading.visible = not rows.is_empty()
	column.add_child(heading)
	_treatment_status = Label.new()
	_treatment_status.name = "TreatmentStatus"
	_treatment_status.visible = false
	_treatment_status.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	_treatment_status.modulate = Color(1, 1, 1, 0.7)
	column.add_child(_treatment_status)
	_practitioner_picks.clear()
	if _selected_member != _choice_owner:
		_practitioner_choice.clear()
		_choice_owner = _selected_member
	if rows.is_empty():
		return
	for row: Dictionary in rows:
		for card_id: String in InjuryTreatment.field_cards():
			_add_injury_row(column, patient, str(row["location"]), row["record"], card_id)


func _add_injury_row(column: VBoxContainer, patient: PartyMember, location: String, record: Dictionary, card_id: String) -> void:
	var card: Dictionary = InjuryTreatment.CARDS[card_id]
	var box := VBoxContainer.new()
	box.name = "Injury_%s" % location
	box.theme_type_variation = "LedgerColumn"
	column.add_child(box)
	var title := Label.new()
	title.name = "InjuryTitle_%s" % location
	title.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	var lifts: Array = InjuryTreatment._restrictions(record)
	title.text = "%s  •  serious  •  %s  •  %s" % [
		location.capitalize(),
		" / ".join(PackedStringArray(lifts)).replace("_", " ") if not lifts.is_empty() else "no listed restriction",
		str(record.get("recovery", "untreated")),
	]
	box.add_child(title)
	var controls := VBoxContainer.new()
	controls.theme_type_variation = "LedgerColumn"
	box.add_child(controls)
	var pick := OptionButton.new()
	pick.name = "Practitioner_%s" % location
	var default_index := -1
	for index in GameState.party.size():
		var candidate: PartyMember = GameState.party[index]
		pick.add_item(candidate.display_name, index)
		# Default to the first candidate who is not refused for a practitioner reason, so a
		# missing supply is reported as a missing supply and not as the patient's own skill.
		var candidate_quote := _field_quote(patient, record, card_id, candidate)
		if default_index < 0 and not PRACTITIONER_REASONS.has(str(candidate_quote.get("blocked_by", ""))):
			default_index = index
	var chosen := int(_practitioner_choice.get(location, -1))
	if chosen < 0 or chosen >= GameState.party.size():
		chosen = maxi(default_index, 0)
	pick.select(chosen)
	pick.item_selected.connect(func(index: int) -> void:
		_practitioner_choice[location] = index
		_rebuild_sheet())
	_practitioner_picks[location] = pick
	controls.add_child(pick)
	var practitioner: PartyMember = GameState.party[pick.selected] if not GameState.party.is_empty() else null
	var quoted := _field_quote(patient, record, card_id, practitioner)
	var supply := str(card["supply_item"])
	var button := Button.new()
	button.name = "FieldTreat_%s" % location
	button.text = "%s\n%d × %s  (carry %d)" % [
		str(card.get("display_name", card_id)), int(card["supply_quantity"]),
		ItemLocalization.text(supply, "name", supply.get_file().capitalize()), GameState.item_count(supply),
	]
	button.disabled = not bool(quoted["allowed"])
	button.pressed.connect(_on_field_treat.bind(patient, location, card_id))
	controls.add_child(button)
	if not bool(quoted["allowed"]):
		var why := Label.new()
		why.name = "InjuryWhy_%s" % location
		why.text = "%s  %s" % [str(quoted.get("message", "")), str(quoted.get("alternative", card.get("alternative", "")))]
		why.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
		why.modulate = Color(1, 0.85, 0.75, 0.85)
		box.add_child(why)


func _field_intent(patient: PartyMember, record: Dictionary, card_id: String, practitioner: PartyMember) -> Dictionary:
	var identity := CombatInjury.record_identity(record)
	return {
		"patient_id": str(patient.id), "instance_id": identity["instance_id"], "revision": identity["revision"],
		"card_id": card_id, "practitioner_id": str(practitioner.id) if practitioner != null else "",
	}


func _field_quote(patient: PartyMember, record: Dictionary, card_id: String, practitioner: PartyMember) -> Dictionary:
	return InjuryTreatment.quote(_field_intent(patient, record, card_id, practitioner), GameState, _combat_active())


func _on_field_treat(patient: PartyMember, location: String, card_id: String) -> void:
	_treatment_notice.clear_notice()
	var record: Dictionary = patient.injuries.get(location, {})
	var pick: OptionButton = _practitioner_picks.get(location)
	var practitioner: PartyMember = GameState.party[pick.selected] if pick != null and pick.selected >= 0 else null
	var intent := _field_intent(patient, record, card_id, practitioner)
	var quoted := InjuryTreatment.quote(intent, GameState, _combat_active())
	if bool(quoted["allowed"]):
		intent["expected_cost"] = quoted["cost"]
	var result := InjuryTreatment.commit(intent, GameState, _combat_active())
	var text := ""
	if bool(result.get("allowed", false)):
		var supply := str(result["paid"]["supply_item"])
		text = "%s treated %s's %s; used %d × %s." % [
			practitioner.display_name if practitioner != null else "Someone", patient.display_name, location,
			int(result["paid"]["supply_quantity"]), ItemLocalization.text(supply, "name", supply.get_file().capitalize()),
		]
	else:
		text = "Treatment refused (%s): %s" % [str(result.get("blocked_by", "")).replace("_", " "), str(result.get("message", ""))]
	_rebuild_sheet()
	if _treatment_status != null:
		_treatment_status.text = text
		_treatment_status.visible = true
	_treatment_notice.show_result(result, patient.display_name)


static func _combat_active() -> bool:
	return Battle.session_active or (Battle.controller != null and not Battle.ended)


## Which skills of one group the sheet lists. Every group shows its whole slate except
## TONES: a member can only ever raise the tones they hold (`Advancement.is_purchasable`),
## so listing all ten would be eight dead rows on most builds. Tones the member already
## has progress in stay listed even when unheld — points already spent must not vanish
## from the sheet just because an element changed.
func _listed_skills(group: String, member: PartyMember) -> PackedStringArray:
	var slate := DramgidSchema.skills_in_group(group)
	if group != DramgidSchema.GROUP_TONES:
		return slate
	var held := Advancement.held_tones(member)
	var listed := PackedStringArray()
	for skill_id: String in slate:
		var trained := str(member.skill_tiers.get(skill_id, "untrained")).to_lower() != "untrained"
		var bought := float(member.skill_percentages.get(skill_id, 0.0)) > 0.0
		if skill_id in held or trained or bought:
			listed.append(skill_id)
	return listed


func _derivation_tooltip(member: PartyMember, skill_id: String, effective: float) -> String:
	var tier := str(member.skill_tiers.get(skill_id, "untrained"))
	var bought := float(member.skill_percentages.get(skill_id, 0.0))
	return (
		"effective %d%% = attribute × 8  +  %s tier bonus  +  %d%% advancement"
		% [int(effective), tier.capitalize(), int(bought)]
	)


## Picked perks first, then the open pick (if any) as one button per offer. A gated capstone
## stays visible with its refusal so the player can see what the ledger would open.
func _render_perks(column: VBoxContainer, member: PartyMember) -> void:
	column.add_child(_section("Perks"))
	var perks_column := VBoxContainer.new()
	perks_column.name = "PerksColumn"
	perks_column.theme_type_variation = "LedgerColumn"
	column.add_child(perks_column)
	if PerkCatalog.for_class(member.class_id).is_empty():
		perks_column.add_child(_perk_label("NoPerks", "(no patron-class perks)", "MutedLabel"))
		return
	for perk: Dictionary in PerkCatalog.picked(member):
		var title := "Lv %d  %s" % [int(perk["level"]), PerkCatalog.display_name(perk)]
		if not PerkCatalog.is_in_play(str(perk["id"])):
			title += "  (planned)"
		perks_column.add_child(_perk_label("Picked_%s" % perk["id"], title, ""))
		perks_column.add_child(_perk_label("", PerkCatalog.blurb(perk), "MutedLabel"))
	var pending := PerkCatalog.pending_level(member)
	if pending == 0:
		var next_level := 0
		for level: int in PerkCatalog.PICK_LEVELS:
			if level > member.level:
				next_level = level
				break
		if next_level > 0:
			perks_column.add_child(
				_perk_label("NextPerk", "Next pick at level %d." % next_level, "MutedLabel")
			)
		return
	perks_column.add_child(
		_perk_label("PerkChoice", "Choose a level-%d perk:" % pending, "HeadingLabel")
	)
	var in_combat := _combat_active()
	for perk: Dictionary in PerkCatalog.offers(member):
		var button := Button.new()
		button.name = "Perk_%s" % perk["id"]
		button.text = PerkCatalog.display_name(perk)
		button.tooltip_text = PerkCatalog.blurb(perk)
		var refusal := PerkCatalog.gate_refusal(perk)
		button.disabled = in_combat or not refusal.is_empty()
		button.mouse_default_cursor_shape = Control.CURSOR_POINTING_HAND
		button.pressed.connect(_on_perk_pressed.bind(str(perk["id"])))
		perks_column.add_child(button)
		var note := PerkCatalog.blurb(perk)
		if not refusal.is_empty():
			note += "  " + refusal
		perks_column.add_child(_perk_label("", note, "MutedLabel"))
	if in_combat:
		perks_column.add_child(
			_perk_label("PerkCombatNote", "Choose after the fight.", "MutedLabel")
		)


func _perk_label(node_name: String, text: String, variation: String) -> Label:
	var label := Label.new()
	if not node_name.is_empty():
		label.name = node_name
	label.text = text
	label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	if not variation.is_empty():
		label.theme_type_variation = variation
	return label


func _on_perk_pressed(perk_id: String) -> void:
	if _selected_member == null:
		return
	var result := PerkCatalog.pick(_selected_member, perk_id)
	if not bool(result.get("allowed", false)):
		return
	_rebuild_sheet()


func _on_buy_pressed(skill_id: String) -> void:
	if _selected_member == null:
		return
	var result := Advancement.buy(_selected_member, skill_id)
	if not bool(result.get("allowed", false)):
		return
	_rebuild_sheet()


func _on_check_math_toggled(pressed: bool) -> void:
	GameState.set_setting("interface", "show_check_math", pressed)
	_rebuild_sheet()
