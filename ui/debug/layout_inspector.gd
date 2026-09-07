extends PanelContainer
## Selection controls and movable, viewport-bounded layout panel.

signal properties_changed(values: Dictionary)
signal command_requested(command: String)

const Overrides := preload("res://globals/layout_overrides.gd")
var _fields: Dictionary = {}
var _toggles: Dictionary = {}
var _selection: Node2D
var _syncing: bool = false
var _moving: bool = false
var _move_offset: Vector2
var _initial_placement: bool = true
var _commands: Dictionary = {}


func _ready() -> void:
	var background := StyleBoxFlat.new()
	background.bg_color = Color(0.07, 0.08, 0.10, 0.98)
	add_theme_stylebox_override("panel", background)
	var toolbar := HBoxContainer.new()
	$Margin/Column.add_child(toolbar)
	$Margin/Column.move_child(toolbar, 1)
	for entry: Array in [["undo", "Undo"], ["redo", "Redo"], ["duplicate", "Duplicate"], ["delete", "Delete"]]:
		var action := Button.new()
		action.text = entry[1]
		action.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		action.pressed.connect(func() -> void: command_requested.emit(entry[0]))
		toolbar.add_child(action)
		_commands[entry[0]] = action
	var column: VBoxContainer = $Margin/Column/Scroll/Content/Transform
	_add_pair(column, "Position (X / Y)", ["x", "y"], -100000, 100000, 1.0)
	_add_pair(column, "Scale (X / Y)", ["scale_x", "scale_y"], 0.01, 20.0, 0.01)
	_add_pair(column, "Rotation / skew (degrees)", ["rotation", "skew"], -360.0, 360.0, 1.0)
	_fields["skew"].min_value = -80.0
	_fields["skew"].max_value = 80.0
	var actions := HBoxContainer.new()
	column.add_child(actions)
	for entry: Array in [["Shrink", 0.8], ["Enlarge", 1.25]]:
		var button := Button.new()
		button.text = entry[0]
		button.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		button.pressed.connect(_resize_selected.bind(float(entry[1])))
		actions.add_child(button)
	for entry: Array in [["flip_h", "Flip horizontally"], ["flip_v", "Flip vertically"], ["grayscale", "Grayscale (black and white)"]]:
		var button := CheckButton.new()
		button.text = entry[1]
		button.toggled.connect(_toggle_changed.bind(String(entry[0])))
		column.add_child(button)
		_toggles[entry[0]] = button
	$Margin/Column/DragHandle.gui_input.connect(_drag_panel)
	get_viewport().size_changed.connect(_fit_panel)
	call_deferred("_fit_panel")
	inspect(null)


func _add_pair(column: VBoxContainer, title: String, fields: Array, low: float, high: float, step_size: float) -> void:
	var label := Label.new()
	label.text = title
	column.add_child(label)
	var row := HBoxContainer.new()
	column.add_child(row)
	for field: String in fields:
		var input := SpinBox.new()
		input.name = field.to_pascal_case()
		input.tooltip_text = field.capitalize()
		input.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		input.min_value = low
		input.max_value = high
		input.step = step_size
		input.value_changed.connect(_transform_changed.bind(field))
		row.add_child(input)
		_fields[field] = input


func inspect(node: Node2D) -> void:
	_selection = node
	_syncing = true
	var valid: bool = is_instance_valid(node)
	_commands["duplicate"].disabled = not valid
	_commands["delete"].disabled = not valid
	for input: SpinBox in _fields.values():
		input.editable = valid
	if valid:
		_fields["x"].set_value_no_signal(node.position.x)
		_fields["y"].set_value_no_signal(node.position.y)
		_fields["scale_x"].set_value_no_signal(absf(node.scale.x))
		_fields["scale_y"].set_value_no_signal(absf(node.scale.y))
		_fields["rotation"].set_value_no_signal(node.rotation_degrees)
		_fields["skew"].set_value_no_signal(rad_to_deg(node.skew))
	var sprite: Sprite2D = Overrides.find_sprite(node) if valid else null
	_toggles["flip_h"].disabled = sprite == null
	_toggles["flip_v"].disabled = sprite == null
	_toggles["flip_h"].set_pressed_no_signal(sprite.flip_h if sprite != null else false)
	_toggles["flip_v"].set_pressed_no_signal(sprite.flip_v if sprite != null else false)
	_toggles["grayscale"].disabled = not valid or not Overrides.supports_grayscale(node)
	_toggles["grayscale"].set_pressed_no_signal(Overrides.is_grayscale(node) if valid else false)
	_toggles["grayscale"].tooltip_text = "Texture files stay unchanged. Assets with custom materials keep their own shader."
	_syncing = false


func _transform_changed(value: float, field: String) -> void:
	if _syncing or not is_instance_valid(_selection):
		return
	match field:
		"x": properties_changed.emit({"position": [value, _selection.position.y]})
		"y": properties_changed.emit({"position": [_selection.position.x, value]})
		"scale_x": properties_changed.emit({"scale": [value * signf(_selection.scale.x), _selection.scale.y]})
		"scale_y": properties_changed.emit({"scale": [_selection.scale.x, value * signf(_selection.scale.y)]})
		"rotation", "skew": properties_changed.emit({field: deg_to_rad(value)})


func _toggle_changed(value: bool, field: String) -> void:
	if not _syncing and is_instance_valid(_selection):
		properties_changed.emit({field: value})


func _resize_selected(factor: float) -> void:
	if not is_instance_valid(_selection):
		return
	properties_changed.emit({"scale": [
		signf(_selection.scale.x) * clampf(absf(_selection.scale.x) * factor, 0.01, 20.0),
		signf(_selection.scale.y) * clampf(absf(_selection.scale.y) * factor, 0.01, 20.0),
	]})


func _drag_panel(event: InputEvent) -> void:
	if event is InputEventMouseButton and event.button_index == MOUSE_BUTTON_LEFT:
		_moving = event.pressed
		_move_offset = get_global_mouse_position() - global_position
		accept_event()
	elif event is InputEventMouseMotion and _moving:
		global_position = get_global_mouse_position() - _move_offset
		_clamp_position()
		accept_event()


func _fit_panel() -> void:
	var available: Vector2 = get_viewport_rect().size
	size = Vector2(minf(360.0, maxf(240.0, available.x - 24.0)), maxf(160.0, minf(780.0, available.y - 108.0)))
	if _initial_placement:
		position = Vector2(available.x - size.x - 12.0, 12.0)
		_initial_placement = false
	_clamp_position()


func _clamp_position() -> void:
	var available: Vector2 = get_viewport_rect().size
	position = position.clamp(Vector2.ZERO, (available - size).max(Vector2.ZERO))
