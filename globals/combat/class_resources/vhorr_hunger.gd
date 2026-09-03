class_name VhorrHunger
extends ClassResource
## Vhorr — Husk-bearer: Hunger. Active DoT ticks stack Hunger; a kill from the owner's DoT
## refunds Soul Gauge.
## INERT until seam v2 emits `dot` writes and &"dot" kill cause.

const MAX_HUNGER := 5 # PROVISIONAL — B11 owns tuning.
const SOUL_REFUND := 1.0 # PROVISIONAL — B11 owns tuning.

var hunger: int = 0
var pending_soul_refunds: float = 0.0


func on_action(event: CombatEvent) -> void:
	# Forward-compatible with B4's requested DoT write. Resolution currently emits no `dot` write.
	var resolution: Dictionary = event.data.get("resolution", {}) as Dictionary
	for write_value: Variant in resolution.get("writes", []):
		if write_value is Dictionary and StringName(str((write_value as Dictionary).get("kind", ""))) == &"dot":
			hunger = mini(hunger + 1, MAX_HUNGER)


func on_kill(_target_id: StringName, cause: StringName) -> void:
	if cause == &"dot":
		pending_soul_refunds += SOUL_REFUND


func snapshot() -> Dictionary:
	return {
		"patron_id": String(patron_id),
		"label": "Hunger",
		"value": hunger,
		"max": MAX_HUNGER,
		"hidden_on_plate": true,
		"pending_soul_refunds": pending_soul_refunds,
	}


func to_dict() -> Dictionary:
	var data: Dictionary = super.to_dict()
	data["hunger"] = hunger
	data["pending_soul_refunds"] = pending_soul_refunds
	return data


func from_dict(data: Dictionary) -> void:
	super.from_dict(data)
	hunger = clampi(int(data.get("hunger", 0)), 0, MAX_HUNGER)
	pending_soul_refunds = maxf(float(data.get("pending_soul_refunds", 0.0)), 0.0)
