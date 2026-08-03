class_name TriadDefinition
extends RefCounted

## Runtime form of one Pandora-authored Triad row.

var id: StringName = &""
var display_name: String = ""
var elements: Array[StringName] = []
var center_element: StringName = &""
var unique_effect_id: StringName = &""
var unique_effect_display_name: String = ""
var unique_effect_parameters: Dictionary = {}

var center: StringName:
	get:
		return center_element


static func from_row(row: Dictionary) -> TriadDefinition:
	var definition := TriadDefinition.new()
	definition.id = _name(row.get("id", ""))
	definition.display_name = str(row.get("display_name", definition.id))
	var authored_elements: Variant = row.get("elements", [])
	if authored_elements is Array:
		for authored_element: Variant in authored_elements:
			definition.elements.append(_name(authored_element))
	definition.center_element = _name(row.get("center", ""))
	var effect: Variant = row.get("unique_effect", {})
	if effect is Dictionary:
		definition.unique_effect_id = _name(effect.get("id", ""))
		definition.unique_effect_display_name = str(effect.get("display_name", ""))
		var parameters: Variant = effect.get("parameters", {})
		if parameters is Dictionary:
			definition.unique_effect_parameters = parameters.duplicate(true)
	return definition


func contains_element(element_id: StringName) -> bool:
	return elements.has(element_id)


func to_dict() -> Dictionary:
	return {
		"id": id,
		"display_name": display_name,
		"elements": elements.duplicate(),
		"center": center_element,
		"unique_effect": {
			"id": unique_effect_id,
			"display_name": unique_effect_display_name,
			"parameters": unique_effect_parameters.duplicate(true),
		},
	}


static func _name(value: Variant) -> StringName:
	return StringName(str(value).to_lower())
