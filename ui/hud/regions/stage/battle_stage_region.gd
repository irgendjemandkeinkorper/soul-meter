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
const MIN_SCALE := 0.6
const MAX_SCALE := 2.4
## Sprite height as a multiple of a (scaled) tile height — reads as "a figure
## standing on the tile" rather than a giant or a speck.
const SPRITE_TILE_HEIGHTS := 2.6
const ACTIVE_RIM := Color("#C9A227")  # bronze — matches the DS "current" accent
const TARGET_RIM := Color("#E06C5A")
const HOVER_RIM := Color("#9AA3B2")
const REACHABLE_TINT := Color(0.24, 0.56, 0.42, 0.18)
const PATH_TINT := Color(0.82, 0.67, 0.24, 0.20)
const COVER_COLOR := Color("#D6C184")
const COVER_ART_PATTERN := "res://assets/generated/sprites/terrain/cover_%s.png"
const COVER_ART_TILE_WIDTHS := 1.35  # prop footprint relative to a tile's width
const ACTION_FEEDBACK_SECONDS := 0.7
const KO_MODULATE := Color(0.5, 0.5, 0.56, 0.45)
const KO_FALL_RADIANS := deg_to_rad(78.0)
const NO_CELL := Vector2i(-999, -999)

var _tiles: Array[Dictionary] = []
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
var _input_locked_until_msec := 0
var _pointer_turn_available := true
var _fallen: Dictionary = {}
var _pending_path_id: StringName = &""
var _pending_path: Array[Vector2i] = []
var _backdrop: TextureRect
var _units_layer: Control
var _fx_layer: Control
var _unit_nodes: Dictionary = {}


func _ready() -> void:
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
	resized.connect(
		func() -> void:
			_sync_units(false)
			queue_redraw()
	)
	mouse_exited.connect(
		func() -> void:
			if _hovered != Vector2i(-1, -1):
				_hovered = Vector2i(-1, -1)
				_hover_path.clear()
				queue_redraw()
	)


func consume_event(event: CombatEvent) -> void:
	var snapshot: Dictionary = event.data.get("snapshot", {})
	_encounter_id = StringName(str(snapshot.get("encounter_id", "")))
	var tile_values: Variant = event.data.get("tiles", snapshot.get("tiles", []))
	if tile_values is Array:
		_tiles.clear()
		for value: Variant in tile_values:
			if value is Dictionary:
				_tiles.append((value as Dictionary).duplicate(true))
	_read_actors(snapshot)
	_set_movement(snapshot.get("movement", {}))
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
	var move_path := _path_cells(event.data.get("path_cells", []))
	if event.type == &"action_resolved" and move_path.size() >= 2 \
			and _unit_nodes.has(event.actor_id):
		_pending_path_id = event.actor_id
		_pending_path = move_path
		_input_locked_until_msec = Time.get_ticks_msec() + roundi(
			float(move_path.size() - 1) * DS.DUR_FAST * 1000.0
		)
	var animate_move := event.type == &"battlefield_changed"
	_sync_units(animate_move)
	if event.type == &"action_resolved" and move_path.is_empty():
		_input_locked_until_msec = maxi(
			_input_locked_until_msec,
			Time.get_ticks_msec() + roundi(ACTION_FEEDBACK_SECONDS * 1000.0)
		)
		_play_action_beat(event)
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


func pointer_input_available() -> bool:
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
	for tile: Dictionary in _tiles:
		if Vector2i(int(tile.get("x", 0)), int(tile.get("y", 0))) == _hovered:
			tile_hovered.emit(tile.duplicate(true))
			break
	queue_redraw()


func _tile_at(cell: Vector2i) -> Dictionary:
	for tile: Dictionary in _tiles:
		if Vector2i(int(tile.get("x", 0)), int(tile.get("y", 0))) == cell:
			return tile.duplicate(true)
	return {}


func _actor_at(cell: Vector2i) -> StringName:
	for actor: Dictionary in _actors:
		if _actor_cell(actor) == cell and int(actor.get("hp", 1)) > 0:
			return StringName(str(actor.get("id", "")))
	return &""


func _cell_at(point: Vector2) -> Vector2i:
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
		if cell == _cell_of(_target_id):
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
					_actors.append((row as Dictionary).duplicate(true))
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
	var texture := _backdrop_texture(_backdrop_theme())
	_backdrop.texture = texture
	_backdrop.visible = texture != null


## Creates/updates one sprite per living actor. Units render only on grid
## battles (zone models snapshot no tiles, and the legacy battle_stage.gd
## composition already presents those).
func _sync_units(animate_move: bool) -> void:
	_sync_cover_props()
	if _tiles.is_empty() or _actors.is_empty():
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
			var unit_id := UnitArtScript.combat_unit_id(
				StringName(str(actor.get("side", "ally"))),
				str(actor.get("archetype_id", "")),
				str(actor.get("display_name", ""))
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
			# The sprite already stands on the path's first cell; slide it through
			# the remaining waypoints the payload carried.
			var slide := create_tween()
			for index: int in range(1, _pending_path.size() - 1):
				slide.tween_property(
					sprite, "position",
					_sprite_pos_for_cell(sprite, _pending_path[index], layout), DS.DUR_FAST
				)
				slide.tween_callback(_apply_painter_order)
			slide.tween_property(sprite, "position", destination, DS.DUR_FAST)
			slide.tween_callback(_apply_painter_order)
			_pending_path_id = &""
			_pending_path = []
		elif animate_move and sprite.position.distance_to(destination) > 1.0:
			var tween := create_tween()
			tween.tween_property(sprite, "position", destination, DS.DUR_BASE)
			tween.tween_callback(_apply_painter_order)
		else:
			sprite.position = destination
		sprite.flip_h = String(actor.get("facing", "")).contains("w") \
			or (str(actor.get("side", "")) == "enemy" and String(actor.get("facing", "")).is_empty())
		var alive := int(actor.get("hp", 1)) > 0
		var was_fallen := bool(_fallen.get(id, false))
		if alive:
			sprite.modulate = Color.WHITE
			sprite.rotation = 0.0
			_fallen[id] = false
		elif was_fallen or not _fallen.has(id):
			# Already down, or first seen dead: settle in the fallen pose instantly.
			sprite.modulate = KO_MODULATE
			sprite.rotation = _fall_rotation(sprite)
			_fallen[id] = true
		else:
			_play_ko_fall(sprite)
			_fallen[id] = true
	for id: StringName in _unit_nodes.keys():
		if not seen.has(id):
			(_unit_nodes[id] as Node).queue_free()
			_unit_nodes.erase(id)
			_fallen.erase(id)
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
	if attacker != null and defender != null and attacker != defender:
		var home := attacker.position
		var toward := home + (defender.position - home) * 0.25
		var lunge := create_tween()
		lunge.tween_property(attacker, "position", toward, DS.DUR_FAST)
		lunge.tween_property(attacker, "position", home, DS.DUR_FAST)
	# A felled defender is mid KO-fall — its fade tween owns modulate; flashing
	# it back to white here would fight that tween frame-by-frame.
	if defender != null and not bool(_fallen.get(event.target_id, false)):
		var flash := create_tween()
		defender.modulate = Color(1.6, 1.4, 1.4, 1.0)
		flash.tween_property(defender, "modulate", Color.WHITE, DS.DUR_BASE)
	var anchor := defender if defender != null else attacker
	if anchor != null:
		_spawn_damage_pop(event, anchor)


func _spawn_damage_pop(event: CombatEvent, anchor: TextureRect) -> void:
	var hit := bool(event.data.get("hit", true))
	var damage := int(event.data.get("damage", 0))
	var pop := Label.new()
	pop.theme_type_variation = "HeadingLabel"
	pop.text = str(damage) if hit and damage > 0 else ("MISS" if not hit else "0")
	pop.modulate = Color("#F2E4C9") if hit else Color("#9AA3B2")
	pop.position = anchor.position + Vector2(anchor.size.x * 0.5 - 10.0, -6.0)
	pop.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_fx_layer.add_child(pop)
	var tween := create_tween()
	tween.set_parallel(true)
	tween.tween_property(pop, "position:y", pop.position.y - 28.0, 0.7)
	tween.tween_property(pop, "modulate:a", 0.0, 0.7)
	tween.chain().tween_callback(pop.queue_free)


func _sprite_pos_for_cell(sprite: TextureRect, cell: Vector2i, layout: Dictionary) -> Vector2:
	var foot := _project(cell.x, cell.y, _height_at(cell), layout)
	var scale_factor: float = layout["scale"]
	return foot - Vector2(
		sprite.size.x * 0.5, sprite.size.y - float(DS.TILE_H) * 0.25 * scale_factor
	)


## A felled unit tips away from the way it faces, pivoting at its feet.
func _fall_rotation(sprite: TextureRect) -> float:
	return -KO_FALL_RADIANS if sprite.flip_h else KO_FALL_RADIANS


func _play_ko_fall(sprite: TextureRect) -> void:
	var fall := create_tween()
	fall.set_parallel(true)
	fall.tween_property(sprite, "rotation", _fall_rotation(sprite), DS.DUR_BASE) \
		.set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_IN)
	fall.tween_property(sprite, "modulate", KO_MODULATE, DS.DUR_BASE)


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
