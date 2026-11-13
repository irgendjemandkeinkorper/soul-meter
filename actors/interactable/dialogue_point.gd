class_name DialoguePoint
extends SMInteractable
## A door, mechanism or site whose choices are authored in dialogue: pressing interact opens
## `dialogue_start` in `dialogue_path`, every time, so skill checks, item use and flags stay in
## the dialogue file the way NPC conversations keep them (the Lower Trial Hall's store door and
## blast seam, 2026-11-04). Range, prompt, `required_flag` and the autosave are SMInteractable's.

@export_file("*.dialogue") var dialogue_path := ""
@export var dialogue_start := "start"


func _ready() -> void:
	repeatable = true
	# SMInteractable shows `interaction_text` once the interaction ran; here it runs again on
	# every press, so the prompt stays the prompt.
	interaction_text = "E — " + prompt_text
	super._ready()


func _apply_interaction() -> void:
	super._apply_interaction()
	var dialogue := load(dialogue_path) as DialogueResource
	if dialogue == null:
		push_error("DialoguePoint '%s' cannot load dialogue '%s'." % [name, dialogue_path])
		return
	DialogueManager.show_dialogue_balloon(dialogue, dialogue_start)
