class_name CombatController
extends RefCounted
## Command/event-driven combat session coordinator. It owns runtime turn state,
## AP, fixed effect pipelines, and positioning queries; presentation consumes
## CombatEvent snapshots and never needs to know which battlefield backs them.
##
## FR-102a (amendment §2.1): turn order and timing are NOT decided here. `scheduler`
## (a `TurnScheduler`, built by `TurnScheduler.create_default(rules)`) is the single
## authority for "who acts next, when, may they, and what does this cost" — this file
## never names `ApRoundScheduler` or `ChargeTimeScheduler` directly, only the interface.
## `rules.use_charge_time` (the flag `create_default()` reads) is therefore the entire
## abort path: flipping it swaps the scheduler implementation without touching a line
## here. AP compatibility is retained by construction, not by a branch in this file —
## `ApRoundScheduler` is a faithful port of the old round/phase loop expressed behind
## the same interface CT uses (amendment §8.1: AP is not removed in the change that
## makes CT authoritative).
##
## Event vocabulary is versioned per amendment §2.1's mandate ("events will change
## shape"): `round_started` / `ap_refreshed` / `round_ended` fire only when the active
## scheduler's `advance()` reports AP round bookkeeping (i.e. only under the AP
## scheduler) via `_translate_scheduler_extras()`. `measure_started` is the CT-native
## replacement beat, firing whenever `advance()` reports a crossed 16-tick measure with
## no round bookkeeping attached. `turn_started` / `turn_ended` / `enemy_turn_started`
## keep their names — they gain new meaning (charge/ticks data instead of AP-only data)
## rather than being replaced, since "whose turn is it" stays meaningful under both
## models.
##
## AP COMPATIBILITY SHIM (Gate T-10, removal ticket #176). The remaining AP-named outcome keys,
## snapshot fields, translated AP-round events, and zero-cost pass field are wire compatibility
## for the rollback scheduler and event-driven HUD. They do not decide readiness, order, or CT
## price; every such decision routes through `scheduler`. Delete these fields together with
## `ApRoundScheduler` after the Gate T rollback window.

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
var scheduler: TurnScheduler

var _actions: Dictionary = {}
var _sequence := 0
## Tracks whose turn was last announced so a continuing actor (AP: still has AP left;
## CT: overflow keeps them past READY_AT) does not get a redundant `turn_started`.
var _last_turn_actor: BattleActor = null
## Tracks which side last acted so `enemy_turn_started` announces a PHASE change (ally
## control handing to the enemy side), not every individual enemy activation — this
## keeps the event's old meaning ("the enemy phase began") intact for both schedulers,
## including CT where several enemies can act back-to-back if they are fast enough.
var _last_side: StringName = &"ally"


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
	scheduler = TurnScheduler.create_default(rules)
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
	active_ally_index = -1
	_last_turn_actor = null
	_last_side = &"ally"
	_assign_combat_ids(allies, &"ally", encounter_id)
	_assign_combat_ids(enemies, &"enemy", encounter_id)
	battlefield.setup(allies, enemies)
	scheduler.setup(allies + enemies)
	_apply_balance_band(false)
	state = State.ROUND_START
	_emit_event(&"battle_started", null, null, {})
	if not _has_living(enemies):
		_finish(ResultState.VICTORY, &"slain")
		return
	_drive_scheduler()


func active_actor() -> BattleActor:
	if scheduler == null:
		return null
	var actor := scheduler.active_actor()
	active_ally_index = allies.find(actor) if actor != null else -1
	return actor


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
	var affordability := _can_afford(actor, action)
	if not bool(affordability.get("allowed", false)):
		return affordability
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
	var commit_result := scheduler.commit(actor, action)
	if not bool(commit_result.get("allowed", false)):
		# query_action() already validated affordability via the same gate, so this is a
		# defensive re-check (e.g. a race between query and submit), not duplicated UX.
		last_refusal = commit_result.duplicate(true)
		_emit_event(&"action_refused", actor, target, {"action_id": action_id, "reason": commit_result})
		return commit_result
	var outcome := _apply_action(actor, target, action, options)
	outcome["action_id"] = action.id
	outcome["verb"] = action.verb
	outcome["ap_cost"] = action.ap_cost
	outcome["ct_spent"] = int(commit_result.get("ct_spent", 0))
	outcome["ap_remaining"] = actor.action_points
	outcome["charge_remaining"] = int(commit_result.get("charge", 0))
	_emit_event(&"action_resolved", actor, target, outcome)
	last_refusal.clear()
	scheduler.release(actor)
	if action.kind == CombatAction.Kind.RESOLUTION:
		_finish(ResultState.VICTORY, action.outcome_id)
		return _allowed(outcome)
	_drive_scheduler()
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
	var commit_result := scheduler.commit(actor, action)
	if not bool(commit_result.get("allowed", false)):
		last_refusal = commit_result.duplicate(true)
		_emit_event(&"action_refused", actor, null, {"action_id": action_id, "reason": commit_result})
		return commit_result
	var succeeded := bool(check_result.get("success", false))
	var outcome: Dictionary = {
		"action_id": action.id,
		"verb": action.verb,
		"ap_cost": action.ap_cost,
		"ct_spent": int(commit_result.get("ct_spent", 0)),
		"ap_remaining": actor.action_points,
		"charge_remaining": int(commit_result.get("charge", 0)),
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
	scheduler.release(actor)

	if succeeded and (
		option.outcome == CombatSpeechOption.Outcome.END or not _has_living(enemies)
	):
		_finish(ResultState.VICTORY, option.outcome_id)
		return _allowed(outcome)
	_drive_scheduler()
	return _allowed(outcome)


func end_turn() -> bool:
	if state != State.ALLY_TURN or active_actor() == null:
		return false
	var actor := active_actor()
	# Yield before publishing the end-of-turn transition. Charge time can refuse a third
	# consecutive wait, in which case the ready actor must remain in control and act.
	var yield_result := scheduler.yield_turn(actor)
	if not bool(yield_result.get("allowed", false)):
		last_refusal = yield_result.duplicate(true)
		_emit_event(&"action_refused", actor, null, {"action_id": &"", "reason": yield_result})
		return false
	last_refusal.clear()
	_emit_event(
		&"turn_ended",
		actor,
		null,
		{"ap_remaining": actor.action_points, "charge_remaining": scheduler.charge_of(actor)},
	)
	# Forfeits whatever resource remains — a no-op if there is nothing left to give up. This
	# is the ONLY place a turn is yielded voluntarily; a turn that already spent its action
	# via submit_action() is advanced by _drive_scheduler() below without yielding, so a
	# charge-time actor with banked overflow is not made to give it up just because it acted.
	_drive_scheduler()
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


## Placeholder Wheel element substituted when an authored `CombatAction` leaves `element_id`
## empty (issue #142 follow-up). `Resolution.resolve()` requires the ability side to name a real
## Wheel element — an empty one blocks with `&"unknown_element"` — but `BattleActor.element_id`
## (the TARGET side) is left empty by default and resolves to `ElementMatrix`'s neutral
## `IDENTITY_ROW` (×1.0) for any attack element. So which real element an unauthored ability is
## "wearing" is inert until a real per-unit attunement is authored on the target: any fixed
## choice here reproduces the same ×1.0 multiplier as before this wiring existed. This is NOT a
## balance or lore decision — it exists only so the resolver's schema-validity check has
## something to validate against.
const _UNAUTHORED_ELEMENT_ID := &"suul"


## Routes live combat damage through the pure `Resolution.resolve()` (globals/combat/resolution.gd,
## #142) instead of standalone arithmetic, while keeping the RPG stat layer (attack/defense/
## flank/cover) this file already owns. The split:
##   - Attacker-side power modifiers (base attack, authored power bonus, flank, Order/Chaos
##     damage_bonus) feed `ability.power`, so they flow through Resolution's
##     `power × attack_scale × element_matrix × facing × tile_charge` chain.
##   - Target-side mitigation (defense, defense_bonus, cover) is subtracted from Resolution's
##     result afterward, exactly as it was subtracted before this change — Resolution has no
##     defense-stat concept of its own (it is the Elements & Music resolver, not the RPG stat
##     system), so this file keeps owning that term rather than inventing one inside Resolution.
## `battle_id`/`tick`/`seed`/facing/tile-state/weather context are left at Resolution's neutral
## defaults: this battlefield model has no tile-charge or per-actor facing-multiplier system yet
## (`BattlefieldModel.flank_bonus()`/`cover_bonus()` are this file's own additive stand-ins for
## those), so passing empty dicts is honest rather than fabricating data that doesn't exist.
static func calculate_damage(
	attacker: BattleActor,
	target: BattleActor,
	power_bonus: int,
	_alignment_shift: int,
	_current_balance: int,
	flank_bonus: int = 0,
	cover_bonus: int = 0,
	ability_element_id: StringName = &"",
	ability_magnitude: StringName = &"note",
	seed: int = 0
) -> int:
	var element_id := ability_element_id
	if String(element_id).is_empty():
		element_id = _UNAUTHORED_ELEMENT_ID
	var power := (
		attacker.effective_attack()
		+ power_bonus
		+ flank_bonus
		+ int(attacker.balance_effects.get("damage_bonus", 0))
	)
	var result := Resolution.resolve_action(
		{
			"id": String(attacker.combat_id),
			"attack_scale": attacker.attack_scale,
		},
		{
			"id": "attack",
			"element_id": element_id,
			"magnitude": ability_magnitude,
			"power": power,
		},
		{
			"target": {
				"id": String(target.combat_id),
				"hp": target.hp,
				"element_id": target.element_id,
			},
		},
		seed,
	)
	var raw_damage := 0
	if bool(result.get("allowed", false)):
		raw_damage = int(result.get("damage", 0))
	else:
		# Should be unreachable: a valid Wheel `element_id` (real or the placeholder above) with
		# magnitude `&"note"` is always a legal single-element Tone, which `CastingGate` always
		# allows regardless of harmony. Surfacing this loudly rather than silently degrading to
		# the 1-damage floor below, in case that invariant is ever violated by a future caller.
		push_warning(
			"CombatController.calculate_damage: Resolution refused (%s) — %s"
			% [result.get("blocked_by", ""), result.get("message", "")]
		)
	return maxi(
		1,
		raw_damage
		- target.effective_defense()
		- int(target.balance_effects.get("defense_bonus", 0))
		- cover_bonus,
	)


## The scheduler-driven turn loop. FR-102a / amendment §2.1: this is the ONLY place
## CombatController decides whose turn it is; everything else asks `active_actor()` or
## reacts to `turn_started` / `enemy_turn_started` events. Loops (rather than recurses)
## through however many actors resolve automatically — every living enemy that becomes
## ready — until it is a living ally's turn or the battle ends, so presentation always
## gets a clean, ordered event stream with a bounded call stack.
func _drive_scheduler() -> void:
	while state != State.FINISHED:
		if not _has_living(allies):
			_finish(ResultState.DEFEAT, &"defeat")
			return
		if not _has_living(enemies):
			_finish(ResultState.VICTORY, &"slain")
			return
		state = State.ROUND_START
		var result := scheduler.advance()
		if not bool(result.get("allowed", false)):
			# The only way advance() refuses here is &"no_participants" — everyone alive was
			# already excluded above — or an internal scheduler defect. Either way the battle
			# cannot continue; side with the party rather than hang.
			_finish(ResultState.DEFEAT, &"defeat")
			return
		_translate_scheduler_extras(result)
		var actor: BattleActor = result.get("actor")
		if actor == null or not actor.is_alive():
			_finish(ResultState.DEFEAT, &"defeat")
			return

		var is_continuation := actor == _last_turn_actor and int(result.get("ticks_elapsed", 0)) == 0
		var turn_payload := {
			"charge": result.get("charge", 0),
			"ticks_elapsed": result.get("ticks_elapsed", 0),
			"measures_crossed": result.get("measures_crossed", 0),
		}

		if actor.side == &"ally":
			state = State.ALLY_TURN
			if not is_continuation:
				_emit_event(&"turn_started", actor, null, turn_payload)
			_last_turn_actor = actor
			_last_side = &"ally"
			active_ally_index = allies.find(actor)
			return

		state = State.ENEMY_TURN
		if _last_side != &"enemy":
			_emit_event(&"enemy_turn_started", actor, null, turn_payload)
		_last_turn_actor = actor
		_last_side = &"enemy"
		_resolve_enemy_actor(actor)
		# Loop continues: the next scheduler.advance() picks whoever is ready next, ally or
		# enemy, without this function recursing into itself.


## Translates the scheduler's optional round bookkeeping (`round_started` / `refreshed` /
## `round_ended`, set only by the AP scheduler) into the legacy events, and fires the CT-
## native `measure_started` beat when the scheduler crossed a measure with no round
## bookkeeping attached (i.e. the CT scheduler is live). This is the one place the two
## event vocabularies fork, and it forks on DATA the scheduler returned, never on
## `rules.use_charge_time` — CombatController does not know which scheduler is active.
func _translate_scheduler_extras(result: Dictionary) -> void:
	# A single advance() call can carry BOTH keys at once — the AP scheduler closes the old
	# round and opens the new one in one step when the last actor's turn passes. `round_ended`
	# must be emitted (and the balance lock checked against the round that JUST ended, not the
	# one about to open) first, matching the original `_resolve_enemy_turn()` order — end the
	# round, release the lock if it was due, THEN `_begin_round()` opens the next one — or the
	# lock would release one round early and presentation would see "round 2 started" before
	# "round 1 ended".
	if bool(result.get("round_ended", false)):
		var ended_round := int(result.get("ended_round", round_number))
		_emit_event(&"round_ended", null, null, {"round": ended_round})
		_release_balance_lock_if_due(ended_round)
	round_number = scheduler.measure_index() + 1
	if bool(result.get("round_started", false)):
		_emit_event(&"round_started", null, null, {"round": int(result.get("round", round_number))})
		for row: Variant in result.get("refreshed", []):
			if row is Dictionary:
				_emit_event(
					&"ap_refreshed",
					row.get("actor"),
					null,
					{"current_ap": row.get("current_ap", 0), "maximum_ap": row.get("maximum_ap", 0)},
				)
	if not result.has("round_started") and not result.has("round_ended"):
		var crossed := int(result.get("measures_crossed", 0))
		if crossed > 0:
			_emit_event(&"measure_started", null, null, {"measure": scheduler.measure_index()})
			_release_balance_lock_if_due(round_number)


## Resolves exactly one enemy's turn. The scheduler — not a `for foe in enemies` loop — decides
## which enemy this is and when. Grid-capable battlefields plan a legal move before committing;
## attack affordability is checked only after a target is in range.
func _resolve_enemy_actor(actor: BattleActor) -> void:
	var enemy_action := action_by_id(&"enemy-strike")
	var target := _first_living(allies)
	if target == null:
		return
	var targeting := battlefield.target_query(actor, target, enemy_action.target_profile)
	if not bool(targeting.get("allowed", false)):
		var destination := _best_enemy_position(actor, target)
		if destination != &"":
			_resolve_enemy_move(actor, target, destination)
			return
	var commit_result := scheduler.commit(actor, enemy_action)
	if not bool(commit_result.get("allowed", false)):
		_emit_event(
			&"action_refused", actor, target, {"action_id": enemy_action.id, "reason": commit_result}
		)
		_force_pass(actor)
		return
	_face_toward(actor, target)
	var outcome := _apply_action(actor, target, enemy_action)
	outcome["action_id"] = enemy_action.id
	outcome["ap_cost"] = enemy_action.ap_cost
	outcome["ct_spent"] = int(commit_result.get("ct_spent", 0))
	outcome["ap_remaining"] = actor.action_points
	outcome["charge_remaining"] = int(commit_result.get("charge", 0))
	_emit_event(&"action_resolved", actor, target, outcome)
	scheduler.release(actor)
	_change_balance(actor.balance_affinity * actor.balance_pressure, actor)


## Grid-capable enemies spend movement on height and rear access before closing directly. The
## capability check keeps zone combat on its legacy attack-or-pass behavior and avoids a concrete
## GridBattlefieldModel dependency at this consumer seam.
func _best_enemy_position(actor: BattleActor, target: BattleActor) -> StringName:
	var capabilities: Dictionary = battlefield.capabilities()
	if not bool(capabilities.get("cells", false)):
		return &""
	var target_position: Dictionary = battlefield.describe_position(battlefield.position_of(target))
	if not target_position.has("cell"):
		return &""
	var budget := rules.maximum_action_ct_cost if rules != null else 0
	var candidates: Array[StringName] = battlefield.reachable_positions(actor, budget)
	var best := &""
	var best_score := -2147483648
	for candidate in candidates:
		var described: Dictionary = battlefield.describe_position(candidate)
		if not described.has("cell"):
			continue
		var score := _enemy_position_score(described, target_position, target)
		if score > best_score or (score == best_score and (best == &"" or candidate < best)):
			best = candidate
			best_score = score
	return best


func _enemy_position_score(
	candidate: Dictionary, target_position: Dictionary, target: BattleActor
) -> int:
	var candidate_cell: Vector2i = candidate.get("cell", Vector2i.ZERO)
	var target_cell: Vector2i = target_position.get("cell", Vector2i.ZERO)
	var delta := candidate_cell - target_cell
	var distance := maxi(absi(delta.x), absi(delta.y))
	var score := int(candidate.get("elevation", 0)) * 1000 - distance
	if distance <= 1:
		score += 500
	var attack_direction := _facing_for_delta(delta)
	if attack_direction != &"" and attack_direction == _opposite_facing(battlefield.facing_of(target)):
		score += 1000
	return score


func _resolve_enemy_move(actor: BattleActor, target: BattleActor, destination: StringName) -> void:
	var path: Dictionary = battlefield.path_query(actor, destination)
	if not bool(path.get("allowed", false)):
		_force_pass(actor)
		return
	var move_action := CombatAction.new()
	move_action.id = &"__enemy_grid_move__"
	move_action.display_name = "Move"
	move_action.kind = CombatAction.Kind.MOVE
	move_action.verb = CombatAction.Verb.MOVE
	move_action.target_profile = &"self"
	move_action.destination = destination
	move_action.ap_cost = 1
	move_action.ct_cost = int(path.get("ct_cost", rules.move_ct_cost if rules != null else 0))
	var commit_result := scheduler.commit(actor, move_action)
	if not bool(commit_result.get("allowed", false)):
		_force_pass(actor)
		return
	var outcome := _apply_action(actor, target, move_action)
	outcome["action_id"] = move_action.id
	outcome["ap_cost"] = move_action.ap_cost
	outcome["ct_spent"] = int(commit_result.get("ct_spent", 0))
	outcome["ap_remaining"] = actor.action_points
	outcome["charge_remaining"] = int(commit_result.get("charge", 0))
	_emit_event(&"action_resolved", actor, target, outcome)
	_face_toward(actor, target)
	scheduler.release(actor)


func _face_toward(actor: BattleActor, target: BattleActor) -> void:
	var capabilities: Dictionary = battlefield.capabilities()
	if not bool(capabilities.get("facing", false)) or not bool(capabilities.get("cells", false)):
		return
	var actor_position: Dictionary = battlefield.describe_position(battlefield.position_of(actor))
	var target_position: Dictionary = battlefield.describe_position(battlefield.position_of(target))
	if not actor_position.has("cell") or not target_position.has("cell"):
		return
	var actor_cell: Vector2i = actor_position.get("cell", Vector2i.ZERO)
	var target_cell: Vector2i = target_position.get("cell", Vector2i.ZERO)
	var facing := _facing_for_delta(target_cell - actor_cell)
	if facing != &"":
		battlefield.set_facing(actor, facing)


func _facing_for_delta(delta: Vector2i) -> StringName:
	if delta == Vector2i.ZERO:
		return &""
	var order: Array[StringName] = [&"e", &"se", &"s", &"sw", &"w", &"nw", &"n", &"ne"]
	var angle := atan2(delta.y, delta.x)
	var index := int(round(angle / (PI / 4.0)))
	index = ((index % order.size()) + order.size()) % order.size()
	return order[index]


func _opposite_facing(facing: StringName) -> StringName:
	var order: Array[StringName] = [&"e", &"se", &"s", &"sw", &"w", &"nw", &"n", &"ne"]
	var index := order.find(facing)
	return &"" if index == -1 else order[(index + 4) % order.size()]


## An enemy that cannot afford its action or cannot reach a target still has to leave
## readiness — otherwise the scheduler would keep re-selecting it (AP: still "unacted
## this round"; CT: still at or above READY_AT) and the battle would hang. A zero-cost
## PASS action is the cleanest way to say "this turn happened and produced nothing"
## through the same commit()/release() pair every other action uses, so the scheduler's
## round/acted bookkeeping updates exactly as if a real action had resolved.
func _force_pass(actor: BattleActor) -> void:
	var result := scheduler.commit(actor, _pass_action())
	if bool(result.get("allowed", false)):
		scheduler.release(actor)
	else:
		# Two bounded attempts: a normal yield preserves scheduler-specific wait semantics. If
		# that is refused by the same non-resource gate (for example an interrupt), consume the
		# readiness with zero refund. Never return with this actor still selectable forever.
		var yielded := scheduler.yield_turn(actor)
		if not bool(yielded.get("allowed", false)):
			var forced := scheduler.force_advance(actor)
			if not bool(forced.get("allowed", false)):
				# Contract violation: force_advance may only refuse not_participating,
				# and a stuck-selectable actor is exactly the hang this path prevents.
				push_error("CombatController._force_pass(): force_advance refused for %s (%s)." % [
					actor.combat_id, str(forced.get("blocked_by", ""))])


func _pass_action() -> CombatAction:
	var action := CombatAction.new()
	action.id = &"__scheduler_pass__"
	action.kind = CombatAction.Kind.PASS
	action.verb = CombatAction.Verb.DEFEND
	action.ap_cost = 0
	action.ct_cost = 0
	return action


## Whether `actor` can pay for `action` specifically, as opposed to `scheduler.can_act()`
## which only answers "is it structurally your turn". The AP scheduler exposes this via
## `can_afford()` (not part of the base `TurnScheduler` contract, since only a resource-
## metered model needs it); the CT scheduler has no equivalent because every authored
## action costs at most `maximum_action_ct_cost` (60) against a 100 threshold, so being
## ready (`can_act()`) already implies being able to afford any authored action. This is
## checked via `has_method()` rather than a concrete-type check so this file still never
## names `ApRoundScheduler` or `ChargeTimeScheduler`.
func _can_afford(actor: BattleActor, action: CombatAction) -> Dictionary:
	if scheduler.has_method("can_afford"):
		return scheduler.call("can_afford", actor, action)
	return scheduler.can_act(actor)


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
			action.element_id,
			action.magnitude,
			_sequence,
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
			# Neither scheduler indexes participants by side internally — ApRoundScheduler
			# reads `actor.side` live on every call, and ChargeTimeScheduler never looks at
			# side at all — so flipping the field is enough. Deliberately NOT calling
			# remove_participant()/setup() here: that would wipe every combatant's banked
			# charge/seat, which is exactly the "a split must not reorder survivors"
			# guarantee the scheduler's own tests require (see test_turn_scheduler.gd).
			target.side = &"ally"
			turned_ids.append(target.combat_id)
		else:
			var removal := battlefield.remove_combatant(target)
			if not bool(removal.get("allowed", false)):
				continue
			enemies.erase(target)
			scheduler.remove_participant(target)
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


func _release_balance_lock_if_due(current_round: int) -> void:
	if balance_lock_until_round <= 0 or current_round < balance_lock_until_round:
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
			"charge": scheduler.charge_of(actor) if scheduler != null else 0,
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
		# Set the side BEFORE the already-assigned check below. An actor reused across battles
		# keeps its combat_id and would otherwise skip the loop body entirely and end up with no
		# side, which reads to a scheduler as "on neither side" and drops it from the order.
		actor.side = prefix
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
