class_name CombatSpeechOption
extends Resource
## One authored choice inside a combat speech hook. Encounter data chooses the
## skill and composition effect; CombatController owns the fixed effect pipeline.

enum Outcome { END, SPLIT, TURN }

const ALLOWED_SKILLS: Array[StringName] = [&"persuasion", &"insight"]

@export var id: StringName = &""
@export var skill: StringName = &"persuasion"
@export var situational_modifier: float = 0.0
@export var outcome: Outcome = Outcome.END
@export_range(0, 20) var target_count: int = 1
@export var outcome_id: StringName = &"spared"
@export var success_message: String = "The appeal changes the field."
@export var failure_message: String = "The appeal fails, but the fight continues."


static func from_dict(row: Dictionary) -> CombatSpeechOption:
	var option := CombatSpeechOption.new()
	option.id = StringName(row.get("id", ""))
	option.skill = StringName(str(row.get("skill", "persuasion")).to_snake_case())
	option.situational_modifier = float(row.get("situational_modifier", 0.0))
	option.outcome = _outcome_from_name(StringName(row.get("outcome", "end")))
	option.target_count = int(row.get("target_count", 1))
	option.outcome_id = StringName(row.get("outcome_id", "spared"))
	option.success_message = str(row.get("success_message", option.success_message))
	option.failure_message = str(row.get("failure_message", option.failure_message))
	return option


func validation_refusal() -> Dictionary:
	if id.is_empty():
		return _blocked(&"speech_option", "Speech option has no stable ID.", {"type": &"stable_id"})
	if not ALLOWED_SKILLS.has(skill):
		return _blocked(
			&"speech_skill",
			"Combat speech must use Persuasion or Insight.",
			{"type": &"skill", "one_of": ALLOWED_SKILLS.duplicate()},
		)
	if outcome_id.is_empty():
		return _blocked(
			&"speech_outcome", "Speech option has no outcome ID.", {"type": &"outcome_id"}
		)
	if outcome != Outcome.END and target_count <= 0:
		return _blocked(
			&"speech_targets",
			"Split and turn outcomes require at least one target.",
			{"type": &"target_count", "minimum": 1},
		)
	return _allowed()


func outcome_name() -> StringName:
	match outcome:
		Outcome.SPLIT:
			return &"split"
		Outcome.TURN:
			return &"turn"
		_:
			return &"end"


static func _outcome_from_name(value: StringName) -> Outcome:
	match value:
		&"split":
			return Outcome.SPLIT
		&"turn":
			return Outcome.TURN
		_:
			return Outcome.END


static func _allowed() -> Dictionary:
	return {"allowed": true, "blocked_by": &"", "nearest_unblock": {}, "message": ""}


static func _blocked(
	blocked_by: StringName, message: String, nearest_unblock: Dictionary
) -> Dictionary:
	return {
		"allowed": false,
		"blocked_by": blocked_by,
		"nearest_unblock": nearest_unblock.duplicate(true),
		"message": message,
	}
