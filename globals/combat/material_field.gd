class_name MaterialField
extends RefCounted
## Physical material substrate for CombatController: objects standing on cells (yard timber
## barricades, the stone control) with integrity, finite burn fuel, physical fire, Wet and
## collapse. Data only; the controller decides targeting, costs, the checkpoint moment and
## which fire line may reignite what.
##
## Rules (docs/ideas/khash-prototype-spell-cards.md "Physical timber rules" and
## docs/ideas/elemental-reaction-matrix.md L2, H2, M4, Z6):
## - Dry timber: combustible, nine fuel ticks. A heat hit deals the card's integrity damage,
##   then ignites it. Repeated heat does not restart or refill the fire.
## - Burning timber loses 3 integrity and one fuel tick per checkpoint. At zero integrity it
##   is ruined: fire ends, footprint opens. Fuel exhausted: fire ends, timber stands.
## - Wet timber (Douse): fire ends, non-ignitable for two checkpoints; direct integrity damage
##   still lands (H2). Wet counts down after protecting its final checkpoint.
## - Stone: noncombustible and immune to authored thermal integrity damage.
## - Ruined timber is a Mozh source once (M4); burning timber is not a source.

const KIND_TIMBER := "timber"
const KIND_STONE := "stone"
const TIMBER_INTEGRITY := 30 # PROVISIONAL — yard barricade baseline.
const TIMBER_FUEL := 9
const BURN_TICK_INTEGRITY := 3
const WET_CHECKPOINTS := 2
const RECLAIM_YIELD := 9 # PROVISIONAL — spell-card-rules.md "Mozh conversion".

## id -> {id, label, cell: Vector2i, kind, integrity, max_integrity, fuel, burning,
##        burn_source_id, wet_checkpoints, ruined, reclaimed}
var objects: Dictionary = {}


func reset() -> void:
	objects.clear()


func is_empty() -> bool:
	return objects.is_empty()


func add_object(id: String, cell: Vector2i, kind: String = KIND_TIMBER, label: String = "") -> Dictionary:
	if id.is_empty() or objects.has(id):
		return {"allowed": false, "reason": "duplicate_id"}
	if kind != KIND_TIMBER and kind != KIND_STONE:
		return {"allowed": false, "reason": "unknown_kind"}
	var row := {
		"id": id,
		"label": label if not label.is_empty() else id.capitalize(),
		"cell": cell,
		"kind": kind,
		"integrity": TIMBER_INTEGRITY,
		"max_integrity": TIMBER_INTEGRITY,
		"fuel": TIMBER_FUEL if kind == KIND_TIMBER else 0,
		"burning": false,
		"burn_source_id": "",
		"wet_checkpoints": 0,
		"ruined": false,
		"reclaimed": false,
	}
	objects[id] = row
	return {"allowed": true, "object": row.duplicate(true)}


func object(id: String) -> Dictionary:
	return objects.get(id, {})


func object_at(cell: Vector2i) -> Dictionary:
	for row: Dictionary in objects.values():
		if row.get("cell", Vector2i(-999, -999)) == cell:
			return row
	return {}


static func is_combustible(row: Dictionary) -> bool:
	return String(row.get("kind", "")) == KIND_TIMBER


static func is_wet(row: Dictionary) -> bool:
	return int(row.get("wet_checkpoints", 0)) > 0


static func can_ignite(row: Dictionary) -> bool:
	return (
		is_combustible(row) and not bool(row.get("ruined", false)) and not bool(row.get("burning", false))
		and not is_wet(row) and int(row.get("fuel", 0)) > 0
	)


## Why a heat working cannot ignite this object right now, or "" when it can.
static func ignition_refusal(row: Dictionary) -> String:
	if row.is_empty():
		return "no_object"
	if not is_combustible(row):
		return "noncombustible"
	if bool(row.get("ruined", false)):
		return "ruined"
	if bool(row.get("burning", false)):
		return "already_burning"
	if is_wet(row):
		return "wet"
	if int(row.get("fuel", 0)) <= 0:
		return "no_fuel"
	return ""


## Authored thermal integrity damage, then eligible ignition. Stone takes nothing.
func thermal_hit(id: String, damage: int, source_id: StringName) -> Dictionary:
	var row: Dictionary = objects.get(id, {})
	if row.is_empty():
		return {"applied": false, "reason": "no_object"}
	var out := {"applied": true, "object_id": id, "damage": 0, "ignited": false, "ignition_refusal": ""}
	if not is_combustible(row):
		out["applied"] = false
		out["reason"] = "noncombustible"
		out["ignition_refusal"] = "noncombustible"
		return out
	if not bool(row.get("ruined", false)) and damage > 0:
		var before := int(row["integrity"])
		row["integrity"] = maxi(before - damage, 0)
		out["damage"] = before - int(row["integrity"])
	var refusal := ignition_refusal(row)
	out["ignition_refusal"] = refusal
	if refusal.is_empty():
		row["burning"] = true
		row["burn_source_id"] = String(source_id)
		out["ignited"] = true
	out["collapsed"] = _settle_collapse(row)
	return out


## A fire line covering the cell ignites eligible timber with no direct hit.
func ignite(id: String, source_id: StringName) -> Dictionary:
	return thermal_hit(id, 0, source_id)


## Douse: the fire ends, the material is Wet. Integrity already lost stays.
func douse(id: String) -> Dictionary:
	var row: Dictionary = objects.get(id, {})
	if row.is_empty():
		return {"applied": false, "reason": "no_object"}
	if not is_combustible(row) or bool(row.get("ruined", false)):
		return {"applied": false, "reason": "no_effect"}
	var quenched := bool(row.get("burning", false))
	row["burning"] = false
	row["burn_source_id"] = ""
	row["wet_checkpoints"] = WET_CHECKPOINTS
	return {"applied": true, "quenched": quenched, "wet": true}


## Rot the Brace: decay damage in its own channel; Wet does not protect, stone rejects.
func rot(id: String, damage: int) -> Dictionary:
	var row: Dictionary = objects.get(id, {})
	if row.is_empty():
		return {"applied": false, "reason": "no_object"}
	if not is_combustible(row) or bool(row.get("ruined", false)):
		return {"applied": false, "reason": "not_susceptible"}
	var before := int(row["integrity"])
	row["integrity"] = maxi(before - maxi(damage, 0), 0)
	return {"applied": true, "damage": before - int(row["integrity"]), "collapsed": _settle_collapse(row)}


## Why Reclaim rejects this object, or "" when it is a source (M4: ruined timber, once).
static func reclaim_refusal(row: Dictionary) -> String:
	if row.is_empty():
		return "no_object"
	if not is_combustible(row):
		return "not_a_source"
	if bool(row.get("reclaimed", false)):
		return "already_claimed"
	if bool(row.get("burning", false)):
		return "burning"
	if not bool(row.get("ruined", false)):
		return "not_a_source"
	return ""


func reclaim(id: String) -> Dictionary:
	var row: Dictionary = objects.get(id, {})
	var refusal := reclaim_refusal(row)
	if not refusal.is_empty():
		return {"applied": false, "reason": refusal, "yield": 0}
	row["reclaimed"] = true
	return {"applied": true, "yield": RECLAIM_YIELD}


## Checkpoint, matrix order: burn ticks on what was burning at entry, then collapse, then
## Wet counts down (it protected this whole checkpoint). Returns the events in order.
func advance_checkpoint() -> Array[Dictionary]:
	var events: Array[Dictionary] = []
	var burning_at_entry: Array[String] = []
	for row: Dictionary in objects.values():
		if bool(row.get("burning", false)):
			burning_at_entry.append(String(row["id"]))
	for id: String in burning_at_entry:
		var row: Dictionary = objects[id]
		var before := int(row["integrity"])
		row["integrity"] = maxi(before - BURN_TICK_INTEGRITY, 0)
		row["fuel"] = maxi(int(row.get("fuel", 0)) - 1, 0)
		events.append({"type": "object_burn_tick", "object_id": id, "damage": before - int(row["integrity"]), "fuel": int(row["fuel"])})
		if _settle_collapse(row):
			events.append({"type": "object_collapsed", "object_id": id})
		elif int(row["fuel"]) <= 0:
			row["burning"] = false
			row["burn_source_id"] = ""
			events.append({"type": "object_fire_exhausted", "object_id": id})
	for row: Dictionary in objects.values():
		if int(row.get("wet_checkpoints", 0)) > 0:
			row["wet_checkpoints"] = int(row["wet_checkpoints"]) - 1
			if int(row["wet_checkpoints"]) <= 0:
				events.append({"type": "wet_expired", "object_id": String(row["id"])})
	return events


func snapshot() -> Array[Dictionary]:
	var out: Array[Dictionary] = []
	for row: Dictionary in objects.values():
		out.append(_serialize(row))
	return out


func to_dict() -> Dictionary:
	return {"objects": snapshot()}


func from_dict(data: Dictionary) -> void:
	reset()
	for raw: Variant in data.get("objects", []):
		if raw is Dictionary:
			var row := _deserialize(raw as Dictionary)
			if not String(row.get("id", "")).is_empty():
				objects[String(row["id"])] = row


static func _settle_collapse(row: Dictionary) -> bool:
	if bool(row.get("ruined", false)) or int(row.get("integrity", 0)) > 0:
		return false
	row["ruined"] = true
	row["burning"] = false
	row["burn_source_id"] = ""
	row["fuel"] = 0
	return true


static func _serialize(row: Dictionary) -> Dictionary:
	var out := row.duplicate(true)
	var cell: Vector2i = row.get("cell", Vector2i.ZERO)
	out["cell"] = {"x": cell.x, "y": cell.y}
	return out


static func _deserialize(data: Dictionary) -> Dictionary:
	var row := data.duplicate(true)
	var cell: Variant = data.get("cell", {})
	row["cell"] = Vector2i(int((cell as Dictionary).get("x", 0)), int((cell as Dictionary).get("y", 0))) if cell is Dictionary else Vector2i.ZERO
	for key: String in ["integrity", "max_integrity", "fuel", "wet_checkpoints"]:
		row[key] = int(data.get(key, 0))
	for key: String in ["burning", "ruined", "reclaimed"]:
		row[key] = bool(data.get(key, false))
	row["kind"] = String(data.get("kind", KIND_TIMBER))
	row["label"] = String(data.get("label", ""))
	row["burn_source_id"] = String(data.get("burn_source_id", ""))
	return row
