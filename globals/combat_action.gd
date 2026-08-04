class_name CombatAction
extends Resource
## Data carried by the combat engine. GodotGAS can implement the effects
## behind this seam later without making battle flow depend on that addon.

enum Kind { ATTACK, GUARD, STABILIZE, RESOLUTION, MOVE, PASS, DEFINING_STRIKE }
enum Verb { MOVE, ATTACK, CAST, ITEM, SPEECH, DEFEND }

@export var id: StringName
@export var display_name: String
@export var kind: Kind = Kind.ATTACK
@export var verb: Verb = Verb.ATTACK
@export_range(0, 20) var ap_cost: int = 1
@export var power_bonus: int = 0
## Negative pushes Chaos; positive pushes Order.
@export_range(-100, 100) var balance_shift: int = 0
@export var soul_cost: float = 0.0
@export var outcome_id: StringName = &""
@export var minimum_enemy_rounds: int = 0
@export_range(-100, 100) var minimum_balance: int = -100
@export_range(-100, 100) var maximum_balance: int = 100
@export var lock_reason: String = ""
## Opaque positioning vocabulary interpreted only by BattlefieldModel.
@export var target_profile: StringName = &"melee"
@export var aoe_shape: StringName = &"single"
@export var destination: StringName = &""
@export_range(0, 100) var center_pull: int = 10
@export var player_available: bool = true


static func make(
	action_id: StringName,
	name: String,
	action_kind: Kind,
	power: int = 0,
	shift: int = 0,
	cost: float = 0.0,
	action_point_cost: int = 1
) -> CombatAction:
	var action := CombatAction.new()
	action.id = action_id
	action.display_name = name
	action.kind = action_kind
	action.power_bonus = power
	action.balance_shift = shift
	action.soul_cost = cost
	action.ap_cost = action_point_cost
	match action_kind:
		Kind.GUARD, Kind.STABILIZE:
			action.verb = Verb.DEFEND
			action.target_profile = &"self"
		Kind.RESOLUTION:
			action.verb = Verb.SPEECH
			action.target_profile = &"encounter"
		Kind.MOVE:
			action.verb = Verb.MOVE
			action.target_profile = &"self"
	return action


static func from_context_row(row: Dictionary) -> CombatAction:
	var action := CombatAction.new()
	action.id = StringName(row.get("id", ""))
	action.display_name = str(row.get("display_name", action.id))
	action.kind = Kind.RESOLUTION
	action.verb = Verb.SPEECH
	action.target_profile = &"encounter"
	action.ap_cost = int(row.get("ap_cost", 0))
	action.soul_cost = float(row.get("soul_cost", 0.0))
	action.outcome_id = StringName(row.get("outcome_id", ""))
	action.minimum_enemy_rounds = int(row.get("minimum_enemy_rounds", 0))
	action.minimum_balance = int(row.get("minimum_balance", -100))
	action.maximum_balance = int(row.get("maximum_balance", 100))
	action.lock_reason = str(row.get("lock_reason", "Requirements not met."))
	return action


func summary() -> String:
	var target := "Enemy target"
	var effect := balance_effect_summary()
	match kind:
		Kind.DEFINING_STRIKE:
			target = "Named weakness"
			effect = "Lore/Insight check applies a targeted effect"
		Kind.GUARD:
			target = "Self"
			effect = "Reduces the next hit"
		Kind.STABILIZE:
			target = "Self"
			effect = "Pulls Balance 30 toward Equilibrium"
		Kind.RESOLUTION:
			target = "Encounter"
			effect = "Ends the encounter"
		Kind.PASS:
			if verb == Verb.SPEECH:
				target = "Encounter"
				effect = "Opens combat dialogue"
	var costs: Array[String] = ["%d AP" % ap_cost]
	if not is_zero_approx(soul_cost):
		costs.append("%d Soul" % int(soul_cost))
	return "%s · %s · %s" % [target, effect, " + ".join(costs)]


func balance_effect_summary() -> String:
	if balance_shift > 0:
		return "+%d Order" % balance_shift
	if balance_shift < 0:
		return "%d Chaos" % balance_shift
	return "Pulls Balance 10 toward Equilibrium"


func requires_enemy_target() -> bool:
	return kind in [Kind.ATTACK, Kind.DEFINING_STRIKE]
