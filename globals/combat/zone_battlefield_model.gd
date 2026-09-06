extends BattlefieldModel
## FR-105 zone implementation. No consumer names this concrete type; creation
## and all queries go through BattlefieldModel.

const FRONT := &"front"
const BACK := &"back"
const FLANK := &"flank"
const ALLY := &"ally"
const ENEMY := &"enemy"
const VALID_POSITIONS: Array[StringName] = [FRONT, BACK, FLANK]

var _positions: Dictionary = {}
var _sides: Dictionary = {}
var _groups: Dictionary = {ALLY: [], ENEMY: []}
var _cover_bonus := 2
var _flank_bonus := 2


func configure(rules: CombatRules) -> void:
	_cover_bonus = rules.cover_defense_bonus
	_flank_bonus = rules.flank_power_bonus


func setup(allies: Array[BattleActor], enemies: Array[BattleActor]) -> void:
	_positions.clear()
	_sides.clear()
	_groups = {ALLY: allies.duplicate(), ENEMY: enemies.duplicate()}
	for actor in allies:
		_register(actor, ALLY, FRONT)
	for actor in enemies:
		_register(actor, ENEMY, FRONT)


func position_of(actor: BattleActor) -> StringName:
	return StringName(_positions.get(actor.get_instance_id(), &""))


func side_of(actor: BattleActor) -> StringName:
	if actor == null:
		return &""
	return StringName(_sides.get(actor.get_instance_id(), &""))


func has_combatant(actor: BattleActor) -> bool:
	return actor != null and _sides.has(actor.get_instance_id())


func combatants_on_side(side: StringName) -> Array[BattleActor]:
	var result: Array[BattleActor] = []
	for actor: BattleActor in _groups.get(side, []):
		result.append(actor)
	return result


## Seats one combatant mid-battle. The zone model has no cells, so `position` is a zone name
## and an unrecognised one lands the newcomer in FRONT rather than refusing — zones are a
## coarse fallback (FR-105) and refusing here would strand an alerted mob outside the fight.
func admit_combatant(actor: BattleActor, position: StringName, side: StringName) -> Dictionary:
	if actor == null:
		return _blocked(
			&"composition", "There is no combatant to admit.", {"type": &"present_combatant"}
		)
	if has_combatant(actor):
		return _blocked(
			&"composition", "Combatant is already on the battlefield.", {"type": &"absent_combatant"}
		)
	if not _groups.has(side):
		return _blocked(
			&"composition", "Unknown battlefield side: %s." % side, {"type": &"known_side"}
		)
	var zone := position if VALID_POSITIONS.has(position) else FRONT
	var group: Array = _groups.get(side, [])
	group.append(actor)
	_register(actor, side, zone)
	return _allowed({"to_side": side, "to_position": position_of(actor)})


func remove_combatant(actor: BattleActor) -> Dictionary:
	if not has_combatant(actor):
		return _blocked(
			&"composition", "Combatant is not on the battlefield.", {"type": &"present_combatant"}
		)
	var previous_side := side_of(actor)
	var previous_position := position_of(actor)
	var group: Array = _groups.get(previous_side, [])
	group.erase(actor)
	_sides.erase(actor.get_instance_id())
	_positions.erase(actor.get_instance_id())
	return _allowed({"from_side": previous_side, "from_position": previous_position})


func transfer_combatant(actor: BattleActor, new_side: StringName) -> Dictionary:
	if not has_combatant(actor):
		return _blocked(
			&"composition", "Combatant is not on the battlefield.", {"type": &"present_combatant"}
		)
	if not _groups.has(new_side):
		return _blocked(
			&"composition", "Unknown battlefield side: %s." % new_side, {"type": &"known_side"}
		)
	var previous_side := side_of(actor)
	if previous_side == new_side:
		return _blocked(
			&"composition", "Combatant is already on that side.", {"type": &"different_side"}
		)
	var previous_group: Array = _groups.get(previous_side, [])
	previous_group.erase(actor)
	var new_group: Array = _groups.get(new_side, [])
	new_group.append(actor)
	_sides[actor.get_instance_id()] = new_side
	return _allowed({"from_side": previous_side, "to_side": new_side})


func move(actor: BattleActor, destination: StringName) -> Dictionary:
	var query := move_query(actor, destination)
	if not bool(query.get("allowed", false)):
		return query
	var previous := position_of(actor)
	_positions[actor.get_instance_id()] = destination
	return _allowed({"from": previous, "to": destination})


func move_query(actor: BattleActor, destination: StringName) -> Dictionary:
	if not VALID_POSITIONS.has(destination):
		return _blocked(
			&"position",
			"Unknown battlefield position: %s." % destination,
			{"type": &"position", "valid": VALID_POSITIONS.duplicate()},
		)
	if position_of(actor) == destination:
		return _blocked(
			&"position",
			"Combatant is already in %s." % destination,
			{"type": &"different_position"},
		)
	return _allowed({"from": position_of(actor), "to": destination})


func target_query(actor: BattleActor, target: BattleActor, profile: StringName) -> Dictionary:
	if not has_combatant(actor):
		return _blocked(&"target", "Acting combatant is not on the battlefield.", {"type": &"present_actor"})
	if not has_combatant(target) or not target.is_alive():
		return _blocked(&"target", "Target is not available.", {"type": &"living_target"})
	if profile == &"self":
		return _allowed() if actor == target else _blocked(
			&"target", "This action targets only its user.", {"type": &"self"}
		)
	if side_of(actor) == side_of(target):
		return _blocked(&"target", "This action requires an opposing target.", {"type": &"enemy"})
	if profile == &"encounter" or profile == &"ranged" or profile == &"any_enemy":
		return _allowed()
	if profile == &"melee":
		if position_of(actor) == BACK:
			return _blocked(
				&"position",
				"Move out of the back position to make a melee attack.",
				{"type": &"position", "one_of": [FRONT, FLANK]},
			)
		if position_of(target) == BACK and _has_living_front(side_of(target), target):
			return _blocked(
				&"cover",
				"A living front position protects that back-line target.",
				{"type": &"remove_front_cover"},
			)
		return _allowed()
	return _blocked(
		&"target_profile",
		"Unknown targeting profile: %s." % profile,
		{"type": &"target_profile"},
	)


func cover_bonus(_actor: BattleActor, target: BattleActor) -> int:
	if position_of(target) == BACK and _has_living_front(side_of(target), target):
		return _cover_bonus
	return 0


func flank_bonus(actor: BattleActor, target: BattleActor) -> int:
	if position_of(actor) == FLANK and position_of(target) != FLANK:
		return _flank_bonus
	return 0


func targets_for(
	actor: BattleActor, primary: BattleActor, shape: StringName
) -> Array[BattleActor]:
	var result: Array[BattleActor] = []
	if primary == null:
		return result
	if shape == &"single":
		if primary.is_alive():
			result.append(primary)
		return result
	for candidate: BattleActor in _groups.get(side_of(primary), []):
		if not candidate.is_alive():
			continue
		if shape == &"side" or (shape == &"position" and position_of(candidate) == position_of(primary)):
			result.append(candidate)
	if shape != &"side" and shape != &"position":
		var query := target_query(actor, primary, &"any_enemy")
		if bool(query.get("allowed", false)):
			result.append(primary)
	return result


func _register(actor: BattleActor, side: StringName, position: StringName) -> void:
	_sides[actor.get_instance_id()] = side
	_positions[actor.get_instance_id()] = position


func _has_living_front(side: StringName, excluded: BattleActor) -> bool:
	for actor: BattleActor in _groups.get(side, []):
		if actor != excluded and actor.is_alive() and position_of(actor) == FRONT:
			return true
	return false
