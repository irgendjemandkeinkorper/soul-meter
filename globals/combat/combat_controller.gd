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

const ACTION_MOVE: StringName = &"move"
## PROVISIONAL Wave P positional-AI weight: cover beats adjacency (+500), while a rear
## opportunity (+1000) remains the stronger tactical instinct.
const _ENEMY_COVER_POSITION_SCORE := 750

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
## Location/encounter input for fizzle. Battle resolves it once at setup so
## forecast and commit cannot observe different scene state.
var agreement_integrity: float = 100.0
## Issue #209: the live Weather instance. Ticks on the scheduler's real CT cadence
## (`_advance_weather()`), applies its per-measure feed/starve to `tile_states`, and
## feeds `Resolution` context. Stays at the UNCHARGED sentinel unless the encounter
## authors an element via `configure_weather()` — which encounters do is an owner
## (balance) decision, not decided here.
var weather: Weather = Weather.new()
## Issue #209: per-cell TileState for grid battles ([] for zone battles). Built from
## the battlefield's static terrain in start(); charge moves only through Weather's
## measure application (residue-on-cast wiring is a separate authored-ability task).
var tile_states: Array[TileState] = []
var _tile_by_cell: Dictionary = {}  ## Vector2i -> TileState

var _actions: Dictionary = {}
var _abilities: Dictionary = {}
var _tactical_tables: TacticalTables
var _sequence := 0
var _encounter_id: StringName = &""
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
	check_service: SkillCheckService = null,
	abilities: Array[AbilityDefinition] = [],
	tactical_tables: TacticalTables = null,
) -> void:
	_actions.clear()
	for action in actions:
		_actions[action.id] = action
	_abilities.clear()
	for ability in abilities:
		_abilities[ability.id] = ability
	_tactical_tables = tactical_tables if tactical_tables != null else TacticalTables.shared()
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


func configure_agreement_integrity(value: float) -> void:
	agreement_integrity = clampf(value, 0.0, 100.0)


## Issue #209: authors this battle's weather element (from encounter data — the caller
## owns where that is authored). Returns Weather's own validation result, so an
## unrecognized element is a loud refusal, never silently "weather".
func configure_weather(element_id: StringName, hush: bool = false) -> Dictionary:
	weather.set_hush(hush)
	if element_id == Weather.UNCHARGED:
		return {"allowed": true, "element_id": String(Weather.UNCHARGED)}
	return weather.set_element(element_id)


## Builds one TileState per battlefield cell (grid battles only; a cell-less model
## reports no tiles and the battle keeps zone semantics). Heights come from the same
## terrain snapshot the presentation layer uses, so the two can never disagree.
func _build_tile_states(encounter_id: StringName) -> void:
	tile_states.clear()
	_tile_by_cell.clear()
	if battlefield == null:
		return
	for terrain: Dictionary in battlefield.tiles_snapshot():
		var tile := TileState.create(
			encounter_id,
			int(terrain.get("x", 0)),
			int(terrain.get("y", 0)),
			int(terrain.get("height_delta", 0)),
			bool(terrain.get("cover", false)),
		)
		tile_states.append(tile)
		_tile_by_cell[Vector2i(tile.x, tile.y)] = tile


## Advances weather by the CT ticks the scheduler just reported. Every 16th tick
## Weather applies its measure over the live tiles; an application that moved charge
## is presentation-worthy, so it is emitted as its own event.
func _advance_weather(ticks_elapsed: int) -> void:
	for i in ticks_elapsed:
		var result := weather.tick(tile_states, balance)
		if not bool(result.get("applied", false)):
			continue
		if weather.element_id == Weather.UNCHARGED:
			continue
		_emit_event(&"weather_applied", null, null, {
			"element_id": String(weather.element_id),
			"charged_tiles": int(result.get("charged_tiles", 0)),
			"drained_tiles": int(result.get("drained_tiles", 0)),
			"measures_applied": weather.measures_applied(),
		})


func tile_state_at(cell: Vector2i) -> TileState:
	return _tile_by_cell.get(cell)


## The diametric Clash element (wheel distance 5) — what this weather starves.
static func _clash_of(element_id: StringName) -> StringName:
	for candidate: StringName in ElementWheel.ORDER:
		if ElementWheel.distance(element_id, candidate) == Weather.CLASH_WHEEL_DISTANCE:
			return candidate
	return &""


func start(
	ally_group: Array[BattleActor],
	enemy_group: Array[BattleActor],
	encounter_id: StringName = &""
) -> void:
	allies = ally_group
	enemies = enemy_group
	_encounter_id = encounter_id
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
	_build_tile_states(encounter_id)
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
	if action.kind == CombatAction.Kind.MOVE:
		var movement := battlefield.move_query(actor, _move_destination(action, options))
		if not bool(movement.get("allowed", false)):
			return movement
		var priced_action := _priced_move_action(action, movement, options)
		var move_affordability := _can_afford(actor, priced_action)
		if not bool(move_affordability.get("allowed", false)):
			return move_affordability
		movement["ap_cost"] = priced_action.ap_cost
		movement["ct_cost"] = priced_action.ct_cost
		return movement
	var affordability := _can_afford(actor, action)
	if not bool(affordability.get("allowed", false)):
		return affordability
	if action.requires_enemy_target():
		var targeting := battlefield.target_query(actor, target, action.target_profile)
		if not bool(targeting.get("allowed", false)):
			return targeting
	if action.kind == CombatAction.Kind.DEFINING_STRIKE:
		var defining_gate := _query_defining_strike(
			target, StringName(options.get("weakness_id", ""))
		)
		if not bool(defining_gate.get("allowed", false)):
			return defining_gate
		var resolution_options := options.duplicate(true)
		resolution_options.merge({
			"weakness": defining_gate.get("weakness", {}).duplicate(true),
			"seed": _sequence,
			"ability_id": String(action.id),
			"battle_id": String(_encounter_id),
		}, true)
		var resolution_gate := _query_attack_resolution(
			actor, target, action, resolution_options
		)
		if not bool(resolution_gate.get("allowed", false)):
			return resolution_gate
		defining_gate.merge(resolution_gate, true)
		return defining_gate
	if action.kind == CombatAction.Kind.CAST:
		return _query_cast(actor, target, action, options)
	if action.kind == CombatAction.Kind.ATTACK:
		return _query_attack_resolution(actor, target, action, options)
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
	var committed_action := _priced_move_action(action, query, options)
	var commit_result := scheduler.commit(actor, committed_action)
	if not bool(commit_result.get("allowed", false)):
		# query_action() already validated affordability via the same gate, so this is a
		# defensive re-check (e.g. a race between query and submit), not duplicated UX.
		last_refusal = commit_result.duplicate(true)
		_emit_event(&"action_refused", actor, target, {"action_id": action_id, "reason": commit_result})
		return commit_result
	var resolved_options := options.duplicate(true)
	if query.has("resolution"):
		resolved_options["_resolution"] = query["resolution"]
		resolved_options["_resolution_context"] = query.get("context", {})
	var outcome := _apply_action(actor, target, committed_action, resolved_options)
	outcome["action_id"] = action.id
	outcome["verb"] = action.verb
	outcome["ap_cost"] = committed_action.ap_cost
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
	var forfeited_ap := actor.action_points
	# Yield before publishing the end-of-turn transition. Charge time can refuse a third
	# consecutive wait, in which case the ready actor must remain in control and act.
	var yield_result := scheduler.yield_turn(actor)
	if not bool(yield_result.get("allowed", false)):
		last_refusal = yield_result.duplicate(true)
		_emit_event(&"action_refused", actor, null, {"action_id": &"", "reason": yield_result})
		return false
	var unused_ap_defense := 0
	if (
		rules != null
		and str(scheduler.to_dict().get("scheduler", "")) == "ap_round"
		and forfeited_ap >= 1
	):
		unused_ap_defense = mini(
			forfeited_ap * rules.unused_ap_defense_per_ap,
			rules.unused_ap_defense_cap,
		)
		actor.unused_ap_defense_bonus = unused_ap_defense
	last_refusal.clear()
	_emit_event(
		&"turn_ended",
		actor,
		null,
		{
			"ap_remaining": actor.action_points,
			"charge_remaining": scheduler.charge_of(actor),
			"forfeited_ap": forfeited_ap,
			"unused_ap_defense_bonus": unused_ap_defense,
		},
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
		"encounter_id": _encounter_id,
		"round": round_number,
		"balance": balance,
		"balance_band_id": balance_band_id,
		"balance_lock_until_round": balance_lock_until_round,
		"threshold_effects_suppressed": threshold_effects_suppressed,
		"active_actor_id": active_actor().combat_id if active_actor() else &"",
		"allies": _actor_snapshots(allies),
		"enemies": _actor_snapshots(enemies),
		"tiles": _tile_snapshots(),
		"weather": _weather_snapshot(),
		"scheduler_mode": str(scheduler.to_dict().get("scheduler", "")) if scheduler != null else "",
		"turn_order": _turn_order_snapshot(),
		"movement": _movement_snapshot(),
	}


## Additive UI query surface for a selected destination. The result uses the battlefield's
## refusal taxonomy and includes the exact AP/CT quote submit_action() will commit.
func move_query(destination: StringName) -> Dictionary:
	return query_action(action_by_id(ACTION_MOVE), null, {"destination": destination})


func _movement_snapshot() -> Dictionary:
	var actor := active_actor()
	var action := action_by_id(ACTION_MOVE)
	if actor == null or action == null or battlefield == null:
		return {}
	var capabilities: Dictionary = battlefield.capabilities()
	if not bool(capabilities.get("cells", false)) or state != State.ALLY_TURN:
		return {}
	var base_move_cost := maxi(1, rules.move_ct_cost if rules != null else 1)
	var per_cell_ap := maxi(1, action.ap_cost)
	var ct_budget := int(actor.action_points / per_cell_ap) * base_move_cost
	var reachable: Array[Dictionary] = []
	for destination: StringName in battlefield.reachable_positions(actor, ct_budget):
		var query := move_query(destination)
		if not bool(query.get("allowed", false)):
			continue
		reachable.append({
			"destination": destination,
			"ap_cost": int(query.get("ap_cost", 0)),
			"ct_cost": int(query.get("ct_cost", 0)),
			"path": (query.get("path", []) as Array).duplicate(),
			"path_cells": _describe_path_cells(query.get("path", [])),
		})
	return {
		"action_id": ACTION_MOVE,
		"per_cell_ap_cost": per_cell_ap,
		"remaining_ap": actor.action_points,
		"reachable": reachable,
	}


func _turn_order_snapshot() -> Array[Dictionary]:
	var result: Array[Dictionary] = []
	if scheduler == null:
		return result
	# The AP scheduler exposes the complete living-round order (acted actors included);
	# CT keeps the forecast-depth view. Region E must never lose an actor mid-round.
	var order: Array[Dictionary]
	if scheduler.has_method("round_overview"):
		order = scheduler.round_overview()
	else:
		order = scheduler.peek_order(8)
	for entry: Dictionary in order:
		var actor := entry.get("actor") as BattleActor
		if actor == null:
			continue
		var row := entry.duplicate(true)
		row.erase("actor")
		row["actor_id"] = actor.combat_id
		row["display_name"] = actor.display_name
		result.append(row)
	return result


## Live tiles (terrain + charge) when a grid battle built TileStates; the static
## terrain snapshot otherwise (zone battles report none either way).
func _tile_snapshots() -> Array[Dictionary]:
	var result: Array[Dictionary] = []
	if tile_states.is_empty():
		if battlefield != null:
			result = battlefield.tiles_snapshot()
		return result
	for tile: TileState in tile_states:
		result.append(tile.to_dict())
	return result


func _weather_snapshot() -> Dictionary:
	var data := weather.to_dict()
	data["tick"] = scheduler.tick_count() if scheduler != null else 0
	if weather.element_id != Weather.UNCHARGED:
		data["gains"] = String(weather.element_id)
		data["drains"] = String(_clash_of(weather.element_id))
	return data


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
## `battle_id`/`tick`/tile-state/weather context stay neutral. Grid-capable callers provide the
## FR-105a height/facing context; zone combat keeps its existing additive flank behavior.
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
	seed: int = 0,
	positional_context: Dictionary = {},
	resolution_context: Dictionary = {},
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
	var unit_context := {
			"id": String(attacker.combat_id),
			"attack_scale": attacker.attack_scale,
			# To-hit (#169 ruling): grid callers supply positional context and opt in; zone
			# combat keeps its legacy auto-hit behavior.
			"to_hit_enabled": not positional_context.is_empty(),
			"tick": int(seed),
			"edge": int(attacker.attributes.get(&"edge", 0)),
			# #209: tile/weather terms ride the same positional channel. Absent keys
			# resolve to Resolution's neutral terms (uncharged tiles, no weather).
			"tile_state": positional_context.get("source_tile", {}),
			"weather": positional_context.get("weather", {}),
		}
	if resolution_context.has("weakness_id"):
		unit_context["weakness_id"] = resolution_context["weakness_id"]
		unit_context["weakness"] = resolution_context.get("weakness", {}).duplicate(true)
	if resolution_context.has("battle_id"):
		unit_context["battle_id"] = resolution_context["battle_id"]
	var result := Resolution.resolve_action(
		unit_context,
		{
			# Defining strikes pass their real ability id so the deterministic roll key
			# matches `forecast_defining_strike()` — forecast==resolution. Plain attacks
			# keep the legacy "attack" key (changing it would reshuffle every battle's RNG).
			"id": str(resolution_context.get("ability_id", "attack")),
			"element_id": element_id,
			"magnitude": ability_magnitude,
			"power": power,
		},
		{
			"target": {
				"id": String(target.combat_id),
				"hp": target.hp,
				"element_id": target.element_id,
				"edge": int(target.attributes.get(&"edge", 0)),
			},
			"tile_state": positional_context.get("target_tile", {}),
			"facing": positional_context.get("facing", {}),
			"height_advantage_steps": int(
				positional_context.get("height_advantage_steps", 0)
			),
		},
		seed,
	)
	var raw_damage := 0
	if bool(result.get("allowed", false)):
		if not bool(result.get("hit", true)):
			# A rolled miss deals nothing: bypass the 1-damage floor below, which exists for
			# glancing hits, not for whiffs.
			return 0
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
	# #209: weather shares the scheduler's clock — one Weather.tick() per CT tick the
	# scheduler just advanced, so the 16-tick measure cadences can never drift apart.
	_advance_weather(int(result.get("ticks_elapsed", 0)))
	if bool(result.get("round_ended", false)):
		var ended_round := int(result.get("ended_round", round_number))
		_emit_event(&"round_ended", null, null, {"round": ended_round})
		_release_balance_lock_if_due(ended_round)
	round_number = scheduler.measure_index() + 1
	if bool(result.get("round_started", false)):
		_emit_event(&"round_started", null, null, {"round": int(result.get("round", round_number))})
		for row: Variant in result.get("refreshed", []):
			if row is Dictionary:
				var refreshed_actor := row.get("actor") as BattleActor
				if refreshed_actor != null:
					refreshed_actor.unused_ap_defense_bonus = 0
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
	var has_cells := bool(battlefield.capabilities().get("cells", false))
	if not bool(targeting.get("allowed", false)) and has_cells:
		var destination := _best_enemy_position(actor, target)
		if destination != &"":
			_resolve_enemy_move(actor, target, destination)
			return
		_emit_event(
			&"action_refused", actor, target, {"action_id": enemy_action.id, "reason": targeting}
		)
		_force_pass(actor)
		return
	var resolution_gate := _query_attack_resolution(actor, target, enemy_action, {})
	if not bool(resolution_gate.get("allowed", false)):
		_emit_event(
			&"action_refused", actor, target, {"action_id": enemy_action.id, "reason": resolution_gate}
		)
		_force_pass(actor)
		return
	var commit_result := scheduler.commit(actor, enemy_action)
	if not bool(commit_result.get("allowed", false)):
		_emit_event(
			&"action_refused", actor, target, {"action_id": enemy_action.id, "reason": commit_result}
		)
		_force_pass(actor)
		return
	_face_toward(actor, target)
	var outcome := _apply_action(actor, target, enemy_action, {
		"_resolution": resolution_gate["resolution"],
		"_resolution_context": resolution_gate["context"],
	})
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
		var score := _enemy_position_score(candidate, described, target_position, target)
		# Tie-break through String: StringName's `<` orders by interning pointer,
		# which varies with process history — the same tie resolved differently
		# in two tests of one run before this was made genuinely lexical.
		if score > best_score \
				or (score == best_score and (best == &"" or String(candidate) < String(best))):
			best = candidate
			best_score = score
	return best


func _enemy_position_score(
	candidate_position: StringName,
	candidate: Dictionary,
	target_position: Dictionary,
	target: BattleActor,
) -> int:
	var candidate_cell: Vector2i = candidate.get("cell", Vector2i.ZERO)
	var target_cell: Vector2i = target_position.get("cell", Vector2i.ZERO)
	var delta := candidate_cell - target_cell
	var distance := maxi(absi(delta.x), absi(delta.y))
	var score := int(candidate.get("elevation", 0)) * 1000 - distance
	if distance <= 1:
		score += 500
	if battlefield.cover_bonus_at(target, candidate_position) > 0:
		score += _ENEMY_COVER_POSITION_SCORE
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


func _move_destination(action: CombatAction, options: Dictionary) -> StringName:
	var authored: Variant = options.get("destination", action.destination)
	return StringName(str(authored))


## AP prices the same weighted path the enemy/CT move path quotes. The authored move
## action's AP cost is the per-cell rate; elevation can raise the number of cost units.
func _priced_move_action(
	action: CombatAction, movement: Dictionary, options: Dictionary
) -> CombatAction:
	if action == null or action.kind != CombatAction.Kind.MOVE:
		return action
	var priced := action.duplicate(true) as CombatAction
	priced.destination = _move_destination(action, options)
	if movement.has("ct_cost"):
		var base_move_cost := maxi(1, rules.move_ct_cost if rules != null else 1)
		var cost_units := maxi(
			1, ceili(float(movement.get("ct_cost", 0)) / float(base_move_cost))
		)
		priced.ap_cost = maxi(1, action.ap_cost) * cost_units
		priced.ct_cost = int(movement.get("ct_cost", base_move_cost))
	return priced


func _apply_action(
	actor: BattleActor, target: BattleActor, action: CombatAction, options: Dictionary = {}
) -> Dictionary:
	var result: Dictionary = {"message": "%s uses %s." % [actor.display_name, action.display_name]}
	match action.kind:
		CombatAction.Kind.ATTACK:
			result.merge(_resolve_attack(actor, target, action, options), true)
		CombatAction.Kind.CAST:
			result.merge(_resolve_attack(actor, target, action, options), true)
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
			result["path_cells"] = _describe_path_cells(result.get("path", []))
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


## Converts model-owned opaque handles at the controller boundary. Presentation receives
## renderable cells without learning GridBattlefieldModel's handle serialization.
func _describe_path_cells(value: Variant) -> Array[Vector2i]:
	var cells: Array[Vector2i] = []
	if battlefield == null or value is not Array:
		return cells
	for handle_value: Variant in value as Array:
		var described: Dictionary = battlefield.describe_position(StringName(str(handle_value)))
		var cell_value: Variant = described.get("cell")
		if cell_value is not Vector2i:
			return []
		cells.append(cell_value)
	return cells


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


func _query_cast(
	actor: BattleActor, target: BattleActor, action: CombatAction, options: Dictionary
) -> Dictionary:
	var requested := str(options.get("ability_id", ""))
	if requested.is_empty():
		return _blocked(
			&"ability",
			"Select an action ability from this unit's loadout to cast.",
			{"type": &"ability_selection"},
		)
	var ability := _cast_ability(actor, options)
	if ability == null:
		return _blocked(
			&"ability",
			"Equip %s in this unit's action loadout before casting it." % requested,
			{"type": &"unit_loadout", "ability_id": requested},
		)
	var context := forecast_context(actor, target, action, options)
	var terms := _positional_terms(actor, target)
	var resolution := _finalize_resolution_damage(
		Resolution.resolve(context), target, int(terms["cover_bonus"])
	)
	if not bool(resolution.get("allowed", false)):
		return resolution
	var soul_cost := 0.0
	for write: Dictionary in resolution.get("writes", []):
		if write.get("kind", "") == "soul_meter":
			soul_cost = -float(write.get("delta", 0.0))
	return _allowed({
		"ability_id": ability.id,
		"breath_cost": ability.breath_cost,
		"soul_cost": soul_cost,
		"context": context,
		"resolution": resolution,
	})


func _query_attack_resolution(
	actor: BattleActor, target: BattleActor, action: CombatAction, options: Dictionary
) -> Dictionary:
	var context := forecast_context(actor, target, action, options)
	var terms := _positional_terms(actor, target)
	var resolution := _finalize_resolution_damage(
		Resolution.resolve(context), target, int(terms["cover_bonus"])
	)
	if not bool(resolution.get("allowed", false)):
		return resolution
	return _allowed({"context": context, "resolution": resolution})


func _cast_ability(actor: BattleActor, options: Dictionary) -> AbilityDefinition:
	var requested := str(options.get("ability_id", ""))
	if requested.is_empty() or actor == null or _tactical_tables == null:
		return null
	for ability: AbilityDefinition in _tactical_tables.abilities_for_unit(
		_actor_unit_id(actor), AbilityDefinition.SLOT_ACTION
	):
		if ability.id == requested:
			return _abilities.get(requested) as AbilityDefinition
	return null


func _actor_unit_id(actor: BattleActor) -> String:
	if actor == null:
		return ""
	if actor.source_member != null:
		return actor.source_member.id
	return String(actor.archetype_id)


func _fizzle_context(actor: BattleActor, options: Dictionary) -> Dictionary:
	var raw: Variant = options.get("fizzle", {})
	var context: Dictionary = raw.duplicate(true) if raw is Dictionary else {}
	if not context.has("agreement_integrity"):
		context["agreement_integrity"] = agreement_integrity
	if not context.has("pitch"):
		context["pitch"] = actor.attribute_value(&"pitch")
	if actor.source_member != null and not context.has("patron"):
		context["patron"] = actor.source_member.patron
	return context


func _resolved_attack(
	actor: BattleActor,
	target: BattleActor,
	action: CombatAction,
	options: Dictionary,
	terms: Dictionary,
) -> Dictionary:
	if options.has("_resolution"):
		var cached := (options["_resolution"] as Dictionary).duplicate(true)
		for write: Dictionary in cached.get("writes", []):
			if (
				write.get("kind", "") == "hp"
				and String(write.get("target_id", "")) == String(target.combat_id)
			):
				return cached
	var context := forecast_context(actor, target, action, options)
	return _finalize_resolution_damage(
		Resolution.resolve(context), target, int(terms["cover_bonus"])
	)


func _finalize_resolution_damage(
	resolution: Dictionary, target: BattleActor, cover_bonus: int
) -> Dictionary:
	if not bool(resolution.get("allowed", false)):
		return resolution
	var finalized := resolution.duplicate(true)
	var damage := 0
	if bool(finalized.get("hit", true)) and not bool(finalized.get("fizzled", false)):
		damage = maxi(
			1,
			int(finalized.get("damage", 0))
			- target.effective_defense()
			- int(target.balance_effects.get("defense_bonus", 0))
			- cover_bonus,
		)
	finalized["damage"] = damage
	var writes: Array = finalized.get("writes", [])
	for write: Dictionary in writes:
		if write.get("kind", "") != "hp":
			continue
		write["before"] = target.hp
		write["after"] = maxi(target.hp - damage, 0)
		write["delta"] = int(write["after"]) - target.hp
	var action_log: Dictionary = finalized.get("action_log", {})
	if not action_log.is_empty():
		action_log["deltas"] = writes.duplicate(true)
		finalized["action_log"] = action_log
	return finalized


func _apply_resolution_writes(
	actor: BattleActor,
	target: BattleActor,
	resolution: Dictionary,
	apply_tile_writes: bool = true,
) -> void:
	for write: Dictionary in resolution.get("writes", []):
		match StringName(write.get("kind", "")):
			&"hp":
				target.hp = int(write.get("after", target.hp))
			&"breath":
				actor.breath = int(write.get("after", actor.breath))
			&"soul_meter":
				_set_soul_meter(float(write.get("after", _soul_meter())))
			&"tile_state":
				if not apply_tile_writes:
					continue
				var cell := Vector2i(int(write.get("x", 0)), int(write.get("y", 0)))
				var live_tile := tile_state_at(cell)
				var after: Dictionary = write.get("after", {})
				if live_tile != null and not after.is_empty():
					live_tile.charge_element_id = StringName(after.get("charge_element_id", ""))
					live_tile.charge_level = int(after.get("charge_level", 0))
					live_tile.height_delta = int(after.get("height_delta", live_tile.height_delta))
					live_tile.cover = bool(after.get("cover", live_tile.cover))
					live_tile.hush = bool(after.get("hush", live_tile.hush))


func _game_state() -> Node:
	var tree := Engine.get_main_loop() as SceneTree
	if tree == null:
		return null
	return tree.root.get_node_or_null("GameState")


func _soul_meter() -> float:
	var game_state := _game_state()
	return float(game_state.get("soul_meter")) if game_state != null else 0.0


func _set_soul_meter(value: float) -> void:
	var game_state := _game_state()
	if game_state != null:
		game_state.call("set_soul_meter", value)


func _resolve_attack(
	actor: BattleActor,
	target: BattleActor,
	action: CombatAction,
	resolution_context: Dictionary = {},
) -> Dictionary:
	var total_damage := 0
	var positional_results: Array[Dictionary] = []
	var committed_resolution: Dictionary = {}
	var hit_targets := battlefield.targets_for(actor, target, action.aoe_shape)
	var pending_hits: Array[Dictionary] = []
	for hit_target: BattleActor in hit_targets:
		var terms := _positional_terms(actor, hit_target)
		var positional_context: Dictionary = terms["positional_context"]
		var resolved := _resolved_attack(actor, hit_target, action, resolution_context, terms)
		if not bool(resolved.get("allowed", false)):
			return resolved
		pending_hits.append({
			"target": hit_target,
			"terms": terms,
			"positional_context": positional_context,
			"resolution": resolved,
		})
	# Resolve every target against the same pre-action resource/tile state. Applying afterward
	# keeps one Breath/Soul/tile cost idempotent while each target receives its own HP write.
	for pending: Dictionary in pending_hits:
		var hit_target := pending["target"] as BattleActor
		var terms: Dictionary = pending["terms"]
		var positional_context: Dictionary = pending["positional_context"]
		var resolved: Dictionary = pending["resolution"]
		# #215 promotes Resolution tile writes for CAST. Mundane attacks keep their ratified
		# non-mutating tile behavior; widening elemental residue to every attack is out of scope.
		_apply_resolution_writes(
			actor, hit_target, resolved, action.kind == CombatAction.Kind.CAST
		)
		committed_resolution = resolved
		var damage := int(resolved.get("damage", 0))
		total_damage += damage
		if not positional_context.is_empty():
			var modifiers := Resolution.positional_modifiers(
				int(positional_context["height_advantage_steps"]),
				StringName(positional_context["facing"]["id"]),
			)
			positional_results.append({
				"target_id": String(hit_target.combat_id),
				"facing": modifiers["facing"],
				"height_advantage_steps": modifiers["height_advantage_steps"],
				"hit_bonus": modifiers["hit_bonus"],
				"line_of_sight": (
					battlefield.line_of_sight(actor, hit_target)
					if action.target_profile == &"ranged" else _allowed()
				),
				"cover_bonus": int(terms["cover_bonus"]),
				"flank_bonus": int(terms["flank_bonus"]),
			})
	return {
		"damage": total_damage,
		"resolution": committed_resolution,
		"positioning": positional_results,
		"message": "%s uses %s for %d damage."
		% [actor.display_name, action.display_name, total_damage],
	}


## #209 forecast parity: the same Resolution context an actual strike will use — same
## power arithmetic, same tile/weather/facing terms — minus the to-hit roll (a forecast
## shows the on-hit number). Region D's only calculator is Resolution.resolve(); feeding
## it this context keeps forecast == resolution by construction.
func forecast_context(
	actor: BattleActor, target: BattleActor, action: CombatAction, options: Dictionary = {}
) -> Dictionary:
	if actor == null or target == null or action == null:
		return {}
	var terms := _positional_terms(actor, target)
	var positional_context: Dictionary = terms["positional_context"]
	var flank_bonus := int(terms["flank_bonus"])
	var cover_bonus := int(terms["cover_bonus"])
	var line_of_sight := (
		battlefield.line_of_sight(actor, target)
		if action.target_profile == &"ranged" else _allowed()
	)
	var cast_ability: AbilityDefinition = (
		_cast_ability(actor, options) if action.kind == CombatAction.Kind.CAST else null
	)
	var element_id := cast_ability.element_id if cast_ability != null else action.element_id
	if String(element_id).is_empty():
		element_id = _UNAUTHORED_ELEMENT_ID
	var power := cast_ability.power if cast_ability != null else (
		actor.effective_attack()
		+ action.power_bonus
		+ flank_bonus
		+ int(actor.balance_effects.get("damage_bonus", 0))
	)
	var ability_id := "attack"
	var battle_id := ""
	if cast_ability != null:
		ability_id = cast_ability.id
		battle_id = String(_encounter_id)
	elif action.kind == CombatAction.Kind.DEFINING_STRIKE:
		ability_id = str(options.get("ability_id", action.id))
		battle_id = str(options.get("battle_id", _encounter_id))
	var resolution_seed := int(options.get("seed", _sequence))
	var ability_context := {
		# Plain attacks retain the pre-#215 deterministic roll key. Casts use the selected
		# AbilityDefinition id so forecast and commit identify the same authored working.
		"id": ability_id,
		"element_id": element_id,
		"elements": cast_ability.elements.duplicate() if cast_ability != null else [element_id],
		"magnitude": cast_ability.magnitude if cast_ability != null else action.magnitude,
		"power": power,
	}
	if cast_ability != null:
		ability_context["is_spell"] = true
		ability_context["breath_cost"] = cast_ability.breath_cost
	var target_height := 0
	var target_position: Dictionary = battlefield.describe_position(battlefield.position_of(target))
	if target_position.has("elevation"):
		target_height = int(target_position["elevation"])
	var context := {
		# Legacy calculate_damage() passed a wrapper with no top-level battle_id to
		# Resolution.resolve_action(), so plain attacks hashed the empty-string fallback.
		# That key is deliberately frozen for legacy roll parity: changing it reshuffles
		# every Gate T-1 self-play roll.
		# Casts and Defining Strikes retain their authored encounter identity.
		"battle_id": battle_id,
		"tick": resolution_seed,
		"seed": resolution_seed,
		"unit": {
			"id": String(actor.combat_id),
			"attack_scale": actor.attack_scale,
			"edge": int(actor.attributes.get(&"edge", 0)),
			"breath": actor.breath,
		},
		"ability": ability_context,
		"target": {
			"id": String(target.combat_id),
			"hp": target.hp,
			"element_id": target.element_id,
			"edge": int(target.attributes.get(&"edge", 0)),
			"height": target_height,
			"attunements": {},
		},
		"source_tile": positional_context.get("source_tile", {}),
		"target_tile": positional_context.get("target_tile", {}),
		"weather": positional_context.get("weather", weather.to_dict()),
		"facing": positional_context.get("facing", {}),
		"height_advantage_steps": int(positional_context.get("height_advantage_steps", 0)),
		"to_hit_enabled": not positional_context.is_empty(),
		"soul_meter": _soul_meter(),
		"fizzle": _fizzle_context(actor, options),
		"caster_context": (options.get("caster_context", {}) as Dictionary).duplicate(true),
		"positioning": {
			"line_of_sight": line_of_sight,
			"cover_bonus": cover_bonus,
			"flank_bonus": flank_bonus,
			"facing": positional_context.get("facing", {}),
			"height_advantage_steps": int(
				positional_context.get("height_advantage_steps", 0)
			),
		},
	}
	if options.has("weakness_id"):
		context["weakness_id"] = options["weakness_id"]
		context["weakness"] = (options.get("weakness", {}) as Dictionary).duplicate(true)
	return context


## User-facing forecast: gate first (including ranged LOS), then run the same pure context and
## post-mitigation damage pipeline submit_action() uses. Refusals are returned unchanged so the
## blocked_by taxonomy is identical at forecast and commit.
func forecast_action(
	action: CombatAction, target: BattleActor = null, options: Dictionary = {}
) -> Dictionary:
	var gate := query_action(action, target, options)
	if not bool(gate.get("allowed", false)):
		return gate
	var actor := active_actor()
	if action.kind == CombatAction.Kind.MOVE:
		return _allowed({
			"action_id": action.id,
			"ap_cost": int(gate.get("ap_cost", action.ap_cost)),
			"ct_cost": int(gate.get("ct_cost", action.ct_cost)),
			"path": (gate.get("path", []) as Array).duplicate(),
			"destination": _move_destination(action, options),
		})
	if action.kind == CombatAction.Kind.CAST:
		var cast_resolution: Dictionary = gate["resolution"]
		return _allowed({
			"action_id": action.id,
			"ability_id": gate["ability_id"],
			"ap_cost": action.ap_cost,
			"damage": int(cast_resolution.get("damage", 0)),
			"fizzle_percent": float(cast_resolution.get("fizzle_percent", 0.0)),
			"breath_cost": int(gate.get("breath_cost", 0)),
			"soul_cost": float(gate.get("soul_cost", 0.0)),
			"resolution": cast_resolution,
			"context": gate["context"],
			"positioning": (gate["context"].get("positioning", {}) as Dictionary).duplicate(true),
		})
	var context := forecast_context(actor, target, action, options)
	var resolution := _finalize_resolution_damage(
		Resolution.resolve(context), target, int(_positional_terms(actor, target)["cover_bonus"])
	)
	var damage := int(resolution.get("damage", 0))
	return _allowed({
		"action_id": action.id,
		"ap_cost": action.ap_cost,
		"damage": damage,
		"resolution": resolution,
		"context": context,
		"positioning": (context.get("positioning", {}) as Dictionary).duplicate(true),
	})


func forecast_defining_strike(target: BattleActor, weakness_id: StringName) -> Dictionary:
	var actor := active_actor()
	var action := action_by_id(&"definition")
	var gate := query_action(action, target, {"weakness_id": weakness_id})
	if not bool(gate.get("allowed", false)):
		return gate
	var weakness: Dictionary = gate.get("weakness", {})
	var resolution_options := {
		"weakness_id": weakness_id,
		"weakness": weakness.duplicate(true),
		"seed": _sequence,
		"ability_id": String(action.id),
		"battle_id": String(_encounter_id),
	}
	var context := forecast_context(actor, target, action, resolution_options)
	var terms := _positional_terms(actor, target)
	var resolution := _finalize_resolution_damage(
		Resolution.resolve(context), target, int(terms["cover_bonus"])
	)
	if not bool(resolution.get("allowed", false)):
		return resolution
	return _allowed({
		"action_id": action.id,
		"weakness_id": weakness_id,
		"weakness_name": str(weakness.get("display_name", weakness_id)),
		"damage": int(resolution.get("damage", 0)),
		"ap_cost": action.ap_cost,
		"chance": skill_check_service.preview(
			str(weakness.get("check_skill", "lore")),
			actor.source_member,
			float(weakness.get("check_modifier", 0.0)),
		),
		"effect_id": StringName(weakness.get("effect_id", "")),
		"effect_parameters": (weakness.get("effect_parameters", {}) as Dictionary).duplicate(true),
		"resolution": resolution,
	})


## The ONE source of positional damage terms. _resolve_attack, forecast_context
## and forecast_action must all draw from here: when forecast_action fetched its
## own flank_bonus without the positional-context guard, forecast and committed
## damage diverged for side/back facing on grid battles (Wave P gate finding).
## Grid battles pay flanking through the ratified facing MULTIPLIERS inside the
## positional context (x1.10 side / x1.25 back); the flat flank_bonus is the
## zone model's mechanism and must stay zero here or flanking double-dips.
func _positional_terms(actor: BattleActor, target: BattleActor) -> Dictionary:
	var positional_context := _positional_resolution_context(actor, target)
	var cover_bonus := battlefield.cover_bonus(actor, target)
	if bool(target.defining_effects.get("revealed", false)):
		cover_bonus = 0
	var flank_bonus := battlefield.flank_bonus(actor, target)
	if not positional_context.is_empty():
		flank_bonus = 0
	return {
		"positional_context": positional_context,
		"cover_bonus": cover_bonus,
		"flank_bonus": flank_bonus,
	}


func _positional_resolution_context(actor: BattleActor, target: BattleActor) -> Dictionary:
	var capabilities: Dictionary = battlefield.capabilities()
	if (
		not bool(capabilities.get("cells", false))
		or not bool(capabilities.get("elevation", false))
		or not bool(capabilities.get("facing", false))
	):
		return {}
	var actor_position: Dictionary = battlefield.describe_position(battlefield.position_of(actor))
	var target_position: Dictionary = battlefield.describe_position(battlefield.position_of(target))
	if not actor_position.has("cell") or not target_position.has("cell"):
		return {}
	var attack_direction := _facing_for_delta(
		(actor_position["cell"] as Vector2i) - (target_position["cell"] as Vector2i)
	)
	var target_facing := battlefield.facing_of(target)
	var facing_id := &"side"
	if attack_direction == target_facing:
		facing_id = &"front"
	elif attack_direction == _opposite_facing(target_facing):
		facing_id = &"back"
	return {
		"height_advantage_steps": maxi(-battlefield.elevation_delta(actor, target), 0),
		"facing": {"id": facing_id},
		# #209: live tactical terrain context. Empty dicts resolve to Resolution's
		# neutral terms, so a grid battle without charges behaves exactly as before.
		"source_tile": _tile_context(actor_position["cell"] as Vector2i),
		"target_tile": _tile_context(target_position["cell"] as Vector2i),
		"weather": weather.to_dict(),
	}


func _tile_context(cell: Vector2i) -> Dictionary:
	var tile := tile_state_at(cell)
	return tile.to_dict() if tile != null else {}


func _resolve_defining_strike(
	actor: BattleActor, target: BattleActor, action: CombatAction, options: Dictionary
) -> Dictionary:
	var weakness_id := StringName(options.get("weakness_id", ""))
	var weakness := CombatIdentityCatalog.weakness(target.archetype_id, weakness_id)
	# Captured BEFORE the check emits `check_resolved` (which advances _sequence), so the
	# damage seed equals the one `forecast_defining_strike()` used — forecast==resolution.
	var damage_seed := _sequence
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

	var resolution_options := options.duplicate(true)
	resolution_options.merge({
		"weakness_id": weakness_id,
		"weakness": weakness.duplicate(true),
		"seed": damage_seed,
		"ability_id": String(action.id),
		"battle_id": String(_encounter_id),
	}, true)
	result.merge(_resolve_attack(actor, target, action, resolution_options), true)
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
			"element_id": actor.element_id,
			"facing": battlefield.facing_of(actor) if battlefield != null else &"",
			"hp": actor.hp,
			"max_hp": actor.max_hp,
			"ap": actor.action_points,
			"max_ap": actor.max_action_points,
			"charge": scheduler.charge_of(actor) if scheduler != null else 0,
			"position": battlefield.position_of(actor),
			"side": battlefield.side_of(actor),
			"guarding": actor.guarding,
			"unused_ap_defense_bonus": actor.unused_ap_defense_bonus,
			"archetype_id": actor.archetype_id,
			"balance_band_id": actor.balance_band_id,
			"balance_effects": actor.balance_effects.duplicate(true),
			"defining_effects": actor.defining_effects.duplicate(true),
			"discovered_weakness_ids": actor.discovered_weakness_ids.duplicate(),
			"breath": actor.breath,
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
