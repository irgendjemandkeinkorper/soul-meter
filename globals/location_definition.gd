class_name LocationDefinition
extends Resource
## Data contract for a loadable gameplay location.

@export var id: StringName = &""
@export_file("*.tscn") var scene_path: String = ""
@export var allowed_gameplay: bool = true
@export var default_spawn_id: StringName = &"default"
@export var spawns: Dictionary = {}
@export var arrival_flag: String = ""
@export var arrival_checkpoint: String = ""


func resolve_spawn(requested: StringName) -> StringName:
	if requested == &"default":
		return default_spawn_id
	if spawns.has(String(requested)):
		return StringName(spawns[String(requested)])
	return default_spawn_id
