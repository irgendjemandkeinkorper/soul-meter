class_name KitPreview
extends RefCounted
## The CALLING tab's ability tiles: what a member of a class can use in a fight, in four
## groups. Membership comes from KitGate, the same checks CombatController runs, so the
## preview never offers what the battle bar would refuse (test_kit_preview.gd checks every
## class). Held tones only sort spells into "your tones": combat casting does not read them
## yet (docs/owner-decisions.md item 27, F3c), so spells in other tones are listed as open.
##
## Each group is an Array of entries {"action": CombatAction, "lock": String}. `lock` is
## empty for a usable action, otherwise the reason it stays shut at creation (a signature
## perk not yet picked). Battle state (AP, Breath, targets, Scars on hand) is not shown.

const CLASS := &"class"
const TONES := &"tones"
const OTHER_TONES := &"other_tones"
const COMMON := &"common"
const GROUPS: Array[StringName] = [CLASS, TONES, OTHER_TONES, COMMON]

## Not tiles: moving is a click on the ground; PASS and RESOLUTION are not abilities.
const _NOT_TILES: Array[CombatAction.Kind] = [
	CombatAction.Kind.MOVE, CombatAction.Kind.PASS, CombatAction.Kind.RESOLUTION,
]


static func for_member(member: PartyMember, actions: Array[CombatAction] = []) -> Dictionary:
	var source: Array[CombatAction] = actions if not actions.is_empty() else CombatActionCatalog.player_actions()
	var resource := ClassResourceRegistry.for_patron(member.patron if member != null else "")
	if member != null:
		resource.apply_perks(member.perk_ids)
	var held := held_elements(member)
	var result: Dictionary = {}
	for group: StringName in GROUPS:
		result[group] = []
	for action: CombatAction in source:
		var group := group_of(action, resource, held)
		if not group.is_empty():
			(result[group] as Array).append({"action": action, "lock": lock_of(action, resource)})
	return result


## The member's Major and Minor elements, in that order, without blanks.
static func held_elements(member: PartyMember) -> Array[StringName]:
	var held: Array[StringName] = []
	if member == null:
		return held
	for element: String in [member.major_element, member.minor_element]:
		if not element.is_empty() and not held.has(StringName(element)):
			held.append(StringName(element))
	return held


## Which tile group an action falls in for this class, or &"" when it is not in the kit.
static func group_of(action: CombatAction, resource: ClassResource, held: Array[StringName]) -> StringName:
	if not KitGate.class_command_refusal(action, resource, "").is_empty():
		return &""
	if not KitGate.patron_refusal(action, resource).is_empty():
		return &""
	if not KitGate.ledger_refusal(action, resource).is_empty():
		return &""
	if not action.class_resource_action.is_empty() or action.effect_payload.has("requires_patron"):
		return CLASS
	if not String(action.element_id).is_empty():
		return TONES if held.has(action.element_id) else OTHER_TONES
	if _NOT_TILES.has(action.kind):
		return &""
	return COMMON


## Why an in-kit action is shut at creation: only a class command whose signature perk has
## not been picked. The resource's own refusal text is used, so the card and the bar agree.
static func lock_of(action: CombatAction, resource: ClassResource) -> String:
	if action.class_resource_action.is_empty():
		return ""
	var gate := resource.query_command(action.class_resource_action, &"", action.class_resource_payload)
	if StringName(str(gate.get("blocked_by", ""))) == &"perk_missing":
		return str(gate.get("message", ""))
	return ""


## The working's breadth for a tier-gated spell (2 = chord, 3 = triad), 0 otherwise. Whether
## it can be cast depends on the party's Var Harmony in battle (CastingGate).
static func tier_of(action: CombatAction) -> int:
	return int(action.effect_payload.get("requires_tier", 0))
