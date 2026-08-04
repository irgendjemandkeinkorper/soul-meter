extends Node
## Presentation adapter for Battle's speech request. Dialogue Manager instantiates
## the registered Echo Gate balloon, so combat does not grow a second presenter.


func _ready() -> void:
	Battle.speech_requested.connect(_on_speech_requested)


func present(
	dialogue_path: String, dialogue_start: String, extra_game_states: Array = []
) -> Node:
	var resource := load(dialogue_path) as DialogueResource
	if resource == null:
		push_error("Could not load combat dialogue resource: %s" % dialogue_path)
		return null
	var states := extra_game_states.duplicate()
	if states.is_empty():
		states.append(Battle)
	return DialogueManager.show_dialogue_balloon(resource, dialogue_start, states)


func _on_speech_requested(dialogue_path: String, dialogue_start: String) -> void:
	present(dialogue_path, dialogue_start)
