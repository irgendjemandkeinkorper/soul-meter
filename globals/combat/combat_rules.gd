class_name CombatRules
extends Resource
## TUNABLE Phase 2 starting values. Keeping AP derivation and positional
## modifiers in authored data lets playtesting move numbers without resolver edits.

@export var base_action_points: int = 4
@export var action_point_attribute: StringName = &"edge"
@export var attribute_points_per_ap: int = 2
@export var minimum_action_points: int = 2
@export var maximum_action_points: int = 8
@export var context_resolution_ap_cost: int = 2
@export var cover_defense_bonus: int = 2
@export var flank_power_bonus: int = 2


func action_points_for(actor: BattleActor) -> int:
	var divisor := maxi(1, attribute_points_per_ap)
	var derived := base_action_points + actor.attribute_value(action_point_attribute) / divisor
	return clampi(
		actor.effective_max_action_points(derived), minimum_action_points, maximum_action_points
	)
