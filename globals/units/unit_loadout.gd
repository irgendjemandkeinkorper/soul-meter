class_name UnitLoadout
extends Resource
## One row of the `unit_loadout` table (issue #141): what a unit brings into a battle.
##
## `equip` is deliberately a plain Dictionary (the issue's `equip json`): equipment
## already has an owner in GLoot/Pandora, and duplicating item structure here would
## create a second source of truth. Values are item ids, resolved by the inventory
## layer, never loaded from this table.

@export var unit_id: String = ""
## Optional FK into `jobs` — the discipline the unit fields.
@export var primary_job_id: String = ""
## Optional FK into `jobs` — the borrowed action set.
@export var secondary_job_id: String = ""
## Explicitly selected `action`-slot abilities available to this unit.
@export var action_ability_ids: PackedStringArray = []
## FK into `abilities`, must be a `reaction`-slot ability.
@export var reaction_ability_id: String = ""
## FK into `abilities`, must be a `passive`-slot ability.
@export var passive_ability_id: String = ""
## equip slot name -> item id.
@export var equip: Dictionary = {}


static func create(p_unit_id: String) -> UnitLoadout:
	var loadout := UnitLoadout.new()
	loadout.unit_id = p_unit_id
	return loadout


func to_dict() -> Dictionary:
	return {
		"unit_id": unit_id,
		"primary_job_id": primary_job_id,
		"secondary_job_id": secondary_job_id,
		"action_ability_ids": Array(action_ability_ids),
		"reaction_ability_id": reaction_ability_id,
		"passive_ability_id": passive_ability_id,
		"equip": equip.duplicate(true),
	}


static func from_dict(data: Dictionary) -> UnitLoadout:
	var loadout := UnitLoadout.new()
	loadout.unit_id = str(data.get("unit_id", ""))
	loadout.primary_job_id = str(data.get("primary_job_id", ""))
	loadout.secondary_job_id = str(data.get("secondary_job_id", ""))
	loadout.action_ability_ids = PackedStringArray(data.get("action_ability_ids", []))
	loadout.reaction_ability_id = str(data.get("reaction_ability_id", ""))
	loadout.passive_ability_id = str(data.get("passive_ability_id", ""))
	var equipped: Variant = data.get("equip", {})
	loadout.equip = (equipped as Dictionary).duplicate(true) if equipped is Dictionary else {}
	return loadout
