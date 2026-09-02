class_name ElementDefinition
extends RefCounted

## Runtime form of one Pandora-authored element row.

var id: StringName = &""
var display_name: String = ""
var vault_id: String = ""
var imposition_id: StringName = &""
var imposition_display_name: String = ""
var rule_bend_id: StringName = &""
var rule_bend_description: String = ""
var deals_damage: bool = true

## Short aliases keep the domain vocabulary readable at call sites.
var imposition: StringName:
	get:
		return imposition_id

var rule_bend: StringName:
	get:
		return rule_bend_id


static func from_row(row: Dictionary) -> ElementDefinition:
	var definition := ElementDefinition.new()
	definition.id = _name(row.get("id", ""))
	definition.display_name = str(row.get("display_name", definition.id))
	definition.vault_id = str(row.get("vault_id", ""))
	definition.imposition_id = _name(row.get("imposition_id", ""))
	definition.imposition_display_name = str(row.get("imposition_display_name", ""))
	definition.rule_bend_id = _name(row.get("rule_bend_id", ""))
	definition.rule_bend_description = str(row.get("rule_bend_description", ""))
	definition.deals_damage = bool(row.get("deals_damage", true))
	return definition


func to_dict() -> Dictionary:
	return {
		"id": id,
		"display_name": display_name,
		"vault_id": vault_id,
		"imposition_id": imposition_id,
		"imposition_display_name": imposition_display_name,
		"rule_bend_id": rule_bend_id,
		"rule_bend_description": rule_bend_description,
		"deals_damage": deals_damage,
	}


static func _name(value: Variant) -> StringName:
	return StringName(str(value).to_lower())
