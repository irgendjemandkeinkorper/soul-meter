extends Screen
## FR-604 character sheet (#100): identity, attributes, skills with their derivation
## surfaced (FR-205 tooltip + recent-check log), the Wheel widget, and the #98
## advancement point-spend surface. Member list on the left mirrors ui/screens/party.gd.

const WheelWidgetScript := preload("res://ui/components/wheel_widget.gd")
const PartyMemberVisualsScript := preload("res://actors/party_followers/party_member_visuals.gd")

var _member_list: ItemList
var _sheet_column: VBoxContainer
var _selected_member: PartyMember


func _build() -> void:
	_add_opaque_backdrop()
	var vbox := _make_shell_window("Register of Persons")

	var row := HBoxContainer.new()
	row.theme_type_variation = "MirrorPairRow"
	row.size_flags_vertical = Control.SIZE_EXPAND_FILL
	vbox.add_child(row)

	_member_list = ItemList.new()
	_member_list.name = "MemberList"
	_member_list.mouse_default_cursor_shape = Control.CURSOR_POINTING_HAND
	_member_list.custom_minimum_size = Vector2(320, 0)
	_member_list.size_flags_vertical = Control.SIZE_EXPAND_FILL
	_member_list.fixed_icon_size = Vector2i(64, 64)
	_member_list.texture_filter = CanvasItem.TEXTURE_FILTER_LINEAR
	row.add_child(_member_list)

	var scroll := ScrollContainer.new()
	scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	scroll.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	scroll.size_flags_vertical = Control.SIZE_EXPAND_FILL
	row.add_child(scroll)

	_sheet_column = VBoxContainer.new()
	_sheet_column.name = "SheetColumn"
	_sheet_column.theme_type_variation = "LedgerColumn"
	_sheet_column.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	scroll.add_child(_sheet_column)

	for member in GameState.party:
		_member_list.add_item(
			"%s  (Lv %d)" % [member.display_name, member.level],
			PartyMemberVisualsScript.ensure_portrait(member)
		)
	_member_list.item_selected.connect(_on_selected)
	if GameState.party.size() > 0:
		_member_list.select(0)
		_on_selected(0)
	else:
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


func _on_selected(idx: int) -> void:
	_selected_member = GameState.party[idx]
	_rebuild_sheet()


func _rebuild_sheet() -> void:
	for child in _sheet_column.get_children():
		_sheet_column.remove_child(child)
		child.queue_free()
	var member := _selected_member
	if member == null:
		return

	var name_label := Label.new()
	name_label.name = "SheetName"
	name_label.theme_type_variation = "HeadingLabel"
	name_label.text = (
		"%s, %s" % [member.display_name, member.epithet]
		if not member.epithet.is_empty() else member.display_name
	)
	_sheet_column.add_child(name_label)

	var identity := Label.new()
	identity.text = "%s  •  %s  •  Level %d" % [member.race, member.char_class, member.level]
	identity.modulate = Color(1, 1, 1, 0.6)
	_sheet_column.add_child(identity)

	var calling_bits: Array[String] = []
	for pair: Array in [
		["Discipline", member.discipline], ["Background", member.background],
		["Flaw", member.flaw], ["Mastery", member.starting_mastery],
	]:
		if not str(pair[1]).is_empty():
			calling_bits.append("%s: %s" % [pair[0], pair[1]])
	if not calling_bits.is_empty():
		var calling := Label.new()
		calling.text = "  •  ".join(calling_bits)
		calling.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
		calling.modulate = Color(1, 1, 1, 0.6)
		_sheet_column.add_child(calling)

	# Two columns: the wheel sits beside the skills instead of below the fold —
	# on a 1080p sheet the single-column layout cut the wheel at the scroll edge
	# while the right half of the sheet stayed empty.
	var body := HBoxContainer.new()
	body.name = "SheetBody"
	body.add_theme_constant_override("separation", 24)
	body.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_sheet_column.add_child(body)
	var main_column := VBoxContainer.new()
	main_column.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	body.add_child(main_column)
	var side_column := VBoxContainer.new()
	side_column.custom_minimum_size = Vector2(320, 0)
	body.add_child(side_column)
	var portrait_frame := PanelContainer.new()
	portrait_frame.theme_type_variation = "NpcPortraitFrame8"
	portrait_frame.custom_minimum_size = Vector2(256, 256)
	side_column.add_child(portrait_frame)
	var portrait := TextureRect.new()
	portrait.name = "MemberPortrait"
	portrait.texture = PartyMemberVisualsScript.ensure_portrait(member)
	portrait.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	portrait.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	portrait.texture_filter = CanvasItem.TEXTURE_FILTER_LINEAR
	portrait.mouse_filter = Control.MOUSE_FILTER_IGNORE
	portrait_frame.add_child(portrait)

	# --- Attributes (fixed after creation, owner 2026-08-24) ---
	if not member.attributes.is_empty():
		main_column.add_child(_section("Attributes"))
		var attribute_grid := GridContainer.new()
		attribute_grid.columns = DramgidSchema.ATTRIBUTE_IDS.size()
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

	# --- Skills + advancement spend (#98) ---
	main_column.add_child(_section("Skills"))
	var points_label := Label.new()
	points_label.name = "AdvancementPoints"
	points_label.text = (
		"Advancement points: %d   (granted at story milestones)" % member.advancement_points
	)
	main_column.add_child(points_label)

	var skill_grid := GridContainer.new()
	skill_grid.name = "SkillGrid"
	skill_grid.columns = 3
	main_column.add_child(skill_grid)
	for group: String in DramgidSchema.SKILL_GROUPS:
		var group_skills := _listed_skills(group, member)
		if group_skills.is_empty():
			continue
		var heading := Label.new()
		heading.name = "SkillGroup_%s" % group
		heading.theme_type_variation = "HeadingLabel"
		heading.text = DramgidSchema.group_label(group)
		skill_grid.add_child(heading)
		# The grid is three columns wide and a heading fills one of them, so two
		# spacers keep the rows under a heading aligned with the rows above it.
		skill_grid.add_child(Control.new())
		skill_grid.add_child(Control.new())

		for skill_id: String in group_skills:
			var label := Label.new()
			label.text = DramgidSchema.skill_label(skill_id)
			label.size_flags_horizontal = Control.SIZE_EXPAND_FILL
			skill_grid.add_child(label)

			var effective := SkillCheck.preview(skill_id, member, 0.0)
			var percent_label := Label.new()
			percent_label.name = "Percent_%s" % skill_id
			percent_label.text = "%d%%" % int(effective)
			# FR-205: the derivation is one hover away, in the ratified formula's own terms.
			percent_label.tooltip_text = _derivation_tooltip(member, skill_id, effective)
			skill_grid.add_child(percent_label)

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
		side_column.add_child(wheel_caption)

	# --- Injuries (called-shots 10C): serious records and qualified field treatment ---
	_render_injuries(main_column, member)

	# --- Recent checks (FR-205, toggleable for Archivists) ---
	main_column.add_child(_section("Recent Checks"))
	var toggle := CheckButton.new()
	toggle.name = "CheckMathToggle"
	toggle.text = "Show check math"
	toggle.button_pressed = bool(GameState.get_setting("interface", "show_check_math", true))
	toggle.toggled.connect(_on_check_math_toggled)
	main_column.add_child(toggle)
	if toggle.button_pressed:
		var checks := SkillCheck.recent_checks()
		if checks.is_empty():
			var none := Label.new()
			none.text = "(no checks made yet)"
			none.modulate = Color(1, 1, 1, 0.5)
			main_column.add_child(none)
		else:
			var log_column := VBoxContainer.new()
			log_column.name = "CheckLog"
			main_column.add_child(log_column)
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
				log_column.add_child(line)


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
	column.add_child(_section("Injuries"))
	_treatment_status = Label.new()
	_treatment_status.name = "TreatmentStatus"
	_treatment_status.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	_treatment_status.modulate = Color(1, 1, 1, 0.7)
	column.add_child(_treatment_status)
	_practitioner_picks.clear()
	if _selected_member != _choice_owner:
		_practitioner_choice.clear()
		_choice_owner = _selected_member
	var rows := InjuryTreatment.treatable_rows(GameState).filter(
		func(row: Dictionary) -> bool: return row["member"] == patient
	)
	if rows.is_empty():
		var none := Label.new()
		none.name = "NoInjuries"
		none.text = "(no serious injuries)"
		none.modulate = Color(1, 1, 1, 0.5)
		column.add_child(none)
		return
	for row: Dictionary in rows:
		for card_id: String in InjuryTreatment.field_cards():
			_add_injury_row(column, patient, str(row["location"]), row["record"], card_id)


func _add_injury_row(column: VBoxContainer, patient: PartyMember, location: String, record: Dictionary, card_id: String) -> void:
	var card: Dictionary = InjuryTreatment.CARDS[card_id]
	var box := VBoxContainer.new()
	box.name = "Injury_%s" % location
	column.add_child(box)
	var title := Label.new()
	title.name = "InjuryTitle_%s" % location
	var lifts: Array = InjuryTreatment._restrictions(record)
	title.text = "%s  •  serious  •  %s  •  %s" % [
		location.capitalize(),
		" / ".join(PackedStringArray(lifts)).replace("_", " ") if not lifts.is_empty() else "no listed restriction",
		str(record.get("recovery", "untreated")),
	]
	box.add_child(title)
	var controls := HBoxContainer.new()
	controls.add_theme_constant_override("separation", 12)
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
	button.text = "%s  •  %d × %s  (carry %d)" % [
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
