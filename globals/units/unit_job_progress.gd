class_name UnitJobProgress
extends Resource
## One row of the `unit_jobs` table (issue #141): what a unit has earned in one job.
##
## SCHEMA ONLY. `mastered` holds ability ids (FKs into `abilities`); this issue
## authors none, so a shipped row is always empty.

@export var unit_id: String = ""
@export var job_id: String = ""
## Job Points earned toward this job. Never negative.
@export var jp: int = 0
## Ability ids already mastered in this job. Kept sorted so the payload is
## deterministic — save round trips must not reorder it.
@export var mastered: PackedStringArray = PackedStringArray()


static func create(p_unit_id: String, p_job_id: String) -> UnitJobProgress:
	var progress := UnitJobProgress.new()
	progress.unit_id = p_unit_id
	progress.job_id = p_job_id
	return progress


func has_mastered(ability_id: String) -> bool:
	return mastered.has(ability_id)


func master(ability_id: String) -> bool:
	if ability_id.is_empty() or has_mastered(ability_id):
		return false
	mastered.append(ability_id)
	var sorted := Array(mastered)
	sorted.sort()
	mastered = PackedStringArray(sorted)
	return true


func to_dict() -> Dictionary:
	return {
		"unit_id": unit_id,
		"job_id": job_id,
		"jp": jp,
		"mastered": Array(mastered),
	}


static func from_dict(data: Dictionary) -> UnitJobProgress:
	var progress := UnitJobProgress.new()
	progress.unit_id = str(data.get("unit_id", ""))
	progress.job_id = str(data.get("job_id", ""))
	progress.jp = maxi(0, int(data.get("jp", 0)))
	var rows: Variant = data.get("mastered", [])
	var ids: Array = []
	if rows is Array:
		for row: Variant in (rows as Array):
			var ability_id := str(row)
			if not ability_id.is_empty() and not ids.has(ability_id):
				ids.append(ability_id)
	ids.sort()
	progress.mastered = PackedStringArray(ids)
	return progress
