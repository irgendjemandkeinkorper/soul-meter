extends Node
## MusicDirector — Project-owned music context director.
##
## Centralizes music asset layout mapping, supports playing, pushing, and popping contexts,
## and fades tracks gracefully. Safely falls back to silence with a clear warning if a track
## is not yet supplied.

const FADE_DURATION: float = 1.0

# Centralized track mapping
const TRACK_MAP: Dictionary = {
	"title": "res://assets/audio/music/title.ogg",
	"field": "res://assets/audio/music/field.ogg",
	"battle": "res://assets/audio/music/battle.ogg",
	"chapter_complete": "res://assets/audio/music/chapter_complete.ogg"
}

# Track context stack for pushing/popping
var context_stack: Array[String] = []

# Current active players
var _current_context: String = ""
var _active_player: AudioStreamPlayer = null


func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS


## Requests playing a music context directly, replacing any existing context stack.
func play_context(context_id: String) -> void:
	context_stack.clear()
	context_stack.push_back(context_id)
	_transition_to_context(context_id)


## Pushes a new music context onto the stack and transitions to it.
func push_context(context_id: String) -> void:
	if not context_stack.is_empty():
		var current := context_stack.back()
		if current == context_id:
			# Idempotent push of the same context
			return
	context_stack.push_back(context_id)
	_transition_to_context(context_id)


## Pops the current music context from the stack and transitions back to the previous context.
func pop_context() -> void:
	if context_stack.is_empty():
		_transition_to_context("")
		return
	context_stack.pop_back()
	if context_stack.is_empty():
		_transition_to_context("")
	else:
		_transition_to_context(context_stack.back())


## Returns the currently playing context ID.
func get_current_context() -> String:
	return _current_context


## Returns the context stack (as a read-only or copy).
func get_context_stack() -> Array[String]:
	return context_stack.duplicate()


func _transition_to_context(context_id: String) -> void:
	if _current_context == context_id:
		# Idempotent: repeated requests for the same context are ignored
		return

	_current_context = context_id

	# Fade out current active player if it exists
	if is_instance_valid(_active_player) and _active_player.playing:
		_fade_out_and_free(_active_player)
		_active_player = null

	if context_id == "" or not TRACK_MAP.has(context_id):
		if context_id != "":
			push_warning("MusicDirector: Context '%s' is not defined in the TRACK_MAP." % context_id)
		return

	var path: String = TRACK_MAP[context_id]
	if not ResourceLoader.exists(path):
		push_warning("MusicDirector: Track file not found for context '%s' at '%s'. Falling back to silence." % [context_id, path])
		return

	var stream: AudioStream = load(path)
	if not stream:
		push_warning("MusicDirector: Failed to load stream for context '%s' at '%s'. Falling back to silence." % [context_id, path])
		return

	# Setup the new player
	var player := AudioStreamPlayer.new()
	player.stream = stream
	player.bus = &"Music"
	player.volume_db = -80.0
	add_child(player)
	player.play()

	_active_player = player
	_fade_in(player)


func _fade_out_and_free(player: AudioStreamPlayer) -> void:
	var tween := create_tween()
	tween.tween_property(player, "volume_db", -80.0, FADE_DURATION)
	tween.tween_callback(player.queue_free)


func _fade_in(player: AudioStreamPlayer) -> void:
	var tween := create_tween()
	# Reset to standard 0.0 dB
	tween.tween_property(player, "volume_db", 0.0, FADE_DURATION)
