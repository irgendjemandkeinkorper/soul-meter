class_name FieldMap
extends Node2D
## Stable field-scene seam shared by navigation and same-map combat.

## Re-emitted for every hostile that accepts an alert on this field, whether the alert came
## from a proximity sensor, from being targeted, or from a chain hop. Battle listens for it and
## decides whether that means "open a session" or "admit into the running one".
signal hostile_alerted(hostile: Hostile)

var _combat_mode_active: bool = false
var _restore_controls: Array[Callable] = []


func _ready() -> void:
	_connect_hostiles.call_deferred()


func ground() -> TileMapLayer:
	var root: Node = _field_root()
	var layer := root.find_child("IsometricGround", true, false) as TileMapLayer
	return layer if layer != null else root.find_child("FieldGround", true, false) as TileMapLayer


func blocking() -> TileMapLayer:
	var root: Node = _field_root()
	var layer := root.find_child("Blocking", true, false) as TileMapLayer
	return layer if layer != null else root.find_child("FieldBlocking", true, false) as TileMapLayer


func iso_grid() -> IsoGrid:
	var controller := (
		_field_root().find_child("ClickMoveController", true, false) as ClickMoveController
	)
	return controller.get_iso_grid() if controller != null else null


## CombatOverlay is introduced in migration step 6; null is the supported value until then.
func combat_overlay() -> Node2D:
	return _field_root().find_child("CombatOverlay", true, false) as Node2D


func set_combat_mode(active: bool) -> void:
	if _combat_mode_active == active:
		return
	_combat_mode_active = active
	var root: Node = _field_root()
	var player := root.find_child("Player", true, false) as Player
	if player != null:
		player.velocity = Vector2.ZERO
	if not active:
		for restore: Callable in _restore_controls:
			if restore.is_valid():
				restore.call()
		_restore_controls.clear()
		return
	if player != null:
		_restore_controls.append(player.set_physics_process.bind(player.is_physics_processing()))
		player.set_physics_process(false)
		var controller := (
			player.find_child("ClickMoveController", true, false) as ClickMoveController
		)
		if controller != null:
			_restore_controls.append(controller.set.bind("enabled", controller.enabled))
			controller.cancel_path()
			controller.enabled = false
	# Interact prompts (E) used to hide behind the paused tree. The field stays live during
	# combat now, so every interactable's unhandled input is switched off instead.
	for node: Node in root.find_children("*", "", true, false):
		if node is PartyFollowers:
			_restore_controls.append(node.set_physics_process.bind(node.is_physics_processing()))
			node.set_physics_process(false)
		if _is_field_interactable(node):
			_restore_controls.append(
				node.set_process_unhandled_input.bind(node.is_processing_unhandled_input())
			)
			node.set_process_unhandled_input(false)
	for node: Node in root.find_children("*", "TravelExit", true, false):
		var travel_exit := node as TravelExit
		if travel_exit != null:
			_restore_controls.append(travel_exit.set.bind("monitoring", travel_exit.monitoring))
			travel_exit.monitoring = false


func combat_mode_active() -> bool:
	return _combat_mode_active


func _is_field_interactable(node: Node) -> bool:
	return (
		node is Enemy
		or node is NPC
		or node is SMInteractable
		or node is TavernDoor
		or node is BuildingDoor
	)


func player() -> Player:
	return _field_root().find_child("Player", true, false) as Player


func party_followers() -> PartyFollowers:
	return _field_root().find_child("PartyFollowers", true, false) as PartyFollowers


## The party's live field cells in party order, player first. This is the input to
## `GridBattlefieldModel.resolve_placement()`; the player's cell is the anchor. Empty when the
## field has no player or no built grid, which the caller must treat as a refusal.
func party_cells() -> Array[Vector2i]:
	var cells: Array[Vector2i] = []
	var grid := iso_grid()
	var lead := player()
	if grid == null or lead == null:
		return cells
	cells.append(grid.world_to_cell(lead.global_position))
	var followers := party_followers()
	if followers == null:
		return cells
	for follower: PartyFollower in followers.followers():
		cells.append(grid.world_to_cell(follower.global_position))
	return cells


## Snaps the presentation party onto the cells combat actually seated them on (F0 ruling 4).
## Followers are presentation-only and CombatOverlay does not exist until migration step 6, so
## without this the visible party and the battlefield model disagree for a whole session.
## Entering combat mode first is what stops the trail from dragging them back off their cells.
func seat_party(cells: Array[Vector2i]) -> void:
	if cells.is_empty():
		return
	set_combat_mode(true)
	var grid := iso_grid()
	if grid == null:
		return
	var lead := player()
	if lead != null:
		# The anchor is never relocated; this only centres it on the cell it already holds.
		lead.global_position = grid.cell_to_world(cells[0])
	var followers := party_followers()
	if followers == null:
		return
	var seated := followers.followers()
	for index in seated.size():
		var cell_index := index + 1
		if cell_index >= cells.size():
			break
		seated[index].snap_to(grid.cell_to_world(cells[cell_index]))


func hostiles() -> Array[Hostile]:
	var result: Array[Hostile] = []
	for node: Node in _field_root().find_children("*", "Node2D", true, false):
		if node is Hostile:
			result.append(node)
	return result


## Called once at a combat clock boundary. Snapshot sources before emitting alerts:
## synchronous admission callbacks must not turn this pass into a recursive cascade.
func propagate_alerts() -> void:
	if no_combat_zone():
		return
	var actors := hostiles()
	_connect_hostiles()
	var sources: Array[Hostile] = []
	for hostile: Hostile in actors:
		if hostile.state == Hostile.State.IN_COMBAT:
			sources.append(hostile)
	for hostile: Hostile in actors:
		if hostile.state != Hostile.State.IDLE:
			continue
		for source: Hostile in sources:
			if source.global_position.distance_to(hostile.global_position) <= source.chain_radius:
				hostile.request_alert()
				break


## Hostiles may be authored in the scene or spawned later, and a field can be entered more than
## once, so this is idempotent and re-run whenever the set might have changed.
func _connect_hostiles() -> void:
	for hostile: Hostile in hostiles():
		if not hostile.alerted.is_connected(_on_hostile_alerted):
			hostile.alerted.connect(_on_hostile_alerted)


func _on_hostile_alerted(hostile: Hostile) -> void:
	hostile_alerted.emit(hostile)


## Location weather moves onto field data in migration step 8.
func weather_default() -> StringName:
	return &""


func no_combat_zone() -> bool:
	return _scene_path().begins_with("res://world/interiors/")


func _scene_path() -> String:
	return _field_root().scene_file_path


func _field_root() -> Node:
	var field_root: Node = self
	var cursor: Node = self
	while cursor != null:
		if not cursor.scene_file_path.is_empty():
			field_root = cursor
		cursor = cursor.get_parent()
	return field_root
