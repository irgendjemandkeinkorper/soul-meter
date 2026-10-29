class_name MaiiamBalance
extends ClassResource
## Maiiam — Mirrorblade: Balance. Alternating strike/guard stays Balanced; spamming one side
## becomes Unbalanced with stronger hits and rising fizzle.

const UNBALANCED_AFTER_STREAK := 2 # B11, ratified 2026-10-25 (owner item 6).
const UNBALANCED_DAMAGE_MULTIPLIER := 1.25 # B11, ratified 2026-10-25 (owner item 6).
const UNBALANCED_FIZZLE_INTEGRITY_PENALTY := 15.0 # B11, ratified 2026-10-25 (owner item 6).

var last_side: StringName = &""
var side_streak: int = 0
var unbalanced: bool = false
## Second Footing (#285 slice 2, ruled 2026-10-26): spent once it forgives a repeat this battle.
var footing_spent: bool = false


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
	return data


func from_dict(data: Dictionary) -> void:
	super.from_dict(data)
	last_side = StringName(str(data.get("last_side", "")))
	side_streak = maxi(int(data.get("side_streak", 0)), 0)
	unbalanced = bool(data.get("unbalanced", false))
	footing_spent = bool(data.get("footing_spent", false))
