class_name FickahRuleBreaker
extends ClassResource
## Locksmirk — Fickah: the rule-breaker. Jam request plus the patron's fizzle floor.
##
## `SkillCheckService.fizzle_percent()` already applies Fickah's PROVISIONAL 5% floor from
## the patron id in the forecast context. Jam execution needs a scheduler cancellation hook
## that the B0 seam does not expose, so this resource records the pending request only.

const FIZZLE_FLOOR_PERCENT := 5.0  # PROVISIONAL — B11 owns the floor

var jam_target_id: StringName = &""


func jam_the_gears(target_id: StringName) -> bool:
	if target_id.is_empty() or not jam_target_id.is_empty():
		return false
	jam_target_id = target_id
	return true


func on_action(event: CombatEvent) -> void:
	if jam_target_id.is_empty() or event.actor_id != owner_id:
		return
	var cancelled_action: Variant = event.data.get("cancelled_action", null)
	if cancelled_action != null and StringName(str(cancelled_action)) == jam_target_id:
		jam_target_id = &""


func snapshot() -> Dictionary:
	return {
		"patron_id": String(patron_id),
		"label": "Jam",
		"value": "ARMED" if not jam_target_id.is_empty() else "READY",
		"fizzle_floor": FIZZLE_FLOOR_PERCENT,
		"target_id": String(jam_target_id),
	}


func to_dict() -> Dictionary:
	var data: Dictionary = super.to_dict()
	data["jam_target_id"] = String(jam_target_id)
	return data


func from_dict(data: Dictionary) -> void:
	super.from_dict(data)
	jam_target_id = StringName(str(data.get("jam_target_id", "")))
