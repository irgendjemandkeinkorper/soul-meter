class_name Screen
extends Control
## Base for every menu screen. Runs while the tree is paused, fills the viewport, and offers
## small helpers so each screen is mostly content, not layout boilerplate.

## Set by UIManager when this screen was opened by the state chart (e.g. the pause menu).
## Flow-owned screens close via a chart event, not a direct stack pop.
var flow_owned := false
var allow_back := true


func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	set_anchors_preset(Control.PRESET_FULL_RECT)
	_build()
	call_deferred("_focus_first_control")


## Override: build this screen's UI here.
func _build() -> void:
	pass


func _focus_first_control() -> void:
	var focus_target := _find_first_focusable(self)
	if focus_target != null:
		focus_target.grab_focus()


func _find_first_focusable(node: Node) -> Control:
	for child in node.get_children():
		var control := child as Control
		if (
			control != null
			and control.visible
			and control.focus_mode != Control.FOCUS_NONE
			and (
				control is BaseButton
				or control is ItemList
				or control is LineEdit
				or control is Slider
			)
		):
			return control
		var nested := _find_first_focusable(child)
		if nested != null:
			return nested
	return null


## Default Back action — pop this screen off the UIManager stack.
func close() -> void:
	UIManager.back()


## The M2 full-screen shell: Screen -> MarginContainer -> VBox with exactly three
## children, Header / Body / HudBar (see design/ui-shell-conventions.md).
##
## Additive on purpose. `_make_window()` below builds the older centered-panel
## window that the ten existing screens use; migrating them is tracked separately
## rather than done here, so both shells coexist until that lands. New M2 screens
## use this one.
##
## Returns the three containers in order. `HudBar` is empty and the caller fills
## it left-to-right; whatever else goes in, SoulGauge is always added LAST so it
## stays rightmost (DS rule).
func _make_shell() -> Array[Control]:
	var margin := MarginContainer.new()
	margin.set_anchors_preset(Control.PRESET_FULL_RECT)
	margin.theme_type_variation = "ScreenShellMargin"
	add_child(margin)

	var column := VBoxContainer.new()
	column.theme_type_variation = "ScreenShellColumn"
	column.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	column.size_flags_vertical = Control.SIZE_EXPAND_FILL
	margin.add_child(column)

	var header := HBoxContainer.new()
	header.name = "Header"
	header.theme_type_variation = "ScreenHeader"
	column.add_child(header)

	var body := MarginContainer.new()
	body.name = "Body"
	# The Body is the only child that grows; Header and HudBar keep their heights.
	body.size_flags_vertical = Control.SIZE_EXPAND_FILL
	column.add_child(body)

	var hud_bar := HBoxContainer.new()
	hud_bar.name = "HudBar"
	hud_bar.theme_type_variation = "ScreenHudBar"
	column.add_child(hud_bar)

	return [header, body, hud_bar] as Array[Control]


## Enter/exit per the shell conventions: fade + settle down 8px, never scale, never
## bounce. Driven from the state chart's `state_entered` / `state_exited` so the
## animation can never disagree with the flow state.
func play_enter() -> void:
	_play_shell_transition(true)


func play_exit() -> void:
	_play_shell_transition(false)


func _play_shell_transition(entering: bool) -> void:
	var duration := DS.DUR_BASE if entering else DS.DUR_FAST
	var settle := 8.0
	modulate.a = 0.0 if entering else 1.0
	position.y = -settle if entering else 0.0

	var tween := create_tween()
	tween.set_parallel(true)
	tween.set_ease(Tween.EASE_OUT)
	tween.set_trans(Tween.TRANS_SINE)
	tween.tween_property(self, "modulate:a", 1.0 if entering else 0.0, duration)
	tween.tween_property(self, "position:y", 0.0 if entering else settle, duration)


## Dimmed full-screen backdrop + a centered panel. Returns the VBox to fill with content.
func _make_window(title_text: String, min_size: Vector2 = Vector2(520, 420)) -> VBoxContainer:
	var dim := ColorRect.new()
	dim.color = Color(0, 0, 0, 0.65)
	dim.set_anchors_preset(Control.PRESET_FULL_RECT)
	add_child(dim)

	var center := CenterContainer.new()
	center.set_anchors_preset(Control.PRESET_FULL_RECT)
	add_child(center)

	var panel := PanelContainer.new()
	# The design sizes are the preferred desktop sizes, not a hard requirement. A
	# small window must still leave room for the panel margins and a usable scroll
	# area instead of letting content spill outside the panel.
	var viewport_size := get_viewport_rect().size
	if viewport_size.x < 1.0 or viewport_size.y < 1.0:
		viewport_size = Vector2(1280, 720)
	var available_size := Vector2(
		maxf(320.0, viewport_size.x - 48.0), maxf(240.0, viewport_size.y - 48.0)
	)
	panel.custom_minimum_size = Vector2(
		minf(min_size.x, available_size.x), minf(min_size.y, available_size.y)
	)
	center.add_child(panel)

	var margin := MarginContainer.new()
	margin.theme_type_variation = "ScreenWindowMargin"
	panel.add_child(margin)

	var scroll := ScrollContainer.new()
	scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	scroll.size_flags_vertical = Control.SIZE_EXPAND_FILL
	margin.add_child(scroll)

	var vbox := VBoxContainer.new()
	vbox.theme_type_variation = "ScreenContentColumn"
	vbox.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	vbox.size_flags_vertical = Control.SIZE_EXPAND_FILL
	scroll.add_child(vbox)

	var title := Label.new()
	title.text = title_text
	title.theme_type_variation = "TitleLabel"
	vbox.add_child(title)
	vbox.add_child(HSeparator.new())
	return vbox


func _menu_button(box: Container, text: String, cb: Callable) -> Button:
	var b := Button.new()
	b.text = text
	b.custom_minimum_size = Vector2(220, 36)
	b.mouse_default_cursor_shape = Control.CURSOR_POINTING_HAND
	b.pressed.connect(cb)
	box.add_child(b)
	return b


func _section(text: String) -> Label:
	var l := Label.new()
	l.text = text
	l.theme_type_variation = "HeadingLabel"
	return l


func _add_back_button(box: Container, text: String = "Back") -> void:
	box.add_child(HSeparator.new())
	_menu_button(box, text, close)
