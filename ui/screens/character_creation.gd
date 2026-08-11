class_name CharacterCreationScreen
extends Screen
## The Register of Persons — character creation (#129), backed by ratified #98 data
## in `globals/chargen_data.gd`. Runs once at boot for a new game (via GameFlow's
## Menus/CharacterCreation state) and is re-triggerable in RECRUIT mode later
## (`ui/screens/tavern.gd`'s "Sign On a New Face", gated by
## `GameState.custom_recruit_chargen_unlocked()`).
##
## KNOWN DEVIATIONS FROM THE LITERAL ISSUE #129 TEXT (flagged per the issue's own
## "if the spec and the design doc disagree, flag it rather than picking" rule):
##
## 1. "The Seven Measures" / D-R-A-M-G-I-D. No such attribute set exists in ratified
##    data. `systems/character-creation.md` (read 2026-08-11) ratifies SIX attributes
##    — Forge/Edge/Anchor/Spark/Pitch/Voice — which is exactly what
##    `globals/skill_check.gd` already implements. The center panel keeps the issue's
##    flavour header text verbatim (it reads as an in-world eyebrow, not a mechanical
##    claim) but the six rows underneath are the real, ratified attributes. This is a
##    naming conflict for #98/the design doc to resolve, not something this build
##    invents an answer for.
## 2. "Traits — choose two" (6 toggle rows). No ratified category is a 6-item,
##    choose-two set. The nearest fit is Chapter 1's roster of 5 ratified ancestries
##    (character-creation.md's "Soul Meter (CRPG) scope note"), which is inherently a
##    single pick (a character has one ancestry). This build uses that slot as a
##    single-select Ancestry list instead of a 6-row choose-two Traits list.
## 3. The vault's full chargen order (Race -> Discipline -> Patron -> Element ->
##    Attributes -> Background -> Skills -> Flaw) has more steps than #129's three-
##    panel mock shows room for. Discipline/Patron/Background/Element/Flaw are
##    surfaced as a compact "Calling" row above the footer rather than as their own
##    illustrated panels, so every #98-required system is actually choosable without
##    redrawing panels the issue never specified.
##
## Point-buy budget/floor/cap and the twelve-skill derivation come from
## `ChargenData`/`SkillCheckService` — never hand-rolled here.

signal recruit_created(member: PartyMember)

enum Mode { PLAYER, RECRUIT }

const UnitArtScript := preload("res://globals/unit_art.gd")
const STAMP_SOUND := preload("res://assets/audio/sfx/impactPlate_heavy_000.ogg")

var mode: Mode = Mode.PLAYER

var _attributes: Dictionary = ChargenData.default_attributes()
var _ancestry_id := ""
var _background_id := ""
var _discipline_id := ""
var _patron_id := ""
var _major_element := ""
var _minor_element := ""
var _flaw_text := ""
var _likeness_id: String = ChargenData.LIKENESS_UNIT_IDS[0]

var _name_edit: LineEdit
var _epithet_edit: LineEdit
var _points_lbl: Label
var _accept_btn: Button
var _summary_lbl: Label
var _eyebrow_lbl: Label
var _attribute_bars: Dictionary = {}
var _attribute_value_lbls: Dictionary = {}
var _skill_pct_lbls: Dictionary = {}
var _ancestry_rows: Dictionary = {}
var _likeness_buttons: Array[Button] = []
var _background_option: OptionButton
var _discipline_option: OptionButton
var _patron_option: OptionButton
var _major_option: OptionButton
var _minor_option: OptionButton
var _flash_rect: ColorRect


func _build() -> void:
	allow_back = false  # ACCEPT is the only way out — Esc must not skip creation.
	var vbox := _make_shell_window("THE REGISTER OF PERSONS")

	_eyebrow_lbl = Label.new()
	_eyebrow_lbl.text = "new entry, form 7, in triplicate"
	_eyebrow_lbl.theme_type_variation = "EyebrowLabel"
	shell_body.get_parent().add_child(_eyebrow_lbl)
	shell_body.get_parent().move_child(_eyebrow_lbl, shell_body.get_index())

	_points_lbl = Label.new()
	_points_lbl.theme_type_variation = "StatLabel"
	shell_header.add_child(_points_lbl)

	var columns := HBoxContainer.new()
	columns.theme_type_variation = "MirrorPairRow"
	columns.size_flags_vertical = Control.SIZE_EXPAND_FILL
	vbox.add_child(columns)

	columns.add_child(_build_left_panel())
	columns.add_child(_build_center_panel())
	columns.add_child(_build_right_panel())

	_build_footer(vbox)

	_refresh_all()


# --- Left: likeness + name -----------------------------------------------------


func _build_left_panel() -> Control:
	var panel := VBoxContainer.new()
	panel.theme_type_variation = "LedgerColumn"
	panel.custom_minimum_size = Vector2(400, 0)

	var heading := Label.new()
	heading.text = "Likeness"
	heading.theme_type_variation = "HeadingLabel"
	panel.add_child(heading)

	var grid := GridContainer.new()
	grid.columns = 2
	panel.add_child(grid)
	_likeness_buttons.clear()
	for unit_id: String in ChargenData.LIKENESS_UNIT_IDS:
		var btn := Button.new()
		btn.custom_minimum_size = Vector2(96, 96)
		btn.toggle_mode = true
		btn.mouse_default_cursor_shape = Control.CURSOR_POINTING_HAND
		btn.icon = load(UnitArtScript.texture_path(unit_id))
		btn.expand_icon = true
		btn.button_pressed = unit_id == _likeness_id
		btn.pressed.connect(_on_likeness_pressed.bind(unit_id, btn))
		grid.add_child(btn)
		_likeness_buttons.append(btn)

	var name_lbl := Label.new()
	name_lbl.text = "Name"
	name_lbl.theme_type_variation = "MutedLabel"
	panel.add_child(name_lbl)
	_name_edit = LineEdit.new()
	_name_edit.placeholder_text = "Their name, for the ledger"
	_name_edit.text_changed.connect(func(_t: String) -> void: _refresh_summary_and_gate())
	panel.add_child(_name_edit)

	var epithet_lbl := Label.new()
	epithet_lbl.text = "Epithet"
	epithet_lbl.theme_type_variation = "MutedLabel"
	panel.add_child(epithet_lbl)
	_epithet_edit = LineEdit.new()
	_epithet_edit.placeholder_text = "the unbowed, the quiet, ..."
	_epithet_edit.text_changed.connect(func(_t: String) -> void: _refresh_summary_and_gate())
	panel.add_child(_epithet_edit)

	return panel


func _on_likeness_pressed(unit_id: String, pressed_btn: Button) -> void:
	_likeness_id = unit_id
	for btn in _likeness_buttons:
		btn.set_pressed_no_signal(btn == pressed_btn)


# --- Center: The Seven Measures -------------------------------------------------


func _build_center_panel() -> Control:
	var panel := VBoxContainer.new()
	panel.theme_type_variation = "LedgerColumn"
	panel.size_flags_horizontal = Control.SIZE_EXPAND_FILL

	var heading := Label.new()
	heading.text = "The Seven Measures"
	heading.theme_type_variation = "HeadingLabel"
	panel.add_child(heading)

	var footnote := Label.new()
	footnote.text = "Doctrine and Decorum amplify Karma/Fame; they never govern a combat roll."
	footnote.theme_type_variation = "QuoteLabel"
	footnote.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	panel.add_child(footnote)

	_attribute_bars.clear()
	_attribute_value_lbls.clear()
	for attribute_id: String in ChargenData.ATTRIBUTE_IDS:
		panel.add_child(_build_attribute_row(attribute_id))

	return panel


func _build_attribute_row(attribute_id: String) -> Control:
	var row := HBoxContainer.new()
	row.theme_type_variation = "BattleHudRow"

	var letter := Label.new()
	letter.text = ChargenData.attribute_label(attribute_id).left(1).to_upper()
	letter.theme_type_variation = "HeadingLabel"
	letter.custom_minimum_size = Vector2(28, 0)
	row.add_child(letter)

	var info := VBoxContainer.new()
	info.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	row.add_child(info)

	var name_lbl := Label.new()
	name_lbl.text = ChargenData.attribute_label(attribute_id)
	info.add_child(name_lbl)

	var hint_lbl := Label.new()
	hint_lbl.text = str(ChargenData.ATTRIBUTE_HINTS.get(attribute_id, ""))
	hint_lbl.theme_type_variation = "QuoteLabel"
	info.add_child(hint_lbl)

	var bar := ProgressBar.new()
	bar.custom_minimum_size = Vector2(0, 5)
	bar.show_percentage = false
	bar.min_value = ChargenData.ATTRIBUTE_FLOOR
	bar.max_value = ChargenData.ATTRIBUTE_CAP
	bar.value = _attributes[attribute_id]
	info.add_child(bar)
	_attribute_bars[attribute_id] = bar

	var minus_btn := Button.new()
	minus_btn.text = "-"
	minus_btn.mouse_default_cursor_shape = Control.CURSOR_POINTING_HAND
	minus_btn.pressed.connect(_on_attribute_step.bind(attribute_id, -1))
	row.add_child(minus_btn)

	var value_lbl := Label.new()
	value_lbl.theme_type_variation = "StatLabel"
	value_lbl.custom_minimum_size = Vector2(24, 0)
	value_lbl.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	row.add_child(value_lbl)
	_attribute_value_lbls[attribute_id] = value_lbl

	var plus_btn := Button.new()
	plus_btn.text = "+"
	plus_btn.mouse_default_cursor_shape = Control.CURSOR_POINTING_HAND
	plus_btn.pressed.connect(_on_attribute_step.bind(attribute_id, 1))
	row.add_child(plus_btn)

	return row


func _on_attribute_step(attribute_id: String, delta: int) -> void:
	var current := int(_attributes[attribute_id])
	var next := clampi(current + delta, ChargenData.ATTRIBUTE_FLOOR, ChargenData.ATTRIBUTE_CAP)
	if next == current:
		return
	if delta > 0 and ChargenData.remaining_points(_attributes) <= 0:
		_flash_points_denied()
		return
	_attributes[attribute_id] = next
	_animate_attribute_change(attribute_id)
	_refresh_all()


func _animate_attribute_change(attribute_id: String) -> void:
	var bar: ProgressBar = _attribute_bars[attribute_id]
	var tween := create_tween()
	tween.tween_property(bar, "value", _attributes[attribute_id], DS.DUR_INSTANT)
	# Staggered ripple: skill rows governed by this attribute fade their new % in
	# 40ms apart, "so the player literally watches the derivation" (#129).
	var delay := 0.0
	for skill_id: String in ChargenData.SKILL_IDS:
		if ChargenData.governing_attribute(skill_id) != attribute_id:
			continue
		var lbl: Label = _skill_pct_lbls.get(skill_id)
		if lbl == null:
			continue
		var skill_tween := create_tween()
		skill_tween.tween_interval(delay)
		skill_tween.tween_property(lbl, "modulate", Color(1, 1, 1, 1), 0.0)
		skill_tween.tween_property(lbl, "modulate:a", 0.2, 0.0)
		skill_tween.tween_property(lbl, "modulate:a", 1.0, DS.DUR_FAST)
		delay += 0.04


func _flash_points_denied() -> void:
	# "Shakes" the points label with an amber flash — no sound punishment (#129).
	# Godot Containers re-lay-out their children every frame, so a position tween
	# here would fight the parent HBoxContainer; a pivot-based wobble survives that.
	var original_color := _points_lbl.modulate
	var tween := create_tween()
	tween.tween_property(_points_lbl, "modulate", DS.GILD_2, DS.DUR_INSTANT)
	tween.parallel().tween_property(_points_lbl, "rotation", deg_to_rad(6.0), 0.04)
	tween.tween_property(_points_lbl, "rotation", deg_to_rad(-6.0), 0.04)
	tween.tween_property(_points_lbl, "rotation", 0.0, 0.04)
	tween.tween_property(_points_lbl, "modulate", original_color, DS.DUR_FAST)


# --- Right: Ancestry + derived skills preview ------------------------------------


func _build_right_panel() -> Control:
	var panel := VBoxContainer.new()
	panel.theme_type_variation = "LedgerColumn"
	panel.custom_minimum_size = Vector2(500, 0)

	var ancestry_heading := Label.new()
	ancestry_heading.text = "Ancestry — choose one"
	ancestry_heading.theme_type_variation = "HeadingLabel"
	panel.add_child(ancestry_heading)

	_ancestry_rows.clear()
	for entry: Dictionary in ChargenData.ANCESTRIES:
		panel.add_child(_build_ancestry_row(entry))

	var skills_heading := Label.new()
	skills_heading.text = "Twelve Skills"
	skills_heading.theme_type_variation = "HeadingLabel"
	panel.add_child(skills_heading)

	var skills_grid := GridContainer.new()
	skills_grid.columns = 2
	panel.add_child(skills_grid)
	_skill_pct_lbls.clear()
	for skill_id: String in ChargenData.SKILL_IDS:
		var row := HBoxContainer.new()
		var name_lbl := Label.new()
		name_lbl.text = ChargenData.skill_label(skill_id)
		name_lbl.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		row.add_child(name_lbl)
		var pct_lbl := Label.new()
		pct_lbl.theme_type_variation = "StatLabel"
		row.add_child(pct_lbl)
		_skill_pct_lbls[skill_id] = pct_lbl
		skills_grid.add_child(row)

	return panel


func _build_ancestry_row(entry: Dictionary) -> Control:
	var btn := Button.new()
	btn.toggle_mode = true
	btn.mouse_default_cursor_shape = Control.CURSOR_POINTING_HAND
	btn.text = "%s%s  —  %s" % [
		"◆ " if entry["id"] == _ancestry_id else "◇ ",
		entry["name"],
		entry["trait"],
	]
	btn.alignment = HORIZONTAL_ALIGNMENT_LEFT
	btn.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	btn.pressed.connect(_on_ancestry_pressed.bind(entry["id"]))
	_ancestry_rows[entry["id"]] = btn
	return btn


func _on_ancestry_pressed(ancestry_id: String) -> void:
	_ancestry_id = ancestry_id
	for id: String in _ancestry_rows:
		var btn: Button = _ancestry_rows[id]
		var entry := ChargenData.ancestry_by_id(id)
		btn.set_pressed_no_signal(id == _ancestry_id)
		btn.text = "%s%s  —  %s" % ["◆ " if id == _ancestry_id else "◇ ", entry["name"], entry["trait"]]
		if id == _ancestry_id:
			var tween := create_tween()
			btn.modulate = Color(1, 1, 1, 1)
			tween.tween_property(btn, "modulate", DS.VIOLET_3, DS.DUR_FAST)
			tween.tween_property(btn, "modulate", Color(1, 1, 1, 1), DS.DUR_FAST)
	_refresh_summary_and_gate()


# --- Footer: Calling row + summary + ACCEPT --------------------------------------


func _build_footer(vbox: VBoxContainer) -> void:
	var calling_heading := Label.new()
	calling_heading.text = "Calling"
	calling_heading.theme_type_variation = "HeadingLabel"
	vbox.add_child(calling_heading)

	var calling_row := HBoxContainer.new()
	calling_row.theme_type_variation = "MirrorPairRow"
	vbox.add_child(calling_row)

	_discipline_option = _labelled_option(calling_row, "Discipline")
	for entry: Dictionary in ChargenData.DISCIPLINES:
		_discipline_option.add_item(entry["name"])
	_discipline_option.item_selected.connect(
		func(idx: int) -> void:
			_discipline_id = ChargenData.DISCIPLINES[idx]["id"]
			_refresh_summary_and_gate()
	)

	_patron_option = _labelled_option(calling_row, "Patron")
	for entry: Dictionary in ChargenData.PATRONS:
		_patron_option.add_item("%s (%s)" % [entry["name"], entry["patron"]])
	_patron_option.item_selected.connect(
		func(idx: int) -> void:
			_patron_id = ChargenData.PATRONS[idx]["id"]
			_refresh_summary_and_gate()
	)

	_background_option = _labelled_option(calling_row, "Background")
	for entry: Dictionary in ChargenData.BACKGROUNDS:
		_background_option.add_item(entry["name"])
	_background_option.item_selected.connect(
		func(idx: int) -> void:
			_background_id = ChargenData.BACKGROUNDS[idx]["id"]
			_refresh_all()
	)

	var element_row := HBoxContainer.new()
	element_row.theme_type_variation = "MirrorPairRow"
	vbox.add_child(element_row)

	_major_option = _labelled_option(element_row, "Major Element")
	_minor_option = _labelled_option(element_row, "Minor Element")
	for wheel_entry: Dictionary in DS.WHEEL:
		_major_option.add_item(wheel_entry["name"])
		_minor_option.add_item(wheel_entry["name"])
	_major_option.item_selected.connect(
		func(idx: int) -> void:
			_major_element = DS.WHEEL[idx]["id"]
			_refresh_summary_and_gate()
	)
	_minor_option.item_selected.connect(
		func(idx: int) -> void:
			_minor_element = DS.WHEEL[idx]["id"]
			_refresh_summary_and_gate()
	)

	var flaw_lbl := Label.new()
	flaw_lbl.text = "Flaw (optional)"
	flaw_lbl.theme_type_variation = "MutedLabel"
	vbox.add_child(flaw_lbl)
	var flaw_edit := LineEdit.new()
	flaw_edit.placeholder_text = "a Waning-flavored complication, if any"
	flaw_edit.text_changed.connect(func(t: String) -> void: _flaw_text = t.strip_edges())
	vbox.add_child(flaw_edit)

	_summary_lbl = Label.new()
	_summary_lbl.theme_type_variation = "QuoteLabel"
	vbox.add_child(_summary_lbl)

	_flash_rect = ColorRect.new()
	_flash_rect.color = DS.PARCHMENT
	_flash_rect.modulate.a = 0.0
	_flash_rect.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_flash_rect.set_anchors_preset(Control.PRESET_FULL_RECT)
	add_child(_flash_rect)

	_accept_btn = _menu_button(vbox, "ACCEPT THE TERMS", _on_accept)
	_accept_btn.theme_type_variation = "BronzeButton"


func _labelled_option(parent: Control, label_text: String) -> OptionButton:
	var col := VBoxContainer.new()
	var lbl := Label.new()
	lbl.text = label_text
	lbl.theme_type_variation = "MutedLabel"
	col.add_child(lbl)
	var option := OptionButton.new()
	option.mouse_default_cursor_shape = Control.CURSOR_POINTING_HAND
	col.add_child(option)
	parent.add_child(col)
	return option


# --- Derivation / gating ----------------------------------------------------------


func _refresh_all() -> void:
	for attribute_id: String in ChargenData.ATTRIBUTE_IDS:
		var value := int(_attributes[attribute_id])
		(_attribute_bars[attribute_id] as ProgressBar).value = value
		(_attribute_value_lbls[attribute_id] as Label).text = str(value)
	var trained_skills: Array = ChargenData.background_by_id(_background_id).get("skills", [])
	var percentages := ChargenData.preview_skill_percentages(_attributes, trained_skills)
	for skill_id: String in ChargenData.SKILL_IDS:
		var lbl: Label = _skill_pct_lbls[skill_id]
		lbl.text = "%d%%" % roundi(percentages[skill_id])
	_refresh_summary_and_gate()


func _refresh_summary_and_gate() -> void:
	var remaining := ChargenData.remaining_points(_attributes)
	_points_lbl.text = "%d POINTS UNSPENT" % remaining
	_points_lbl.modulate = DS.GILD_2 if remaining > 0 else DS.STATE_CONSTANT

	var name_text := _name_edit.text.strip_edges() if _name_edit else ""
	var epithet_text := _epithet_edit.text.strip_edges() if _epithet_edit else ""
	var initials: PackedStringArray = []
	for attribute_id: String in ChargenData.ATTRIBUTE_IDS:
		initials.append(
			"%s%d" % [ChargenData.attribute_label(attribute_id).left(1), int(_attributes[attribute_id])]
		)
	_summary_lbl.text = "%s%s  ·  %s" % [
		name_text if not name_text.is_empty() else "(unnamed)",
		(", the " + epithet_text) if not epithet_text.is_empty() else "",
		"  ·  ".join(initials),
	]

	var ready := (
		remaining == 0
		and not _ancestry_id.is_empty()
		and not name_text.is_empty()
		and ChargenData.is_valid_element_pair(_major_element, _minor_element)
	)
	if _accept_btn != null:
		_accept_btn.disabled = not ready


# --- ACCEPT -------------------------------------------------------------------------


func _on_accept() -> void:
	if _accept_btn.disabled:
		return
	var member := _build_party_member()
	if mode == Mode.RECRUIT:
		GameState.add_custom_recruit(member)
	else:
		GameState.apply_created_character(member)
	_play_accept_juice()
	recruit_created.emit(member)
	if mode == Mode.PLAYER:
		await get_tree().create_timer(0.35).timeout
		GameFlow.send_event("new_game")
	else:
		await get_tree().create_timer(0.35).timeout
		close()


func _build_party_member() -> PartyMember:
	var member := PartyMember.new()
	member.display_name = _name_edit.text.strip_edges()
	member.epithet = _epithet_edit.text.strip_edges()
	member.race = ChargenData.ancestry_by_id(_ancestry_id).get("name", "")
	var patron_entry := ChargenData.patron_by_id(_patron_id)
	member.char_class = (
		"%s (%s)" % [patron_entry["name"], patron_entry["patron"]] if not patron_entry.is_empty() else ""
	)
	member.discipline = _discipline_id
	member.patron = _patron_id
	member.background = _background_id
	member.flaw = _flaw_text
	member.starting_mastery = ChargenData.background_by_id(_background_id).get("mastery", "")
	member.major_element = _major_element
	member.minor_element = _minor_element
	member.attributes = _attributes.duplicate(true)
	member.skill_tiers = {}
	for skill_id: String in ChargenData.background_by_id(_background_id).get("skills", []):
		member.skill_tiers[skill_id] = "trained"
	member.skill_percentages = {}
	member.bio = ChargenData.ancestry_by_id(_ancestry_id).get("trait", "")
	member.portrait = load(UnitArtScript.texture_path(_likeness_id))
	member.level = 1
	member.max_hp = int(_attributes.get("anchor", ChargenData.ATTRIBUTE_FLOOR)) * 8
	member.hp = member.max_hp
	member.attack = int(_attributes.get("forge", ChargenData.ATTRIBUTE_FLOOR))
	member.defense = int(_attributes.get("edge", ChargenData.ATTRIBUTE_FLOOR))
	return member


func _play_accept_juice() -> void:
	_accept_btn.disabled = true
	var player := AudioStreamPlayer.new()
	player.stream = STAMP_SOUND
	add_child(player)
	player.finished.connect(player.queue_free)
	player.play()
	_eyebrow_lbl.text = "...recorded."
	var tween := create_tween()
	_flash_rect.modulate.a = 0.9
	tween.tween_property(_flash_rect, "modulate:a", 0.0, DS.DUR_FAST)
