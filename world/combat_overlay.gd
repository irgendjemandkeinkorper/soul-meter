class_name CombatOverlay
extends Node2D
## Field-space presentation only. CombatEvent snapshots own state; IsoGrid owns projection.
## Actor nodes are borrowed, never duplicated, and no combat model is mutated here.

var _grid: IsoGrid
var _ground: TileMapLayer
## Vector2i -> the controller snapshot's tile dictionary, by reference (read-only here; each
## snapshot builds fresh ones). tile_at() hands out copies.
var _tiles: Dictionary = {}
var _tiles_source: Array = []  ## the payload array _tiles was read from; same array, same tiles
## StringName -> the snapshot's actor row, by reference (read-only here; each snapshot builds
## fresh rows).
var _actors: Dictionary = {}
var _bound_roster := PackedStringArray()  ## actor ids, in snapshot order, last bound to nodes
var _nodes: Dictionary = {}
var _moves: Dictionary = {}
var _active_id: StringName
var _target_id: StringName
var _preview_id: StringName
var _reachable: Dictionary = {}
var _fire_cells: Dictionary = {}
var _mark_cells: Dictionary = {}
var _light_cells: Dictionary = {}
var _shroud_cells: Dictionary = {}  # Vector2i -> true (inside a Shroud / Eclipse Procession)
var _selected: Variant = null
var _hovered: Variant = null
var _field: FieldMap
var _original_colors: Dictionary = {}
var _flashes: Dictionary = {}
var _pending_defeats: Dictionary = {}
var _theme: Theme
var animate_events := true:
	set(value):
		animate_events = value
		if not value and is_inside_tree():
			_settle_motion()
			for effect: Node in get_children():
				effect.queue_free()
## D6 camera: the field camera belongs to the player and keeps following them. The overlay
## only drives its `offset`, so limits and smoothing stay the player's, and clearing the
## offset at the end is all it takes to hand the view back.
var _camera: Camera2D
var _camera_anchor: Node2D
var _camera_tween: Tween
## The screen rect the battle HUD leaves open over the field. Framing centres the fight in
## it and visibility checks use it, so an actor behind a HUD panel counts as off-screen.
## Empty means the whole viewport.
var _view_window := Rect2()
## The camera's own limits, lifted for the fight so it can centre a fight at a room's edge,
## and handed back once the release pan lands.
var _saved_limits: Array[int] = []
var _roster_framed := false
## Actor ids whose current turn began beyond one screen of margin (D9): no pan, no move
## tween — the actor snaps between cells until its next turn starts nearer the view.
var _suppressed: Dictionary = {}
const NUMERIC_FONT := preload(DS.FONT_NUMERIC)
const HitPulseScript := preload("res://ui/hud/hit_pulse.gd")
const SpellCastScript := preload("res://ui/hud/spell_cast_effect.gd")
const CombatMotionScript := preload("res://ui/hud/combat_motion.gd")
const CombatResultScene := preload("res://ui/hud/combat_result.tscn")
## D9: how far past the visible rect an enemy may start its turn and still earn a pan.
const CAMERA_MARGIN_SCREENS := 1.0


func _ready() -> void:
	GameState.setting_changed.connect(_on_setting_changed)


func set_preview_target(actor_id: StringName) -> void:
	_preview_id = actor_id
	queue_redraw()


func bind_field(field: FieldMap) -> void:
	_field = field
	_bound_roster = PackedStringArray()
	z_index = 1
	bind_grid(field.iso_grid(), field.ground())
	var lead := field.player()
	if lead != null:
		var camera := lead.get_node_or_null("Camera2D") as Camera2D
		if camera != null:
			bind_camera(camera, lead)


func bind_camera(camera: Camera2D, anchor: Node2D) -> void:
	_camera = camera
	_camera_anchor = anchor
	_roster_framed = false
	_saved_limits = [camera.limit_left, camera.limit_top, camera.limit_right, camera.limit_bottom]
	# Start the fight from what the player was already looking at: the clamped centre.
	camera.offset = _clamped_center(anchor.global_position) - anchor.global_position
	camera.limit_left = -10000000
	camera.limit_top = -10000000
	camera.limit_right = 10000000
	camera.limit_bottom = 10000000


## `window` is in viewport pixels; see `_view_window`.
func set_view_window(window: Rect2) -> void:
	if window == _view_window:
		return
	_view_window = window
	# The HUD lays out after the session's first events are replayed; re-centre once it has.
	if _roster_framed:
		_roster_framed = false
		_frame_roster()


func pans_suppressed_for(actor_id: StringName) -> bool:
	return _suppressed.has(actor_id)


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
		# A locked hostile's dim is its gate, not its colour. It is bound with the rest of the
		# field at session start; its colour is recorded once it opens and can actually join.
		if node is Hostile and not (node as Hostile).is_unlocked():
			return
		_original_colors[node] = node.modulate


## A bound actor's node, or null once it is freed (Battle frees set-piece bodies with the
## session, which can be before this overlay leaves the tree).
func _node(id: StringName) -> Node2D:
	var node: Variant = _nodes.get(id)
	return node as Node2D if is_instance_valid(node) else null


func _exit_tree() -> void:
	_settle_motion()
	for node: Variant in _original_colors:
		if is_instance_valid(node):
			node.modulate = _original_colors[node]
	_release_camera(false)


func is_animating() -> bool:
	if not _moves.is_empty() or not _flashes.is_empty():
		return true
	for effect: Node in get_children():
		if effect.get_script() == SpellCastScript and effect.is_animating():
			return true
	return false


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
	if tiles is Array and not is_same(tiles, _tiles_source):
		_tiles_source = tiles
		_tiles.clear()
		for tile: Variant in tiles:
			if tile is Dictionary:
				_tiles[Vector2i(int(tile.get("x", 0)), int(tile.get("y", 0)))] = tile
	if snapshot.has("allies") or snapshot.has("enemies"):
		_actors.clear()
		var roster := PackedStringArray()
		for side: String in ["allies", "enemies"]:
			for actor: Dictionary in snapshot.get(side, []):
				var id := StringName(str(actor.get("id", "")))
				_actors[id] = actor
				roster.append(id)
		# Binding walks every field node; the roster only changes on admission and exit.
		if roster != _bound_roster:
			_bound_roster = roster
			_bind_field_actors(snapshot)
	_reachable.clear()
	_read_fields(snapshot)
	var movement: Dictionary = snapshot.get("movement", {})
	for row: Dictionary in movement.get("reachable", []):
		var cells: Array = row.get("path_cells", [])
		if not cells.is_empty() and cells.back() is Vector2i:
			_reachable[cells.back()] = true
	match event.type:
		&"turn_started", &"enemy_turn_started":
			_active_id = event.actor_id
			_target_id = &""
			_focus_camera(event.actor_id, event.type == &"enemy_turn_started")
		&"action_resolved":
			_active_id = event.actor_id
			_target_id = event.target_id
		&"battle_finished":
			_active_id = &""
			_target_id = &""
			_release_camera(animate_events)
	if animate_events and not _reduced_motion() and is_instance_valid(_nodes.get(event.actor_id)) \
			and SpellCastScript.is_cast(event) and HitPulseScript.is_damaging_hit(event):
		_pending_defeats[event.target_id] = event.get_instance_id()
	_sync_actors(event)
	_frame_roster()
	if animate_events and event.type == &"action_resolved" and (event.data.get("path_cells", []) as Array).is_empty():
		_play_action(event)
	queue_redraw()


## The rect the player currently sees, in world space, from the camera the overlay drives.
## Uses the intended centre (anchor + offset) rather than the smoothed one so a pan already
## in flight is not re-decided against a half-way frame.
func _view_rect() -> Rect2:
	var viewport := _camera.get_viewport_rect().size
	var window := _window(viewport)
	var center := _camera_anchor.global_position + _camera.offset
	return Rect2(center + (window.position - viewport * 0.5) / _camera.zoom, window.size / _camera.zoom)


func _window(viewport: Vector2) -> Rect2:
	return _view_window if _view_window.has_area() else Rect2(Vector2.ZERO, viewport)


## The camera offset that puts world point `point` at the centre of the open window.
func _offset_framing(point: Vector2) -> Vector2:
	var viewport := _camera.get_viewport_rect().size
	var shift := (_window(viewport).get_center() - viewport * 0.5) / _camera.zoom
	return point - shift - _camera_anchor.global_position


## Once per session: centre every combatant in the window, so the opening shows both sides
## rather than wherever the room camera happened to stop.
func _frame_roster() -> void:
	if _roster_framed or not is_instance_valid(_camera) or not is_instance_valid(_camera_anchor):
		return
	var bounds := Rect2()
	var found := false
	for id: StringName in _actors:
		var node := _node(id)
		if not is_instance_valid(node):
			continue
		bounds = bounds.expand(node.global_position) if found else Rect2(node.global_position, Vector2.ZERO)
		found = true
	if not found:
		return
	_roster_framed = true
	var view := _view_rect()
	# A roster wider than the window frames the lead instead; turn focus pans to the rest.
	var focus := bounds.get_center() if view.size.x >= bounds.size.x and view.size.y >= bounds.size.y \
		else _camera_anchor.global_position
	_pan_camera_to(_offset_framing(focus))


## Where the camera would sit for `center` under its own (saved) limits.
func _clamped_center(center: Vector2) -> Vector2:
	if _saved_limits.size() != 4:
		return center
	var half := _camera.get_viewport_rect().size * 0.5 / _camera.zoom
	var low := Vector2(_saved_limits[0], _saved_limits[1]) + half
	var high := Vector2(_saved_limits[2], _saved_limits[3]) - half
	return Vector2(
		center.x if low.x > high.x else clampf(center.x, low.x, high.x),
		center.y if low.y > high.y else clampf(center.y, low.y, high.y),
	)


func _focus_camera(actor_id: StringName, is_enemy: bool) -> void:
	if not is_instance_valid(_camera) or not is_instance_valid(_camera_anchor):
		return
	var node := _node(actor_id)
	if not is_instance_valid(node):
		return
	var view := _view_rect()
	if view.has_point(node.global_position):
		_suppressed.erase(actor_id)
		return
	if is_enemy and not view.grow_individual(
		view.size.x * CAMERA_MARGIN_SCREENS, view.size.y * CAMERA_MARGIN_SCREENS,
		view.size.x * CAMERA_MARGIN_SCREENS, view.size.y * CAMERA_MARGIN_SCREENS
	).has_point(node.global_position):
		_suppressed[actor_id] = true
		return
	_suppressed.erase(actor_id)
	_pan_camera_to(_offset_framing(node.global_position))


func _release_camera(animated: bool) -> void:
	_suppressed.clear()
	if not is_instance_valid(_camera):
		return
	if animated and is_instance_valid(_camera_anchor):
		# Pan to where the limited camera will sit, then restore the limits: no snap.
		var anchor := _camera_anchor.global_position
		_pan_camera_to(_clamped_center(anchor) - anchor)
		if _camera_tween != null and _camera_tween.is_valid():
			_camera_tween.tween_callback(_restore_camera_limits)
			return
	if _camera_tween != null and _camera_tween.is_valid():
		_camera_tween.kill()
	_camera_tween = null
	_restore_camera_limits()


func _restore_camera_limits() -> void:
	if not is_instance_valid(_camera):
		return
	if _saved_limits.size() == 4:
		_camera.limit_left = _saved_limits[0]
		_camera.limit_top = _saved_limits[1]
		_camera.limit_right = _saved_limits[2]
		_camera.limit_bottom = _saved_limits[3]
		_saved_limits.clear()
	_camera.offset = Vector2.ZERO
	_camera.reset_smoothing()


func _pan_camera_to(offset: Vector2) -> void:
	if _camera_tween != null and _camera_tween.is_valid():
		_camera_tween.kill()
	_camera_tween = null
	if not animate_events or not is_inside_tree():
		_camera.offset = offset
		return
	_camera_tween = create_tween().set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN_OUT)
	_camera_tween.tween_property(_camera, "offset", offset, DS.DUR_BASE)


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
	if _grid == null or not is_instance_valid(_ground):
		return
	for id: StringName in _actors:
		var node := _node(id)
		if not is_instance_valid(node):
			continue
		var actor: Dictionary = _actors[id]
		var cell: Variant = _actor_cell(actor)
		if cell == null:
			continue
		var path: Array = event.data.get("path_cells", [])
		if (
			animate_events and not _reduced_motion() and event.type == &"action_resolved"
			and id == event.actor_id and path.size() >= 2 and not _suppressed.has(id)
		):
			_stop_move(id)
			var points := PackedVector2Array([node.global_position])
			for index: int in range(1, path.size()):
				if path[index] is Vector2i:
					points.append(_grid.cell_to_world(path[index]))
			var tween := CombatMotionScript.along_path(self, points, _set_actor_position.bind(id))
			_moves[id] = tween
			tween.tween_callback(func() -> void: _moves.erase(id))
		elif not _moves.has(id):
			node.global_position = _grid.cell_to_world(cell)
		# Keep the actor's scene-authored art; facing is a presentation property only.
		var sprite := node.find_child("Sprite2D", true, false) as Sprite2D
		if sprite != null and actor.has("facing"):
			sprite.flip_h = str(actor["facing"]).contains("w")
		if int(actor.get("hp", 1)) <= 0:
			if not _pending_defeats.has(id):
				_stop_flash(id)
				node.modulate.a = 0.35
		elif not _flashes.has(id):
			node.modulate = _original_colors.get(node, Color.WHITE)


func _play_action(event: CombatEvent) -> void:
	var attacker := _node(event.actor_id)
	var target := _node(event.target_id)
	if is_instance_valid(attacker) and SpellCastScript.is_cast(event):
		var targets: Array[Callable] = []
		for cell: Vector2i in FireField.cells_from_data(event.data.get("cells", [])):
			targets.append(cell_center.bind(cell))
		if targets.is_empty():
			targets.append(_result_anchor.bind(event.target_id if is_instance_valid(target) else event.actor_id))
		var spell := SpellCastScript.new()
		spell.name = "SpellCast"
		spell.setup(event, _result_anchor.bind(event.actor_id), targets, 1.0)
		spell.impact_reached.connect(_present_action_result.bind(event), CONNECT_ONE_SHOT)
		add_child(spell)
		return
	if not _reduced_motion() and is_instance_valid(attacker) and is_instance_valid(target) and attacker != target:
		_stop_move(event.actor_id)
		var home := attacker.global_position
		var cell: Variant = _actor_cell(_actors.get(event.actor_id, {}))
		if _grid != null and cell != null:
			home = _grid.cell_to_world(cell)
		var lunge := create_tween()
		_moves[event.actor_id] = lunge
		lunge.set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN_OUT)
		var toward := home + (target.global_position - home).limit_length(DS.SPACE_4)
		lunge.tween_method(_set_actor_position.bind(event.actor_id), attacker.global_position, toward, DS.DUR_FAST)
		lunge.tween_method(_set_actor_position.bind(event.actor_id), toward, home, DS.DUR_FAST)
		lunge.tween_callback(func() -> void: _moves.erase(event.actor_id))
	_present_action_result(event)


func _present_action_result(event: CombatEvent) -> void:
	if _pending_defeats.get(event.target_id, 0) == event.get_instance_id():
		_pending_defeats.erase(event.target_id)
		_sync_actors(CombatEvent.new())
	var target := _node(event.target_id)
	if not is_instance_valid(target):
		return
	if HitPulseScript.is_damaging_hit(event) and not _reduced_motion():
		if not SpellCastScript.is_cast(event):
			var pulse := HitPulseScript.new()
			pulse.name = "HitPulse"
			pulse.position = _result_anchor(event.target_id)
			add_child(pulse)
		_stop_flash(event.target_id)
		# A defeated target keeps its fallen opacity; feedback must not revive its tint.
		if int((_actors.get(event.target_id, {}) as Dictionary).get("hp", 1)) > 0:
			var color: Color = _original_colors.get(target, Color.WHITE)
			var flash := create_tween()
			_flashes[event.target_id] = flash
			target.modulate = color * DS.PARCHMENT
			flash.tween_property(target, "modulate", color, DS.DUR_BASE)
			flash.tween_callback(func() -> void: _flashes.erase(event.target_id))
	if not HitPulseScript.has_result(event):
		return
	for previous: Node in get_children():
		if previous.get_meta("result_target", &"") == event.target_id:
			remove_child(previous)
			previous.queue_free()
	var pop := CombatResultScene.instantiate()
	if _theme == null:
		_theme = ThemeBuilder.build()
	pop.theme = _theme
	add_child(pop)
	pop.setup(event, _result_anchor.bind(event.target_id),
		func() -> Rect2: return get_viewport_rect()
	)


func _result_anchor(id: StringName) -> Variant:
	var target := _node(id)
	return to_local(target.global_position) + Vector2(0, -DS.SPACE_8) if is_instance_valid(target) else null


func _set_actor_position(value: Vector2, id: StringName) -> void:
	var node := _node(id)
	if is_instance_valid(node):
		node.global_position = value
		queue_redraw()


func _reduced_motion() -> bool:
	return bool(GameState.get_setting("accessibility", "reduced_motion", false))


func _on_setting_changed(section: String, key: String, value: Variant) -> void:
	if section == "accessibility" and key == "reduced_motion" and bool(value):
		_settle_motion()
		for effect: Node in get_children():
			if effect.get_script() == HitPulseScript:
				effect.queue_free()


func _settle_motion() -> void:
	for id: StringName in _moves.keys():
		_stop_move(id)
	for id: StringName in _flashes.keys():
		_stop_flash(id)
	_pending_defeats.clear()
	_sync_actors(CombatEvent.new())
	queue_redraw()


func _stop_move(id: StringName) -> void:
	var tween := _moves.get(id) as Tween
	if tween != null and tween.is_valid():
		tween.kill()
	_moves.erase(id)


func _stop_flash(id: StringName) -> void:
	var tween := _flashes.get(id) as Tween
	if tween != null and tween.is_valid():
		tween.kill()
	_flashes.erase(id)


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


func _draw() -> void:
	if _grid == null or not is_instance_valid(_ground):
		return
	for cell: Vector2i in _tiles:
		var tile: Dictionary = _tiles[cell]
		var diamond := _diamond(cell)
		if _reachable.has(cell):
			draw_colored_polygon(diamond, Color(DS.TILE_SELECT_RIM, 0.12))
		if _shroud_cells.has(cell):
			draw_colored_polygon(diamond, Color(0.22, 0.16, 0.36, 0.30))
		if _light_cells.has(cell):
			draw_colored_polygon(diamond, Color(1.0, 0.94, 0.70, 0.22))
		if _fire_cells.has(cell):
			draw_colored_polygon(diamond, Color(0.94, 0.42, 0.16, 0.34))
		elif _mark_cells.has(cell):
			draw_colored_polygon(diamond, Color(0.94, 0.42, 0.16, 0.14))
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
	for id: StringName in [_active_id, _preview_id if not _preview_id.is_empty() else _target_id]:
		if not _actors.has(id):
			continue
		var cell: Variant = _actor_cell(_actors[id])
		if cell != null:
			var diamond := _diamond(cell)
			diamond.append(diamond[0])
			draw_polyline(diamond, DS.BRONZE_3 if id == _active_id else DS.CINDER_3, 2.0)
