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


## Override: build this screen's UI here.
func _build() -> void:
	pass


## Default Back action — pop this screen off the UIManager stack.
func close() -> void:
	UIManager.back()


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
	panel.custom_minimum_size = min_size
	center.add_child(panel)

	var margin := MarginContainer.new()
	for side in ["margin_left", "margin_right", "margin_top", "margin_bottom"]:
		margin.add_theme_constant_override(side, 20)
	panel.add_child(margin)

	var vbox := VBoxContainer.new()
	vbox.add_theme_constant_override("separation", 12)
	margin.add_child(vbox)

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
