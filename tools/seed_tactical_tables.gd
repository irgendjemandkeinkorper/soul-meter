extends Node
## seed_tactical_tables.gd — idempotent Pandora schema seeder for the six
## tactical-layer tables of issue #141 (Elemental Architecture Section III):
##   Jobs, Abilities, Units, Unit Jobs, Unit Attunement, Unit Loadout
##
## WHY A SECOND SEEDER. tools/seed_pandora.gd is a one-shot bootstrap: it aborts the
## moment res://data.pandora has any root, so it can never add a table to the committed
## data. This script adds only the roots it is missing and creates only the property
## definitions or baseline rows that are missing. The one removal below retires a test fixture
## that was accidentally seeded as canonical data; all authored rows remain additive-only.
##
## Run headless: register as a temp autoload and run once (see DEPENDENCIES.md), or
##   ~/.local/bin/godot --headless --path . --script tools/seed_tactical_tables.gd
## NOTE: `godot --headless --script` aborts at teardown ~20-30% of the time in this
## environment. Judge the printed output, never the exit code.

const TABLES := {
	"Jobs":
	[
		["Job Id", "string"],
		["Display Name", "string"],
		["Tier", "int"],
		["Element Id", "string"],
		["Requires Job Id", "string"],
		["Growth HP", "float"],
		["Growth MP", "float"],
		["Growth SPD", "float"],
		["Vault Id", "string"],
	],
	"Abilities":
	[
		["Ability Id", "string"],
		["Display Name", "string"],
		["Job Id", "string"],
		["Slot", "string"],
		["Element Id", "string"],
		["Power", "int"],
		["MP Cost", "int"],
		# CT Cost replaces the old AP cost. Bounds live with the CT economy in
		# globals/combat/turn_scheduler.gd (READY_AT = 100); the generator enforces them.
		["CT Cost", "int"],
		["Range", "int"],
		["AoE", "int"],
		["Vertical", "int"],
		["Vault Id", "string"],
	],
	"Units":
	[
		["Unit Id", "string"],
		["Display Name", "string"],
		["Epithet", "string"],
		["Base HP", "int"],
		["Base MP", "int"],
		["Base SPD", "int"],
		["Move", "int"],
		["Jump", "int"],
		# An opaque reference, never a resource path: units must not become a second
		# portrait-loading path around PartyMember's #66 extension allowlist.
		["Portrait Ref", "string"],
		["Vault Id", "string"],
	],
	"Unit Jobs":
	[
		["Row Id", "string"],
		["Unit Id", "string"],
		["Job Id", "string"],
		["JP", "int"],
		# JSON array of ability ids.
		["Mastered", "string"],
	],
	"Unit Attunement":
	[
		["Row Id", "string"],
		["Unit Id", "string"],
		["Element Id", "string"],
		# Signed, -3 .. +3, one row per element of the Wheel of Ten.
		# UI RULE: never rendered as ten meters — see globals/units/unit_attunement.gd.
		["Value", "int"],
	],
	"Unit Loadout":
	[
		["Row Id", "string"],
		["Unit Id", "string"],
		["Primary Job Id", "string"],
		["Secondary Job Id", "string"],
		# JSON array of explicitly selected action-slot ability ids.
		["Action Ability Ids", "string"],
		["Reaction Ability Id", "string"],
		["Passive Ability Id", "string"],
		# JSON object: equip slot name -> item id.
		["Equip", "string"],
	],
}

const CAST_UNIT_ROWS := [
	{
		"Unit Id": "vex",
		"Display Name": "Vex",
		"Epithet": "",
		"Base HP": 44,
		"Base MP": 6,
		"Base SPD": 6,
		"Move": 4,
		"Jump": 1,
		"Portrait Ref": "",
		"Vault Id": "",
		"Action Ability Ids": '["note-scor"]',
	},
]

const RETIRED_FIXTURE_UNIT_ID := "caster"


func _ready() -> void:
	await get_tree().process_frame
	if not Pandora.is_loaded():
		Pandora.load_data()
	var changes := seed_tables()
	if changes.is_empty():
		print("SEED-TACTICAL: all six tables already present — nothing to do (idempotent).")
	else:
		Pandora.save_data()
		print("SEED-TACTICAL: applied changes -> ", ", ".join(changes))
	get_tree().quit()


## Creates only missing roots, properties, and baseline rows.
static func seed_tables() -> PackedStringArray:
	var created := PackedStringArray()
	for table_name: String in TABLES:
		var root := _root_by_name(table_name)
		if root == null:
			root = Pandora.create_category(table_name)
			created.append(table_name)
		for definition: Array in TABLES[table_name]:
			if not root.has_entity_property(definition[0]):
				Pandora.create_property(root, definition[0], definition[1])
				created.append("%s.%s" % [table_name, definition[0]])
	_remove_retired_cast_fixture(created)
	_seed_note_abilities(created)
	_seed_cast_units(created)
	return created


static func _remove_retired_cast_fixture(changes: PackedStringArray) -> void:
	for table_name: String in ["Units", "Unit Loadout"]:
		var root := _root_by_name(table_name)
		for candidate: PandoraEntity in Pandora.get_all_entities(root):
			if candidate is PandoraCategory:
				continue
			if candidate.get_string("Unit Id") != RETIRED_FIXTURE_UNIT_ID:
				continue
			Pandora.delete_entity(candidate)
			changes.append("removed %s/%s" % [table_name, RETIRED_FIXTURE_UNIT_ID])
			break


static func _seed_note_abilities(created: PackedStringArray) -> void:
	var root := _root_by_name("Abilities")
	for element: ElementDefinition in ElementsData.all_elements():
		var ability_id := "note-%s" % element.id
		if _ensure_entity(root, "Ability Id", ability_id, "%s Note" % element.display_name, {
			"Ability Id": ability_id,
			"Display Name": "%s Note" % element.display_name,
			"Job Id": "",
			"Slot": "action",
			"Element Id": String(element.id),
			"Power": 6,
			"MP Cost": 1,
			"CT Cost": 30,
			"Range": 3,
			"AoE": 0,
			"Vertical": 0,
			"Vault Id": element.vault_id,
		}):
			created.append("Abilities/%s" % ability_id)


static func _seed_cast_units(created: PackedStringArray) -> void:
	var units_root := _root_by_name("Units")
	var loadouts_root := _root_by_name("Unit Loadout")
	for row: Dictionary in CAST_UNIT_ROWS:
		var unit_id: String = row["Unit Id"]
		var unit_values := row.duplicate(true)
		unit_values.erase("Action Ability Ids")
		if _ensure_entity(
			units_root, "Unit Id", unit_id, str(row["Display Name"]), unit_values
		):
			created.append("Units/%s" % unit_id)
		if _ensure_entity(loadouts_root, "Unit Id", unit_id, "%s Loadout" % row["Display Name"], {
			"Row Id": unit_id,
			"Unit Id": unit_id,
			"Primary Job Id": "",
			"Secondary Job Id": "",
			"Action Ability Ids": row["Action Ability Ids"],
			"Reaction Ability Id": "",
			"Passive Ability Id": "",
			"Equip": "{}",
		}):
			created.append("Unit Loadout/%s" % unit_id)


static func _ensure_entity(
	root: PandoraCategory,
	id_property: String,
	id_value: String,
	entity_name: String,
	values: Dictionary,
) -> bool:
	for candidate: PandoraEntity in Pandora.get_all_entities(root):
		if not candidate is PandoraCategory and candidate.get_string(id_property) == id_value:
			return false
	var entity := Pandora.create_entity(entity_name, root)
	for property_name: String in values:
		var property := entity.get_entity_property(property_name)
		assert(property != null, "Missing Pandora property '%s'" % property_name)
		property.set_default_value(values[property_name])
	return true


static func _root_by_name(name: String) -> PandoraCategory:
	for root: PandoraCategory in Pandora.get_all_roots():
		if root.get_entity_name() == name:
			return root
	return null
