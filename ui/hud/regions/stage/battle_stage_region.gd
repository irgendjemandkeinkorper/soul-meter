class_name BattleStageRegion
extends Control

## Event-only isometric tactical board (#211 presentation pass).
##
## Rebuilds its whole view from each CombatEvent's snapshot: the tile grid
## (scaled to fill the region instead of a fixed corner), one painterly unit
## sprite per living actor at its grid cell, active/target cell rims, and
## action feedback beats (attacker lunge, damage pop, KO fade). Purely
## presentational — the frozen region contract (consume_event / tile_selected /
## rendered_tile_count / select_tile) is unchanged.
signal tile_selected(tile: Dictionary)

const UnitArtScript := preload("res://globals/unit_art.gd")
const DORTHKOR_BACKGROUND := preload(
	"res://assets/generated/backgrounds/combat/dorthkor-road-battlefield-v1.png"
)

const FIT_MARGIN := 20.0
const MIN_SCALE := 0.6
const MAX_SCALE := 2.4
## Sprite height as a multiple of a (scaled) tile height — reads as "a figure
## standing on the tile" rather than a giant or a speck.
const SPRITE_TILE_HEIGHTS := 2.6
const ACTIVE_RIM := Color("#C9A227")  # bronze — matches the DS "current" accent
const TARGET_RIM := Color("#E06C5A")

var _tiles: Array[Dictionary] = []
var _actors: Array[Dictionary] = []
var _encounter_id: StringName = &""
var _active_id: StringName = &""
var _target_id: StringName = &""
var _selected := Vector2i(-1, -1)
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
	var animate_move := event.type == &"battlefield_changed"
	_sync_units(animate_move)
	if event.type == &"action_resolved":
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
		var layout := _layout()
		var closest := Vector2i(-1, -1)
		var distance := INF
		for tile: Dictionary in _tiles:
			var cell := Vector2i(int(tile.get("x", 0)), int(tile.get("y", 0)))
			var point := _project(cell.x, cell.y, _tile_height(tile), layout)
			var candidate := point.distance_squared_to(event.position)
			if candidate < distance:
				distance = candidate
				closest = cell
		var reach: float = float(DS.TILE_W) * float(layout["scale"])
		if distance <= reach * reach:
			select_tile(closest)


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
		var cell := Vector2i(x, y)
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


func _sync_background() -> void:
	var is_dorthkor := String(_encounter_id).begins_with("dorthkor")
	_backdrop.texture = DORTHKOR_BACKGROUND if is_dorthkor else null
	_backdrop.visible = is_dorthkor


## Creates/updates one sprite per living actor. Units render only on grid
## battles (zone models snapshot no tiles, and the legacy battle_stage.gd
## composition already presents those).
func _sync_units(animate_move: bool) -> void:
	if _tiles.is_empty() or _actors.is_empty():
		for node: Node in _unit_nodes.values():
			node.queue_free()
		_unit_nodes.clear()
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
		var foot := _project(cell.x, cell.y, _height_at(cell), layout)
		var sprite_h := float(DS.TILE_H) * SPRITE_TILE_HEIGHTS * scale_factor
		var aspect := 1.0
		if sprite.texture != null and sprite.texture.get_height() > 0:
			aspect = float(sprite.texture.get_width()) / float(sprite.texture.get_height())
		sprite.size = Vector2(sprite_h * aspect, sprite_h)
		var destination := foot - Vector2(sprite.size.x * 0.5, sprite.size.y - float(DS.TILE_H) * 0.25 * scale_factor)
		if animate_move and sprite.position.distance_to(destination) > 1.0:
			var tween := create_tween()
			tween.tween_property(sprite, "position", destination, DS.DUR_BASE)
		else:
			sprite.position = destination
		sprite.flip_h = String(actor.get("facing", "")).contains("w") \
			or (str(actor.get("side", "")) == "enemy" and String(actor.get("facing", "")).is_empty())
		var alive := int(actor.get("hp", 1)) > 0
		sprite.modulate = Color.WHITE if alive else Color(0.5, 0.5, 0.56, 0.45)
	for id: StringName in _unit_nodes.keys():
		if not seen.has(id):
			(_unit_nodes[id] as Node).queue_free()
			_unit_nodes.erase(id)
	# Painter's order: lower on screen draws in front.
	var order: Array = _unit_nodes.values()
	order.sort_custom(
		func(a: TextureRect, b: TextureRect) -> bool:
			return a.position.y + a.size.y < b.position.y + b.size.y
	)
	for index: int in order.size():
		_units_layer.move_child(order[index], index)


func _play_action_beat(event: CombatEvent) -> void:
	var attacker := _unit_nodes.get(event.actor_id) as TextureRect
	var defender := _unit_nodes.get(event.target_id) as TextureRect
	if attacker != null and defender != null and attacker != defender:
		var home := attacker.position
		var toward := home + (defender.position - home) * 0.25
		var lunge := create_tween()
		lunge.tween_property(attacker, "position", toward, DS.DUR_FAST)
		lunge.tween_property(attacker, "position", home, DS.DUR_FAST)
	if defender != null:
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
