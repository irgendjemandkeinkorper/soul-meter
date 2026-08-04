class_name BuildingTransitionDefinition
extends Resource
## Data-only definition for one directed building doorway.

@export var id: StringName = &""
@export var building_id: StringName = &""
@export var building_name: String = ""
@export_enum("enter", "exit") var direction: String = "enter"
@export_file("*.tscn") var source_scene: String = ""
@export var source_anchor: StringName = &""
@export var source_position := Vector2.ZERO
@export_file("*.tscn") var destination_scene: String = ""
@export var destination_location_id: StringName = &""
@export var spawn_id: StringName = &"default"
@export var destination_spawn_position := Vector2.ZERO
@export var prompt_text: String = "E — ENTER"
@export var required_flag: String = ""
@export var reputation_faction: String = ""
@export var minimum_reputation_band: StringName = &""
@export var locked_message: String = "This door is locked."


func is_entry() -> bool:
	return direction == "enter"


func is_exit() -> bool:
	return direction == "exit"
