class_name CombatController
extends RefCounted
## Command/event-driven combat session coordinator. It owns runtime turn state,
## AP, fixed effect pipelines, and positioning queries; presentation consumes
## CombatEvent snapshots and never needs to know which battlefield backs them.

signal event_emitted(event: CombatEvent)
signal battle_finished(state: ResultState, outcome_id: StringName)

enum State { IDLE, ROUND_START, ALLY_TURN, ENEMY_TURN, FINISHED }
enum ResultState { VICTORY, DEFEAT, FLED }

var state: State = State.IDLE
var allies: Array[BattleActor] = []
var enemies: Array[BattleActor] = []
var active_ally_index := -1
var round_number := 0
var balance := 0
var balance_band_id: StringName = &""
var balance_lock_until_round := 0
var threshold_effects_suppressed := false
var last_refusal: Dictionary = {}
var battlefield: BattlefieldModel
var rules: CombatRules
var skill_check_service: SkillCheckService

var _actions: Dictionary = {}
var _sequence := 0


func configure(
	actions: Array[CombatAction],
	positioning: BattlefieldModel,
	combat_rules: CombatRules,
	check_service: SkillCheckService = null
) -> void:
	_actions.clear()
	for action in actions:
		_actions[action.id] = action
	battlefield = positioning
	rules = combat_rules
	skill_check_service = check_service
	if skill_check_service == null:
		var main_loop := Engine.get_main_loop()
		if main_loop is SceneTree:
			skill_check_service = (
				(main_loop as SceneTree).root.get_node_or_null("SkillCheck") as SkillCheckService
			)
	if skill_check_service == null:
		skill_check_service = SkillCheckService.new()


func start(
	ally_group: Array[BattleActor],
	enemy_group: Array[BattleActor],
	encounter_id: StringName = &""
) -> void:
	allies = ally_group
	enemies = enemy_group
	_sequence = 0
	round_number = 0
	balance = 0
	balance_band_id = &""
	balance_lock_until_round = 0
	threshold_effects_suppressed = false
	last_refusal.clear()
	_assign_combat_ids(allies, &"ally", encounter_id)
	_assign_combat_ids(enemies, &"enemy", encounter_id)
	battlefield.setup(allies, enemies)
	_apply_balance_band(false)
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


func query_action(
	action: CombatAction, target: BattleActor = null, options: Dictionary = {}
) -> Dictionary:
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
	if action.requires_enemy_target():
		var targeting := battlefield.target_query(actor, target, action.target_profile)
		if not bool(targeting.get("allowed", false)):
			return targeting
	if action.kind == CombatAction.Kind.DEFINING_STRIKE:
		return _query_defining_strike(target, StringName(options.get("weakness_id", "")))
	return _allowed()


func submit_action(
	action_id: StringName, target: BattleActor = null, options: Dictionary = {}
) -> Dictionary:
	var action := action_by_id(action_id)
	if action != null and action.requires_enemy_target() and target == null:
		target = _first_living(enemies)
	var query := query_action(action, target, options)
	if not bool(query.get("allowed", false)):
		last_refusal = query.duplicate(true)
		_emit_event(&"action_refused", active_actor(), target, {"action_id": action_id, "reason": query})
		return query

	var actor := active_actor()
	actor.action_points -= action.ap_cost
	var outcome := _apply_action(actor, target, action, options)
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


func apply_balance_effect(parameters: Dictionary, actor: BattleActor = null) -> Dictionary:
	if (
		str(parameters.get("balance_gauge", "")) != "exact_center"
		or str(parameters.get("lock_until", "")) != "end_of_next_round"
	):
		return _blocked(&"balance_effect", "Unsupported Balance Gauge effect.", {})
	var previous := balance
	balance = 0
	threshold_effects_suppressed = bool(parameters.get("suppress_threshold_effects", false))
	balance_lock_until_round = round_number + 1
	_apply_balance_band()
	if previous != balance:
		_emit_event(
			&"balance_changed",
			actor,
			null,
			{"balance": balance, "delta": balance - previous, "band_id": balance_band_id},
		)
	_emit_event(
		&"balance_locked",
		actor,
		null,
		{
			"balance": balance,
			"until_round": balance_lock_until_round,
			"threshold_effects_suppressed": threshold_effects_suppressed,
		},
	)
	return _allowed({"balance": balance, "until_round": balance_lock_until_round})


func snapshot() -> Dictionary:
	return {
		"state": state,
		"round": round_number,
		"balance": balance,
		"balance_band_id": balance_band_id,
		"balance_lock_until_round": balance_lock_until_round,
		"threshold_effects_suppressed": threshold_effects_suppressed,
		"active_actor_id": active_actor().combat_id if active_actor() else &"",
		"allies": _actor_snapshots(allies),
		"enemies": _actor_snapshots(enemies),
	}


static func calculate_damage(
	attacker: BattleActor,
	target: BattleActor,
	power_bonus: int,
	_alignment_shift: int,
	_current_balance: int,
	flank_bonus: int = 0,
	cover_bonus: int = 0
) -> int:
	return maxi(
		1,
		attacker.effective_attack()
		+ power_bonus
		+ flank_bonus
		+ int(attacker.balance_effects.get("damage_bonus", 0))
		- target.effective_defense()
		- int(target.balance_effects.get("defense_bonus", 0))
		- cover_bonus,
	)


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
		if foe.action_points < enemy_action.ap_cost:
			var reason := _blocked(
				&"action_points",
				"%s cannot afford %s." % [foe.display_name, enemy_action.display_name],
				{
					"type": &"action_points",
					"minimum": enemy_action.ap_cost,
					"delta": enemy_action.ap_cost - foe.action_points,
				},
			)
			_emit_event(
				&"action_refused",
				foe,
				target,
				{"action_id": enemy_action.id, "reason": reason},
			)
			continue
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
	_release_balance_lock_if_due()
	_begin_round()


func _apply_action(
	actor: BattleActor, target: BattleActor, action: CombatAction, options: Dictionary = {}
) -> Dictionary:
	var result: Dictionary = {"message": "%s uses %s." % [actor.display_name, action.display_name]}
	match action.kind:
		CombatAction.Kind.ATTACK:
			result.merge(_resolve_attack(actor, target, action), true)
		CombatAction.Kind.DEFINING_STRIKE:
			result.merge(_resolve_defining_strike(actor, target, action, options), true)
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


func _query_defining_strike(target: BattleActor, weakness_id: StringName) -> Dictionary:
	if target == null or target.archetype_id.is_empty():
		return _blocked(
			&"archetype", "This enemy has no authored Defining Strike table.", {"type": &"archetype"}
		)
	if weakness_id.is_empty():
		return _blocked(
			&"weakness",
			"Choose a discovered weakness to name.",
			{"type": &"discovered_weakness", "available": target.discovered_weakness_ids.size()},
		)
	var weakness := CombatIdentityCatalog.weakness(target.archetype_id, weakness_id)
	if weakness.is_empty():
		return _blocked(
			&"weakness", "Unknown weakness for this archetype.", {"type": &"authored_weakness"}
		)
	if weakness_id not in target.discovered_weakness_ids:
		return _blocked(
			&"weakness",
			"That weakness has not been discovered.",
			{"type": &"discovered_weakness", "weakness_id": weakness_id},
		)
	return _allowed({"weakness": weakness})


func _resolve_attack(
	actor: BattleActor, target: BattleActor, action: CombatAction
) -> Dictionary:
	var total_damage := 0
	var hit_targets := battlefield.targets_for(actor, target, action.aoe_shape)
	for hit_target: BattleActor in hit_targets:
		var cover_bonus := battlefield.cover_bonus(actor, hit_target)
		if bool(hit_target.defining_effects.get("revealed", false)):
			cover_bonus = 0
		var damage := calculate_damage(
			actor,
			hit_target,
			action.power_bonus,
			action.balance_shift,
			balance,
			battlefield.flank_bonus(actor, hit_target),
			cover_bonus,
		)
		hit_target.hp = maxi(0, hit_target.hp - damage)
		total_damage += damage
	return {
		"damage": total_damage,
		"message": "%s uses %s for %d damage."
		% [actor.display_name, action.display_name, total_damage],
	}


func _resolve_defining_strike(
	actor: BattleActor, target: BattleActor, action: CombatAction, options: Dictionary
) -> Dictionary:
	var weakness_id := StringName(options.get("weakness_id", ""))
	var weakness := CombatIdentityCatalog.weakness(target.archetype_id, weakness_id)
	var forced_rolls: Array[int] = []
	var authored_rolls: Variant = options.get("forced_rolls", [])
	if authored_rolls is Array:
		for roll: Variant in authored_rolls:
			if typeof(roll) == TYPE_INT:
				forced_rolls.append(int(roll))
	var check_skill := str(weakness.get("check_skill", "lore"))
	# Was `"combat-%d" % get_instance_id()` — CombatController's own instance id is
	# process-local and allocation-order dependent (issue #186). `actor.combat_id` is the
	# FR-802 stable id assigned deterministically at encounter setup, so the same encounter
	# produces the same scene_id/reroll-dedup key on every run and across a mid-battle
	# save/load. Note: skill_check.gd's own `_reroll_key()` still folds in
	# `member.get_instance_id()` (the PartyMember, not this actor) — that is a separate,
	# out-of-scope defect in a file this issue does not own; see the report.
	var check := skill_check_service.resolve(
		check_skill,
		actor.source_member,
		float(weakness.get("check_modifier", 0.0)),
		"combat-%s" % actor.combat_id,
		forced_rolls,
	)
	var result := {
		"defining_strike": true,
		"weakness_id": weakness_id,
		"weakness_name": str(weakness.get("display_name", weakness_id)),
		"check_skill": check_skill,
		"check": check,
		"effect_id": StringName(weakness.get("effect_id", "")),
		"effect_applied": false,
		"resisted": false,
		"damage": 0,
	}
	if not bool(check.get("success", false)):
		result["message"] = (
			"%s names %s, but the strike misses."
			% [actor.display_name, result["weakness_name"]]
		)
		return result

	result.merge(_resolve_attack(actor, target, action), true)
	var resistance: Variant = weakness.get("resistance", {})
	var resisted := false
	if resistance is Dictionary:
		var threshold := int(resistance.get("threshold", 0))
		var stat_id := StringName(resistance.get("stat", ""))
		resisted = threshold > 0 and target.combat_stat(stat_id) >= threshold
	result["resisted"] = resisted
	if resisted:
		result["message"] = (
			"%s names %s, but %s resists the targeted effect."
			% [actor.display_name, result["weakness_name"], target.display_name]
		)
		return result

	var effect_parameters: Variant = weakness.get("effect_parameters", {})
	if effect_parameters is Dictionary:
		target.apply_defining_effect(effect_parameters)
		var updated_max_ap := rules.action_points_for(target)
		if target.max_action_points > 0:
			target.max_action_points = mini(target.max_action_points, updated_max_ap)
			target.action_points = mini(target.action_points, target.max_action_points)
		result["effect_applied"] = true
	result["message"] = (
		"%s names %s; %s is %s."
		% [
			actor.display_name,
			result["weakness_name"],
			target.display_name,
			str(result["effect_id"]).replace("_", " "),
		]
	)
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
	if balance_lock_until_round > 0:
		_emit_event(
			&"balance_shift_suppressed",
			actor,
			null,
			{"attempted_delta": amount, "until_round": balance_lock_until_round},
		)
		return
	var previous := balance
	balance = clampi(
		balance + amount,
		CombatIdentityCatalog.balance_minimum(),
		CombatIdentityCatalog.balance_maximum(),
	)
	if balance == previous:
		return
	_apply_balance_band()
	_emit_event(
		&"balance_changed",
		actor,
		null,
		{"balance": balance, "delta": balance - previous, "band_id": balance_band_id},
	)


func _shift_toward_center(amount: int, actor: BattleActor) -> void:
	if balance > 0:
		_change_balance(-mini(balance, amount), actor)
	elif balance < 0:
		_change_balance(mini(-balance, amount), actor)


func _apply_balance_band(emit_change: bool = true) -> void:
	var band := CombatIdentityCatalog.balance_band(balance)
	var next_band_id := StringName(band.get("id", ""))
	var previous_band_id := balance_band_id
	balance_band_id = next_band_id
	var effects := CombatIdentityCatalog.balance_effects(balance, threshold_effects_suppressed)
	var affected_ids: Array[StringName] = []
	for actor: BattleActor in allies + enemies:
		var actor_effects := effects
		if not bool(band.get("global", false)) and actor not in allies:
			actor_effects = {}
		actor.apply_balance_band(balance_band_id, actor_effects)
		affected_ids.append(actor.combat_id)
	if emit_change and next_band_id != previous_band_id:
		_emit_event(
			&"balance_band_changed",
			null,
			null,
			{
				"band_id": balance_band_id,
				"effects": effects.duplicate(true),
				"affected_actor_ids": affected_ids,
			},
		)


func _release_balance_lock_if_due() -> void:
	if balance_lock_until_round <= 0 or round_number < balance_lock_until_round:
		return
	balance_lock_until_round = 0
	threshold_effects_suppressed = false
	_apply_balance_band()
	_emit_event(&"balance_unlocked", null, null, {"balance": balance})


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
			"archetype_id": actor.archetype_id,
			"balance_band_id": actor.balance_band_id,
			"balance_effects": actor.balance_effects.duplicate(true),
			"defining_effects": actor.defining_effects.duplicate(true),
			"discovered_weakness_ids": actor.discovered_weakness_ids.duplicate(),
		})
	return result


## FR-802 (globals/stable_ids.gd). Builds `BattleActor.combat_id` from stable inputs only —
## `encounter_id` (if the caller has one), `archetype_id`, and the actor's ordinal position
## within its side's array — never from `get_instance_id()` or allocation order. Two runs with
## identical `ally_group`/`enemy_group`/`encounter_id` inputs therefore produce identical ids,
## and the trailing ordinal guarantees uniqueness even when two combatants share both
## `display_name` and `archetype_id` (e.g. two Bog Wights). Must run before
## `battlefield.setup()` (see `start()`) so the battlefield never sees an unassigned id.
func _assign_combat_ids(
	group: Array[BattleActor], prefix: StringName, encounter_id: StringName = &""
) -> void:
	for i in group.size():
		var actor := group[i]
		if not actor.combat_id.is_empty():
			continue
		var parts: Array[String] = [String(prefix)]
		if not String(encounter_id).is_empty():
			parts.append(String(encounter_id))
		var archetype := String(actor.archetype_id)
		if not archetype.is_empty() and StableIds.is_valid(StableIds.ACTOR, archetype):
			parts.append(archetype)
		parts.append(str(i))
		var candidate := "-".join(parts)
		var record := StableIds.actor(candidate)
		actor.combat_id = StringName(record.get("id", candidate))


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
