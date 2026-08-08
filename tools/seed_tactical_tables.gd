extends Node
## seed_tactical_tables.gd — ADDITIVE, idempotent Pandora schema seeder for the six
## tactical-layer tables of issue #141 (Elemental Architecture Section III):
##   Jobs, Abilities, Units, Unit Jobs, Unit Attunement, Unit Loadout
##
## WHY A SECOND SEEDER. tools/seed_pandora.gd is a one-shot bootstrap: it aborts the
## moment res://data.pandora has any root, so it can never add a table to the committed
## data. This script adds only the roots it is missing and creates only the property
## definitions on them — it never touches an existing root, and it never edits or
## deletes anything already authored.
##
## SCHEMA ONLY — ZERO ROWS. It creates no entities. That is deliberate and is the
## acceptance condition of issue #141: the naming of combat disciplines is canon owned
## by GitHub #132 (docs/prd-amendment-tactical-layer.md §9.1, DECIDED 2026-08-05 —
## combat disciplines, Patron remains the class). Inventing a job or an ability name
## here would resolve canon by accident.
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
		["Reaction Ability Id", "string"],
		["Passive Ability Id", "string"],
		# JSON object: equip slot name -> item id.
		["Equip", "string"],
	],
}


func _ready() -> void:
	await get_tree().process_frame
	if not Pandora.is_loaded():
		Pandora.load_data()
	var created := seed_tables()
	if created.is_empty():
		print("SEED-TACTICAL: all six tables already present — nothing to do (idempotent).")
	else:
		Pandora.save_data()
		print("SEED-TACTICAL: created roots -> ", ", ".join(created))
	get_tree().quit()


## Creates any missing table root plus its properties. Returns the roots created.
## Never mutates a root that already exists.
static func seed_tables() -> PackedStringArray:
	var created := PackedStringArray()
	for table_name: String in TABLES:
		if _root_by_name(table_name) != null:
			continue
		var root := Pandora.create_category(table_name)
		for definition: Array in TABLES[table_name]:
			Pandora.create_property(root, definition[0], definition[1])
		created.append(table_name)
	return created


static func _root_by_name(name: String) -> PandoraCategory:
	for root: PandoraCategory in Pandora.get_all_roots():
		if root.get_entity_name() == name:
			return root
	return null
