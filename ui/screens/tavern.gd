extends Screen
## Vex is the fixed lead. The Four Arms supplies exactly two companions from a
## deliberately small prototype roster.

const PartyMemberVisualsScript := preload(
	"res://actors/party_followers/party_member_visuals.gd"
)
const MAX_COMPANIONS := 2

var _checks: Array[CheckBox] = []
var _candidates: Array[PartyMember] = []
var _confirm_btn: Button
var _hint_lbl: Label


func _build() -> void:
	var vbox := _make_window("The Four Arms — Choose Two Companions", Vector2(700, 620))

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

	var scroll := ScrollContainer.new()
	scroll.size_flags_vertical = Control.SIZE_EXPAND_FILL
	vbox.add_child(scroll)

	var list_box := VBoxContainer.new()
	list_box.add_theme_constant_override("separation", 10)
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

	var info := VBoxContainer.new()
	info.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	if not lock_reason.is_empty():
		info.modulate = Color(1, 1, 1, 0.5)
	row.add_child(info)

	var name_lbl := Label.new()
	name_lbl.text = "%s  (Lv %d)" % [member.display_name, member.level]
	info.add_child(name_lbl)

	var sub_lbl := Label.new()
	sub_lbl.modulate = Color(1, 1, 1, 0.6)
	sub_lbl.text = format_recruit_subtext(member.race, member.char_class, member.hp, member.max_hp)
	info.add_child(sub_lbl)

	var bio_lbl := Label.new()
	bio_lbl.text = lock_reason if not lock_reason.is_empty() else member.bio
	bio_lbl.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	info.add_child(bio_lbl)

	return margin_container


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
	_update_hint()


func _selected_count() -> int:
	var n := 0
	for check in _checks:
		if check.button_pressed:
			n += 1
	return n


func _update_hint() -> void:
	_hint_lbl.text = "%d / %d companions chosen" % [_selected_count(), MAX_COMPANIONS]
	_confirm_btn.disabled = _selected_count() != MAX_COMPANIONS


func _on_confirm() -> void:
	var chosen: Array[PartyMember] = []
	for i in _checks.size():
		if _checks[i].button_pressed:
			chosen.append(_candidates[i])
	if GameState.set_companions(chosen):
		close()
