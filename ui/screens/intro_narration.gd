class_name IntroNarrationScreen
extends Screen
## Flow-owned opening narration. Copy is intentionally constrained to phrases
## already established in docs/prd-chapter-one.md pending owner canon review.

# PROVISIONAL — CANON REVIEW REQUIRED.
const NARRATION_BEATS: Array[String] = [
	"This is the third era of the Dramgid Cycle, and the land keeps its own ledger now. Roads shorten. Names go unanswered. What is given is written; what is taken is written deeper.",
	"They say the Front is coming. Nobody agrees on what it is — only that the wards burn a little dimmer each season, and the four arms of Dom hold up more weight than they were built to bear.",
	"In Dom, the City of the Four Arms, every debt is remembered — by the Companies who tally it, by the Sentinels who guard it, and by the Registry, which forgets nothing at all.",
	"You arrive owing nothing and owed nothing. That will not last. Step carefully: the soul keeps a ledger too.",
]

var _beat_index := 0
var _completed := false
var _narration_label: Label
var _progress_label: Label


func _build() -> void:
	allow_back = false
	_add_opaque_backdrop(DS.VOID_1)

	var safe_margin := MarginContainer.new()
	safe_margin.theme_type_variation = "MainMenuSafeMargin"
	safe_margin.set_anchors_preset(Control.PRESET_FULL_RECT)
	add_child(safe_margin)

	var center := CenterContainer.new()
	center.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	center.size_flags_vertical = Control.SIZE_EXPAND_FILL
	safe_margin.add_child(center)

	var panel := PanelContainer.new()
	panel.theme_type_variation = "MainMenuMirrorFrame"
	panel.custom_minimum_size = Vector2(760, 420)
	center.add_child(panel)

	var column := VBoxContainer.new()
	column.theme_type_variation = "MainMenuColumn"
	column.alignment = BoxContainer.ALIGNMENT_CENTER
	panel.add_child(column)

	var review_label := Label.new()
	review_label.text = "PROVISIONAL — CANON REVIEW REQUIRED"
	review_label.theme_type_variation = "EyebrowLabel"
	review_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	column.add_child(review_label)

	var title := Label.new()
	title.text = "THE FRONT IS COMING"
	title.theme_type_variation = "TitleLabel"
	title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	column.add_child(title)

	column.add_child(HSeparator.new())

	_narration_label = Label.new()
	_narration_label.theme_type_variation = "HeadingLabel"
	_narration_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_narration_label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	_narration_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	_narration_label.custom_minimum_size = Vector2(680, 180)
	_narration_label.mouse_filter = Control.MOUSE_FILTER_IGNORE
	column.add_child(_narration_label)

	_progress_label = Label.new()
	_progress_label.theme_type_variation = "MutedLabel"
	_progress_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	column.add_child(_progress_label)

	var actions := HBoxContainer.new()
	actions.theme_type_variation = "MirrorPairRow"
	column.add_child(actions)

	var continue_button := Button.new()
	continue_button.text = "Continue"
	continue_button.theme_type_variation = "PrimaryButton"
	continue_button.pressed.connect(_advance)
	actions.add_child(continue_button)

	var skip_button := Button.new()
	skip_button.text = "Skip"
	skip_button.theme_type_variation = "SecondaryButton"
	skip_button.pressed.connect(_complete)
	actions.add_child(skip_button)

	_refresh_beat()


func _gui_input(event: InputEvent) -> void:
	if event is InputEventMouseButton and event.pressed:
		_advance()
		accept_event()


func _unhandled_input(event: InputEvent) -> void:
	if _completed:
		return
	if event.is_action_pressed("ui_cancel"):
		_complete()
		get_viewport().set_input_as_handled()
		return
	if event is InputEventKey and event.pressed and not event.echo:
		_advance()
		get_viewport().set_input_as_handled()
	elif event is InputEventMouseButton and event.pressed:
		_advance()
		get_viewport().set_input_as_handled()


func _advance() -> void:
	if _completed:
		return
	if _beat_index >= NARRATION_BEATS.size() - 1:
		_complete()
		return
	_beat_index += 1
	_refresh_beat()


func _refresh_beat() -> void:
	_narration_label.text = NARRATION_BEATS[_beat_index]
	_progress_label.text = "%d / %d  ·  any key or click" % [
		_beat_index + 1, NARRATION_BEATS.size()
	]


func _complete() -> void:
	if _completed:
		return
	_completed = true
	GameFlow.send_event("intro_done")
