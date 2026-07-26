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


func setup(p_text: String, p_tag: String, p_cost: String, p_consequence: String, p_locked: bool) -> void:
	choice_text = p_text
	tag = p_tag
	cost = p_cost
	consequence = p_consequence
	locked = p_locked


func _ready() -> void:
	focus_mode = FOCUS_ALL
	disabled = locked
	custom_minimum_size = Vector2(0, DS.CONTROL_H_LG)
	# the 3px bronze→violet left edge — the DS's one allowed left-border accent
	_edge = ColorRect.new()
	_edge.custom_minimum_size = Vector2(3, 0)
	_edge.set_anchors_preset(Control.PRESET_LEFT_WIDE)
	_edge.offset_right = 3.0
	_edge.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(_edge)
	_style(false)
	mouse_entered.connect(func() -> void: _style(true))
	mouse_exited.connect(func() -> void: _style(false))
	focus_entered.connect(func() -> void: _style(true))
	focus_exited.connect(func() -> void: _style(false))

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

	var top := HBoxContainer.new()
	top.add_theme_constant_override("separation", DS.SPACE_4)
	top.mouse_filter = Control.MOUSE_FILTER_IGNORE
	vbox.add_child(top)

	if not tag.is_empty():
		var tag_label := Label.new()
		tag_label.text = "[%s]" % tag.to_upper()
		tag_label.theme_type_variation = "EyebrowLabel"
		tag_label.modulate = DS.BRONZE_3
		top.add_child(tag_label)

	var text_label := Label.new()
	text_label.text = choice_text
	text_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	text_label.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	top.add_child(text_label)

	if not cost.is_empty():
		var cost_label := Label.new()
		cost_label.text = cost.to_upper()
		cost_label.theme_type_variation = "StatLabel"
		cost_label.modulate = DS.BRONZE_4
		top.add_child(cost_label)

	if not consequence.is_empty():
		var cons := Label.new()
		cons.text = consequence
		cons.theme_type_variation = "QuoteLabel"
		cons.modulate = DS.ASH_DIM
		vbox.add_child(cons)

	if locked:
		modulate = Color(1, 1, 1, 0.42)


func _style(hot: bool) -> void:
	var sb := StyleBoxFlat.new()
	sb.bg_color = DS.STONE_2 if (hot and not locked) else DS.STONE_1
	sb.border_color = DS.VIOLET_3 if (hot and not locked) else DS.IRON_1
	sb.set_border_width_all(1)
	sb.set_corner_radius_all(DS.RADIUS)
	sb.set_content_margin_all(0)
	for state in ["normal", "hover", "pressed", "focus", "disabled"]:
		add_theme_stylebox_override(state, sb)
	if _edge != null:
		_edge.color = DS.VIOLET_3 if (hot and not locked) else DS.BRONZE_2
