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
var _quest_button: Button
var _selected_member: PartyMember


func _build() -> void:
	var vbox := _make_shell_window("Party")

	var row := HBoxContainer.new()
	row.theme_type_variation = "MirrorPairRow"
	row.size_flags_vertical = Control.SIZE_EXPAND_FILL
	vbox.add_child(row)

	var list := ItemList.new()
	list.name = "MemberList"
	list.mouse_default_cursor_shape = Control.CURSOR_POINTING_HAND
	list.custom_minimum_size = Vector2(260, 0)
	list.size_flags_vertical = Control.SIZE_EXPAND_FILL
	list.fixed_icon_size = Vector2i(48, 48)
	list.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	row.add_child(list)

	var sheet := VBoxContainer.new()
	sheet.theme_type_variation = "LedgerColumn"
	sheet.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	row.add_child(sheet)

	_name_lbl = Label.new()
	_name_lbl.theme_type_variation = "HeadingLabel"
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

	var sheet_button := Button.new()
	sheet_button.name = "CharacterSheetButton"
	sheet_button.text = "Character Sheet"
	sheet_button.mouse_default_cursor_shape = Control.CURSOR_POINTING_HAND
	sheet_button.pressed.connect(_on_sheet_button_pressed)
	sheet.add_child(sheet_button)

	_quest_button = Button.new()
	_quest_button.name = "PersonalQuestButton"
	_quest_button.visible = false
	_quest_button.mouse_default_cursor_shape = Control.CURSOR_POINTING_HAND
	_quest_button.pressed.connect(_on_quest_button_pressed)
	sheet.add_child(_quest_button)

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
	_selected_member = m
	_name_lbl.text = m.display_name
	_sub_lbl.text = "%s  •  %s  •  Level %d" % [m.race, m.char_class, m.level]
	_hp_lbl.text = "HP  %d / %d" % [m.hp, m.max_hp]
	_hp_bar.max_value = m.max_hp
	_hp_bar.value = m.hp
	_bio_lbl.text = m.bio
	var dialogue_path := QuestRegistry.companion_quest_dialogue_for(m.id)
	_quest_button.visible = not dialogue_path.is_empty()
	_quest_button.text = "Talk to %s" % m.display_name


## FR-604 (#100): the full sheet lives on its own screen.
func _on_sheet_button_pressed() -> void:
	var sheet_screen := UIManager.open(UIManager.CHARACTER_SHEET, true)
	if _selected_member != null and sheet_screen != null:
		sheet_screen.call_deferred("select_member", _selected_member.id)


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
