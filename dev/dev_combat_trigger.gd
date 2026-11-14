extends SMInteractable
## The same on-field encounter entry as the Lower Trial Hall; existing enemy data only.

@export var encounter_id: StringName = &"bog-wight"


func _apply_interaction() -> void:
	var field: FieldMap = Battle._current_field_map()
	var opened := Battle.start_set_piece(field, encounter_id)
	if bool(opened.get("allowed", false)) and not Battle.ended:
		GameFlow.send_event("enter_set_piece")
