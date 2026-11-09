extends RefCounted
## #603 measurement-only reader of the existing combat boundary. Never installed in Battle.
## Full = existing intent + movement search for every hostile on each refresh.
## Cached = revision cache, cheap distant intents, full imminent/revealed intents.
## Fallback = only the first PROVISIONAL 24 speculative planners; CT membership is untouched.

const PROVISIONAL_PRIORITY_DEPTH := 8
const PROVISIONAL_NEAR_DISTANCE := 6
const PROVISIONAL_FALLBACK := 24

var _controller: CombatController
var _variant := ""
var _revision := 0
var _cache: Dictionary = {}
var decision_ms: Array[float] = []


func configure(controller: CombatController, variant: String) -> void:
	_controller = controller
	_variant = variant
	_controller.event_emitted.connect(_invalidate)


func dispose() -> void:
	if _controller != null and _controller.event_emitted.is_connected(_invalidate):
		_controller.event_emitted.disconnect(_invalidate)
	_controller = null
	_cache.clear()


func _invalidate(_event: CombatEvent) -> void:
	# Conservative: any combat event dirties speculative work. No stale plan is executable.
	_revision += 1


func refresh() -> Dictionary:
	var priority: Dictionary = {}
	if _variant == "cached":
		for row: Dictionary in _controller.scheduler.peek_order(PROVISIONAL_PRIORITY_DEPTH):
			var actor := row.get("actor") as BattleActor
			if actor != null:
				priority[actor.combat_id] = true
	var ct: Dictionary = _controller.scheduler.to_dict().get("charge", {})
	var ct_hostiles := 0
	var planned := 0
	var detailed := 0
	var hits := 0
	var plans: Dictionary = {}
	for enemy: BattleActor in _controller.enemies:
		if not enemy.is_alive():
			continue
		if ct.has(String(enemy.combat_id)):
			ct_hostiles += 1
		if _variant == "fallback24" and planned >= PROVISIONAL_FALLBACK:
			continue
		var full := _variant != "cached" or priority.has(enemy.combat_id) \
			or _controller.is_intent_locked(enemy.combat_id) or _near_party(enemy)
		var cached: Dictionary = _cache.get(enemy.combat_id, {})
		var plan: Dictionary
		if _variant == "cached" and int(cached.get("revision", -1)) == _revision \
				and bool(cached.get("full", false)) == full:
			plan = cached["plan"]
			hits += 1
		else:
			var started := Time.get_ticks_usec()
			plan = _full_plan(enemy) if full else _controller.plan_enemy_turn(enemy)
			decision_ms.append(float(Time.get_ticks_usec() - started) / 1000.0)
			_cache[enemy.combat_id] = {"revision": _revision, "full": full, "plan": plan}
		plans[String(enemy.combat_id)] = plan
		planned += 1
		if full:
			detailed += 1
	return {
		"ct_hostiles": ct_hostiles, "planned_hostiles": planned,
		"detailed_hostiles": detailed, "cheap_hostiles": planned - detailed,
		"cache_hits": hits, "revision": _revision, "plans": plans,
	}


func plan_for_decision(enemy: BattleActor) -> Dictionary:
	# This seam is exercised by the fixture, never substituted into shipped combat.
	# Fresh at consumption even if a caller mutated a fixture without emitting an event.
	return _full_plan(enemy)


func _full_plan(enemy: BattleActor) -> Dictionary:
	var plan := _controller.plan_enemy_turn(enemy)
	if str(plan.get("kind", "")) == "advance":
		var target := _controller.actor_by_id(StringName(str(plan.get("target_id", ""))))
		if target != null:
			# Reuse the existing movement search; do not invent a second tactical scoring model.
			plan["destination"] = String(_controller._best_enemy_position(enemy, target))
	return plan


func _near_party(enemy: BattleActor) -> bool:
	var board := _controller.battlefield
	var origin := board.describe_position(board.position_of(enemy))
	if not origin.has("cell"):
		return true
	for ally: BattleActor in _controller.allies:
		if not ally.is_alive():
			continue
		var destination := board.describe_position(board.position_of(ally))
		if destination.has("cell") and GridMetric.distance(origin["cell"], destination["cell"]) \
				<= PROVISIONAL_NEAR_DISTANCE:
			return true
	return false
