class_name AbilityDefinition
extends Resource
## One row of the `abilities` table (issue #141, Elemental Architecture Section III).
##
## SCHEMA ONLY — see JobDefinition's header. No ability is named or costed here;
## power/cost balance is owner-authored content.
##
## CT, NOT AP. `ct_cost` replaces the old AP cost. The charge-time economy lives in
## globals/combat/turn_scheduler.gd (READY_AT = 100, TICKS_PER_MEASURE = 16) and its
## charge-time implementation in charge_time_scheduler.gd: a participant acts at
## charge 100, moving costs 20, actions cost 30-60. Those constants are NOT redefined
## here — the generator bounds-checks authored ct_cost against them
## (see tools/generate_tactical_tables.gd) and a unit test asserts the mirror never drifts.

const SLOT_ACTION := &"action"
const SLOT_REACTION := &"reaction"
const SLOT_PASSIVE := &"passive"

## Provisional casting costs from docs/casting-economy.md. Keep this single
## source of defaults aligned with the Pandora seeder's authored rows.
const BREATH_COST_BY_MAGNITUDE := {
	&"note": 3,
	&"phrase": 6,
	&"song": 12,
	&"refrain": 24,
}

const SLOTS: Array[StringName] = [SLOT_ACTION, SLOT_REACTION, SLOT_PASSIVE]

@export var id: String = ""
@export var display_name: String = ""
## Optional FK into `jobs`; directly equipped unit abilities leave it empty.
@export var job_id: String = ""
@export var slot: StringName = SLOT_ACTION
## FK into ElementWheel.ORDER; empty means the ability is unaligned.
@export var element_id: StringName = &""
@export var elements: Array[StringName] = []
@export var magnitude: StringName = &"note"
@export var power: int = 0
@export var breath_cost: int = 0
## Legacy serialization/authoring alias. Breath is the canonical runtime name.
@export var mp_cost: int:
	get:
		return breath_cost
	set(value):
		breath_cost = value
@export var ct_cost: int = 0
@export var range: int = 0
@export var aoe: int = 0
## Vertical tolerance in tiles — how much height difference the ability can cross.
@export var vertical: int = 0
@export var vault_id: String = ""


static func is_valid_slot(value: Variant) -> bool:
	return StringName(str(value)) in SLOTS


static func breath_cost_for_magnitude(magnitude: StringName, fallback: int = 0) -> int:
	return int(BREATH_COST_BY_MAGNITUDE.get(magnitude, fallback))


func to_dict() -> Dictionary:
	return {
		"id": id,
		"display_name": display_name,
		"job_id": job_id,
		"slot": String(slot),
		"element_id": String(element_id),
		"elements": elements.duplicate(),
		"magnitude": String(magnitude),
		"power": power,
		"breath_cost": breath_cost,
		"mp_cost": breath_cost,
		"ct_cost": ct_cost,
		"range": range,
		"aoe": aoe,
		"vertical": vertical,
		"vault_id": vault_id,
	}


static func from_dict(data: Dictionary) -> AbilityDefinition:
	var ability := AbilityDefinition.new()
	ability.id = str(data.get("id", ""))
	ability.display_name = str(data.get("display_name", ""))
	ability.job_id = str(data.get("job_id", ""))
	ability.slot = StringName(str(data.get("slot", String(SLOT_ACTION))))
	ability.element_id = StringName(str(data.get("element_id", "")))
	ability.elements.assign(data.get("elements", []))
	ability.magnitude = StringName(str(data.get("magnitude", "note")))
	ability.power = int(data.get("power", 0))
	if data.has("breath_cost"):
		ability.breath_cost = int(data["breath_cost"])
	elif data.has("mp_cost"):
		ability.breath_cost = int(data["mp_cost"])
	else:
		ability.breath_cost = breath_cost_for_magnitude(ability.magnitude)
	ability.ct_cost = int(data.get("ct_cost", 0))
	ability.range = int(data.get("range", 0))
	ability.aoe = int(data.get("aoe", 0))
	ability.vertical = int(data.get("vertical", 0))
	ability.vault_id = str(data.get("vault_id", ""))
	return ability
