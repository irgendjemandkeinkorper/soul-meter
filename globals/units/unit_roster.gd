class_name UnitRoster
extends RefCounted
## The serializable aggregate of the four per-unit tables (issue #141):
## `units`, `unit_jobs`, `unit_attunement`, `unit_loadout`.
##
## `jobs` and `abilities` are NOT here — those are canonical authored data owned by
## Pandora and read through TacticalTables. Only per-unit state belongs in a save.
##
## Kept a plain RefCounted with to_dict/from_dict so GameState stays serializable
## (co-op is a live maybe — see CLAUDE.md).

var units: Dictionary = {}  # unit_id -> UnitDefinition
var job_progress: Dictionary = {}  # unit_id -> {job_id -> UnitJobProgress}
var attunements: Dictionary = {}  # unit_id -> UnitAttunement
var loadouts: Dictionary = {}  # unit_id -> UnitLoadout


func is_empty() -> bool:
	return units.is_empty()


func unit_ids() -> PackedStringArray:
	var ids: Array = units.keys()
	ids.sort()
	return PackedStringArray(ids)


func add_unit(unit: UnitDefinition) -> bool:
	if unit == null or unit.id.is_empty() or units.has(unit.id):
		return false
	units[unit.id] = unit
	job_progress[unit.id] = {}
	attunements[unit.id] = UnitAttunement.create(unit.id)
	loadouts[unit.id] = UnitLoadout.create(unit.id)
	return true


func unit(unit_id: String) -> UnitDefinition:
	return units.get(unit_id, null)


func attunement(unit_id: String) -> UnitAttunement:
	return attunements.get(unit_id, null)


func loadout(unit_id: String) -> UnitLoadout:
	return loadouts.get(unit_id, null)


func progress_for(unit_id: String, job_id: String) -> UnitJobProgress:
	var rows: Dictionary = job_progress.get(unit_id, {})
	return rows.get(job_id, null)


func to_dict() -> Dictionary:
	var unit_rows: Dictionary = {}
	var job_rows: Dictionary = {}
	var attunement_rows: Dictionary = {}
	var loadout_rows: Dictionary = {}
	for unit_id: String in unit_ids():
		unit_rows[unit_id] = (units[unit_id] as UnitDefinition).to_dict()
		var progress: Dictionary = job_progress.get(unit_id, {})
		var job_ids: Array = progress.keys()
		job_ids.sort()
		var serialized_jobs: Dictionary = {}
		for job_id: String in job_ids:
			serialized_jobs[job_id] = (progress[job_id] as UnitJobProgress).to_dict()
		job_rows[unit_id] = serialized_jobs
		var attunement_row: UnitAttunement = attunements.get(unit_id, null)
		if attunement_row != null:
			attunement_rows[unit_id] = attunement_row.to_dict()
		var loadout_row: UnitLoadout = loadouts.get(unit_id, null)
		if loadout_row != null:
			loadout_rows[unit_id] = loadout_row.to_dict()
	return {
		"units": unit_rows,
		"unit_jobs": job_rows,
		"unit_attunement": attunement_rows,
		"unit_loadout": loadout_rows,
	}


## Returns null when the payload is malformed — in particular when any attunement
## row carries a value outside -3 .. +3 or an element outside the Wheel of Ten.
static func from_dict(data: Variant) -> UnitRoster:
	if not data is Dictionary:
		return null
	var source: Dictionary = data
	var roster := UnitRoster.new()
	var unit_rows: Variant = source.get("units", {})
	if not unit_rows is Dictionary:
		return null
	for unit_id: Variant in (unit_rows as Dictionary):
		var row: Variant = (unit_rows as Dictionary)[unit_id]
		if not row is Dictionary:
			return null
		var unit := UnitDefinition.from_dict(row)
		unit.id = str(unit_id)
		if not roster.add_unit(unit):
			return null

	var job_rows: Variant = source.get("unit_jobs", {})
	if not job_rows is Dictionary:
		return null
	for unit_id: Variant in (job_rows as Dictionary):
		if not roster.units.has(str(unit_id)):
			return null
		var per_job: Variant = (job_rows as Dictionary)[unit_id]
		if not per_job is Dictionary:
			return null
		for job_id: Variant in (per_job as Dictionary):
			var progress_row: Variant = (per_job as Dictionary)[job_id]
			if not progress_row is Dictionary:
				return null
			var progress := UnitJobProgress.from_dict(progress_row)
			progress.unit_id = str(unit_id)
			progress.job_id = str(job_id)
			(roster.job_progress[str(unit_id)] as Dictionary)[str(job_id)] = progress

	var attunement_rows: Variant = source.get("unit_attunement", {})
	if not attunement_rows is Dictionary:
		return null
	for unit_id: Variant in (attunement_rows as Dictionary):
		if not roster.units.has(str(unit_id)):
			return null
		var attunement_row: Variant = (attunement_rows as Dictionary)[unit_id]
		if not attunement_row is Dictionary:
			return null
		var attunement := UnitAttunement.from_dict(attunement_row)
		if attunement == null:
			return null
		attunement.unit_id = str(unit_id)
		roster.attunements[str(unit_id)] = attunement

	var loadout_rows: Variant = source.get("unit_loadout", {})
	if not loadout_rows is Dictionary:
		return null
	for unit_id: Variant in (loadout_rows as Dictionary):
		if not roster.units.has(str(unit_id)):
			return null
		var loadout_row: Variant = (loadout_rows as Dictionary)[unit_id]
		if not loadout_row is Dictionary:
			return null
		var loadout := UnitLoadout.from_dict(loadout_row)
		loadout.unit_id = str(unit_id)
		roster.loadouts[str(unit_id)] = loadout

	return roster
