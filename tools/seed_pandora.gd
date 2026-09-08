extends Node
## seed_pandora.gd — one-shot seeder for the Pandora category trees (install-order step 4).
## Run headless: register as a temp autoload, run once, remove (see DEPENDENCIES.md).
## Idempotent: existing roots are updated by stable id. Data lands in res://data.pandora.
##
## Canon source: ~/projects/dramgid-vault (the lore vault). Entities carry a `Vault Id`
## property bridging back to the vault entity so dialogue/code can query canon.
## res://canon is canonical for migrated game data; Pandora remains the runtime database.
## Placeholder spells/effects are flagged `Placeholder = true` — mechanics, not canon.

var _cats := {}

## Item sub-categories, in creation order. These are Pandora tree structure rather than canon:
## an item document names one by this exact display name, and `_item_categories_exist()`
## refuses an unknown one before anything is written. The order is fixed here because on an
## empty database it decides the generated category ids, and deriving it from whichever item
## document happened to sort first would make a fresh seed disagree with the committed one.
const ITEM_CATEGORIES := ["Weapons", "Relics", "Tools", "Consumables", "Materials"]


class CanonReader:
	const CANON_ROOT := "res://canon"

	## Per-kind contract. A kind listed here is validated and must produce at least one
	## document; a kind that is not is read verbatim, so a later E1.4 migration can land its
	## documents before its schema is settled without this file blocking it.
	##
	## `ordered` kinds carry an integer `order` and are returned in it. The wheel is a ring and
	## its rotation is canon — ring distance and the clash pairs are read off it — so that order
	## must not be an accident of how the files happen to sort.
	##
	## `integers`, `numbers` and `vector2is` name non-string fields. JSON has a single number
	## type, so `integers` and `numbers` are validated identically and differ only in what the
	## seeder writes into Pandora — an int property against a float one. `vector2is` are authored
	## as a two-number array, `[width, height]`.
	##
	## `kinds` scopes the contract by the document's own `kind` discriminator (spec
	## §4.7, ruling 5): the top-level `fields` are what EVERY document of the kind must
	## carry, and the per-kind block adds what only that kind means. An archetype has no
	## district and an npc has no stat block, and demanding either of the other is how a
	## flat field list quietly forces empty strings into canon. An unknown `kind` is
	## refused — the registry is open, but it is opened here, not by a typo.
	##
	## `stat_blocks` name OPAQUE blocks: the reader checks the block is an object carrying
	## a non-empty `schema` string and looks no further. Which schemas exist and what they
	## require belongs to whoever installs them (`six-stat.v1` today, `dramgid.v1` after
	## #283); this file must not grow a second opinion about combat stats.
	##
	## `string_lists` name arrays of non-empty strings. `outcomes` name consequence blocks —
	## `null` (this side of the encounter writes no ledger row) or
	## `{"faction": s, "delta": n, "cause": s}`. `refused` names fields a document must NOT
	## carry: an encounter owns no `grid` and no `weather_default` (F0 D8 — the grid derives
	## from field tiles and weather is per location), and a refused field is caught here
	## rather than silently ignored by a seeder that never reads it.
	##
	## `booleans` name required `true`/`false` fields. `routines` name FR-504a routine maps
	## (issue #385): phase name -> `null` (declared absent) or
	## `{"position": [x, y], "state": "<state>"}`, with `{}` meaning "no routine, FR-504
	## flag/rep reactivity applies". The reader validates the SHAPE only; which phase names
	## are legal and how many routines a hub may carry belong to `NpcRoutines`, which owns
	## the FR-504a rules and is the runtime reader of this field.
	const SCHEMAS := {
		"factions": {
			"noun": "faction",
			"schema": "weftlumin.faction.v1",
			"fields": ["id", "display_name", "summary", "seat", "vault_id"],
		},
		"elements": {
			"noun": "element",
			"schema": "weftlumin.element.v1",
			"fields": ["id", "display_name", "clash"],
			"ordered": true,
		},
		"classes": {
			"noun": "class",
			"schema": "weftlumin.class.v1",
			"fields": ["id", "display_name", "patron", "resource_name", "vault_id"],
		},
		"spells": {
			"noun": "spell",
			"schema": "weftlumin.spell.v1",
			"fields": ["id", "display_name", "description", "element"],
			"integers": ["soul_cost"],
		},
		"effects": {
			"noun": "effect",
			"schema": "weftlumin.effect.v1",
			"fields": ["id", "display_name", "description", "duration_type"],
		},
		"characters": {
			"noun": "character",
			"schema": "weftlumin.character.v1",
			"fields": ["id", "kind", "display_name"],
			"ordered": true,
			"kinds": {
				"npc": {
					"fields": [
						"epithet", "bio", "role", "home", "district", "faction_id", "vault_id",
						"portrait_path", "context_line", "dialogue_hostile", "dialogue_warm",
						"placement_anchor", "involvement", "hook_summary",
					],
					"number_pairs": ["placement_offset"],
					"booleans": ["phase_agnostic"],
					"routines": ["routine"],
				},
				"archetype": {
					"fields": ["element_id"],
					"stat_blocks": ["stats"],
				},
			},
		},
		"encounters": {
			"noun": "encounter",
			"schema": "weftlumin.encounter.v1",
			"fields": ["id", "display_name", "defeated_flag"],
			"ordered": true,
			"string_lists": ["archetype_ids"],
			"outcomes": ["win", "loss"],
			"refused": ["grid", "weather_default"],
		},
		"items": {
			"noun": "item",
			"schema": "weftlumin.item.v1",
			"fields": [
				"id", "display_name", "category", "description", "equip_slot", "rarity",
				"flavour",
			],
			"integers": ["max_stack_size"],
			"numbers": ["weight"],
			"number_pairs": ["grid_size"],
		},
		"locations": {
			"noun": "location",
			"schema": "weftlumin.location.v1",
			"fields": ["id", "display_name", "epithet", "patron", "agreement", "vault_id"],
		},
		"lore": {
			"noun": "lore entry",
			"schema": "weftlumin.lore.v1",
			"fields": ["id", "display_name", "summary", "vault_id", "vault_path"],
		},
		"peoples": {
			"noun": "people",
			"schema": "weftlumin.people.v1",
			"fields": ["id", "display_name", "analogue", "homeland", "vault_id"],
		},
	}

	static func load(kind: String, canon_root: String = CANON_ROOT) -> Array[Dictionary]:
		var documents: Array[Dictionary] = []
		var stable_ids: Dictionary = {}
		if kind.is_empty() or kind.contains("/") or kind.contains("\\") or kind.contains(".."):
			push_error("CANON-SEED: invalid kind '%s'." % kind)
			return documents

		var hubs: PackedStringArray = []
		if DirAccess.dir_exists_absolute(canon_root):
			hubs = DirAccess.get_directories_at(canon_root)
		hubs.sort()
		for hub: String in hubs:
			var kind_root: String = canon_root.path_join(hub).path_join(kind)
			if not DirAccess.dir_exists_absolute(kind_root):
				continue
			var filenames: PackedStringArray = DirAccess.get_files_at(kind_root)
			filenames.sort()
			for filename: String in filenames:
				if filename.get_extension().to_lower() != "json":
					continue
				var document_path: String = kind_root.path_join(filename)
				var file: FileAccess = FileAccess.open(document_path, FileAccess.READ)
				if file == null:
					push_error("CANON-SEED: could not read %s." % document_path)
					return []
				var text: String = file.get_as_text()
				file.close()
				var parser := JSON.new()
				if parser.parse(text) != OK or typeof(parser.data) != TYPE_DICTIONARY:
					push_error("CANON-SEED: %s must contain one JSON object." % document_path)
					return []
				var row: Dictionary = parser.data
				if SCHEMAS.has(kind):
					if not _valid(kind, row, document_path, stable_ids):
						return []
					stable_ids[row["id"]] = true
				documents.append(row)
		if SCHEMAS.has(kind):
			if documents.is_empty():
				push_error(
					"CANON-SEED: no %s documents found in %s."
					% [SCHEMAS[kind]["noun"], canon_root]
				)
				return documents
			if bool(SCHEMAS[kind].get("ordered", false)):
				documents.sort_custom(func(first: Dictionary, second: Dictionary) -> bool:
					return int(first.get("order", 0)) < int(second.get("order", 0))
				)
			if kind == "elements" and not _clashes_are_symmetric(documents):
				return []
		return documents

	static func _valid(
		kind: String, row: Dictionary, document_path: String, stable_ids: Dictionary
	) -> bool:
		var contract: Dictionary = SCHEMAS[kind]
		var noun: String = contract["noun"]
		var scoped: Dictionary = _kind_contract(contract, row, document_path, noun)
		if scoped.has("__refused__"):
			return false
		var fields: Array = (
			["schema"] + Array(contract["fields"]) + Array(scoped.get("fields", []))
		)
		for field: String in fields:
			if typeof(row.get(field)) != TYPE_STRING:
				push_error("CANON-SEED: %s requires string '%s'." % [document_path, field])
				return false
		if row["schema"] != contract["schema"]:
			push_error("CANON-SEED: unsupported %s schema in %s." % [noun, document_path])
			return false
		if String(row["id"]).strip_edges().is_empty():
			push_error("CANON-SEED: empty %s id in %s." % [noun, document_path])
			return false
		if stable_ids.has(row["id"]):
			push_error(
				"CANON-SEED: duplicate %s id '%s' in %s." % [noun, row["id"], document_path]
			)
			return false
		if bool(contract.get("ordered", false)) and typeof(row.get("order")) != TYPE_FLOAT:
			# JSON has one number type, so an authored integer arrives as a float.
			push_error("CANON-SEED: %s requires numeric 'order'." % document_path)
			return false
		for field: String in Array(contract.get("integers", [])) + Array(
			contract.get("numbers", [])
		) + Array(scoped.get("integers", [])) + Array(scoped.get("numbers", [])):
			if typeof(row.get(field)) != TYPE_FLOAT:
				push_error("CANON-SEED: %s requires numeric '%s'." % [document_path, field])
				return false
		for field: String in Array(contract.get("number_pairs", [])) + Array(
			scoped.get("number_pairs", [])
		):
			var pair: Variant = row.get(field)
			if typeof(pair) != TYPE_ARRAY or (pair as Array).size() != 2:
				push_error(
					"CANON-SEED: %s requires '%s' as a two-number array." % [document_path, field]
				)
				return false
			for component: Variant in pair as Array:
				if typeof(component) != TYPE_FLOAT:
					push_error(
						"CANON-SEED: %s has a non-numeric '%s' component."
						% [document_path, field]
					)
					return false
		for field: String in Array(contract.get("booleans", [])) + Array(
			scoped.get("booleans", [])
		):
			if typeof(row.get(field)) != TYPE_BOOL:
				push_error("CANON-SEED: %s requires boolean '%s'." % [document_path, field])
				return false
		for field: String in Array(contract.get("routines", [])) + Array(
			scoped.get("routines", [])
		):
			if not _valid_routine(row.get(field), field, document_path):
				return false
		for field: String in Array(contract.get("string_lists", [])) + Array(
			scoped.get("string_lists", [])
		):
			if not _valid_string_list(row.get(field), field, document_path):
				return false
		for field: String in Array(contract.get("outcomes", [])) + Array(
			scoped.get("outcomes", [])
		):
			if not _valid_outcome(row.get(field), field, document_path):
				return false
		for field: String in Array(contract.get("stat_blocks", [])) + Array(
			scoped.get("stat_blocks", [])
		):
			if not _valid_stat_block(row.get(field), field, document_path):
				return false
		for field: String in Array(contract.get("refused", [])) + Array(
			scoped.get("refused", [])
		):
			if row.has(field):
				push_error(
					"CANON-SEED: %s must not carry '%s' — an encounter owns no grid and no "
					% [document_path, field]
					+ "weather (F0 D8: the grid derives from field tiles, weather is per location)."
				)
				return false
		return true


	## The kind-scoped half of the contract. Returns the merged sub-contract, or an empty
	## dictionary when the document declares a kind the schema does not open.
	static func _kind_contract(
		contract: Dictionary, row: Dictionary, document_path: String, noun: String
	) -> Dictionary:
		var kinds: Dictionary = contract.get("kinds", {})
		if kinds.is_empty():
			return {}
		var declared: String = String(row.get("kind", ""))
		if not kinds.has(declared):
			push_error(
				"CANON-SEED: %s declares %s kind '%s', which this schema does not open."
				% [document_path, noun, declared]
			)
			return {"__refused__": true}
		return kinds[declared]


	## Opaque by contract: an object with a non-empty `schema` string, and nothing more is
	## asked of it. See the `stat_blocks` note on SCHEMAS for why this reader stops here.
	static func _valid_stat_block(value: Variant, field: String, document_path: String) -> bool:
		if typeof(value) != TYPE_DICTIONARY:
			push_error("CANON-SEED: %s requires '%s' as an object." % [document_path, field])
			return false
		var schema: Variant = (value as Dictionary).get("schema")
		if typeof(schema) != TYPE_STRING or String(schema).strip_edges().is_empty():
			push_error(
				"CANON-SEED: %s '%s' needs a non-empty 'schema' naming who validates it."
				% [document_path, field]
			)
			return false
		return true


	static func _valid_string_list(value: Variant, field: String, document_path: String) -> bool:
		if typeof(value) != TYPE_ARRAY or (value as Array).is_empty():
			push_error(
				"CANON-SEED: %s requires '%s' as a non-empty array." % [document_path, field]
			)
			return false
		for entry: Variant in value as Array:
			if typeof(entry) != TYPE_STRING or String(entry).strip_edges().is_empty():
				push_error(
					"CANON-SEED: %s has an empty or non-string '%s' entry."
					% [document_path, field]
				)
				return false
		return true


	## `null` is the authored way to say "this side writes no ledger row" — the same
	## explicit-absence rule the routine reader keeps, and for the same reason: a missing
	## key cannot be told apart from an oversight.
	static func _valid_outcome(value: Variant, field: String, document_path: String) -> bool:
		if value == null:
			return true
		if typeof(value) != TYPE_DICTIONARY:
			push_error(
				"CANON-SEED: %s '%s' must be null or an object." % [document_path, field]
			)
			return false
		var row: Dictionary = value
		for text_field: String in ["faction", "cause"]:
			if typeof(row.get(text_field)) != TYPE_STRING:
				push_error(
					"CANON-SEED: %s '%s' requires string '%s'."
					% [document_path, field, text_field]
				)
				return false
		if typeof(row.get("delta")) != TYPE_FLOAT:
			push_error("CANON-SEED: %s '%s' requires numeric 'delta'." % [document_path, field])
			return false
		if String(row["faction"]).strip_edges().is_empty():
			push_error(
				"CANON-SEED: %s '%s' names no faction — write null, not an empty one."
				% [document_path, field]
			)
			return false
		return true


	## A routine map is `phase -> null | {"position": [x, y], "state": "<state>"}`. An empty
	## map is the common case: it means the character has no routine at all. Absence inside a
	## routine must be the explicit `null` row, never a missing key — FR-504a §5 criterion 4
	## draws that line, and this reader will not let a document blur it into "nowhere".
	static func _valid_routine(value: Variant, field: String, document_path: String) -> bool:
		if typeof(value) != TYPE_DICTIONARY:
			push_error("CANON-SEED: %s requires '%s' as an object." % [document_path, field])
			return false
		for phase: Variant in value as Dictionary:
			if typeof(phase) != TYPE_STRING:
				push_error(
					"CANON-SEED: %s has a non-string '%s' phase name." % [document_path, field]
				)
				return false
			var placement: Variant = (value as Dictionary)[phase]
			if placement == null:
				continue
			if typeof(placement) != TYPE_DICTIONARY:
				push_error(
					"CANON-SEED: %s '%s' phase '%s' must be null or an object."
					% [document_path, field, phase]
				)
				return false
			var row: Dictionary = placement
			var position: Variant = row.get("position")
			if typeof(position) != TYPE_ARRAY or (position as Array).size() != 2:
				push_error(
					"CANON-SEED: %s '%s' phase '%s' needs a two-number 'position'."
					% [document_path, field, phase]
				)
				return false
			for component: Variant in position as Array:
				if typeof(component) != TYPE_FLOAT:
					push_error(
						"CANON-SEED: %s '%s' phase '%s' has a non-numeric position component."
						% [document_path, field, phase]
					)
					return false
			if typeof(row.get("state")) != TYPE_STRING or String(row["state"]).is_empty():
				push_error(
					"CANON-SEED: %s '%s' phase '%s' needs a non-empty 'state'."
					% [document_path, field, phase]
				)
				return false
		return true

	## The wheel's oppositions are canon and symmetric (§ vault systems/magic-system.md). Two
	## documents can each name a clash independently, so a rename that touched only one side
	## would otherwise seed a half-broken wheel and only surface as a wrong matrix in combat.
	static func _clashes_are_symmetric(documents: Array[Dictionary]) -> bool:
		var clash_by_id: Dictionary = {}
		for row: Dictionary in documents:
			clash_by_id[row["id"]] = row["clash"]
		for element_id: String in clash_by_id:
			var opposite: String = clash_by_id[element_id]
			if not clash_by_id.has(opposite):
				push_error(
					"CANON-SEED: element '%s' clashes with unknown '%s'."
					% [element_id, opposite]
				)
				return false
			if String(clash_by_id[opposite]) != element_id:
				push_error(
					(
						"CANON-SEED: clash is not symmetric — '%s' names '%s', which names '%s'."
					)
					% [element_id, opposite, clash_by_id[opposite]]
				)
				return false
		return true


func _ready() -> void:
	await get_tree().process_frame
	if not Pandora.is_loaded():
		Pandora.load_data()
	var drift_check: bool = OS.get_environment("SOUL_METER_DRIFT_CHECK") == "1"
	var before_data: String = ""
	var before_ids: String = ""
	if drift_check:
		before_data = JSON.stringify(Pandora._entity_backend.save_data())
		before_ids = JSON.stringify(Pandora._id_generator.save_data())
	if not _seed_from_canon():
		get_tree().quit(1)
		return
	if drift_check:
		if (
			JSON.stringify(Pandora._entity_backend.save_data()) != before_data
			or JSON.stringify(Pandora._id_generator.save_data()) != before_ids
		):
			push_error("CANON-SEED: drift detected. Re-seed Pandora from canon before committing.")
			get_tree().quit(1)
			return
		print("CANON-SEED: no drift.")
		get_tree().quit()
		return
	Pandora.save_data()
	print("SEED: done — roots=", Pandora.get_all_roots().size())
	get_tree().quit()


func _seed_from_canon(canon_root: String = CanonReader.CANON_ROOT) -> bool:
	# Preflight once before even the empty-database bootstrap can create roots.
	var factions: Array[Dictionary] = CanonReader.load("factions", canon_root)
	if factions.is_empty() or not _faction_ids_are_unambiguous(factions):
		return false
	var elements: Array[Dictionary] = CanonReader.load("elements", canon_root)
	var classes: Array[Dictionary] = CanonReader.load("classes", canon_root)
	var peoples: Array[Dictionary] = CanonReader.load("peoples", canon_root)
	var items: Array[Dictionary] = CanonReader.load("items", canon_root)
	var spells: Array[Dictionary] = CanonReader.load("spells", canon_root)
	var effects: Array[Dictionary] = CanonReader.load("effects", canon_root)
	var locations: Array[Dictionary] = CanonReader.load("locations", canon_root)
	var lore: Array[Dictionary] = CanonReader.load("lore", canon_root)
	var characters: Array[Dictionary] = CanonReader.load("characters", canon_root)
	var archetypes: Array[Dictionary] = _of_kind(characters, "archetype")
	var encounters: Array[Dictionary] = CanonReader.load("encounters", canon_root)
	if archetypes.is_empty() or encounters.is_empty():
		return false
	if not _encounters_name_real_archetypes(encounters, archetypes):
		return false
	if (
		elements.is_empty() or classes.is_empty() or peoples.is_empty() or items.is_empty()
		or spells.is_empty() or effects.is_empty() or locations.is_empty() or lore.is_empty()
	):
		return false
	if not _elements_match_the_design_system(elements):
		return false
	if not _item_categories_exist(items):
		return false
	if Pandora.get_all_roots().is_empty():
		_seed(
			factions, elements, classes, peoples, items, spells, effects, locations, lore,
			archetypes, encounters
		)
	else:
		_apply_elements(elements)
		_apply_classes(classes)
		_apply_peoples(peoples)
		_apply_items(items)
		_apply_spells(spells)
		_apply_effects(effects)
		_apply_factions(factions)
		_apply_locations(locations)
		_apply_lore(lore)
		_apply_combatants(archetypes)
		_apply_encounters(encounters)
	return true


func _of_kind(documents: Array[Dictionary], wanted: String) -> Array[Dictionary]:
	var result: Array[Dictionary] = []
	for document: Dictionary in documents:
		if String(document.get("kind", "")) == wanted:
			result.append(document)
	return result


## The archetype_id indirection is the seam encounters and spawn tables are meant to reference
## through (spec §4.7), so a name that resolves to nothing is a broken encounter, not a
## harmless typo — and it fails here, at seed time, rather than as an empty enemy list in a
## fight the player has already walked into.
func _encounters_name_real_archetypes(
	encounters: Array[Dictionary], archetypes: Array[Dictionary]
) -> bool:
	var known: Dictionary = {}
	for row: Dictionary in archetypes:
		known[row["id"]] = true
	for row: Dictionary in encounters:
		for archetype_id: String in Array(row["archetype_ids"]):
			if not known.has(archetype_id):
				push_error(
					"CANON-SEED: encounter '%s' names unknown archetype '%s'."
					% [row["id"], archetype_id]
				)
				return false
	return true


## The wheel is a closed canon set and its presentation tokens are the design system's, not
## canon's: `DS.WHEEL` is synced from the design-system project (`design/DESIGN_SYSTEM.md`) and
## copying its hex into `canon/` would create a second source to drift. So canon owns identity,
## order and the clash; DS owns sigil, colour and glow, and the two lists must agree exactly —
## in both directions, because an eleventh element added on either side is the failure this
## guard exists to catch.
func _elements_match_the_design_system(elements: Array[Dictionary]) -> bool:
	var canon_ids: Dictionary = {}
	for row: Dictionary in elements:
		canon_ids[row["id"]] = true
	var token_ids: Dictionary = {}
	for token: Dictionary in DS.WHEEL:
		token_ids[String(token["id"])] = true
	for element_id: String in canon_ids:
		if not token_ids.has(element_id):
			push_error("CANON-SEED: element '%s' has no DS.WHEEL token." % element_id)
			return false
	for token_id: String in token_ids:
		if not canon_ids.has(token_id):
			push_error("CANON-SEED: DS.WHEEL token '%s' has no canon document." % token_id)
			return false
	return true


## An item naming a category this seeder does not create would be a null parent at creation
## time, so it is caught in preflight where every other canon-shape failure is caught.
func _item_categories_exist(items: Array[Dictionary]) -> bool:
	for row: Dictionary in items:
		if not ITEM_CATEGORIES.has(row["category"]):
			push_error(
				"CANON-SEED: item '%s' names unknown category '%s'."
				% [row["id"], row["category"]]
			)
			return false
	return true


func _design_system_token(element_id: String) -> Dictionary:
	for token: Dictionary in DS.WHEEL:
		if String(token["id"]) == element_id:
			return token
	return {}


func _cat(name: String, parent: PandoraCategory = null) -> PandoraCategory:
	var c := Pandora.create_category(name, parent)
	_cats[name] = c
	return c


func _ensure_root(name: String) -> PandoraCategory:
	for candidate: PandoraCategory in Pandora.get_all_roots():
		if candidate.get_entity_name() == name:
			_cats[name] = candidate
			return candidate
	return _cat(name)


## The sub-category equivalent of `_ensure_root()`. Re-creating a category that already exists
## would give it a new generated id and move every child under it, which reads as drift.
func _ensure_child_category(parent: PandoraCategory, name: String) -> PandoraCategory:
	# `get_all_categories()`, not `get_all_entities()` — the latter filters categories out
	# entirely, so a lookup through it can never find one and would recreate it every seed.
	# Both recurse, hence the parent check: a category of the same name nested deeper is a
	# different category and must not be adopted as this one.
	for candidate: PandoraEntity in Pandora.get_all_categories(parent):
		if (
			candidate is PandoraCategory
			and candidate.get_entity_name() == name
			and (candidate as PandoraCategory)._category_id == parent.get_entity_id()
		):
			_cats[name] = candidate
			return candidate as PandoraCategory
	return _cat(name, parent)


## Authored default values: runtime setters (set_string etc.) only work on instantiate()d
## copies. Authoring goes through the OverridingProperty wrapper -> _property_overrides,
## which is what save_data() persists (and what the Pandora editor itself does).
## PandoraEntity values are auto-wrapped into PandoraReference by set_default_value.
func _assign(ent: PandoraEntity, prop_name: String, value: Variant) -> void:
	var prop := ent.get_entity_property(prop_name)
	if prop == null:
		push_error("SEED: no property '%s' on %s" % [prop_name, ent.get_entity_name()])
		return
	prop.set_default_value(value)


func _seed(
	factions: Array[Dictionary],
	elements: Array[Dictionary],
	classes: Array[Dictionary],
	peoples: Array[Dictionary],
	items: Array[Dictionary],
	spells: Array[Dictionary],
	effects: Array[Dictionary],
	locations: Array[Dictionary],
	lore: Array[Dictionary],
	archetypes: Array[Dictionary],
	encounters: Array[Dictionary]
) -> void:
	_apply_elements(elements)
	_apply_classes(classes)
	_apply_peoples(peoples)
	_apply_items(items)
	_apply_spells(spells)
	_apply_effects(effects)
	_apply_factions(factions)
	_seed_npcs()
	_apply_combatants(archetypes)
	_apply_encounters(encounters)
	_apply_locations(locations)
	_apply_lore(lore)


# --- Elements: the Wheel of Ten (closed canon set; canon/<hub>/elements) -----------------


## Identity, wheel order and the clash come from canon; sigil, colour and glow come from the
## design system. See `_elements_match_the_design_system()` for why the two are kept apart.
func _apply_elements(elements: Array[Dictionary]) -> void:
	var root: PandoraCategory = _ensure_root("Elements")
	for property_spec: Array in [
		["Display Name", "string"],
		["Sigil", "string"],
		["Color", "color"],
		["Glow", "color"],
		["Clash", "reference"],
	]:
		if not root.has_entity_property(property_spec[0]):
			Pandora.create_property(root, property_spec[0], property_spec[1])

	var canon_ids: Dictionary = {}
	for row: Dictionary in elements:
		canon_ids[row["id"]] = true
	var made: Dictionary = {}
	for row: Dictionary in elements:
		var stable_id: String = row["id"]
		var entity: PandoraEntity = _find_by_stable_id(root, stable_id, canon_ids)
		if entity == null:
			# Presentation is stamped once, when the row is first written. Re-stamping it on
			# every seed would make this seeder a second writer of design tokens into game
			# data, and it is not: `DS.WHEEL` is what the UI actually reads (badge, theme
			# builder, character creation), and canon owns identity, not appearance.
			entity = Pandora.create_entity(row["display_name"], root)
			var token: Dictionary = _design_system_token(stable_id)
			_assign(entity, "Sigil", token["sigil"])
			_assign(entity, "Color", token["color"])
			_assign(entity, "Glow", token["glow"])
		_assign(entity, "Display Name", row["display_name"])
		made[stable_id] = entity
	# Assigned in a second pass: an element's opposite may not have existed on the first.
	for row: Dictionary in elements:
		_assign(made[row["id"]], "Clash", made[row["clash"]])


# --- Classes: the Ten Patron Classes (vault: systems/ten-patron-classes.md) --------------


func _apply_classes(classes: Array[Dictionary]) -> void:
	var root: PandoraCategory = _ensure_root("Classes")
	for property_spec: Array in [
		["Display Name", "string"],
		["Patron", "string"],
		["Resource Name", "string"],
		["Vault Id", "string"],
	]:
		if not root.has_entity_property(property_spec[0]):
			Pandora.create_property(root, property_spec[0], property_spec[1])

	var canon_ids: Dictionary = {}
	for row: Dictionary in classes:
		canon_ids[row["id"]] = true
	for row: Dictionary in classes:
		var entity: PandoraEntity = _find_by_stable_id(root, row["id"], canon_ids)
		if entity == null:
			entity = Pandora.create_entity(row["display_name"], root)
		_assign(entity, "Display Name", row["display_name"])
		_assign(entity, "Patron", row["patron"])
		_assign(entity, "Resource Name", row["resource_name"])
		_assign(entity, "Vault Id", row["vault_id"])


# --- Peoples: playable races (vault: peoples/) -------------------------------------------


func _apply_peoples(peoples: Array[Dictionary]) -> void:
	var root: PandoraCategory = _ensure_root("Peoples")
	for property_spec: Array in [
		["Display Name", "string"],
		["Analogue", "string"],
		["Homeland", "string"],
		["Vault Id", "string"],
	]:
		if not root.has_entity_property(property_spec[0]):
			Pandora.create_property(root, property_spec[0], property_spec[1])

	var canon_ids: Dictionary = {}
	for row: Dictionary in peoples:
		canon_ids[row["id"]] = true
	for row: Dictionary in peoples:
		var entity: PandoraEntity = _find_by_stable_id(root, row["id"], canon_ids)
		if entity == null:
			entity = Pandora.create_entity(row["display_name"], root)
		_assign(entity, "Display Name", row["display_name"])
		_assign(entity, "Analogue", row["analogue"])
		_assign(entity, "Homeland", row["homeland"])
		_assign(entity, "Vault Id", row["vault_id"])


# --- Items: reserved sync-spec properties on the ROOT (propagate to all children) --------


func _apply_items(items: Array[Dictionary]) -> void:
	var root: PandoraCategory = _ensure_root("Items")
	# Reserved properties per docs/godot-architecture.md sync spec. Grid inventory is
	# confirmed, so Grid Size is REQUIRED.
	for property_spec: Array in [
		["Display Name", "string"],
		["Description", "string"],
		["Max Stack Size", "int"],
		["Weight", "float"],
		["Grid Size", "vector2i"],
		["Equip Slot", "string"],
		["Rarity", "string"],
		["Flavour", "string"],
	]:
		if not root.has_entity_property(property_spec[0]):
			Pandora.create_property(root, property_spec[0], property_spec[1])

	var categories: Dictionary = {}
	for category_name: String in ITEM_CATEGORIES:
		categories[category_name] = _ensure_child_category(root, category_name)

	var canon_ids: Dictionary = {}
	for row: Dictionary in items:
		canon_ids[row["id"]] = true
	for row: Dictionary in items:
		var entity: PandoraEntity = _find_by_stable_id(root, row["id"], canon_ids)
		if entity == null:
			# The category places a NEW item in the tree and is deliberately not re-applied to
			# one that already exists: moving an authored entity between categories is a
			# structural edit, and this seeder's contract is to update values, not to reshape
			# a database someone may have arranged in the Pandora editor.
			entity = Pandora.create_entity(row["display_name"], categories[row["category"]])
		_assign(entity, "Display Name", row["display_name"])
		_assign(entity, "Description", row["description"])
		_assign(entity, "Max Stack Size", int(row["max_stack_size"]))
		_assign(entity, "Weight", float(row["weight"]))
		_assign(entity, "Grid Size", _vector2i(row["grid_size"]))
		_assign(entity, "Equip Slot", row["equip_slot"])
		_assign(entity, "Rarity", row["rarity"])
		_assign(entity, "Flavour", row["flavour"])


static func _vector2i(pair: Variant) -> Vector2i:
	var components: Array = pair as Array
	return Vector2i(int(components[0]), int(components[1]))



# --- Spells: PLACEHOLDER mechanics referencing canon elements ----------------------------


## `Placeholder` is set here rather than carried in the documents on purpose: it is a mechanics
## flag saying these spells are stand-ins until the real ability layer exists, and canon is not
## the place to record what the build has not built yet (see this file's header).
##
## The `element` field is an element id, resolved against the Elements root — not an entity name.
## Names are display text and can be re-cased or re-worded; the id is the thing that is stable.
func _apply_spells(spells: Array[Dictionary]) -> void:
	var root: PandoraCategory = _ensure_root("Spells")
	for property_spec: Array in [
		["Display Name", "string"],
		["Description", "string"],
		["Element", "reference"],
		["Soul Cost", "int"],
		["Placeholder", "bool"],
	]:
		if not root.has_entity_property(property_spec[0]):
			Pandora.create_property(root, property_spec[0], property_spec[1])

	var elements_root: PandoraCategory = _ensure_root("Elements")
	var canon_ids: Dictionary = {}
	for row: Dictionary in spells:
		canon_ids[row["id"]] = true
	for row: Dictionary in spells:
		var element: PandoraEntity = _find_by_stable_id(elements_root, row["element"])
		if element == null:
			push_error(
				"CANON-SEED: spell '%s' names unknown element '%s'." % [row["id"], row["element"]]
			)
			continue
		var entity: PandoraEntity = _find_by_stable_id(root, row["id"], canon_ids)
		if entity == null:
			entity = Pandora.create_entity(row["display_name"], root)
		_assign(entity, "Display Name", row["display_name"])
		_assign(entity, "Element", element)
		_assign(entity, "Soul Cost", int(row["soul_cost"]))
		_assign(entity, "Description", row["description"])
		_assign(entity, "Placeholder", true)


# --- Effects: PLACEHOLDER status shapes for GAS later ------------------------------------


func _apply_effects(effects: Array[Dictionary]) -> void:
	var root: PandoraCategory = _ensure_root("Effects")
	for property_spec: Array in [
		["Display Name", "string"],
		["Description", "string"],
		["Duration Type", "string"],
		["Placeholder", "bool"],
	]:
		if not root.has_entity_property(property_spec[0]):
			Pandora.create_property(root, property_spec[0], property_spec[1])

	var canon_ids: Dictionary = {}
	for row: Dictionary in effects:
		canon_ids[row["id"]] = true
	for row: Dictionary in effects:
		var entity: PandoraEntity = _find_by_stable_id(root, row["id"], canon_ids)
		if entity == null:
			entity = Pandora.create_entity(row["display_name"], root)
		_assign(entity, "Display Name", row["display_name"])
		_assign(entity, "Description", row["description"])
		_assign(entity, "Duration Type", row["duration_type"])
		_assign(entity, "Placeholder", true)


# --- Factions: from the vault's city dossiers --------------------------------------------


func _seed_factions(canon_root: String = CanonReader.CANON_ROOT) -> bool:
	var factions: Array[Dictionary] = CanonReader.load("factions", canon_root)
	if factions.is_empty() or not _faction_ids_are_unambiguous(factions):
		return false
	_apply_factions(factions)
	return true


func _faction_ids_are_unambiguous(factions: Array[Dictionary]) -> bool:
	var root: PandoraCategory = null
	for candidate: PandoraCategory in Pandora.get_all_roots():
		if candidate.get_entity_name() == "Factions":
			root = candidate
			break
	if root == null:
		return true
	var claims: Dictionary = {}
	for row: Dictionary in factions:
		# Resolve against existing entities before any new entity can change lookup.
		# An exact name must not steal the entity owned by a legacy slug identity.
		var existing: PandoraEntity = _find_by_stable_id(root, row["id"])
		if existing == null:
			continue
		var entity_id: String = existing.get_entity_id()
		if claims.has(entity_id):
			push_error(
				"CANON-SEED: faction ids '%s' and '%s' claim the same existing entity."
				% [claims[entity_id], row["id"]]
			)
			return false
		claims[entity_id] = row["id"]
	return true


func _apply_factions(factions: Array[Dictionary]) -> void:
	var canon_ids: Dictionary = {}
	for row: Dictionary in factions:
		canon_ids[row["id"]] = true
	var root: PandoraCategory = _ensure_root("Factions")
	for property_spec: Array in [
		["Display Name", "string"],
		["Summary", "string"],
		["Seat", "string"],
		["Vault Id", "string"],
	]:
		if not root.has_entity_property(property_spec[0]):
			Pandora.create_property(root, property_spec[0], property_spec[1])

	for row: Dictionary in factions:
		var stable_id: String = row["id"]
		var entity: PandoraEntity = _find_by_stable_id(root, stable_id, canon_ids)
		if entity == null:
			entity = Pandora.create_entity(stable_id, root)
		_assign(entity, "Display Name", row["display_name"])
		_assign(entity, "Summary", row["summary"])
		_assign(entity, "Seat", row["seat"])
		_assign(entity, "Vault Id", row["vault_id"])


func _find_by_stable_id(
	root: PandoraCategory, stable_id: String, canon_ids: Dictionary = {}
) -> PandoraEntity:
	# Canon-created entities use the immutable id as their internal name. Older
	# entities keep their existing names and generated IDs, with a slug fallback.
	for candidate: PandoraEntity in Pandora.get_all_entities(root):
		if not candidate is PandoraCategory and candidate.get_entity_name() == stable_id:
			return candidate
	for candidate: PandoraEntity in Pandora.get_all_entities(root):
		if candidate is PandoraCategory:
			continue
		# A different current canon id is never a legacy display-name alias.
		if canon_ids.has(candidate.get_entity_name()):
			continue
		var candidate_id: String = _slug(candidate.get_entity_name())
		if candidate_id == stable_id:
			return candidate
	return null


func _slug(value: String) -> String:
	var result: String = value.to_lower()
	for pair: Array in [["'", ""], ["’", ""], [" ", "-"], ["_", "-"]]:
		result = result.replace(pair[0], pair[1])
	return result


# --- NPCs: the demo party + canon-named persons ------------------------------------------


func _seed_npcs() -> void:
	var root := _cat("NPCs")
	Pandora.create_property(root, "Display Name", "string")
	Pandora.create_property(root, "Epithet", "string")
	Pandora.create_property(root, "Race", "reference")
	Pandora.create_property(root, "Class", "reference")
	Pandora.create_property(root, "Bio", "string")
	Pandora.create_property(root, "Vault Id", "string")

	var peoples := {}
	for e in Pandora.get_all_entities(_cats["Peoples"]):
		peoples[e.get_entity_name()] = e
	var classes := {}
	for e in Pandora.get_all_entities(_cats["Classes"]):
		classes[e.get_entity_name()] = e

	var rows := [
		[
			"Vex",
			"the Unbowed",
			"Kes'reth",
			"Ironbrand",
			(
				"A horned reaver of Karrn-Vash; her soul is a held line, sealed "
				+ "against the Loam and tattooed in cinder-ink."
			)
		],
		[
			"Serai-Lun",
			"",
			"Kes'reth",
			"Mirrorblade",
			(
				"A mirror-dancer of Vervulling who fights in paired, reflected "
				+ "forms and speaks in balanced halves."
			)
		],
		[
			"Old Grumbrand",
			"",
			"Kaan",
			"Lensbearer",
			(
				"A soot-stained salvager who reads Age-of-Stars machines for a "
				+ "price and trusts nothing that hums."
			)
		],
		[
			"Iris Illepah",
			"",
			"Weftkin",
			"Husk-bearer",
			"Ssae-Seeder cultivator of Loamgate's groves; keeps the overhang swept for Schutte.",
			"iris-illepah"
		],
	]
	for r in rows:
		var ent := Pandora.create_entity(r[0], root)
		_assign(ent, "Display Name", r[0])
		_assign(ent, "Epithet", r[1])
		if peoples.has(r[2]):
			_assign(ent, "Race", peoples[r[2]])
		if classes.has(r[3]):
			_assign(ent, "Class", classes[r[3]])
		_assign(ent, "Bio", r[4])
		if r.size() > 5:
			_assign(ent, "Vault Id", r[5])


# --- Combatants and encounters: read from canon, expanded into generated JSON ------------


## Archetypes are `canon/<hub>/characters/*.json` with `kind: "archetype"` (spec §4.7): the
## same document kind as the townsfolk, discriminated rather than duplicated, and the thing
## encounters and spawn tables reference by id instead of inlining stats.
##
## `element_id` is a Wheel id (`globals/elements/element_wheel.gd`'s ORDER) read as this
## combatant's TARGET-side attunement — the "target relation" gamble curve (vault:
## systems/magic-system.md, ratified 2026-08-05) prices any elemental attack against it by
## Wheel distance. Bog Wight (grave-rotted) is Mozh; the Loam-Maddened Boar (maddened by
## corrupted soil) is Tham. Empty means no authored attunement, which keeps that combatant
## resolving at the ElementMatrix neutral IDENTITY_ROW.
##
## The stat block is tagged `dramgid.v1` (owner ruling 2026-09-07: DRAMGID stats on
## enemies as well). Each archetype carries all seven attributes, and `alacrity` is the
## ratified rename of the old `edge` (`DramgidSchema.ATTRIBUTE_RENAMES`).
##
## `max_hp`, `attack` and `defense` stay AUTHORED here — INTERIM, tracked as #412, not a
## settled answer. The owner has ruled (2026-09-07) that enemy attributes SHOULD drive the
## three combat numbers, and that different instances met in the wild should differ: "I
## don't want it to be a 'solved' kinda question." What this pass will not do is reach that
## by reusing the party's curve. The party point-buys 2..5, so `max_hp = 12 + grit * 6`
## yields 24/30/36/42 while the shipped enemies run 14..36 with a grit-1 boar the party can
## never build; a 14 HP boar would become 24, a 71% buff, every encounter would need
## rebalancing, and Gate T-1's ratified evidence (five archetype encounters cleared by four
## build archetypes) would stop describing the game. #412 carries the enemy-side curve plus
## the per-spawn variation on top of it, and is sequenced behind #345's SpawnDirector
## because the roll belongs to the wild spawn path, not to these authored set-pieces. Until
## then the attributes give enemies the DRAMGID surface (to-hit, charge speed, checks) and
## the three combat numbers stay where Gate T-1 left them.
##
## The one remaining boundary: Pandora's column and `data/generated/encounters.json`
## still say `Edge`, because campaign packages author that key
## (`campaign_encounter_loader.gd`) and renaming it would break every authored package.
## Canon and the runtime both say `alacrity`; the mapping happens here and in
## `EncounterCatalog._actor_from_row()`, in one direction, once.
func _apply_combatants(archetypes: Array[Dictionary]) -> void:
	var root: PandoraCategory = _ensure_root("Combatants")
	for property_spec: Array in [
		["Combatant Id", "string"],
		["Display Name", "string"],
		["Max HP", "int"],
		["Attack", "int"],
		["Defense", "int"],
		["Edge", "int"],
		["Balance Affinity", "int"],
		["Balance Pressure", "int"],
		["Element Id", "string"],
	]:
		if not root.has_entity_property(property_spec[0]):
			Pandora.create_property(root, property_spec[0], property_spec[1])

	for row: Dictionary in archetypes:
		var stats: Dictionary = row["stats"]
		var entity: PandoraEntity = _find_by_id_property(root, "Combatant Id", row["id"])
		if entity == null:
			entity = Pandora.create_entity(row["display_name"], root)
		_assign(entity, "Combatant Id", row["id"])
		_assign(entity, "Display Name", row["display_name"])
		_assign(entity, "Element Id", row["element_id"])
		_assign(entity, "Max HP", int(stats["max_hp"]))
		_assign(entity, "Attack", int(stats["attack"]))
		_assign(entity, "Defense", int(stats["defense"]))
		_assign(entity, "Edge", int(stats["alacrity"]))
		_assign(entity, "Balance Affinity", int(stats["balance_affinity"]))
		_assign(entity, "Balance Pressure", int(stats["balance_pressure"]))


## Encounters are `canon/<hub>/encounters/*.json`. Per F0 D8 (spec §4.9) an encounter owns
## its actors and its consequences and owns NEITHER a grid NOR a weather default: the grid
## derives from the field's own tiles and weather belongs to the location. The reader refuses
## either field outright rather than accepting and ignoring it.
##
## `win`/`loss` are `null` when that side of the fight writes no ledger row — the two Dorthkor
## encounters have no authored loss consequence, and `null` says so where an empty faction
## string only looks like an oversight. Pandora keeps the flat legacy columns; the shape of a
## post-#281 encounter (spoils, speech hooks, group_id) is E5.2's call, not this migration's.
func _apply_encounters(encounters: Array[Dictionary]) -> void:
	var root: PandoraCategory = _ensure_root("Encounters")
	for property_spec: Array in [
		["Encounter Id", "string"],
		["Display Name", "string"],
		["Combatant Ids", "string"],
		["Defeated Flag", "string"],
		["Win Faction", "string"],
		["Win Delta", "float"],
		["Win Cause", "string"],
		["Loss Faction", "string"],
		["Loss Delta", "float"],
		["Loss Cause", "string"],
	]:
		if not root.has_entity_property(property_spec[0]):
			Pandora.create_property(root, property_spec[0], property_spec[1])

	for row: Dictionary in encounters:
		var entity: PandoraEntity = _find_by_id_property(root, "Encounter Id", row["id"])
		if entity == null:
			entity = Pandora.create_entity(row["display_name"], root)
		_assign(entity, "Encounter Id", row["id"])
		_assign(entity, "Display Name", row["display_name"])
		_assign(entity, "Combatant Ids", ",".join(PackedStringArray(row["archetype_ids"])))
		_assign(entity, "Defeated Flag", row["defeated_flag"])
		_assign_outcome(entity, "Win", row["win"])
		_assign_outcome(entity, "Loss", row["loss"])


## A `null` outcome writes the flat legacy absence the old authored rows carried: no faction,
## no delta, no cause. Keeping the columns rather than deleting them is what lets this land
## with zero `data.pandora` diff.
func _assign_outcome(entity: PandoraEntity, prefix: String, outcome: Variant) -> void:
	if outcome == null:
		_assign(entity, "%s Faction" % prefix, "")
		_assign(entity, "%s Delta" % prefix, 0.0)
		_assign(entity, "%s Cause" % prefix, "")
		return
	var row: Dictionary = outcome
	_assign(entity, "%s Faction" % prefix, row["faction"])
	_assign(entity, "%s Delta" % prefix, float(row["delta"]))
	_assign(entity, "%s Cause" % prefix, row["cause"])


## Combatant and encounter entities keep their DISPLAY names, so the slug fallback in
## `_find_by_stable_id` cannot resolve them — "The Empty Post" slugs to `the-empty-post`,
## never to `jawbrace-empty-post`. Their id lives in an explicit property instead, which is
## exact, so match on that and let creation be the genuine last resort.
func _find_by_id_property(
	root: PandoraCategory, property_name: String, stable_id: String
) -> PandoraEntity:
	for candidate: PandoraEntity in Pandora.get_all_entities(root):
		if candidate is PandoraCategory:
			continue
		var property: PandoraProperty = candidate.get_entity_property(property_name)
		if property != null and String(property.get_default_value()) == stable_id:
			return candidate
	return _find_by_stable_id(root, stable_id)


# --- Locations: the 12 gazetteer cities (vault: cities/) ---------------------------------


## The twelve world-map locations of the Dramgid map. NOT the same set as the playable scenes
## in `world/locations/*.tres` — those are `LocationDefinition`s and include Dom's twenty
## interiors, which have no entry here. `agreement` stays the authored string it always was
## ("91-93%"); turning it into a `harmonic_accord` float would be inventing a number, and C21
## (#258) owns authored per-location values.
func _apply_locations(locations: Array[Dictionary]) -> void:
	var root: PandoraCategory = _ensure_root("Locations")
	for property_spec: Array in [
		["Display Name", "string"],
		["Epithet", "string"],
		["Patron", "string"],
		["Agreement", "string"],
		["Vault Id", "string"],
	]:
		if not root.has_entity_property(property_spec[0]):
			Pandora.create_property(root, property_spec[0], property_spec[1])

	var canon_ids: Dictionary = {}
	for row: Dictionary in locations:
		canon_ids[row["id"]] = true
	for row: Dictionary in locations:
		var entity: PandoraEntity = _find_by_stable_id(root, row["id"], canon_ids)
		if entity == null:
			entity = Pandora.create_entity(row["display_name"], root)
		_assign(entity, "Display Name", row["display_name"])
		_assign(entity, "Epithet", row["epithet"])
		_assign(entity, "Patron", row["patron"])
		_assign(entity, "Agreement", row["agreement"])
		_assign(entity, "Vault Id", row["vault_id"])


# --- Lore: bridge entries into the vault (id + path; prose STAYS in the vault) -----------


## Bridge rows only: the id, the summary and the vault path. The prose stays in the vault, and
## a `vault_id` here is not the document's own id — "The Soul Gauge" bridges to `souls`, "The
## Taubstummers" to `last-great-war`. That is why the two fields exist separately.
func _apply_lore(lore: Array[Dictionary]) -> void:
	var root: PandoraCategory = _ensure_root("Lore")
	for property_spec: Array in [
		["Display Name", "string"],
		["Summary", "string"],
		["Vault Id", "string"],
		["Vault Path", "string"],
	]:
		if not root.has_entity_property(property_spec[0]):
			Pandora.create_property(root, property_spec[0], property_spec[1])

	var canon_ids: Dictionary = {}
	for row: Dictionary in lore:
		canon_ids[row["id"]] = true
	for row: Dictionary in lore:
		var entity: PandoraEntity = _find_by_stable_id(root, row["id"], canon_ids)
		if entity == null:
			entity = Pandora.create_entity(row["display_name"], root)
		_assign(entity, "Display Name", row["display_name"])
		_assign(entity, "Summary", row["summary"])
		_assign(entity, "Vault Id", row["vault_id"])
		_assign(entity, "Vault Path", row["vault_path"])
