class_name CharacterCreationScreen
extends Screen
## The Register of Persons — a nine-leaf illustrated Form 7 over ChargenBuild
## (docs/architecture-chargen-dramgid.md §7). The screen owns presentation and focus only:
## every rule, percentage and gate comes from the model, so the boot-time player path,
## the tavern's recruit path and the integration tests drive the same public API below.

signal recruit_created(member: PartyMember)

enum Mode { PLAYER, RECRUIT }

const ChargenArtResolverScript := preload("res://ui/screens/chargen/chargen_art_resolver.gd")
const WheelWidgetScript := preload("res://ui/components/wheel_widget.gd")
const STAMP_SOUND := preload("res://assets/audio/sfx/impactPlate_heavy_000.ogg")

## Two-letter measure marks for skill rows (DRAMGID has two Ds).
const ATTRIBUTE_MARKS: Dictionary = {
	"doctrine": "Do", "reason": "Re", "alacrity": "Al", "muster": "Mu",
	"grit": "Gr", "intuition": "In", "decorum": "De",
}
const TIER_MARKS: Dictionary = {"untrained": "", "trained": "◆", "expert": "◆◆"}

var mode: Mode = Mode.PLAYER
## The in-progress character. Read freely; mutate through the select_*/set_* API so the
## screen refreshes.
var build: ChargenBuild = ChargenBuild.new()

var _step_index := 0
var _step_pages: Array[Control] = []
var _step_markers: Array[Label] = []
var _page_focusables: Dictionary = {}

var _eyebrow_lbl: Label
var _points_lbl: Label
var _accept_btn: Button
var _next_btn: Button
var _back_btn: Button
var _step_status_lbl: Label
var _validation_lbl: Label
var _flash_rect: ColorRect

var _ancestry_rows: Dictionary = {}
var _ancestry_art: TextureRect
var _ancestry_art_fallback: Label

var _discipline_rows: Dictionary = {}
var _discipline_detail: Label

var _class_cards: Dictionary = {}
var _kit_row: HBoxContainer
var _kit_buttons: Dictionary = {}
var _class_detail: Label

var _major_option: OptionButton
var _minor_option: OptionButton
var _mastery_option: OptionButton
var _suggest_btn: Button
var _wheel: Control
var _elements_note: Label

var _attribute_bars: Dictionary = {}
var _attribute_value_lbls: Dictionary = {}
var _attribute_readout: Label

var _background_rows: Dictionary = {}

var _skills_form: VBoxContainer
var _skills_pool_lbl: Label
var _skill_rows: Dictionary = {}

var _name_edit: LineEdit
var _epithet_edit: LineEdit
var _flaw_edit: LineEdit
var _likeness_buttons: Array[Button] = []
var _identity_portrait: TextureRect
var _identity_portrait_fallback: Label

var _summary_lbl: Label


# --- build ----------------------------------------------------------------------------------

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
	var builders: Dictionary = {
		&"ancestry": _build_ancestry_page,
		&"discipline": _build_discipline_page,
		&"patron": _build_patron_page,
		&"elements": _build_elements_page,
		&"attributes": _build_attributes_page,
		&"background": _build_background_page,
		&"skills": _build_skills_page,
		&"identity": _build_identity_page,
		&"summary": _build_summary_page,
	}
	_step_pages.clear()
	for step: Dictionary in ChargenSteps.STEPS:
		var builder: Callable = builders[step["id"]]
		var page: Control = builder.call(step)
		page.name = "Page_%s" % step["id"]
		page_host.add_child(page)
		_step_pages.append(page)

	_build_navigation(content)
	_build_flash()
	_refresh_all()
	_show_step(0)


func _build_step_rail(parent: VBoxContainer) -> void:
	var rail := HBoxContainer.new()
	rail.theme_type_variation = "ChargenStepRail"
	parent.add_child(rail)
	for index: int in ChargenSteps.count():
		var marker := Label.new()
		marker.theme_type_variation = "ChargenStepMarker"
		marker.text = "%d  %s" % [index + 1, ChargenSteps.at(index)["name"]]
		marker.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		rail.add_child(marker)
		_step_markers.append(marker)


func _new_page(step: Dictionary, illustration_copy: String) -> Dictionary:
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
	plate.text = str(step["illustration_title"])
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
	title.text = str(step["title"])
	title.theme_type_variation = "HeadingLabel"
	form.add_child(title)

	var note := Label.new()
	note.text = "FORM 7, IN TRIPLICATE  ·  %s" % step["registry_note"]
	note.theme_type_variation = "MutedLabel"
	note.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	form.add_child(note)

	return {"page": page, "form": form, "illustration": illustration,
		"illustration_body": illustration_body}


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


func _detail_label(parent: Control) -> Label:
	var lbl := Label.new()
	lbl.theme_type_variation = "ChargenSummaryText"
	lbl.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	lbl.size_flags_vertical = Control.SIZE_EXPAND_FILL
	parent.add_child(lbl)
	return lbl


# --- leaf 1: ancestry -----------------------------------------------------------------------

func _build_ancestry_page(step: Dictionary) -> Control:
	var parts: Dictionary = _new_page(step,
		"Select an ancestry to reveal the Registry's plate and field notes.")
	var illustration := parts["illustration"] as VBoxContainer
	_ancestry_art_fallback = parts["illustration_body"] as Label
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
		var id := str(entry["id"])
		var btn := _choice_button("%s  —  %s" % [entry["name"], entry["trait"]], select_ancestry.bind(id))
		form.add_child(btn)
		_ancestry_rows[id] = btn
		focusables.append(btn)
	_page_focusables[&"ancestry"] = focusables
	return parts["page"] as Control


func _refresh_ancestry() -> void:
	for id: String in _ancestry_rows:
		(_ancestry_rows[id] as Button).set_pressed_no_signal(id == build.ancestry_id)
	var entry: Dictionary = ChargenData.ancestry_by_id(build.ancestry_id)
	var art_path: String = ChargenArtResolverScript.ancestry_path(build.ancestry_id)
	_ancestry_art.texture = null
	if not art_path.is_empty():
		var art_resource: Resource = load(art_path)
		if art_resource is Texture2D:
			_ancestry_art.texture = art_resource as Texture2D
	_ancestry_art.visible = _ancestry_art.texture != null
	_ancestry_art_fallback.visible = not _ancestry_art.visible
	_ancestry_art_fallback.text = "%s\n\n%s\n\nLeanings: %s" % [
		entry.get("name", "Select an ancestry"),
		entry.get("trait", "The Registry plate will be opened here."),
		entry.get("leans", "—"),
	]


# --- leaf 2: discipline ---------------------------------------------------------------------

func _build_discipline_page(step: Dictionary) -> Control:
	var parts: Dictionary = _new_page(step,
		"A Discipline is what a body can do — movement, reach, elevation — in any zone, the Hush included. It is not a class.")
	_discipline_detail = _detail_label(parts["illustration"] as VBoxContainer)
	var form := parts["form"] as VBoxContainer
	_discipline_rows.clear()
	var focusables: Array[Control] = []
	for entry: Dictionary in ChargenData.DISCIPLINES:
		var id := str(entry["id"])
		var btn := _choice_button("%s  —  %s\n%s" % [entry["name"], entry["blurb"], entry["verbs"]],
			select_discipline.bind(id))
		form.add_child(btn)
		_discipline_rows[id] = btn
		focusables.append(btn)
	_page_focusables[&"discipline"] = focusables
	return parts["page"] as Control


func _refresh_discipline() -> void:
	for id: String in _discipline_rows:
		(_discipline_rows[id] as Button).set_pressed_no_signal(id == build.discipline_id)
	var entry: Dictionary = ChargenData.discipline_by_id(build.discipline_id)
	if entry.is_empty():
		_discipline_detail.text = "Choose the stance the body already knows."
		return
	_discipline_detail.text = "%s\n\n%s\n\n%s\n\nFavours %s." % [
		entry["name"], entry["blurb"], entry["verbs"], _wheel_name(str(entry["favours"])),
	]


# --- leaf 3: patron (class cards) -----------------------------------------------------------

func _build_patron_page(step: Dictionary) -> Control:
	var parts: Dictionary = _new_page(step,
		"Choose a Patron to read its Kit, Resource and Signature. The Kit holds at full strength in the Hush.")
	_class_detail = _detail_label(parts["illustration"] as VBoxContainer)
	var form := parts["form"] as VBoxContainer
	var grid := GridContainer.new()
	grid.theme_type_variation = "ChargenCardGrid"
	grid.columns = 2
	grid.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	form.add_child(grid)
	_class_cards.clear()
	var focusables: Array[Control] = []
	for entry: Dictionary in ClassCatalog.ALL:
		var id := str(entry["id"])
		var card := _choice_button(_class_card_text(entry), select_class.bind(id))
		card.name = "Card_%s" % id
		grid.add_child(card)
		_class_cards[id] = card
		focusables.append(card)

	_kit_row = HBoxContainer.new()
	_kit_row.theme_type_variation = "ChargenSkillRow"
	form.add_child(_kit_row)
	var kit_lbl := Label.new()
	kit_lbl.text = "Kit weapon"
	kit_lbl.theme_type_variation = "MutedLabel"
	_kit_row.add_child(kit_lbl)
	_kit_buttons.clear()
	for skill_id: String in DramgidSchema.ARMS_SKILL_IDS:
		var btn := Button.new()
		btn.name = "Kit_%s" % skill_id
		btn.toggle_mode = true
		btn.text = DramgidSchema.skill_label(skill_id)
		btn.mouse_default_cursor_shape = Control.CURSOR_POINTING_HAND
		btn.pressed.connect(select_kit.bind(skill_id))
		btn.visible = false
		_kit_row.add_child(btn)
		_kit_buttons[skill_id] = btn
		focusables.append(btn)
	_page_focusables[&"patron"] = focusables
	return parts["page"] as Control


func _class_card_text(entry: Dictionary) -> String:
	var kit_skills: Array = entry["kit_skills"]
	var kit_names: PackedStringArray = []
	for skill_id in kit_skills:
		kit_names.append(DramgidSchema.skill_label(str(skill_id)))
	var suggestion := "flexible — no suggested elements"
	if not str(entry["suggested_major"]).is_empty():
		suggestion = "%s / %s  (%s)" % [
			_wheel_sigil_name(str(entry["suggested_major"])),
			_wheel_sigil_name(str(entry["suggested_minor"])),
			entry["chord"],
		]
	return "%s  ·  %s  ·  %s\nKit: %s — Trained %s\nResource: %s  ·  Signature: %s\nSuggested: %s" % [
		entry["name"], entry["patron"], entry["role"],
		entry["kit"], " or ".join(kit_names),
		entry["resource"], entry["signature"],
		suggestion,
	]


func _refresh_patron() -> void:
	for id: String in _class_cards:
		var card := _class_cards[id] as Button
		var retired := ClassCatalog.is_retired_pairing(id, build.discipline_id)
		card.disabled = retired
		card.set_pressed_no_signal(id == build.class_id and not retired)
		card.tooltip_text = "Retired pairing with %s." % _discipline_name() if retired else ""
	var entry: Dictionary = ClassCatalog.by_id(build.class_id)
	var offers_choice := ClassCatalog.offers_kit_choice(build.class_id)
	_kit_row.visible = offers_choice
	var offered: Array = entry.get("kit_skills", [])
	for skill_id: String in _kit_buttons:
		var btn := _kit_buttons[skill_id] as Button
		btn.visible = offers_choice and skill_id in offered
		btn.set_pressed_no_signal(skill_id == build.kit_skill)
	if entry.is_empty():
		_class_detail.text = "Ten patrons, one oath. The Kit is what you carry; the Resource is how the god keeps score."
		return
	var lines: PackedStringArray = []
	lines.append("%s — patron %s (%s)" % [entry["name"], entry["patron"], entry["role"]])
	lines.append("")
	lines.append("KIT  %s" % entry["kit"])
	lines.append("Trains %s — the weapon skill this class fights with." % DramgidSchema.skill_label(build.kit_skill))
	lines.append("")
	lines.append("RESOURCE  %s" % entry["resource"])
	lines.append(str(entry["resource_blurb"]))
	lines.append("")
	lines.append("SIGNATURE  %s" % entry["signature"])
	lines.append(str(entry["signature_blurb"]))
	var watch := ClassCatalog.is_watch_pairing(build.class_id, build.discipline_id)
	if watch or not str(entry["notes"]).is_empty():
		lines.append("")
		lines.append(str(entry["notes"]))
	if not build.discipline_id.is_empty():
		lines.append("")
		lines.append("With %s: %s" % [_discipline_name(), "under watch" if watch else "clean pairing"])
	_class_detail.text = "\n".join(lines)


# --- leaf 4: elements -----------------------------------------------------------------------

func _build_elements_page(step: Dictionary) -> Control:
	var parts: Dictionary = _new_page(step,
		"Chord may answer Chord. Clash may not be entered beside its opposite. The Major and Minor tones begin Trained.")
	var illustration := parts["illustration"] as VBoxContainer
	_wheel = WheelWidgetScript.new()
	_wheel.name = "WheelWidget"
	_wheel.custom_minimum_size = Vector2(260, 260)
	_wheel.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
	illustration.add_child(_wheel)
	illustration.move_child(_wheel, 1)

	var form := parts["form"] as VBoxContainer
	_major_option = _labelled_option(form, "Major Element")
	_minor_option = _labelled_option(form, "Minor Element")
	for option: OptionButton in [_major_option, _minor_option]:
		option.add_item("—  (unentered)")
		for wheel_entry: Dictionary in DS.WHEEL:
			option.add_item("%s  %s" % [wheel_entry["sigil"], wheel_entry["name"]])
	_major_option.item_selected.connect(_on_major_option)
	_minor_option.item_selected.connect(_on_minor_option)

	_suggest_btn = Button.new()
	_suggest_btn.text = "USE THE PATRON'S SUGGESTION"
	_suggest_btn.mouse_default_cursor_shape = Control.CURSOR_POINTING_HAND
	_suggest_btn.pressed.connect(_on_suggest_pressed)
	form.add_child(_suggest_btn)

	_mastery_option = _labelled_option(form, "Root Note Mastery (from your Background)")
	_mastery_option.item_selected.connect(_on_mastery_option)

	_elements_note = Label.new()
	_elements_note.theme_type_variation = "QuoteLabel"
	_elements_note.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	form.add_child(_elements_note)
	_page_focusables[&"elements"] = [_major_option, _minor_option, _suggest_btn, _mastery_option] as Array[Control]
	return parts["page"] as Control


func _on_major_option(index: int) -> void:
	select_major("" if index == 0 else str(DS.WHEEL[index - 1]["id"]))


func _on_minor_option(index: int) -> void:
	select_minor("" if index == 0 else str(DS.WHEEL[index - 1]["id"]))


func _on_suggest_pressed() -> void:
	build.apply_suggested_elements()
	_refresh_all()


func _on_mastery_option(index: int) -> void:
	var held := build.held_elements()
	if index >= 0 and index < held.size():
		select_mastery(held[index])


func _refresh_elements() -> void:
	_major_option.select(_wheel_index(build.major_element) + 1)
	_minor_option.select(_wheel_index(build.minor_element) + 1)
	_suggest_btn.disabled = str(ClassCatalog.by_id(build.class_id).get("suggested_major", "")).is_empty()
	_mastery_option.clear()
	var held := build.held_elements()
	for element: String in held:
		_mastery_option.add_item(_wheel_sigil_name(element))
	var mastery_index := held.find(build.mastery_element)
	if mastery_index >= 0:
		_mastery_option.select(mastery_index)
	_mastery_option.disabled = held.is_empty()
	_wheel.call("set_elements", build.major_element, build.minor_element)
	var lines: PackedStringArray = []
	if not build.major_element.is_empty() and not ChargenData.is_valid_element_pair(build.major_element, build.minor_element):
		lines.append("Clash: %s and %s are opposed on the Wheel." % [
			_wheel_name(build.major_element), _wheel_name(build.minor_element)])
	for element: String in held:
		var tone_id := DramgidSchema.tone_skill_for(element)
		lines.append("%s starts Trained at %d%%." % [
			DramgidSchema.skill_label(tone_id), roundi(build.preview_percent(tone_id))])
	if lines.is_empty():
		lines.append("A Major is required; a Minor is optional. Only held tones can be trained in Chapter 1.")
	_elements_note.text = "\n".join(lines)


# --- leaf 5: attributes ---------------------------------------------------------------------

func _build_attributes_page(step: Dictionary) -> Control:
	var parts: Dictionary = _new_page(step,
		"Seven measures, fixed at creation. No attribute is a safe dump.")
	_attribute_readout = _detail_label(parts["illustration"] as VBoxContainer)
	var form := parts["form"] as VBoxContainer
	var heading := Label.new()
	heading.text = "THE SEVEN MEASURES"
	heading.theme_type_variation = "ChargenIllustrationTitle"
	form.add_child(heading)

	_attribute_bars.clear()
	_attribute_value_lbls.clear()
	var focusables: Array[Control] = []
	for attribute_id: String in DramgidSchema.ATTRIBUTE_IDS:
		var row_data: Dictionary = _build_attribute_row(attribute_id)
		form.add_child(row_data["row"] as Control)
		focusables.append(row_data["minus"] as Control)
		focusables.append(row_data["plus"] as Control)
	_page_focusables[&"attributes"] = focusables
	return parts["page"] as Control


func _build_attribute_row(attribute_id: String) -> Dictionary:
	var row := HBoxContainer.new()
	row.theme_type_variation = "BattleHudRow"

	var info := VBoxContainer.new()
	info.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	row.add_child(info)
	var name_lbl := Label.new()
	name_lbl.text = DramgidSchema.attribute_label(attribute_id)
	name_lbl.theme_type_variation = "HeadingLabel"
	info.add_child(name_lbl)
	var hint_lbl := Label.new()
	hint_lbl.text = ChargenData.attribute_hint(attribute_id)
	hint_lbl.theme_type_variation = "QuoteLabel"
	info.add_child(hint_lbl)
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
	return {"row": row, "minus": minus_btn, "plus": plus_btn}


func _on_attribute_step(attribute_id: String, delta: int) -> void:
	var had_buys := not build.creation_buys.is_empty()
	if not build.step_attribute(attribute_id, delta):
		if delta > 0:
			_flash_points_denied()
		return
	_animate_attribute_change(attribute_id)
	if had_buys:
		_validation_lbl.text = "Creation points returned — the measures moved."
	_refresh_all()


func _animate_attribute_change(attribute_id: String) -> void:
	var bar := _attribute_bars.get(attribute_id) as ProgressBar
	if bar == null:
		return
	var tween := create_tween()
	tween.tween_property(bar, "value", build.attributes[attribute_id], DS.DUR_INSTANT)


func _flash_points_denied() -> void:
	var original_color := _points_lbl.modulate
	var tween := create_tween()
	tween.tween_property(_points_lbl, "modulate", DS.GILD_2, DS.DUR_INSTANT)
	tween.parallel().tween_property(_points_lbl, "rotation", deg_to_rad(6.0), 0.04)
	tween.tween_property(_points_lbl, "rotation", deg_to_rad(-6.0), 0.04)
	tween.tween_property(_points_lbl, "rotation", 0.0, 0.04)
	tween.tween_property(_points_lbl, "modulate", original_color, DS.DUR_FAST)


func _refresh_attributes() -> void:
	for attribute_id: String in DramgidSchema.ATTRIBUTE_IDS:
		var value := int(build.attributes.get(attribute_id, DramgidSchema.ATTRIBUTE_FLOOR))
		(_attribute_bars[attribute_id] as ProgressBar).value = value
		(_attribute_value_lbls[attribute_id] as Label).text = str(value)
	var scratch := build.scratch_member()
	var lines: PackedStringArray = []
	lines.append("HP %d  ·  Breath %d" % [scratch.max_hp, scratch.breath_max])
	lines.append("Creation skill pool: %d points" % build.creation_pool())
	if not build.kit_skill.is_empty():
		lines.append("%s (Kit): %d%%" % [DramgidSchema.skill_label(build.kit_skill),
			roundi(build.preview_percent(build.kit_skill))])
	for tone_id: String in build.held_tones():
		lines.append("%s: %d%%" % [DramgidSchema.skill_label(tone_id), roundi(build.preview_percent(tone_id))])
	var ancestry: Dictionary = ChargenData.ancestry_by_id(build.ancestry_id)
	if not ancestry.is_empty():
		lines.append("")
		lines.append("%s lean: %s (a nudge, never a bonus)" % [ancestry["name"], ancestry["leans"]])
	_attribute_readout.text = "\n".join(lines)


# --- leaf 6: background ---------------------------------------------------------------------

func _build_background_page(step: Dictionary) -> Control:
	var parts: Dictionary = _new_page(step,
		"Every city dossier is a Background waiting to be statted. Two trades come Trained; the Root Note comes Mastered.")
	var form := parts["form"] as VBoxContainer
	_background_rows.clear()
	var focusables: Array[Control] = []
	for entry: Dictionary in ChargenData.BACKGROUNDS:
		var id := str(entry["id"])
		var skills: Array = entry["skills"]
		var skill_names: PackedStringArray = []
		for skill_id in skills:
			skill_names.append(DramgidSchema.skill_label(str(skill_id)))
		var btn := _choice_button("%s  —  Trained: %s\n%s" % [
			entry["name"], ", ".join(skill_names), entry["feature"]], select_background.bind(id))
		form.add_child(btn)
		_background_rows[id] = btn
		focusables.append(btn)
	_page_focusables[&"background"] = focusables
	return parts["page"] as Control


func _refresh_background() -> void:
	for id: String in _background_rows:
		(_background_rows[id] as Button).set_pressed_no_signal(id == build.background_id)


# --- leaf 7: skills (creation points) -------------------------------------------------------

func _build_skills_page(step: Dictionary) -> Control:
	var parts: Dictionary = _new_page(step,
		"Each +5%% step costs 1 point up to 50%%, 2 to 75%%, 3 to 95%%. ◆ marks a Trained tag. Unspent points carry into play.")
	var form := parts["form"] as VBoxContainer
	_skills_pool_lbl = Label.new()
	_skills_pool_lbl.theme_type_variation = "StatLabel"
	form.add_child(_skills_pool_lbl)
	var scroll := ScrollContainer.new()
	scroll.size_flags_vertical = Control.SIZE_EXPAND_FILL
	scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	form.add_child(scroll)
	_skills_form = VBoxContainer.new()
	_skills_form.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	scroll.add_child(_skills_form)
	_page_focusables[&"skills"] = [] as Array[Control]
	return parts["page"] as Control


## Rows are rebuilt when the set of purchasable skills can have changed (entering the leaf);
## buy/refund refreshes them in place.
func _rebuild_skill_rows() -> void:
	for child in _skills_form.get_children():
		child.queue_free()
	_skill_rows.clear()
	var focusables: Array[Control] = []
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
			var row_data := _build_skill_row(skill_id)
			_skills_form.add_child(row_data["row"] as Control)
			focusables.append(row_data["refund"] as Control)
			focusables.append(row_data["buy"] as Control)
	_page_focusables[&"skills"] = focusables
	_refresh_skills()


func _build_skill_row(skill_id: String) -> Dictionary:
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
	return {"row": row, "refund": refund_btn, "buy": buy_btn}


func _refresh_skills() -> void:
	if _skills_pool_lbl == null:
		return
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


# --- leaf 8: identity -----------------------------------------------------------------------

func _build_identity_page(step: Dictionary) -> Control:
	var parts: Dictionary = _new_page(step,
		"Painterly plates are preferred. Until a plate arrives, the field likeness remains valid Registry evidence.")
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
	portrait_grid.columns = 5
	form.add_child(portrait_grid)
	_likeness_buttons.clear()
	var focusables: Array[Control] = []
	for likeness: Dictionary in ChargenData.LIKENESSES:
		var likeness_id := str(likeness.get("id", ""))
		var btn := Button.new()
		btn.theme_type_variation = "ChargenPortraitButton"
		btn.custom_minimum_size = Vector2(96, 128)
		btn.toggle_mode = true
		btn.expand_icon = true
		btn.icon = ChargenArtResolverScript.portrait_texture(likeness_id)
		btn.tooltip_text = str(likeness.get("label", likeness_id))
		btn.pressed.connect(select_likeness.bind(likeness_id))
		btn.set_meta("likeness_id", likeness_id)
		portrait_grid.add_child(btn)
		_likeness_buttons.append(btn)
		focusables.append(btn)

	_name_edit = _labelled_line_edit(form, "Name", "Their name, for the ledger")
	_name_edit.text_changed.connect(set_display_name)
	_epithet_edit = _labelled_line_edit(form, "Epithet", "the unbowed, the quiet, …")
	_epithet_edit.text_changed.connect(set_epithet)
	_flaw_edit = _labelled_line_edit(form, "Flaw (optional)", "A Waning-flavored complication, if any")
	_flaw_edit.text_changed.connect(set_flaw)
	focusables.append(_name_edit)
	focusables.append(_epithet_edit)
	focusables.append(_flaw_edit)
	_page_focusables[&"identity"] = focusables
	return parts["page"] as Control


func _refresh_identity() -> void:
	for btn: Button in _likeness_buttons:
		btn.set_pressed_no_signal(str(btn.get_meta("likeness_id", "")) == build.likeness_id)
	_identity_portrait.texture = ChargenArtResolverScript.portrait_texture(build.likeness_id)
	_identity_portrait.visible = _identity_portrait.texture != null
	_identity_portrait_fallback.visible = not _identity_portrait.visible
	if _name_edit.text != build.display_name:
		_name_edit.text = build.display_name
	if _epithet_edit.text != build.epithet:
		_epithet_edit.text = build.epithet
	if _flaw_edit.text != build.flaw:
		_flaw_edit.text = build.flaw


# --- leaf 9: summary ------------------------------------------------------------------------

func _build_summary_page(step: Dictionary) -> Control:
	var parts: Dictionary = _new_page(step,
		"One copy for the Registry, one for the Company, and one for whichever archive denies receiving it.")
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
	jump_grid.columns = 4
	form.add_child(jump_grid)
	var focusables: Array[Control] = []
	for index: int in ChargenSteps.count() - 1:
		var target: Dictionary = ChargenSteps.at(index)
		var jump_btn := Button.new()
		jump_btn.text = "%d. %s" % [index + 1, target["name"]]
		jump_btn.pressed.connect(go_to_step.bind(target["id"]))
		jump_grid.add_child(jump_btn)
		focusables.append(jump_btn)
	_page_focusables[&"summary"] = focusables
	return parts["page"] as Control


func _summary_text() -> String:
	var ancestry: Dictionary = ChargenData.ancestry_by_id(build.ancestry_id)
	var class_entry: Dictionary = ClassCatalog.by_id(build.class_id)
	var background: Dictionary = ChargenData.background_by_id(build.background_id)
	var attribute_lines: PackedStringArray = []
	for attribute_id: String in DramgidSchema.ATTRIBUTE_IDS:
		attribute_lines.append("%s %d" % [
			DramgidSchema.attribute_label(attribute_id),
			int(build.attributes.get(attribute_id, DramgidSchema.ATTRIBUTE_FLOOR)),
		])
	var tag_lines: PackedStringArray = []
	for skill_id: String in build.granted_tiers().keys():
		tag_lines.append(DramgidSchema.skill_label(skill_id))
	var bought_lines: PackedStringArray = []
	for skill_id: String in build.creation_buys.keys():
		bought_lines.append("%s +%d%%" % [DramgidSchema.skill_label(skill_id), int(build.bought_percent(skill_id))])
	var name_text := build.display_name.strip_edges()
	var epithet_text := build.epithet.strip_edges()
	return (
		"NAME\n%s%s\n\nANCESTRY\n%s\n\nCALLING\n%s  ·  %s  ·  %s\nKit: %s\n\n"
		+ "ELEMENTS\nMajor: %s  ·  Minor: %s  ·  Mastery: %s\n\nATTRIBUTES\n%s\n\n"
		+ "TRAINED\n%s\n\nCREATION POINTS\n%s  ·  %d carried into play\n\nFLAW\n%s\n\nLIKENESS\n%s"
	) % [
		name_text if not name_text.is_empty() else "(unnamed)",
		(", " + epithet_text) if not epithet_text.is_empty() else "",
		ancestry.get("name", "(unentered)"),
		_discipline_name() if not build.discipline_id.is_empty() else "(unentered)",
		class_entry.get("name", "(unentered)"),
		background.get("name", "(unentered)"),
		DramgidSchema.skill_label(build.kit_skill) if not build.kit_skill.is_empty() else "(unentered)",
		_wheel_name(build.major_element) if not build.major_element.is_empty() else "(unentered)",
		_wheel_name(build.minor_element) if not build.minor_element.is_empty() else "(none)",
		_wheel_name(build.mastery_element) if not build.mastery_element.is_empty() else "(unentered)",
		"  ·  ".join(attribute_lines),
		"  ·  ".join(tag_lines) if not tag_lines.is_empty() else "(none)",
		"  ·  ".join(bought_lines) if not bought_lines.is_empty() else "(none spent)",
		maxi(build.points_remaining(), 0),
		build.flaw if not build.flaw.is_empty() else "(none entered)",
		build.likeness_id,
	]


# --- navigation -----------------------------------------------------------------------------

func _build_navigation(parent: VBoxContainer) -> void:
	_validation_lbl = Label.new()
	_validation_lbl.theme_type_variation = "ChargenValidationLabel"
	_validation_lbl.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	parent.add_child(_validation_lbl)

	var navigation := HBoxContainer.new()
	navigation.theme_type_variation = "ChargenNavigation"
	parent.add_child(navigation)
	_back_btn = _menu_button(navigation, "BACK", back_step)
	_step_status_lbl = Label.new()
	_step_status_lbl.theme_type_variation = "StatLabel"
	_step_status_lbl.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_step_status_lbl.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	navigation.add_child(_step_status_lbl)
	_next_btn = _menu_button(navigation, "NEXT LEAF", next_step)
	_next_btn.theme_type_variation = "BronzeButton"
	_accept_btn = _menu_button(navigation, "ACCEPT THE TERMS", accept)
	_accept_btn.theme_type_variation = "BronzeButton"


func _build_flash() -> void:
	_flash_rect = ColorRect.new()
	_flash_rect.color = DS.PARCHMENT
	_flash_rect.modulate.a = 0.0
	_flash_rect.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_flash_rect.set_anchors_preset(Control.PRESET_FULL_RECT)
	add_child(_flash_rect)


func _show_step(index: int) -> void:
	_step_index = clampi(index, 0, ChargenSteps.count() - 1)
	for page_index: int in _step_pages.size():
		_step_pages[page_index].visible = page_index == _step_index
	for marker_index: int in _step_markers.size():
		var prefix := "◆" if marker_index == _step_index else "◇"
		_step_markers[marker_index].text = "%s %d  %s" % [
			prefix, marker_index + 1, ChargenSteps.at(marker_index)["name"],
		]
	if current_step_id() == &"skills":
		_rebuild_skill_rows()
	_update_navigation()
	_wire_focus_for_current_step()
	call_deferred("_focus_current_page")


func _update_navigation() -> void:
	if _next_btn == null:
		return
	var step_id := current_step_id()
	var is_summary := step_id == &"summary"
	_next_btn.visible = not is_summary
	_accept_btn.visible = is_summary
	var verdict := build.validate(step_id)
	_next_btn.disabled = not verdict["valid"]
	_accept_btn.disabled = not build.is_complete()
	_back_btn.text = "CANCEL ENTRY" if _step_index == 0 else "BACK"
	_back_btn.disabled = _step_index == 0 and flow_owned
	_step_status_lbl.text = "LEAF %d OF %d  ·  %s" % [
		_step_index + 1, ChargenSteps.count(), str(ChargenSteps.at(_step_index)["name"]).to_upper(),
	]
	_validation_lbl.text = "Registry check passed." if verdict["valid"] else str(verdict["message"])
	match step_id:
		&"attributes":
			var remaining := build.remaining_attribute_points()
			_points_lbl.text = "%d POINTS UNSPENT" % remaining
			_points_lbl.modulate = DS.GILD_2 if remaining > 0 else DS.STATE_CONSTANT
		&"skills", &"summary":
			var remaining := build.points_remaining()
			_points_lbl.text = "%d CREATION POINTS" % remaining
			_points_lbl.modulate = DS.ASH if remaining > 0 else DS.STATE_CONSTANT
		_:
			_points_lbl.text = ""


func _refresh_all() -> void:
	if _next_btn == null:
		return
	_refresh_ancestry()
	_refresh_discipline()
	_refresh_patron()
	_refresh_elements()
	_refresh_attributes()
	_refresh_background()
	_refresh_skills()
	_refresh_identity()
	if _summary_lbl != null:
		_summary_lbl.text = _summary_text()
	_update_navigation()


func _unhandled_input(event: InputEvent) -> void:
	if event.is_action_pressed("ui_cancel") and _step_index > 0:
		get_viewport().set_input_as_handled()
		_show_step(_step_index - 1)


func _wire_focus_for_current_step() -> void:
	var controls: Array[Control] = []
	var page_controls: Array = _page_focusables.get(current_step_id(), [])
	for value: Variant in page_controls:
		var control := value as Control
		if control != null and control.visible and not _control_is_disabled(control):
			controls.append(control)
	if not _back_btn.disabled:
		controls.append(_back_btn)
	controls.append(_accept_btn if current_step_id() == &"summary" else _next_btn)
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
	var page_controls: Array = _page_focusables.get(current_step_id(), [])
	for value: Variant in page_controls:
		var control := value as Control
		if control != null and control.visible and not _control_is_disabled(control):
			control.grab_focus()
			return
	var action := _accept_btn if current_step_id() == &"summary" else _next_btn
	if action != null and not action.disabled:
		action.grab_focus()


func _control_is_disabled(control: Control) -> bool:
	return control is BaseButton and (control as BaseButton).disabled


# --- public driving API (docs §7.4) ---------------------------------------------------------

func select_ancestry(id: String) -> void:
	build.select_ancestry(id)
	_refresh_all()


func select_discipline(id: String) -> void:
	build.select_discipline(id)
	_refresh_all()


func select_class(id: String) -> void:
	if ClassCatalog.is_retired_pairing(id, build.discipline_id):
		_refresh_all()
		return
	build.select_class(id)
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
		_refresh_skills()
		_update_navigation()
		if _summary_lbl != null:
			_summary_lbl.text = _summary_text()
	else:
		_validation_lbl.text = str(result["message"])
	return result


func refund_skill(skill_id: String) -> Dictionary:
	var result := build.refund(skill_id)
	if result["allowed"]:
		_refresh_skills()
		_update_navigation()
		if _summary_lbl != null:
			_summary_lbl.text = _summary_text()
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


func current_step_id() -> StringName:
	return ChargenSteps.at(_step_index)["id"]


func can_advance() -> bool:
	return build.validate(current_step_id())["valid"]


func next_step() -> void:
	if _step_index >= ChargenSteps.count() - 1 or not can_advance():
		_update_navigation()
		return
	_show_step(_step_index + 1)


func back_step() -> void:
	if _step_index > 0:
		_show_step(_step_index - 1)
	elif not flow_owned:
		close()


func go_to_step(step_id: StringName) -> void:
	var index := ChargenSteps.index_of(step_id)
	if index >= 0:
		_show_step(index)


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


# --- helpers --------------------------------------------------------------------------------

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
