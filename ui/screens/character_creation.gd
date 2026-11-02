class_name CharacterCreationScreen
extends Screen
## The Register of Persons — one screen over ChargenBuild (owner ruling 2026-11-02,
## docs/design/chargen-overhaul-plan-2026-11-02.md). Every choice is rolled when the screen
## opens; the tabs ORIGIN · CALLING · MEASURES · NAME can be visited in any order; the entry
## column (likeness, name, identity, measures) never leaves the screen; BEGIN works from any
## tab once the entry has a name. The screen owns presentation and focus only: every rule,
## percentage and gate comes from the model, so the boot-time player path, the tavern's
## recruit path and the integration tests drive the same public API below.

signal recruit_created(member: PartyMember)

enum Mode { PLAYER, RECRUIT }

const ChargenArtResolverScript := preload("res://ui/screens/chargen/chargen_art_resolver.gd")
const STAMP_SOUND := preload("res://assets/audio/sfx/impactPlate_heavy_000.ogg")

## Two-letter measure marks for skill rows (DRAMGID has two Ds).
const ATTRIBUTE_MARKS: Dictionary = {
	"doctrine": "Do", "reason": "Re", "alacrity": "Al", "muster": "Mu",
	"grit": "Gr", "intuition": "In", "decorum": "De",
}
const TIER_MARKS: Dictionary = {"untrained": "", "trained": "◆", "expert": "◆◆"}
## Debug builds only: the stand-in name QUICK START gives a hero left unnamed.
const QUICK_START_NAME := "Tester"
## The playtest found the class choice the unclear one, so the register opens on it.
const OPENING_TAB := &"calling"
const ELEMENT_ICON := "res://assets/icons/src/elements/%s.svg"
const COMMAND_ICON := "res://assets/icons/png/64/commands/%s.png"
const ENTRY_WIDTH := 420.0
const CLASS_TILE_SIZE := Vector2(0, 72)
const ABILITY_TILE_SIZE := Vector2(104, 76)
const CARD_WIDTH := 400.0

## The tavern sets RECRUIT after the screen opens, so a change re-checks the header.
var mode: Mode = Mode.PLAYER:
	set(value):
		mode = value
		_update_status()
## The in-progress character. Read freely; mutate through the select_*/set_* API so the
## screen refreshes.
var build: ChargenBuild = ChargenBuild.new()

var _tab_id: StringName = OPENING_TAB
var _tab_buttons: Dictionary = {}
var _tab_pages: Dictionary = {}
var _random_rng := RandomNumberGenerator.new()
## True while the creation points are the roll's, not the player's: a choice that refunds
## them (class, kit, tones, ancestry, background, measures) re-spends them so the entry stays
## ready. The first hand-made buy or refund hands the pool to the player for good.
var _rolled_purchases := true

var _eyebrow_lbl: Label
var _status_lbl: Label
var _begin_btn: Button
var _cancel_btn: Button
var _randomize_btn: Button
var _quick_start_btn: Button
var _roll_tab_btn: Button
var _flash_rect: ColorRect

var _portrait: TextureRect
var _name_edit: LineEdit
var _identity_lbl: Label
var _vitals_lbl: Label
var _measure_value_lbls: Dictionary = {}

var _ancestry_rows: Dictionary = {}
var _ancestry_art: TextureRect
var _ancestry_notes: Label
var _background_rows: Dictionary = {}

var _class_tiles: Dictionary = {}
var _class_heading: Label
var _kit_heading: Label
var _kit_lbl: Label
var _kit_chips: Dictionary = {}
var _resource_heading: Label
var _resource_lbl: Label
var _signature_heading: Label
var _signature_lbl: Label
var _major_option: OptionButton
var _minor_option: OptionButton
var _mastery_option: OptionButton
var _tones_note: Label
var _discipline_chips: Dictionary = {}
var _discipline_lbl: Label
var _pairing_lbl: Label
var _ability_groups: VBoxContainer
var _ability_key := ""
var _ability_card: PanelContainer
var _card_source: Control
var _card_title: Label
var _card_stats: Label
var _card_effect: Label
var _card_lock: Label

var _points_lbl: Label
var _attribute_bars: Dictionary = {}
var _attribute_value_lbls: Dictionary = {}
var _attribute_tweens: Dictionary = {}
var _attribute_readout: Label
var _skills_form: VBoxContainer
var _skills_pool_lbl: Label
var _skill_rows: Dictionary = {}
var _skills_key := ""

var _epithet_edit: LineEdit
var _flaw_edit: LineEdit
var _likeness_buttons: Array[Button] = []


# --- build ----------------------------------------------------------------------------------

func _build() -> void:
	_random_rng.randomize()
	# Player chargen remains flow-owned and uncancellable. Recruit chargen remains a
	# normal stack screen, so CANCEL ENTRY returns to the tavern as before.
	allow_back = false
	_add_opaque_backdrop(DS.STONE_0)
	var content := _make_shell_window("THE REGISTER OF PERSONS")

	_eyebrow_lbl = Label.new()
	_eyebrow_lbl.theme_type_variation = "EyebrowLabel"
	shell_body.get_parent().add_child(_eyebrow_lbl)
	shell_body.get_parent().move_child(_eyebrow_lbl, shell_body.get_index())
	_build_header_actions()

	var register := HBoxContainer.new()
	register.name = "Register"
	register.theme_type_variation = "ChargenRegister"
	register.size_flags_vertical = Control.SIZE_EXPAND_FILL
	content.add_child(register)
	register.add_child(_build_entry_column())

	var tab_column := VBoxContainer.new()
	tab_column.name = "Tabs"
	tab_column.theme_type_variation = "ChargenTabColumn"
	tab_column.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	register.add_child(tab_column)
	_build_tab_bar(tab_column)
	var panel := PanelContainer.new()
	panel.theme_type_variation = "ChargenTabPanel"
	panel.size_flags_vertical = Control.SIZE_EXPAND_FILL
	tab_column.add_child(panel)
	var pages := VBoxContainer.new()
	pages.name = "TabPages"
	panel.add_child(pages)
	_tab_pages[&"origin"] = _build_origin_tab()
	_tab_pages[&"calling"] = _build_calling_tab()
	_tab_pages[&"measures"] = _build_measures_tab()
	_tab_pages[&"name"] = _build_name_tab()
	for tab_id: StringName in ChargenSteps.tab_ids():
		pages.add_child(_tab_pages[tab_id] as Control)

	_build_footer()
	_build_ability_card()
	_build_flash()
	# Ready anytime: the entry opens fully rolled; only the name is left to the player.
	build = ChargenRandomizer.roll(_random_rng, build)
	_refresh_all()
	_show_tab(OPENING_TAB)


func _build_header_actions() -> void:
	var spacer := Control.new()
	spacer.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	spacer.mouse_filter = Control.MOUSE_FILTER_IGNORE
	shell_header.add_child(spacer)
	_randomize_btn = _menu_button(shell_header, "RANDOMIZE ALL", randomize_character)
	_randomize_btn.name = "RandomizeButton"
	_randomize_btn.theme_type_variation = "ChargenChoiceButton"
	# Playtest shortcut, debug builds only like the title's DEV ROOM: roll everything, name
	# the hero and begin in one press. The release export never builds it.
	if OS.is_debug_build():
		_quick_start_btn = _menu_button(shell_header, "QUICK START", quick_start)
		_quick_start_btn.name = "QuickStartButton"
		_quick_start_btn.theme_type_variation = "ChargenChoiceButton"
	_begin_btn = _menu_button(shell_header, "BEGIN", begin)
	_begin_btn.name = "BeginButton"
	_begin_btn.theme_type_variation = "BronzeButton"


func _build_footer() -> void:
	_cancel_btn = _menu_button(shell_hud_bar, "CANCEL ENTRY", _on_cancel_pressed)
	_cancel_btn.name = "CancelEntryButton"
	shell_hud_bar.move_child(_cancel_btn, 0)
	_status_lbl = Label.new()
	_status_lbl.name = "StatusLine"
	_status_lbl.theme_type_variation = "ChargenStatusLine"
	_status_lbl.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_status_lbl.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_status_lbl.size_flags_stretch_ratio = 4.0
	shell_hud_bar.add_child(_status_lbl)
	shell_hud_bar.move_child(_status_lbl, 1)


func _build_flash() -> void:
	_flash_rect = ColorRect.new()
	_flash_rect.color = DS.PARCHMENT
	_flash_rect.modulate.a = 0.0
	_flash_rect.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_flash_rect.set_anchors_preset(Control.PRESET_FULL_RECT)
	add_child(_flash_rect)


func _build_tab_bar(parent: Container) -> void:
	var bar := HBoxContainer.new()
	bar.name = "TabBar"
	bar.theme_type_variation = "ChargenTabBar"
	parent.add_child(bar)
	var group := ButtonGroup.new()
	for tab: Dictionary in ChargenSteps.TABS:
		var tab_id: StringName = tab["id"]
		var btn := Button.new()
		btn.name = "Tab_%s" % tab_id
		btn.theme_type_variation = "ChargenTab"
		btn.toggle_mode = true
		btn.button_group = group
		btn.mouse_default_cursor_shape = Control.CURSOR_POINTING_HAND
		btn.pressed.connect(go_to_tab.bind(tab_id))
		bar.add_child(btn)
		_tab_buttons[tab_id] = btn
	var spacer := Control.new()
	spacer.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	spacer.mouse_filter = Control.MOUSE_FILTER_IGNORE
	bar.add_child(spacer)
	_roll_tab_btn = _menu_button(bar, "ROLL THIS TAB", roll_tab)
	_roll_tab_btn.name = "RollTabButton"
	_roll_tab_btn.theme_type_variation = "ChargenChoiceButton"


# --- entry column ---------------------------------------------------------------------------

func _build_entry_column() -> Control:
	var frame := PanelContainer.new()
	frame.name = "EntryColumn"
	frame.theme_type_variation = "ChargenEntryFrame"
	frame.custom_minimum_size = Vector2(ENTRY_WIDTH, 0)
	var column := VBoxContainer.new()
	column.theme_type_variation = "ChargenEntryColumn"
	frame.add_child(column)

	_portrait = TextureRect.new()
	_portrait.name = "Likeness"
	_portrait.texture_filter = CanvasItem.TEXTURE_FILTER_LINEAR
	_portrait.custom_minimum_size = Vector2(0, 340)
	_portrait.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	_portrait.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_COVERED
	_portrait.mouse_filter = Control.MOUSE_FILTER_IGNORE
	column.add_child(_portrait)

	_name_edit = LineEdit.new()
	_name_edit.name = "NameEdit"
	_name_edit.theme_type_variation = "ChargenNameEdit"
	_name_edit.placeholder_text = "Name this person"
	_name_edit.text_changed.connect(set_display_name)
	column.add_child(_name_edit)
	column.add_child(_quote("The one thing never rolled."))

	_identity_lbl = Label.new()
	_identity_lbl.name = "IdentityLine"
	_identity_lbl.theme_type_variation = "ChargenIdentityLine"
	_identity_lbl.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	column.add_child(_identity_lbl)

	_vitals_lbl = Label.new()
	_vitals_lbl.name = "Vitals"
	_vitals_lbl.theme_type_variation = "StatLabel"
	column.add_child(_vitals_lbl)

	var heading := Label.new()
	heading.text = "THE SEVEN MEASURES"
	heading.theme_type_variation = "EyebrowLabel"
	column.add_child(heading)
	var grid := GridContainer.new()
	grid.name = "Measures"
	grid.theme_type_variation = "ChargenMeasureGrid"
	grid.columns = DramgidSchema.ATTRIBUTE_IDS.size()
	column.add_child(grid)
	_measure_value_lbls.clear()
	for attribute_id: String in DramgidSchema.ATTRIBUTE_IDS:
		var cell := PanelContainer.new()
		cell.theme_type_variation = "ChargenMeasureCell"
		cell.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		cell.tooltip_text = DramgidSchema.attribute_label(attribute_id)
		grid.add_child(cell)
		var stack := VBoxContainer.new()
		stack.mouse_filter = Control.MOUSE_FILTER_IGNORE
		cell.add_child(stack)
		var mark := Label.new()
		mark.text = DramgidSchema.attribute_label(attribute_id).substr(0, 3).to_upper()
		mark.theme_type_variation = "EyebrowLabel"
		mark.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		stack.add_child(mark)
		var value := Label.new()
		value.theme_type_variation = "StatLabel"
		value.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		stack.add_child(value)
		_measure_value_lbls[attribute_id] = value
	return frame


func _refresh_entry() -> void:
	_portrait.texture = ChargenArtResolverScript.portrait_texture(build.likeness_id)
	if _name_edit.text != build.display_name:
		_name_edit.text = build.display_name
	_identity_lbl.text = _identity_line()
	var scratch := build.scratch_member()
	_vitals_lbl.text = "HP %d  ·  BREATH %d" % [scratch.max_hp, scratch.breath_max]
	for attribute_id: String in DramgidSchema.ATTRIBUTE_IDS:
		(_measure_value_lbls[attribute_id] as Label).text = str(
			int(build.attributes.get(attribute_id, DramgidSchema.ATTRIBUTE_FLOOR))
		)


func _identity_line() -> String:
	var parts: PackedStringArray = []
	if not build.epithet.strip_edges().is_empty():
		parts.append(build.epithet.strip_edges())
	var ancestry := str(ChargenData.ancestry_by_id(build.ancestry_id).get("name", ""))
	if not ancestry.is_empty():
		parts.append(ancestry)
	var class_entry: Dictionary = ClassCatalog.by_id(build.class_id)
	if not class_entry.is_empty():
		parts.append("%s of %s" % [class_entry["name"], class_entry["patron"]])
	if not build.discipline_id.is_empty():
		parts.append(_discipline_name())
	var background := str(ChargenData.background_by_id(build.background_id).get("name", ""))
	if not background.is_empty():
		parts.append(background)
	return "  ·  ".join(parts)


# --- ORIGIN: ancestry and background --------------------------------------------------------

func _build_origin_tab() -> Control:
	var page := HBoxContainer.new()
	page.name = "Page_origin"
	page.theme_type_variation = "ChargenPage"
	page.size_flags_vertical = Control.SIZE_EXPAND_FILL

	var people := _form_column(page, "PEOPLE")
	_ancestry_rows.clear()
	for entry: Dictionary in ChargenData.ANCESTRIES:
		var id := str(entry["id"])
		var btn := _choice_button("%s  —  %s" % [entry["name"], entry["trait"]], select_ancestry.bind(id))
		btn.name = "Ancestry_%s" % id
		people.add_child(btn)
		_ancestry_rows[id] = btn

	var plate := VBoxContainer.new()
	plate.theme_type_variation = "ChargenIllustrationColumn"
	plate.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	page.add_child(plate)
	_ancestry_art = TextureRect.new()
	_ancestry_art.texture_filter = CanvasItem.TEXTURE_FILTER_LINEAR
	_ancestry_art.custom_minimum_size = Vector2(0, 360)
	_ancestry_art.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	_ancestry_art.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	_ancestry_art.mouse_filter = Control.MOUSE_FILTER_IGNORE
	plate.add_child(_ancestry_art)
	_ancestry_notes = Label.new()
	_ancestry_notes.theme_type_variation = "QuoteLabel"
	_ancestry_notes.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	_ancestry_notes.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	plate.add_child(_ancestry_notes)

	var history := _form_column(page, "BACKGROUND  ·  TWO TRADES TRAINED, THE ROOT NOTE MASTERED")
	_background_rows.clear()
	for entry: Dictionary in ChargenData.BACKGROUNDS:
		var id := str(entry["id"])
		var skill_names: PackedStringArray = []
		for skill_id in entry["skills"]:
			skill_names.append(DramgidSchema.skill_label(str(skill_id)))
		var btn := _choice_button("%s  —  Trained: %s\n%s" % [
			entry["name"], ", ".join(skill_names), entry["feature"]], select_background.bind(id))
		btn.name = "Background_%s" % id
		history.add_child(btn)
		_background_rows[id] = btn
	return page


func _refresh_origin() -> void:
	for id: String in _ancestry_rows:
		(_ancestry_rows[id] as Button).set_pressed_no_signal(id == build.ancestry_id)
	for id: String in _background_rows:
		(_background_rows[id] as Button).set_pressed_no_signal(id == build.background_id)
	var entry: Dictionary = ChargenData.ancestry_by_id(build.ancestry_id)
	var art_path: String = ChargenArtResolverScript.ancestry_path(build.ancestry_id)
	_ancestry_art.texture = null
	if not art_path.is_empty():
		var art_resource: Resource = load(art_path)
		if art_resource is Texture2D:
			_ancestry_art.texture = art_resource as Texture2D
	_ancestry_art.visible = _ancestry_art.texture != null
	_ancestry_notes.text = "%s\n%s\nLeanings: %s" % [
		entry.get("name", ""), entry.get("trait", ""), entry.get("leans", "—"),
	]


# --- CALLING: patron, kit, tones, discipline, ability tiles ---------------------------------

func _build_calling_tab() -> Control:
	var page := VBoxContainer.new()
	page.name = "Page_calling"
	page.theme_type_variation = "ChargenTabColumn"
	page.size_flags_vertical = Control.SIZE_EXPAND_FILL

	var tiles_heading := Label.new()
	tiles_heading.text = "PATRON  ·  CLASS"
	tiles_heading.theme_type_variation = "EyebrowLabel"
	page.add_child(tiles_heading)
	var grid := GridContainer.new()
	grid.name = "ClassTiles"
	grid.theme_type_variation = "ChargenTileGrid"
	grid.columns = ClassCatalog.ALL.size()
	page.add_child(grid)
	_class_tiles.clear()
	for entry: Dictionary in ClassCatalog.ALL:
		var id := str(entry["id"])
		var tile := Button.new()
		tile.name = "Class_%s" % id
		tile.theme_type_variation = "ChargenClassTile"
		tile.toggle_mode = true
		tile.text = str(entry["name"])
		tile.icon = _element_icon(str(entry["suggested_major"]))
		tile.icon_alignment = HORIZONTAL_ALIGNMENT_CENTER
		tile.vertical_icon_alignment = VERTICAL_ALIGNMENT_TOP
		tile.custom_minimum_size = CLASS_TILE_SIZE
		tile.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		tile.mouse_default_cursor_shape = Control.CURSOR_POINTING_HAND
		tile.pressed.connect(select_class.bind(id))
		grid.add_child(tile)
		_class_tiles[id] = tile

	var lower := HBoxContainer.new()
	lower.theme_type_variation = "ChargenPage"
	lower.size_flags_vertical = Control.SIZE_EXPAND_FILL
	page.add_child(lower)

	var detail := VBoxContainer.new()
	detail.name = "ClassDetail"
	detail.theme_type_variation = "ChargenEntryColumn"
	detail.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	lower.add_child(detail)
	_class_heading = Label.new()
	_class_heading.theme_type_variation = "HeadingLabel"
	detail.add_child(_class_heading)
	_kit_heading = _eyebrow(detail, "")
	_kit_lbl = _blurb(detail)
	var kit_row := HBoxContainer.new()
	kit_row.theme_type_variation = "ChargenTabBar"
	detail.add_child(kit_row)
	_kit_chips.clear()
	for skill_id: String in DramgidSchema.ARMS_SKILL_IDS:
		var chip := _chip(DramgidSchema.skill_label(skill_id), select_kit.bind(skill_id))
		chip.name = "Kit_%s" % skill_id
		kit_row.add_child(chip)
		_kit_chips[skill_id] = chip
	_resource_heading = _eyebrow(detail, "")
	_resource_lbl = _blurb(detail)
	_signature_heading = _eyebrow(detail, "")
	_signature_lbl = _blurb(detail)

	_eyebrow(detail, "TONES  ·  MAJOR AND MINOR BEGIN TRAINED")
	var tones := HBoxContainer.new()
	tones.theme_type_variation = "ChargenTabBar"
	detail.add_child(tones)
	_major_option = _option_column(tones, "Major")
	_minor_option = _option_column(tones, "Minor")
	for option: OptionButton in [_major_option, _minor_option]:
		option.add_item("—  (unentered)")
		for wheel_entry: Dictionary in DS.WHEEL:
			option.add_item("%s  %s" % [wheel_entry["sigil"], wheel_entry["name"]])
	_major_option.item_selected.connect(_on_major_option)
	_minor_option.item_selected.connect(_on_minor_option)
	_mastery_option = _option_column(tones, "Root Note Mastery")
	_mastery_option.item_selected.connect(_on_mastery_option)
	_tones_note = Label.new()
	_tones_note.theme_type_variation = "QuoteLabel"
	_tones_note.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	detail.add_child(_tones_note)

	_eyebrow(detail, "DISCIPLINE  ·  HOW THE BODY MOVES")
	var disciplines := HBoxContainer.new()
	disciplines.theme_type_variation = "ChargenTabBar"
	detail.add_child(disciplines)
	_discipline_chips.clear()
	for entry: Dictionary in ChargenData.DISCIPLINES:
		var id := str(entry["id"])
		var chip := _chip(str(entry["name"]), select_discipline.bind(id))
		chip.name = "Discipline_%s" % id
		disciplines.add_child(chip)
		_discipline_chips[id] = chip
	_discipline_lbl = _blurb(detail)
	_pairing_lbl = Label.new()
	_pairing_lbl.theme_type_variation = "ChargenValidationLabel"
	_pairing_lbl.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	detail.add_child(_pairing_lbl)

	_ability_groups = VBoxContainer.new()
	_ability_groups.name = "AbilityTiles"
	_ability_groups.theme_type_variation = "ChargenEntryColumn"
	_ability_groups.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_ability_groups.size_flags_stretch_ratio = 1.6
	lower.add_child(_ability_groups)
	return page


func _refresh_calling() -> void:
	for id: String in _class_tiles:
		var tile := _class_tiles[id] as Button
		var retired := ClassCatalog.is_retired_pairing(id, build.discipline_id)
		tile.disabled = retired
		tile.set_pressed_no_signal(id == build.class_id and not retired)
		var role := str(ClassCatalog.by_id(id).get("role", ""))
		tile.tooltip_text = ("%s — retired pairing with %s." % [role, _discipline_name()]) if retired else role
	var entry: Dictionary = ClassCatalog.by_id(build.class_id)
	if entry.is_empty():
		_class_heading.text = "CHOOSE A PATRON"
		return
	_class_heading.text = "%s  ·  PATRON %s  ·  %s" % [
		str(entry["name"]).to_upper(), str(entry["patron"]).to_upper(), str(entry["role"]).to_upper(),
	]
	var offers_choice := ClassCatalog.offers_kit_choice(build.class_id)
	_kit_heading.text = "KIT  ·  CHOOSE THE ARMS SKILL IT TRAINS" if offers_choice else (
		"KIT  ·  TRAINS %s" % DramgidSchema.skill_label(build.kit_skill).to_upper()
	)
	_kit_lbl.text = str(entry["kit"])
	var offered: Array = entry.get("kit_skills", [])
	for skill_id: String in _kit_chips:
		var chip := _kit_chips[skill_id] as Button
		chip.visible = offers_choice and skill_id in offered
		chip.set_pressed_no_signal(skill_id == build.kit_skill)
	_resource_heading.text = "RESOURCE  ·  %s" % str(entry["resource"]).to_upper()
	_resource_lbl.text = str(entry["resource_blurb"])
	_signature_heading.text = "SIGNATURE  ·  %s" % str(entry["signature"]).to_upper()
	_signature_lbl.text = str(entry["signature_blurb"])

	_major_option.select(_wheel_index(build.major_element) + 1)
	_minor_option.select(_wheel_index(build.minor_element) + 1)
	_mastery_option.clear()
	var held := build.held_elements()
	for element: String in held:
		_mastery_option.add_item(_wheel_sigil_name(element))
	var mastery_index := held.find(build.mastery_element)
	if mastery_index >= 0:
		_mastery_option.select(mastery_index)
	_mastery_option.disabled = held.is_empty()
	var notes: PackedStringArray = []
	if not build.major_element.is_empty() and not ChargenData.is_valid_element_pair(build.major_element, build.minor_element):
		notes.append("Clash: %s and %s are opposed on the Wheel." % [
			_wheel_name(build.major_element), _wheel_name(build.minor_element)])
	for element: String in held:
		var tone_id := DramgidSchema.tone_skill_for(element)
		notes.append("%s starts Trained at %d%%." % [
			DramgidSchema.skill_label(tone_id), roundi(build.preview_percent(tone_id))])
	if notes.is_empty():
		notes.append("A Major is required; a Minor is optional. Only held tones can be trained in Chapter 1.")
	_tones_note.text = "  ".join(notes)

	for id: String in _discipline_chips:
		(_discipline_chips[id] as Button).set_pressed_no_signal(id == build.discipline_id)
	var discipline: Dictionary = ChargenData.discipline_by_id(build.discipline_id)
	_discipline_lbl.text = "" if discipline.is_empty() else "%s  %s  Favours %s." % [
		discipline["blurb"], discipline["verbs"], _wheel_name(str(discipline["favours"])),
	]
	var pairing := build.validate(&"patron")
	if not bool(pairing["valid"]):
		_pairing_lbl.text = str(pairing["message"])
	elif ClassCatalog.is_watch_pairing(build.class_id, build.discipline_id):
		_pairing_lbl.text = str(entry["notes"])
	else:
		_pairing_lbl.text = ""
	_rebuild_ability_tiles()


## The tiles are rebuilt only when what they show can have changed: the class or the held
## tones. Everything they list comes from KitPreview, the gates combat itself reads.
func _rebuild_ability_tiles() -> void:
	var member := build.scratch_member()
	var key := "%s|%s|%s" % [build.class_id, member.major_element, member.minor_element]
	if key == _ability_key:
		return
	_ability_key = key
	_hide_card(_card_source)
	for child: Node in _ability_groups.get_children():
		_ability_groups.remove_child(child)
		child.queue_free()
	var groups := KitPreview.for_member(member)
	var class_name_text := str(ClassCatalog.by_id(build.class_id).get("name", ""))

	var own := _tile_group("WHAT %s ADDS" % class_name_text.to_upper(), "ClassAbilities")
	for entry: Dictionary in groups[KitPreview.CLASS]:
		own.add_child(_ability_tile(entry, KitPreview.CLASS))
	if (groups[KitPreview.CLASS] as Array).is_empty():
		_ability_groups.add_child(_quote("No actions of its own yet."))

	var held := KitPreview.held_elements(member)
	var held_names: PackedStringArray = []
	for element: StringName in held:
		held_names.append(_wheel_name(String(element)).to_upper())
	var tones := _tile_group(
		("YOUR TONES  ·  %s" % " AND ".join(held_names)) if not held_names.is_empty() else "YOUR TONES",
		"ToneAbilities",
	)
	var spells_per_tone: Dictionary = {}
	for entry: Dictionary in groups[KitPreview.TONES]:
		tones.add_child(_ability_tile(entry, KitPreview.TONES))
		var element := (entry["action"] as CombatAction).element_id
		spells_per_tone[element] = int(spells_per_tone.get(element, 0)) + 1
	for element: StringName in held:
		if not spells_per_tone.has(element):
			_ability_groups.add_child(_quote("No %s spells yet." % _wheel_name(String(element))))
	var others := (groups[KitPreview.OTHER_TONES] as Array).size()
	if others > 0:
		# Tones do not gate casting yet (owner-list item 27): say so instead of implying a lock.
		_ability_groups.add_child(_quote(
			"+%d spells in other tones — every class can cast them today." % others))

	var common := _tile_group("EVERY BODY CAN", "CommonAbilities")
	for entry: Dictionary in groups[KitPreview.COMMON]:
		common.add_child(_ability_tile(entry, KitPreview.COMMON))


func _tile_group(heading: String, flow_name: String) -> HFlowContainer:
	var header := Label.new()
	header.text = heading
	header.theme_type_variation = "ChargenGroupHeader"
	_ability_groups.add_child(header)
	var flow := HFlowContainer.new()
	flow.name = flow_name
	flow.theme_type_variation = "ChargenTileFlow"
	_ability_groups.add_child(flow)
	return flow


func _ability_tile(entry: Dictionary, group: StringName) -> Button:
	var action := entry["action"] as CombatAction
	var tile := Button.new()
	tile.name = "Ability_%s" % String(action.id).replace("-", "_")
	tile.theme_type_variation = "ChargenAbilityTile" if str(entry["lock"]).is_empty() else "ChargenAbilityTileLocked"
	tile.text = action.display_name
	tile.icon = _action_icon(action)
	tile.icon_alignment = HORIZONTAL_ALIGNMENT_CENTER
	tile.vertical_icon_alignment = VERTICAL_ALIGNMENT_TOP
	tile.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	tile.custom_minimum_size = ABILITY_TILE_SIZE
	tile.set_meta("action_id", action.id)
	tile.set_meta("group", group)
	# AP round economy: AP is the shipped scheduler (Gate T-10, battle_actor.gd), so the tile
	# shows the same `ap_cost` the battle bar charges.
	var cost := Label.new()
	cost.theme_type_variation = "ChargenTileCost"
	cost.text = "%d AP" % action.ap_cost
	cost.mouse_filter = Control.MOUSE_FILTER_IGNORE
	cost.set_anchors_and_offsets_preset(Control.PRESET_TOP_RIGHT, Control.PRESET_MODE_MINSIZE, DS.SPACE_2)
	tile.add_child(cost)
	tile.mouse_entered.connect(_show_card.bind(tile, entry))
	tile.focus_entered.connect(_show_card.bind(tile, entry))
	tile.mouse_exited.connect(_hide_card.bind(tile))
	tile.focus_exited.connect(_hide_card.bind(tile))
	return tile


# --- the hover card -------------------------------------------------------------------------

func _build_ability_card() -> void:
	_ability_card = PanelContainer.new()
	_ability_card.name = "AbilityCard"
	_ability_card.theme_type_variation = "ChargenAbilityCard"
	_ability_card.top_level = true
	_ability_card.z_index = 1
	_ability_card.visible = false
	_ability_card.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_ability_card.custom_minimum_size = Vector2(CARD_WIDTH, 0)
	var column := VBoxContainer.new()
	column.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_ability_card.add_child(column)
	_card_title = _card_label(column, "ChargenCardTitle")
	_card_stats = _card_label(column, "ChargenCardStats")
	_card_effect = _card_label(column, "ChargenCardEffect")
	_card_lock = _card_label(column, "ChargenCardLock")
	add_child(_ability_card)


func _card_label(parent: Container, type_variation: String) -> Label:
	var lbl := Label.new()
	lbl.theme_type_variation = type_variation
	lbl.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	lbl.custom_minimum_size = Vector2(CARD_WIDTH - DS.SPACE_6 * 2, 0)
	lbl.mouse_filter = Control.MOUSE_FILTER_IGNORE
	parent.add_child(lbl)
	return lbl


func _show_card(tile: Control, entry: Dictionary) -> void:
	var action := entry["action"] as CombatAction
	_card_source = tile
	_card_title.text = action.display_name
	var stats: PackedStringArray = []
	if not String(action.element_id).is_empty():
		stats.append("Tone %s" % _wheel_name(String(action.element_id)))
	if action.aoe_shape != &"single":
		stats.append("Area %s" % String(action.aoe_shape).capitalize())
	_card_stats.text = "  ·  ".join(stats)
	_card_stats.visible = not stats.is_empty()
	_card_effect.text = action.summary()
	var lock := str(entry["lock"])
	var tier := KitPreview.tier_of(action)
	if lock.is_empty() and tier >= 2:
		lock = "A %s working: Var Harmony %d or higher in battle." % [
			"triad" if tier >= 3 else "chord",
			CastingGate.TRIAD_MIN_HARMONY if tier >= 3 else CastingGate.CHORD_MIN_HARMONY,
		]
	_card_lock.text = lock
	# A signature's own description already names its perk; say it once.
	_card_lock.visible = not lock.is_empty() and not _card_effect.text.contains(lock)
	_ability_card.visible = true
	_ability_card.reset_size()
	_place_card(tile)


func _place_card(tile: Control) -> void:
	var rect := tile.get_global_rect()
	var card_size := _ability_card.get_combined_minimum_size()
	var view := get_viewport_rect().size
	var at := Vector2(rect.position.x, rect.end.y + DS.SPACE_2)
	if at.y + card_size.y > view.y:
		at.y = rect.position.y - card_size.y - DS.SPACE_2
	at.x = clampf(at.x, 0.0, maxf(view.x - card_size.x, 0.0))
	_ability_card.global_position = at


func _hide_card(tile: Control) -> void:
	if _ability_card != null and tile == _card_source:
		_ability_card.visible = false
		_card_source = null


## The card currently shown, for tests and captures: {} when hidden.
func ability_card_text() -> Dictionary:
	if _ability_card == null or not _ability_card.visible:
		return {}
	return {"title": _card_title.text, "effect": _card_effect.text,
		"lock": _card_lock.text if _card_lock.visible else ""}


# --- MEASURES: attributes and creation points -----------------------------------------------

func _build_measures_tab() -> Control:
	var page := HBoxContainer.new()
	page.name = "Page_measures"
	page.theme_type_variation = "ChargenPage"
	page.size_flags_vertical = Control.SIZE_EXPAND_FILL

	var measures := _form_column(page, "THE SEVEN MEASURES  ·  FIXED AT CREATION")
	_points_lbl = Label.new()
	_points_lbl.theme_type_variation = "StatLabel"
	measures.add_child(_points_lbl)
	_attribute_bars.clear()
	_attribute_value_lbls.clear()
	for attribute_id: String in DramgidSchema.ATTRIBUTE_IDS:
		measures.add_child(_build_attribute_row(attribute_id))
	_attribute_readout = Label.new()
	_attribute_readout.theme_type_variation = "ChargenSummaryText"
	_attribute_readout.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	measures.add_child(_attribute_readout)

	var skills := _form_column(page, "SKILLS  ·  THE CREATION POOL")
	_skills_pool_lbl = Label.new()
	_skills_pool_lbl.theme_type_variation = "StatLabel"
	skills.add_child(_skills_pool_lbl)
	skills.add_child(_quote(
		"Each +5% step costs 1 point up to 50%, 2 to 75%, 3 to 95%. ◆ marks a Trained tag. Unspent points carry into play."))
	var scroll := ScrollContainer.new()
	scroll.name = "SkillsScroll"
	scroll.custom_minimum_size = Vector2(0, 470)
	scroll.size_flags_vertical = Control.SIZE_EXPAND_FILL
	scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	skills.add_child(scroll)
	_skills_form = VBoxContainer.new()
	_skills_form.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	scroll.add_child(_skills_form)
	return page


func _build_attribute_row(attribute_id: String) -> Control:
	var row := HBoxContainer.new()
	row.theme_type_variation = "BattleHudRow"
	var info := VBoxContainer.new()
	info.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	row.add_child(info)
	var name_lbl := Label.new()
	name_lbl.text = "%s  —  %s" % [DramgidSchema.attribute_label(attribute_id), ChargenData.attribute_hint(attribute_id)]
	name_lbl.theme_type_variation = "MutedLabel"
	info.add_child(name_lbl)
	var bar := ProgressBar.new()
	bar.custom_minimum_size = Vector2(0, 8)
	bar.show_percentage = false
	bar.min_value = DramgidSchema.ATTRIBUTE_FLOOR
	bar.max_value = DramgidSchema.ATTRIBUTE_CAP
	info.add_child(bar)
	_attribute_bars[attribute_id] = bar
	var minus_btn := Button.new()
	minus_btn.name = "Minus_%s" % attribute_id
	minus_btn.text = "−"
	minus_btn.pressed.connect(_on_attribute_step.bind(attribute_id, -1))
	row.add_child(minus_btn)
	var value_lbl := Label.new()
	value_lbl.theme_type_variation = "StatLabel"
	value_lbl.custom_minimum_size = Vector2(32, 0)
	value_lbl.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	row.add_child(value_lbl)
	_attribute_value_lbls[attribute_id] = value_lbl
	var plus_btn := Button.new()
	plus_btn.name = "Plus_%s" % attribute_id
	plus_btn.text = "+"
	plus_btn.pressed.connect(_on_attribute_step.bind(attribute_id, 1))
	row.add_child(plus_btn)
	return row


func _on_attribute_step(attribute_id: String, delta: int) -> void:
	if not build.step_attribute(attribute_id, delta):
		if delta > 0:
			_flash_points_denied()
		return
	_animate_attribute_change(attribute_id)
	_refresh_all()


func _animate_attribute_change(attribute_id: String) -> void:
	var bar := _attribute_bars.get(attribute_id) as ProgressBar
	if bar == null:
		return
	var previous := _attribute_tweens.get(attribute_id) as Tween
	if previous != null:
		previous.kill()
	var tween := create_tween()
	_attribute_tweens[attribute_id] = tween
	tween.tween_property(bar, "value", build.attributes[attribute_id], DS.DUR_INSTANT)


func _flash_points_denied() -> void:
	var original_color := _points_lbl.modulate
	var tween := create_tween()
	tween.tween_property(_points_lbl, "modulate", DS.GILD_2, DS.DUR_INSTANT)
	tween.parallel().tween_property(_points_lbl, "rotation", deg_to_rad(6.0), 0.04)
	tween.tween_property(_points_lbl, "rotation", deg_to_rad(-6.0), 0.04)
	tween.tween_property(_points_lbl, "rotation", 0.0, 0.04)
	tween.tween_property(_points_lbl, "modulate", original_color, DS.DUR_FAST)


func _refresh_measures() -> void:
	for attribute_id: String in DramgidSchema.ATTRIBUTE_IDS:
		var value := int(build.attributes.get(attribute_id, DramgidSchema.ATTRIBUTE_FLOOR))
		if not _attribute_tweens.has(attribute_id) or not (_attribute_tweens[attribute_id] as Tween).is_running():
			(_attribute_bars[attribute_id] as ProgressBar).value = value
		(_attribute_value_lbls[attribute_id] as Label).text = str(value)
	var remaining := build.remaining_attribute_points()
	_points_lbl.text = "%d MEASURE POINTS UNSPENT" % remaining if remaining > 0 else "EVERY MEASURE POINT PLACED"
	_points_lbl.modulate = DS.GILD_2 if remaining > 0 else DS.STATE_CONSTANT
	var lines: PackedStringArray = []
	if not build.kit_skill.is_empty():
		lines.append("%s (Kit): %d%%" % [DramgidSchema.skill_label(build.kit_skill),
			roundi(build.preview_percent(build.kit_skill))])
	for tone_id: String in build.held_tones():
		lines.append("%s: %d%%" % [DramgidSchema.skill_label(tone_id), roundi(build.preview_percent(tone_id))])
	var ancestry: Dictionary = ChargenData.ancestry_by_id(build.ancestry_id)
	if not ancestry.is_empty():
		lines.append("%s lean: %s (a nudge, never a bonus)" % [ancestry["name"], ancestry["leans"]])
	_attribute_readout.text = "\n".join(lines)
	var purchasable := ",".join(build.purchasable_skills())
	if purchasable != _skills_key:
		_rebuild_skill_rows()
	_refresh_skills()


## Rows are rebuilt when the set of purchasable skills changes (ancestry, kit, tones or
## background moved); buy/refund refreshes them in place.
func _rebuild_skill_rows() -> void:
	_skills_key = ",".join(build.purchasable_skills())
	for child: Node in _skills_form.get_children():
		_skills_form.remove_child(child)
		child.queue_free()
	_skill_rows.clear()
	var purchasable := build.purchasable_skills()
	for group: String in DramgidSchema.SKILL_GROUPS:
		var members: PackedStringArray = []
		for skill_id: String in DramgidSchema.skills_in_group(group):
			if purchasable.has(skill_id):
				members.append(skill_id)
		if members.is_empty():
			continue
		var header := Label.new()
		header.text = DramgidSchema.group_label(group).to_upper()
		header.theme_type_variation = "ChargenGroupHeader"
		_skills_form.add_child(header)
		for skill_id: String in members:
			_skills_form.add_child(_build_skill_row(skill_id))


func _build_skill_row(skill_id: String) -> Control:
	var row := HBoxContainer.new()
	row.theme_type_variation = "ChargenSkillRow"
	var name_lbl := Label.new()
	name_lbl.text = DramgidSchema.skill_label(skill_id)
	name_lbl.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	row.add_child(name_lbl)
	var mark_lbl := Label.new()
	mark_lbl.theme_type_variation = "MutedLabel"
	mark_lbl.text = str(ATTRIBUTE_MARKS.get(DramgidSchema.governing_attribute(skill_id), ""))
	mark_lbl.custom_minimum_size = Vector2(28, 0)
	row.add_child(mark_lbl)
	var tier_lbl := Label.new()
	tier_lbl.custom_minimum_size = Vector2(28, 0)
	row.add_child(tier_lbl)
	var pct_lbl := Label.new()
	pct_lbl.name = "Percent_%s" % skill_id
	pct_lbl.theme_type_variation = "StatLabel"
	pct_lbl.custom_minimum_size = Vector2(48, 0)
	pct_lbl.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
	row.add_child(pct_lbl)
	var refund_btn := Button.new()
	refund_btn.name = "Refund_%s" % skill_id
	refund_btn.text = "−"
	refund_btn.pressed.connect(refund_skill.bind(skill_id))
	row.add_child(refund_btn)
	var buy_btn := Button.new()
	buy_btn.name = "Buy_%s" % skill_id
	buy_btn.pressed.connect(buy_skill.bind(skill_id))
	row.add_child(buy_btn)
	_skill_rows[skill_id] = {"tier": tier_lbl, "percent": pct_lbl, "refund": refund_btn, "buy": buy_btn}
	return row


func _refresh_skills() -> void:
	_skills_pool_lbl.text = "%d OF %d CREATION POINTS LEFT" % [build.points_remaining(), build.creation_pool()]
	for skill_id: String in _skill_rows:
		var widgets: Dictionary = _skill_rows[skill_id]
		(widgets["tier"] as Label).text = str(TIER_MARKS.get(build.tier_of(skill_id), ""))
		var steps := build.steps_bought(skill_id)
		(widgets["percent"] as Label).text = "%d%%%s" % [
			roundi(build.preview_percent(skill_id)), "  (+%d)" % int(build.bought_percent(skill_id)) if steps > 0 else ""]
		(widgets["refund"] as Button).disabled = steps == 0
		var gate := build.can_buy(skill_id)
		var buy := widgets["buy"] as Button
		if str(gate["blocked_by"]) == "effective_cap":
			buy.text = "at cap"
		else:
			var cost := int(gate["cost"])
			if cost <= 0:
				cost = maxi(Advancement.step_cost(build.scratch_member(), skill_id), 1)
			buy.text = "+5%%  (%d pt)" % cost
		buy.disabled = not gate["allowed"]
		buy.tooltip_text = str(gate["message"])


# --- NAME: likeness, epithet, flaw ----------------------------------------------------------

func _build_name_tab() -> Control:
	var page := HBoxContainer.new()
	page.name = "Page_name"
	page.theme_type_variation = "ChargenPage"
	page.size_flags_vertical = Control.SIZE_EXPAND_FILL

	var likeness := _form_column(page, "LIKENESS OF RECORD")
	var grid := GridContainer.new()
	grid.columns = 6
	grid.theme_type_variation = "ChargenTileGrid"
	likeness.add_child(grid)
	_likeness_buttons.clear()
	for entry: Dictionary in ChargenData.LIKENESSES:
		var likeness_id := str(entry.get("id", ""))
		var btn := Button.new()
		btn.name = "Likeness_%s" % likeness_id
		btn.theme_type_variation = "ChargenPortraitButton"
		btn.custom_minimum_size = Vector2(96, 128)
		btn.toggle_mode = true
		btn.expand_icon = true
		btn.icon = ChargenArtResolverScript.portrait_texture(likeness_id)
		btn.tooltip_text = str(entry.get("label", likeness_id))
		btn.pressed.connect(select_likeness.bind(likeness_id))
		btn.set_meta("likeness_id", likeness_id)
		grid.add_child(btn)
		_likeness_buttons.append(btn)

	var words := _form_column(page, "THE PUBLIC RECORD")
	words.add_child(_quote("The name sits at the top of the entry, on every tab."))
	_epithet_edit = _labelled_line_edit(words, "Epithet", "the unbowed, the quiet, …")
	_epithet_edit.text_changed.connect(set_epithet)
	_flaw_edit = _labelled_line_edit(words, "Flaw (optional)", "A Waning-flavored complication, if any")
	_flaw_edit.text_changed.connect(set_flaw)
	return page


func _refresh_name() -> void:
	for btn: Button in _likeness_buttons:
		btn.set_pressed_no_signal(str(btn.get_meta("likeness_id", "")) == build.likeness_id)
	if _epithet_edit.text != build.epithet:
		_epithet_edit.text = build.epithet
	if _flaw_edit.text != build.flaw:
		_flaw_edit.text = build.flaw


# --- tabs, status and refresh ---------------------------------------------------------------

func _show_tab(tab_id: StringName) -> void:
	if not _tab_pages.has(tab_id):
		return
	_tab_id = tab_id
	_hide_card(_card_source)
	for id: StringName in _tab_pages:
		(_tab_pages[id] as Control).visible = id == tab_id
	_update_status()
	call_deferred("_focus_tab")


func _focus_first_control() -> void:
	_focus_tab()


## Focus the tab's current choice (the chosen class on CALLING), else its first control.
func _focus_tab() -> void:
	if not is_inside_tree():
		return
	var preferred: Control = null
	match _tab_id:
		&"origin":
			preferred = _ancestry_rows.get(build.ancestry_id) as Control
		&"calling":
			preferred = _class_tiles.get(build.class_id) as Control
		&"name":
			preferred = _name_edit if build.display_name.strip_edges().is_empty() else null
	if preferred == null or not preferred.is_visible_in_tree():
		preferred = _find_first_focusable(_tab_pages[_tab_id] as Node)
	if preferred != null:
		preferred.grab_focus()


## The first leaf that still blocks BEGIN, in tab order: {tab, step, message}, or {}.
func _blocking_verdict() -> Dictionary:
	for tab: Dictionary in ChargenSteps.TABS:
		for step_id: StringName in tab["steps"]:
			var verdict := build.validate(step_id)
			if not bool(verdict["valid"]):
				return {"tab": tab["id"], "step": step_id, "message": str(verdict["message"])}
	return {}


func _status_text() -> String:
	var blocking := _blocking_verdict()
	if not blocking.is_empty():
		if blocking["step"] == &"identity":
			return "Name the entry to begin"
		return "%s  ·  %s" % [_tab_name(blocking["tab"]), blocking["message"]]
	var remaining := build.points_remaining()
	if remaining > 0:
		return "%d skill point%s unspent — they carry into play" % [remaining, "" if remaining == 1 else "s"]
	return "Entry ready — BEGIN when you are"


func _update_status() -> void:
	if _begin_btn == null:
		return
	for tab: Dictionary in ChargenSteps.TABS:
		var tab_id: StringName = tab["id"]
		var text := str(tab["name"])
		if tab_id == &"measures" and build.points_remaining() > 0:
			text += "  ·  %d PTS" % build.points_remaining()
		for step_id: StringName in tab["steps"]:
			if not bool(build.validate(step_id)["valid"]):
				text += "  •"
				break
		var btn := _tab_buttons[tab_id] as Button
		btn.text = text
		btn.set_pressed_no_signal(tab_id == _tab_id)
	_status_lbl.text = _status_text()
	_eyebrow_lbl.text = "FORM 7, IN TRIPLICATE  ·  %s" % ("ENTRY READY" if build.is_complete() else "ENTRY PENDING")
	if _quick_start_btn != null:
		_quick_start_btn.visible = mode == Mode.PLAYER
	_cancel_btn.visible = not flow_owned


func _refresh_all() -> void:
	if _begin_btn == null:
		return
	if _rolled_purchases and build.creation_buys.is_empty() and build.points_remaining() > 0:
		ChargenRandomizer.spend_creation_points(_random_rng, build)
	_refresh_entry()
	_refresh_origin()
	_refresh_calling()
	_refresh_measures()
	_refresh_name()
	_update_status()


func _on_cancel_pressed() -> void:
	if not flow_owned:
		close()


# --- public driving API (docs §7.4) ---------------------------------------------------------

func current_tab_id() -> StringName:
	return _tab_id


func go_to_tab(tab_id: StringName) -> void:
	_show_tab(tab_id)


## Shows the tab that holds a leaf ("summary" opens the first tab).
func go_to_step(step_id: StringName) -> void:
	_show_tab(ChargenSteps.tab_of(step_id))


## RANDOMIZE ALL: every tab rolled, the typed name kept.
func randomize_character() -> void:
	_kill_attribute_tweens()
	_rolled_purchases = true
	build = ChargenRandomizer.roll(_random_rng, build)
	_refresh_all()


## ROLL THIS TAB: only the open tab's choices are rolled; the other tabs keep theirs.
func roll_tab() -> void:
	_kill_attribute_tweens()
	if _tab_id == &"measures":
		_rolled_purchases = true
	build = ChargenRandomizer.roll_tab(_random_rng, build, _tab_id)
	_refresh_all()


## BEGIN from any tab. With a blank name it puts the cursor in the name field; any other
## unfinished leaf opens its tab. A complete entry is accepted.
func begin() -> void:
	_refresh_all()
	var blocking := _blocking_verdict()
	if blocking.is_empty():
		await accept()
		return
	if blocking["step"] == &"identity":
		# Deferred, so a tab switch's own deferred focus cannot take the cursor back.
		_name_edit.call_deferred("grab_focus")
	else:
		_show_tab(blocking["tab"])
	_flash_status()


## Debug playtest path for the player's own entry: roll everything, give an unnamed hero
## the stand-in name (a typed name stays) and accept into the game.
func quick_start() -> void:
	if not OS.is_debug_build() or mode != Mode.PLAYER:
		return
	if _quick_start_btn != null:
		_quick_start_btn.disabled = true
	randomize_character()
	if build.display_name.strip_edges().is_empty():
		set_display_name(QUICK_START_NAME)
	await accept()


func select_ancestry(id: String) -> void:
	build.select_ancestry(id)
	_refresh_all()


func select_discipline(id: String) -> void:
	build.select_discipline(id)
	_refresh_all()


## Picking a class applies its suggested tones, so the tiles show the spells it is built
## around (Locksmirk suggests none and keeps the current pair). The tones stay editable.
func select_class(id: String) -> void:
	if ClassCatalog.is_retired_pairing(id, build.discipline_id):
		_refresh_all()
		return
	var changed := id != build.class_id
	build.select_class(id)
	if changed and not str(ClassCatalog.by_id(id).get("suggested_major", "")).is_empty():
		build.apply_suggested_elements()
	_refresh_all()


func select_kit(arms_skill: String) -> bool:
	var ok := build.select_kit(arms_skill)
	_refresh_all()
	return ok


func select_major(id: String) -> void:
	build.select_major(id)
	_refresh_all()


func select_minor(id: String) -> void:
	build.select_minor(id)
	_refresh_all()


func select_mastery(element: String) -> bool:
	var ok := build.select_mastery(element)
	_refresh_all()
	return ok


func set_attribute(id: String, value: int) -> bool:
	var ok := build.set_attribute(id, value)
	_refresh_all()
	return ok


func select_background(id: String) -> void:
	build.select_background(id)
	_refresh_all()


func buy_skill(skill_id: String) -> Dictionary:
	var result := build.buy(skill_id)
	if result["allowed"]:
		_rolled_purchases = false
		_refresh_skills()
		_update_status()
	else:
		_status_lbl.text = str(result["message"])
	return result


func refund_skill(skill_id: String) -> Dictionary:
	var result := build.refund(skill_id)
	if result["allowed"]:
		_rolled_purchases = false
		_refresh_skills()
		_update_status()
	return result


func set_display_name(text: String) -> void:
	build.display_name = text
	_refresh_all()


func set_epithet(text: String) -> void:
	build.epithet = text
	_refresh_all()


func set_flaw(text: String) -> void:
	build.flaw = text.strip_edges()
	_refresh_all()


func select_likeness(id: String) -> void:
	build.likeness_id = id
	_refresh_all()


## ACCEPT: build → register (id assigned) → seed the creation ledger → juice → event/close.
func accept() -> void:
	_refresh_all()
	if not build.is_complete():
		return
	var member := build.to_party_member()
	member.portrait = ChargenArtResolverScript.portrait_texture(build.likeness_id)
	if mode == Mode.RECRUIT:
		GameState.add_custom_recruit(member)
	else:
		GameState.apply_created_character(member)
	Advancement.seed_creation_ledger(member, build.creation_ledger_rows())
	_play_accept_juice()
	recruit_created.emit(member)
	await get_tree().create_timer(0.35).timeout
	if mode == Mode.PLAYER:
		GameFlow.send_event("new_game")
	else:
		close()


func _play_accept_juice() -> void:
	_begin_btn.disabled = true
	var player := AudioStreamPlayer.new()
	player.stream = STAMP_SOUND
	add_child(player)
	player.finished.connect(player.queue_free)
	player.play()
	_eyebrow_lbl.text = "FORM 7, IN TRIPLICATE  ·  RECORDED"
	var tween := create_tween()
	_flash_rect.modulate.a = 0.9
	tween.tween_property(_flash_rect, "modulate:a", 0.0, DS.DUR_FAST)


func _flash_status() -> void:
	var tween := create_tween()
	_status_lbl.modulate = DS.GILD_2
	tween.tween_property(_status_lbl, "modulate", Color.WHITE, DS.DUR_SLOW)


# --- helpers --------------------------------------------------------------------------------

func _kill_attribute_tweens() -> void:
	for tween: Tween in _attribute_tweens.values():
		tween.kill()
	_attribute_tweens.clear()


func _on_major_option(index: int) -> void:
	select_major("" if index == 0 else str(DS.WHEEL[index - 1]["id"]))


func _on_minor_option(index: int) -> void:
	select_minor("" if index == 0 else str(DS.WHEEL[index - 1]["id"]))


func _on_mastery_option(index: int) -> void:
	var held := build.held_elements()
	if index >= 0 and index < held.size():
		select_mastery(held[index])


func _form_column(parent: Container, heading: String) -> VBoxContainer:
	var form := VBoxContainer.new()
	form.theme_type_variation = "ChargenFormColumn"
	form.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	parent.add_child(form)
	_eyebrow(form, heading)
	return form


func _eyebrow(parent: Container, text: String) -> Label:
	var lbl := Label.new()
	lbl.text = text
	lbl.theme_type_variation = "EyebrowLabel"
	parent.add_child(lbl)
	return lbl


func _blurb(parent: Container) -> Label:
	var lbl := Label.new()
	lbl.theme_type_variation = "ChargenBlurb"
	lbl.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	parent.add_child(lbl)
	return lbl


func _quote(text: String) -> Label:
	var lbl := Label.new()
	lbl.text = text
	lbl.theme_type_variation = "QuoteLabel"
	lbl.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	return lbl


func _choice_button(text: String, cb: Callable) -> Button:
	var btn := Button.new()
	btn.theme_type_variation = "ChargenChoiceButton"
	btn.toggle_mode = true
	btn.text = text
	btn.alignment = HORIZONTAL_ALIGNMENT_LEFT
	btn.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	btn.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	btn.mouse_default_cursor_shape = Control.CURSOR_POINTING_HAND
	btn.pressed.connect(cb)
	return btn


func _chip(text: String, cb: Callable) -> Button:
	var chip := Button.new()
	chip.theme_type_variation = "ChargenChip"
	chip.toggle_mode = true
	chip.text = text
	chip.mouse_default_cursor_shape = Control.CURSOR_POINTING_HAND
	chip.pressed.connect(cb)
	return chip


func _option_column(parent: Container, label_text: String) -> OptionButton:
	var column := VBoxContainer.new()
	column.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	parent.add_child(column)
	var lbl := Label.new()
	lbl.text = label_text
	lbl.theme_type_variation = "MutedLabel"
	column.add_child(lbl)
	var option := OptionButton.new()
	option.mouse_default_cursor_shape = Control.CURSOR_POINTING_HAND
	column.add_child(option)
	return option


func _labelled_line_edit(parent: Control, label_text: String, placeholder: String) -> LineEdit:
	var lbl := Label.new()
	lbl.text = label_text
	lbl.theme_type_variation = "MutedLabel"
	parent.add_child(lbl)
	var edit := LineEdit.new()
	edit.placeholder_text = placeholder
	parent.add_child(edit)
	return edit


func _tab_name(tab_id: StringName) -> String:
	for tab: Dictionary in ChargenSteps.TABS:
		if tab["id"] == tab_id:
			return str(tab["name"])
	return ""


func _discipline_name() -> String:
	return str(ChargenData.discipline_by_id(build.discipline_id).get("name", build.discipline_id))


func _wheel_index(id: String) -> int:
	for index: int in DS.WHEEL.size():
		if str(DS.WHEEL[index]["id"]) == id:
			return index
	return -1


func _wheel_name(id: String) -> String:
	var index := _wheel_index(id)
	return str(DS.WHEEL[index]["name"]) if index >= 0 else ""


func _wheel_sigil_name(id: String) -> String:
	var index := _wheel_index(id)
	return "%s %s" % [DS.WHEEL[index]["sigil"], DS.WHEEL[index]["name"]] if index >= 0 else ""


static func _element_icon(element: String) -> Texture2D:
	if element.is_empty() or not ResourceLoader.exists(ELEMENT_ICON % element):
		return null
	return load(ELEMENT_ICON % element) as Texture2D


## Placeholder glyphs until the art pass: a spell shows its tone; commands use the battle
## command icons by kind.
static func _action_icon(action: CombatAction) -> Texture2D:
	if not String(action.element_id).is_empty():
		return _element_icon(String(action.element_id))
	var icon := "strike"
	match action.kind:
		CombatAction.Kind.GUARD:
			icon = "guard"
		CombatAction.Kind.STABILIZE:
			icon = "focus" if action.id == &"focus" else "stabilize"
		CombatAction.Kind.DEFINING_STRIKE:
			icon = "definition"
		CombatAction.Kind.CAST:
			icon = "cast"
		CombatAction.Kind.PASS:
			icon = "paradox"
		_:
			if action.target_profile != &"melee":
				icon = "target"
	return load(COMMAND_ICON % icon) as Texture2D
