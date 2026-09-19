class_name CalledShot
extends RefCounted
## Data-only legality and pricing for explicitly authored anatomical aims.
## No injury effects or lore discovery are implied by an exposed location.


static func query(
	action: CombatAction, target: BattleActor, location: StringName,
	accuracy_enabled: bool, maximum_ct_cost: int, cover: Dictionary = {},
) -> Dictionary:
	if (
		action.kind != CombatAction.Kind.ATTACK or action.spell or action.no_damage
		or action.aoe_shape != &"single" or not action.effect_id.is_empty()
		or not action.aim_profiles.has(location)
	):
		return _blocked(&"aim_action", "This action does not support that aim.")
	if target == null or not target.is_alive():
		return _blocked(&"no_target", "Choose a living target before aiming.")
	if not target.anatomy.get(location) is Dictionary:
		return _blocked(&"aim_location", "This target has no such authored location.")
	var anatomy: Dictionary = target.anatomy[location]
	if not bool(anatomy.get("exposed", false)):
		return _blocked(&"aim_exposure", "That location is not exposed.")
	# Partial exposure: low cover hides only the locations authored as cover-hidden; the
	# rest stay targetable. A fully blocked line of fire is refused before this point.
	if bool(cover.get("covered", false)) and bool(anatomy.get("hidden_by_cover", false)):
		return _blocked(&"aim_cover", "Low cover hides that location from here.")
	if not accuracy_enabled:
		return _blocked(&"aim_accuracy", "Aiming requires a battlefield with accuracy resolution.")
	if not action.aim_profiles[location] is Dictionary:
		return _blocked(&"aim_profile", "The aim profile is incomplete.")
	var profile: Dictionary = action.aim_profiles[location]
	for key: String in ["ap_surcharge", "ct_surcharge", "accuracy_penalty"]:
		var value: Variant = profile.get(key)
		if not (value is int or value is float):
			return _blocked(&"aim_profile", "Aim costs and penalty must be authored as positive integers.")
		if not is_finite(float(value)) or float(value) != float(int(value)) or int(value) <= 0:
			return _blocked(&"aim_profile", "Aim costs and penalty must be authored as positive integers.")
	if action.ct_cost < 0 or action.ct_cost + int(profile["ct_surcharge"]) > maximum_ct_cost:
		return _blocked(&"aim_profile", "Aim needs an explicit CT cost within the action cost limit.")
	var injury: Dictionary = {}
	if profile.has("injury"):
		if not profile["injury"] is Dictionary or str((profile["injury"] as Dictionary).get("id", "")).is_empty():
			return _blocked(&"aim_profile", "An aim injury must author an id.")
		injury = (profile["injury"] as Dictionary).duplicate(true)
		var chance: Variant = injury.get("chance_on_hit", 0)
		if not (chance is int or chance is float) or int(chance) < 0 or int(chance) > 100:
			return _blocked(&"aim_profile", "Aim injury chance must be authored as 0-100.")
		injury["chance_on_hit"] = int(chance)
		injury["min_damage"] = maxi(int(injury.get("min_damage", 1)), 0)
		injury["location_id"] = String(location)
	var result := {
		"allowed": true, "location_id": String(location),
		"display_name": str(anatomy.get("display_name", location)),
		"ap_surcharge": int(profile["ap_surcharge"]),
		"ct_surcharge": int(profile["ct_surcharge"]),
		"accuracy_penalty": int(profile["accuracy_penalty"]),
	}
	if not injury.is_empty():
		result["injury"] = injury
	return result


## Called only after query succeeds. Never changes the catalog Resource.
static func priced_action(action: CombatAction, location: StringName) -> CombatAction:
	if location.is_empty():
		return action
	var priced := action.duplicate(true) as CombatAction
	var profile: Dictionary = action.aim_profiles[location]
	priced.ap_cost += int(profile["ap_surcharge"])
	priced.ct_cost += int(profile["ct_surcharge"])
	return priced


static func _blocked(reason: StringName, message: String) -> Dictionary:
	return {"allowed": false, "blocked_by": reason, "message": message, "nearest_unblock": {}}
