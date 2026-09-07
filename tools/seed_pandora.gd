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


class CanonReader:
	const CANON_ROOT := "res://canon"

	## Per-kind contract. A kind listed here is validated and must produce at least one
	## document; a kind that is not is read verbatim, so a later E1.4 migration can land its
	## documents before its schema is settled without this file blocking it.
	##
	## `ordered` kinds carry an integer `order` and are returned in it. The wheel is a ring and
	## its rotation is canon — ring distance and the clash pairs are read off it — so that order
	## must not be an accident of how the files happen to sort.
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
	if elements.is_empty() or classes.is_empty() or peoples.is_empty():
		return false
	if not _elements_match_the_design_system(elements):
		return false
	if Pandora.get_all_roots().is_empty():
		_seed(factions, elements, classes, peoples)
	else:
		_apply_elements(elements)
		_apply_classes(classes)
		_apply_peoples(peoples)
		_apply_factions(factions)
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
	peoples: Array[Dictionary]
) -> void:
	_apply_elements(elements)
	_apply_classes(classes)
	_apply_peoples(peoples)
	_seed_items()
	_seed_spells()
	_seed_effects()
	_apply_factions(factions)
	_seed_npcs()
	_seed_combatants()
	_seed_encounters()
	_seed_locations()
	_seed_lore()


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


func _seed_items() -> void:
	var root := _cat("Items")
	# Reserved properties per docs/godot-architecture.md sync spec. Grid inventory is
	# confirmed, so Grid Size is REQUIRED.
	Pandora.create_property(root, "Display Name", "string")
	Pandora.create_property(root, "Description", "string")
	Pandora.create_property(root, "Max Stack Size", "int")
	Pandora.create_property(root, "Weight", "float")
	Pandora.create_property(root, "Grid Size", "vector2i")
	Pandora.create_property(root, "Equip Slot", "string")
	Pandora.create_property(root, "Rarity", "string")
	Pandora.create_property(root, "Flavour", "string")

	var weapons := _cat("Weapons", root)
	var relics := _cat("Relics", root)
	var tools := _cat("Tools", root)
	var consumables := _cat("Consumables", root)
	var materials := _cat("Materials", root)

	var rows := [
		[
			weapons,
			"Taubstummer Axe",
			"A sealed soul-weapon of the Last Great War; its edge remembers what it unmade.",
			1,
			6.0,
			Vector2i(2, 3),
			"main_hand",
			"mythic",
			"It does not ring when struck. Nothing it touches does."
		],
		[
			relics,
			"Captured Reflection",
			"An obsidian shard that shows a room lit by a sky that does not exist.",
			1,
			0.3,
			Vector2i(1, 1),
			"",
			"rare",
			"Do not name what you see in it. Under the Vow, a named Seat must abdicate."
		],
		[
			tools,
			"Soul Gauge",
			"A brass-and-glass dial that reads a soul's integrity — and what magic has spent.",
			1,
			0.8,
			Vector2i(1, 2),
			"",
			"rare",
			"The needle is honest. That is the problem."
		],
		[
			consumables,
			"Loam Bread",
			"Dense composting-city fare from Loamgate. Restores a little vigor.",
			10,
			0.4,
			Vector2i(1, 1),
			"",
			"common",
			"Everything returns. Some of it returns as bread."
		],
		[
			materials,
			"Cinder-Ink Vial",
			"Ash-Bound tattoo ink; names written in it resist the Waning's slow erasure.",
			5,
			0.2,
			Vector2i(1, 1),
			"",
			"common",
			"The soul is a held line. Hold it."
		],
		[
			relics,
			"QUINE Shard",
			"A fragment of pre-Bloom machine, one cyan light still faintly alive.",
			1,
			1.1,
			Vector2i(1, 1),
			"",
			"mythic",
			"It is still counting. No one knows what."
		],
	]
	for r in rows:
		var ent := Pandora.create_entity(r[1], r[0])
		_assign(ent, "Display Name", r[1])
		_assign(ent, "Description", r[2])
		_assign(ent, "Max Stack Size", r[3])
		_assign(ent, "Weight", r[4])
		_assign(ent, "Grid Size", r[5])
		_assign(ent, "Equip Slot", r[6])
		_assign(ent, "Rarity", r[7])
		_assign(ent, "Flavour", r[8])


# --- Spells: PLACEHOLDER mechanics referencing canon elements ----------------------------


func _seed_spells() -> void:
	var root := _cat("Spells")
	Pandora.create_property(root, "Display Name", "string")
	Pandora.create_property(root, "Description", "string")
	Pandora.create_property(root, "Element", "reference")
	Pandora.create_property(root, "Soul Cost", "int")
	Pandora.create_property(root, "Placeholder", "bool")

	var by_name := {}
	for e in Pandora.get_all_entities(_cats["Elements"]):
		by_name[e.get_entity_name()] = e

	var rows := [
		[
			"Ember Chord",
			"Khash",
			4,
			"A struck chord of fire; louder if Sul or Mozh sounded this measure."
		],
		[
			"Still Water",
			"Luth",
			3,
			"Quiets one surface to mirror-calm; suppressed while Khash rings."
		],
		["Hushfall", "Zhem", 6, "A hole with edges: silences a zone's tone for one measure."],
	]
	for r in rows:
		var ent := Pandora.create_entity(r[0], root)
		_assign(ent, "Display Name", r[0])
		_assign(ent, "Element", by_name[r[1]])
		_assign(ent, "Soul Cost", r[2])
		_assign(ent, "Description", r[3])
		_assign(ent, "Placeholder", true)


# --- Effects: PLACEHOLDER status shapes for GAS later ------------------------------------


func _seed_effects() -> void:
	var root := _cat("Effects")
	Pandora.create_property(root, "Display Name", "string")
	Pandora.create_property(root, "Description", "string")
	Pandora.create_property(root, "Duration Type", "string")
	Pandora.create_property(root, "Placeholder", "bool")

	var rows := [
		["Burning", "Khash damage over time; ends early if Luth sounds.", "duration"],
		[
			"Detuned",
			"The Waning's fizzle-state: next casting rolls against a worse Agreement.",
			"duration"
		],
		["Soul Drain", "The Gauge only goes down. This makes it go down faster.", "duration"],
		["Warded", "A held line against one named element.", "duration"],
	]
	for r in rows:
		var ent := Pandora.create_entity(r[0], root)
		_assign(ent, "Display Name", r[0])
		_assign(ent, "Description", r[1])
		_assign(ent, "Duration Type", r[2])
		_assign(ent, "Placeholder", true)


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


func _seed_locations() -> void:
	var root := _cat("Locations")
	Pandora.create_property(root, "Display Name", "string")
	Pandora.create_property(root, "Epithet", "string")
	Pandora.create_property(root, "Patron", "string")
	Pandora.create_property(root, "Agreement", "string")
	Pandora.create_property(root, "Vault Id", "string")

	var rows := [
		["Vervulling", "The Twinfire Capital", "Maiiam", "91–93%", "vervulling"],
		["Deivel Zeit", "", "Haeren", "90–92%", "deivel"],
		["Dom", "", "Kero", "", "dom"],
		["Karrn-Vash", "", "Blidnisch", "", "karrn-vash"],
		["Solmarch", "", "Sulmae (the mask)", "", "solmarch"],
		["Rennen", "", "Pazzah", "", "rennen"],
		["Tweede", "", "Vicoar", "", "tweede"],
		["Pozor", "", "Stuid", "", "pozor"],
		["Lefren", "", "Fickah", "", "lefren"],
		["Milinel", "", "Izhakel", "", "milinel"],
		["Verspch", "", "Ofshütje", "", "verspch"],
		["Loamgate", "", "Vhorr", "84–87%", "loamgate"],
	]
	for r in rows:
		var ent := Pandora.create_entity(r[0], root)
		_assign(ent, "Display Name", r[0])
		_assign(ent, "Epithet", r[1])
		_assign(ent, "Patron", r[2])
		_assign(ent, "Agreement", r[3])
		_assign(ent, "Vault Id", r[4])


# --- Lore: bridge entries into the vault (id + path; prose STAYS in the vault) -----------


func _seed_lore() -> void:
	var root := _cat("Lore")
	Pandora.create_property(root, "Display Name", "string")
	Pandora.create_property(root, "Summary", "string")
	Pandora.create_property(root, "Vault Id", "string")
	Pandora.create_property(root, "Vault Path", "string")

	var rows := [
		[
			"The Waning",
			"Maiiam is withdrawing; magic is dying; the Agreement loosens.",
			"the-waning",
			"cosmology/the-waning.md"
		],
		[
			"The Bloom",
			"Year 0: Kronos unmade into the Mycosphere. The world composted — literally.",
			"the-bloom",
			"eras/the-bloom.md"
		],
		[
			"The Soul Gauge",
			"Souls are Weft-anchored patterns; magic spends them, mostly downward.",
			"souls",
			"cosmology/souls.md"
		],
		[
			"Verleidenlot",
			"The Kes'reth mass-emergence — the Waning's true, unrecognized origin.",
			"verleidenlot",
			"locations/verleidenlot.md"
		],
		[
			"The Taubstummers",
			"The sealed soul-weapons that broke the Tidal Dominion.",
			"last-great-war",
			"eras/last-great-war.md"
		],
		[
			"The Wheel of Ten",
			"Ten elements; adjacency is Chord, opposition is Clash.",
			"magic-system",
			"systems/magic-system.md"
		],
	]
	for r in rows:
		var ent := Pandora.create_entity(r[0], root)
		_assign(ent, "Display Name", r[0])
		_assign(ent, "Summary", r[1])
		_assign(ent, "Vault Id", r[2])
		_assign(ent, "Vault Path", r[3])
