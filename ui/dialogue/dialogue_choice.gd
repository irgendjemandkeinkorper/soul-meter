class_name SMDialogueChoice
extends Button
## DialogueChoice (DS: components/narrative/DialogueChoice) — the load-bearing component
## of a Soul Meter conversation. U1 (owner 2026-11-01) shape:
##  - Player lines are in quotes; the tag in square brackets, UPPERCASE, followed by the
##    player's chance in the stat face when the choice rolls a check ("[UNDERTONE] 62%").
##  - `effects` is the exact ledger the choice writes ("SOUL −6 · SSAE SEEDERS +3"), mono,
##    right of the tag: numbers are the ledger.
##  - `consequence` is the promise the game keeps. The balloon shows it once, for the
##    focused choice, in its promise line; a row never prints it, so a menu stays short.
##  - A locked choice is visible and dim (42%) only when the player could earn it, and its
##    `lock_reason` names the system and the bar (FR-606). Other locks never reach a row.
##  - The 3px bronze→violet left edge is the selection affordance (the one allowed
##    left-border accent in the whole DS).

## Hover or focus moved onto (true) or off (false) this row; the balloon's promise line
## follows it.
signal hot_changed(hot: bool)

var choice_text: String = ""
var tag: String = ""
var odds: int = -1
var effects: String = ""
var consequence: String = ""
var locked: bool = false
var lock_reason: String = ""

var _edge: ColorRect
var _text_label: Label
var _reason_label: Label


func setup(
	p_text: String,
	p_tag: String,
	p_effects: String,
	p_consequence: String,
	p_locked: bool,
	p_odds: int = -1,
	p_lock_reason: String = "",
) -> void:
	choice_text = p_text
	tag = p_tag
	effects = p_effects
	consequence = p_consequence
	locked = p_locked
	odds = p_odds
	lock_reason = p_lock_reason


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
	vbox.theme_type_variation = "DialogueChoiceRows"
	vbox.mouse_filter = Control.MOUSE_FILTER_IGNORE
	margin.add_child(vbox)

	# Metadata gets its own row. Keeping the spoken text out of this HBox is
	# important: long choices must wrap beneath the tag/effects instead of squeezing
	# three labels into the same line and drawing over one another.
	if _has_meta():
		var meta := HBoxContainer.new()
		meta.name = "Meta"
		meta.theme_type_variation = "DialogueChoiceMeta"
		meta.mouse_filter = Control.MOUSE_FILTER_IGNORE
		vbox.add_child(meta)
		if not tag.is_empty():
			var tag_label := Label.new()
			tag_label.name = "Tag"
			tag_label.text = "[%s]" % tag.to_upper()
			tag_label.theme_type_variation = "EyebrowLabel"
			tag_label.modulate = DS.BRONZE_3
			meta.add_child(tag_label)
		if odds >= 0:
			var odds_label := Label.new()
			odds_label.name = "Odds"
			odds_label.text = "%d%%" % odds
			odds_label.theme_type_variation = "DialogueOddsLabel"
			meta.add_child(odds_label)
		var meta_spacer := Control.new()
		meta_spacer.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		meta_spacer.mouse_filter = Control.MOUSE_FILTER_IGNORE
		meta.add_child(meta_spacer)
		if not effects.is_empty():
			var effects_label := Label.new()
			effects_label.name = "Effects"
			effects_label.text = effects
			effects_label.theme_type_variation = "DialogueEffectLabel"
			meta.add_child(effects_label)

	_text_label = Label.new()
	_text_label.name = "Line"
	_text_label.text = choice_text
	_text_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	_text_label.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_text_label.mouse_filter = Control.MOUSE_FILTER_IGNORE
	vbox.add_child(_text_label)

	if locked and not lock_reason.is_empty():
		_reason_label = Label.new()
		_reason_label.name = "LockReason"
		_reason_label.text = lock_reason
		_reason_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
		_reason_label.theme_type_variation = "DialogueLockReasonLabel"
		_reason_label.mouse_filter = Control.MOUSE_FILTER_IGNORE
		vbox.add_child(_reason_label)

	# Button children do not contribute their natural height to BaseButton's
	# minimum size. Reserve enough room for wrapped text explicitly, then update
	# it again after the button receives its real width.
	_refresh_minimum_height()
	call_deferred("_refresh_minimum_height")

	if locked:
		modulate = Color(1, 1, 1, 0.42)


func _has_meta() -> bool:
	return not tag.is_empty() or odds >= 0 or not effects.is_empty()


func _set_edge(hot: bool) -> void:
	if _edge != null:
		_edge.color = DS.VIOLET_3 if (hot and not locked) else DS.BRONZE_2
	hot_changed.emit(hot)


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
	var reason_lines := 0
	if _reason_label != null:
		reason_lines = maxi(1, ceili(_reason_label.text.length() / maxf(18.0, available_width / 8.0)))
	var meta_lines := 1 if _has_meta() else 0
	var content_height := meta_lines * 18 + body_lines * 24 + reason_lines * 18
	custom_minimum_size.y = maxf(float(DS.CONTROL_H_LG), float(content_height + DS.SPACE_3 * 2 + 12))
