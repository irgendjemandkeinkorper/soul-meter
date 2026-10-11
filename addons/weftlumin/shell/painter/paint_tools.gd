class_name WeftluminPaintTools
extends VBoxContainer
## Dock controls and viewport overlay for the data-layer painters (§4.6.3).
##
## Presentation only: every edit is a `WeftluminTilePainter` command. While **Paint** is on, the
## host routes viewport pointer events here instead of to its selection tool. The overlay draws
## the walkability of one of the painter's grids — rebuilt after every stroke — and always says
## which one, with its clearance, because the player's path grid and the placement grid
## disagree next to every wall. Colours come from the host (`colors`); chrome uses the shell's
## `Editor*` theme variations.

signal changed

## Overlay choice 0 is "off"; choice n shows `painter.grids()[n - 1]`.
const OVERLAY_OFF := "Overlay off"

var painter: WeftluminTilePainter = null
## Host palette: `blocked`, `blocked_edge`, `walkable`, `preview`, `caption`, `caption_back`.
## A layer value may carry its own `color`. A missing key draws nothing.
var colors: Dictionary = {}
var paint_toggle: CheckBox
var layer_option: OptionButton
var brush_option: OptionButton
var value_option: OptionButton
var overlay_option: OptionButton
var caption: Label
var status: Label


func _init() -> void:
	name = "PaintTools"
	theme_type_variation = &"EditorColumn"
	paint_toggle = CheckBox.new()
	paint_toggle.name = "Paint"
	paint_toggle.text = "Paint data layers"
	paint_toggle.theme_type_variation = &"EditorCheckBox"
	paint_toggle.toggled.connect(_on_paint_toggled)
	add_child(paint_toggle)
	layer_option = _option("PaintLayer", _on_layer_selected)
	brush_option = _option("Brush", _on_brush_selected)
	for label: String in WeftluminBrushes.LABELS:
		brush_option.add_item(label)
	value_option = _option("PaintValue", _on_value_selected)
	overlay_option = _option("Overlay", _on_overlay_selected)
	caption = _label("Caption")
	status = _label("PaintStatus")


## Show `new_painter`'s layers and grids. Keeps the current choices where they still exist.
func bind(new_painter: WeftluminTilePainter) -> void:
	if painter != null and painter.painted.is_connected(_on_painted):
		painter.painted.disconnect(_on_painted)
	painter = new_painter
	if painter != null:
		painter.painted.connect(_on_painted)
	layer_option.clear()
	for id: StringName in painter.layer_ids() if painter != null else [] as Array[StringName]:
		layer_option.add_item(String(id))
		layer_option.set_item_metadata(layer_option.item_count - 1, id)
	var previous_overlay: int = overlay_option.selected
	overlay_option.clear()
	overlay_option.add_item(OVERLAY_OFF)
	for spec: Dictionary in painter.grids() if painter != null else [] as Array[Dictionary]:
		overlay_option.add_item(str(spec["label"]))
	overlay_option.select(clampi(previous_overlay, 0, overlay_option.item_count - 1))
	var has_layers: bool = layer_option.item_count > 0
	paint_toggle.disabled = not has_layers
	if not has_layers:
		paint_toggle.set_pressed_no_signal(false)
	var index: int = maxi(painter.layer_ids().find(painter.active_layer), 0) if has_layers else -1
	if has_layers:
		layer_option.select(index)
		_on_layer_selected(index)
	brush_option.select(int(painter.shape) if painter != null else 0)
	_refresh_caption()


func painting() -> bool:
	return paint_toggle.button_pressed and painter != null and not painter.layer_ids().is_empty()


func set_painting(on: bool) -> void:
	paint_toggle.button_pressed = on


func select_layer(id: StringName) -> void:
	var index: int = painter.layer_ids().find(id)
	if index >= 0:
		layer_option.select(index)
		_on_layer_selected(index)


func select_value(label: String) -> void:
	for index: int in value_option.item_count:
		if value_option.get_item_text(index) == label:
			value_option.select(index)
			_on_value_selected(index)
			return


func select_brush(shape: WeftluminBrushes.Shape) -> void:
	brush_option.select(int(shape))
	_on_brush_selected(int(shape))


## 0 hides the overlay; n shows grid n.
func select_overlay(index: int) -> void:
	overlay_option.select(clampi(index, 0, overlay_option.item_count - 1))
	_on_overlay_selected(overlay_option.selected)


## The overlay's label: which grid and clearance it shows ("" when off).
func overlay_caption() -> String:
	var spec: Dictionary = _overlay_spec()
	return "" if spec.is_empty() else "Walkability: %s" % spec["label"]


## A viewport pointer event in world space. True when the painter consumed it.
func pointer_input(event: InputEvent, world_position: Vector2) -> bool:
	if not painting():
		return false
	if event is InputEventMouseButton:
		var button := event as InputEventMouseButton
		if button.button_index == MOUSE_BUTTON_LEFT:
			_report(painter.press(world_position) if button.pressed else painter.release())
		elif button.button_index == MOUSE_BUTTON_RIGHT and button.pressed:
			painter.cancel()
	elif event is InputEventMouseMotion:
		if (event as InputEventMouseMotion).button_mask & MOUSE_BUTTON_MASK_LEFT:
			painter.drag(world_position)
		elif painter.stroke_active():
			_report(painter.release())
	changed.emit()
	return true


## A release the viewport missed (over a dock, outside the window) still ends the stroke.
func finish_pointer() -> void:
	if painter != null and painter.stroke_active():
		_report(painter.release())
		changed.emit()


func cancel() -> void:
	if painter != null:
		painter.cancel()
		changed.emit()


## Draw the overlay, the active layer's painted cells and the stroke preview on `surface`.
func draw_overlay(surface: Control, world_to_surface: Transform2D) -> void:
	if painter == null:
		return
	var spec: Dictionary = _overlay_spec()
	if not spec.is_empty():
		_draw_walkability(surface, world_to_surface, spec)
	var id: StringName = painter.active_layer
	var node: TileMapLayer = painter.layer_node(id)
	var space: TileMapLayer = painter.space_layer(id)
	if painting() and node != null and space != null:
		for value: Dictionary in painter.layer_values(id):
			if not value.has("color"):
				continue
			for cell: Vector2i in node.get_used_cells():
				if WeftluminTilePainter.read_tile(node, cell) == (value["tile"] as Array):
					_outline(surface, _diamond(space, cell, world_to_surface), value["color"])
		for cell: Vector2i in painter.preview_cells():
			_outline(surface, _diamond(space, cell, world_to_surface), colors.get("preview"))
	if not spec.is_empty():
		_draw_caption(surface, overlay_caption())


func _draw_walkability(surface: Control, world_to_surface: Transform2D, spec: Dictionary) -> void:
	var grid: IsoGrid = spec["grid"]
	var ground: TileMapLayer = spec["ground"]
	if grid == null or not is_instance_valid(ground) or ground.tile_set == null:
		return
	var region: Rect2i = grid.get_used_rect()
	var visible_area := Rect2(Vector2.ZERO, surface.size)
	for y: int in range(region.position.y, region.end.y):
		for x: int in range(region.position.x, region.end.x):
			var cell := Vector2i(x, y)
			var points: PackedVector2Array = _diamond(ground, cell, world_to_surface)
			if not visible_area.intersects(Rect2(points[0], Vector2.ZERO).expand(points[1]).expand(points[2]).expand(points[3])):
				continue
			if grid.is_blocked_for(cell):
				if colors.has("blocked"):
					surface.draw_colored_polygon(points, colors["blocked"])
				_outline(surface, points, colors.get("blocked_edge"))
			else:
				_outline(surface, points, colors.get("walkable"))


func _draw_caption(surface: Control, text: String) -> void:
	if not colors.has("caption"):
		return
	var font: Font = surface.get_theme_font(&"font", &"EditorLabel")
	var size: int = surface.get_theme_font_size(&"font_size", &"EditorLabel")
	var margin: float = float(size) * 0.5
	var extent: Vector2 = font.get_string_size(text, HORIZONTAL_ALIGNMENT_LEFT, -1, size)
	var baseline := Vector2(margin, surface.size.y - margin - font.get_descent(size))
	if colors.has("caption_back"):
		surface.draw_rect(Rect2(
			Vector2(0.0, surface.size.y - extent.y - 2.0 * margin), extent + Vector2(2.0 * margin, 2.0 * margin)
		), colors["caption_back"])
	surface.draw_string(font, baseline, text, HORIZONTAL_ALIGNMENT_LEFT, -1, size, colors["caption"])


## The cell's diamond in `space`, in surface coordinates.
static func _diamond(space: TileMapLayer, cell: Vector2i, world_to_surface: Transform2D) -> PackedVector2Array:
	var centre: Vector2 = space.map_to_local(cell)
	var half := Vector2(space.tile_set.tile_size) * 0.5
	var points := PackedVector2Array()
	for offset: Vector2 in [Vector2(0, -half.y), Vector2(half.x, 0), Vector2(0, half.y), Vector2(-half.x, 0)]:
		points.append(world_to_surface * space.to_global(centre + offset))
	return points


static func _outline(surface: Control, points: PackedVector2Array, color: Variant) -> void:
	if not color is Color:
		return
	var closed := points.duplicate()
	closed.append(points[0])
	surface.draw_polyline(closed, color as Color, 1.0)


func _overlay_spec() -> Dictionary:
	if painter == null or overlay_option.selected <= 0:
		return {}
	var specs: Array[Dictionary] = painter.grids()
	return specs[overlay_option.selected - 1] if overlay_option.selected - 1 < specs.size() else {}


func _on_paint_toggled(on: bool) -> void:
	if painter != null:
		painter.cancel()
	# Painting without seeing walkability is guessing: show the first grid unless one is chosen.
	if on and overlay_option.selected <= 0 and overlay_option.item_count > 1:
		overlay_option.select(1)
	_refresh_caption()
	changed.emit()


func _on_layer_selected(index: int) -> void:
	if painter == null or index < 0:
		return
	painter.cancel()
	painter.active_layer = layer_option.get_item_metadata(index)
	value_option.clear()
	for value: Dictionary in painter.layer_values(painter.active_layer):
		value_option.add_item(str(value["label"]))
	if value_option.item_count > 0:
		value_option.select(0)
		_on_value_selected(0)
	changed.emit()


func _on_value_selected(index: int) -> void:
	var values: Array[Dictionary] = painter.layer_values(painter.active_layer) if painter != null else [] as Array[Dictionary]
	if index >= 0 and index < values.size():
		painter.tile = (values[index]["tile"] as Array).duplicate()


func _on_brush_selected(index: int) -> void:
	if painter != null:
		painter.cancel()
		painter.shape = index as WeftluminBrushes.Shape


func _on_overlay_selected(_index: int) -> void:
	_refresh_caption()
	changed.emit()


func _on_painted(_id: StringName) -> void:
	changed.emit()


func _refresh_caption() -> void:
	var text: String = overlay_caption()
	caption.text = text
	caption.visible = not text.is_empty()


func _report(outcome: Dictionary) -> void:
	var message: String = "" if bool(outcome.get("allowed", true)) else str(outcome.get("message", ""))
	status.text = message
	status.visible = not message.is_empty()


func _option(node_name: String, action: Callable) -> OptionButton:
	var option := OptionButton.new()
	option.name = node_name
	option.theme_type_variation = &"EditorOptionButton"
	option.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	option.item_selected.connect(action)
	add_child(option)
	return option


func _label(node_name: String) -> Label:
	var label := Label.new()
	label.name = node_name
	label.theme_type_variation = &"EditorLabel"
	label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	label.visible = false
	add_child(label)
	return label
