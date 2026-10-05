class_name BattleStageRegion
extends Control

## Event-only isometric tactical board (#211 presentation pass).
##
## Rebuilds its whole view from each CombatEvent's snapshot: the tile grid
## (scaled to fill the region instead of a fixed corner), one painterly unit
## sprite per living actor at its grid cell, active/target cell rims, and
## action feedback beats (attacker lunge, damage pop, KO fall, path-following
## move slides). Purely presentational — the frozen region contract
## (consume_event / tile_selected / rendered_tile_count / select_tile) is
## unchanged; tile_hovered is an additive signal.
signal tile_selected(tile: Dictionary)
signal tile_hovered(tile: Dictionary)
signal pointer_pressed(tile: Dictionary, actor_id: StringName)
signal pointer_cleared

const UnitArtScript := preload("res://globals/unit_art.gd")
const FieldOverlayScript := preload("res://world/combat_overlay.gd")
const HitPulseScript := preload("res://ui/hud/hit_pulse.gd")
const SpellCastScript := preload("res://ui/hud/spell_cast_effect.gd")
const CombatMotionScript := preload("res://ui/hud/combat_motion.gd")
const CombatResultScene := preload("res://ui/hud/combat_result.tscn")
const TargetPreviewScene := preload("res://ui/hud/target_preview.tscn")
const BACKDROP_PATTERN := "res://assets/generated/backgrounds/combat/%s-battlefield-v1.png"
const GROUND_ATLAS := preload("res://assets/generated/sprites/ground/ground_tiles.png")

## Ground diamonds from the generated Kenney tileset (64x32, same 2:1 ratio the
## stage projects at): road battles pave with the road tile, everything else is
## broken field. Variants are picked deterministically per cell. GROUND_STONE is
## a boulder prop render, not flat paving — never use it as ground.
const GROUND_ROAD_VARIANTS: Array[Vector2i] = [IsometricSpriteCatalog.GROUND_ROAD]
const GROUND_FIELD_VARIANTS: Array[Vector2i] = [
	IsometricSpriteCatalog.GROUND_GRASS, IsometricSpriteCatalog.GROUND_DIRT,
]
## Dims the bright source tiles toward the battle screen's moody palette; the
## translucency lets the dark diamond under-fill mute the Kenney saturation.
const GROUND_MODULATE := Color(0.62, 0.63, 0.68, 0.60)

const FIT_MARGIN := 20.0
## Full field grids can be much larger than the old encounter boards. Permit
## overview scales so their edge combatants remain inside this region.
const MIN_SCALE := 0.01
const MAX_SCALE := 2.4
## Sprite height as a multiple of a (scaled) tile height — reads as "a figure
## standing on the tile" rather than a giant or a speck.
const SPRITE_TILE_HEIGHTS := 2.6
const ACTIVE_RIM := Color("#C9A227")  # bronze — matches the DS "current" accent
const TARGET_RIM := Color("#E06C5A")
const HOVER_RIM := Color("#9AA3B2")
const REACHABLE_TINT := Color(0.24, 0.56, 0.42, 0.18)
const PATH_TINT := Color(0.82, 0.67, 0.24, 0.20)
const PENDING_TINT := Color(0.84, 0.71, 1.0, 0.30)  # khor glow: the cells being picked
const FIRE_TINT := Color(0.94, 0.42, 0.16, 0.34)
const MARK_TINT := Color(0.94, 0.42, 0.16, 0.14)   # filed, not yet burning
const LIGHT_TINT := Color(1.0, 0.94, 0.70, 0.22)
const SHROUD_TINT := Color(0.22, 0.16, 0.36, 0.30)
const COVER_COLOR := Color("#D6C184")
const COVER_ART_PATTERN := "res://assets/generated/sprites/terrain/cover_%s.png"
const COVER_ART_TILE_WIDTHS := 1.35  # prop footprint relative to a tile's width
const ACTION_FEEDBACK_SECONDS := 0.7
const KO_MODULATE := Color(0.5, 0.5, 0.56, 0.45)
const KO_FALL_RADIANS := deg_to_rad(78.0)
const NO_CELL := Vector2i(-999, -999)

## Tile dictionaries are the controller snapshot's own, held by reference: each snapshot
## builds fresh ones and no presentation code writes to them. Copies leave through _tile_at().
var _tiles: Array[Dictionary] = []
var _tile_index: Dictionary = {}  # Vector2i -> the tile dictionary in _tiles; see _tile_lookup()
var _tile_index_stale := false
## The payload array _tiles was read from. The controller hands out the same read-only array
## until a tile changes, so an identical one means there is nothing to re-read.
var _tiles_source: Array = []
## The snapshot's actor rows, by reference (read-only here; each snapshot builds fresh rows).
var _actors: Array[Dictionary] = []
var _backdrop_texture_cache: Dictionary = {}
var _cover_texture_cache: Dictionary = {}
var _cover_nodes: Dictionary = {}
var _encounter_id: StringName = &""
var _active_id: StringName = &""
var _target_id: StringName = &""
var _selected := Vector2i(-1, -1)
var _hovered := Vector2i(-1, -1)
var _reachable: Dictionary = {}
var _hover_path: Array[Vector2i] = []
var _pending_cells: Array[Vector2i] = []
var _fire_cells: Dictionary = {}   # Vector2i -> true (burning now)
var _mark_cells: Dictionary = {}   # Vector2i -> true (filed for a later beat)
var _light_cells: Dictionary = {}
var _shroud_cells: Dictionary = {}  # Vector2i -> true (inside a Shroud / Eclipse Procession)  # Vector2i -> true (inside a Witness Light)
var _input_locked_until_msec := 0
var _pointer_turn_available := true
var _fallen: Dictionary = {}
var _pending_path_id: StringName = &""
var _pending_path: Array[Vector2i] = []
var _backdrop: TextureRect
var _units_layer: Control
var _fx_layer: Control
var _unit_nodes: Dictionary = {}
var _field_overlay: FieldOverlayScript
var _animate_events := true
var _hit_flashes: Dictionary = {}
var _moves: Dictionary = {}
var _falls: Dictionary = {}
var _pending_defeats: Dictionary = {}
var _preview_id: StringName = &""
var target_preview: PanelContainer


## Receives a public quote from the interface; no combat arithmetic or rolls here.
func show_target_preview(actor_id: StringName, actor_name: String, quote: String) -> void:
	_preview_id = actor_id
	(target_preview.get_node("Column/TargetName") as Label).text = actor_name
	(target_preview.get_node("Column/Quote") as Label).text = quote
	target_preview.reset_size()
	target_preview.show()
	if is_instance_valid(_field_overlay):
		_field_overlay.set_preview_target(actor_id)
	_process(0.0)
	queue_redraw()


func clear_target_preview() -> void:
	_preview_id = &""
	if is_instance_valid(target_preview):
		target_preview.hide()
	if is_instance_valid(_field_overlay):
		_field_overlay.set_preview_target(&"")
	queue_redraw()


func _process(_delta: float) -> void:
	if _preview_id.is_empty() or not is_instance_valid(target_preview):
		return
	var cell := _cell_of(_preview_id)
	if cell == NO_CELL:
		clear_target_preview()
		return
	# Project through the field's canvas transform too, so camera motion keeps the
	# quote beside its target while text remains at HUD scale.
	var anchor := cell_center(cell)
	var desired := anchor + Vector2(DS.SPACE_8, -target_preview.size.y - DS.SPACE_8)
	if desired.x + target_preview.size.x > size.x - DS.SPACE_4:
		desired.x = anchor.x - target_preview.size.x - DS.SPACE_8
	target_preview.position = desired.clamp(Vector2.ONE * DS.SPACE_4,
		(size - target_preview.size - Vector2.ONE * DS.SPACE_4).max(Vector2.ONE * DS.SPACE_4))


## Migration step 6: the region retains its frozen input/payload API while the
## loaded field owns projection and actor presentation for ambient sessions.
func bind_field(field: FieldMap) -> void:
	if is_instance_valid(_field_overlay):
		_field_overlay.free()
	_field_overlay = FieldOverlayScript.new()
	_field_overlay.name = "CombatOverlay"
	field.add_child(_field_overlay)
	_field_overlay.bind_field(field)
	_sync_view_window()
	if not resized.is_connected(_sync_view_window):
		resized.connect(_sync_view_window)
	_backdrop.hide()
	_units_layer.hide()
	_fx_layer.hide()
	queue_redraw()


## The field shows through this region only; the overlay frames the fight inside it.
func _sync_view_window() -> void:
	if is_instance_valid(_field_overlay):
		_field_overlay.set_view_window(get_global_rect())


func _exit_tree() -> void:
	if is_instance_valid(_field_overlay):
		_field_overlay.name = "RetiredCombatOverlay"
		_field_overlay.queue_free()


func set_replaying(replaying: bool) -> void:
	_animate_events = not replaying
	if replaying:
		_settle_motion()
		for effect: Node in _fx_layer.get_children():
			effect.queue_free()
	if is_instance_valid(_field_overlay):
		_field_overlay.animate_events = not replaying


func _ready() -> void:
	GameState.setting_changed.connect(_on_setting_changed)
	_backdrop = TextureRect.new()
	_backdrop.name = "EnvironmentBackdrop"
	_backdrop.set_anchors_preset(Control.PRESET_FULL_RECT)
	_backdrop.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	_backdrop.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_COVERED
	_backdrop.texture_filter = CanvasItem.TEXTURE_FILTER_LINEAR
	_backdrop.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_backdrop.modulate = Color(0.72, 0.75, 0.80, 0.72)
	_backdrop.show_behind_parent = true
	_backdrop.hide()
	add_child(_backdrop)
	_units_layer = Control.new()
	_units_layer.name = "UnitsLayer"
	_units_layer.set_anchors_preset(Control.PRESET_FULL_RECT)
	_units_layer.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(_units_layer)
	_fx_layer = Control.new()
	_fx_layer.name = "FxLayer"
	_fx_layer.set_anchors_preset(Control.PRESET_FULL_RECT)
	_fx_layer.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(_fx_layer)
	target_preview = TargetPreviewScene.instantiate() as PanelContainer
	target_preview.z_index = 2
	add_child(target_preview)
	resized.connect(
		func() -> void:
			_settle_motion()
			queue_redraw()
	)
	mouse_exited.connect(
		func() -> void:
			if _hovered != Vector2i(-1, -1):
				_hovered = Vector2i(-1, -1)
				_hover_path.clear()
				queue_redraw()
				if is_instance_valid(_field_overlay):
					_field_overlay.set_pointer(_selected, null)
	)


func consume_event(event: CombatEvent) -> void:
	var snapshot: Dictionary = event.data.get("snapshot", {})
	_encounter_id = StringName(str(snapshot.get("encounter_id", "")))
	var tile_values: Variant = event.data.get("tiles", snapshot.get("tiles", []))
	if tile_values is Array and not is_same(tile_values, _tiles_source):
		_tiles_source = tile_values
		_tiles.clear()
		for value: Variant in tile_values:
			if value is Dictionary:
				_tiles.append(value)
		_tile_index_stale = true
	_read_actors(snapshot)
	_set_movement(snapshot.get("movement", {}))
	_read_fields(snapshot)
	match event.type:
		&"turn_started", &"enemy_turn_started":
			_active_id = event.actor_id
			_target_id = &""
		&"action_resolved":
			if event.actor_id != &"":
				_active_id = event.actor_id
			_target_id = event.target_id
		&"battle_finished":
			_active_id = &""
			_target_id = &""
	if is_instance_valid(_field_overlay):
		_field_overlay.consume_event(event)
		_field_overlay.set_pointer(_selected, _hovered)
		return
	if _animate_events and not _reduced_motion() and _unit_nodes.has(event.actor_id) \
			and SpellCastScript.is_cast(event) and HitPulseScript.is_damaging_hit(event):
		_pending_defeats[event.target_id] = event.get_instance_id()
	var move_path := _path_cells(event.data.get("path_cells", []))
	if _animate_events and not _reduced_motion() and event.type == &"action_resolved" and move_path.size() >= 2 \
			and _unit_nodes.has(event.actor_id):
		_pending_path_id = event.actor_id
		_pending_path = move_path
		_input_locked_until_msec = Time.get_ticks_msec() + roundi(
			float(move_path.size() - 1) * DS.DUR_FAST * 1000.0
		)
	var animate_move := event.type == &"battlefield_changed"
	_sync_units(animate_move)
	if _animate_events and event.type == &"action_resolved" and move_path.is_empty():
		if not _reduced_motion():
			var duration := SpellCastScript.DURATION if SpellCastScript.is_cast(event) else ACTION_FEEDBACK_SECONDS
			_input_locked_until_msec = maxi(
				_input_locked_until_msec, Time.get_ticks_msec() + roundi(duration * 1000.0)
			)
		_play_action_beat(event)
	queue_redraw()


func rendered_tile_count() -> int:
	return _tiles.size()


func set_pending_cells(cells: Array[Vector2i]) -> void:
	_pending_cells = cells.duplicate()
	queue_redraw()


func fire_cell_count() -> int:
	return _fire_cells.size()


func light_cell_count() -> int:
	return _light_cells.size()


func shroud_cell_count() -> int:
	return _shroud_cells.size()


## Board workings from the controller snapshot: burning Firebreak cells, filed marks, and
## Witness Light fields. Rendered as ground tints so units and cover still read on top.
func _read_fields(snapshot: Dictionary) -> void:
	if not snapshot.has("fire") and not snapshot.has("light"):
		return
	_fire_cells.clear()
	_mark_cells.clear()
	_light_cells.clear()
	_shroud_cells.clear()
	var fire: Dictionary = snapshot.get("fire", {})
	for line: Variant in fire.get("lines", []):
		if line is Dictionary:
			for cell: Vector2i in FireField.cells_from_data((line as Dictionary).get("cells", [])):
				_fire_cells[cell] = true
	for mark: Variant in fire.get("marks", []):
		if mark is Dictionary:
			for cell: Vector2i in FireField.cells_from_data((mark as Dictionary).get("cells", [])):
				_mark_cells[cell] = true
	var light: Dictionary = snapshot.get("light", {})
	for field: Variant in light.get("fields", []):
		if not (field is Dictionary):
			continue
		var center: Variant = LightField.cell_from_data((field as Dictionary).get("center", {}))
		if not (center is Vector2i):
			continue
		var radius := int((field as Dictionary).get("radius", 0))
		for dy: int in range(-radius, radius + 1):
			for dx: int in range(-radius, radius + 1):
				_light_cells[(center as Vector2i) + Vector2i(dx, dy)] = true
	for field: Variant in light.get("shrouds", []):
		if not (field is Dictionary):
			continue
		var center: Variant = LightField.cell_from_data((field as Dictionary).get("center", {}))
		if not (center is Vector2i):
			continue
		var radius := int((field as Dictionary).get("radius", 0))
		for dy: int in range(-radius, radius + 1):
			for dx: int in range(-radius, radius + 1):
				_shroud_cells[(center as Vector2i) + Vector2i(dx, dy)] = true


func select_tile(cell: Vector2i) -> void:
	_selected = cell
	for tile: Dictionary in _tiles:
		if Vector2i(int(tile.get("x", 0)), int(tile.get("y", 0))) == cell:
			tile_selected.emit(tile.duplicate(true))
			break
	queue_redraw()
	if is_instance_valid(_field_overlay):
		_field_overlay.set_pointer(_selected, _hovered)


func _gui_input(event: InputEvent) -> void:
	if event is InputEventMouseButton and event.pressed:
		if event.button_index == MOUSE_BUTTON_RIGHT:
			clear_pointer()
			accept_event()
			return
		if event.button_index != MOUSE_BUTTON_LEFT:
			return
		if not pointer_input_available():
			accept_event()
			return
		var cell := _cell_at(event.position)
		if cell != NO_CELL:
			select_tile(cell)
			pointer_pressed.emit(_tile_at(cell), _actor_at(cell))
	elif event is InputEventMouseMotion:
		var cell := _cell_at(event.position)
		var hovered := cell if cell != NO_CELL else Vector2i(-1, -1)
		if hovered == _hovered:
			return
		_hovered = hovered
		_refresh_hover()
	elif event is InputEventKey and event.pressed and event.keycode == KEY_ESCAPE:
		clear_pointer()
		accept_event()


func clear_pointer() -> void:
	_hovered = Vector2i(-1, -1)
	_hover_path.clear()
	_selected = Vector2i(-1, -1)
	pointer_cleared.emit()
	queue_redraw()
	if is_instance_valid(_field_overlay):
		_field_overlay.set_pointer(null, null)


func pointer_input_available() -> bool:
	if is_instance_valid(_field_overlay):
		return _pointer_turn_available and not _field_overlay.is_animating()
	for effect: Node in _fx_layer.get_children():
		if effect.get_script() == SpellCastScript and effect.is_animating():
			return false
	return _pointer_turn_available and Time.get_ticks_msec() >= _input_locked_until_msec


func set_pointer_turn_available(available: bool) -> void:
	_pointer_turn_available = available


func _unhandled_key_input(event: InputEvent) -> void:
	if event is InputEventKey and event.pressed and event.keycode == KEY_ESCAPE:
		clear_pointer()
		get_viewport().set_input_as_handled()


## Display-only AP quote from the controller's movement snapshot (AP compatibility:
## gate T-10 — the stage never computes AP, it renders what move_query priced).
func hovered_ap_cost() -> int:
	return int(_reachable.get(_hovered, {}).get("ap_cost", -1))


func destination_for_cell(cell: Vector2i) -> StringName:
	return StringName((_reachable.get(cell, {}) as Dictionary).get("destination", &""))


func cover_marker_count() -> int:
	var count := 0
	for tile: Dictionary in _tiles:
		if bool(tile.get("cover", false)):
			count += 1
	return count


func cell_center(cell: Vector2i) -> Vector2:
	if is_instance_valid(_field_overlay):
		var point := _field_overlay.cell_center(cell)
		return get_global_transform_with_canvas().affine_inverse() * (
			_field_overlay.get_global_transform_with_canvas() * point
		)
	return _project(cell.x, cell.y, _height_at(cell), _layout())


func _set_movement(value: Variant) -> void:
	_reachable.clear()
	if value is not Dictionary:
		_refresh_hover()
		return
	var rows: Variant = (value as Dictionary).get("reachable", [])
	if rows is not Array:
		_refresh_hover()
		return
	for raw: Variant in rows:
		if raw is not Dictionary:
			continue
		var row: Dictionary = (raw as Dictionary).duplicate(true)
		var cells := _path_cells(row.get("path_cells", []))
		if cells.is_empty():
			continue
		row["path_cells"] = cells
		_reachable[cells.back()] = row
	_refresh_hover()


func _refresh_hover() -> void:
	_hover_path.clear()
	var hover_value: Variant = _reachable.get(_hovered, {})
	if hover_value is Dictionary:
		var path_value: Variant = (hover_value as Dictionary).get("path_cells", [])
		if path_value is Array:
			for path_cell: Variant in path_value:
				if path_cell is Vector2i:
					_hover_path.append(path_cell)
	if _hovered != Vector2i(-1, -1) and _tile_lookup().has(_hovered):
		tile_hovered.emit(_tile_at(_hovered))
	queue_redraw()
	if is_instance_valid(_field_overlay):
		_field_overlay.set_pointer(_selected, _hovered)


func _tile_at(cell: Vector2i) -> Dictionary:
	return (_tile_lookup().get(cell, {}) as Dictionary).duplicate(true)


## Built on first lookup after a snapshot, so events that never look a tile up never pay for it.
func _tile_lookup() -> Dictionary:
	if _tile_index_stale:
		_tile_index.clear()
		for tile: Dictionary in _tiles:
			var cell := Vector2i(int(tile.get("x", 0)), int(tile.get("y", 0)))
			if not _tile_index.has(cell):  # first wins, as the old linear scan did
				_tile_index[cell] = tile
		_tile_index_stale = false
	return _tile_index


func _actor_at(cell: Vector2i) -> StringName:
	for actor: Dictionary in _actors:
		if _actor_cell(actor) == cell and int(actor.get("hp", 1)) > 0:
			return StringName(str(actor.get("id", "")))
	return &""


func _cell_at(point: Vector2) -> Vector2i:
	if is_instance_valid(_field_overlay):
		var cell := _field_overlay.cell_at_viewport(get_global_transform_with_canvas() * point)
		return cell if not _tile_at(cell).is_empty() else NO_CELL
	var layout := _layout()
	var closest := NO_CELL
	var distance := INF
	for tile: Dictionary in _tiles:
		var cell := Vector2i(int(tile.get("x", 0)), int(tile.get("y", 0)))
		var center := _project(cell.x, cell.y, _tile_height(tile), layout)
		var candidate := center.distance_squared_to(point)
		if candidate < distance:
			distance = candidate
			closest = cell
	var reach: float = float(DS.TILE_W) * float(layout["scale"])
	return closest if distance <= reach * reach else NO_CELL


func _draw() -> void:
	if is_instance_valid(_field_overlay):
		return
	var layout := _layout()
	var scale_factor: float = layout["scale"]
	var half_w := float(DS.TILE_W) * 0.5 * scale_factor
	var half_h := float(DS.TILE_H) * 0.5 * scale_factor
	for tile: Dictionary in _tiles:
		var x := int(tile.get("x", 0))
		var y := int(tile.get("y", 0))
		var height := _tile_height(tile)
		var center := _project(x, y, height, layout)
		var diamond := PackedVector2Array([
			center + Vector2(0, -half_h), center + Vector2(half_w, 0),
			center + Vector2(0, half_h), center + Vector2(-half_w, 0),
		])
		draw_colored_polygon(diamond, Color("#20242D"))
		var atlas_cell := _ground_variant(x, y)
		draw_texture_rect_region(
			GROUND_ATLAS,
			Rect2(center - Vector2(half_w, half_h), Vector2(half_w * 2.0, half_h * 2.0)),
			Rect2(
				Vector2(atlas_cell * IsometricSpriteCatalog.TILE_SIZE),
				Vector2(IsometricSpriteCatalog.TILE_SIZE)
			),
			GROUND_MODULATE
		)
		var cell := Vector2i(x, y)
		if _reachable.has(cell):
			draw_colored_polygon(diamond, REACHABLE_TINT)
		if _hover_path.has(cell):
			draw_colored_polygon(diamond, PATH_TINT)
		if _shroud_cells.has(cell):
			draw_colored_polygon(diamond, SHROUD_TINT)
		if _light_cells.has(cell):
			draw_colored_polygon(diamond, LIGHT_TINT)
		if _fire_cells.has(cell):
			draw_colored_polygon(diamond, FIRE_TINT)
		elif _mark_cells.has(cell):
			draw_colored_polygon(diamond, MARK_TINT)
		if _pending_cells.has(cell):
			draw_colored_polygon(diamond, PENDING_TINT)
		if bool(tile.get("cover", false)) and _cover_texture() == null:
			# Badge is the LAST-RESORT marker; with prop art present the cover
			# prop is a y-sorted node in UnitsLayer (gate r1: props must
			# interleave with units by base Y, and ground overlays like the
			# reachable tint must not be painted over by a ground-pass prop).
			var notch := PackedVector2Array([
				diamond[0] + Vector2(0, 3), diamond[0] + Vector2(8, 7),
				diamond[0] + Vector2(6, 15), diamond[0] + Vector2(0, 19),
				diamond[0] + Vector2(-6, 15), diamond[0] + Vector2(-8, 7),
			])
			draw_colored_polygon(notch, COVER_COLOR)
		var charge := clampi(int(tile.get("charge_level", 0)), 0, DS.CHARGE_MAX)
		if charge > 0:
			var color := Color(str(tile.get("element_color", "#7BDFF2")))
			draw_colored_polygon(diamond, DS.charge_tint(color, charge))
			draw_string(
				ThemeDB.fallback_font, center + Vector2(-4.0 * scale_factor, 5.0 * scale_factor),
				str(tile.get("charge_element_id", "?")).left(1).to_upper(),
				HORIZONTAL_ALIGNMENT_LEFT, -1, maxi(9, int(12.0 * scale_factor)),
				Color(color, float(charge) / DS.CHARGE_MAX)
			)
		var rim := Color("#58606F")
		var rim_width := 1.0
		if cell == _hovered:
			rim = HOVER_RIM
			rim_width = 1.5
		if cell == _cell_of(_preview_id if not _preview_id.is_empty() else _target_id):
			rim = TARGET_RIM
			rim_width = 2.0
		elif cell == _cell_of(_active_id):
			rim = ACTIVE_RIM
			rim_width = 2.0
		if cell == _selected:
			rim = DS.TILE_SELECT_RIM
			rim_width = 2.0
		draw_polyline(
			PackedVector2Array([diamond[0], diamond[1], diamond[2], diamond[3], diamond[0]]),
			rim, rim_width
		)
		if cell == _hovered and _reachable.has(cell):
			draw_string(
				ThemeDB.fallback_font, center + Vector2(-13.0, -half_h - 4.0),
				"%d AP" % int((_reachable[cell] as Dictionary).get("ap_cost", 0)),
				HORIZONTAL_ALIGNMENT_LEFT, -1, 11, Color("#F2E4C9")
			)
		if height > 0:
			draw_string(
				ThemeDB.fallback_font, center + Vector2(-6.0 * scale_factor, half_h + 11.0),
				"H%d" % height, HORIZONTAL_ALIGNMENT_LEFT, -1, 10, Color("#8891A0")
			)


# --- units ---------------------------------------------------------------------


func _read_actors(snapshot: Dictionary) -> void:
	if not (snapshot.has("allies") or snapshot.has("enemies")):
		return
	_actors.clear()
	for side_key: String in ["allies", "enemies"]:
		var rows: Variant = snapshot.get(side_key, [])
		if rows is Array:
			for row: Variant in rows:
				if row is Dictionary:
					_actors.append(row as Dictionary)
	_sync_background()


func background_texture_path() -> String:
	if _backdrop == null or _backdrop.texture == null:
		return ""
	return _backdrop.texture.resource_path


## Encounter-prefix -> backdrop theme, mirroring _cover_theme()'s mapping.
## Unknown/absent art degrades to a hidden backdrop, never a crash.
func _backdrop_theme() -> String:
	var id := String(_encounter_id)
	if id.begins_with("dorthkor"):
		return "dorthkor-road"
	if id.begins_with("bog") or id.begins_with("loam"):
		return "bog-marsh"
	if id.begins_with("jawbrace"):
		return "jawbrace-ledge"
	if id.begins_with("trial"):
		return "trial-hall"
	return "wound-touched-field"


func _backdrop_texture(theme_name: String) -> Texture2D:
	if _backdrop_texture_cache.has(theme_name):
		return _backdrop_texture_cache[theme_name]
	var path := BACKDROP_PATTERN % theme_name
	var texture: Texture2D = null
	# Export-safe gate + load validation (project art-fallback standard).
	if ResourceLoader.exists(path) or FileAccess.file_exists(path):
		var resource: Resource = load(path)
		if resource is Texture2D:
			texture = resource as Texture2D
	_backdrop_texture_cache[theme_name] = texture
	return texture


func _sync_background() -> void:
	if is_instance_valid(_field_overlay):
		_backdrop.hide()
		return
	var texture := _backdrop_texture(_backdrop_theme())
	_backdrop.texture = texture
	_backdrop.visible = texture != null


## Creates/updates one sprite per living actor. Units render only on grid
## battles (zone models snapshot no tiles, and the legacy battle_stage.gd
## composition already presents those).
func _sync_units(animate_move: bool) -> void:
	if is_instance_valid(_field_overlay):
		return
	_sync_cover_props()
	if _tiles.is_empty() or _actors.is_empty():
		for id: StringName in _moves.keys():
			_stop_tween(_moves, id)
		for id: StringName in _falls.keys():
			_stop_tween(_falls, id)
		for id: StringName in _hit_flashes.keys():
			_stop_hit_flash(id)
		for node: Node in _unit_nodes.values():
			node.queue_free()
		_unit_nodes.clear()
		# Prop-only snapshots still need depth order (gate r2) — without this
		# the cover nodes keep tile insertion order.
		_apply_painter_order()
		return
	var layout := _layout()
	var scale_factor: float = layout["scale"]
	var seen: Dictionary = {}
	for actor: Dictionary in _actors:
		var id := StringName(str(actor.get("id", "")))
		if id == &"":
			continue
		seen[id] = true
		var sprite := _unit_nodes.get(id) as TextureRect
		if sprite == null:
			sprite = TextureRect.new()
			sprite.name = "Unit_%s" % id
			sprite.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
			sprite.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
			sprite.mouse_filter = Control.MOUSE_FILTER_IGNORE
			sprite.texture_filter = CanvasItem.TEXTURE_FILTER_LINEAR
			var unit_id := UnitArtScript.combat_unit_id(
				StringName(str(actor.get("side", "ally"))),
				str(actor.get("archetype_id", "")),
				str(actor.get("display_name", ""))
			)
			if not str(actor.get("member_id", "")).is_empty():
				unit_id = UnitArtScript.field_unit_id(
					str(actor["member_id"]), str(actor.get("portrait_path", ""))
				)
			sprite.texture = load(UnitArtScript.texture_path(UnitArtScript.resolve(unit_id)))
			_units_layer.add_child(sprite)
			_unit_nodes[id] = sprite
		var cell: Vector2i = _actor_cell(actor)
		var sprite_h := float(DS.TILE_H) * SPRITE_TILE_HEIGHTS * scale_factor
		var aspect := 1.0
		if sprite.texture != null and sprite.texture.get_height() > 0:
			aspect = float(sprite.texture.get_width()) / float(sprite.texture.get_height())
		sprite.size = Vector2(sprite_h * aspect, sprite_h)
		sprite.pivot_offset = Vector2(sprite.size.x * 0.5, sprite.size.y)
		var destination := _sprite_pos_for_cell(sprite, cell, layout)
		if id == _pending_path_id and _pending_path.size() >= 2:
			_stop_tween(_moves, id)
			var points := PackedVector2Array([sprite.position])
			for index: int in range(1, _pending_path.size()):
				points.append(_sprite_pos_for_cell(sprite, _pending_path[index], layout))
			var slide := CombatMotionScript.along_path(self, points, _set_unit_position.bind(id))
			_moves[id] = slide
			slide.tween_callback(func() -> void: _moves.erase(id))
			_pending_path_id = &""
			_pending_path = []
		elif _moves.has(id):
			# Turn/resource snapshots can arrive in the same frame as a committed move.
			# Its tween owns position until it ends; do not teleport to the snapshot.
			pass
		elif animate_move and _animate_events and not _reduced_motion() and sprite.position.distance_to(destination) > 1.0:
			var tween := create_tween()
			_moves[id] = tween
			tween.tween_method(_set_unit_position.bind(id), sprite.position, destination, DS.DUR_BASE) \
				.set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN_OUT)
			tween.tween_callback(func() -> void: _moves.erase(id))
		else:
			sprite.position = destination
		sprite.flip_h = String(actor.get("facing", "")).contains("w") \
			or (str(actor.get("side", "")) == "enemy" and String(actor.get("facing", "")).is_empty())
		var alive := int(actor.get("hp", 1)) > 0
		var was_fallen := bool(_fallen.get(id, false))
		if alive:
			_stop_tween(_falls, id)
			if not _hit_flashes.has(id):
				sprite.modulate = Color.WHITE
			sprite.rotation = 0.0
			_fallen[id] = false
		elif _falls.has(id) or _pending_defeats.has(id):
			pass
		elif was_fallen or not _fallen.has(id) or not _animate_events or _reduced_motion():
			# Already down, or first seen dead: settle in the fallen pose instantly.
			sprite.modulate = KO_MODULATE
			sprite.rotation = _fall_rotation(sprite)
			_fallen[id] = true
		else:
			_stop_hit_flash(id)
			_play_ko_fall(sprite, id)
			_fallen[id] = true
	for id: StringName in _unit_nodes.keys():
		if not seen.has(id):
			_stop_tween(_moves, id)
			_stop_tween(_falls, id)
			_stop_hit_flash(id)
			(_unit_nodes[id] as Node).queue_free()
			_unit_nodes.erase(id)
			_fallen.erase(id)
			_pending_defeats.erase(id)
	_apply_painter_order()


## Painter's order: lower on screen draws in front. Cover props share the
## layer so a unit behind a prop is occluded by it and vice versa (gate r1).
## Also re-invoked from movement-tween callbacks (gate r2): a sliding unit
## that crosses a prop's base Y must swap draw order as it passes, not wait
## for the next combat event or resize.
func _apply_painter_order() -> void:
	if _units_layer == null:
		return
	var order: Array = _unit_nodes.values() + _cover_nodes.values()
	order.sort_custom(
		func(a: TextureRect, b: TextureRect) -> bool:
			return a.position.y + a.size.y < b.position.y + b.size.y
	)
	for index: int in order.size():
		_units_layer.move_child(order[index], index)


## Cover props live in UnitsLayer as bottom-anchored nodes so painter's-order
## sorting depth-interleaves them with units. When no prop art resolves, the
## ground pass draws the legacy badge instead and this keeps zero nodes.
func _sync_cover_props() -> void:
	var texture := _cover_texture()
	if _tiles.is_empty() or texture == null:
		for node: Node in _cover_nodes.values():
			node.queue_free()
		_cover_nodes.clear()
		return
	var layout := _layout()
	var scale_factor: float = layout["scale"]
	var half_h := float(DS.TILE_H) * 0.5 * scale_factor
	var seen: Dictionary = {}
	for tile: Dictionary in _tiles:
		if not bool(tile.get("cover", false)):
			continue
		var cell := Vector2i(int(tile.get("x", 0)), int(tile.get("y", 0)))
		seen[cell] = true
		var sprite := _cover_nodes.get(cell) as TextureRect
		if sprite == null:
			sprite = TextureRect.new()
			sprite.name = "Cover_%d_%d" % [cell.x, cell.y]
			sprite.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
			sprite.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
			sprite.mouse_filter = Control.MOUSE_FILTER_IGNORE
			_units_layer.add_child(sprite)
			_cover_nodes[cell] = sprite
		sprite.texture = texture
		var width := float(DS.TILE_W) * COVER_ART_TILE_WIDTHS * scale_factor
		var height := width * (
			float(texture.get_height()) / maxf(1.0, float(texture.get_width()))
		)
		sprite.size = Vector2(width, height)
		var center := _project(cell.x, cell.y, _tile_height(tile), layout)
		sprite.position = Vector2(center.x - width / 2.0, center.y + half_h - height)
	for cell: Variant in _cover_nodes.keys():
		if not seen.has(cell):
			(_cover_nodes[cell] as Node).queue_free()
			_cover_nodes.erase(cell)


func _play_action_beat(event: CombatEvent) -> void:
	var attacker := _unit_nodes.get(event.actor_id) as TextureRect
	var defender := _unit_nodes.get(event.target_id) as TextureRect
	if attacker != null and SpellCastScript.is_cast(event):
		var targets: Array[Callable] = []
		for cell: Vector2i in FireField.cells_from_data(event.data.get("cells", [])):
			targets.append(cell_center.bind(cell))
		if targets.is_empty():
			targets.append(_result_anchor.bind(event.target_id if defender != null else event.actor_id))
		var spell := SpellCastScript.new()
		spell.name = "SpellCast"
		spell.setup(event, _result_anchor.bind(event.actor_id), targets, float(_layout()["scale"]))
		spell.impact_reached.connect(_present_action_result.bind(event), CONNECT_ONE_SHOT)
		_fx_layer.add_child(spell)
		return
	if not _reduced_motion() and attacker != null and defender != null and attacker != defender:
		_stop_tween(_moves, event.actor_id)
		var home := _sprite_pos_for_cell(attacker, _cell_of(event.actor_id), _layout())
		var toward := home + (defender.position - home).limit_length(DS.SPACE_4)
		var lunge := create_tween()
		_moves[event.actor_id] = lunge
		lunge.set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN_OUT)
		lunge.tween_method(_set_unit_position.bind(event.actor_id), attacker.position, toward, DS.DUR_FAST)
		lunge.tween_method(_set_unit_position.bind(event.actor_id), toward, home, DS.DUR_FAST)
		lunge.tween_callback(func() -> void: _moves.erase(event.actor_id))
	_present_action_result(event)


func _present_action_result(event: CombatEvent) -> void:
	if _pending_defeats.get(event.target_id, 0) == event.get_instance_id():
		_pending_defeats.erase(event.target_id)
		_sync_units(false)
	var defender := _unit_nodes.get(event.target_id) as TextureRect
	# A felled defender is mid KO-fall — its fade tween owns modulate; flashing
	# it back to white here would fight that tween frame-by-frame.
	if defender != null and HitPulseScript.is_damaging_hit(event) and not _reduced_motion() and not SpellCastScript.is_cast(event):
		var pulse := HitPulseScript.new()
		pulse.name = "HitPulse"
		pulse.position = defender.position + defender.size * Vector2(0.5, 0.45)
		_fx_layer.add_child(pulse)
	if defender != null and HitPulseScript.is_damaging_hit(event) and not _reduced_motion() and not bool(_fallen.get(event.target_id, false)):
		_stop_hit_flash(event.target_id)
		var flash := create_tween()
		_hit_flashes[event.target_id] = flash
		defender.modulate = DS.PARCHMENT
		flash.tween_property(defender, "modulate", Color.WHITE, DS.DUR_BASE)
		flash.tween_callback(func() -> void: _hit_flashes.erase(event.target_id))
	if defender != null and HitPulseScript.has_result(event):
		_spawn_damage_pop(event)


func _stop_hit_flash(id: StringName) -> void:
	var previous := _hit_flashes.get(id) as Tween
	if previous != null and previous.is_valid():
		previous.kill()
	_hit_flashes.erase(id)


func _spawn_damage_pop(event: CombatEvent) -> void:
	for previous: Node in _fx_layer.get_children():
		if previous.get_meta("result_target", &"") == event.target_id:
			_fx_layer.remove_child(previous)
			previous.queue_free()
	var pop := CombatResultScene.instantiate()
	_fx_layer.add_child(pop)
	pop.setup(event, _result_anchor.bind(event.target_id), func() -> Rect2:
		return get_global_transform_with_canvas() * Rect2(Vector2.ZERO, size)
	)


func _result_anchor(id: StringName) -> Variant:
	var unit := _unit_nodes.get(id) as TextureRect
	return unit.position + unit.size * Vector2(0.5, 0.55) if is_instance_valid(unit) else null


func _sprite_pos_for_cell(sprite: TextureRect, cell: Vector2i, layout: Dictionary) -> Vector2:
	var foot := _project(cell.x, cell.y, _height_at(cell), layout)
	var scale_factor: float = layout["scale"]
	return foot - Vector2(
		sprite.size.x * 0.5, sprite.size.y - float(DS.TILE_H) * 0.25 * scale_factor
	)


## A felled unit tips away from the way it faces, pivoting at its feet.
func _fall_rotation(sprite: TextureRect) -> float:
	return -KO_FALL_RADIANS if sprite.flip_h else KO_FALL_RADIANS


func _play_ko_fall(sprite: TextureRect, id: StringName) -> void:
	var fall := create_tween()
	_falls[id] = fall
	fall.set_parallel(true)
	fall.tween_property(sprite, "rotation", _fall_rotation(sprite), DS.DUR_BASE) \
		.set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_IN)
	fall.tween_property(sprite, "modulate", KO_MODULATE, DS.DUR_BASE)
	fall.chain().tween_callback(func() -> void: _falls.erase(id))


func _set_unit_position(value: Vector2, id: StringName) -> void:
	var unit := _unit_nodes.get(id) as TextureRect
	if is_instance_valid(unit):
		unit.position = value
		_apply_painter_order()


func _stop_tween(collection: Dictionary, id: StringName) -> void:
	var tween := collection.get(id) as Tween
	if tween != null and tween.is_valid():
		tween.kill()
	collection.erase(id)


func _reduced_motion() -> bool:
	return bool(GameState.get_setting("accessibility", "reduced_motion", false))


func _on_setting_changed(section: String, key: String, value: Variant) -> void:
	if section == "accessibility" and key == "reduced_motion" and bool(value):
		_settle_motion()
		for effect: Node in _fx_layer.get_children():
			if effect.get_script() == HitPulseScript:
				effect.queue_free()


func _settle_motion() -> void:
	for collection: Dictionary in [_moves, _falls, _hit_flashes]:
		for id: StringName in collection.keys():
			_stop_tween(collection, id)
	_pending_path_id = &""
	_pending_path.clear()
	_pending_defeats.clear()
	_input_locked_until_msec = 0
	_sync_units(false)


## Accepts controller-projected cells only. Opaque position handles remain model-owned.
func _path_cells(value: Variant) -> Array[Vector2i]:
	var cells: Array[Vector2i] = []
	if value is not Array:
		return cells
	for cell_value: Variant in value as Array:
		if cell_value is not Vector2i:
			return []
		cells.append(cell_value)
	return cells


# --- projection ----------------------------------------------------------------


## Fit the whole board (plus sprite headroom) inside the region: scale factor +
## pixel origin so DS.iso_project coordinates land centered.
func _layout() -> Dictionary:
	if _tiles.is_empty():
		return {"scale": 1.0, "origin": Vector2(size.x * 0.5, maxf(36.0, size.y * 0.18))}
	var low := Vector2(INF, INF)
	var high := Vector2(-INF, -INF)
	for tile: Dictionary in _tiles:
		var center := DS.iso_project(
			int(tile.get("x", 0)), int(tile.get("y", 0)), _tile_height(tile), Vector2.ZERO
		)
		low = low.min(center)
		high = high.max(center)
	low -= Vector2(DS.TILE_W * 0.5, DS.TILE_H * 0.5 + DS.TILE_H * SPRITE_TILE_HEIGHTS)
	high += Vector2(DS.TILE_W * 0.5, DS.TILE_H * 0.5)
	var extent := (high - low).max(Vector2.ONE)
	var scale_factor := clampf(
		minf((size.x - FIT_MARGIN * 2.0) / extent.x, (size.y - FIT_MARGIN * 2.0) / extent.y),
		MIN_SCALE, MAX_SCALE
	)
	var origin := size * 0.5 - (low + extent * 0.5) * scale_factor
	return {"scale": scale_factor, "origin": origin}


func _project(x: int, y: int, height: int, layout: Dictionary) -> Vector2:
	return DS.iso_project(x, y, height, Vector2.ZERO) * float(layout["scale"]) \
		+ (layout["origin"] as Vector2)


## Encounter-id prefix -> cover prop theme (mirrors _ground_variant's approach).
func _cover_theme() -> String:
	var id := String(_encounter_id)
	if id.begins_with("dorthkor"):
		return "road"
	if id.begins_with("bog") or id.begins_with("loam"):
		return "bog"
	if id.begins_with("jawbrace"):
		return "barricade"
	if id.begins_with("trial"):
		return "pillar"
	return "generic"


## Texture-level resolution (project standard: existence is not validity) —
## themed prop, else the generic prop, else null so the drawn badge remains
## the last-resort marker. Cached per theme for the draw loop.
func _cover_texture() -> Texture2D:
	var theme_id := _cover_theme()
	if _cover_texture_cache.has(theme_id):
		return _cover_texture_cache[theme_id]
	var texture: Texture2D = null
	for candidate: String in [theme_id, "generic"]:
		var path := COVER_ART_PATTERN % candidate
		# ResourceLoader.exists follows export remapping (FileAccess alone
		# misses imported textures inside a PCK — gate r1); FileAccess keeps
		# unimported files (tests, fresh drops) resolvable in the editor.
		if ResourceLoader.exists(path) or FileAccess.file_exists(path):
			var resource: Resource = load(path)
			if resource is Texture2D:
				texture = resource as Texture2D
				break
	_cover_texture_cache[theme_id] = texture
	return texture


func _ground_variant(x: int, y: int) -> Vector2i:
	var variants := GROUND_ROAD_VARIANTS \
		if String(_encounter_id).begins_with("dorthkor") else GROUND_FIELD_VARIANTS
	return variants[absi(x * 31 + y * 17) % variants.size()]


func _tile_height(tile: Dictionary) -> int:
	return clampi(int(tile.get("height_delta", tile.get("height", 0))), 0, DS.ELEVATION_MAX)


func _height_at(cell: Vector2i) -> int:
	for tile: Dictionary in _tiles:
		if int(tile.get("x", 0)) == cell.x and int(tile.get("y", 0)) == cell.y:
			return _tile_height(tile)
	return 0


func _actor_cell(actor: Dictionary) -> Vector2i:
	var position: Variant = actor.get("position", Vector2i.ZERO)
	if position is Vector2i:
		return position
	if position is Vector2:
		return Vector2i(position)
	# Live snapshots carry GridBattlefieldModel.cell_id() tokens ("c:x,y,h") —
	# without this decode every unit stacked on cell (0,0).
	var token := str(position)
	if token.begins_with("c:"):
		var parts := token.trim_prefix("c:").split(",")
		if parts.size() >= 2 and parts[0].is_valid_int() and parts[1].is_valid_int():
			return Vector2i(parts[0].to_int(), parts[1].to_int())
	return Vector2i.ZERO


func _cell_of(actor_id: StringName) -> Vector2i:
	if actor_id == &"":
		return Vector2i(-999, -999)
	for actor: Dictionary in _actors:
		if StringName(str(actor.get("id", ""))) == actor_id:
			return _actor_cell(actor)
	return Vector2i(-999, -999)
