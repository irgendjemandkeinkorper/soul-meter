class_name VicoarInstructiveFailure
extends ClassResource
## Vicoar — Flamebinder: Instructive Failure. A fizzle banks a token; spending one guarantees a
## later cast.

const MAX_TOKENS := 3 # PROVISIONAL — B11 owns tuning.

var tokens: int = 0
var guaranteed_cast_armed: bool = false
## Second Casting (#285 slice 4, ruled 2026-10-26): spent once a fizzle was converted.
var second_casting_used: bool = false

## The live cap: MAX_TOKENS plus any picked `cap_delta` perk (Third Lesson, #285 slice 2).
func max_tokens() -> int:
	return MAX_TOKENS + perk_total("cap_delta")


## Spectacular Failure (#285 slice 3, ruled 2026-10-26): with a living ally within 2 cells,
## somebody saw it, and the fizzle banks one more token.
const WITNESS_RADIUS := 2


func on_fizzle(_resolution: Dictionary) -> void:
	if guaranteed_cast_armed:
		return
	var banked := 1
	if perk_total("witnessed_fizzle_bonus") > 0 and host != null and host.allies_within(owner_id, WITNESS_RADIUS) > 0:
		banked += perk_total("witnessed_fizzle_bonus")
	tokens = mini(tokens + banked, max_tokens())


func spend_token() -> bool:
	if tokens <= 0 or guaranteed_cast_armed:
		return false
	tokens -= 1
	guaranteed_cast_armed = true
	return true


## `data/combat/actions/22_spend_token.tres` is the button. A token is banked by
## a fizzle and spent to guarantee a later cast; the command only spends it.
func commands() -> Array[StringName]:
	return [&"spend_token"]


func query_command(action_id: StringName, target_id: StringName, payload: Dictionary = {}) -> Dictionary:
	var gate := super.query_command(action_id, target_id, payload)
	if not bool(gate.allowed):
		return gate
	if guaranteed_cast_armed:
		return command_refusal(&"class_resource_armed", "Your guaranteed cast is already armed.")
	if tokens <= 0:
		return command_refusal(&"class_resource_empty", "No Failure Tokens banked. A fizzled cast banks one.")
	return gate


func on_command(action_id: StringName, _target_id: StringName) -> void:
	if action_id != &"spend_token":
		return
	spend_token()


func on_cast_forecast(context: Dictionary) -> Dictionary:
	if not guaranteed_cast_armed:
		# Second Casting: with the tokens banked, a fizzle this cast converts after the fact.
		var cost := perk_total("second_casting")
		if cost > 0 and not second_casting_used and tokens >= cost:
			return {"second_casting": true}
		return {}
	# Seam v2: an armed token guarantees every cast magnitude, not only mastery magnitudes.
	return {"fizzle_percent_override": 0.0}


func on_action(event: CombatEvent) -> void:
	var settled: Dictionary = event.data.get("resolution", {}) as Dictionary
	if bool(settled.get("second_cast", false)) and not second_casting_used:
		second_casting_used = true
		tokens = maxi(tokens - perk_total("second_casting"), 0)
	if not guaranteed_cast_armed:
		return
	if int(event.data.get("verb", -1)) != CombatAction.Verb.CAST:
		return
	var resolution: Dictionary = event.data.get("resolution", {}) as Dictionary
	if resolution.is_empty():
		return
	if bool(resolution.get("fizzled", false)):
		tokens = mini(tokens + 1, max_tokens())
	guaranteed_cast_armed = false


func snapshot() -> Dictionary:
	return {
		"patron_id": String(patron_id),
		"label": "Failure Tokens",
		"value": tokens,
		"max": max_tokens(),
		"armed": guaranteed_cast_armed,
	}


func to_dict() -> Dictionary:
	var data: Dictionary = super.to_dict()
	data["tokens"] = tokens
	data["guaranteed_cast_armed"] = guaranteed_cast_armed
	data["second_casting_used"] = second_casting_used
	return data


## Carried Lesson (#285 slice 4): one banked token survives into the next battle.
func carry_out() -> Dictionary:
	var kept := mini(tokens, perk_total("carry_one_token"))
	return {"tokens": kept} if kept > 0 else {}


func receive_carry(carried: Dictionary) -> void:
	tokens = mini(tokens + maxi(int(carried.get("tokens", 0)), 0), max_tokens())


func from_dict(data: Dictionary) -> void:
	super.from_dict(data)
	tokens = clampi(int(data.get("tokens", 0)), 0, max_tokens())
	guaranteed_cast_armed = bool(data.get("guaranteed_cast_armed", false))
	second_casting_used = bool(data.get("second_casting_used", false))
