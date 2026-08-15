class_name SMDialogueChoice
extends Button
## DialogueChoice (DS: components/narrative/DialogueChoice) — the load-bearing component
## of a Soul Meter conversation.
##  - Player lines are in quotes; tags in square brackets, UPPERCASE.
##  - `cost` renders in the mono face — numbers are the ledger.
##  - `consequence` is a promise the game keeps — what the world WILL do, never flavour.
##  - Locked choices stay VISIBLE and dim (42%) — the player must see what they cannot say.
##  - The 3px bronze→violet left edge is the selection affordance (the one allowed
##    left-border accent in the whole DS).

var choice_text: String = ""
var tag: String = ""
var cost: String = ""
var consequence: String = ""
var locked: bool = false

var _edge: ColorRect
var _text_label: Label
var _consequence_label: Label


func setup(p_text: String, p_tag: String, p_cost: String, p_consequence: String, p_locked: bool) -> void:
	choice_text = p_text
	tag = p_tag
	cost = p_cost
	consequence = p_consequence
	locked = p_locked


func _ready() -> void:
	theme_type_variation = "DialogueChoice"
	focus_mode = FOCUS_ALL
	disabled = locked
	custom_minimum_size = Vector2(0, DS.CONTROL_H_LG)
	mouse_default_cursor_shape = Control.CURSOR_POINTING_HAND
	# the 3px bronze→violet left edge — the DS's one allowed left-border accent
	_edge = ColorRect.new()
	_edge.custom_minimum_size = Vector2(3, 0)
	_edge.set_anchors_preset(Control.PRESET_LEFT_WIDE)
	_edge.offset_right = 3.0
	_edge.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(_edge)
	_set_edge(false)
	mouse_entered.connect(func() -> void: _set_edge(true))
	mouse_exited.connect(func() -> void: _set_edge(false))
	focus_entered.connect(func() -> void: _set_edge(true))
	focus_exited.connect(func() -> void: _set_edge(false))

	var margin := MarginContainer.new()
	margin.set_anchors_preset(Control.PRESET_FULL_RECT)
	margin.add_theme_constant_override("margin_left", DS.SPACE_6)
	margin.add_theme_constant_override("margin_right", DS.SPACE_5)
	margin.add_theme_constant_override("margin_top", DS.SPACE_3)
	margin.add_theme_constant_override("margin_bottom", DS.SPACE_3)
	margin.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(margin)

	var vbox := VBoxContainer.new()
	vbox.add_theme_constant_override("separation", 2)
	vbox.mouse_filter = Control.MOUSE_FILTER_IGNORE
	margin.add_child(vbox)

	# Metadata gets its own row. Keeping the spoken text out of this HBox is
	# important: long choices must wrap beneath the tag/cost instead of squeezing
	# three labels into the same line and drawing over one another.
	var meta := HBoxContainer.new()
	meta.add_theme_constant_override("separation", DS.SPACE_4)
	meta.mouse_filter = Control.MOUSE_FILTER_IGNORE
	vbox.add_child(meta)

	if not tag.is_empty():
		var tag_label := Label.new()
		tag_label.text = "[%s]" % tag.to_upper()
		tag_label.theme_type_variation = "EyebrowLabel"
		tag_label.modulate = DS.BRONZE_3
		meta.add_child(tag_label)

	var meta_spacer := Control.new()
	meta_spacer.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	meta.add_child(meta_spacer)

	if not cost.is_empty():
		var cost_label := Label.new()
		cost_label.text = cost.to_upper()
		cost_label.theme_type_variation = "StatLabel"
		cost_label.modulate = DS.BRONZE_4
		meta.add_child(cost_label)

	_text_label = Label.new()
	_text_label.text = choice_text
	_text_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	_text_label.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_text_label.mouse_filter = Control.MOUSE_FILTER_IGNORE
	vbox.add_child(_text_label)

	if not consequence.is_empty():
		_consequence_label = Label.new()
		_consequence_label.text = consequence
		_consequence_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
		_consequence_label.theme_type_variation = "QuoteLabel"
		_consequence_label.modulate = DS.ASH_DIM
		_consequence_label.mouse_filter = Control.MOUSE_FILTER_IGNORE
		vbox.add_child(_consequence_label)

	# Button children do not contribute their natural height to BaseButton's
	# minimum size. Reserve enough room for wrapped text explicitly, then update
	# it again after the button receives its real width.
	_refresh_minimum_height()
	call_deferred("_refresh_minimum_height")

	if locked:
		modulate = Color(1, 1, 1, 0.42)


func _set_edge(hot: bool) -> void:
	if _edge != null:
		_edge.color = DS.VIOLET_3 if (hot and not locked) else DS.BRONZE_2


func _notification(what: int) -> void:
	if what == NOTIFICATION_RESIZED:
		_refresh_minimum_height()


func _refresh_minimum_height() -> void:
	if _text_label == null:
		return
	var available_width := size.x
	if available_width < 100.0:
		available_width = 860.0
	available_width = maxf(200.0, available_width - DS.SPACE_6 - DS.SPACE_5)
	var body_lines := maxi(1, ceili(_text_label.text.length() / maxf(18.0, available_width / 8.5)))
	var consequence_lines := 0
	if _consequence_label != null:
		consequence_lines = maxi(
			1, ceili(_consequence_label.text.length() / maxf(18.0, available_width / 8.0))
		)
	var meta_lines := 1 if not tag.is_empty() or not cost.is_empty() else 0
	var content_height := meta_lines * 18 + body_lines * 24 + consequence_lines * 22
	custom_minimum_size.y = maxf(float(DS.CONTROL_H_LG), float(content_height + DS.SPACE_3 * 2 + 12))
