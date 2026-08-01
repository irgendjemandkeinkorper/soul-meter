extends Node
## Party turn combat around the Balance Gauge. Encounter composition,
## contextual resolutions, and their consequences come from generated data.

signal battle_started
signal turn_resolved
signal balance_changed(value: int)
signal battle_ended(result: BattleResult)

const BALANCE_MIN := -100
const BALANCE_MAX := 100
const EXTREME_THRESHOLD := 60
const EXTREME_POWER_BONUS := 2

const ACTION_STRIKE := &"strike"
const ACTION_GUARD := &"guard"
const ACTION_STABILIZE := &"stabilize"
const ACTION_DEFINITION := &"definition"
const ACTION_PARADOX := &"paradox"
const OUTCOME_DEFEAT := &"defeat"
const OUTCOME_FLED := &"fled"

var allies: Array[BattleActor] = []
var enemies: Array[BattleActor] = []
var active_ally_index := 0
var target_enemy_index := 0
var balance := 0
var enemy_rounds := 0
var last_message := ""
var ended := false
var encounter_id: StringName = &""
var last_result: BattleResult

var player: BattleActor:
	get:
		return current_ally()
var enemy: BattleActor:
	get:
		return enemies[0] if not enemies.is_empty() else null

var _definition: Dictionary = {}


func start(encounter: Variant) -> void:
	allies.clear()
	enemies.clear()
	_definition.clear()
	encounter_id = &""
	for i in GameState.party.size():
		var member: PartyMember = GameState.party[i]
		var actor := BattleActor.new()
		actor.display_name = member.display_name
		actor.hp = member.hp
		actor.max_hp = member.max_hp
		actor.attack = member.attack
		actor.defense = member.defense
		actor.party_index = i
		allies.append(actor)
	if allies.is_empty():
		allies.append(BattleActor.new())
	if encounter is StringName or encounter is String:
		encounter_id = StringName(encounter)
		_definition = EncounterCatalog.definition(encounter_id)
		enemies = EncounterCatalog.make_actors(encounter_id)
	elif encounter is BattleActor:
		enemies.append(encounter)
	elif encounter is Array:
		for actor in encounter:
			if actor is BattleActor:
				enemies.append(actor)
	active_ally_index = _next_living_index(allies, -1)
	target_enemy_index = _next_living_index(enemies, -1)
	balance = 0
	enemy_rounds = 0
	last_message = "The field hangs in balance. Each party member acts before the enemy round."
	ended = enemies.is_empty()
	last_result = null
	if ended:
		push_error("Cannot start an empty encounter: %s" % encounter_id)
		return
	battle_started.emit()
	balance_changed.emit(balance)


func available_actions() -> Array[CombatAction]:
	var result: Array[CombatAction] = [
		CombatAction.make(ACTION_STRIKE, "Strike", CombatAction.Kind.ATTACK),
		CombatAction.make(ACTION_GUARD, "Guard", CombatAction.Kind.GUARD),
		CombatAction.make(ACTION_STABILIZE, "Stabilize", CombatAction.Kind.STABILIZE),
		CombatAction.make(
			ACTION_DEFINITION, "Defining Strike", CombatAction.Kind.ATTACK, 2, 25, 3.0
		),
		CombatAction.make(ACTION_PARADOX, "Paradox Strike", CombatAction.Kind.ATTACK, 2, -25, 3.0),
	]
	for row in EncounterCatalog.context_actions(encounter_id):
		result.append(CombatAction.from_context_row(row))
	return result


func can_use(action: CombatAction) -> bool:
	return action_lock_reason(action).is_empty()


func action_lock_reason(action: CombatAction) -> String:
	if ended or current_ally() == null:
		return "Battle has ended."
	if GameState.soul_meter < action.soul_cost:
		return "Requires %d Soul." % int(action.soul_cost)
	if action.kind == CombatAction.Kind.RESOLUTION:
		if enemy_rounds < action.minimum_enemy_rounds:
			return action.lock_reason
		if balance < action.minimum_balance or balance > action.maximum_balance:
			return action.lock_reason
	return ""


func use_action(action_id: StringName, target_index: int = -1) -> bool:
	var action := _action_by_id(action_id)
	var actor := current_ally()
	if action == null or actor == null or not can_use(action):
		return false
	var target: BattleActor = null
	if action.kind == CombatAction.Kind.ATTACK:
		target = _living_enemy(target_enemy_index if target_index < 0 else target_index)
		if target == null:
			return false
	if action.soul_cost > 0.0:
		GameState.set_soul_meter(GameState.soul_meter - action.soul_cost)

	match action.kind:
		CombatAction.Kind.ATTACK:
			var damage := calculate_damage(
				actor, target, action.power_bonus, action.balance_shift, balance
			)
			target.hp = maxi(0, target.hp - damage)
			last_message = (
				"%s uses %s on %s for %d damage."
				% [actor.display_name, action.display_name, target.display_name, damage]
			)
		CombatAction.Kind.GUARD:
			actor.guarding = true
			last_message = "%s guards; incoming damage is reduced." % actor.display_name
		CombatAction.Kind.STABILIZE:
			actor.guarding = true
			last_message = "%s steadies the field toward equilibrium." % actor.display_name
		CombatAction.Kind.RESOLUTION:
			last_message = "%s chooses %s." % [actor.display_name, action.display_name]
			_finish(BattleResult.State.VICTORY, action.outcome_id)

	if action.kind != CombatAction.Kind.RESOLUTION:
		if action.balance_shift == 0:
			_shift_toward_center(30 if action.kind == CombatAction.Kind.STABILIZE else 10)
		else:
			shift_balance(action.balance_shift)
		if not _has_living(enemies):
			_finish(BattleResult.State.VICTORY, _default_outcome())
		else:
			if current_target() == null or not current_target().is_alive():
				target_enemy_index = _next_living_index(enemies, -1)
			_advance_party_turn()
	turn_resolved.emit()
	return true


func player_attack() -> void:
	use_action(ACTION_STRIKE)


func player_defend() -> void:
	use_action(ACTION_GUARD)


func flee() -> void:
	if not ended:
		last_message = "The party disengages. Current wounds are preserved."
		_finish(BattleResult.State.FLED, OUTCOME_FLED)


func current_ally() -> BattleActor:
	if active_ally_index < 0 or active_ally_index >= allies.size():
		return null
	return allies[active_ally_index]


func living_enemies() -> Array[BattleActor]:
	var result: Array[BattleActor] = []
	for actor in enemies:
		if actor.is_alive():
			result.append(actor)
	return result


func current_target() -> BattleActor:
	return _living_enemy(target_enemy_index)


func select_next_enemy() -> void:
	if enemies.is_empty():
		return
	for offset in range(1, enemies.size() + 1):
		var index := (target_enemy_index + offset) % enemies.size()
		if enemies[index].is_alive():
			target_enemy_index = index
			turn_resolved.emit()
			return


func shift_balance(amount: int) -> void:
	balance = clampi(balance + amount, BALANCE_MIN, BALANCE_MAX)
	balance_changed.emit(balance)


static func calculate_damage(
	attacker: BattleActor,
	target: BattleActor,
	power_bonus: int,
	alignment_shift: int,
	current_balance: int
) -> int:
	var damage := maxi(1, attacker.attack + power_bonus - target.defense)
	if alignment_shift > 0 and current_balance >= EXTREME_THRESHOLD:
		damage += EXTREME_POWER_BONUS
	elif alignment_shift < 0 and current_balance <= -EXTREME_THRESHOLD:
		damage += EXTREME_POWER_BONUS
	return damage


func _advance_party_turn() -> void:
	var next := _next_living_index(allies, active_ally_index)
	if next > active_ally_index:
		active_ally_index = next
		return
	_resolve_enemy_round()
	if _has_living(allies):
		active_ally_index = _next_living_index(allies, -1)
	else:
		_finish(BattleResult.State.DEFEAT, &"defeat")


func _resolve_enemy_round() -> void:
	enemy_rounds += 1
	for foe in enemies:
		if not foe.is_alive():
			continue
		var index := _next_living_index(allies, -1)
		if index < 0:
			return
		var target := allies[index]
		var damage := maxi(1, foe.attack - target.defense)
		if target.guarding:
			damage = maxi(1, damage / 2)
			target.guarding = false
		target.hp = maxi(0, target.hp - damage)
		shift_balance(foe.balance_affinity * foe.balance_pressure)
		last_message += " %s strikes %s for %d." % [foe.display_name, target.display_name, damage]


func _finish(state: BattleResult.State, outcome_id: StringName) -> void:
	if ended:
		return
	ended = true
	_sync_party_hp()
	if state == BattleResult.State.DEFEAT:
		for member in GameState.party:
			member.hp = maxi(1, ceili(member.max_hp * 0.5))
		GameState.party_changed.emit()
	var result := BattleResult.new()
	result.state = state
	result.encounter_id = encounter_id
	result.outcome_id = outcome_id
	_record_last_outcome(result)
	if state == BattleResult.State.VICTORY:
		_apply_victory(result)
	elif state == BattleResult.State.DEFEAT:
		result.message = "The company falls back and recovers to half strength."
		result.cause = _loss_cause()
		_apply_loss_consequence(result)
	else:
		result.message = "The company disengages without reward or resolution."
		result.cause = _flee_cause()
		SaveGame.request_autosave("encounter-" + String(encounter_id) + "-fled")
	last_result = result
	battle_ended.emit(result)


func _apply_victory(result: BattleResult) -> void:
	var outcome := EncounterCatalog.outcome(encounter_id, result.outcome_id)
	result.message = str(outcome.get("message", "The opposition is defeated."))
	result.cause = str(outcome.get("cause", _definition.get("win_cause", "Won a field encounter")))
	var defeated_flag := str(_definition.get("defeated_flag", ""))
	if defeated_flag.is_empty() and not enemies.is_empty():
		defeated_flag = enemies[0].defeated_flag
	var already_resolved := not defeated_flag.is_empty() and bool(GameState.get_flag(defeated_flag))
	if not defeated_flag.is_empty():
		GameState.set_flag(defeated_flag, true)
	if encounter_id == &"dorthkor-muster":
		GameState.set_flag("dorthkor_muster_outcome", String(result.outcome_id))
		GameState.set_flag("dorthkor_muster_cause", result.cause)
	if already_resolved:
		return
	var faction := str(outcome.get("faction", _definition.get("win_faction", "")))
	var delta := float(outcome.get("delta", _definition.get("win_delta", 0.0)))
	if faction.is_empty() and not enemies.is_empty():
		faction = enemies[0].win_faction
		delta = enemies[0].win_delta
	if not faction.is_empty():
		Reputation.record("player", faction, delta, result.cause, "field")
	Renown.gain_reputation(
		"player", float(outcome.get("renown", 3.0)), "Won a field encounter", "field"
	)
	SaveGame.request_autosave("encounter-" + String(encounter_id) + "-" + String(result.outcome_id))


func _apply_loss_consequence(result: BattleResult) -> void:
	var consequence_flag := _consequence_flag(result.outcome_id)
	if not consequence_flag.is_empty() and bool(GameState.get_flag(consequence_flag)):
		return
	if not consequence_flag.is_empty():
		GameState.set_flag(consequence_flag, true)

	var faction := ""
	var delta := 0.0
	if not enemies.is_empty():
		faction = enemies[0].loss_faction
		delta = enemies[0].loss_delta
	if not faction.is_empty():
		Reputation.record("player", faction, delta, result.cause, "field")
	SaveGame.request_autosave("encounter-" + String(encounter_id) + "-defeat")


func _record_last_outcome(result: BattleResult) -> void:
	var outcome_flag := _outcome_flag()
	if not outcome_flag.is_empty():
		GameState.set_flag(outcome_flag, String(result.outcome_id))


func _loss_cause() -> String:
	var configured := str(_definition.get("loss_cause", ""))
	if not configured.is_empty():
		return configured
	if not enemies.is_empty() and not enemies[0].loss_cause.is_empty():
		return enemies[0].loss_cause
	return "The company was driven back by the opposition."


func _flee_cause() -> String:
	var outcome := EncounterCatalog.outcome(encounter_id, OUTCOME_FLED)
	var configured := str(outcome.get("cause", ""))
	if not configured.is_empty():
		return configured
	return "The company chose to preserve its strength and withdraw."


func _outcome_flag() -> String:
	if encounter_id.is_empty():
		return ""
	return "encounter_" + String(encounter_id).replace("-", "_") + "_outcome"


func _consequence_flag(outcome_id: StringName) -> String:
	if encounter_id.is_empty():
		return ""
	return (
		"encounter_" + String(encounter_id).replace("-", "_") + "_"
		+ String(outcome_id) + "_consequence"
	)


func _sync_party_hp() -> void:
	for actor in allies:
		if actor.party_index >= 0 and actor.party_index < GameState.party.size():
			GameState.party[actor.party_index].hp = actor.hp
	GameState.party_changed.emit()


func _action_by_id(action_id: StringName) -> CombatAction:
	for action in available_actions():
		if action.id == action_id:
			return action
	return null


func _living_enemy(preferred: int) -> BattleActor:
	if preferred >= 0 and preferred < enemies.size() and enemies[preferred].is_alive():
		return enemies[preferred]
	for actor in enemies:
		if actor.is_alive():
			return actor
	return null


func _shift_toward_center(amount: int) -> void:
	if balance > 0:
		shift_balance(-mini(balance, amount))
	elif balance < 0:
		shift_balance(mini(-balance, amount))


func _has_living(group: Array[BattleActor]) -> bool:
	return _next_living_index(group, -1) >= 0


func _next_living_index(group: Array[BattleActor], after: int) -> int:
	for i in range(after + 1, group.size()):
		if group[i].is_alive():
			return i
	return -1


func _default_outcome() -> StringName:
	if encounter_id.is_empty():
		return &"slain"
	return EncounterCatalog.default_outcome(encounter_id)
