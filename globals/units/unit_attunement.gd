class_name UnitAttunement
extends Resource
## One unit's row set in the `unit_attunement` table (issue #141): ten signed
## values, one per element of the Wheel, each in the closed range -3 .. +3.
##
## UI RULE — encoded here because it is the whole point of the design, and code
## that forgets it produces the wrong screen:
##   ATTUNEMENT IS NEVER SHOWN AS TEN METERS.
## Ten simultaneous bars is exactly the readout the Elemental Architecture rejects.
## Presentation surfaces the shape of a unit's attunement (its leanings and its
## one or two refusals), not a per-element gauge row. Any UI that renders all ten
## values as parallel meters is a bug against this table's contract.
##
## The keys are ElementWheel.ORDER and nothing else — the Wheel of Ten is closed
## canon. A row keyed by an unknown element is rejected, not coerced.

const MIN_VALUE := -3
const MAX_VALUE := 3

@export var unit_id: String = ""
## element id (StringName from ElementWheel.ORDER) -> signed int in [-3, +3].
@export var values: Dictionary = {}


static func create(p_unit_id: String) -> UnitAttunement:
	var attunement := UnitAttunement.new()
	attunement.unit_id = p_unit_id
	for element in ElementWheel.ORDER:
		attunement.values[element] = 0
	return attunement


static func is_valid_value(value: Variant) -> bool:
	if typeof(value) != TYPE_INT and typeof(value) != TYPE_FLOAT:
		return false
	# A float that is not a whole number is not a valid attunement step. JSON has no
	# integer type, so honest round-tripped ints arrive as floats and must survive.
	if typeof(value) == TYPE_FLOAT and float(value) != floor(float(value)):
		return false
	var as_int := int(value)
	return as_int >= MIN_VALUE and as_int <= MAX_VALUE


static func is_known_element(element: Variant) -> bool:
	return ElementWheel.index_of(element) >= 0


func value_for(element: Variant) -> int:
	return int(values.get(ElementWheel.normalize(element), 0))


## Rejects rather than clamps: an out-of-range write is a data bug upstream, and
## silently clamping it hides the bug in a save file. Returns false and leaves the
## row untouched.
func set_value(element: Variant, value: Variant) -> bool:
	if not is_known_element(element) or not is_valid_value(value):
		return false
	values[ElementWheel.normalize(element)] = int(value)
	return true


## True when this row has exactly the ten Wheel elements, each in range.
func is_complete() -> bool:
	if values.size() != ElementWheel.ORDER.size():
		return false
	for element in ElementWheel.ORDER:
		if not values.has(element) or not is_valid_value(values[element]):
			return false
	return true


func to_dict() -> Dictionary:
	var row: Dictionary = {}
	# Serialize in Wheel order so the payload is deterministic across runs.
	for element in ElementWheel.ORDER:
		row[String(element)] = int(values.get(element, 0))
	return {"unit_id": unit_id, "values": row}


## Returns null when the payload is not a valid attunement row — an unknown
## element key or a value outside -3 .. +3 rejects the whole row.
static func from_dict(data: Dictionary) -> UnitAttunement:
	var attunement := UnitAttunement.create(str(data.get("unit_id", "")))
	var row: Variant = data.get("values", {})
	if not row is Dictionary:
		return null
	for element: Variant in (row as Dictionary):
		if not is_known_element(element):
			return null
		if not attunement.set_value(element, (row as Dictionary)[element]):
			return null
	return attunement
