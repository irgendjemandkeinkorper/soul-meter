extends Screen
## A view of GameState.party: member list on the left, sheet on the right.

const PartyMemberVisualsScript := preload(
	"res://actors/party_followers/party_member_visuals.gd"
)

var _name_lbl: Label
var _sub_lbl: Label
var _hp_bar: ProgressBar
var _hp_lbl: Label
var _bio_lbl: Label


func _build() -> void:
	var vbox := _make_window("Party", Vector2(720, 480))

	var row := HBoxContainer.new()
	row.size_flags_vertical = Control.SIZE_EXPAND_FILL
	row.add_theme_constant_override("separation", 16)
	vbox.add_child(row)

	var list := ItemList.new()
	list.mouse_default_cursor_shape = Control.CURSOR_POINTING_HAND
	list.custom_minimum_size = Vector2(260, 0)
	list.size_flags_vertical = Control.SIZE_EXPAND_FILL
	list.fixed_icon_size = Vector2i(48, 48)
	list.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	row.add_child(list)

	var sheet := VBoxContainer.new()
	sheet.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	sheet.add_theme_constant_override("separation", 8)
	row.add_child(sheet)

	_name_lbl = Label.new()
	_name_lbl.add_theme_font_size_override("font_size", 24)
	sheet.add_child(_name_lbl)

	_sub_lbl = Label.new()
	_sub_lbl.modulate = Color(1, 1, 1, 0.6)
	sheet.add_child(_sub_lbl)

	_hp_lbl = Label.new()
	sheet.add_child(_hp_lbl)
	_hp_bar = ProgressBar.new()
	_hp_bar.show_percentage = false
	_hp_bar.custom_minimum_size = Vector2(0, 18)
	sheet.add_child(_hp_bar)

	_bio_lbl = Label.new()
	_bio_lbl.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	_bio_lbl.size_flags_vertical = Control.SIZE_EXPAND_FILL
	sheet.add_child(_bio_lbl)

	for member in GameState.party:
		list.add_item(
			"%s  (Lv %d)" % [member.display_name, member.level],
			PartyMemberVisualsScript.ensure_portrait(member)
		)

	list.item_selected.connect(_on_selected)
	if GameState.party.size() > 0:
		list.select(0)
		_on_selected(0)
	else:
		_name_lbl.text = "(no party)"

	_add_back_button(vbox)


func _on_selected(idx: int) -> void:
	var m: PartyMember = GameState.party[idx]
	_name_lbl.text = m.display_name
	_sub_lbl.text = "%s  •  %s  •  Level %d" % [m.race, m.char_class, m.level]
	_hp_lbl.text = "HP  %d / %d" % [m.hp, m.max_hp]
	_hp_bar.max_value = m.max_hp
	_hp_bar.value = m.hp
	_bio_lbl.text = m.bio
