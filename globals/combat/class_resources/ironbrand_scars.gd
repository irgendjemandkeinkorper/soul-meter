class_name IronbrandScars
extends ClassResource
## Kero — Ironbrand: **Scars**. The worked example for the B-wave (#223 → #226 completes it).
##
## Vault `systems/magic-system.md` §Per-class resources: "Taking (or self-inflicting) damage
## banks Scars; spend them for guaranteed-hit / guaranteed-crit windows."
##
## Mechanics here: every HP loss banks one Scar (cap `MAX_SCARS`, PROVISIONAL — B11 owns the
## number). `spend_scar()` arms a guaranteed-hit window; `on_cast_forecast()` expresses it as
## `{"to_hit_enabled": false}` — Resolution's existing "no to-hit roll" channel — so the forecast
## and the commit both see a certain hit. The window is consumed by the owner's next resolved
## action (`on_action`), never by a forecast. Guaranteed-crit is #226's job (no crit channel
## exists in Resolution yet; do not invent one here).

const MAX_SCARS := 5  # PROVISIONAL — B11 numeric pass

var scars: int = 0
var guaranteed_hit_armed: bool = false


func on_damage_taken(amount: int, _source_id: StringName) -> void:
	if amount <= 0:
		return
	scars = mini(scars + 1, MAX_SCARS)


## Arms a guaranteed hit for the owner's next resolved action. Returns false when no Scar is
## banked or a window is already armed (spending twice would waste a Scar).
func spend_scar() -> bool:
	if scars <= 0 or guaranteed_hit_armed:
		return false
	scars -= 1
	guaranteed_hit_armed = true
	return true


func on_cast_forecast(_context: Dictionary) -> Dictionary:
	if guaranteed_hit_armed:
		return {"to_hit_enabled": false}
	return {}


func on_action(event: CombatEvent) -> void:
	# Only an action that actually resolved an attack/cast consumes the window; a move or a
	# guard leaves it armed for the strike that follows.
	if not guaranteed_hit_armed:
		return
	var data: Dictionary = event.data
	if data.has("resolution") and not (data.get("resolution", {}) as Dictionary).is_empty():
		guaranteed_hit_armed = false


func snapshot() -> Dictionary:
	return {
		"patron_id": String(patron_id),
		"label": "Scars",
		"value": scars,
		"max": MAX_SCARS,
		"armed": guaranteed_hit_armed,
	}


func to_dict() -> Dictionary:
	var data := super.to_dict()
	data["scars"] = scars
	data["guaranteed_hit_armed"] = guaranteed_hit_armed
	return data


func from_dict(data: Dictionary) -> void:
	super.from_dict(data)
	scars = clampi(int(data.get("scars", 0)), 0, MAX_SCARS)
	guaranteed_hit_armed = bool(data.get("guaranteed_hit_armed", false))
