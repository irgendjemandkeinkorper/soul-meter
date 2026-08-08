extends Node
## generate_tactical_tables.gd — the Pandora one-way generator for the six
## tactical-layer tables of issue #141 (Elemental Architecture Section III).
##
## Same contract as tools/generate_gloot.gd: Pandora OWNS this data, nothing writes
## back, and the emitted artifacts are committed but NEVER hand-edited.
##
## Emits:
##   res://data/generated/tactical_tables.json — jobs, abilities, units, unit_jobs,
##       unit_attunement, unit_loadout (each a deterministically ordered array)
##   res://data/generated/tactical_ids.gd     — stable TacticalIds constants; no
##       literal job/ability/unit id strings in code, ever
##
## Run ways (same autoload-tool convention as generate_gloot.gd — see
## scripts/seed_town_npcs.sh and scripts/check_generated_data.sh for the recipe):
##   - Headless: register as a temp autoload, run once
##   - Drift check (CI/pre-commit): same, with env SOUL_METER_DRIFT_CHECK=1 —
##     exits non-zero if the committed artifacts differ from a fresh generation
## NOTE: `godot --headless --script` aborts at teardown ~20-30% of the time in this
## environment. Judge the printed output, never the raw exit code.
##
## SHIPPED CONTENT IS EMPTY ON PURPOSE. Issue #141 is schema and generator only; the
## naming of combat disciplines is canon owned by GitHub #132
## (docs/prd-amendment-tactical-layer.md §9.1). The generator is written to validate
## content the moment it is authored, and to emit correct empty tables until then.

const GENERATED_HEADER := "GENERATED FILE — do not edit by hand."
const GENERATED_INSTRUCTION := (
	"Source of truth is res://data.pandora; regenerate with tools/generate_tactical_tables.gd."
)

const OUT_DIR := "res://data/generated"
const TABLES_PATH := "res://data/generated/tactical_tables.json"
const IDS_PATH := "res://data/generated/tactical_ids.gd"

## Mirrors TurnScheduler.READY_AT (globals/combat/turn_scheduler.gd). Deliberately a
## mirror rather than a preload so this tool does not couple to the combat layer while
## its consumer is being rewritten; test/unit/test_tactical_schema.gd asserts the two
## never drift apart. `ct_cost` replaces AP cost — an action costing more charge than a
## full turn's worth is a data error, not a design choice this generator may make.
const CT_READY_AT := 100

const TABLE_ROOTS := ["Jobs", "Abilities", "Units", "Unit Jobs", "Unit Attunement", "Unit Loadout"]


func _ready() -> void:
	await get_tree().process_frame
	if not Pandora.is_loaded():
		Pandora.load_data()
	var check_only: bool = OS.get_environment("SOUL_METER_DRIFT_CHECK") == "1"
	var result := generate(check_only)
	if check_only:
		if result["drift"]:
			printerr(
				"TACTICAL-GEN: DRIFT — committed artifacts differ from Pandora. Regenerate and commit."
			)
			get_tree().quit(1)
			return
		print("TACTICAL-GEN: no drift.")
	else:
		print(
			(
				"TACTICAL-GEN: wrote %d jobs, %d abilities, and %d units."
				% [result["job_count"], result["ability_count"], result["unit_count"]]
			)
		)
	get_tree().quit()


## Walks the six Pandora roots and builds the runtime lookup.
## Returns {job_count, ability_count, unit_count, drift} — when check_only, nothing is written.
static func generate(check_only: bool = false) -> Dictionary:
	var jobs := _job_rows()
	var abilities := _ability_rows(jobs)
	var units := _unit_rows()
	var unit_jobs := _unit_job_rows(units, jobs, abilities)
	var unit_attunement := _unit_attunement_rows(units)
	var unit_loadout := _unit_loadout_rows(units, jobs, abilities)

	var tables := {
		"jobs": jobs,
		"abilities": abilities,
		"units": units,
		"unit_jobs": unit_jobs,
		"unit_attunement": unit_attunement,
		"unit_loadout": unit_loadout,
	}
	var json_text := JSON.stringify(tables, "  ", false) + "\n"
	var ids_text := _ids_source(jobs, abilities, units)

	var drift := _differs(TABLES_PATH, json_text) or _differs(IDS_PATH, ids_text)
	if not check_only:
		DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path(OUT_DIR))
		_write(TABLES_PATH, json_text)
		_write(IDS_PATH, ids_text)

	return {
		"job_count": jobs.size(),
		"ability_count": abilities.size(),
		"unit_count": units.size(),
		"drift": drift,
	}


# --- table readers ------------------------------------------------------------


static func _job_rows() -> Array:
	var rows: Array = []
	var seen := {}
	for entity: PandoraEntity in _entities("Jobs"):
		var job_id := entity.get_string("Job Id")
		assert(not job_id.is_empty(), "Job is missing Job Id")
		assert(not seen.has(job_id), "Duplicate job id: %s" % job_id)
		assert(StableIds.is_valid(StableIds.ACTOR, job_id), "Job has a malformed id: %s" % job_id)
		seen[job_id] = true
		var element_id := entity.get_string("Element Id")
		assert(_is_valid_element(element_id), "Job '%s' has unknown element '%s'" % [job_id, element_id])
		var tier := entity.get_integer("Tier")
		assert(tier >= 1, "Job '%s' has a tier below 1" % job_id)
		rows.append(
			{
				"id": job_id,
				"display_name": entity.get_string("Display Name"),
				"tier": tier,
				"element_id": element_id,
				"requires_job_id": entity.get_string("Requires Job Id"),
				"growth_hp": entity.get_float("Growth HP"),
				"growth_mp": entity.get_float("Growth MP"),
				"growth_spd": entity.get_float("Growth SPD"),
				"vault_id": entity.get_string("Vault Id"),
			}
		)
	# Prerequisites resolve only once every job is known, so this is a second pass.
	for row: Dictionary in rows:
		var requires: String = row["requires_job_id"]
		assert(
			requires.is_empty() or seen.has(requires),
			"Job '%s' requires unknown job '%s'" % [row["id"], requires]
		)
		assert(requires != row["id"], "Job '%s' requires itself" % row["id"])
	return _sorted_by_id(rows)


static func _ability_rows(jobs: Array) -> Array:
	var job_ids := _id_set(jobs)
	var rows: Array = []
	var seen := {}
	for entity: PandoraEntity in _entities("Abilities"):
		var ability_id := entity.get_string("Ability Id")
		assert(not ability_id.is_empty(), "Ability is missing Ability Id")
		assert(not seen.has(ability_id), "Duplicate ability id: %s" % ability_id)
		assert(
			StableIds.is_valid(StableIds.ACTOR, ability_id),
			"Ability has a malformed id: %s" % ability_id
		)
		seen[ability_id] = true
		var job_id := entity.get_string("Job Id")
		assert(job_ids.has(job_id), "Ability '%s' references unknown job '%s'" % [ability_id, job_id])
		var slot := entity.get_string("Slot")
		assert(
			AbilityDefinition.is_valid_slot(slot),
			"Ability '%s' has invalid slot '%s' (action|reaction|passive)" % [ability_id, slot]
		)
		var element_id := entity.get_string("Element Id")
		assert(
			_is_valid_element(element_id),
			"Ability '%s' has unknown element '%s'" % [ability_id, element_id]
		)
		var ct_cost := entity.get_integer("CT Cost")
		assert(
			ct_cost >= 0 and ct_cost <= CT_READY_AT,
			"Ability '%s' has ct_cost %d outside 0..%d" % [ability_id, ct_cost, CT_READY_AT]
		)
		var mp_cost := entity.get_integer("MP Cost")
		assert(mp_cost >= 0, "Ability '%s' has a negative mp_cost" % ability_id)
		for field in ["Range", "AoE", "Vertical"]:
			assert(
				entity.get_integer(field) >= 0,
				"Ability '%s' has a negative %s" % [ability_id, field]
			)
		rows.append(
			{
				"id": ability_id,
				"display_name": entity.get_string("Display Name"),
				"job_id": job_id,
				"slot": slot,
				"element_id": element_id,
				"power": entity.get_integer("Power"),
				"mp_cost": mp_cost,
				"ct_cost": ct_cost,
				"range": entity.get_integer("Range"),
				"aoe": entity.get_integer("AoE"),
				"vertical": entity.get_integer("Vertical"),
				"vault_id": entity.get_string("Vault Id"),
			}
		)
	return _sorted_by_id(rows)


static func _unit_rows() -> Array:
	var rows: Array = []
	var seen := {}
	for entity: PandoraEntity in _entities("Units"):
		var unit_id := entity.get_string("Unit Id")
		assert(not unit_id.is_empty(), "Unit is missing Unit Id")
		assert(not seen.has(unit_id), "Duplicate unit id: %s" % unit_id)
		assert(StableIds.is_valid(StableIds.ACTOR, unit_id), "Unit has a malformed id: %s" % unit_id)
		seen[unit_id] = true
		for field in ["Base HP", "Base MP", "Base SPD", "Move", "Jump"]:
			assert(entity.get_integer(field) >= 0, "Unit '%s' has a negative %s" % [unit_id, field])
		rows.append(
			{
				"id": unit_id,
				"display_name": entity.get_string("Display Name"),
				"epithet": entity.get_string("Epithet"),
				"base_hp": entity.get_integer("Base HP"),
				"base_mp": entity.get_integer("Base MP"),
				"base_spd": entity.get_integer("Base SPD"),
				"move": entity.get_integer("Move"),
				"jump": entity.get_integer("Jump"),
				"portrait_ref": entity.get_string("Portrait Ref"),
				"vault_id": entity.get_string("Vault Id"),
			}
		)
	return _sorted_by_id(rows)


static func _unit_job_rows(units: Array, jobs: Array, abilities: Array) -> Array:
	var unit_ids := _id_set(units)
	var job_ids := _id_set(jobs)
	var abilities_by_id := {}
	for ability: Dictionary in abilities:
		abilities_by_id[ability["id"]] = ability
	var rows: Array = []
	var seen := {}
	for entity: PandoraEntity in _entities("Unit Jobs"):
		var unit_id := entity.get_string("Unit Id")
		var job_id := entity.get_string("Job Id")
		var key := "%s/%s" % [unit_id, job_id]
		assert(unit_ids.has(unit_id), "Unit job row references unknown unit '%s'" % unit_id)
		assert(job_ids.has(job_id), "Unit job row references unknown job '%s'" % job_id)
		assert(not seen.has(key), "Duplicate unit job row: %s" % key)
		seen[key] = true
		var jp := entity.get_integer("JP")
		assert(jp >= 0, "Unit job row '%s' has negative JP" % key)
		var mastered := _parse_id_array(entity.get_string("Mastered"), key)
		for ability_id: String in mastered:
			assert(
				abilities_by_id.has(ability_id),
				"Unit job row '%s' masters unknown ability '%s'" % [key, ability_id]
			)
			assert(
				abilities_by_id[ability_id]["job_id"] == job_id,
				"Unit job row '%s' masters ability '%s' from another job" % [key, ability_id]
			)
		mastered.sort()
		rows.append({"id": key, "unit_id": unit_id, "job_id": job_id, "jp": jp, "mastered": mastered})
	return _sorted_by_id(rows)


static func _unit_attunement_rows(units: Array) -> Array:
	var unit_ids := _id_set(units)
	var rows: Array = []
	var seen := {}
	for entity: PandoraEntity in _entities("Unit Attunement"):
		var unit_id := entity.get_string("Unit Id")
		var element_id := entity.get_string("Element Id")
		var key := "%s/%s" % [unit_id, element_id]
		assert(unit_ids.has(unit_id), "Attunement row references unknown unit '%s'" % unit_id)
		# The Wheel of Ten is a closed canon set: an eleventh element is never invented.
		assert(
			ElementWheel.index_of(element_id) >= 0,
			"Attunement row '%s' names a non-Wheel element" % key
		)
		assert(not seen.has(key), "Duplicate attunement row: %s" % key)
		seen[key] = true
		var value := entity.get_integer("Value")
		assert(
			value >= UnitAttunement.MIN_VALUE and value <= UnitAttunement.MAX_VALUE,
			"Attunement row '%s' has value %d outside %d..%d"
			% [key, value, UnitAttunement.MIN_VALUE, UnitAttunement.MAX_VALUE]
		)
		rows.append({"id": key, "unit_id": unit_id, "element_id": element_id, "value": value})
	# Attunement is all-or-nothing: a unit with any row must carry all ten, because a
	# partial row set silently reads as "neutral" and hides authoring mistakes.
	var per_unit := {}
	for row: Dictionary in rows:
		per_unit[row["unit_id"]] = int(per_unit.get(row["unit_id"], 0)) + 1
	for unit_id: String in per_unit:
		assert(
			int(per_unit[unit_id]) == ElementWheel.ORDER.size(),
			"Unit '%s' has %d attunement rows; all ten Wheel elements are required"
			% [unit_id, int(per_unit[unit_id])]
		)
	return _sorted_by_id(rows)


static func _unit_loadout_rows(units: Array, jobs: Array, abilities: Array) -> Array:
	var unit_ids := _id_set(units)
	var job_ids := _id_set(jobs)
	var abilities_by_id := {}
	for ability: Dictionary in abilities:
		abilities_by_id[ability["id"]] = ability
	var rows: Array = []
	var seen := {}
	for entity: PandoraEntity in _entities("Unit Loadout"):
		var unit_id := entity.get_string("Unit Id")
		assert(unit_ids.has(unit_id), "Loadout row references unknown unit '%s'" % unit_id)
		assert(not seen.has(unit_id), "Duplicate loadout for unit '%s'" % unit_id)
		seen[unit_id] = true
		var primary := entity.get_string("Primary Job Id")
		var secondary := entity.get_string("Secondary Job Id")
		assert(job_ids.has(primary), "Loadout '%s' has unknown primary job '%s'" % [unit_id, primary])
		assert(
			secondary.is_empty() or job_ids.has(secondary),
			"Loadout '%s' has unknown secondary job '%s'" % [unit_id, secondary]
		)
		assert(secondary != primary, "Loadout '%s' repeats its primary job as secondary" % unit_id)
		var reaction := entity.get_string("Reaction Ability Id")
		var passive := entity.get_string("Passive Ability Id")
		_assert_slot(abilities_by_id, unit_id, reaction, AbilityDefinition.SLOT_REACTION)
		_assert_slot(abilities_by_id, unit_id, passive, AbilityDefinition.SLOT_PASSIVE)
		rows.append(
			{
				"id": unit_id,
				"unit_id": unit_id,
				"primary_job_id": primary,
				"secondary_job_id": secondary,
				"reaction_ability_id": reaction,
				"passive_ability_id": passive,
				"equip": _parse_json_object(entity.get_string("Equip"), unit_id),
			}
		)
	return _sorted_by_id(rows)


static func _assert_slot(
	abilities_by_id: Dictionary, unit_id: String, ability_id: String, slot: StringName
) -> void:
	if ability_id.is_empty():
		return
	assert(
		abilities_by_id.has(ability_id),
		"Loadout '%s' references unknown ability '%s'" % [unit_id, ability_id]
	)
	assert(
		StringName(str(abilities_by_id[ability_id]["slot"])) == slot,
		"Loadout '%s' put ability '%s' in the %s slot" % [unit_id, ability_id, String(slot)]
	)


# --- artifact writers ---------------------------------------------------------


static func _ids_source(jobs: Array, abilities: Array, units: Array) -> String:
	var source := "# %s\n# %s\nclass_name TacticalIds\n" % [GENERATED_HEADER, GENERATED_INSTRUCTION]
	source += _ids_block("JOB", jobs)
	source += _ids_block("ABILITY", abilities)
	source += _ids_block("UNIT", units)
	return source


static func _ids_block(prefix: String, rows: Array) -> String:
	var block := "\n"
	if rows.is_empty():
		# An empty table is the correct shipped state for jobs/abilities while the
		# discipline naming is canon-blocked on GitHub #132.
		return block + "# No %s rows are authored yet.\n" % prefix.to_lower()
	for row: Dictionary in rows:
		var identifier: String = str(row["id"]).to_upper().replace("-", "_").replace("/", "_")
		block += 'const %s_%s := "%s"\n' % [prefix, identifier, row["id"]]
	return block


# --- helpers ------------------------------------------------------------------


static func _entities(root_name: String) -> Array[PandoraEntity]:
	var rows: Array[PandoraEntity] = []
	var root := _root_by_name(root_name)
	if root == null:
		# Missing root means the schema seeder has not run against this data.pandora.
		# Treat it as an empty table so a fresh checkout can still generate.
		push_warning("Pandora has no '%s' root — run tools/seed_tactical_tables.gd" % root_name)
		return rows
	for entity: PandoraEntity in Pandora.get_all_entities(root):
		if entity is PandoraCategory:
			continue
		rows.append(entity)
	return rows


static func _root_by_name(root_name: String) -> PandoraCategory:
	for root: PandoraCategory in Pandora.get_all_roots():
		if root.get_entity_name() == root_name:
			return root
	return null


static func _is_valid_element(element_id: String) -> bool:
	return element_id.is_empty() or ElementWheel.index_of(element_id) >= 0


static func _id_set(rows: Array) -> Dictionary:
	var ids := {}
	for row: Dictionary in rows:
		ids[row["id"]] = true
	return ids


static func _sorted_by_id(rows: Array) -> Array:
	# Deterministic output — required for the drift check.
	rows.sort_custom(func(a: Dictionary, b: Dictionary) -> bool: return str(a["id"]) < str(b["id"]))
	return rows


static func _parse_id_array(raw: String, context: String) -> Array:
	if raw.strip_edges().is_empty():
		return []
	var parsed: Variant = JSON.parse_string(raw)
	assert(parsed is Array, "Malformed JSON array in '%s': %s" % [context, raw])
	var ids: Array = []
	for value: Variant in (parsed as Array):
		ids.append(str(value))
	return ids


static func _parse_json_object(raw: String, context: String) -> Dictionary:
	if raw.strip_edges().is_empty():
		return {}
	var parsed: Variant = JSON.parse_string(raw)
	assert(parsed is Dictionary, "Malformed JSON object in '%s': %s" % [context, raw])
	return parsed


static func _differs(path: String, text: String) -> bool:
	if not FileAccess.file_exists(path):
		return true
	return FileAccess.get_file_as_string(path) != text


static func _write(path: String, text: String) -> void:
	var file := FileAccess.open(path, FileAccess.WRITE)
	assert(file != null, "Could not write generated artifact: %s" % path)
	file.store_string(text)
	file.close()
