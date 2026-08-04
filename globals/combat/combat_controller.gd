class_name CombatController
extends RefCounted
## Command/event-driven combat session coordinator. It owns runtime turn state,
## AP, fixed effect pipelines, and positioning queries; presentation consumes
## CombatEvent snapshots and never needs to know which battlefield backs them.

signal event_emitted(event: CombatEvent)
signal battle_finished(state: ResultState, outcome_id: StringName)

enum State { IDLE, ROUND_START, ALLY_TURN, ENEMY_TURN, FINISHED }
enum ResultState { VICTORY, DEFEAT, FLED }

const BALANCE_MIN := -100
const BALANCE_MAX := 100
const EXTREME_THRESHOLD := 60
const EXTREME_POWER_BONUS := 2

var state: State = State.IDLE
var allies: Array[BattleActor] = []
var enemies: Array[BattleActor] = []
var active_ally_index := -1
var round_number := 0
var balance := 0
var last_refusal: Dictionary = {}
var battlefield: BattlefieldModel
var rules: CombatRules

var _actions: Dictionary = {}
var _sequence := 0


func configure(
	actions: Array[CombatAction], positioning: BattlefieldModel, combat_rules: CombatRules
) -> void:
	_actions.clear()
	for action in actions:
		_actions[action.id] = action
	battlefield = positioning
	rules = combat_rules


func start(ally_group: Array[BattleActor], enemy_group: Array[BattleActor]) -> void:
	allies = ally_group
	enemies = enemy_group
	_sequence = 0
	round_number = 0
	balance = 0
	last_refusal.clear()
	_assign_combat_ids(allies, &"ally")
	_assign_combat_ids(enemies, &"enemy")
	battlefield.setup(allies, enemies)
	state = State.ROUND_START
	_emit_event(&"battle_started", null, null, {})
	if not _has_living(enemies):
		_finish(ResultState.VICTORY, &"slain")
		return
	_begin_round()


func active_actor() -> BattleActor:
	if active_ally_index < 0 or active_ally_index >= allies.size():
		return null
	return allies[active_ally_index]


func action_by_id(action_id: StringName) -> CombatAction:
	return _actions.get(action_id) as CombatAction


func query_action(action: CombatAction, target: BattleActor = null) -> Dictionary:
	var actor := active_actor()
	if state != State.ALLY_TURN or actor == null or not actor.is_alive():
		return _blocked(&"turn_state", "No party combatant can act right now.", {})
	if action == null:
		return _blocked(&"action", "Unknown combat action.", {"type": &"known_action"})
	if actor.action_points < action.ap_cost:
		return {
			"allowed": false,
			"blocked_by": &"action_points",
			"nearest_unblock": {
				"type": &"action_points",
				"minimum": action.ap_cost,
				"delta": action.ap_cost - actor.action_points,
			},
			"current_ap": actor.action_points,
			"required_ap": action.ap_cost,
			"message": "Requires %d AP; %d AP remains." % [action.ap_cost, actor.action_points],
		}
	if action.kind == CombatAction.Kind.MOVE:
		return battlefield.move_query(actor, action.destination)
	if action.kind == CombatAction.Kind.ATTACK:
		return battlefield.target_query(actor, target, action.target_profile)
	return _allowed()


func submit_action(action_id: StringName, target: BattleActor = null) -> Dictionary:
	var action := action_by_id(action_id)
	if action != null and action.kind == CombatAction.Kind.ATTACK and target == null:
		target = _first_living(enemies)
	var query := query_action(action, target)
	if not bool(query.get("allowed", false)):
		last_refusal = query.duplicate(true)
		_emit_event(&"action_refused", active_actor(), target, {"action_id": action_id, "reason": query})
		return query

	var actor := active_actor()
	actor.action_points -= action.ap_cost
	var outcome := _apply_action(actor, target, action)
	outcome["action_id"] = action.id
	outcome["verb"] = action.verb
	outcome["ap_cost"] = action.ap_cost
	outcome["ap_remaining"] = actor.action_points
	_emit_event(&"action_resolved", actor, target, outcome)
	last_refusal.clear()
	if action.kind == CombatAction.Kind.RESOLUTION:
		_finish(ResultState.VICTORY, action.outcome_id)
	elif not _has_living(enemies):
		_finish(ResultState.VICTORY, &"slain")
	elif actor.action_points == 0:
		end_turn()
	return _allowed(outcome)


func submit_speech(
	action_id: StringName, check_result: Dictionary, option: CombatSpeechOption
) -> Dictionary:
	var action := action_by_id(action_id)
	var query := query_action(action)
	if not bool(query.get("allowed", false)):
		last_refusal = query.duplicate(true)
		_emit_event(&"action_refused", active_actor(), null, {"action_id": action_id, "reason": query})
		return query
	if action.verb != CombatAction.Verb.SPEECH:
		var wrong_verb := _blocked(
			&"action_verb",
			"Only a declared speech verb can resolve a combat speech check.",
			{"type": &"verb", "required": CombatAction.Verb.SPEECH},
		)
		last_refusal = wrong_verb.duplicate(true)
		_emit_event(
			&"action_refused", active_actor(), null, {"action_id": action_id, "reason": wrong_verb}
		)
		return wrong_verb
	var option_refusal := option.validation_refusal() if option != null else _blocked(
		&"speech_option", "Unknown combat speech option.", {"type": &"known_speech_option"}
	)
	if not bool(option_refusal.get("allowed", false)):
		last_refusal = option_refusal.duplicate(true)
		_emit_event(
			&"action_refused",
			active_actor(),
			null,
			{"action_id": action_id, "reason": option_refusal},
		)
		return option_refusal

	var actor := active_actor()
	actor.action_points -= action.ap_cost
	var succeeded := bool(check_result.get("success", false))
	var outcome: Dictionary = {
		"action_id": action.id,
		"verb": action.verb,
		"ap_cost": action.ap_cost,
		"ap_remaining": actor.action_points,
		"speech_option_id": option.id,
		"speech_outcome": option.outcome_name(),
		"outcome_id": option.outcome_id,
		"check": check_result.duplicate(true),
		"success": succeeded,
		"damage": 0,
		"message": option.success_message if succeeded else option.failure_message,
	}
	if succeeded:
		outcome.merge(_apply_speech_composition(actor, option), true)
	_emit_event(&"action_resolved", actor, null, outcome)
	last_refusal.clear()

	if succeeded and (
		option.outcome == CombatSpeechOption.Outcome.END or not _has_living(enemies)
	):
		_finish(ResultState.VICTORY, option.outcome_id)
	elif actor.action_points == 0:
		end_turn()
	return _allowed(outcome)


func end_turn() -> bool:
	if state != State.ALLY_TURN or active_actor() == null:
		return false
	var actor := active_actor()
	_emit_event(&"turn_ended", actor, null, {"ap_remaining": actor.action_points})
	var next := _next_living_index(allies, active_ally_index)
	if next >= 0:
		active_ally_index = next
		_emit_event(&"turn_started", active_actor(), null, {})
		return true
	_resolve_enemy_turn()
	return true


func force_finish(result_state: ResultState, outcome_id: StringName) -> void:
	_finish(result_state, outcome_id)


func shift_balance(amount: int) -> void:
	_change_balance(amount)


func snapshot() -> Dictionary:
	return {
		"state": state,
		"round": round_number,
		"balance": balance,
		"active_actor_id": active_actor().combat_id if active_actor() else &"",
		"allies": _actor_snapshots(allies),
		"enemies": _actor_snapshots(enemies),
	}


static func calculate_damage(
	attacker: BattleActor,
	target: BattleActor,
	power_bonus: int,
	alignment_shift: int,
	current_balance: int,
	flank_bonus: int = 0,
	cover_bonus: int = 0
) -> int:
	var damage := maxi(1, attacker.attack + power_bonus + flank_bonus - target.defense - cover_bonus)
	if alignment_shift > 0 and current_balance >= EXTREME_THRESHOLD:
		damage += EXTREME_POWER_BONUS
	elif alignment_shift < 0 and current_balance <= -EXTREME_THRESHOLD:
		damage += EXTREME_POWER_BONUS
	return damage


func _begin_round() -> void:
	round_number += 1
	state = State.ROUND_START
	_emit_event(&"round_started", null, null, {"round": round_number})
	for actor in allies + enemies:
		if not actor.is_alive():
			continue
		actor.max_action_points = rules.action_points_for(actor)
		actor.action_points = actor.max_action_points
		_emit_event(
			&"ap_refreshed",
			actor,
			null,
			{"current_ap": actor.action_points, "maximum_ap": actor.max_action_points},
		)
	active_ally_index = _next_living_index(allies, -1)
	if active_ally_index < 0:
		_finish(ResultState.DEFEAT, &"defeat")
		return
	state = State.ALLY_TURN
	_emit_event(&"turn_started", active_actor(), null, {})


func _resolve_enemy_turn() -> void:
	state = State.ENEMY_TURN
	_emit_event(&"enemy_turn_started", null, null, {})
	var enemy_action := action_by_id(&"enemy-strike")
	for foe in enemies:
		if not foe.is_alive():
			continue
		var target := _first_living(allies)
		if target == null:
			break
		var query := battlefield.target_query(foe, target, enemy_action.target_profile)
		if not bool(query.get("allowed", false)):
			continue
		foe.action_points = maxi(0, foe.action_points - enemy_action.ap_cost)
		var outcome := _apply_action(foe, target, enemy_action)
		outcome["action_id"] = enemy_action.id
		outcome["ap_cost"] = enemy_action.ap_cost
		outcome["ap_remaining"] = foe.action_points
		_emit_event(&"action_resolved", foe, target, outcome)
		_change_balance(foe.balance_affinity * foe.balance_pressure, foe)
		if not _has_living(allies):
			_finish(ResultState.DEFEAT, &"defeat")
			return
	_emit_event(&"round_ended", null, null, {"round": round_number})
	_begin_round()


func _apply_action(
	actor: BattleActor, target: BattleActor, action: CombatAction
) -> Dictionary:
	var result: Dictionary = {"message": "%s uses %s." % [actor.display_name, action.display_name]}
	match action.kind:
		CombatAction.Kind.ATTACK:
			var total_damage := 0
			var hit_targets := battlefield.targets_for(actor, target, action.aoe_shape)
			for hit_target in hit_targets:
				var damage := calculate_damage(
					actor,
					hit_target,
					action.power_bonus,
					action.balance_shift,
					balance,
					battlefield.flank_bonus(actor, hit_target),
					battlefield.cover_bonus(actor, hit_target),
				)
				hit_target.hp = maxi(0, hit_target.hp - damage)
				total_damage += damage
			result["damage"] = total_damage
			result["message"] = "%s uses %s for %d damage." % [
				actor.display_name, action.display_name, total_damage
			]
		CombatAction.Kind.GUARD:
			actor.guarding = true
			result["message"] = "%s guards; incoming damage is reduced." % actor.display_name
		CombatAction.Kind.STABILIZE:
			actor.guarding = true
			_shift_toward_center(action.center_pull, actor)
			result["message"] = "%s steadies the field toward equilibrium." % actor.display_name
		CombatAction.Kind.MOVE:
			var movement := battlefield.move(actor, action.destination)
			result.merge(movement, true)
			result["message"] = "%s moves to %s." % [actor.display_name, action.destination]
		CombatAction.Kind.RESOLUTION:
			result["outcome_id"] = action.outcome_id
			result["message"] = "%s chooses %s." % [actor.display_name, action.display_name]
		CombatAction.Kind.PASS:
			pass
	if action.kind != CombatAction.Kind.RESOLUTION:
		if action.balance_shift != 0:
			_change_balance(action.balance_shift, actor)
		elif action.kind != CombatAction.Kind.STABILIZE and action.center_pull > 0:
			_shift_toward_center(action.center_pull, actor)
	return result


func _apply_speech_composition(
	actor: BattleActor, option: CombatSpeechOption
) -> Dictionary:
	var candidates: Array[BattleActor] = []
	for foe in enemies:
		if foe.is_alive() and battlefield.has_combatant(foe):
			candidates.append(foe)
	var count := candidates.size()
	if option.outcome != CombatSpeechOption.Outcome.END:
		count = mini(option.target_count, candidates.size())
	var removed_ids: Array[StringName] = []
	var turned_ids: Array[StringName] = []
	var ally_side := battlefield.side_of(actor)
	for i in count:
		var target := candidates[i]
		if option.outcome == CombatSpeechOption.Outcome.TURN:
			var transfer := battlefield.transfer_combatant(target, ally_side)
			if not bool(transfer.get("allowed", false)):
				continue
			enemies.erase(target)
			allies.append(target)
			turned_ids.append(target.combat_id)
		else:
			var removal := battlefield.remove_combatant(target)
			if not bool(removal.get("allowed", false)):
				continue
			enemies.erase(target)
			removed_ids.append(target.combat_id)
	var result := {
		"removed_ids": removed_ids,
		"turned_ids": turned_ids,
		"remaining_enemies": _living_count(enemies),
	}
	_emit_event(&"battlefield_changed", actor, null, result)
	return result


func _change_balance(amount: int, actor: BattleActor = null) -> void:
	if amount == 0:
		return
	balance = clampi(balance + amount, BALANCE_MIN, BALANCE_MAX)
	_emit_event(&"balance_changed", actor, null, {"balance": balance, "delta": amount})


func _shift_toward_center(amount: int, actor: BattleActor) -> void:
	if balance > 0:
		_change_balance(-mini(balance, amount), actor)
	elif balance < 0:
		_change_balance(mini(-balance, amount), actor)


func _finish(result_state: ResultState, outcome_id: StringName) -> void:
	if state == State.FINISHED:
		return
	state = State.FINISHED
	_emit_event(&"battle_finished", null, null, {"result": result_state, "outcome_id": outcome_id})
	battle_finished.emit(result_state, outcome_id)


func _emit_event(
	type: StringName, actor: BattleActor, target: BattleActor, payload: Dictionary
) -> void:
	_sequence += 1
	var event := CombatEvent.new()
	event.sequence = _sequence
	event.type = type
	event.actor_id = actor.combat_id if actor else &""
	event.target_id = target.combat_id if target else &""
	event.data = payload.duplicate(true)
	event.data["snapshot"] = snapshot()
	event_emitted.emit(event)


func _actor_snapshots(group: Array[BattleActor]) -> Array[Dictionary]:
	var result: Array[Dictionary] = []
	for actor in group:
		result.append({
			"id": actor.combat_id,
			"display_name": actor.display_name,
			"hp": actor.hp,
			"max_hp": actor.max_hp,
			"ap": actor.action_points,
			"max_ap": actor.max_action_points,
			"position": battlefield.position_of(actor),
			"side": battlefield.side_of(actor),
			"guarding": actor.guarding,
		})
	return result


func _assign_combat_ids(group: Array[BattleActor], prefix: StringName) -> void:
	for i in group.size():
		if group[i].combat_id.is_empty():
			group[i].combat_id = StringName("%s-%d" % [prefix, i])


func _has_living(group: Array[BattleActor]) -> bool:
	return _first_living(group) != null


func _living_count(group: Array[BattleActor]) -> int:
	var count := 0
	for actor in group:
		if actor.is_alive():
			count += 1
	return count


func _first_living(group: Array[BattleActor]) -> BattleActor:
	for actor in group:
		if actor.is_alive():
			return actor
	return null


func _next_living_index(group: Array[BattleActor], after: int) -> int:
	for i in range(after + 1, group.size()):
		if group[i].is_alive():
			return i
	return -1


static func _allowed(extra: Dictionary = {}) -> Dictionary:
	var result := {
		"allowed": true,
		"blocked_by": &"",
		"nearest_unblock": {},
		"message": "",
	}
	result.merge(extra, true)
	return result


static func _blocked(
	blocked_by: StringName, message: String, nearest_unblock: Dictionary
) -> Dictionary:
	return {
		"allowed": false,
		"blocked_by": blocked_by,
		"nearest_unblock": nearest_unblock.duplicate(true),
		"message": message,
	}
