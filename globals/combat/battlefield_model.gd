class_name BattlefieldModel
extends RefCounted
## Positioning interface consumed by CombatController. Action resolution only
## speaks these opaque position/profile/shape APIs, so a grid can replace zones.


static func create_default(rules: CombatRules) -> BattlefieldModel:
	var script := load("res://globals/combat/zone_battlefield_model.gd") as Script
	var model := script.new() as BattlefieldModel
	model.configure(rules)
	return model


func configure(_rules: CombatRules) -> void:
	pass


func setup(_allies: Array[BattleActor], _enemies: Array[BattleActor]) -> void:
	push_error("BattlefieldModel.setup() must be implemented.")


func position_of(_actor: BattleActor) -> StringName:
	return &""


func side_of(_actor: BattleActor) -> StringName:
	return &""


func move(_actor: BattleActor, _destination: StringName) -> Dictionary:
	return _blocked(&"position", "Positioning model does not support movement.", {})


func move_query(_actor: BattleActor, _destination: StringName) -> Dictionary:
	return _blocked(&"position", "Positioning model does not support movement.", {})


func target_query(
	_actor: BattleActor, _target: BattleActor, _profile: StringName
) -> Dictionary:
	return _blocked(&"target", "Positioning model does not support targeting.", {})


func cover_bonus(_actor: BattleActor, _target: BattleActor) -> int:
	return 0


func flank_bonus(_actor: BattleActor, _target: BattleActor) -> int:
	return 0


func targets_for(
	_actor: BattleActor, _primary: BattleActor, _shape: StringName
) -> Array[BattleActor]:
	return []


static func _allowed(extra: Dictionary = {}) -> Dictionary:
	var result := {
		"allowed": true,
		"blocked_by": &"",
		"nearest_unblock": {},
		"message": "",
	}
	result.merge(extra, true)
	return result


static func _blocked(
	blocked_by: StringName, message: String, nearest_unblock: Dictionary
) -> Dictionary:
	return {
		"allowed": false,
		"blocked_by": blocked_by,
		"nearest_unblock": nearest_unblock.duplicate(true),
		"message": message,
	}
