class_name VicoarInstructiveFailure
extends ClassResource
## Vicoar — Flamebinder: Instructive Failure. A fizzle banks a token; spending one guarantees a
## later cast.

const MAX_TOKENS := 3 # PROVISIONAL — B11 owns tuning.

var tokens: int = 0
var guaranteed_cast_armed: bool = false

func on_fizzle(_resolution: Dictionary) -> void:
	if guaranteed_cast_armed:
		return
	tokens = mini(tokens + 1, MAX_TOKENS)


func spend_token() -> bool:
	if tokens <= 0 or guaranteed_cast_armed:
		return false
	tokens -= 1
	guaranteed_cast_armed = true
	return true


func on_cast_forecast(context: Dictionary) -> Dictionary:
	if not guaranteed_cast_armed:
		return {}
	# Seam v2: an armed token guarantees every cast magnitude, not only mastery magnitudes.
	return {"fizzle_percent_override": 0.0}


func on_action(event: CombatEvent) -> void:
	if not guaranteed_cast_armed:
		return
	if int(event.data.get("verb", -1)) != CombatAction.Verb.CAST:
		return
	var resolution: Dictionary = event.data.get("resolution", {}) as Dictionary
	if resolution.is_empty():
		return
	if bool(resolution.get("fizzled", false)):
		tokens = mini(tokens + 1, MAX_TOKENS)
	guaranteed_cast_armed = false


func snapshot() -> Dictionary:
	return {
		"patron_id": String(patron_id),
		"label": "Failure Tokens",
		"value": tokens,
		"max": MAX_TOKENS,
		"armed": guaranteed_cast_armed,
	}


func to_dict() -> Dictionary:
	var data: Dictionary = super.to_dict()
	data["tokens"] = tokens
	data["guaranteed_cast_armed"] = guaranteed_cast_armed
	return data


func from_dict(data: Dictionary) -> void:
	super.from_dict(data)
	tokens = clampi(int(data.get("tokens", 0)), 0, MAX_TOKENS)
	guaranteed_cast_armed = bool(data.get("guaranteed_cast_armed", false))
