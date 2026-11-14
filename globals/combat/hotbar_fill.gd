class_name HotbarFill
extends RefCounted
## The battle bar's default slot fill (owner 2026-11-01: an eight-slot hotbar, auto-filled;
## fill order ruled "Keep as built" 2026-11-02). CombatBar slots a fight with it and the
## chargen entry column's "In a fight" row previews it (KitPreview.hotbar), so the preview
## shows the bar the battle will slot (docs/design/chargen-overhaul-plan-2026-11-02.md).

const SIZE := 8
## Fill order: one command per role, then the two cheapest usable weapon arts and spells.
enum SlotRole { STRIKE, GUARD, SIGNATURE, DEFINING, WEAPON_ART, SPELL, OTHER }
const ROLE_QUOTA := {
	SlotRole.STRIKE: 1, SlotRole.GUARD: 1, SlotRole.SIGNATURE: 1, SlotRole.DEFINING: 1,
	SlotRole.WEAPON_ART: 2, SlotRole.SPELL: 2,
}


## Fills the open slots: Strike, Guard, the class signature and Defining Strike, then the two
## cheapest usable weapon arts and the two cheapest usable spells; any slot still open takes
## the cheapest usable command left. Strike and the signature hold their slot while locked
## (out of reach, nothing banked yet); every other role needs a command usable now.
## `ready[i]` and `in_kit[i]` describe `actions[i]`; `taken` are ids already slotted.
static func default_fill(
	actions: Array[CombatAction], ready: Array[bool], in_kit: Array[bool], taken: Array[StringName]
) -> Array[StringName]:
	var picked: Array[StringName] = []
	var room := SIZE - taken.size()
	if room <= 0:
		return picked
	var filled: Dictionary = {}
	var candidates: Array[int] = []
	for i: int in actions.size():
		if taken.has(actions[i].id):
			var role := slot_role(actions[i])
			filled[role] = int(filled.get(role, 0)) + 1
		elif in_kit[i]:
			candidates.append(i)
	candidates.sort_custom(func(a: int, b: int) -> bool:
		var role_a := slot_role(actions[a])
		var role_b := slot_role(actions[b])
		if role_a != role_b:
			return role_a < role_b
		if actions[a].ap_cost != actions[b].ap_cost:
			return actions[a].ap_cost < actions[b].ap_cost
		return a < b
	)
	for i: int in candidates:
		if picked.size() >= room:
			return picked
		var role := slot_role(actions[i])
		if int(filled.get(role, 0)) >= int(ROLE_QUOTA.get(role, 0)):
			continue
		if not ready[i] and role != SlotRole.STRIKE and role != SlotRole.SIGNATURE:
			continue
		picked.append(actions[i].id)
		filled[role] = int(filled.get(role, 0)) + 1
	candidates.sort_custom(func(a: int, b: int) -> bool:
		if actions[a].ap_cost != actions[b].ap_cost:
			return actions[a].ap_cost < actions[b].ap_cost
		return a < b
	)
	for i: int in candidates:
		if picked.size() >= room:
			break
		if ready[i] and not picked.has(actions[i].id):
			picked.append(actions[i].id)
	return picked


static func slot_role(action: CombatAction) -> SlotRole:
	if action.id == Battle.ACTION_STRIKE:
		return SlotRole.STRIKE
	if action.kind == CombatAction.Kind.GUARD:
		return SlotRole.GUARD
	if not action.class_resource_action.is_empty():
		return SlotRole.SIGNATURE
	if action.kind == CombatAction.Kind.DEFINING_STRIKE:
		return SlotRole.DEFINING
	if action.spell:
		return SlotRole.SPELL
	if action.kind == CombatAction.Kind.ATTACK:
		return SlotRole.WEAPON_ART
	return SlotRole.OTHER
