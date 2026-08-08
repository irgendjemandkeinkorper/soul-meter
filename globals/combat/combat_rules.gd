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

## FR-105a seam (architecture doc §1.5). Selects which BattlefieldModel
## `create_default()` builds. False keeps the zone model live; grid support
## (#137) flips this once Gate T passes. The flag is the only activation path —
## `create_default()` must not hardcode a concrete model path.
@export var use_grid_battlefield: bool = false

# ---- FR-102a charge time (amendment §2.1: CT values are balance data, never controller
# literals). The AP block above is retained deliberately — amendment §8.1 forbids removing AP
# compatibility in the same change that first makes CT authoritative. ----

## Charge gained per tick before per-actor variation. No `speed` attribute exists on BattleActor
## today, so speed derives from an authored attribute the same way AP derives from `edge`.
@export var base_charge_speed: int = 6
@export var charge_speed_attribute: StringName = &"edge"
@export var attribute_points_per_speed: int = 2
@export var minimum_charge_speed: int = 1
@export var maximum_charge_speed: int = 30

## Default CT costs. An action with `ct_cost < 0` has not been authored yet and falls back to
## `ap_cost * ct_per_ap` — a migration shim, not a permanent conversion. Author real values.
@export var ct_per_ap: int = 15
@export var move_ct_cost: int = 20
@export var minimum_action_ct_cost: int = 30
@export var maximum_action_ct_cost: int = 60
## Fraction of spent CT returned when a committed action is cancelled or a wait is refunded.
@export_range(0.0, 1.0) var cancel_refund_ratio: float = 1.0

## Selects which TurnScheduler `create_default()` builds, exactly as `use_grid_battlefield` does
## for the battlefield. False keeps the AP round economy authoritative.
##
## This flag IS the abort path amendment §8 requires: reverting charge time must be a flag flip,
## not a revert of a controller rewrite. That only holds while `ApRoundScheduler` stays behind the
## seam, which is why §8.1 forbids deleting AP compatibility in the same change that makes CT
## authoritative. Gate T criterion 10 retires both the flag and the AP scheduler together.
@export var use_charge_time: bool = false


func action_points_for(actor: BattleActor) -> int:
	var divisor := maxi(1, attribute_points_per_ap)
	var derived := base_action_points + actor.attribute_value(action_point_attribute) / divisor
	return clampi(
		actor.effective_max_action_points(derived), minimum_action_points, maximum_action_points
	)


## Charge gained per tick. Deterministic — no RNG anywhere in the CT path, which is what makes
## replay and the forecast the same code path.
func charge_speed_for(actor: BattleActor) -> int:
	var divisor := maxi(1, attribute_points_per_speed)
	var derived := base_charge_speed + actor.attribute_value(charge_speed_attribute) / divisor
	return clampi(derived, maximum_of(minimum_charge_speed, 1), maximum_charge_speed)


## CT cost of an action. Movement is priced separately from action verbs, per FR-102a.
func charge_cost_for(action: CombatAction) -> int:
	if action == null:
		return minimum_action_ct_cost
	if action.ct_cost >= 0:
		return action.ct_cost
	if action.verb == CombatAction.Verb.MOVE:
		return move_ct_cost
	var converted := action.ap_cost * maxi(1, ct_per_ap)
	return clampi(converted, minimum_action_ct_cost, maximum_action_ct_cost)


static func maximum_of(value: int, floor_value: int) -> int:
	return maxi(value, floor_value)
