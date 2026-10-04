class_name DestructibleStructure
extends SMInteractable
## Opt-in field binding for SaveGame.world_structures. The Blocking layer remains
## authoritative for physics and paths; this node owns no duplicate solid body.

const GROUP := &"world_structure"
const FRAMES := {"intact": 0, "damaged": 1, "ruined": 2, "rebuilding": 3}

@export var structure_id: String = ""
@export var max_integrity: int = 30
@export var rebuild_phases: int = 0
@export var blocking_path: NodePath
## Cells already painted in Blocking, exclusively owned by this object.
@export var footprint: Array[Vector2i] = []
## Zero disables manual damage. Positive values are for the playable test fixture;
## combat callers must supply resolved damage through apply_structure_damage().
@export var interaction_damage: int = 0

var structure_state: WorldStructureState
var _blocking: BlockingLayer
var _tiles: Dictionary = {}
var _shapes: Array[ConvexPolygonShape2D] = []
var _shape_transforms: Array[Transform2D] = []
var _bound := false
var _retry_elapsed := 0.0


func _ready() -> void:
	super._ready()
	repeatable = true
	structure_state = SaveGame.world_structures
	_blocking = get_node_or_null(blocking_path) as BlockingLayer
	if not _capture_footprint():
		push_error("%s requires an exclusive painted Blocking footprint with collision." % name)
		set_process_unhandled_input(false)
		return
	_bound = structure_state.register_structure(structure_id, max_integrity, rebuild_phases)
	if not _bound:
		push_error("%s has an invalid or conflicting structure registration." % name)
		set_process_unhandled_input(false)
		return
	add_to_group(GROUP)
	structure_state.structure_changed.connect(_on_structure_changed)
	structure_state.state_restored.connect(_on_state_restored)
	WorldClock.phase_advanced.connect(_on_world_phase_advanced)
	_refresh_structure()


func _capture_footprint() -> bool:
	if _blocking == null or _blocking.tile_set == null or footprint.is_empty():
		return false
	for node: Node in get_tree().get_nodes_in_group(GROUP):
		if node is DestructibleStructure and node._blocking == _blocking:
			for cell: Vector2i in footprint:
				if cell in node.footprint:
					return false
	for cell: Vector2i in footprint:
		var tile := _blocking.get_cell_tile_data(cell)
		if tile == null or _tiles.has(cell) or _blocking.tile_set.get_physics_layers_count() == 0:
			return false
		if tile.get_collision_polygons_count(0) == 0:
			return false
		_tiles[cell] = [
			_blocking.get_cell_source_id(cell), _blocking.get_cell_atlas_coords(cell),
			_blocking.get_cell_alternative_tile(cell),
		]
		for index in tile.get_collision_polygons_count(0):
			var shape := ConvexPolygonShape2D.new()
			shape.points = tile.get_collision_polygon_points(0, index)
			_shapes.append(shape)
			_shape_transforms.append(
				_blocking.global_transform * Transform2D(0.0, _blocking.map_to_local(cell))
			)
	return true


func apply_structure_damage(amount: int) -> bool:
	return _bound and structure_state.damage(structure_id, amount, WorldClock.phase_count)


func _apply_interaction() -> void:
	if interaction_damage > 0:
		apply_structure_damage(interaction_damage)
	# A ruin is still inspectable. Never turn repeated E presses into a repair.
	_refresh_structure()


func _on_structure_changed(id: String) -> void:
	if id == structure_id:
		_refresh_structure()


func _on_world_phase_advanced(_phase_count: int) -> void:
	# A countdown changes even when the model stays in "rebuilding".
	_refresh_structure()


func _on_state_restored() -> void:
	# Legacy saves and new-game resets have no registration yet.
	_bound = structure_state.register_structure(structure_id, max_integrity, rebuild_phases)
	if _bound:
		_refresh_structure()


func _refresh_structure() -> void:
	if not _bound:
		return
	var row := structure_state.structure(structure_id)
	var solid: bool = int(row.integrity) > 0
	_blocking.set_structure_footprint(_tiles, solid)
	$Sprite2D.frame = FRAMES[row.state]
	prompt_text = "STRIKE" if interaction_damage > 0 and row.state != "ruined" else "INSPECT"
	interaction_text = "%s — %s (%d/%d)" % [
		display_name, str(row.state).to_upper(), row.integrity, row.max_integrity,
	]
	if int(row.rebuild_at) >= 0:
		var remaining := maxi(0, int(row.rebuild_at) - WorldClock.phase_count)
		interaction_text += (
			"\nRepair: %d world phases" % remaining
			if remaining > 0 else "\nRepair waiting for a clear site."
		)
	elif not solid:
		interaction_text += "\nNo one maintains this site."
	_refresh_prompt()


func _refresh_prompt() -> void:
	super._refresh_prompt()
	if _prompt != null and _bound:
		_prompt.text += "\n" + interaction_text


## SaveGame asks before restoring any loaded footprint. Physics catches body
## edges, while live cells also catch moves this frame and non-physical followers.
func rebuild_is_blocked() -> bool:
	if not _bound:
		return true
	var root := _blocking.owner if _blocking.owner != null else _blocking.get_parent()
	var field := root.find_child("FieldMap", true, false) as FieldMap
	if field != null and field.combat_mode_active():
		return true
	for node: Node in root.find_children("*", "Node2D", true, false):
		if not (node is CharacterBody2D or node is PartyFollower):
			continue
		var actor := node as Node2D
		# Followers have no collision body; include a modest foot radius for them.
		var offsets: Array[Vector2] = [
			Vector2.ZERO, Vector2(16, 0), Vector2(-16, 0), Vector2(0, 16), Vector2(0, -16),
		]
		for offset: Vector2 in offsets:
			var cell := _blocking.local_to_map(_blocking.to_local(actor.global_position + offset))
			if cell in footprint:
				return true
	for index in _shapes.size():
		var query := PhysicsShapeQueryParameters2D.new()
		query.shape = _shapes[index]
		query.transform = _shape_transforms[index]
		query.collision_mask = 0xFFFFFFFF
		for hit: Dictionary in get_world_2d().direct_space_state.intersect_shape(query):
			if (
				(hit.collider is CharacterBody2D or hit.collider is RigidBody2D)
				and root.is_ancestor_of(hit.collider)
			):
				return true
	return false


func _process(delta: float) -> void:
	if not _bound:
		return
	_retry_elapsed += delta
	if _retry_elapsed < 0.25:
		return
	_retry_elapsed = 0.0
	var row := structure_state.structure(structure_id)
	if int(row.rebuild_at) >= 0 and WorldClock.phase_count >= int(row.rebuild_at):
		SaveGame.advance_world_structures()
