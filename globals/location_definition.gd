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
## Local Harmonic Accord presented to the casting fizzle context — the same quantity
## previously called Agreement Integrity (owner ruling, #329). C21 owns authored
## per-location values; 100 is the neutral fallback for un-authored areas.
@export_range(0.0, 100.0, 1.0) var harmonic_accord: float = 100.0
## FR-506 thinning gradient: 0 = Dom (stable), rising toward the front
## (Wound Lip = 3). Consumed as a Harmonic Accord INPUT via
## SkillCheck.location_fizzle_integrity() — never as a formula change.
@export_range(0, 3) var thinning_tier := 0


func resolve_spawn(requested: StringName) -> StringName:
	if requested == &"default":
		return default_spawn_id
	if spawns.has(String(requested)):
		return StringName(spawns[String(requested)])
	return default_spawn_id
