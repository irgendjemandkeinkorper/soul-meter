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
## #281 G9: KO fades and the ids already shown downed, so a later snapshot neither restarts
## the fade nor snaps it.
var _fades: Dictionary = {}
var _downed: Dictionary = {}
## #281 G10: the HP each bar draws (`_shown_hp`) eases to the presented snapshot value
## (`_hp_target`); `_ghost_hp` trails behind it so the lost slice reads before it drains.
var _shown_hp: Dictionary = {}
var _ghost_hp: Dictionary = {}
var _hp_target: Dictionary = {}
var _hp_tweens: Dictionary = {}
## #281 G1: the model resolves a whole enemy phase in one frame. Events are presented in
## emitted order, and an action beat holds the presentation long enough to read before the
## next event is presented. The queue only spaces presentation: order and content come from
## the event stream, and nothing here feeds back into combat.
var _queue: Array[CombatEvent] = []
var _holding := false
var _beat: Tween
var _theme: Theme
var animate_events := true:
	set(value):
		animate_events = value
		if not value and is_inside_tree():
			_flush_queue()
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
## #281 G1: how long an action beat with a result card stays alone on screen before the next
## presented event. The card itself lives longer (combat_result.gd); the next card or the
## next turn cue retires it, so a card never sits over a beat it does not describe.
const BEAT_READ_SECONDS := 1.2
## A turn start's cue: the active diamond lands on the actor before its action plays.
const TURN_CUE_SECONDS := DS.DUR_SLOW
## #281 G9: a downed body is dimmed, not hidden; it must stay clearly visible on the field.
const KO_TINT := Color(0.6, 0.6, 0.66, 0.8)
## #281 G7: CombatEvent facing ids are grid directions (GridBattlefieldModel._ORDER, by
## atan2 over the cell delta), not screen directions.
const FACING_STEPS := {
	"e": Vector2i(1, 0), "se": Vector2i(1, 1), "s": Vector2i(0, 1), "sw": Vector2i(-1, 1),
	"w": Vector2i(-1, 0), "nw": Vector2i(-1, -1), "n": Vector2i(0, -1), "ne": Vector2i(1, -1),
}


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
	_queue.clear()
	_end_hold()
	_settle_motion()
	for node: Variant in _original_colors:
		if is_instance_valid(node):
			node.modulate = _original_colors[node]
	_release_camera(false)


## True while bodies are in motion or presented beats are still waiting their turn. A lone
## beat's reading hold does not count: the result outlives motion without gating input.
func is_animating() -> bool:
	if not _moves.is_empty() or not _flashes.is_empty() or not _queue.is_empty():
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


## True until every received event has been presented and the last beat's hold has ended.
func is_presenting() -> bool:
	return _holding or not _queue.is_empty()


func consume_event(event: CombatEvent) -> void:
	if not animate_events:
		_flush_queue()
		_present(event)
		return
	if _holding or not _queue.is_empty():
		_queue.append(event)
		return
	_present(event)


func _present(event: CombatEvent) -> void:
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
			_retire_result_cards()
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
	_sync_hp()
	_frame_roster()
	var path: Array = event.data.get("path_cells", [])
	if animate_events and event.type == &"action_resolved" and path.is_empty():
		_play_action(event)
	queue_redraw()
	if animate_events:
		_hold(_beat_seconds(event, path))


## How long `event` keeps the presentation before the next queued event is presented.
func _beat_seconds(event: CombatEvent, path: Array) -> float:
	match event.type:
		&"enemy_turn_started":
			return TURN_CUE_SECONDS
		&"action_resolved":
			if path.size() >= 2:
				return DS.DUR_FAST * (path.size() if _moves.has(event.actor_id) else 1)
			if SpellCastScript.is_cast(event) and is_instance_valid(_node(event.actor_id)):
				return SpellCastScript.DURATION + BEAT_READ_SECONDS
			if HitPulseScript.has_result(event):
				return BEAT_READ_SECONDS
			if not event.target_id.is_empty():
				return DS.DUR_FAST * 2.0
	return 0.0


func _hold(seconds: float) -> void:
	if seconds <= 0.0 or not is_inside_tree():
		return
	_end_hold()
	_holding = true
	_beat = create_tween()
	_beat.tween_interval(seconds)
	_beat.tween_callback(_release_hold)


func _release_hold() -> void:
	_holding = false
	_beat = null
	while not _queue.is_empty() and not _holding:
		_present(_queue.pop_front())


func _end_hold() -> void:
	if _beat != null and _beat.is_valid():
		_beat.kill()
	_beat = null
	_holding = false


## Presents everything still waiting at once (replay, reduced presentation, teardown).
func _flush_queue() -> void:
	_end_hold()
	var pending := _queue.duplicate()
	_queue.clear()
	for event: CombatEvent in pending:
		_present(event)
	_end_hold()


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
				_fall(id, node)
		else:
			_downed.erase(id)
			_stop_fade(id)
			if not _flashes.has(id):
				node.modulate = _original_colors.get(node, Color.WHITE)


## #281 G9: a felled body fades to KO_TINT once, then stays there.
func _fall(id: StringName, node: Node2D) -> void:
	var fallen: Color = _original_colors.get(node, Color.WHITE) * KO_TINT
	if _fades.has(id):
		return
	# Already down, or first seen down (a replayed or joined session): settle without a fade.
	if _downed.has(id) or not _hp_target.has(id) or not animate_events or _reduced_motion():
		node.modulate = fallen
		_downed[id] = true
		return
	_downed[id] = true
	var fade := create_tween().set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_OUT)
	_fades[id] = fade
	fade.tween_property(node, "modulate", fallen, DS.DUR_SLOW * 2.0)
	fade.tween_callback(func() -> void: _fades.erase(id))


func _stop_fade(id: StringName) -> void:
	var tween := _fades.get(id) as Tween
	if tween != null and tween.is_valid():
		tween.kill()
	_fades.erase(id)


## #281 G10: each bar eases from what it showed to the presented HP; the lost slice lingers.
func _sync_hp() -> void:
	for id: StringName in _actors:
		var hp := float(int((_actors[id] as Dictionary).get("hp", 0)))
		if _hp_target.get(id, -1.0) == hp:
			continue
		var animate := _shown_hp.has(id) and animate_events and not _reduced_motion() and is_inside_tree()
		_hp_target[id] = hp
		_stop_hp(id)
		if not animate:
			_shown_hp[id] = hp
			_ghost_hp[id] = hp
			continue
		_ghost_hp[id] = maxf(float(_ghost_hp.get(id, hp)), float(_shown_hp[id]))
		var tick := create_tween().set_parallel(true)
		_hp_tweens[id] = tick
		tick.tween_method(_set_shown_hp.bind(id, _shown_hp), float(_shown_hp[id]), hp, DS.DUR_SLOW) \
			.set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_OUT)
		tick.tween_method(_set_shown_hp.bind(id, _ghost_hp), float(_ghost_hp[id]), minf(hp, float(_ghost_hp[id])), DS.DUR_SLOW) \
			.set_delay(DS.DUR_SLOW + DS.DUR_BASE)
		tick.chain().tween_callback(func() -> void:
			_hp_tweens.erase(id)
			_ghost_hp[id] = hp
			queue_redraw()
		)


func _set_shown_hp(value: float, id: StringName, into: Dictionary) -> void:
	into[id] = value
	queue_redraw()


func _stop_hp(id: StringName) -> void:
	var tween := _hp_tweens.get(id) as Tween
	if tween != null and tween.is_valid():
		tween.kill()
	_hp_tweens.erase(id)


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
	# #281 G1: one result card on the field at a time. The next beat's card replaces the
	# last one instead of stacking over it (adjacent combatants share screen space).
	for previous: Node in get_children():
		if previous.has_meta("result_target"):
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


## Fades out result cards from earlier beats (a new turn has begun).
func _retire_result_cards() -> void:
	for card: Node in get_children():
		if not card.has_meta("result_target") or card.has_meta("retiring"):
			continue
		card.set_meta("retiring", true)
		if not animate_events or not is_inside_tree():
			remove_child(card)
			card.queue_free()
			continue
		var fade := create_tween()
		fade.tween_property(card, "modulate:a", 0.0, DS.DUR_BASE)
		fade.tween_callback(card.queue_free)


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
	for id: StringName in _fades.keys():
		_stop_fade(id)
	for id: StringName in _hp_tweens.keys():
		_stop_hp(id)
	for id: Variant in _hp_target:
		_shown_hp[id] = _hp_target[id]
		_ghost_hp[id] = _hp_target[id]
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
	# #281 G2: everything attached to a combatant is drawn at its body, so it travels with a
	# move slide or lunge instead of waiting at the destination cell.
	for id: StringName in _actors:
		var actor: Dictionary = _actors[id]
		var cell: Variant = _actor_cell(actor)
		if cell == null:
			continue
		var shown := float(_shown_hp.get(id, int(actor.get("hp", 0))))
		var ghost := float(_ghost_hp.get(id, shown))
		if shown <= 0.0 and ghost <= 0.0:
			continue
		var anchor := _body_anchor(id, cell)
		_draw_hp(anchor, shown, ghost, maxi(1, int(actor.get("max_hp", int(actor.get("hp", 1))))))
		if int(actor.get("hp", 0)) > 0:
			_draw_facing(anchor, cell, str(actor.get("facing", "")))
	for id: StringName in [_active_id, _preview_id if not _preview_id.is_empty() else _target_id]:
		if not _actors.has(id):
			continue
		var cell: Variant = _actor_cell(_actors[id])
		if cell != null:
			var diamond := _diamond(cell)
			diamond.append(diamond[0])
			var shift := _body_anchor(id, cell) - cell_center(cell)
			for index: int in diamond.size():
				diamond[index] += shift
			draw_polyline(diamond, DS.BRONZE_3 if id == _active_id else DS.CINDER_3, 3.0)


## Where a combatant's body stands now: its bound node (mid-slide or mid-lunge), else its cell.
func _body_anchor(id: StringName, cell: Vector2i) -> Vector2:
	var node := _node(id)
	return to_local(node.global_position) if is_instance_valid(node) else cell_center(cell)


func _draw_hp(anchor: Vector2, shown: float, ghost: float, max_hp: int) -> void:
	var bar := Rect2(anchor + Vector2(-18, -38), Vector2(36, 5))
	draw_rect(bar.grow(1), DS.STONE_0)
	draw_rect(bar, DS.STONE_1)
	if ghost > shown:
		var ghost_rect := bar
		ghost_rect.size.x = bar.size.x * clampf(ghost / max_hp, 0, 1)
		draw_rect(ghost_rect, DS.STATE_FEEDBACK)
	var fill := bar
	fill.size.x = bar.size.x * clampf(shown / max_hp, 0, 1)
	draw_rect(fill, DS.STATE_CONSTANT)
	var label := str(ceili(shown))
	# Beside the bar, not above it: adjacent combatants' bars sit one iso step apart, and a
	# number above one bar lands on its neighbour's.
	var origin := bar.position + Vector2(bar.size.x + DS.SPACE_2, bar.size.y + 4)
	draw_string_outline(NUMERIC_FONT, origin, label, HORIZONTAL_ALIGNMENT_LEFT, -1, 14, 4, DS.STONE_0)
	draw_string(NUMERIC_FONT, origin, label, HORIZONTAL_ALIGNMENT_LEFT, -1, 14, DS.PARCHMENT)


## #281 G7: the chevron points along the grid neighbour the facing names, at the cell's rim.
func _draw_facing(anchor: Vector2, cell: Vector2i, facing: String) -> void:
	if not FACING_STEPS.has(facing) or _grid == null:
		return
	var reach := facing_vector(cell, facing) * 0.5
	if reach.is_zero_approx():
		return
	var direction := reach.normalized()
	var side := direction.orthogonal() * 9.0
	var tip := anchor + reach + direction * 16.0
	var base := anchor + reach - direction * 2.0
	var arrow := PackedVector2Array([tip, base + side, base - side])
	draw_colored_polygon(arrow, DS.BRONZE_4)
	arrow.append(arrow[0])
	draw_polyline(arrow, DS.STONE_0, 1.5)


## The local-space step from `cell` to the neighbour its facing names (zero when unknown).
func facing_vector(cell: Vector2i, facing: String) -> Vector2:
	if not FACING_STEPS.has(facing) or _grid == null:
		return Vector2.ZERO
	return cell_center(cell + (FACING_STEPS[facing] as Vector2i)) - cell_center(cell)
