class_name BattleStageRegion
extends Control

## Event-only isometric tactical board. The legacy Kenney environment remains composed
## underneath this transparent control; it is not replaced or queried.
signal tile_selected(tile: Dictionary)

var _tiles: Array[Dictionary] = []
var _selected := Vector2i(-1, -1)


func consume_event(event: CombatEvent) -> void:
	var snapshot: Dictionary = event.data.get("snapshot", {})
	var tile_values: Variant = event.data.get("tiles", snapshot.get("tiles", []))
	if tile_values is Array:
		_tiles.clear()
		for value: Variant in tile_values:
			if value is Dictionary:
				_tiles.append((value as Dictionary).duplicate(true))
		queue_redraw()


func rendered_tile_count() -> int:
	return _tiles.size()


func select_tile(cell: Vector2i) -> void:
	_selected = cell
	for tile: Dictionary in _tiles:
		if Vector2i(int(tile.get("x", 0)), int(tile.get("y", 0))) == cell:
			tile_selected.emit(tile.duplicate(true))
			break
	queue_redraw()


func _gui_input(event: InputEvent) -> void:
	if event is InputEventMouseButton and event.pressed:
		var closest := Vector2i(-1, -1)
		var distance := INF
		for tile: Dictionary in _tiles:
			var cell := Vector2i(int(tile.get("x", 0)), int(tile.get("y", 0)))
			var point := DS.iso_project(cell.x, cell.y, int(tile.get("height_delta", tile.get("height", 0))), _origin())
			var candidate := point.distance_squared_to(event.position)
			if candidate < distance:
				distance = candidate
				closest = cell
		if distance <= float(DS.TILE_W * DS.TILE_W):
			select_tile(closest)


func _draw() -> void:
	for tile: Dictionary in _tiles:
		var x := int(tile.get("x", 0))
		var y := int(tile.get("y", 0))
		var height := clampi(int(tile.get("height_delta", tile.get("height", 0))), 0, DS.ELEVATION_MAX)
		var center := DS.iso_project(x, y, height, _origin())
		var diamond := PackedVector2Array([
			center + Vector2(0, -DS.TILE_H * 0.5), center + Vector2(DS.TILE_W * 0.5, 0),
			center + Vector2(0, DS.TILE_H * 0.5), center + Vector2(-DS.TILE_W * 0.5, 0),
		])
		draw_colored_polygon(diamond, Color("#20242D"))
		var charge := clampi(int(tile.get("charge_level", 0)), 0, DS.CHARGE_MAX)
		if charge > 0:
			var color := Color(str(tile.get("element_color", "#7BDFF2")))
			draw_colored_polygon(diamond, DS.charge_tint(color, charge))
			draw_string(ThemeDB.fallback_font, center + Vector2(-4, 5), str(tile.get("charge_element_id", "?")).left(1).to_upper(), HORIZONTAL_ALIGNMENT_LEFT, -1, 12, Color(color, float(charge) / DS.CHARGE_MAX))
		var selected := Vector2i(x, y) == _selected
		draw_polyline(PackedVector2Array([diamond[0], diamond[1], diamond[2], diamond[3], diamond[0]]), DS.TILE_SELECT_RIM if selected else Color("#58606F"), 1.0)
		draw_string(ThemeDB.fallback_font, center + Vector2(-6, 22), "H%d" % height, HORIZONTAL_ALIGNMENT_LEFT, -1, 11, Color("#D9DEE8"))


func _origin() -> Vector2:
	return Vector2(size.x * 0.5, maxf(36.0, size.y * 0.18))
