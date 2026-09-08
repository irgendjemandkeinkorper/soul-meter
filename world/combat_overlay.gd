class_name CombatOverlay
extends Node2D
## Field-space presentation only. CombatEvent snapshots own state; IsoGrid owns projection.
## Actor nodes are borrowed, never duplicated, and no combat model is mutated here.

var _grid: IsoGrid
var _ground: TileMapLayer
var _tiles: Dictionary = {}
var _actors: Dictionary = {}
var _nodes: Dictionary = {}
var _moves: Dictionary = {}
var _active_id: StringName
var _target_id: StringName
var _reachable: Dictionary = {}
var _selected: Variant = null
var _hovered: Variant = null
var _field: FieldMap
var _original_colors: Dictionary = {}
var _flashes: Dictionary = {}
var _theme: Theme
var animate_events := true
const NUMERIC_FONT := preload(DS.FONT_NUMERIC)


func bind_field(field: FieldMap) -> void:
	_field = field
	z_index = 1
	bind_grid(field.iso_grid(), field.ground())


func cell_at_viewport(point: Vector2) -> Vector2i:
	var local_point := get_global_transform_with_canvas().affine_inverse() * point
	return _grid.world_to_cell(to_global(local_point))


func bind_grid(grid: IsoGrid, ground: TileMapLayer) -> void:
	_grid = grid
	_ground = ground
	queue_redraw()


func bind_actor(actor_id: StringName, node: Node2D) -> void:
	_nodes[actor_id] = node
	if is_instance_valid(node) and not _original_colors.has(node):
		_original_colors[node] = node.modulate


func _exit_tree() -> void:
	for id: StringName in _moves.keys():
		_stop_move(id)
	for tween: Tween in _flashes.values():
		if tween.is_valid():
			tween.kill()
	for node: Variant in _original_colors:
		if is_instance_valid(node):
			node.modulate = _original_colors[node]


func is_animating() -> bool:
	return not _moves.is_empty() or not _flashes.is_empty()


func cell_center(cell: Vector2i) -> Vector2:
	return to_local(_grid.cell_to_world(cell)) if _grid != null else Vector2.ZERO


func tile_at(cell: Vector2i) -> Dictionary:
	return (_tiles.get(cell, {}) as Dictionary).duplicate(true)


func set_pointer(selected: Variant, hovered: Variant) -> void:
	_selected = selected
	_hovered = hovered
	queue_redraw()


func consume_event(event: CombatEvent) -> void:
	var snapshot: Dictionary = event.data.get("snapshot", {})
	var tiles: Variant = event.data.get("tiles", snapshot.get("tiles", []))
	if tiles is Array:
		_tiles.clear()
		for tile: Variant in tiles:
			if tile is Dictionary:
				_tiles[Vector2i(int(tile.get("x", 0)), int(tile.get("y", 0)))] = tile.duplicate(true)
	if snapshot.has("allies") or snapshot.has("enemies"):
		_actors.clear()
		for side: String in ["allies", "enemies"]:
			for actor: Dictionary in snapshot.get(side, []):
				_actors[StringName(str(actor.get("id", "")))] = actor.duplicate(true)
		_bind_field_actors(snapshot)
	_reachable.clear()
	var movement: Dictionary = snapshot.get("movement", {})
	for row: Dictionary in movement.get("reachable", []):
		var cells: Array = row.get("path_cells", [])
		if not cells.is_empty() and cells.back() is Vector2i:
			_reachable[cells.back()] = true
	match event.type:
		&"turn_started", &"enemy_turn_started":
			_active_id = event.actor_id
			_target_id = &""
		&"action_resolved":
			_active_id = event.actor_id
			_target_id = event.target_id
		&"battle_finished":
			_active_id = &""
			_target_id = &""
	_sync_actors(event)
	if animate_events and event.type == &"action_resolved" and (event.data.get("path_cells", []) as Array).is_empty():
		_play_action(event)
	queue_redraw()


func _bind_field_actors(snapshot: Dictionary) -> void:
	if not is_instance_valid(_field):
		return
	var party_nodes: Array[Node2D] = []
	party_nodes.append(_field.player())
	var followers := _field.party_followers()
	if followers != null:
		for follower: PartyFollower in followers.followers():
			party_nodes.append(follower)
	var allies: Array = snapshot.get("allies", [])
	for index: int in mini(allies.size(), party_nodes.size()):
		bind_actor(StringName(str(allies[index].get("id", ""))), party_nodes[index])
	for hostile: Hostile in _field.hostiles():
		bind_actor(hostile.combat_id, hostile)


func _sync_actors(event: CombatEvent) -> void:
	if _grid == null:
		return
	for id: StringName in _actors:
		var node := _nodes.get(id) as Node2D
		if not is_instance_valid(node):
			continue
		var actor: Dictionary = _actors[id]
		var cell: Variant = _actor_cell(actor)
		if cell == null:
			continue
		var path: Array = event.data.get("path_cells", [])
		if animate_events and event.type == &"action_resolved" and id == event.actor_id and path.size() >= 2:
			_stop_move(id)
			var tween := create_tween()
			_moves[id] = tween
			for index: int in range(1, path.size()):
				if path[index] is Vector2i:
					tween.tween_property(node, "global_position", _grid.cell_to_world(path[index]), DS.DUR_FAST)
			tween.tween_callback(func() -> void: _moves.erase(id))
		elif not _moves.has(id):
			node.global_position = _grid.cell_to_world(cell)
		# Keep the actor's scene-authored art; facing is a presentation property only.
		var sprite := node.find_child("Sprite2D", true, false) as Sprite2D
		if sprite != null and actor.has("facing"):
			sprite.flip_h = str(actor["facing"]).contains("w")
		if int(actor.get("hp", 1)) <= 0:
			node.modulate.a = 0.35
		elif not _flashes.has(id):
			node.modulate = _original_colors.get(node, Color.WHITE)


func _play_action(event: CombatEvent) -> void:
	var attacker := _nodes.get(event.actor_id) as Node2D
	var target := _nodes.get(event.target_id) as Node2D
	if is_instance_valid(attacker) and is_instance_valid(target) and attacker != target:
		_stop_move(event.actor_id)
		var home := attacker.global_position
		var lunge := create_tween()
		_moves[event.actor_id] = lunge
		lunge.tween_property(attacker, "global_position", home.lerp(target.global_position, 0.25), DS.DUR_FAST)
		lunge.tween_property(attacker, "global_position", home, DS.DUR_FAST)
		lunge.tween_callback(func() -> void: _moves.erase(event.actor_id))
	if not is_instance_valid(target):
		return
	var previous := _flashes.get(event.target_id) as Tween
	if previous != null and previous.is_valid():
		previous.kill()
	var color: Color = _original_colors.get(target, Color.WHITE)
	if int((_actors.get(event.target_id, {}) as Dictionary).get("hp", 1)) <= 0:
		color.a = 0.35
	var flash := create_tween()
	_flashes[event.target_id] = flash
	target.modulate = DS.PARCHMENT
	flash.tween_property(target, "modulate", color, DS.DUR_BASE)
	flash.tween_callback(func() -> void: _flashes.erase(event.target_id))
	var pop := Label.new()
	if _theme == null:
		_theme = ThemeBuilder.build()
	pop.theme = _theme
	pop.theme_type_variation = &"StatLabel" if bool(event.data.get("hit", true)) else &"HeadingLabel"
	pop.mouse_filter = Control.MOUSE_FILTER_IGNORE
	pop.text = str(int(event.data.get("damage", 0))) if bool(event.data.get("hit", true)) else "MISS"
	pop.modulate = DS.PARCHMENT
	add_child(pop)
	pop.position = to_local(target.global_position) + Vector2(0, -48)
	var rise := create_tween().set_parallel(true)
	rise.tween_property(pop, "position:y", pop.position.y - 28.0, DS.DUR_SLOW)
	rise.tween_property(pop, "modulate:a", 0.0, DS.DUR_SLOW)
	rise.chain().tween_callback(pop.queue_free)


func _stop_move(id: StringName) -> void:
	var tween := _moves.get(id) as Tween
	if tween != null and tween.is_valid():
		tween.kill()
	_moves.erase(id)


func _actor_cell(actor: Dictionary) -> Variant:
	var value: Variant = actor.get("position")
	if value is Vector2i:
		return value
	if value is Vector2:
		return Vector2i(value)
	var token := str(value)
	if token.begins_with("c:"):
		var parts := token.trim_prefix("c:").split(",")
		if parts.size() >= 2 and parts[0].is_valid_int() and parts[1].is_valid_int():
			return Vector2i(parts[0].to_int(), parts[1].to_int())
	return null


func _diamond(cell: Vector2i) -> PackedVector2Array:
	var center := _ground.map_to_local(cell)
	var half := Vector2(_ground.tile_set.tile_size) * 0.5
	var points := PackedVector2Array()
	for offset: Vector2 in [Vector2(0, -half.y), Vector2(half.x, 0), Vector2(0, half.y), Vector2(-half.x, 0)]:
		points.append(to_local(_ground.to_global(center + offset)))
	return points


func _draw() -> void:
	if _grid == null or not is_instance_valid(_ground):
		return
	for cell: Vector2i in _tiles:
		var tile: Dictionary = _tiles[cell]
		var diamond := _diamond(cell)
		if _reachable.has(cell):
			draw_colored_polygon(diamond, Color(DS.TILE_SELECT_RIM, 0.12))
		var charge := int(tile.get("charge_level", 0))
		if charge > 0:
			var element_color := Color(str(tile.get("element_color", DS.MOTE_3.to_html())))
			draw_colored_polygon(diamond, DS.charge_tint(element_color, charge))
		if cell == _selected or cell == _hovered:
			diamond.append(diamond[0])
			draw_polyline(diamond, DS.TILE_SELECT_RIM, 2.0)
	for actor: Dictionary in _actors.values():
		var cell: Variant = _actor_cell(actor)
		if cell == null or int(actor.get("hp", 0)) <= 0:
			continue
		var center := cell_center(cell)
		var hp := int(actor.get("hp", 0))
		var max_hp := maxi(1, int(actor.get("max_hp", hp)))
		draw_rect(Rect2(center + Vector2(-16, -36), Vector2(32, 3)), DS.STONE_1)
		var fill_width := 32.0 * clampf(float(hp) / max_hp, 0, 1)
		draw_rect(Rect2(center + Vector2(-16, -36), Vector2(fill_width, 3)), DS.STATE_CONSTANT)
		draw_string(
			NUMERIC_FONT, center + Vector2(-16, -42), str(hp),
			HORIZONTAL_ALIGNMENT_LEFT, -1, 12, DS.PARCHMENT
		)
		var facing := str(actor.get("facing", ""))
		var direction := Vector2(
			float(facing.contains("e")) - float(facing.contains("w")),
			float(facing.contains("s")) - float(facing.contains("n"))
		).normalized()
		if not direction.is_zero_approx():
			var tip := center + direction * 18
			var side := direction.orthogonal() * 4
			draw_polyline(
				PackedVector2Array([tip - direction * 6 + side, tip, tip - direction * 6 - side]),
				DS.BRONZE_3, 2.0
			)
	for id: StringName in [_active_id, _target_id]:
		if not _actors.has(id):
			continue
		var cell: Variant = _actor_cell(_actors[id])
		if cell != null:
			var diamond := _diamond(cell)
			diamond.append(diamond[0])
			draw_polyline(diamond, DS.BRONZE_3 if id == _active_id else DS.CINDER_3, 2.0)
