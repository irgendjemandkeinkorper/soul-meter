class_name CombatAudio
extends Node
## Presentation-only combat sound consumer. It maps immutable CombatEvent data
## to cues and never reads Battle or CombatController state.

const CUE_HIT := &"hit"
const CUE_DEFINING_STRIKE := &"defining_strike"
const CUE_BALANCE_EXTREME := &"balance_extreme"

const SOUND_PATHS: Dictionary = {
	CUE_HIT: [
		"res://assets/audio/sfx/impactPunch_medium_000.ogg",
		"res://assets/audio/sfx/impactPunch_medium_001.ogg",
		"res://assets/audio/sfx/impactPunch_medium_002.ogg",
		"res://assets/audio/sfx/impactPunch_medium_003.ogg",
		"res://assets/audio/sfx/impactPunch_medium_004.ogg",
	],
	CUE_DEFINING_STRIKE: ["res://assets/audio/sfx/impactGlass_heavy_003.ogg"],
	CUE_BALANCE_EXTREME: ["res://assets/audio/sfx/impactBell_heavy_004.ogg"],
}

var _rng := RandomNumberGenerator.new()
var _last_variant_by_cue: Dictionary = {}


func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	_rng.randomize()


func consume_event(event: CombatEvent) -> void:
	var cue := cue_for_event(event)
	if cue.is_empty():
		return
	var paths := sound_paths_for_cue(cue)
	if paths.is_empty():
		return
	var index := _rng.randi_range(0, paths.size() - 1)
	var previous_index := int(_last_variant_by_cue.get(cue, -1))
	if paths.size() > 1 and index == previous_index:
		index = (index + _rng.randi_range(1, paths.size() - 1)) % paths.size()
	_last_variant_by_cue[cue] = index
	_play_one_shot(paths[index])


static func cue_for_event(event: CombatEvent) -> StringName:
	if event == null:
		return &""
	if event.type == &"balance_band_changed":
		var effects: Variant = event.data.get("effects", {})
		if effects is Dictionary and int(effects.get("damage_bonus", 0)) > 0:
			return CUE_BALANCE_EXTREME
		return &""
	if event.type != &"action_resolved" or int(event.data.get("damage", 0)) <= 0:
		return &""
	if bool(event.data.get("defining_strike", false)):
		return CUE_DEFINING_STRIKE
	return CUE_HIT


static func sound_paths_for_cue(cue: StringName) -> Array[String]:
	var result: Array[String] = []
	var paths: Variant = SOUND_PATHS.get(cue, [])
	if paths is Array:
		for path: Variant in paths:
			if path is String:
				result.append(path)
	return result


func _play_one_shot(path: String) -> void:
	var stream := load(path) as AudioStream
	if stream == null:
		push_warning("CombatAudio: could not load sound '%s'." % path)
		return
	var player := AudioStreamPlayer.new()
	player.stream = stream
	player.bus = &"SFX"
	player.finished.connect(player.queue_free)
	add_child(player)
	player.play()
