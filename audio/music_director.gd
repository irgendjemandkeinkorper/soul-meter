extends Node
## Project-owned music context director.
##
## Gameplay asks for stable context IDs; this node owns the asset mapping and
## player lifecycle. Missing optional tracks intentionally degrade to silence.

const FADE_DURATION: float = 1.0
const TRACK_MAP: Dictionary = {
	"title": "res://assets/audio/music/title.ogg",
	"field": "res://assets/audio/music/field.ogg",
	"battle": "res://assets/audio/music/battle.ogg",
	"chapter_complete": "res://assets/audio/music/chapter_complete.ogg",
}

var context_stack: Array[String] = []
var _current_context: String = ""
var _active_player: AudioStreamPlayer = null


func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS


func play_context(context_id: String) -> void:
	context_stack.clear()
	context_stack.push_back(context_id)
	_transition_to_context(context_id)


func push_context(context_id: String) -> void:
	if not context_stack.is_empty():
		var current: String = context_stack.back()
		if current == context_id:
			return
	context_stack.push_back(context_id)
	_transition_to_context(context_id)


func pop_context() -> void:
	if not context_stack.is_empty():
		context_stack.pop_back()
	_transition_to_context(context_stack.back() if not context_stack.is_empty() else "")


func get_current_context() -> String:
	return _current_context


func get_context_stack() -> Array[String]:
	return context_stack.duplicate()


func _transition_to_context(context_id: String) -> void:
	if _current_context == context_id:
		return
	_current_context = context_id

	if is_instance_valid(_active_player) and _active_player.playing:
		_fade_out_and_free(_active_player)
		_active_player = null

	if context_id.is_empty() or not TRACK_MAP.has(context_id):
		if not context_id.is_empty():
			push_warning("MusicDirector: unknown context '%s'; falling back to silence." % context_id)
		return

	var path: String = str(TRACK_MAP[context_id])
	if not ResourceLoader.exists(path):
		push_warning(
			"MusicDirector: missing track for context '%s' at '%s'; falling back to silence."
			% [context_id, path]
		)
		return

	var stream: AudioStream = load(path) as AudioStream
	if stream == null:
		push_warning("MusicDirector: could not load track '%s'; falling back to silence." % path)
		return

	var player: AudioStreamPlayer = AudioStreamPlayer.new()
	player.stream = stream
	player.bus = &"Music"
	player.volume_db = -80.0
	add_child(player)
	player.play()
	_active_player = player
	_fade_in(player)


func _fade_out_and_free(player: AudioStreamPlayer) -> void:
	var tween: Tween = create_tween()
	tween.tween_property(player, "volume_db", -80.0, FADE_DURATION)
	tween.tween_callback(player.queue_free)


func _fade_in(player: AudioStreamPlayer) -> void:
	var tween: Tween = create_tween()
	tween.tween_property(player, "volume_db", 0.0, FADE_DURATION)
