class_name KitGate
extends RefCounted
## Whether an action belongs to a class's kit at all. CombatController and the chargen
## preview (KitPreview) read these same checks, so the CALLING tab never offers what the
## battle bar would refuse. Battle state (AP, Breath, targets, Scars on hand, a full Ledger,
## Var Harmony) is not a kit question and stays in CombatController.
##
## Each check returns {} when the action is in the kit, otherwise
## {"blocked_by", "message", "nearest_unblock"} for the caller to wrap as a refusal.


## A class-resource action is authored once and offered to every actor; the resource decides
## whether the command means anything for its patron.
static func class_command_refusal(
	action: CombatAction, resource: ClassResource, actor_name: String
) -> Dictionary:
	if action.class_resource_action.is_empty() or resource.accepts_command(action.class_resource_action):
		return {}
	return _refusal(
		&"class_resource", "%s cannot use that class action." % actor_name,
		{"type": &"patron", "patron": resource.patron_id},
	)


## `effect_payload.requires_patron`: a working that belongs to one patron's kit.
static func patron_refusal(action: CombatAction, resource: ClassResource) -> Dictionary:
	var required_patron := StringName(str(action.effect_payload.get("requires_patron", "")))
	if required_patron.is_empty() or resource.patron_id == required_patron:
		return {}
	return _refusal(
		&"class_resource",
		"%s belongs to the %s kit." % [action.display_name, String(required_patron).capitalize()],
		{"type": &"patron", "patron": required_patron},
	)


## `effect_payload.ledger_entry`: the working files through the Pazzah Ledger. Only the
## Ledger's identity is a kit question; its capacity is battle state.
static func ledger_refusal(action: CombatAction, resource: ClassResource) -> Dictionary:
	if not bool(action.effect_payload.get("ledger_entry", false)) or resource is PazzahLedger:
		return {}
	return _refusal(
		&"class_resource", "%s files through the Pazzah Ledger." % action.display_name,
		{"type": &"patron", "patron": &"pazzah"},
	)


static func _refusal(blocked_by: StringName, message: String, nearest_unblock: Dictionary) -> Dictionary:
	return {"blocked_by": blocked_by, "message": message, "nearest_unblock": nearest_unblock}
