class_name FieldMap
extends Node2D
## Stable field-scene seam shared by navigation and same-map combat.

var _combat_mode_active: bool = false


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
		player.set_physics_process(not active)
		var controller := (
			player.find_child("ClickMoveController", true, false) as ClickMoveController
		)
		if controller != null:
			controller.cancel_path()
			controller.enabled = not active
	# Interact prompts (E) used to hide behind the paused tree. The field stays live during
	# combat now, so every interactable's unhandled input is switched off instead.
	for node: Node in root.find_children("*", "", true, false):
		if _is_field_interactable(node):
			node.set_process_unhandled_input(not active)
	for node: Node in root.find_children("*", "TravelExit", true, false):
		var travel_exit := node as TravelExit
		if travel_exit != null:
			travel_exit.monitoring = not active


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


## Hostile replaces Enemy in migration step 4; this group seam stays empty until then.
func hostiles() -> Array[Node2D]:
	var result: Array[Node2D] = []
	for node: Node in _field_root().find_children("*", "Node2D", true, false):
		if node.is_in_group(&"hostile"):
			result.append(node)
	return result


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
