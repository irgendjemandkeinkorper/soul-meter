class_name FickahRuleBreaker
extends ClassResource
## Locksmirk — Fickah: the rule-breaker. Retryable Jam plus the patron's fizzle floor.
##
## `SkillCheckService.fizzle_percent()` already applies Fickah's PROVISIONAL 5% floor from
## the patron id in the forecast context. A refused Jam is retried when this owner next turns.

const FIZZLE_FLOOR_PERCENT := SkillCheckService.FIZZLE_FLOOR_PERCENT

var jam_target_id: StringName = &""


func commands() -> Array[StringName]:
	return [&"jam_the_gears"]


func query_command(action_id: StringName, target_id: StringName, payload: Dictionary = {}) -> Dictionary:
	var gate := super.query_command(action_id, target_id, payload)
	if not bool(gate.allowed):
		return gate
	if not jam_target_id.is_empty():
		return command_refusal(&"class_resource_armed", "A Jam is already waiting on its target.")
	if target_id.is_empty() or host == null:
		return command_refusal(&"no_target", "Choose a living enemy to Jam.")
	return gate


func on_command(action_id: StringName, target_id: StringName) -> void:
	if action_id == &"jam_the_gears":
		jam_the_gears(target_id)


func jam_the_gears(target_id: StringName) -> bool:
	if target_id.is_empty() or not jam_target_id.is_empty():
		return false
	var result: Dictionary = request_cancel(target_id, &"any")
	var blocked_by: StringName = StringName(str(result.get("blocked_by", "")))
	if not bool(result.get("allowed", false)) and (
		blocked_by == &"nothing_to_cancel" or blocked_by == &"resolving"
	):
		jam_target_id = target_id
		return false
	return bool(result.get("allowed", false))


func has_armed_jam() -> bool:
	return not jam_target_id.is_empty()


func on_turn_start() -> void:
	if jam_target_id.is_empty() or host == null:
		return
	var target := host.actor_by_id(jam_target_id) if host != null else null
	if target == null or not target.is_alive():
		jam_target_id = &""
		return
	var result: Dictionary = request_cancel(jam_target_id, &"any")
	if bool(result.get("allowed", false)):
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
