extends Screen
## Vex is the fixed lead. The Four Arms supplies exactly two companions from a
## deliberately small prototype roster.
##
## Layout mirrors ui/screens/party.gd's proven list-plus-sheet split (same
## "MirrorPairRow"/"LedgerColumn" DS tokens — no new theme types needed): a
## compact checkbox list on the left, a focused-recruit detail sheet on the
## right. Clicking a row (or its checkbox) focuses that recruit in the sheet;
## the checkbox alone commits/withdraws them from the chosen two.

const PartyMemberVisualsScript := preload(
	"res://actors/party_followers/party_member_visuals.gd"
)
const MAX_COMPANIONS := 2
const _FOCUS_POP_FROM_SCALE := 0.85

var _checks: Array[CheckBox] = []
var _candidates: Array[PartyMember] = []
var _row_portraits: Array[TextureRect] = []
var _confirm_btn: Button
var _hint_lbl: Label

var _focused_member: PartyMember
var _detail_portrait: TextureRect
var _detail_name_lbl: Label
var _detail_sub_lbl: Label
var _detail_hp_lbl: Label
var _detail_hp_bar: ProgressBar
var _detail_status_lbl: Label
var _detail_bio_lbl: Label


func _build() -> void:
	# Opaque: the tavern interior + field HUD otherwise bleed through the roster text.
	_add_opaque_backdrop()
	var vbox := _make_shell_window("The Four Arms — Choose Two Companions")

	var lead_lbl := Label.new()
	lead_lbl.text = "LEAD  •  Vex the Unbowed  •  Ironbrand  •  44 HP"
	lead_lbl.theme_type_variation = "HeadingLabel"
	vbox.add_child(lead_lbl)

	var renown_lbl := Label.new()
	renown_lbl.text = (
		"Renown %d  •  Infamy %d" % [roundi(Renown.reputation()), roundi(Renown.infamy())]
	)
	vbox.add_child(renown_lbl)

	var hint := Label.new()
	hint.text = "Choose exactly two. Vex always leads; locked recruits explain what must be earned."
	hint.modulate = Color(1, 1, 1, 0.6)
	hint.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	vbox.add_child(hint)

	# Reuses the chargen screen in recruit mode (#98/#129 "reusable later" scope) —
	# unlocked later via GameState.unlock_custom_recruit_chargen(); off by default.
	if GameState.custom_recruit_chargen_unlocked():
		var create_btn := _menu_button(vbox, "Sign On a New Face", _on_create_recruit)
		create_btn.theme_type_variation = "BronzeButton"

	var split := HBoxContainer.new()
	split.theme_type_variation = "MirrorPairRow"
	split.size_flags_vertical = Control.SIZE_EXPAND_FILL
	vbox.add_child(split)

	var scroll := ScrollContainer.new()
	scroll.custom_minimum_size = Vector2(360, 0)
	scroll.size_flags_vertical = Control.SIZE_EXPAND_FILL
	# Rows wrap inside the column; a horizontal scrollbar just hides recruit text.
	scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	split.add_child(scroll)

	var list_box := VBoxContainer.new()
	list_box.theme_type_variation = "ScreenContentColumn"
	list_box.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	scroll.add_child(list_box)

	_candidates = GameState.recruitable_candidates()
	var last_class := ""
	for member in _candidates:
		if member.char_class != last_class:
			last_class = member.char_class
			if list_box.get_child_count() > 0:
				var sep := HSeparator.new()
				list_box.add_child(sep)
			var heading := _section(last_class)
			list_box.add_child(heading)
		list_box.add_child(_build_row(member))
		if GameState.has_party_member(member.display_name):
			_checks.back().set_pressed_no_signal(true)

	_build_detail_sheet(split)
	if not _candidates.is_empty():
		_focus_member(_candidates[0], false)

	_hint_lbl = Label.new()
	_hint_lbl.modulate = Color(1, 1, 1, 0.6)
	vbox.add_child(_hint_lbl)

	_confirm_btn = _menu_button(vbox, "Confirm Vex's Company", _on_confirm)
	_confirm_btn.theme_type_variation = "BronzeButton"
	_update_hint()

	_add_back_button(vbox, "Leave without choosing")
	var back_btn := vbox.get_child(-1) as Button
	if back_btn:
		back_btn.mouse_default_cursor_shape = Control.CURSOR_POINTING_HAND


func _build_row(member: PartyMember) -> Control:
	var margin_container := MarginContainer.new()
	margin_container.add_theme_constant_override("margin_left", 16)
	margin_container.mouse_filter = Control.MOUSE_FILTER_STOP
	margin_container.mouse_default_cursor_shape = Control.CURSOR_POINTING_HAND
	margin_container.gui_input.connect(_on_row_gui_input.bind(member))

	var row := HBoxContainer.new()
	row.add_theme_constant_override("separation", 12)
	margin_container.add_child(row)

	var check := CheckBox.new()
	check.mouse_default_cursor_shape = Control.CURSOR_POINTING_HAND
	var lock_reason := _lock_reason(member)
	if not lock_reason.is_empty():
		check.disabled = true
	check.toggled.connect(_on_toggled.bind(check))
	_checks.append(check)
	row.add_child(check)

	var portrait := TextureRect.new()
	portrait.texture = PartyMemberVisualsScript.ensure_portrait(member)
	portrait.custom_minimum_size = Vector2(56, 56)
	portrait.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	portrait.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	portrait.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	portrait.mouse_filter = Control.MOUSE_FILTER_IGNORE
	row.add_child(portrait)
	_row_portraits.append(portrait)

	var info := VBoxContainer.new()
	info.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	info.mouse_filter = Control.MOUSE_FILTER_IGNORE
	if not lock_reason.is_empty():
		info.modulate = Color(1, 1, 1, 0.5)
	row.add_child(info)

	var name_lbl := Label.new()
	name_lbl.mouse_filter = Control.MOUSE_FILTER_IGNORE
	name_lbl.text = "%s  (Lv %d)" % [member.display_name, member.level]
	info.add_child(name_lbl)

	var sub_lbl := Label.new()
	sub_lbl.mouse_filter = Control.MOUSE_FILTER_IGNORE
	sub_lbl.modulate = Color(1, 1, 1, 0.6)
	sub_lbl.text = format_recruit_subtext(member.race, member.char_class, member.hp, member.max_hp)
	sub_lbl.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	info.add_child(sub_lbl)

	var bio_lbl := Label.new()
	bio_lbl.mouse_filter = Control.MOUSE_FILTER_IGNORE
	bio_lbl.text = lock_reason if not lock_reason.is_empty() else member.bio
	bio_lbl.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	info.add_child(bio_lbl)

	return margin_container


## The right-hand pane — mirrors party.gd's "LedgerColumn" sheet, sized up for
## a recruiting decision: a bigger portrait than the list row's, HP, and
## whichever of "chosen" / lock reason / "available" applies right now.
func _build_detail_sheet(split: HBoxContainer) -> void:
	var sheet := VBoxContainer.new()
	sheet.name = "RecruitDetailSheet"
	sheet.theme_type_variation = "LedgerColumn"
	sheet.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	split.add_child(sheet)

	_detail_portrait = TextureRect.new()
	_detail_portrait.custom_minimum_size = Vector2(128, 128)
	_detail_portrait.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	_detail_portrait.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	_detail_portrait.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	_detail_portrait.mouse_filter = Control.MOUSE_FILTER_IGNORE
	sheet.add_child(_detail_portrait)

	_detail_name_lbl = Label.new()
	_detail_name_lbl.theme_type_variation = "HeadingLabel"
	sheet.add_child(_detail_name_lbl)

	_detail_sub_lbl = Label.new()
	_detail_sub_lbl.modulate = Color(1, 1, 1, 0.6)
	sheet.add_child(_detail_sub_lbl)

	_detail_hp_lbl = Label.new()
	sheet.add_child(_detail_hp_lbl)
	_detail_hp_bar = ProgressBar.new()
	_detail_hp_bar.show_percentage = false
	_detail_hp_bar.custom_minimum_size = Vector2(0, 18)
	sheet.add_child(_detail_hp_bar)

	_detail_status_lbl = Label.new()
	_detail_status_lbl.theme_type_variation = "HeadingLabel"
	sheet.add_child(_detail_status_lbl)

	_detail_bio_lbl = Label.new()
	_detail_bio_lbl.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	_detail_bio_lbl.size_flags_vertical = Control.SIZE_EXPAND_FILL
	sheet.add_child(_detail_bio_lbl)


func _on_row_gui_input(event: InputEvent, member: PartyMember) -> void:
	if event is InputEventMouseButton and event.pressed and event.button_index == MOUSE_BUTTON_LEFT:
		_focus_member(member)


## Updates the detail sheet and, unless suppressed for the initial build, pops
## the portrait in — the "animation for the unit you have selected" cue. Juicee
## effects self-gate on the player's reduced-motion setting; no manual check
## needed here (see ui/screens/settings.gd).
func _focus_member(member: PartyMember, animate: bool = true) -> void:
	_focused_member = member
	var lock_reason := _lock_reason(member)

	_detail_portrait.texture = PartyMemberVisualsScript.ensure_portrait(member)
	_detail_name_lbl.text = "%s  (Lv %d)" % [member.display_name, member.level]
	_detail_sub_lbl.text = format_recruit_subtext(
		member.race, member.char_class, member.hp, member.max_hp
	)
	_detail_hp_lbl.text = "HP  %d / %d" % [member.hp, member.max_hp]
	_detail_hp_bar.max_value = member.max_hp
	_detail_hp_bar.value = member.hp
	_detail_bio_lbl.text = lock_reason if not lock_reason.is_empty() else member.bio

	if not lock_reason.is_empty():
		_detail_status_lbl.text = "Locked"
		_detail_status_lbl.modulate = Color(1, 1, 1, 0.6)
	elif _is_checked(member):
		_detail_status_lbl.text = "Chosen for the company"
		_detail_status_lbl.modulate = DS.BRONZE_3
	else:
		_detail_status_lbl.text = "Available"
		_detail_status_lbl.modulate = Color(1, 1, 1, 1)

	if animate:
		Juicee.pop_in(_detail_portrait, _FOCUS_POP_FROM_SCALE)


static func format_recruit_subtext(race: String, char_class: String, hp: int, max_hp: int) -> String:
	return "%s  •  %s  •  HP %d/%d" % [race, char_class, hp, max_hp]


static func get_lock_reason_text(min_rep: float, current_rep: float, min_infamy: float, current_infamy: float) -> String:
	if min_rep > current_rep:
		return "Won't talk to you yet — needs Renown %d (you have %d)." % [
			roundi(min_rep), roundi(current_rep)]
	if min_infamy > current_infamy:
		return "Doesn't trust anyone this clean — needs Infamy %d (you have %d)." % [
			roundi(min_infamy), roundi(current_infamy)]
	return ""


## Empty means recruitable right now. Non-empty replaces the bio with why not,
## same spirit as Reputation's "say what the world will remember" cause text.
func _lock_reason(member: PartyMember) -> String:
	return get_lock_reason_text(member.min_reputation, Renown.reputation(), member.min_infamy, Renown.infamy())


func _on_toggled(pressed: bool, check: CheckBox) -> void:
	if pressed and _selected_count() > MAX_COMPANIONS:
		check.set_pressed_no_signal(false)
		pressed = false
	_update_hint()

	var index := _checks.find(check)
	if index < 0:
		return
	var member := _candidates[index]
	if pressed:
		Juicee.flash(_row_portraits[index], DS.BRONZE_3, 0.15, 1)
	_focus_member(member, member != _focused_member)


func _is_checked(member: PartyMember) -> bool:
	var index := _candidates.find(member)
	return index >= 0 and index < _checks.size() and _checks[index].button_pressed


func _selected_count() -> int:
	var n := 0
	for check in _checks:
		if check.button_pressed:
			n += 1
	return n


func _update_hint() -> void:
	_hint_lbl.text = "%d / %d companions chosen" % [_selected_count(), MAX_COMPANIONS]
	_confirm_btn.disabled = _selected_count() != MAX_COMPANIONS


func _on_create_recruit() -> void:
	# The chargen screen (in RECRUIT mode) closes itself once its own ACCEPT juice
	# finishes — the tavern stays open underneath so the new recruit shows up in
	# the same list without the player having to reopen it.
	var screen := UIManager.open(load("res://ui/screens/character_creation.tscn")) as CharacterCreationScreen
	if screen != null:
		screen.mode = CharacterCreationScreen.Mode.RECRUIT


func _on_confirm() -> void:
	var chosen: Array[PartyMember] = []
	for i in _checks.size():
		if _checks[i].button_pressed:
			chosen.append(_candidates[i])
	if GameState.set_companions(chosen):
		close()
