class_name TacticalTables
extends RefCounted
## Runtime read side of the generated tactical lookup (issue #141).
##
## ONE-WAY. res://data/generated/tactical_tables.json is emitted by
## tools/generate_tactical_tables.gd from Pandora and is never hand-edited and never
## written back to. This class only reads it.
##
## The `jobs` and `abilities` tables are EMPTY in shipped data by design: the naming
## of combat disciplines is canon owned by GitHub #132 (docs/prd-amendment-tactical-layer.md
## §9.1). Every consumer must therefore tolerate an empty catalog — an empty table is
## the correct state, not a load failure.

const TABLE_PATH := "res://data/generated/tactical_tables.json"

static var _cache: TacticalTables = null

var jobs: Dictionary = {}  # job_id -> JobDefinition
var abilities: Dictionary = {}  # ability_id -> AbilityDefinition


static func load_tables(path: String = TABLE_PATH) -> TacticalTables:
	var tables := TacticalTables.new()
	if not FileAccess.file_exists(path):
		return tables
	var parsed: Variant = JSON.parse_string(FileAccess.get_file_as_string(path))
	if not parsed is Dictionary:
		push_warning("Tactical tables artifact is malformed: %s" % path)
		return tables
	var source: Dictionary = parsed
	for row: Variant in source.get("jobs", []):
		if row is Dictionary:
			var job := JobDefinition.from_dict(row)
			tables.jobs[job.id] = job
	for row: Variant in source.get("abilities", []):
		if row is Dictionary:
			var ability := AbilityDefinition.from_dict(row)
			tables.abilities[ability.id] = ability
	return tables


## Shared, lazily loaded instance. Definitions are read-only value objects, so
## sharing is safe — but that makes it an INVARIANT: never mutate a definition
## returned from here. (Same contract as the generated GLoot definitions.)
static func shared() -> TacticalTables:
	if _cache == null:
		_cache = load_tables()
	return _cache


static func reset_cache() -> void:
	_cache = null


func job(job_id: String) -> JobDefinition:
	return jobs.get(job_id, null)


func ability(ability_id: String) -> AbilityDefinition:
	return abilities.get(ability_id, null)


func abilities_for_job(job_id: String) -> Array[AbilityDefinition]:
	var rows: Array[AbilityDefinition] = []
	var ids: Array = abilities.keys()
	ids.sort()
	for ability_id: String in ids:
		var row: AbilityDefinition = abilities[ability_id]
		if row.job_id == job_id:
			rows.append(row)
	return rows


func abilities_in_slot(slot: StringName) -> Array[AbilityDefinition]:
	var rows: Array[AbilityDefinition] = []
	var ids: Array = abilities.keys()
	ids.sort()
	for ability_id: String in ids:
		var row: AbilityDefinition = abilities[ability_id]
		if row.slot == slot:
			rows.append(row)
	return rows
