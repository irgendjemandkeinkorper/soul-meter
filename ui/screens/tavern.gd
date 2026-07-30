extends Screen
## The Four Arms tavern in Dom, the starting town — pick up to MAX_PARTY_SIZE
## recruits from GameState.recruitable_candidates() and set out. Reopenable
## any time the player is back in the tavern, so it doubles as a re-recruit
## screen, not just a one-time chargen step.

const MAX_PARTY_SIZE := 3

var _checks: Array[CheckBox] = []
var _candidates: Array[PartyMember] = []
var _confirm_btn: Button
var _hint_lbl: Label


func _build() -> void:
	var vbox := _make_window("The Four Arms — Choose Your Party", Vector2(640, 560))

	var hint := Label.new()
	hint.text = "Pick up to %d to set out with." % MAX_PARTY_SIZE
	hint.modulate = Color(1, 1, 1, 0.6)
	vbox.add_child(hint)

	var scroll := ScrollContainer.new()
	scroll.size_flags_vertical = Control.SIZE_EXPAND_FILL
	vbox.add_child(scroll)

	var list_box := VBoxContainer.new()
	list_box.add_theme_constant_override("separation", 10)
	list_box.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	scroll.add_child(list_box)

	_candidates = GameState.recruitable_candidates()
	for member in _candidates:
		list_box.add_child(_build_row(member))

	_hint_lbl = Label.new()
	_hint_lbl.modulate = Color(1, 1, 1, 0.6)
	vbox.add_child(_hint_lbl)

	_confirm_btn = _menu_button(vbox, "Set out", _on_confirm)
	_update_hint()

	_add_back_button(vbox, "Leave without choosing")


func _build_row(member: PartyMember) -> Control:
	var row := HBoxContainer.new()
	row.add_theme_constant_override("separation", 12)

	var check := CheckBox.new()
	check.toggled.connect(_on_toggled.bind(check))
	_checks.append(check)
	row.add_child(check)

	var info := VBoxContainer.new()
	info.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	row.add_child(info)

	var name_lbl := Label.new()
	name_lbl.text = "%s  (Lv %d)" % [member.display_name, member.level]
	info.add_child(name_lbl)

	var sub_lbl := Label.new()
	sub_lbl.modulate = Color(1, 1, 1, 0.6)
	sub_lbl.text = "%s  •  %s  •  HP %d/%d" % [member.race, member.char_class, member.hp, member.max_hp]
	info.add_child(sub_lbl)

	var bio_lbl := Label.new()
	bio_lbl.text = member.bio
	bio_lbl.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	info.add_child(bio_lbl)

	return row


func _on_toggled(pressed: bool, check: CheckBox) -> void:
	if pressed and _selected_count() > MAX_PARTY_SIZE:
		check.set_pressed_no_signal(false)
	_update_hint()


func _selected_count() -> int:
	var n := 0
	for check in _checks:
		if check.button_pressed:
			n += 1
	return n


func _update_hint() -> void:
	_hint_lbl.text = "%d / %d chosen" % [_selected_count(), MAX_PARTY_SIZE]
	_confirm_btn.disabled = _selected_count() == 0


func _on_confirm() -> void:
	var chosen: Array[PartyMember] = []
	for i in _checks.size():
		if _checks[i].button_pressed:
			chosen.append(_candidates[i])
	GameState.set_party(chosen)
	close()
