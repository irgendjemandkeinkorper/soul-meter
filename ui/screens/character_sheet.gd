extends Screen
## FR-604 character sheet (#100): identity, attributes, skills with their derivation
## surfaced (FR-205 tooltip + recent-check log), the Wheel widget, and the #98
## advancement point-spend surface. Member list on the left mirrors ui/screens/party.gd.

const WheelWidgetScript := preload("res://ui/components/wheel_widget.gd")

var _member_list: ItemList
var _sheet_column: VBoxContainer
var _selected_member: PartyMember


func _build() -> void:
	var vbox := _make_shell_window("Register of Persons")

	var row := HBoxContainer.new()
	row.theme_type_variation = "MirrorPairRow"
	row.size_flags_vertical = Control.SIZE_EXPAND_FILL
	vbox.add_child(row)

	_member_list = ItemList.new()
	_member_list.name = "MemberList"
	_member_list.mouse_default_cursor_shape = Control.CURSOR_POINTING_HAND
	_member_list.custom_minimum_size = Vector2(240, 0)
	_member_list.size_flags_vertical = Control.SIZE_EXPAND_FILL
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
		_member_list.add_item("%s  (Lv %d)" % [member.display_name, member.level])
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

	# --- Attributes (fixed after creation, owner 2026-08-24) ---
	if not member.attributes.is_empty():
		_sheet_column.add_child(_section("Attributes"))
		var attribute_grid := GridContainer.new()
		attribute_grid.columns = 6
		for attribute_id: String in ChargenData.ATTRIBUTE_IDS:
			var cell := Label.new()
			cell.text = "%s %d" % [
				ChargenData.ATTRIBUTE_LABELS.get(attribute_id, attribute_id),
				int(member.attributes.get(attribute_id, 0)),
			]
			cell.tooltip_text = str(ChargenData.ATTRIBUTE_HINTS.get(attribute_id, ""))
			cell.size_flags_horizontal = Control.SIZE_EXPAND_FILL
			attribute_grid.add_child(cell)
		_sheet_column.add_child(attribute_grid)

	# --- Skills + advancement spend (#98) ---
	_sheet_column.add_child(_section("Skills"))
	var points_label := Label.new()
	points_label.name = "AdvancementPoints"
	points_label.text = (
		"Advancement points: %d   (granted at story milestones)" % member.advancement_points
	)
	_sheet_column.add_child(points_label)

	var skill_grid := GridContainer.new()
	skill_grid.name = "SkillGrid"
	skill_grid.columns = 3
	_sheet_column.add_child(skill_grid)
	for skill_id: String in ChargenData.SKILL_IDS:
		var label := Label.new()
		label.text = str(ChargenData.SKILL_LABELS.get(skill_id, skill_id))
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
		if cost < 0:
			buy.text = "at cap"
			buy.disabled = true
		else:
			buy.text = "+5%%  (%d pt)" % cost
			buy.disabled = not Advancement.can_buy(member, skill_id)
		buy.mouse_default_cursor_shape = Control.CURSOR_POINTING_HAND
		buy.pressed.connect(_on_buy_pressed.bind(skill_id))
		skill_grid.add_child(buy)

	# --- The Wheel (FR-604) ---
	_sheet_column.add_child(_section("The Wheel"))
	var wheel := WheelWidgetScript.new()
	wheel.name = "WheelWidget"
	wheel.set_elements(member.major_element, member.minor_element)
	_sheet_column.add_child(wheel)
	if not member.major_element.is_empty() or not member.minor_element.is_empty():
		var wheel_caption := Label.new()
		wheel_caption.text = "Major: %s   Minor: %s" % [
			member.major_element.capitalize() if not member.major_element.is_empty() else "—",
			member.minor_element.capitalize() if not member.minor_element.is_empty() else "—",
		]
		wheel_caption.modulate = Color(1, 1, 1, 0.6)
		_sheet_column.add_child(wheel_caption)

	# --- Recent checks (FR-205, toggleable for Archivists) ---
	_sheet_column.add_child(_section("Recent Checks"))
	var toggle := CheckButton.new()
	toggle.name = "CheckMathToggle"
	toggle.text = "Show check math"
	toggle.button_pressed = bool(GameState.get_setting("interface", "show_check_math", true))
	toggle.toggled.connect(_on_check_math_toggled)
	_sheet_column.add_child(toggle)
	if toggle.button_pressed:
		var checks := SkillCheck.recent_checks()
		if checks.is_empty():
			var none := Label.new()
			none.text = "(no checks made yet)"
			none.modulate = Color(1, 1, 1, 0.5)
			_sheet_column.add_child(none)
		else:
			var log_column := VBoxContainer.new()
			log_column.name = "CheckLog"
			_sheet_column.add_child(log_column)
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
