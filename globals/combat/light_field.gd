class_name LightField
extends RefCounted
## Sul / Vekh revelation substrate for CombatController: Witness Light fields on the board and
## the per-creature signature impositions (Exposed, Veiled, Lit) stored in
## `BattleActor.impositions`. Data only; the controller decides when a checkpoint happens and
## what "revealed" lets the panel see.
##
## Card rules (docs/ideas/elemental-spell-cards.md, Sul and Vekh rows):
## - Exposed: two checkpoints; cover is worthless against attacks and signatures are visible.
## - Veiled: two checkpoints; signatures concealed. Cannot be applied over Exposed (X1).
## - Lit (Term of Daylight): a revelation that follows the creature for one checkpoint.
## - Witness Light: fixed center, radius 1, two checkpoints; occupants read as Exposed while inside.

const FIELD_DURATION_CHECKPOINTS := 2
const FIELD_RADIUS := 1
const EXPOSED_CHECKPOINTS := 2
const VEILED_CHECKPOINTS := 2
const LIT_CHECKPOINTS := 1
const IMPOSITION_EXPOSED := "exposed"
const IMPOSITION_VEILED := "veiled"
const IMPOSITION_LIT := "lit"

## {id, owner_id, center: Vector2i, radius, remaining_checkpoints, created_round}
var fields: Array[Dictionary] = []
var _sequence := 0


func reset() -> void:
	fields.clear()
	_sequence = 0


func is_empty() -> bool:
	return fields.is_empty()


func create_field(owner_id: StringName, center: Vector2i, radius: int, round_number: int) -> Dictionary:
	_sequence += 1
	var field := {
		"id": _sequence,
		"owner_id": String(owner_id),
		"center": center,
		"radius": maxi(radius, 0),
		"remaining_checkpoints": FIELD_DURATION_CHECKPOINTS,
		"created_round": round_number,
	}
	fields.append(field)
	return {"allowed": true, "field": field.duplicate(true)}


func field_by_id(field_id: int) -> Dictionary:
	for field: Dictionary in fields:
		if int(field.get("id", 0)) == field_id:
			return field
	return {}


## The oldest field covering `cell`, or `{}`.
func field_at(cell: Vector2i) -> Dictionary:
	for field: Dictionary in fields:
		if covers(field, cell):
			return field
	return {}


func is_lit_cell(cell: Vector2i) -> bool:
	return not field_at(cell).is_empty()


func remove_field(field_id: int) -> bool:
	for index: int in fields.size():
		if int(fields[index].get("id", 0)) == field_id:
			fields.remove_at(index)
			return true
	return false


## Ages every field by one checkpoint and returns the ones that expired (already removed).
func advance_checkpoint() -> Array[Dictionary]:
	var expired: Array[Dictionary] = []
	var kept: Array[Dictionary] = []
	for field: Dictionary in fields:
		field["remaining_checkpoints"] = int(field.get("remaining_checkpoints", 0)) - 1
		if int(field["remaining_checkpoints"]) <= 0:
			expired.append(field.duplicate(true))
		else:
			kept.append(field)
	fields = kept
	return expired


func snapshot() -> Array[Dictionary]:
	var out: Array[Dictionary] = []
	for field: Dictionary in fields:
		out.append(_serialize_field(field))
	return out


func to_dict() -> Dictionary:
	return {"sequence": _sequence, "fields": snapshot()}


func from_dict(data: Dictionary) -> void:
	reset()
	_sequence = int(data.get("sequence", 0))
	for raw: Variant in data.get("fields", []):
		if raw is Dictionary:
			fields.append(_deserialize_field(raw as Dictionary))


static func covers(field: Dictionary, cell: Vector2i) -> bool:
	if field.is_empty():
		return false
	var center: Vector2i = field.get("center", Vector2i.ZERO)
	var delta := cell - center
	return maxi(absi(delta.x), absi(delta.y)) <= int(field.get("radius", 0))


static func cell_to_data(cell: Vector2i) -> Dictionary:
	return {"x": cell.x, "y": cell.y}


static func cell_from_data(value: Variant) -> Variant:
	if value is Vector2i:
		return value
	if value is Dictionary:
		var data := value as Dictionary
		if data.has("x") and data.has("y"):
			return Vector2i(int(data["x"]), int(data["y"]))
	return null


# ─── impositions ────────────────────────────────────────────────────────────


static func is_exposed(actor: BattleActor) -> bool:
	return actor != null and actor.impositions.has(IMPOSITION_EXPOSED)


static func is_veiled(actor: BattleActor) -> bool:
	return actor != null and actor.impositions.has(IMPOSITION_VEILED)


static func is_lit(actor: BattleActor) -> bool:
	return actor != null and actor.impositions.has(IMPOSITION_LIT)


## Exposed replaces Veiled (S3: revelation contests the veil). Refresh, never stack.
static func apply_exposed(actor: BattleActor, source_id: StringName, checkpoints: int = EXPOSED_CHECKPOINTS) -> Dictionary:
	if actor == null:
		return {"applied": false, "refreshed": false, "reason": "no_target"}
	var unveiled := actor.impositions.erase(IMPOSITION_VEILED)
	var refreshed := is_exposed(actor)
	actor.impositions[IMPOSITION_EXPOSED] = {
		"remaining_checkpoints": maxi(checkpoints, 1),
		"source_id": String(source_id),
	}
	return {"applied": true, "refreshed": refreshed, "unveiled": unveiled, "reason": ""}


## X1: Vekh cannot re-veil an Exposed creature.
static func apply_veiled(actor: BattleActor, source_id: StringName, checkpoints: int = VEILED_CHECKPOINTS) -> Dictionary:
	if actor == null:
		return {"applied": false, "refreshed": false, "reason": "no_target"}
	if is_exposed(actor):
		return {"applied": false, "refreshed": false, "reason": "exposed"}
	var refreshed := is_veiled(actor)
	actor.impositions[IMPOSITION_VEILED] = {
		"remaining_checkpoints": maxi(checkpoints, 1),
		"source_id": String(source_id),
	}
	return {"applied": true, "refreshed": refreshed, "reason": ""}


static func apply_lit(actor: BattleActor, source_id: StringName, field_id: int, checkpoints: int = LIT_CHECKPOINTS) -> Dictionary:
	if actor == null:
		return {"applied": false, "reason": "no_target"}
	actor.impositions[IMPOSITION_LIT] = {
		"remaining_checkpoints": maxi(checkpoints, 1),
		"source_id": String(source_id),
		"field_id": field_id,
	}
	return {"applied": true, "reason": ""}


static func clear_veiled(actor: BattleActor) -> bool:
	return actor != null and actor.impositions.erase(IMPOSITION_VEILED)


## Ages one imposition; returns true when it expired at this checkpoint.
static func age(actor: BattleActor, imposition: String) -> bool:
	if actor == null or not actor.impositions.has(imposition):
		return false
	var entry: Dictionary = actor.impositions[imposition]
	var remaining := int(entry.get("remaining_checkpoints", 0)) - 1
	if remaining <= 0:
		actor.impositions.erase(imposition)
		return true
	entry["remaining_checkpoints"] = remaining
	return false


static func _serialize_field(field: Dictionary) -> Dictionary:
	var out := field.duplicate(true)
	out["center"] = cell_to_data(field.get("center", Vector2i.ZERO))
	return out


static func _deserialize_field(data: Dictionary) -> Dictionary:
	var field := data.duplicate(true)
	var center: Variant = cell_from_data(data.get("center", {}))
	field["center"] = center if center is Vector2i else Vector2i.ZERO
	field["id"] = int(data.get("id", 0))
	field["radius"] = int(data.get("radius", 0))
	field["remaining_checkpoints"] = int(data.get("remaining_checkpoints", 0))
	return field
