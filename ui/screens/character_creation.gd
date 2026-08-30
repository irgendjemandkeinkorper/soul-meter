class_name CharacterCreationScreen
extends Screen
## The Register of Persons — a seven-page illustrated Form 7 backed exclusively by
## the ratified rules in ChargenData and SkillCheckService. Both the boot-time player
## path and the tavern's reusable recruit path share this exact wizard.

signal recruit_created(member: PartyMember)

enum Mode { PLAYER, RECRUIT }

const ChargenArtResolverScript := preload("res://ui/screens/chargen/chargen_art_resolver.gd")
const STAMP_SOUND := preload("res://assets/audio/sfx/impactPlate_heavy_000.ogg")

const STEP_ANCESTRY := 0
const STEP_CALLING := 1
const STEP_ELEMENTS := 2
const STEP_ATTRIBUTES := 3
const STEP_SKILLS := 4
const STEP_IDENTITY := 5
const STEP_SUMMARY := 6
const STEP_COUNT := 7
const STEP_NAMES: PackedStringArray = [
	"Ancestry", "Calling", "Elements", "Attributes", "Skills", "Identity", "Summary",
]

var mode: Mode = Mode.PLAYER

var _attributes: Dictionary = ChargenData.default_attributes()
var _ancestry_id := ""
var _background_id := ""
var _discipline_id := ""
var _patron_id := ""
var _major_element := ""
var _minor_element := ""
var _flaw_text := ""
var _likeness_id: String = str(ChargenData.LIKENESSES[0]["id"])

var _step_index := STEP_ANCESTRY
var _step_pages: Array[Control] = []
var _step_markers: Array[Label] = []
var _page_focusables: Dictionary = {}

var _name_edit: LineEdit
var _epithet_edit: LineEdit
var _points_lbl: Label
var _accept_btn: Button
var _next_btn: Button
var _back_btn: Button
var _step_status_lbl: Label
var _validation_lbl: Label
var _summary_lbl: Label
var _eyebrow_lbl: Label
var _ancestry_art: TextureRect
var _ancestry_art_fallback: Label
var _identity_portrait: TextureRect
var _identity_portrait_fallback: Label
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
	# Player chargen remains flow-owned and uncancellable. Recruit chargen remains a
	# normal stack screen, so cancelling page one returns to the tavern as before.
	allow_back = false
	_add_opaque_backdrop(DS.STONE_0)
	var content := _make_shell_window("THE REGISTER OF PERSONS")

	_eyebrow_lbl = Label.new()
	_eyebrow_lbl.text = "FORM 7, IN TRIPLICATE  ·  ENTRY PENDING"
	_eyebrow_lbl.theme_type_variation = "EyebrowLabel"
	shell_body.get_parent().add_child(_eyebrow_lbl)
	shell_body.get_parent().move_child(_eyebrow_lbl, shell_body.get_index())

	_points_lbl = Label.new()
	_points_lbl.theme_type_variation = "StatLabel"
	shell_header.add_child(_points_lbl)

	_build_step_rail(content)

	var page_host := VBoxContainer.new()
	page_host.name = "WizardPages"
	page_host.size_flags_vertical = Control.SIZE_EXPAND_FILL
	content.add_child(page_host)
	_step_pages = [
		_build_ancestry_page(),
		_build_calling_page(),
		_build_elements_page(),
		_build_attributes_page(),
		_build_skills_page(),
		_build_identity_page(),
		_build_summary_page(),
	]
	for page: Control in _step_pages:
		page_host.add_child(page)

	_build_navigation(content)
	_build_flash()
	_refresh_all()
	_show_step(STEP_ANCESTRY)


func _build_step_rail(parent: VBoxContainer) -> void:
	var rail := HBoxContainer.new()
	rail.theme_type_variation = "ChargenStepRail"
	parent.add_child(rail)
	for index: int in STEP_COUNT:
		var marker := Label.new()
		marker.theme_type_variation = "ChargenStepMarker"
		marker.text = "%d  %s" % [index + 1, STEP_NAMES[index]]
		marker.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		rail.add_child(marker)
		_step_markers.append(marker)


func _new_page(title_text: String, registry_note: String, illustration_title: String,
		illustration_copy: String) -> Dictionary:
	var page := HBoxContainer.new()
	page.theme_type_variation = "ChargenPage"
	page.custom_minimum_size = Vector2(0, 510)
	page.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	page.size_flags_vertical = Control.SIZE_EXPAND_FILL

	var illustration_frame := PanelContainer.new()
	illustration_frame.theme_type_variation = "ChargenIllustrationFrame"
	illustration_frame.custom_minimum_size = Vector2(400, 480)
	illustration_frame.size_flags_vertical = Control.SIZE_EXPAND_FILL
	page.add_child(illustration_frame)

	var illustration := VBoxContainer.new()
	illustration.theme_type_variation = "ChargenIllustrationColumn"
	illustration_frame.add_child(illustration)

	var plate := Label.new()
	plate.text = illustration_title
	plate.theme_type_variation = "ChargenIllustrationTitle"
	plate.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	illustration.add_child(plate)

	var illustration_body := Label.new()
	illustration_body.text = illustration_copy
	illustration_body.theme_type_variation = "QuoteLabel"
	illustration_body.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	illustration_body.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	illustration_body.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	illustration_body.size_flags_vertical = Control.SIZE_EXPAND_FILL
	illustration.add_child(illustration_body)

	var form := VBoxContainer.new()
	form.theme_type_variation = "ChargenFormColumn"
	form.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	form.size_flags_vertical = Control.SIZE_EXPAND_FILL
	page.add_child(form)

	var title := Label.new()
	title.text = title_text
	title.theme_type_variation = "HeadingLabel"
	form.add_child(title)

	var note := Label.new()
	note.text = "FORM 7, IN TRIPLICATE  ·  %s" % registry_note
	note.theme_type_variation = "MutedLabel"
	note.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	form.add_child(note)

	return {"page": page, "form": form, "illustration": illustration,
		"illustration_body": illustration_body}


func _build_ancestry_page() -> Control:
	var parts: Dictionary = _new_page(
		"1. ANCESTRY",
		"Declare the lineage under which this person is to be indexed.",
		"ILLUMINATED LINEAGE",
		"Select an ancestry to reveal the Registry's plate and field notes.",
	)
	var illustration := parts["illustration"] as VBoxContainer
	var fallback := parts["illustration_body"] as Label
	_ancestry_art_fallback = fallback
	_ancestry_art = TextureRect.new()
	_ancestry_art.custom_minimum_size = Vector2(360, 360)
	_ancestry_art.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	_ancestry_art.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	_ancestry_art.size_flags_vertical = Control.SIZE_EXPAND_FILL
	_ancestry_art.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_ancestry_art.visible = false
	illustration.add_child(_ancestry_art)
	illustration.move_child(_ancestry_art, 1)

	var form := parts["form"] as VBoxContainer
	_ancestry_rows.clear()
	var focusables: Array[Control] = []
	for entry: Dictionary in ChargenData.ANCESTRIES:
		var btn := Button.new()
		btn.theme_type_variation = "ChargenChoiceButton"
		btn.toggle_mode = true
		btn.text = "%s  —  %s" % [entry["name"], entry["trait"]]
		btn.alignment = HORIZONTAL_ALIGNMENT_LEFT
		btn.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
		btn.mouse_default_cursor_shape = Control.CURSOR_POINTING_HAND
		btn.pressed.connect(_on_ancestry_pressed.bind(str(entry["id"])))
		form.add_child(btn)
		_ancestry_rows[str(entry["id"])] = btn
		focusables.append(btn)
	_page_focusables[STEP_ANCESTRY] = focusables
	return parts["page"] as Control


func _build_calling_page() -> Control:
	var parts: Dictionary = _new_page(
		"2. CALLING",
		"Record discipline, patronage, and the history the applicant admits to.",
		"THREE SEALS",
		"Discipline is the hand. Patron is the oath. Background is the road already walked.",
	)
	var form := parts["form"] as VBoxContainer
	_discipline_option = _labelled_option(form, "Discipline")
	for entry: Dictionary in ChargenData.DISCIPLINES:
		_discipline_option.add_item(str(entry["name"]))
	_discipline_option.item_selected.connect(_on_discipline_selected)

	_patron_option = _labelled_option(form, "Patron")
	for entry: Dictionary in ChargenData.PATRONS:
		_patron_option.add_item("%s (%s) — %s" % [entry["name"], entry["patron"], entry["role"]])
	_patron_option.item_selected.connect(_on_patron_selected)

	_background_option = _labelled_option(form, "Background")
	for entry: Dictionary in ChargenData.BACKGROUNDS:
		_background_option.add_item(str(entry["name"]))
	_background_option.item_selected.connect(_on_background_selected)

	_page_focusables[STEP_CALLING] = [
		_discipline_option, _patron_option, _background_option,
	] as Array[Control]
	return parts["page"] as Control


func _build_elements_page() -> Control:
	var parts: Dictionary = _new_page(
		"3. ELEMENTS",
		"Enter major and minor affinities; opposing Clash marks invalidate this leaf.",
		"THE WHEEL OF TEN",
		"Chord may answer Chord. Clash may not be entered beside its opposite.",
	)
	var form := parts["form"] as VBoxContainer
	_major_option = _labelled_option(form, "Major Element")
	_minor_option = _labelled_option(form, "Minor Element")
	for wheel_entry: Dictionary in DS.WHEEL:
		var option_text := "%s  %s" % [wheel_entry["sigil"], wheel_entry["name"]]
		_major_option.add_item(option_text)
		_minor_option.add_item(option_text)
	_major_option.item_selected.connect(_on_major_selected)
	_minor_option.item_selected.connect(_on_minor_selected)

	var wheel_note := Label.new()
	wheel_note.text = "Both fields may be left unentered. If entered, they must be distinct and must not form a Clash pair."
	wheel_note.theme_type_variation = "QuoteLabel"
	wheel_note.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	form.add_child(wheel_note)
	_page_focusables[STEP_ELEMENTS] = [_major_option, _minor_option] as Array[Control]
	return parts["page"] as Control


func _build_attributes_page() -> Control:
	var parts: Dictionary = _new_page(
		"4. ATTRIBUTES",
		"Distribute the sanctioned twenty points; no measure may exceed five.",
		"THE BODY, MIND, AND SOUL",
		"The clerk tallies six ratified measures beneath a title whose seventh remains deliberately unstated.",
	)
	var form := parts["form"] as VBoxContainer
	var heading := Label.new()
	# Owner ruling 2026-08-30: keep this seven-count header verbatim as DRAMGID
	# foreshadowing; the six ratified attributes remain the only mechanics.
	# Owner ruling 2026-08-30 (docs/chapter-one-open-questions.md): "Seven Measures"
	# stays verbatim over the six ratified attributes — a DRAMGID (7-letter) attribute
	# system is planned but unratified; the seven-count header is intentional
	# foreshadowing. Do not "fix" the count and do not add a seventh attribute.
	heading.text = "THE SEVEN MEASURES"
	heading.theme_type_variation = "ChargenIllustrationTitle"
	form.add_child(heading)

	_attribute_bars.clear()
	_attribute_value_lbls.clear()
	var focusables: Array[Control] = []
	for attribute_id: String in ChargenData.ATTRIBUTE_IDS:
		var row_data: Dictionary = _build_attribute_row(attribute_id)
		form.add_child(row_data["row"] as Control)
		focusables.append(row_data["minus"] as Control)
		focusables.append(row_data["plus"] as Control)
	_page_focusables[STEP_ATTRIBUTES] = focusables
	return parts["page"] as Control


func _build_attribute_row(attribute_id: String) -> Dictionary:
	var row := HBoxContainer.new()
	row.theme_type_variation = "BattleHudRow"

	var info := VBoxContainer.new()
	info.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	row.add_child(info)
	var name_lbl := Label.new()
	name_lbl.text = ChargenData.attribute_label(attribute_id)
	name_lbl.theme_type_variation = "HeadingLabel"
	info.add_child(name_lbl)
	var hint_lbl := Label.new()
	hint_lbl.text = str(ChargenData.ATTRIBUTE_HINTS.get(attribute_id, ""))
	hint_lbl.theme_type_variation = "QuoteLabel"
	info.add_child(hint_lbl)
	var bar := ProgressBar.new()
	bar.custom_minimum_size = Vector2(0, 8)
	bar.show_percentage = false
	bar.min_value = ChargenData.ATTRIBUTE_FLOOR
	bar.max_value = ChargenData.ATTRIBUTE_CAP
	info.add_child(bar)
	_attribute_bars[attribute_id] = bar

	var minus_btn := Button.new()
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
	plus_btn.text = "+"
	plus_btn.pressed.connect(_on_attribute_step.bind(attribute_id, 1))
	row.add_child(plus_btn)
	return {"row": row, "minus": minus_btn, "plus": plus_btn}


func _build_skills_page() -> Control:
	var parts: Dictionary = _new_page(
		"5. SKILLS",
		"Inspect the percentages derived from the recorded measures and background.",
		"THE CLERK'S ABACUS",
		"No mark here is chosen by hand. Percentages are derived by the same service used for play.",
	)
	var form := parts["form"] as VBoxContainer
	var grid := GridContainer.new()
	grid.columns = 2
	grid.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	form.add_child(grid)
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
		grid.add_child(row)
	_page_focusables[STEP_SKILLS] = [] as Array[Control]
	return parts["page"] as Control


func _build_identity_page() -> Control:
	var parts: Dictionary = _new_page(
		"6. FLAW, NAME, AND LIKENESS",
		"Affix a likeness, enter the public name, and note any admitted complication.",
		"PORTRAIT OF RECORD",
		"Painterly plates are preferred. Until a plate arrives, the field likeness remains valid Registry evidence.",
	)
	var illustration := parts["illustration"] as VBoxContainer
	_identity_portrait_fallback = parts["illustration_body"] as Label
	_identity_portrait = TextureRect.new()
	_identity_portrait.custom_minimum_size = Vector2(360, 360)
	_identity_portrait.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	_identity_portrait.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	_identity_portrait.size_flags_vertical = Control.SIZE_EXPAND_FILL
	_identity_portrait.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_identity_portrait.visible = false
	illustration.add_child(_identity_portrait)
	illustration.move_child(_identity_portrait, 1)
	var form := parts["form"] as VBoxContainer
	var portrait_grid := GridContainer.new()
	portrait_grid.columns = 4
	form.add_child(portrait_grid)
	_likeness_buttons.clear()
	var focusables: Array[Control] = []
	for likeness: Dictionary in ChargenData.LIKENESSES:
		var likeness_id := str(likeness.get("id", ""))
		var btn := Button.new()
		btn.theme_type_variation = "ChargenPortraitButton"
		btn.custom_minimum_size = Vector2(116, 156)
		btn.toggle_mode = true
		btn.expand_icon = true
		btn.button_pressed = likeness_id == _likeness_id
		btn.icon = ChargenArtResolverScript.portrait_texture(likeness_id)
		btn.tooltip_text = str(likeness.get("label", likeness_id))
		btn.pressed.connect(_on_likeness_pressed.bind(likeness_id, btn))
		portrait_grid.add_child(btn)
		_likeness_buttons.append(btn)
		focusables.append(btn)

	_name_edit = _labelled_line_edit(form, "Name", "Their name, for the ledger")
	_name_edit.text_changed.connect(_on_name_changed)
	_epithet_edit = _labelled_line_edit(form, "Epithet", "the unbowed, the quiet, …")
	_epithet_edit.text_changed.connect(_on_epithet_changed)
	var flaw_edit := _labelled_line_edit(form, "Flaw (optional)", "A Waning-flavored complication, if any")
	flaw_edit.text_changed.connect(_on_flaw_changed)
	focusables.append(_name_edit)
	focusables.append(_epithet_edit)
	focusables.append(flaw_edit)
	_page_focusables[STEP_IDENTITY] = focusables
	_update_identity_portrait()
	return parts["page"] as Control


func _build_summary_page() -> Control:
	var parts: Dictionary = _new_page(
		"7. THE COMPLETED FORM 7",
		"Review every leaf before the Registry stamp is struck.",
		"READY FOR THE SEAL",
		"One copy for the Registry, one for the Company, and one for whichever archive denies receiving it.",
	)
	var form := parts["form"] as VBoxContainer
	_summary_lbl = Label.new()
	_summary_lbl.theme_type_variation = "ChargenSummaryText"
	_summary_lbl.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	_summary_lbl.size_flags_vertical = Control.SIZE_EXPAND_FILL
	form.add_child(_summary_lbl)

	var jump_heading := Label.new()
	jump_heading.text = "Amend a leaf"
	jump_heading.theme_type_variation = "HeadingLabel"
	form.add_child(jump_heading)
	var jump_grid := GridContainer.new()
	jump_grid.columns = 3
	form.add_child(jump_grid)
	var focusables: Array[Control] = []
	for index: int in STEP_SUMMARY:
		var jump_btn := Button.new()
		jump_btn.text = "%d. %s" % [index + 1, STEP_NAMES[index]]
		jump_btn.pressed.connect(_show_step.bind(index))
		jump_grid.add_child(jump_btn)
		focusables.append(jump_btn)
	_page_focusables[STEP_SUMMARY] = focusables
	return parts["page"] as Control


func _build_navigation(parent: VBoxContainer) -> void:
	_validation_lbl = Label.new()
	_validation_lbl.theme_type_variation = "ChargenValidationLabel"
	_validation_lbl.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	parent.add_child(_validation_lbl)

	var navigation := HBoxContainer.new()
	navigation.theme_type_variation = "ChargenNavigation"
	parent.add_child(navigation)
	_back_btn = _menu_button(navigation, "BACK", _on_back)
	_step_status_lbl = Label.new()
	_step_status_lbl.theme_type_variation = "StatLabel"
	_step_status_lbl.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_step_status_lbl.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	navigation.add_child(_step_status_lbl)
	_next_btn = _menu_button(navigation, "NEXT LEAF", _on_next)
	_next_btn.theme_type_variation = "BronzeButton"
	_accept_btn = _menu_button(navigation, "ACCEPT THE TERMS", _on_accept)
	_accept_btn.theme_type_variation = "BronzeButton"


func _build_flash() -> void:
	_flash_rect = ColorRect.new()
	_flash_rect.color = DS.PARCHMENT
	_flash_rect.modulate.a = 0.0
	_flash_rect.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_flash_rect.set_anchors_preset(Control.PRESET_FULL_RECT)
	add_child(_flash_rect)


func _labelled_option(parent: Control, label_text: String) -> OptionButton:
	var lbl := Label.new()
	lbl.text = label_text
	lbl.theme_type_variation = "MutedLabel"
	parent.add_child(lbl)
	var option := OptionButton.new()
	option.mouse_default_cursor_shape = Control.CURSOR_POINTING_HAND
	parent.add_child(option)
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


func _on_ancestry_pressed(ancestry_id: String) -> void:
	_ancestry_id = ancestry_id
	for id: String in _ancestry_rows:
		var btn := _ancestry_rows[id] as Button
		btn.set_pressed_no_signal(id == ancestry_id)
	_update_ancestry_illustration()
	_refresh_summary_and_gate()


func _update_ancestry_illustration() -> void:
	var entry: Dictionary = ChargenData.ancestry_by_id(_ancestry_id)
	var art_path: String = ChargenArtResolverScript.ancestry_path(_ancestry_id)
	_ancestry_art.texture = null
	if not art_path.is_empty():
		var art_resource: Resource = load(art_path)
		if art_resource is Texture2D:
			_ancestry_art.texture = art_resource as Texture2D
	_ancestry_art.visible = _ancestry_art.texture != null
	_ancestry_art_fallback.visible = not _ancestry_art.visible
	_ancestry_art_fallback.text = (
		"%s\n\n%s\n\nLeanings: %s" % [
			entry.get("name", "Select an ancestry"),
			entry.get("trait", "The Registry plate will be opened here."),
			entry.get("leans", "—"),
		]
	)


func _update_identity_portrait() -> void:
	if _identity_portrait == null:
		return
	_identity_portrait.texture = ChargenArtResolverScript.portrait_texture(_likeness_id)
	_identity_portrait.visible = _identity_portrait.texture != null
	_identity_portrait_fallback.visible = not _identity_portrait.visible


func _on_likeness_pressed(likeness_id: String, pressed_btn: Button) -> void:
	_likeness_id = likeness_id
	_update_identity_portrait()
	for btn: Button in _likeness_buttons:
		btn.set_pressed_no_signal(btn == pressed_btn)
	_refresh_summary_and_gate()


func _on_discipline_selected(index: int) -> void:
	_discipline_id = str(ChargenData.DISCIPLINES[index]["id"])
	_refresh_summary_and_gate()


func _on_patron_selected(index: int) -> void:
	_patron_id = str(ChargenData.PATRONS[index]["id"])
	_refresh_summary_and_gate()


func _on_background_selected(index: int) -> void:
	_background_id = str(ChargenData.BACKGROUNDS[index]["id"])
	_refresh_all()


func _on_major_selected(index: int) -> void:
	_major_element = str(DS.WHEEL[index]["id"])
	_refresh_summary_and_gate()


func _on_minor_selected(index: int) -> void:
	_minor_element = str(DS.WHEEL[index]["id"])
	_refresh_summary_and_gate()


func _on_name_changed(_text: String) -> void:
	_refresh_summary_and_gate()


func _on_epithet_changed(_text: String) -> void:
	_refresh_summary_and_gate()


func _on_flaw_changed(text: String) -> void:
	_flaw_text = text.strip_edges()
	_refresh_summary_and_gate()


func _on_attribute_step(attribute_id: String, delta: int) -> void:
	var current := int(_attributes[attribute_id])
	var next_value := clampi(current + delta, ChargenData.ATTRIBUTE_FLOOR, ChargenData.ATTRIBUTE_CAP)
	if next_value == current:
		return
	if delta > 0 and ChargenData.remaining_points(_attributes) <= 0:
		_flash_points_denied()
		return
	_attributes[attribute_id] = next_value
	_animate_attribute_change(attribute_id)
	_refresh_all()


func _animate_attribute_change(attribute_id: String) -> void:
	var bar := _attribute_bars.get(attribute_id) as ProgressBar
	if bar == null:
		return
	var tween := create_tween()
	tween.tween_property(bar, "value", _attributes[attribute_id], DS.DUR_INSTANT)
	var delay := 0.0
	for skill_id: String in ChargenData.SKILL_IDS:
		if ChargenData.governing_attribute(skill_id) != attribute_id:
			continue
		var lbl := _skill_pct_lbls.get(skill_id) as Label
		if lbl == null:
			continue
		var skill_tween := create_tween()
		skill_tween.tween_interval(delay)
		skill_tween.tween_property(lbl, "modulate:a", 0.2, 0.0)
		skill_tween.tween_property(lbl, "modulate:a", 1.0, DS.DUR_FAST)
		delay += 0.04


func _flash_points_denied() -> void:
	var original_color := _points_lbl.modulate
	var tween := create_tween()
	tween.tween_property(_points_lbl, "modulate", DS.GILD_2, DS.DUR_INSTANT)
	tween.parallel().tween_property(_points_lbl, "rotation", deg_to_rad(6.0), 0.04)
	tween.tween_property(_points_lbl, "rotation", deg_to_rad(-6.0), 0.04)
	tween.tween_property(_points_lbl, "rotation", 0.0, 0.04)
	tween.tween_property(_points_lbl, "modulate", original_color, DS.DUR_FAST)


func _refresh_all() -> void:
	for attribute_id: String in ChargenData.ATTRIBUTE_IDS:
		var bar := _attribute_bars.get(attribute_id) as ProgressBar
		var value_lbl := _attribute_value_lbls.get(attribute_id) as Label
		if bar != null:
			bar.value = int(_attributes.get(attribute_id, ChargenData.ATTRIBUTE_FLOOR))
		if value_lbl != null:
			value_lbl.text = str(_attributes.get(attribute_id, ChargenData.ATTRIBUTE_FLOOR))
	var background: Dictionary = ChargenData.background_by_id(_background_id)
	var trained_skills: Array = background.get("skills", [])
	var percentages: Dictionary = ChargenData.preview_skill_percentages(_attributes, trained_skills)
	for skill_id: String in ChargenData.SKILL_IDS:
		var lbl := _skill_pct_lbls.get(skill_id) as Label
		if lbl != null:
			var tier_mark := "  ·  TRAINED" if skill_id in trained_skills else ""
			lbl.text = "%d%%%s" % [roundi(float(percentages[skill_id])), tier_mark]
	_refresh_summary_and_gate()


func _refresh_summary_and_gate() -> void:
	var remaining: int = ChargenData.remaining_points(_attributes)
	if _points_lbl != null:
		_points_lbl.text = "%d POINTS UNSPENT" % remaining
		_points_lbl.modulate = DS.GILD_2 if remaining > 0 else DS.STATE_CONSTANT

	if _summary_lbl != null:
		_summary_lbl.text = _summary_text()
	_update_navigation()


func _summary_text() -> String:
	var ancestry: Dictionary = ChargenData.ancestry_by_id(_ancestry_id)
	var patron: Dictionary = ChargenData.patron_by_id(_patron_id)
	var background: Dictionary = ChargenData.background_by_id(_background_id)
	var discipline_name := _entry_name_by_id(ChargenData.DISCIPLINES, _discipline_id)
	var major_name := _wheel_name(_major_element)
	var minor_name := _wheel_name(_minor_element)
	var attribute_lines: PackedStringArray = []
	for attribute_id: String in ChargenData.ATTRIBUTE_IDS:
		attribute_lines.append("%s %d" % [
			ChargenData.attribute_label(attribute_id),
			int(_attributes.get(attribute_id, ChargenData.ATTRIBUTE_FLOOR)),
		])
	var name_text := _name_edit.text.strip_edges() if _name_edit != null else ""
	var epithet_text := _epithet_edit.text.strip_edges() if _epithet_edit != null else ""
	return (
		"NAME\n%s%s\n\nANCESTRY\n%s\n\nCALLING\n%s  ·  %s  ·  %s\n\n"
		+ "ELEMENTS\nMajor: %s  ·  Minor: %s\n\nATTRIBUTES\n%s\n\nFLAW\n%s\n\nLIKENESS\n%s"
	) % [
		name_text if not name_text.is_empty() else "(unnamed)",
		(", " + epithet_text) if not epithet_text.is_empty() else "",
		ancestry.get("name", "(unentered)"),
		discipline_name if not discipline_name.is_empty() else "(unentered)",
		patron.get("name", "(unentered)"),
		background.get("name", "(unentered)"),
		major_name if not major_name.is_empty() else "(unentered)",
		minor_name if not minor_name.is_empty() else "(unentered)",
		"  ·  ".join(attribute_lines),
		_flaw_text if not _flaw_text.is_empty() else "(none entered)",
		_likeness_id,
	]


func _entry_name_by_id(entries: Array[Dictionary], id: String) -> String:
	for entry: Dictionary in entries:
		if str(entry["id"]) == id:
			return str(entry["name"])
	return ""


func _wheel_name(id: String) -> String:
	for entry: Dictionary in DS.WHEEL:
		if str(entry["id"]) == id:
			return str(entry["name"])
	return ""


func _show_step(index: int) -> void:
	_step_index = clampi(index, STEP_ANCESTRY, STEP_SUMMARY)
	for page_index: int in _step_pages.size():
		_step_pages[page_index].visible = page_index == _step_index
	for marker_index: int in _step_markers.size():
		var prefix := "◆" if marker_index == _step_index else "◇"
		_step_markers[marker_index].text = "%s %d  %s" % [
			prefix, marker_index + 1, STEP_NAMES[marker_index],
		]
	_update_navigation()
	_wire_focus_for_current_step()
	call_deferred("_focus_current_page")


func _update_navigation() -> void:
	if _next_btn == null:
		return
	var is_summary := _step_index == STEP_SUMMARY
	_next_btn.visible = not is_summary
	_accept_btn.visible = is_summary
	_next_btn.disabled = not _step_is_valid(_step_index)
	_accept_btn.disabled = not _is_accept_ready()
	_back_btn.text = "CANCEL ENTRY" if _step_index == STEP_ANCESTRY else "BACK"
	_back_btn.disabled = _step_index == STEP_ANCESTRY and flow_owned
	_step_status_lbl.text = "LEAF %d OF %d  ·  %s" % [
		_step_index + 1, STEP_COUNT, STEP_NAMES[_step_index].to_upper(),
	]
	_validation_lbl.text = _validation_message(_step_index)


func _step_is_valid(index: int) -> bool:
	match index:
		STEP_ANCESTRY:
			return not _ancestry_id.is_empty()
		STEP_ELEMENTS:
			return ChargenData.is_valid_element_pair(_major_element, _minor_element)
		STEP_ATTRIBUTES:
			return ChargenData.is_valid_point_buy(_attributes)
		STEP_IDENTITY:
			return _name_edit != null and not _name_edit.text.strip_edges().is_empty()
		STEP_SUMMARY:
			return _is_accept_ready()
		_:
			return true


func _validation_message(index: int) -> String:
	if _step_is_valid(index):
		return "Registry check passed."
	match index:
		STEP_ANCESTRY:
			return "Choose one ancestry before turning the leaf."
		STEP_ELEMENTS:
			return "Major and minor may not match or form an opposed Clash pair."
		STEP_ATTRIBUTES:
			return "Spend all twenty points within the ratified floor and cap."
		STEP_IDENTITY:
			return "A name is required for the Registry entry."
		_:
			return "Complete the required entries before continuing."


func _is_accept_ready() -> bool:
	var name_text := _name_edit.text.strip_edges() if _name_edit != null else ""
	return (
		ChargenData.remaining_points(_attributes) == 0
		and not _ancestry_id.is_empty()
		and not name_text.is_empty()
		and ChargenData.is_valid_element_pair(_major_element, _minor_element)
	)


func _on_next() -> void:
	if _step_index >= STEP_SUMMARY or not _step_is_valid(_step_index):
		return
	_show_step(_step_index + 1)


func _on_back() -> void:
	if _step_index > STEP_ANCESTRY:
		_show_step(_step_index - 1)
	elif not flow_owned:
		close()


func _unhandled_input(event: InputEvent) -> void:
	if event.is_action_pressed("ui_cancel") and _step_index > STEP_ANCESTRY:
		get_viewport().set_input_as_handled()
		_show_step(_step_index - 1)


func _wire_focus_for_current_step() -> void:
	var controls: Array[Control] = []
	var page_controls: Array = _page_focusables.get(_step_index, [])
	for value: Variant in page_controls:
		var control := value as Control
		if control != null and control.visible and not _control_is_disabled(control):
			controls.append(control)
	if not _back_btn.disabled:
		controls.append(_back_btn)
	controls.append(_accept_btn if _step_index == STEP_SUMMARY else _next_btn)
	if controls.is_empty():
		return
	for index: int in controls.size():
		var control := controls[index]
		var previous := controls[posmod(index - 1, controls.size())]
		var next_control := controls[(index + 1) % controls.size()]
		control.focus_previous = control.get_path_to(previous)
		control.focus_next = control.get_path_to(next_control)
		control.focus_neighbor_top = control.get_path_to(previous)
		control.focus_neighbor_left = control.get_path_to(previous)
		control.focus_neighbor_bottom = control.get_path_to(next_control)
		control.focus_neighbor_right = control.get_path_to(next_control)


func _focus_current_page() -> void:
	var page_controls: Array = _page_focusables.get(_step_index, [])
	for value: Variant in page_controls:
		var control := value as Control
		if control != null and control.visible and not _control_is_disabled(control):
			control.grab_focus()
			return
	var action := _accept_btn if _step_index == STEP_SUMMARY else _next_btn
	if action != null and not action.disabled:
		action.grab_focus()


func _control_is_disabled(control: Control) -> bool:
	return control is BaseButton and (control as BaseButton).disabled


func _on_accept() -> void:
	_refresh_summary_and_gate()
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
	member.race = str(ChargenData.ancestry_by_id(_ancestry_id).get("name", ""))
	var patron_entry: Dictionary = ChargenData.patron_by_id(_patron_id)
	member.char_class = (
		"%s (%s)" % [patron_entry["name"], patron_entry["patron"]]
		if not patron_entry.is_empty() else ""
	)
	member.discipline = _discipline_id
	member.patron = _patron_id
	member.background = _background_id
	member.flaw = _flaw_text
	member.starting_mastery = str(ChargenData.background_by_id(_background_id).get("mastery", ""))
	member.major_element = _major_element
	member.minor_element = _minor_element
	member.attributes = _attributes.duplicate(true)
	member.skill_tiers = {}
	var trained_skills: Array = ChargenData.background_by_id(_background_id).get("skills", [])
	for skill_id: String in trained_skills:
		member.skill_tiers[skill_id] = "trained"
	member.skill_percentages = {}
	member.bio = str(ChargenData.ancestry_by_id(_ancestry_id).get("trait", ""))
	member.portrait = ChargenArtResolverScript.portrait_texture(_likeness_id)
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
	_eyebrow_lbl.text = "FORM 7, IN TRIPLICATE  ·  RECORDED"
	var tween := create_tween()
	_flash_rect.modulate.a = 0.9
	tween.tween_property(_flash_rect, "modulate:a", 0.0, DS.DUR_FAST)
