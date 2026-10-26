class_name MaiiamBalance
extends ClassResource
## Maiiam — Mirrorblade: Balance. Alternating strike/guard stays Balanced; spamming one side
## becomes Unbalanced with stronger hits and rising fizzle.

const UNBALANCED_AFTER_STREAK := 2 # PROVISIONAL — B11 owns tuning.
const UNBALANCED_DAMAGE_MULTIPLIER := 1.25 # PROVISIONAL — B11 owns tuning.
const UNBALANCED_FIZZLE_INTEGRITY_PENALTY := 15.0 # PROVISIONAL — B11 owns tuning.

var last_side: StringName = &""
var side_streak: int = 0
var unbalanced: bool = false
## Second Footing (#285 slice 2, ruled 2026-10-26): spent once it forgives a repeat this battle.
var footing_spent: bool = false
## Even Hand (#285 slice 3, ruled 2026-10-26): spent by the first fizzle this battle.
var even_hand_spent: bool = false
## Known Edge (#285 slice 3): spent once an enemy has acted against the Mirrorblade.
var known_edge_spent: bool = false
## Reflection (#285 slice 4, ruled 2026-10-26): armed by the command, spent by the next enemy
## attack against her. Once per battle.
var reflection_armed: bool = false
var reflection_used: bool = false


func commands() -> Array[StringName]:
	return [&"reflection"]


func query_command(action_id: StringName, target_id: StringName, payload: Dictionary = {}) -> Dictionary:
	var gate := super.query_command(action_id, target_id, payload)
	if not bool(gate.allowed):
		return gate
	var missing := perk_refusal("reflect_next_attack", "Reflection")
	if not missing.is_empty():
		return missing
	if reflection_armed:
		return command_refusal(&"class_resource_armed", "Reflection is already raised.")
	if reflection_used:
		return command_refusal(&"class_resource_spent", "Reflection is spent for this battle.")
	return gate


func on_command(action_id: StringName, _target_id: StringName) -> void:
	if action_id == &"reflection" and perk_total("reflect_next_attack") > 0 and not reflection_used:
		reflection_armed = true


## The armed Reflection keeps `100 - reflect_next_attack` percent of an enemy's hit and sends
## the rest back to the attacker (a deferred write, through the controller's one write path).
func adjust_incoming_hp(actor_id: StringName, target_id: StringName, before: int, after: int) -> int:
	if not reflection_armed or target_id != owner_id or host == null:
		return after
	var attacker := host.actor_by_id(actor_id)
	if attacker == null or not host.enemies.has(attacker):
		return after
	var loss := before - after
	var reflected := loss * perk_total("reflect_next_attack") / 100
	reflection_armed = false
	reflection_used = true
	if reflected <= 0:
		return after
	enqueue_deferred(
		{"writes": [{"kind": "hp", "target_id": String(actor_id), "amount": reflected}]},
		{"delay_rounds": 0},
		&"reflection",
	)
	return after + reflected


func on_action(event: CombatEvent) -> void:
	var action_id: StringName = StringName(str(event.data.get("action_id", "")))
	var side: StringName = action_id if action_id in [&"strike", &"guard"] else &""
	if side == &"":
		return
	if side == last_side:
		side_streak += 1
	else:
		last_side = side
		side_streak = 1
	# Second Footing: the repeat that would unbalance is forgiven once; the streak steps back
	# so the NEXT same-side action unbalances as usual.
	if (
		side_streak == UNBALANCED_AFTER_STREAK and not footing_spent
		and perk_total("forgive_streak_once") > 0
	):
		footing_spent = true
		side_streak -= 1
	unbalanced = side_streak >= UNBALANCED_AFTER_STREAK


## Even Hand: the first fizzle each battle returns the Mirrorblade to Balance.
func on_fizzle(_resolution: Dictionary) -> void:
	if even_hand_spent or perk_total("fizzle_rebalances_once") <= 0:
		return
	even_hand_spent = true
	last_side = &""
	side_streak = 0
	unbalanced = false


## Known Edge: the first enemy to act against the Mirrorblade each battle has heard of her,
## and its next turn comes `delay_first_attacker` CT late.
func on_any_action(
	actor_id: StringName, _action_id: StringName, target_id: StringName, _outcome: Dictionary
) -> void:
	if known_edge_spent or target_id != owner_id or host == null:
		return
	if perk_total("delay_first_attacker") <= 0:
		return
	var actor := host.actor_by_id(actor_id)
	if actor == null or not host.enemies.has(actor):
		return
	known_edge_spent = true
	host.delay_actor(actor_id, perk_total("delay_first_attacker"))


func on_cast_forecast(context: Dictionary) -> Dictionary:
	if not unbalanced:
		return {}
	var unit: Dictionary = (context.get("unit", {}) as Dictionary).duplicate(true)
	var fizzle: Dictionary = (context.get("fizzle", {}) as Dictionary).duplicate(true)
	unit["attack_scale"] = UNBALANCED_DAMAGE_MULTIPLIER
	var accord := maxf(
		float(fizzle.get("harmonic_accord", fizzle.get("agreement_integrity", 100.0)))
		- UNBALANCED_FIZZLE_INTEGRITY_PENALTY,
		0.0,
	)
	fizzle["harmonic_accord"] = accord
	fizzle["agreement_integrity"] = accord # alias wave, #329
	return {
		"unit": unit,
		"fizzle": fizzle,
	}


func snapshot() -> Dictionary:
	return {
		"patron_id": String(patron_id),
		"label": "Balance",
		"value": "Unbalanced" if unbalanced else "Balanced",
		"side": String(last_side),
		"streak": side_streak,
	}


func to_dict() -> Dictionary:
	var data: Dictionary = super.to_dict()
	data["last_side"] = String(last_side)
	data["side_streak"] = side_streak
	data["unbalanced"] = unbalanced
	data["footing_spent"] = footing_spent
	data["even_hand_spent"] = even_hand_spent
	data["known_edge_spent"] = known_edge_spent
	data["reflection_armed"] = reflection_armed
	data["reflection_used"] = reflection_used
	return data


func from_dict(data: Dictionary) -> void:
	super.from_dict(data)
	last_side = StringName(str(data.get("last_side", "")))
	side_streak = maxi(int(data.get("side_streak", 0)), 0)
	unbalanced = bool(data.get("unbalanced", false))
	footing_spent = bool(data.get("footing_spent", false))
	even_hand_spent = bool(data.get("even_hand_spent", false))
	known_edge_spent = bool(data.get("known_edge_spent", false))
	reflection_armed = bool(data.get("reflection_armed", false))
	reflection_used = bool(data.get("reflection_used", false))
