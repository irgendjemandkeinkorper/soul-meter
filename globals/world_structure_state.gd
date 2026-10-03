class_name WorldStructureState
extends RefCounted
## Persistent, opt-in physical structures. See tasks/persistent-structures.md.

signal structure_changed(structure_id: String)
signal state_restored

const MAX_COUNTER := 2147483647

var _structures: Dictionary = {}
var _services: Dictionary = {}


func register_structure(id: String, max_integrity: int, rebuild_phases: int = 0) -> bool:
	if not _valid_id(id) or not _integer(max_integrity, 1) or not _integer(rebuild_phases, 0):
		return false
	if _structures.has(id):
		var existing: Dictionary = _structures[id]
		return existing["max_integrity"] == max_integrity and existing["rebuild_phases"] == rebuild_phases
	_structures[id] = {
		"max_integrity": max_integrity, "integrity": max_integrity,
		"rebuild_phases": rebuild_phases, "state": "intact",
		"destroyed_at": -1, "rebuild_at": -1, "restoration_events": [],
	}
	return true


func structure(id: String) -> Dictionary:
	return (_structures.get(id, {}) as Dictionary).duplicate(true)


func damage(id: String, amount: int, phase_count: int) -> bool:
	if not _structures.has(id) or amount <= 0 or not _integer(phase_count, 0):
		return false
	var row: Dictionary = _structures[id]
	if phase_count > MAX_COUNTER - int(row["rebuild_phases"]):
		return false
	if row["state"] == "ruined" or phase_count < int(row["destroyed_at"]):
		return false
	row["integrity"] = maxi(0, int(row["integrity"]) - amount)
	row["state"] = "damaged" if int(row["integrity"]) > 0 else "ruined"
	if int(row["integrity"]) == 0:
		row["destroyed_at"] = phase_count
		var duration: int = row["rebuild_phases"]
		row["rebuild_at"] = phase_count + duration if duration > 0 else -1
	structure_changed.emit(id)
	return true


## A story event may restore an abandoned site, but never creates a repeating timer.
## Event ids remain consumed after restoration and subsequent destruction.
func begin_rebuild(id: String, duration: int, phase_count: int, event_id: String) -> bool:
	if not _structures.has(id) or not _valid_id(event_id) or not _integer(duration, 1):
		return false
	var row: Dictionary = _structures[id]
	if not _integer(phase_count, 0) or phase_count > MAX_COUNTER - duration:
		return false
	if row["state"] != "ruined" or int(row["rebuild_at"]) >= 0:
		return false
	if phase_count < int(row["destroyed_at"]) or row["restoration_events"].has(event_id):
		return false
	row["restoration_events"].append(event_id)
	row["rebuild_at"] = phase_count + duration
	row["state"] = "rebuilding"
	structure_changed.emit(id)
	return true


## `blocked_ids` lets field integration defer a restored footprint occupied by an actor.
## Calling again at the SAME phase retries placement without aging construction.
func advance(phase_count: int, blocked_ids: Array[String] = []) -> void:
	var ids: Array = _structures.keys()
	ids.sort()
	for id: String in ids:
		var row: Dictionary = _structures[id]
		var deadline: int = row["rebuild_at"]
		if deadline < 0 or phase_count <= int(row["destroyed_at"]):
			continue
		var previous: String = row["state"]
		if phase_count >= deadline and not blocked_ids.has(id):
			row["integrity"] = row["max_integrity"]
			row["state"] = "intact"
			row["rebuild_at"] = -1
		else:
			row["state"] = "rebuilding"
		if previous != row["state"]:
			structure_changed.emit(id)


static func _valid_id(value: Variant) -> bool:
	return value is String and not value.is_empty() and value.length() <= 128 and value == value.strip_edges()


## One existing merchant identity; no inventory, NPC or quest state is copied here.
func register_service(vendor_id: String, structure_id: String, home: String, temporary: String = "") -> bool:
	var row := {"structure_id": structure_id, "home": home, "temporary": temporary}
	if not _valid_id(vendor_id) or not _valid_service(row, _structures):
		return false
	if _services.has(vendor_id):
		return _services[vendor_id] == row
	_services[vendor_id] = row
	return true


func service_status(vendor_id: String) -> Dictionary:
	if not _services.has(vendor_id):
		return {}
	var service: Dictionary = _services[vendor_id]
	var row: Dictionary = _structures[service["structure_id"]]
	var usable: bool = int(row["integrity"]) > 0
	var relocated: bool = not usable and not str(service["temporary"]).is_empty()
	return {
		"structure_id": service["structure_id"], "available": usable or relocated,
		"relocated": relocated,
		"location_id": service["home"] if usable else service["temporary"],
	}


func to_dict() -> Dictionary:
	return {"structures": _structures.duplicate(true), "services": _services.duplicate(true)}


func from_dict(value: Variant) -> bool:
	if not validate_save_data(value):
		return false
	_structures = (value.get("structures", {}) as Dictionary).duplicate(true)
	_services = (value.get("services", {}) as Dictionary).duplicate(true)
	state_restored.emit()
	return true


static func validate_save_data(value: Variant) -> bool:
	if not value is Dictionary or not value.get("structures", {}) is Dictionary:
		return false
	var rows: Dictionary = value.get("structures", {})
	for id: Variant in rows:
		if not _valid_id(id) or not _valid_structure(rows[id]):
			return false
	var services: Variant = value.get("services", {})
	if not services is Dictionary:
		return false
	for vendor_id: Variant in services:
		if not _valid_id(vendor_id) or not _valid_service(services[vendor_id], rows):
			return false
	return true


static func _valid_service(value: Variant, structures: Dictionary) -> bool:
	if not value is Dictionary or not _valid_id(value.get("structure_id")):
		return false
	if not structures.has(value["structure_id"]) or not _valid_id(value.get("home")):
		return false
	var temporary: Variant = value.get("temporary")
	return temporary is String and (temporary.is_empty() or (_valid_id(temporary) and temporary != value["home"]))


static func _valid_structure(value: Variant) -> bool:
	if not value is Dictionary:
		return false
	for key: String in ["max_integrity", "integrity", "rebuild_phases", "destroyed_at", "rebuild_at"]:
		var minimum := -1 if key in ["destroyed_at", "rebuild_at"] else 0
		if not _integer(value.get(key), minimum):
			return false
	var hp: int = value["integrity"]
	var maximum: int = value["max_integrity"]
	var destroyed: int = value["destroyed_at"]
	var deadline: int = value["rebuild_at"]
	var status: Variant = value.get("state")
	if maximum <= 0 or hp > maximum or not status is String:
		return false
	if hp > 0:
		if status != ("intact" if hp == maximum else "damaged") or deadline != -1:
			return false
	else:
		if status not in ["ruined", "rebuilding"] or destroyed < 0:
			return false
		if status == "rebuilding" and deadline < 0:
			return false
	if deadline >= 0 and (destroyed < 0 or deadline <= destroyed):
		return false
	var events: Variant = value.get("restoration_events")
	if not events is Array:
		return false
	var seen := {}
	for event_id: Variant in events:
		if not _valid_id(event_id) or seen.has(event_id):
			return false
		seen[event_id] = true
	return true


static func _integer(value: Variant, minimum: int) -> bool:
	return typeof(value) == TYPE_INT and value >= minimum and value <= MAX_COUNTER
