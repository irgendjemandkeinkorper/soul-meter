class_name InteractionFocus
extends RefCounted
## One interact key, many targets. A building door, a sign or ledger, and a townsperson can all
## have the player in range at once; before this, whichever node came last in the tree took the
## key, so Dom's townsfolk and signs answered E on five building thresholds and the door never
## did (#665). The rule:
##
## 1. A THRESHOLD target (a building or tavern door) outranks every WORLD target (signs, chests,
##    townsfolk). Door ranges are small, so inside one E enters; one step out, E talks or reads.
## 2. Among the highest-ranked targets in range, the one nearest the player takes the key.
##
## Each target reports its range with `set_in_range()` and asks `takes_interact()` before handling
## the key. A target that does not take it leaves the event unhandled, so it reaches the one that
## does. Prompts of outranked targets hide (`is_outranked()`), refreshed through the
## `interaction_focus_targets` group's `_on_interaction_focus_changed()`.

enum Tier { WORLD = 0, THRESHOLD = 1 }

const GROUP := &"interaction_focus_targets"

## target (Node2D) -> Tier, for every target the player is currently inside the range of.
static var _in_range: Dictionary = {}
static var _player: Node2D = null


static func set_in_range(target: Node2D, player: Node2D, entered: bool, tier: Tier) -> void:
	if entered:
		_in_range[target] = tier
		_player = player
	else:
		_in_range.erase(target)
	_prune()
	if target.is_inside_tree():
		target.get_tree().call_group(GROUP, &"_on_interaction_focus_changed")


## True when `target` should handle the interact key now.
static func takes_interact(target: Node2D) -> bool:
	_prune()
	if not _in_range.has(target):
		# A target that never registered (an older scene, a test double) keeps its own handling.
		return true
	return _focused() == target


## True when a higher-ranked target also has the player in range (hide this target's prompt).
static func is_outranked(target: Node2D) -> bool:
	_prune()
	if not _in_range.has(target):
		return false
	return int(_in_range[target]) < _top_tier()


static func _focused() -> Node2D:
	var top := _top_tier()
	var best: Node2D = null
	var best_distance := INF
	for target: Node2D in _in_range:
		if int(_in_range[target]) != top:
			continue
		var distance := (
			target.global_position.distance_squared_to(_player.global_position)
			if is_instance_valid(_player) else 0.0
		)
		if best == null or distance < best_distance:
			best = target
			best_distance = distance
	return best


static func _top_tier() -> int:
	var top := -1
	for tier: Variant in _in_range.values():
		top = maxi(top, int(tier))
	return top


## Freed targets and targets in a scene that has left the tree drop out.
static func _prune() -> void:
	for target: Variant in _in_range.keys():
		if not is_instance_valid(target) or not (target as Node2D).is_inside_tree():
			_in_range.erase(target)
