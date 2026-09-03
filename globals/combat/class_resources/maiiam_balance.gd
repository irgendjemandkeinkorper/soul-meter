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
	unbalanced = side_streak >= UNBALANCED_AFTER_STREAK


func on_cast_forecast(context: Dictionary) -> Dictionary:
	if not unbalanced:
		return {}
	var unit: Dictionary = (context.get("unit", {}) as Dictionary).duplicate(true)
	var fizzle: Dictionary = (context.get("fizzle", {}) as Dictionary).duplicate(true)
	unit["attack_scale"] = UNBALANCED_DAMAGE_MULTIPLIER
	fizzle["agreement_integrity"] = maxf(
		float(fizzle.get("agreement_integrity", 100.0))
		- UNBALANCED_FIZZLE_INTEGRITY_PENALTY,
		0.0,
	)
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
	return data


func from_dict(data: Dictionary) -> void:
	super.from_dict(data)
	last_side = StringName(str(data.get("last_side", "")))
	side_streak = maxi(int(data.get("side_streak", 0)), 0)
	unbalanced = bool(data.get("unbalanced", false))
