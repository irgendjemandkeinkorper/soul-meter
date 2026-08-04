class_name CombatStyleTracker
extends Node
## FR-110 event-stream scorer. Per-battle observations are transient; only the
## awarded total is committed into SaveGame's existing ng_plus block.

signal points_awarded(points: int, breakdown: Dictionary)

const VERB_VARIETY := &"verb_variety"
const BALANCE_MANAGEMENT := &"balance_management"
const NO_DAMAGE_TURNS := &"no_damage_turns"
const SPEECH_RESOLUTIONS := &"speech_resolutions"

var last_breakdown: Dictionary = _empty_breakdown()

var _active := false
var _ally_ids: Dictionary = {}
var _verbs: Dictionary = {}
var _speech_keys: Dictionary = {}
var _balance_management := 0
var _no_damage_turns := 0
var _speech_resolutions := 0
var _round_start_hp := -1


func _ready() -> void:
	if not Battle.combat_event.is_connected(consume_event):
		Battle.combat_event.connect(consume_event)


func consume_event(event: CombatEvent) -> void:
	if event == null:
		return
	var snapshot := _snapshot(event)
	match event.type:
		&"battle_started":
			_reset_battle(snapshot)
		&"action_resolved":
			_record_action(event)
		&"balance_changed":
			_record_balance(event)
		&"round_started":
			_round_start_hp = _allied_hp(snapshot)
		&"round_ended":
			_record_round_end(snapshot)
		&"speech_resolved":
			_record_explicit_speech(event)
		&"battle_finished":
			_finish_battle()


func score_breakdown() -> Dictionary:
	var result := {
		VERB_VARIETY: maxi(0, _verbs.size() - 1),
		BALANCE_MANAGEMENT: _balance_management,
		NO_DAMAGE_TURNS: _no_damage_turns,
		SPEECH_RESOLUTIONS: _speech_resolutions,
	}
	result[&"total"] = (
		int(result[VERB_VARIETY])
		+ int(result[BALANCE_MANAGEMENT])
		+ int(result[NO_DAMAGE_TURNS])
		+ int(result[SPEECH_RESOLUTIONS])
	)
	return result


func accrue_into(ng_plus_block: Dictionary) -> Dictionary:
	var result := NGPlus.normalize(ng_plus_block)
	result["style_points"] = int(result.get("style_points", 0)) + int(score_breakdown()[&"total"])
	return result


func _reset_battle(snapshot: Dictionary) -> void:
	_active = true
	_ally_ids.clear()
	_verbs.clear()
	_speech_keys.clear()
	_balance_management = 0
	_no_damage_turns = 0
	_speech_resolutions = 0
	_round_start_hp = -1
	for row: Variant in snapshot.get("allies", []):
		if row is Dictionary:
			var actor_id := StringName(row.get("id", ""))
			if not actor_id.is_empty():
				_ally_ids[actor_id] = true


func _record_action(event: CombatEvent) -> void:
	if not _active or not _is_ally(event.actor_id):
		return
	var verb := int(event.data.get("verb", -1))
	if verb >= CombatAction.Verb.MOVE and verb <= CombatAction.Verb.DEFEND:
		_verbs[verb] = true
	if verb == CombatAction.Verb.SPEECH and not StringName(event.data.get("outcome_id", "")).is_empty():
		_record_speech(event)


func _record_balance(event: CombatEvent) -> void:
	if not _active or not _is_ally(event.actor_id):
		return
	var after := int(event.data.get("balance", 0))
	var before := after - int(event.data.get("delta", 0))
	if absi(after) < absi(before):
		_balance_management += 1


func _record_round_end(snapshot: Dictionary) -> void:
	if not _active or _round_start_hp < 0:
		return
	var ending_hp := _allied_hp(snapshot)
	if ending_hp >= 0 and ending_hp == _round_start_hp:
		_no_damage_turns += 1
	_round_start_hp = -1


func _record_explicit_speech(event: CombatEvent) -> void:
	if _active and (_is_ally(event.actor_id) or event.actor_id.is_empty()):
		_record_speech(event)


func _record_speech(event: CombatEvent) -> void:
	var key := str(event.data.get("outcome_id", event.data.get("action_id", event.sequence)))
	if _speech_keys.has(key):
		return
	_speech_keys[key] = true
	_speech_resolutions += 1


func _finish_battle() -> void:
	if not _active:
		return
	last_breakdown = score_breakdown()
	SaveGame.ng_plus = accrue_into(SaveGame.ng_plus)
	_active = false
	points_awarded.emit(int(last_breakdown[&"total"]), last_breakdown.duplicate(true))


func _is_ally(actor_id: StringName) -> bool:
	return not actor_id.is_empty() and _ally_ids.has(actor_id)


func _allied_hp(snapshot: Dictionary) -> int:
	var rows: Variant = snapshot.get("allies", [])
	if not rows is Array:
		return -1
	var total := 0
	for row: Variant in rows:
		if row is Dictionary:
			total += int(row.get("hp", 0))
	return total


func _snapshot(event: CombatEvent) -> Dictionary:
	var value: Variant = event.data.get("snapshot", {})
	return value if value is Dictionary else {}


static func _empty_breakdown() -> Dictionary:
	return {
		VERB_VARIETY: 0,
		BALANCE_MANAGEMENT: 0,
		NO_DAMAGE_TURNS: 0,
		SPEECH_RESOLUTIONS: 0,
		&"total": 0,
	}
