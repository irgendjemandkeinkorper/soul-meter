class_name WeftluminCharactersKind
extends WeftluminKind
## The `characters` kind (architecture §4.7, E5.1 / #347): `canon/<hub>/characters/<id>.json`
## documents in the `weftlumin.character.v1` schema, one document kind with a `kind`
## discriminator.
##
## Both discriminators are OPEN REGISTRIES the host declares, not closed enums:
##
## - **Character kinds** (`register_character_kind`): what one kind means — its required fields
##   and their shapes, its optional fields, and whether it must name a lore-vault character on
##   create. `declare_soul_meter()` opens Soul Meter's three: `npc` (Dom's townsfolk; seeds the
##   Pandora NPC category and, through `tools/generate_gloot.gd`, the roster/placement JSON
##   `TownNpcSpawner` reads), `archetype` (a combatant encounters and spawn tables name by id —
##   seeds Combatants) and `recruit` (a recruitable `PartyMember`; required `vault_id`).
## - **Stat schemas** (`register_stat_schema`): who validates a `stats` block. This kind never
##   interprets stats: it checks the block is an object naming a registered schema and hands
##   the block to that schema's validator. `dramgid.v1` is read through `DramgidSchema` (one
##   more reader, no second definition — `docs/architecture-dramgid.md` §3); `six-stat.v1` has
##   no installed definition any more and stays fully opaque.
##
## An undeclared kind or schema is refused: the registry is open, but it opens in the host's
## declaration, not by a typo in a document.
##
## The npc and archetype contracts are the ones `tools/seed_pandora.gd` `CanonReader` enforces
## (a test pins the parity). `recruit` is new here; nothing seeds it yet (see `docs/weftlumin.md`).
##
## `vault_id` is the bridge to the lore vault (§4.3.1): required on create for kinds that
## declare `requires_vault_id`, validated against the vault index through
## `PartyMember.vault_id_refusal`, never renamed once set and never generated. Those are
## create/edit rules (`create_problems`, `edit_problems`) because they need the previous
## document and the vault index; `validate()` stays pure and checks shape only, so canon loads
## where the vault is absent (CI).
##
## `register()` stays the base refusal: there is no live runtime overlay for characters yet.

const SCHEMA := "weftlumin.character.v1"
const BAKE_SCHEMA := "weftlumin.bake.v1"
const CANON_ROOT := "res://canon"
const DEFAULT_HUB := "dom"
## The lore vault sits beside the repository (AGENTS.md); read-only.
const VAULT_INDEX_RELATIVE := "../dramgid-vault/index.json"
const VAULT_CHARACTER_TYPE := "character"
## Load-time-only keys `load_canon()` attaches for error attribution; never written back.
const META_FILE := "$file"
const META_HUB := "$hub"

## Field shapes a contract may name.
const STRING := "string"
const NUMBER := "number"
const NUMBER_PAIR := "number_pair"
const BOOLEAN := "boolean"
const ROUTINE := "routine"
const STATS := "stats"
const ANATOMY := "anatomy"
const BLOCK := "block"

## Every document, whatever its kind: these come first, in this order.
const COMMON_FIELDS: Array[String] = ["schema", "kind", "id", "order", "display_name"]
## Optional on every kind: the portrait and sprite pickers' fields. `sprite_unit_id` is canon
## but not yet read by any seeder (art still resolves by character id); `runtime_notes` says so.
const PICKER_FIELDS: Dictionary = {"portrait_path": STRING, "sprite_unit_id": STRING}
const SAFE_PORTRAIT_EXTENSIONS: Array[String] = ["png", "jpg", "jpeg", "svg", "webp", "tga"]

## Soul Meter's declarations. Field order is the canonical key order of the canon text.
const NPC_CONTRACT: Dictionary = {
	"fields": {
		"epithet": STRING, "bio": STRING, "role": STRING, "home": STRING, "district": STRING,
		"faction_id": STRING, "vault_id": STRING, "portrait_path": STRING,
		"context_line": STRING, "dialogue_hostile": STRING, "dialogue_warm": STRING,
		"placement_anchor": STRING, "placement_offset": NUMBER_PAIR, "routine": ROUTINE,
		"phase_agnostic": BOOLEAN, "involvement": STRING, "hook_summary": STRING,
	},
	"optional": {},
	"requires_vault_id": false,
}
const ARCHETYPE_CONTRACT: Dictionary = {
	"fields": {"element_id": STRING},
	"optional": {"attribute_note": STRING, "stats": STATS, "anatomy": ANATOMY},
	# `stats` is required; it sits in `optional` only to keep the canon key order
	# (element_id, attribute_note, stats, anatomy). `required` lists it.
	"required": ["stats"],
	"requires_vault_id": false,
}
## Spec §4.7: a recruit names its vault character and carries the tavern gate and identity
## block `PartyMember` already has (min_reputation, min_infamy, epithet, background,
## discipline, patron).
const RECRUIT_CONTRACT: Dictionary = {
	"fields": {"vault_id": STRING, "recruit": BLOCK},
	"optional": {"faction_id": STRING, "stats": STATS},
	"blocks": {
		"recruit": {
			"min_reputation": NUMBER, "min_infamy": NUMBER, "epithet": STRING,
			"background": STRING, "discipline": STRING, "patron": STRING,
		},
	},
	"requires_vault_id": true,
}

## Test seams.
var vault_index_path_for_tests: String = ""

var _character_kinds: Dictionary = {}
var _stat_schemas: Dictionary = {}
var _vault_characters: Dictionary = {}
var _vault_loaded: bool = false


func _init() -> void:
	id = &"characters"
	subdir = "characters"
	ext = "json"
	stable_id_kind = &"actor"


## A characters kind carrying Soul Meter's registry declarations.
static func soul_meter() -> WeftluminCharactersKind:
	var kind := WeftluminCharactersKind.new()
	kind.declare_soul_meter()
	return kind


func declare_soul_meter() -> void:
	register_character_kind("npc", NPC_CONTRACT)
	register_character_kind("archetype", ARCHETYPE_CONTRACT)
	register_character_kind("recruit", RECRUIT_CONTRACT)
	register_stat_schema("dramgid.v1", {
		"label": "DRAMGID attributes",
		"fields": DramgidSchema.ATTRIBUTE_IDS,
		"field_label": func(field: String) -> String:
			return DramgidSchema.attribute_label(field) if DramgidSchema.ATTRIBUTES.has(field) else field,
		"validate": _dramgid_problems,
	})
	register_stat_schema("six-stat.v1", {
		"label": "Six-stat (retired build; opaque)",
		"fields": PackedStringArray(),
	})


# --- Registries ----------------------------------------------------------------------------


## Opens a character kind. `contract` = {fields: {name: shape}, optional: {name: shape},
## required?: [optional names that are nonetheless required], blocks?: {block: {name: shape}},
## requires_vault_id: bool}. Refuses an empty name, a reserved field or a duplicate.
func register_character_kind(kind_name: String, contract: Dictionary) -> bool:
	if not _is_stable_id(kind_name) or _character_kinds.has(kind_name):
		return false
	for group: String in ["fields", "optional"]:
		var shapes: Variant = contract.get(group, {})
		if not shapes is Dictionary:
			return false
		for field: Variant in shapes:
			if COMMON_FIELDS.has(String(field)):
				return false
	_character_kinds[kind_name] = contract.duplicate(true)
	return true


## Opens a stat schema. `entry` = {label?, fields?: PackedStringArray (display order),
## field_label?: Callable(String) -> String, validate?: Callable(Dictionary) -> Array[String]}.
## No `validate` = opaque: any object naming the schema passes.
func register_stat_schema(schema_name: String, entry: Dictionary) -> bool:
	if schema_name.strip_edges().is_empty() or _stat_schemas.has(schema_name):
		return false
	_stat_schemas[schema_name] = entry.duplicate()
	return true


func character_kinds() -> Array[String]:
	var names: Array[String] = []
	names.assign(_character_kinds.keys())
	return names


func stat_schemas() -> Array[String]:
	var names: Array[String] = []
	names.assign(_stat_schemas.keys())
	return names


func contract(kind_name: String) -> Dictionary:
	return (_character_kinds.get(kind_name, {}) as Dictionary).duplicate(true)


func requires_vault_id(kind_name: String) -> bool:
	return bool(contract(kind_name).get("requires_vault_id", false))


## Every field a kind's document may carry after the common ones, in canonical order, with its
## shape: the kind's fields, its optional fields, then the picker fields it does not name.
func field_shapes(kind_name: String) -> Dictionary:
	var declared: Dictionary = contract(kind_name)
	var shapes: Dictionary = {}
	shapes.merge(declared.get("fields", {}))
	shapes.merge(declared.get("optional", {}))
	shapes.merge(PICKER_FIELDS)
	return shapes


func is_required(kind_name: String, field: String) -> bool:
	var declared: Dictionary = contract(kind_name)
	return (declared.get("fields", {}) as Dictionary).has(field) or Array(declared.get("required", [])).has(field)


func block_shapes(kind_name: String, block: String) -> Dictionary:
	return ((contract(kind_name).get("blocks", {}) as Dictionary).get(block, {}) as Dictionary).duplicate()


## Display order of a stat block: the schema's declared fields that are present, then any other
## keys the block carries, sorted. Never `schema` itself.
func stat_fields(stats: Dictionary) -> Array[String]:
	var entry: Dictionary = _stat_schemas.get(String(stats.get("schema", "")), {})
	var ordered: Array[String] = []
	for field: String in entry.get("fields", PackedStringArray()):
		ordered.append(field)
	var rest: Array[String] = []
	for key: Variant in stats:
		if String(key) != "schema" and not ordered.has(String(key)):
			rest.append(String(key))
	rest.sort()
	ordered.append_array(rest)
	return ordered


func stat_field_label(schema_name: String, field: String) -> String:
	var entry: Dictionary = _stat_schemas.get(schema_name, {})
	var labeller: Variant = entry.get("field_label")
	return String((labeller as Callable).call(field)) if labeller is Callable else field


func stat_schema_label(schema_name: String) -> String:
	return String((_stat_schemas.get(schema_name, {}) as Dictionary).get("label", schema_name))


## `dramgid.v1`, read through `DramgidSchema`: every attribute the schema defines is present and
## whole. Ranges are not checked — enemies sit outside the party's point-buy floor by design,
## and other keys (`max_hp`, `balance_*`) are the seeder's business, not this editor's.
static func _dramgid_problems(stats: Dictionary) -> Array[String]:
	var problems: Array[String] = []
	for attribute: String in DramgidSchema.ATTRIBUTE_IDS:
		var value: Variant = stats.get(attribute)
		if not (value is float or value is int) or float(value) != floorf(float(value)):
			problems.append("%s: expected a whole number (DramgidSchema attribute)." % attribute)
	return problems


# --- Vault index ---------------------------------------------------------------------------


## The vault's character ids (`type: "character"`), read once from `index.json`. Empty when the
## vault is not beside the repository, which refuses every vault check rather than passing it.
func vault_character_ids() -> Dictionary:
	if _vault_loaded:
		return _vault_characters
	_vault_loaded = true
	_vault_characters = {}
	var path: String = vault_index_path()
	if not FileAccess.file_exists(path):
		return _vault_characters
	var parsed: Variant = JSON.parse_string(FileAccess.get_file_as_string(path))
	if not parsed is Dictionary or not (parsed as Dictionary).get("entities") is Array:
		return _vault_characters
	for entity: Variant in (parsed as Dictionary)["entities"]:
		if entity is Dictionary and String((entity as Dictionary).get("type", "")) == VAULT_CHARACTER_TYPE:
			_vault_characters[String((entity as Dictionary).get("id", ""))] = String((entity as Dictionary).get("name", ""))
	return _vault_characters


func vault_index_path() -> String:
	if not vault_index_path_for_tests.is_empty():
		return vault_index_path_for_tests
	return ProjectSettings.globalize_path("res://").path_join(VAULT_INDEX_RELATIVE).simplify_path()


# --- Discovery -----------------------------------------------------------------------------


## Every `canon/<hub>/characters/*.json` in a stable (hub, filename) order, each tagged with its
## file and hub. Unreadable or non-object files append an attributed error and are skipped.
static func load_canon(errors: Array[Dictionary], canon_root: String = CANON_ROOT) -> Array[Dictionary]:
	var documents: Array[Dictionary] = []
	if not DirAccess.dir_exists_absolute(canon_root):
		errors.append(_error(canon_root, "$", "canon root directory", "missing_canon_root"))
		return documents
	var hubs: PackedStringArray = DirAccess.get_directories_at(canon_root)
	hubs.sort()
	for hub: String in hubs:
		var kind_root: String = canon_root.path_join(hub).path_join("characters")
		if not DirAccess.dir_exists_absolute(kind_root):
			continue
		var filenames: PackedStringArray = DirAccess.get_files_at(kind_root)
		filenames.sort()
		for filename: String in filenames:
			if filename.get_extension().to_lower() != "json":
				continue
			var path: String = kind_root.path_join(filename)
			var parsed: Variant = JSON.parse_string(FileAccess.get_file_as_string(path))
			if not parsed is Dictionary:
				errors.append(_error(path, "$", "one JSON object", "invalid_document"))
				continue
			var document: Dictionary = parsed
			document[META_FILE] = path
			document[META_HUB] = hub
			documents.append(document)
	return documents


# --- Validation ----------------------------------------------------------------------------


## Pure shape validation: returns normalised documents (canonical key order, meta keys kept for
## the bake target), sorted by `order` then id, or an empty array when any error was appended.
func validate(documents: Array[Dictionary], errors: Array[Dictionary]) -> Array[Dictionary]:
	var normalised: Array[Dictionary] = []
	var error_count: int = errors.size()
	var seen_ids: Dictionary = {}
	for index: int in documents.size():
		var document: Dictionary = documents[index]
		var file: String = String(document.get(META_FILE, "characters[%d]" % index))
		var row: Dictionary = _normalise(document, file, errors)
		if row.is_empty():
			continue
		var character_id: String = row["id"]
		if seen_ids.has(character_id):
			errors.append(_error(file, "id", "unique character id", "duplicate_id",
				"Character id '%s' is also declared by %s." % [character_id, seen_ids[character_id]]))
			continue
		seen_ids[character_id] = file
		normalised.append(row)
	if errors.size() != error_count:
		return []
	normalised.sort_custom(func(a: Dictionary, b: Dictionary) -> bool:
		if float(a["order"]) != float(b["order"]):
			return float(a["order"]) < float(b["order"])
		return String(a["id"]) < String(b["id"])
	)
	return normalised


func _normalise(document: Dictionary, file: String, errors: Array[Dictionary]) -> Dictionary:
	var error_count: int = errors.size()
	if document.get("schema") != SCHEMA:
		errors.append(_error(file, "schema", SCHEMA, "unsupported_schema"))
	var character_id: Variant = document.get("id")
	if not character_id is String or not _is_stable_id(character_id):
		errors.append(_error(file, "id", "lower-case stable id ([a-z0-9_-]+)", "invalid_id"))
	var kind_name: String = String(document.get("kind", "")) if document.get("kind") is String else ""
	if not _character_kinds.has(kind_name):
		errors.append(_error(file, "kind", "a declared character kind (%s)" % ", ".join(character_kinds()),
			"unknown_character_kind",
			"Character kind '%s' is not declared by the host." % str(document.get("kind", ""))))
		return {}
	var order: Variant = document.get("order")
	if not (order is float or order is int) or float(order) != floorf(float(order)):
		errors.append(_error(file, "order", "whole number", "invalid_field_type"))
	if not document.get("display_name") is String or String(document["display_name"]).strip_edges().is_empty():
		errors.append(_error(file, "display_name", "non-empty string", "invalid_field_type"))
	var shapes: Dictionary = field_shapes(kind_name)
	for key: Variant in document.keys():
		var field: String = String(key)
		if not COMMON_FIELDS.has(field) and not shapes.has(field) and field != META_FILE and field != META_HUB:
			errors.append(_error(file, field, "a %s field" % kind_name, "unknown_field"))
	var row: Dictionary = {}
	for field: String in COMMON_FIELDS:
		row[field] = document.get(field)
	for field: String in shapes:
		if not document.has(field):
			if is_required(kind_name, field):
				errors.append(_error(file, field, "%s (required for %s)" % [shapes[field], kind_name], "missing_field"))
			continue
		var problem: String = _shape_problem(kind_name, field, shapes[field], document[field])
		if not problem.is_empty():
			errors.append(_error(file, field, shapes[field], "invalid_field_type", "%s: %s" % [field, problem]))
		row[field] = document[field]
	var portrait: Variant = row.get("portrait_path", "")
	if portrait is String and not String(portrait).is_empty() and not is_safe_portrait_path(portrait):
		errors.append(_error(file, "portrait_path", "res:// image path", "invalid_portrait_path"))
	if requires_vault_id(kind_name) and String(row.get("vault_id", "")).is_empty():
		errors.append(_error(file, "vault_id", "the lore-vault character id", "missing_vault_id",
			"A %s must name its lore-vault character (vault_id); it is never generated." % kind_name))
	for meta: String in [META_FILE, META_HUB]:
		if document.has(meta):
			row[meta] = document[meta]
	return row if errors.size() == error_count else {}


func _shape_problem(kind_name: String, field: String, shape: String, value: Variant) -> String:
	match shape:
		STRING:
			return "" if value is String else "expected a string"
		NUMBER:
			return "" if value is float or value is int else "expected a number"
		BOOLEAN:
			return "" if value is bool else "expected true or false"
		NUMBER_PAIR:
			if value is Array and (value as Array).size() == 2:
				for component: Variant in value:
					if not (component is float or component is int):
						return "expected two numbers"
				return ""
			return "expected [x, y]"
		ROUTINE:
			return _routine_problem(value)
		ANATOMY:
			return _anatomy_problem(value)
		STATS:
			return stats_problem(value)
		BLOCK:
			if not value is Dictionary:
				return "expected an object"
			var shapes: Dictionary = block_shapes(kind_name, field)
			var problems: Array[String] = []
			for key: Variant in value:
				if not shapes.has(String(key)):
					problems.append("%s is not a %s.%s field" % [key, kind_name, field])
			for key: String in shapes:
				if not (value as Dictionary).has(key):
					problems.append("%s is missing" % key)
				else:
					var inner: String = _shape_problem(kind_name, key, shapes[key], value[key])
					if not inner.is_empty():
						problems.append("%s %s" % [key, inner])
			return "; ".join(problems)
	return "unknown shape '%s'" % shape


## Opaque by contract: an object naming a declared schema, then whatever that schema's own
## validator says. Returns "" when the block passes.
func stats_problem(value: Variant) -> String:
	if not value is Dictionary:
		return "expected an object"
	var schema: Variant = (value as Dictionary).get("schema")
	if not schema is String or String(schema).strip_edges().is_empty():
		return "needs a non-empty 'schema' naming who validates it"
	if not _stat_schemas.has(schema):
		return "stat schema '%s' is not declared by the host (%s)" % [schema, ", ".join(stat_schemas())]
	var validator: Variant = (_stat_schemas[schema] as Dictionary).get("validate")
	if validator is Callable:
		var problems: Array = (validator as Callable).call(value)
		return "; ".join(PackedStringArray(problems))
	return ""


## FR-504a routine SHAPE only (as `CanonReader` checks it): phase → null or
## {position: [x, y], state: string}. Phase names and caps are `NpcRoutines`' rules.
static func _routine_problem(value: Variant) -> String:
	if not value is Dictionary:
		return "expected an object of phase → null | {position, state}"
	for phase: Variant in value:
		var slot: Variant = value[phase]
		if slot == null:
			continue
		if not slot is Dictionary:
			return "%s must be null or an object" % phase
		var position: Variant = (slot as Dictionary).get("position")
		if not position is Array or (position as Array).size() != 2:
			return "%s.position must be [x, y]" % phase
		if not (slot as Dictionary).get("state") is String or String(slot["state"]).is_empty():
			return "%s.state must be a non-empty string" % phase
	return ""


## Anatomy SHAPE (as `CanonReader` checks it): location id → {display_name, exposed?, hidden_by_cover?}.
static func _anatomy_problem(value: Variant) -> String:
	if not value is Dictionary:
		return "expected an object of location → part"
	for location: Variant in value:
		var part: Variant = value[location]
		if not part is Dictionary or not (part as Dictionary).get("display_name") is String:
			return "%s needs a string display_name" % location
		for flag: String in ["exposed", "hidden_by_cover"]:
			if (part as Dictionary).has(flag) and not part[flag] is bool:
				return "%s.%s must be true or false" % [location, flag]
	return ""


static func is_safe_portrait_path(path: String) -> bool:
	return path.begins_with("res://") and not path.contains("..") \
		and SAFE_PORTRAIT_EXTENSIONS.has(path.get_extension().to_lower())


# --- Create / edit rules (vault_id) --------------------------------------------------------


## Problems with creating `document` next to `existing` (normalised rows). Adds the vault rules
## to `validate()`'s shape check: a kind that requires a vault_id gets one that the vault index
## names as a character; any other non-empty vault_id is checked the same way.
func create_problems(document: Dictionary, existing: Array[Dictionary]) -> Array[Dictionary]:
	var errors: Array[Dictionary] = []
	var file: String = String(document.get(META_FILE, String(document.get("id", ""))))
	for row: Dictionary in existing:
		if row["id"] == document.get("id"):
			errors.append(_error(file, "id", "an id no character uses", "duplicate_id",
				"Character id '%s' already exists." % row["id"]))
	var batch: Array[Dictionary] = [document]
	validate(batch, errors)
	if not errors.is_empty():
		return errors
	var kind_name: String = document["kind"]
	var vault_id: String = String(document.get("vault_id", ""))
	if requires_vault_id(kind_name) or not vault_id.is_empty():
		var refusal: String = PartyMember.vault_id_refusal(vault_id, vault_character_ids())
		if not refusal.is_empty():
			errors.append(_error(file, "vault_id", "a lore-vault character id", "invalid_vault_id", refusal))
	return errors


## Problems with replacing `previous` by `next`. Identity (`id`, `kind`, `schema`) is fixed, and
## a vault_id once set is never renamed; linking an empty one is checked like a create.
func edit_problems(previous: Dictionary, next: Dictionary) -> Array[Dictionary]:
	var errors: Array[Dictionary] = []
	var file: String = String(previous.get(META_FILE, String(previous.get("id", ""))))
	for field: String in ["id", "kind", "schema"]:
		if previous.get(field) != next.get(field):
			errors.append(_error(file, field, "unchanged %s" % field, "identity_change",
				"%s is identity; it cannot change on an existing character." % field))
	if not errors.is_empty():
		return errors
	var batch: Array[Dictionary] = [next]
	validate(batch, errors)
	if not errors.is_empty():
		return errors
	var before: String = String(previous.get("vault_id", ""))
	var after: String = String(next.get("vault_id", ""))
	if not before.is_empty() and after != before:
		errors.append(_error(file, "vault_id", "unchanged vault_id '%s'" % before, "vault_id_rename",
			"vault_id is the bridge to the lore vault; '%s' is never renamed." % before))
	elif before.is_empty() and not after.is_empty():
		var refusal: String = PartyMember.vault_id_refusal(after, vault_character_ids())
		if not refusal.is_empty():
			errors.append(_error(file, "vault_id", "a lore-vault character id", "invalid_vault_id", refusal))
	return errors


## A new document of `kind_name` with every required field present and empty (strings ""),
## zero, false, `{}` routines, and a stats block naming the first declared schema. Carries the
## caller's id, display name and vault_id verbatim — nothing here fills a vault_id in.
func skeleton(kind_name: String, character_id: String, display_name: String, vault_id: String, order: int) -> Dictionary:
	var document: Dictionary = {
		"schema": SCHEMA, "kind": kind_name, "id": character_id, "order": order,
		"display_name": display_name,
	}
	var shapes: Dictionary = field_shapes(kind_name)
	for field: String in shapes:
		if not is_required(kind_name, field) and field != "vault_id":
			continue
		document[field] = _empty_value(kind_name, field, shapes[field])
	if shapes.has("vault_id"):
		document["vault_id"] = vault_id
	return document


func _empty_value(kind_name: String, field: String, shape: String) -> Variant:
	match shape:
		NUMBER:
			return 0
		NUMBER_PAIR:
			return [0, 0]
		BOOLEAN:
			return false
		ROUTINE, ANATOMY:
			return {}
		STATS:
			var schemas: Array[String] = stat_schemas()
			return {"schema": schemas[0] if not schemas.is_empty() else ""}
		BLOCK:
			var block: Dictionary = {}
			var shapes: Dictionary = block_shapes(kind_name, field)
			for key: String in shapes:
				block[key] = _empty_value(kind_name, key, shapes[key])
			return block
	return ""


## Non-blocking authoring notes for one normalised document.
func runtime_notes(row: Dictionary) -> Array[String]:
	var notes: Array[String] = []
	var kind_name: String = String(row.get("kind", ""))
	if row.has("sprite_unit_id") and String(row["sprite_unit_id"]) != String(row.get("id", "")):
		notes.append("sprite_unit_id is canon, but seeders still resolve art by the character id.")
	if kind_name == "recruit":
		notes.append("Recruits are not seeded yet: the tavern roster is still GameState.recruitable_candidates().")
	if row.has("stats") and (row["stats"] as Dictionary).get("schema") == "six-stat.v1":
		notes.append("six-stat.v1 is the retired build; nothing reads it.")
	return notes


static func _is_stable_id(value: String) -> bool:
	if value.is_empty():
		return false
	for character: String in value:
		if not (character in "abcdefghijklmnopqrstuvwxyz0123456789_-"):
			return false
	return true


static func _error(file: String, field: String, expected: String, code: String, message: String = "") -> Dictionary:
	return {
		"file": file, "field": field, "expected": expected, "code": code,
		"message": message if not message.is_empty() else "%s: expected %s." % [field, expected],
	}


# --- Diff ----------------------------------------------------------------------------------


func diff(previous: Array[Dictionary], next: Array[Dictionary]) -> Dictionary:
	var before: Dictionary = {}
	for row: Dictionary in previous:
		before[row["id"]] = row
	var added: Array[String] = []
	var modified: Array[String] = []
	var removed: Array[String] = []
	var after_ids: Dictionary = {}
	for row: Dictionary in next:
		after_ids[row["id"]] = true
		if not before.has(row["id"]):
			added.append(row["id"])
		elif not same_content(before[row["id"]], row):
			modified.append(row["id"])
	for character_id: String in before:
		if not after_ids.has(character_id):
			removed.append(character_id)
	return {
		"changed": not (added.is_empty() and modified.is_empty() and removed.is_empty()),
		"added": added, "modified": modified, "removed": removed,
	}


## Semantic equality, meta keys aside. Authored files differ in escapes, trailing newlines,
## number spelling and key order, none of which is content.
static func same_content(a: Dictionary, b: Dictionary) -> bool:
	return _integral(_without_meta(a)) == _integral(_without_meta(b))


static func _without_meta(row: Dictionary) -> Dictionary:
	var clean: Dictionary = row.duplicate(true)
	clean.erase(META_FILE)
	clean.erase(META_HUB)
	return clean


# --- Text forms ----------------------------------------------------------------------------


## The canonical on-disk form of one character document: compact JSON in the document's key
## order (normalised rows are already canonical), whole numbers written as integers, meta keys
## dropped, one trailing newline.
static func canon_text(row: Dictionary) -> String:
	var clean: Dictionary = {}
	for key: Variant in row:
		if String(key) != META_FILE and String(key) != META_HUB:
			clean[key] = _integral(row[key])
	return JSON.stringify(clean, "", false) + "\n"


static func _integral(value: Variant) -> Variant:
	if value is float and is_finite(value) and float(value) == floorf(float(value)) and absf(value) < 9.0e15:
		return int(value)
	if value is Array:
		var result: Array = []
		for entry: Variant in value:
			result.append(_integral(entry))
		return result
	if value is Dictionary:
		var result: Dictionary = {}
		for key: Variant in value:
			result[key] = _integral(value[key])
		return result
	return value


## Where a normalised row bakes to: its own file when it came from canon, otherwise
## `canon/<hub>/characters/<id>.json` (the default hub when it names none).
static func canon_path(row: Dictionary) -> String:
	var file: String = String(row.get(META_FILE, ""))
	if file.begins_with(CANON_ROOT + "/"):
		return file
	var hub: String = String(row.get(META_HUB, DEFAULT_HUB))
	return CANON_ROOT.path_join(hub).path_join("characters").path_join("%s.json" % row["id"])


# --- Bake ----------------------------------------------------------------------------------


## `weftlumin.bake.v1` report over the canon documents themselves: a document whose content
## differs from its file plans `update`, a new one `create`. When an `npc` row changes, the
## generated roster/placements are listed under `regenerated` (`tools/generate_gloot.gd` emits
## them from canon). `target_root` re-roots every `res://` path; `write` writes changed
## documents. `force` has no effect. A canon file no row explains is an orphan, never deleted.
func bake(normalised: Array[Dictionary], target_root: String, write: bool, force: bool) -> Dictionary:
	var _unused_force: bool = force
	var report: Dictionary = {
		"schema": BAKE_SCHEMA, "package": "canon", "mode": "write" if write else "report",
		"planned": [], "written": [], "regenerated": [], "orphans": [],
		"lint": {"errors": 0, "warnings": 0, "pot_delta": []},
		"refused_overlap": [], "errors": [], "summary": "",
	}
	var changed: int = 0
	var npc_changed: bool = false
	var paths: Dictionary = {}
	for row: Dictionary in normalised:
		var path: String = canon_path(row)
		paths[path] = true
		var target: String = _retarget(path, target_root)
		var action: String = "unchanged"
		if not FileAccess.file_exists(target):
			action = "create"
		else:
			var parsed: Variant = JSON.parse_string(FileAccess.get_file_as_string(target))
			if not parsed is Dictionary or not same_content(parsed, row):
				action = "update"
		(report["planned"] as Array).append({"kind": String(id), "path": path, "action": action, "id": row["id"]})
		(report["lint"] as Dictionary)["warnings"] = int(report["lint"]["warnings"]) + runtime_notes(row).size()
		if action == "unchanged":
			continue
		changed += 1
		npc_changed = npc_changed or row["kind"] == "npc"
		if write:
			DirAccess.make_dir_recursive_absolute(target.get_base_dir())
			var file := FileAccess.open(target, FileAccess.WRITE)
			if file == null:
				(report["errors"] as Array).append(_error(path, "$", "writable document", "write_failed"))
				continue
			file.store_string(canon_text(row))
			file.close()
			(report["written"] as Array).append(path)
	if npc_changed:
		report["regenerated"] = [
			"res://data/generated/dom_npc_roster.json", "res://data/generated/dom_npc_placements.json",
		]
	var orphan_errors: Array[Dictionary] = []
	for document: Dictionary in load_canon(orphan_errors, _retarget(CANON_ROOT, target_root)):
		var logical: String = CANON_ROOT.path_join(String(document[META_HUB])).path_join("characters") \
			.path_join(String(document[META_FILE]).get_file())
		if not paths.has(logical):
			(report["orphans"] as Array).append(logical)
	report["summary"] = "%d characters, %d changed, %d orphaned" % [
		normalised.size(), changed, (report["orphans"] as Array).size(),
	]
	return report


## True when canon fully explains itself (every row unchanged, nothing orphaned or failing).
static func report_is_clean(report: Dictionary) -> bool:
	if not (report.get("errors", []) as Array).is_empty() or not (report.get("orphans", []) as Array).is_empty():
		return false
	for entry: Dictionary in report.get("planned", []):
		if entry["action"] != "unchanged":
			return false
	return true


static func _retarget(path: String, target_root: String) -> String:
	if target_root.is_empty() or target_root == "res://":
		return path
	return target_root.path_join(path.trim_prefix("res://"))
