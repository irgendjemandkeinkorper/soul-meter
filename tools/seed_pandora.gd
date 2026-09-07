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
		"items": {
			"noun": "item",
			"schema": "weftlumin.item.v1",
			"fields": [
				"id", "display_name", "category", "description", "equip_slot", "rarity",
				"flavour",
			],
			"integers": ["max_stack_size"],
			"numbers": ["weight"],
			"vector2is": ["grid_size"],
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
		var fields: Array = ["schema"] + Array(contract["fields"])
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
		):
			if typeof(row.get(field)) != TYPE_FLOAT:
				push_error("CANON-SEED: %s requires numeric '%s'." % [document_path, field])
				return false
		for field: String in Array(contract.get("vector2is", [])):
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
		_seed(factions, elements, classes, peoples, items, spells, effects, locations, lore)
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
	lore: Array[Dictionary]
) -> void:
	_apply_elements(elements)
	_apply_classes(classes)
	_apply_peoples(peoples)
	_apply_items(items)
	_apply_spells(spells)
	_apply_effects(effects)
	_apply_factions(factions)
	_seed_npcs()
	_seed_combatants()
	_seed_encounters()
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


# --- Combatants and encounters: authored here, expanded into generated JSON ---------------


func _seed_combatants() -> void:
	var root := _cat("Combatants")
	Pandora.create_property(root, "Combatant Id", "string")
	Pandora.create_property(root, "Display Name", "string")
	Pandora.create_property(root, "Max HP", "int")
	Pandora.create_property(root, "Attack", "int")
	Pandora.create_property(root, "Defense", "int")
	Pandora.create_property(root, "Edge", "int")
	Pandora.create_property(root, "Balance Affinity", "int")
	Pandora.create_property(root, "Balance Pressure", "int")
	Pandora.create_property(root, "Element Id", "string")

	# Element Id is a Wheel id (globals/elements/element_wheel.gd's ORDER) read as this
	# combatant's TARGET-side attunement — see tools/seed_chapter_one.gd's _seed_combatants()
	# for the thematic reasoning; keep the two seeders in lockstep.
	# Edge (9th column) is PROVISIONAL enemy accuracy/evasion (#169/#98 owner ruling
	# 2026-08-24: to-hit adds (attacker Edge - defender Edge) x 2%). Values follow the
	# creature fiction: nimble skirmishers high, armored or shambling low.
	var rows := [
		["Bog Wight", "bog-wight", 20, 4, 1, 1, 18, "mozh", 2],
		["Loam-Maddened Boar", "loam-maddened-boar", 14, 6, 0, -1, 18, "tham", 3],
		["Gnaal Breach-Hound", "gnaal-breach-hound", 28, 7, 1, -1, 22, "", 4],
		["Gnaal Rift-Scavenger", "gnaal-rift-scavenger", 16, 5, 0, -1, 16, "", 4],
		["Mustered Bloodbellow", "mustered-bloodbellow", 32, 6, 3, 1, 22, "", 2],
		["Cleaned Jawbrace Guard", "cleaned-jawbrace-guard", 36, 7, 4, 1, 24, "", 3],
	]
	for row in rows:
		var entity := Pandora.create_entity(row[0], root)
		_assign_combatant(entity, row)


func _seed_encounters() -> void:
	var root := _cat("Encounters")
	Pandora.create_property(root, "Encounter Id", "string")
	Pandora.create_property(root, "Display Name", "string")
	Pandora.create_property(root, "Combatant Ids", "string")
	Pandora.create_property(root, "Defeated Flag", "string")
	Pandora.create_property(root, "Win Faction", "string")
	Pandora.create_property(root, "Win Delta", "float")
	Pandora.create_property(root, "Win Cause", "string")
	Pandora.create_property(root, "Loss Faction", "string")
	Pandora.create_property(root, "Loss Delta", "float")
	Pandora.create_property(root, "Loss Cause", "string")

	var rows := _encounter_rows()
	for row in rows:
		var entity := Pandora.create_entity(row[0], root)
		_assign_encounter(entity, row)


func _assign_combatant(entity: PandoraEntity, row: Array) -> void:
	_assign(entity, "Display Name", row[0])
	_assign(entity, "Combatant Id", row[1])
	_assign(entity, "Max HP", row[2])
	_assign(entity, "Attack", row[3])
	_assign(entity, "Defense", row[4])
	_assign(entity, "Balance Affinity", row[5])
	_assign(entity, "Balance Pressure", row[6])
	_assign(entity, "Element Id", row[7])
	_assign(entity, "Edge", row[8] if row.size() > 8 else 0)


func _assign_encounter(entity: PandoraEntity, row: Array) -> void:
	var properties := [
		"Display Name",
		"Encounter Id",
		"Combatant Ids",
		"Defeated Flag",
		"Win Faction",
		"Win Delta",
		"Win Cause",
		"Loss Faction",
		"Loss Delta",
		"Loss Cause",
	]
	for index in properties.size():
		_assign(entity, properties[index], row[index])


func _encounter_rows() -> Array:
	return [
		[
			"Bog Wight",
			"bog-wight",
			"bog-wight",
			"defeated_bog_wight",
			"ssae-seeders",
			6.0,
			"Cleared the Bog Wight from the grove margins",
			"ssae-seeders",
			-3.0,
			"The Bog Wight still haunts the grove's edge",
		],
		[
			"Loam-Maddened Boar",
			"loam-boar",
			"loam-maddened-boar",
			"defeated_loam_boar",
			"ssae-seeders",
			5.0,
			"Culled a Loam-maddened boar before it reached the grove",
			"ssae-seeders",
			-3.0,
			"A Loam-maddened boar broke loose near the grove",
		],
		[
			"Dorthkor Demon Vanguard",
			"dorthkor-vanguard",
			"gnaal-breach-hound,gnaal-rift-scavenger",
			"defeated_breach_hound",
			"iron-companies",
			5.0,
			"Broke the demon vanguard at Dorthkor",
			"",
			0.0,
			"",
		],
		[
			"Dorthkor Dead Muster",
			"dorthkor-muster",
			"mustered-bloodbellow",
			"defeated_mustered_dead",
			"ironbrand-sentinels",
			5.0,
			"Stopped a dead soldier answering Dom's muster",
			"",
			0.0,
			"",
		],
		[
			"The Empty Post",
			"jawbrace-empty-post",
			"cleaned-jawbrace-guard",
			"defeated_cleaned_jawbrace_guard",
			"ironbrand-sentinels",
			6.0,
			"Stopped the cleaned armor standing watch at the Jawbrace",
			"ironbrand-sentinels",
			-3.0,
			"The empty guard still holds the first gate",
		],
	]


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
