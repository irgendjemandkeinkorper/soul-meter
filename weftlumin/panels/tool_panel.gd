class_name SoulMeterToolPanel
extends WeftluminPanel
## Shared hosting for the five re-hosted debug tools (architecture §4.5.5, E2.5a).
##
## Each panel owns ONE private instance of its tool's model script (`weftlumin/panels/models/*`,
## export-excluded) and enables it through the model's `host_in_panel()` seam; the legacy autoload
## hosts were removed in E2.5b (#337), so the panel is the model's only host. The model is a
## child of the panel: it lives exactly as long as the dock that shows it, and its own
## `_exit_tree()` shutdown (restore, disconnect, tear down) runs when the shell closes.
##
## Presentation only: every effect is the model's. Chrome uses the `Editor*` theme variations.

var model: Node = null
var _host: WeftluminShell = null
var _status: Label = null


## Model script this panel hosts. Subclasses return their tool's script.
func _model_script() -> Script:
	return null


## Enable the hosted model. Sandbox panels pass the shell's owner token.
func _attach_model() -> bool:
	return bool(model.call("host_in_panel"))


## Build the panel's controls once the model is live.
func _build(_content: VBoxContainer) -> void:
	pass


func configure(host: WeftluminShell) -> void:
	_host = host
	var script: Script = _model_script()
	if script == null or model != null:
		return
	model = script.new() as Node
	model.name = "Model"
	add_child(model)
	if not _attach_model():
		push_warning("Weftlumin: %s could not host its model." % title)
	var scroll := ScrollContainer.new()
	scroll.name = "Scroll"
	scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	add_child(scroll)
	scroll.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	var content := VBoxContainer.new()
	content.name = "Content"
	content.theme_type_variation = &"EditorColumn"
	content.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	content.size_flags_vertical = Control.SIZE_EXPAND_FILL
	scroll.add_child(content)
	_build(content)
	_status = _label("", &"EditorLabel", true)
	_status.name = "Status"
	_status.visible = false
	content.add_child(_status)
	refresh({})


## Last presentation message, for refusals the model reports only as warnings.
func status_text() -> String:
	return _status.text if _status != null else ""


func _set_status(text: String) -> void:
	if _status != null:
		_status.text = text
		_status.visible = not text.is_empty()


## `wrap` only for labels a column gives a width; a wrapping label in a row collapses to one
## character per line and stretches the whole row.
static func _label(
	text: String, variation: StringName = &"EditorLabel", wrap: bool = false
) -> Label:
	var label := Label.new()
	label.text = text
	label.theme_type_variation = variation
	if wrap:
		label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	return label


static func _row() -> HBoxContainer:
	var row := HBoxContainer.new()
	row.theme_type_variation = &"EditorRow"
	return row


static func _button(text: String, node_name: String, action: Callable) -> Button:
	var button := Button.new()
	button.name = node_name
	button.text = text
	button.theme_type_variation = &"EditorButton"
	button.pressed.connect(action)
	return button


static func _option(node_name: String) -> OptionButton:
	var option := OptionButton.new()
	option.name = node_name
	option.theme_type_variation = &"EditorOptionButton"
	return option


static func _text_box(node_name: String, editable: bool) -> TextEdit:
	var box := TextEdit.new()
	box.name = node_name
	box.theme_type_variation = &"EditorTextEdit"
	box.editable = editable
	box.wrap_mode = TextEdit.LINE_WRAPPING_BOUNDARY
	box.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	box.size_flags_vertical = Control.SIZE_EXPAND_FILL
	box.scroll_fit_content_height = true
	return box


static func _selected_metadata(option: OptionButton) -> Variant:
	if option.item_count == 0 or option.selected < 0:
		return null
	return option.get_item_metadata(option.selected)
