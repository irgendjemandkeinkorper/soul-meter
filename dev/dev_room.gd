extends Node2D
## Door destinations stay on the existing flow/location contracts.

static func destinations() -> Dictionary:
	return {
		"Dom": GameFlow.TOWN_SCENE,
		"Ashlaren": LocationRegistry.ASHLAREN.scene_path,
		"Kesselford": LocationRegistry.KESSELFORD.scene_path,
		"LongVerge": LocationRegistry.LONG_VERGE.scene_path,
		"Hollowmere": LocationRegistry.HOLLOWMERE.scene_path,
		"Wilds": GameFlow.WILDS_SCENE,
		"DorthkorRoad": GameFlow.DORTHKOR_SCENE,
		"WoundLip": GameFlow.WOUND_LIP_SCENE,
	}


func _enter_tree() -> void:
	# Assign before the TravelExit children resolve their destinations in _ready().
	var doors := destinations()
	for door_name: String in doors:
		var door := get_node("DoorBoard/" + door_name) as TravelExit
		door.target_scene = str(doors[door_name])
