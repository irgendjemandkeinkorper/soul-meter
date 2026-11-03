class_name FieldGridLayer
extends Node2D
## The hex grid on the floor (owner item 34, ruling H-c; hex slice H3). It shows under every body
## during a fight, fading in when the fight starts and out when it ends. While exploring it shows
## faintly only when the player turns on "Show hex grid while exploring" (Settings, off by
## default). Only a hex grid draws; the square grid keeps its look.
##
## FieldMap owns this layer. It sits at z -1: above the painted floor (z -15 to -20) and the ground
## details (z -2), below every body and prop (z 0 and up). The grid is drawn in chunks of square
## cells, each built once as the view first reaches it, so walking costs nothing per frame.

const SETTING_SECTION := "display"
const SETTING_KEY := "hex_grid_exploring"
## Line strength (the layer's alpha) in a fight and while exploring with the setting on.
const COMBAT_ALPHA := 0.24
const EXPLORE_ALPHA := 0.10
## Square cells per chunk side, and how many chunks may be built in one frame.
const CHUNK_CELLS := 8
const CHUNKS_PER_FRAME := 6

var _field: FieldMap
var _grid: IsoGrid
var _combat := false
var _fade: Tween
var _chunks: Dictionary = {}  ## Vector2i chunk -> _Chunk


## One chunk's lines, drawn once; the renderer culls it while it is off screen.
class _Chunk extends Node2D:
	var segments := PackedVector2Array()

	func _draw() -> void:
		if segments.size() >= 2:
			draw_multiline(segments, DS.PARCHMENT, 1.0)


func _init(field: FieldMap = null) -> void:
	_field = field
	name = "FieldGridLayer"
	z_index = -1
	modulate.a = 0.0
	visible = false


func _ready() -> void:
	set_process(false)
	GameState.setting_changed.connect(_on_setting_changed)
	_refresh(false)


## FieldMap calls this as a fight starts and ends.
func set_combat(active: bool) -> void:
	if _combat == active:
		return
	_combat = active
	_refresh(true)


func combat_active() -> bool:
	return _combat


## The alpha the layer is heading for: the fight's, the faint exploring grid, or nothing.
func target_alpha() -> float:
	if not _hex_grid():
		return 0.0
	if _combat:
		return COMBAT_ALPHA
	return EXPLORE_ALPHA if exploring_grid_enabled() else 0.0


static func exploring_grid_enabled() -> bool:
	return bool(GameState.get_setting(SETTING_SECTION, SETTING_KEY, false))


## Chunks built so far (tests read this; the count only grows).
func chunk_count() -> int:
	return _chunks.size()


func _hex_grid() -> bool:
	if not is_instance_valid(_grid) and is_instance_valid(_field):
		_grid = _field.iso_grid()
	return is_instance_valid(_grid) and _grid.hex_mode


func _refresh(animated: bool) -> void:
	var target := target_alpha()
	if _fade != null and _fade.is_valid():
		_fade.kill()
	_fade = null
	if target > 0.0:
		visible = true
		set_process(true)
		_build_visible_chunks()
	var reduced := bool(GameState.get_setting("accessibility", "reduced_motion", false))
	if not animated or reduced or not is_inside_tree():
		modulate.a = target
		_settle(target)
		return
	_fade = create_tween().set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN_OUT)
	_fade.tween_property(self, "modulate:a", target, DS.DUR_SLOW)
	_fade.tween_callback(_settle.bind(target))


func _settle(target: float) -> void:
	_fade = null
	if target <= 0.0:
		visible = false
		set_process(false)


func _on_setting_changed(section: String, key: String, _value: Variant) -> void:
	if section == SETTING_SECTION and key == SETTING_KEY:
		_refresh(true)
	elif section == "accessibility" and key == "reduced_motion" and _fade != null:
		_refresh(false)


func _process(_delta: float) -> void:
	_build_visible_chunks()


## Builds the missing chunks the view touches, a few per frame.
func _build_visible_chunks() -> void:
	if not _hex_grid() or not is_inside_tree():
		return
	var ground := _field.ground() if is_instance_valid(_field) else null
	if not is_instance_valid(ground):
		return
	var viewport := get_viewport()
	var view := viewport.get_canvas_transform().affine_inverse() * viewport.get_visible_rect()
	var low := Vector2i(1 << 30, 1 << 30)
	var high := -low
	for corner: Vector2 in [view.position, Vector2(view.end.x, view.position.y), view.end, Vector2(view.position.x, view.end.y)]:
		var cell := ground.local_to_map(ground.to_local(corner))
		low = Vector2i(mini(low.x, cell.x), mini(low.y, cell.y))
		high = Vector2i(maxi(high.x, cell.x), maxi(high.y, cell.y))
	var rect := _grid.square_rect()
	low = Vector2i(maxi(low.x - 1, rect.position.x), maxi(low.y - 1, rect.position.y))
	high = Vector2i(mini(high.x + 1, rect.end.x - 1), mini(high.y + 1, rect.end.y - 1))
	if high.x < low.x or high.y < low.y:
		return
	var built := 0
	for cy in range(floori(float(low.y) / CHUNK_CELLS), floori(float(high.y) / CHUNK_CELLS) + 1):
		for cx in range(floori(float(low.x) / CHUNK_CELLS), floori(float(high.x) / CHUNK_CELLS) + 1):
			var key := Vector2i(cx, cy)
			if _chunks.has(key):
				continue
			_build_chunk(key, rect)
			built += 1
			if built >= CHUNKS_PER_FRAME:
				return


func _build_chunk(key: Vector2i, rect: Rect2i) -> void:
	var chunk := _Chunk.new()
	chunk.name = "Chunk_%d_%d" % [key.x, key.y]
	var start := key * CHUNK_CELLS
	for y in range(maxi(start.y, rect.position.y), mini(start.y + CHUNK_CELLS, rect.end.y)):
		for x in range(maxi(start.x, rect.position.x), mini(start.x + CHUNK_CELLS, rect.end.x)):
			for hex: Vector2i in _grid.cells_on_square(Vector2i(x, y)):
				_append_edges(chunk.segments, hex)
	_chunks[key] = chunk
	add_child(chunk)


## A floor hex draws its three right-hand edges (NE, E, SE), which its neighbours share, and any
## other edge that borders a wall or the map's end, so every floor hex is closed.
func _append_edges(segments: PackedVector2Array, hex: Vector2i) -> void:
	if not _grid.is_in_bounds(hex) or _grid.is_wall(hex):
		return
	var outline := _grid.cell_outline(hex)
	for edge: int in outline.size():
		if edge >= 3:
			var neighbour := hex + HexMath.DIRECTIONS[HexLayout.EDGE_NEIGHBOR[edge]]
			if _grid.is_in_bounds(neighbour) and not _grid.is_wall(neighbour):
				continue
		segments.append(to_local(outline[edge]))
		segments.append(to_local(outline[(edge + 1) % outline.size()]))
