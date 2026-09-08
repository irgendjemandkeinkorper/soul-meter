class_name SMInteractable
extends Area2D
## Small field interaction used for signs, shrines, and other non-character events.
## It deliberately owns only durable facts and feedback; quest/reputation policy
## remains in dialogue or the relevant singleton.

@export var display_name: String = "INTERACT"
@export var prompt_text: String = "INTERACT"
@export_multiline var interaction_text: String = "You find nothing that needs doing."
@export var interaction_flag: String = ""
@export var required_flag: String = ""
@export var locked_message: String = "That is not available yet."

## FR-402 / game-identity ruling 7 ("stats matter outside combat"), #284.
## A DRAMGID skill id from `DramgidSchema.SKILLS` — `slip` for a lock, `strain`
## for forcing something. Empty means this interactable has no skill lock and
## behaves exactly as before. A skill lock is INDEPENDENT of `required_flag`:
## a flag gate says "not yet", a skill lock says "not by you, not like that".
@export var lock_skill: String = ""
## PROVISIONAL — difficulty is DeepSeek's per #284's "do not decide" boundary.
## Passed to `SkillCheck.resolve()` as a situational modifier, so 0.0 is the
## unmodified skill chance and negative numbers make the lock harder.
@export var lock_modifier: float = 0.0
## Durable id for this lock's outcome flags. `Chest` defaults it to its
## `container_id`. Required whenever `lock_skill` is set, or the outcome cannot
## be recorded and the check would be re-rollable by walking away.
@export var lock_id: String = ""
@export var lock_failed_message: String = "The mechanism does not give. Not this time."
@export var marker_color := Color("#B8860B")
@export var repeatable := false
@export var save_point := false
@export var shop_type := ""

var _player_in_range := false
var _used := false
var _prompt: Label
var _sign: Label


func _ready() -> void:
	_used = not interaction_flag.is_empty() and GameState.flag_is_true(interaction_flag)
	_prompt = $Prompt
	_sign = $Sign
	_sign.text = display_name
	$Marker.color = marker_color
	_prompt.visible = false
	_refresh_prompt()

	var range_area := Area2D.new()
	var shape := CollisionShape2D.new()
	var circle := CircleShape2D.new()
	circle.radius = 96.0
	shape.shape = circle
	range_area.add_child(shape)
	add_child(range_area)
	range_area.body_entered.connect(_on_body.bind(true))
	range_area.body_exited.connect(_on_body.bind(false))
	GameState.flag_changed.connect(_on_flag_changed)


func _on_body(body: Node2D, entered: bool) -> void:
	if body is Player:
		_player_in_range = entered
		_prompt.visible = entered
		if entered:
			_refresh_prompt()


func _unhandled_input(event: InputEvent) -> void:
	if not _player_in_range or not event.is_action_pressed("interact") or get_tree().paused:
		return
	get_viewport().set_input_as_handled()
	if _skill_lock_is_live():
		# A flag gate outranks a skill lock: do not spend the one attempt on a
		# container the player is not yet allowed to be opening at all.
		if not required_flag.is_empty() and not GameState.flag_is_true(required_flag):
			_prompt.text = "LOCKED — " + locked_message
			return
		var attempt := attempt_skill_lock()
		if not bool(attempt.get("success", false)):
			_prompt.text = "LOCKED — " + lock_failed_message
			return
		_refresh_prompt()
	if not _is_unlocked():
		_prompt.text = "LOCKED — " + locked_message
		return
	if _used and not repeatable:
		_prompt.text = interaction_text
		return
	_apply_interaction()
	if not repeatable:
		_used = true
	_prompt.text = interaction_text
	SaveGame.request_autosave(
		("save-point-" if save_point else "town-event-") + name.to_snake_case()
	)
	if not shop_type.is_empty():
		var shop_screen := UIManager.open(UIManager.SHOP, true)
		shop_screen.call("configure_shop", shop_type)


## Override this for an interaction with a different durable effect while
## retaining this class's range, input, lock, prompt, and autosave behavior.
func _apply_interaction() -> void:
	if not interaction_flag.is_empty():
		GameState.set_flag(interaction_flag, true)


func _on_flag_changed(flag: String, _value: Variant) -> void:
	if flag == required_flag:
		_refresh_prompt()


func _refresh_prompt() -> void:
	if _prompt == null:
		return
	if _skill_lock_is_live():
		var message := (
			lock_failed_message
			if GameState.flag_is_true(lock_failed_flag())
			else "%s — %s" % [DramgidSchema.skill_label(lock_skill).to_upper(), locked_message]
		)
		_prompt.text = "LOCKED — " + message
		return
	_prompt.text = "E — " + prompt_text if _is_unlocked() else "LOCKED — " + locked_message


func _is_unlocked() -> bool:
	if not required_flag.is_empty() and not GameState.flag_is_true(required_flag):
		return false
	return not _skill_lock_is_live()


## True while a skill lock stands between the player and this interactable.
func _skill_lock_is_live() -> bool:
	return has_skill_lock() and not GameState.flag_is_true(lock_picked_flag())


func has_skill_lock() -> bool:
	return not lock_skill.is_empty() and not lock_id.is_empty()


func lock_picked_flag() -> String:
	return "lock_picked_%s" % lock_id


func lock_failed_flag() -> String:
	return "lock_failed_%s" % lock_id


## One committed attempt, recorded durably.
##
## The alternative — letting the player press E until the dice cooperate — makes
## the skill irrelevant, because an unlimited retry converts any non-zero chance
## into a certainty. Every other check in this game commits (see
## `SkillCheck._expert_rerolls_used`, capped per scene), so this does too: the
## outcome is written to a flag before anything else, and a failed lock stays
## failed across save/load. What is behind a lock is loot, never progression, so
## a bad roll costs a reward rather than blocking the chapter.
##
## PROVISIONAL: whether a lock should later become re-attemptable — on a skill
## increase, say — is an owner call (#284).
func attempt_skill_lock() -> Dictionary:
	if not has_skill_lock():
		return {"attempted": false, "success": false}
	if GameState.flag_is_true(lock_picked_flag()):
		return {"attempted": false, "success": true}
	if GameState.flag_is_true(lock_failed_flag()):
		return {"attempted": false, "success": false}
	if not DramgidSchema.is_skill(lock_skill):
		push_warning(
			"'%s' authors unknown lock skill '%s'; the lock opens." % [name, lock_skill]
		)
		GameState.set_flag(lock_picked_flag(), true)
		return {"attempted": false, "success": true}
	var check: Dictionary = SkillCheck.resolve(
		lock_skill, null, lock_modifier, "lock-%s" % lock_id
	)
	var succeeded := bool(check.get("success", false))
	GameState.set_flag(lock_picked_flag() if succeeded else lock_failed_flag(), true)
	return {"attempted": true, "success": succeeded, "check": check}
