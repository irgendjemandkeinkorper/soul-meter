class_name KitAI
extends RefCounted
## The class-kit enemy AI (combat polish, owner ruling 2026-11-02: "you lead 5, AI runs 5"). An
## enemy built from a PartyMember (a person of a class, not a creature row) fights with that
## class's kit: its class commands, the spells in its own tones, and the common arms. Every
## option is checked through `CombatController.query_action_for`, the same gates the player's
## bar runs, so the AI can only do what a player of that class could.
##
## One call plans one step of a turn: act now, walk (into reach, or toward the nearest foe),
## or pass. The controller executes it and asks again while the actor still has AP.
##
## Every value below is PROVISIONAL (balance pass pending): expected damage from the forecast
## the player sees, plus small fixed weights for effects the forecast does not price.

## A status effect riding a hit (Burning, Blinded, a pull...): worth this many HP of damage.
const PROVISIONAL_EFFECT_VALUE := 3.0
## A hit forecast to drop the target outright.
const PROVISIONAL_KILL_VALUE := 5.0
## A class command that is allowed now, once per turn.
const PROVISIONAL_COMMAND_VALUE := 3.5
## Per foe / per friend standing in a cell working's cells.
const PROVISIONAL_CELL_FOE_VALUE := 6.0
const PROVISIONAL_CELL_FRIEND_COST := 8.0
## Breath restored to a friend who is low on it, per point (capped at the action's fill).
const PROVISIONAL_BREATH_VALUE := 0.8
const PROVISIONAL_GUARD_VALUE := 0.5
## Kinds the AI never plans: walking is planned separately, PASS-without-command and
## RESOLUTION are not abilities, a loadout CAST and a Defining Strike need choices the kit
## does not author (a loadout, a named weakness).
const _NEVER: Array[CombatAction.Kind] = [
	CombatAction.Kind.MOVE, CombatAction.Kind.RESOLUTION, CombatAction.Kind.CAST,
	CombatAction.Kind.DEFINING_STRIKE,
]


## True for an enemy this AI runs: a combatant built from a roster member.
static func runs(actor: BattleActor) -> bool:
	return actor != null and actor.source_member != null


## One step: `{kind: "act", action, target, options}`, `{kind: "move", destination}`, or
## `{kind: "pass"}`. `used_commands` lists the class commands already used this turn.
static func plan_step(controller: CombatController, actor: BattleActor, used_commands: Array = []) -> Dictionary:
	var kit := kit_actions(actor)
	var foes := _living(controller.foes_of(actor))
	if foes.is_empty():
		return {"kind": "pass"}
	var best := {}
	for action: CombatAction in kit:
		if used_commands.has(action.id):
			continue
		for candidate: Dictionary in _candidates(controller, actor, action, foes):
			var target := candidate.get("target") as BattleActor
			var options: Dictionary = candidate.get("options", {})
			var gate := controller.query_action_for(actor, action, target, options)
			if not bool(gate.get("allowed", false)):
				continue
			var value := _value(controller, actor, action, target, options)
			if value <= 0.0:
				continue
			best = _better(best, {"kind": "act", "action": action, "target": target, "options": options, "value": value})
	if not best.is_empty() and float(best["value"]) > PROVISIONAL_GUARD_VALUE:
		return best
	var walk := _walk_in(controller, actor, kit, foes)
	if not walk.is_empty():
		return walk
	var advance := _advance(controller, actor, foes)
	if not advance.is_empty():
		return advance
	# Nothing to hit and nowhere closer to stand: brace if the kit can, else pass.
	if not best.is_empty():
		return best
	return {"kind": "pass"}


## The actions a member of this class fights with: class commands, own-tone spells, the
## common arms (KitPreview's groups, so the AI and the CALLING tab agree). Spells in other
## tones are open to every class today (owner item 27), but a Flamebinder that fights with
## Flamebinder spells reads as its class; tier workings need the party's Var Harmony.
static func kit_actions(actor: BattleActor) -> Array[CombatAction]:
	var kit: Array[CombatAction] = []
	if actor == null or actor.source_member == null:
		return kit
	var groups := KitPreview.for_member(actor.source_member)
	for group: StringName in [KitPreview.CLASS, KitPreview.TONES, KitPreview.COMMON]:
		for entry: Dictionary in groups[group]:
			var action := entry["action"] as CombatAction
			if _NEVER.has(action.kind) or KitPreview.tier_of(action) > 0:
				continue
			if not str(entry["lock"]).is_empty():
				continue
			if bool(action.effect_payload.get("contract_target", false)):
				continue
			kit.append(action)
	return kit


## Who or where an action could be aimed this step.
static func _candidates(
	controller: CombatController, actor: BattleActor, action: CombatAction, foes: Array[BattleActor]
) -> Array[Dictionary]:
	var out: Array[Dictionary] = []
	if action.targets_cells():
		for foe: BattleActor in foes:
			for cells: Array[Vector2i] in _cell_patterns(controller, actor, action, foe):
				out.append({"target": null, "options": {"cells": FireField.cells_to_data(cells)}})
		return out
	if action.target_profile == &"self":
		out.append({"target": null, "options": {}})
		return out
	if action.requires_ally_target():
		for friend: BattleActor in _living(controller.friends_of(actor)):
			out.append({"target": friend, "options": {}})
		return out
	if action.targets_any_side():
		for creature: BattleActor in _living(controller.friends_of(actor)) + foes:
			out.append({"target": creature, "options": {}})
		return out
	for foe: BattleActor in foes:
		out.append({"target": foe, "options": {}})
	if action.target_profile == &"encounter":
		out.append({"target": null, "options": {}})
	return out


static func _value(
	controller: CombatController, actor: BattleActor, action: CombatAction, target: BattleActor, options: Dictionary
) -> float:
	if not action.class_resource_action.is_empty():
		return PROVISIONAL_COMMAND_VALUE
	if action.targets_cells():
		return _cell_value(controller, actor, options)
	var foe := target != null and controller.foes_of(actor).has(target)
	if action.kind == CombatAction.Kind.GUARD:
		return PROVISIONAL_GUARD_VALUE
	if action.kind != CombatAction.Kind.ATTACK:
		return 0.0
	if foe:
		var value := controller.attack_value(actor, target, action, options)
		if value < 0.0:
			return 0.0
		if not action.effect_id.is_empty():
			value += PROVISIONAL_EFFECT_VALUE
		var context := controller.forecast_context(actor, target, action, options)
		if not context.is_empty() and controller.forecast_damage_on_hit(context, target) >= target.hp:
			value += PROVISIONAL_KILL_VALUE
		return value
	# A friendly working: worth it only when the friend needs what it gives.
	if target == null:
		return 0.0
	if action.effect_id in [&"second_breath", &"opened_sluice"]:
		var room := controller.breath_room(target)
		return float(mini(room, 6)) * PROVISIONAL_BREATH_VALUE if room >= 4 else 0.0
	if action.effect_id == &"douse":
		return PROVISIONAL_EFFECT_VALUE if FireField.is_burning(target) else 0.0
	if action.effect_id == &"veil":
		return PROVISIONAL_EFFECT_VALUE if target.hp * 5 < target.max_hp * 3 else 0.0
	return 0.0


static func _cell_value(controller: CombatController, actor: BattleActor, options: Dictionary) -> float:
	var cells := FireField.cells_from_data(options.get("cells", []))
	var value := 0.0
	for foe: BattleActor in _living(controller.foes_of(actor)):
		if cells.has(controller.battlefield.cell_of(foe)):
			value += PROVISIONAL_CELL_FOE_VALUE
	for friend: BattleActor in _living(controller.friends_of(actor)):
		if cells.has(controller.battlefield.cell_of(friend)):
			value -= PROVISIONAL_CELL_FRIEND_COST
	return value


## Cell sets around a foe for a working of `cell_count` cells, legal-looking first: a cluster
## on the foe, then a row and a column through it. The controller's own gate decides.
static func _cell_patterns(
	controller: CombatController, _actor: BattleActor, action: CombatAction, foe: BattleActor
) -> Array[Array]:
	var patterns: Array[Array] = []
	var center: Variant = controller.battlefield.cell_of(foe)
	if not (center is Vector2i):
		return patterns
	var at := center as Vector2i
	var count := maxi(1, int(action.effect_payload.get("cell_count", 3)))
	var cluster: Array[Vector2i] = [at]
	for ring: int in range(1, 3):
		for dy: int in range(-ring, ring + 1):
			for dx: int in range(-ring, ring + 1):
				if maxi(absi(dx), absi(dy)) == ring and cluster.size() < count:
					cluster.append(at + Vector2i(dx, dy))
	patterns.append(cluster)
	for axis: Vector2i in [Vector2i(1, 0), Vector2i(0, 1)]:
		var line: Array[Vector2i] = [at]
		var step := 1
		while line.size() < count:
			line.append(at + axis * step)
			if line.size() < count:
				line.append(at - axis * step)
			step += 1
		patterns.append(line)
	return patterns


## Walk into reach for the strongest creature action on the nearest foes: the cheapest legal
## walk-in order (the same planner the player's click uses).
static func _walk_in(
	controller: CombatController, actor: BattleActor, kit: Array[CombatAction], foes: Array[BattleActor]
) -> Dictionary:
	var nearest := _by_distance(controller, actor, foes).slice(0, 2)
	var best := {}
	for action: CombatAction in kit:
		if action.kind != CombatAction.Kind.ATTACK or action.targets_cells() or action.requires_ally_target():
			continue
		for foe: BattleActor in nearest:
			var plan := controller.approach_plan(actor, action, foe)
			if not bool(plan.get("allowed", false)):
				continue
			var entry := {"kind": "move", "destination": plan["destination"], "total_ap": int(plan["total_ap"]), "key": "%s|%s" % [foe.combat_id, action.id]}
			if best.is_empty() or int(entry["total_ap"]) < int(best["total_ap"]) \
					or (int(entry["total_ap"]) == int(best["total_ap"]) and str(entry["key"]) < str(best["key"])):
				best = entry
	return best


## Close on the nearest foe as far as the AP allows, when no walk-in order is affordable.
static func _advance(controller: CombatController, actor: BattleActor, foes: Array[BattleActor]) -> Dictionary:
	var here: Variant = controller.battlefield.cell_of(actor)
	if not (here is Vector2i):
		return {}
	var start := _distance_to_nearest(controller, here as Vector2i, foes)
	var best := {}
	var best_distance := start
	for row: Dictionary in controller.reachable_for(actor):
		var described: Dictionary = controller.battlefield.describe_position(StringName(row["destination"]))
		if not described.has("cell"):
			continue
		var distance := _distance_to_nearest(controller, described["cell"] as Vector2i, foes)
		if distance < best_distance or (distance == best_distance and not best.is_empty() and (
			int(row["ap_cost"]) < int(best["ap_cost"])
			or (int(row["ap_cost"]) == int(best["ap_cost"]) and String(row["destination"]) < String(best["destination"]))
		)):
			if distance < start:
				best = row
				best_distance = distance
	if best.is_empty():
		return {}
	return {"kind": "move", "destination": best["destination"]}


static func _distance_to_nearest(controller: CombatController, cell: Vector2i, foes: Array[BattleActor]) -> int:
	var nearest := 1 << 30
	for foe: BattleActor in foes:
		var at: Variant = controller.battlefield.cell_of(foe)
		if at is Vector2i:
			var delta: Vector2i = (at as Vector2i) - cell
			nearest = mini(nearest, maxi(absi(delta.x), absi(delta.y)))
	return nearest


static func _distance_between(controller: CombatController, cell: Vector2i, other: BattleActor) -> int:
	var at: Variant = controller.battlefield.cell_of(other)
	if not (at is Vector2i):
		return 1 << 30
	var delta: Vector2i = (at as Vector2i) - cell
	return maxi(absi(delta.x), absi(delta.y))


static func _by_distance(controller: CombatController, actor: BattleActor, foes: Array[BattleActor]) -> Array[BattleActor]:
	var here: Variant = controller.battlefield.cell_of(actor)
	var sorted := foes.duplicate()
	if not (here is Vector2i):
		return sorted
	sorted.sort_custom(func(a: BattleActor, b: BattleActor) -> bool:
		var da := _distance_between(controller, here as Vector2i, a)
		var db := _distance_between(controller, here as Vector2i, b)
		return da < db if da != db else String(a.combat_id) < String(b.combat_id)
	)
	return sorted


## Higher value; then cheaper AP; then action id, then target id (deterministic).
## AP round economy: AP is the shipped scheduler (Gate T-10), so `ap_cost` is the live price.
static func _better(current: Dictionary, entry: Dictionary) -> Dictionary:
	if current.is_empty():
		return entry
	var cv := float(current["value"])
	var ev := float(entry["value"])
	if absf(ev - cv) > 0.001:
		return entry if ev > cv else current
	var ca := (current["action"] as CombatAction).ap_cost
	var ea := (entry["action"] as CombatAction).ap_cost
	if ea != ca:
		return entry if ea < ca else current
	var ck := "%s|%s" % [(current["action"] as CombatAction).id, _id_of(current.get("target"))]
	var ek := "%s|%s" % [(entry["action"] as CombatAction).id, _id_of(entry.get("target"))]
	return entry if ek < ck else current


static func _id_of(value: Variant) -> String:
	return String((value as BattleActor).combat_id) if value is BattleActor else ""


static func _living(group: Array[BattleActor]) -> Array[BattleActor]:
	var out: Array[BattleActor] = []
	for actor: BattleActor in group:
		if actor != null and actor.is_alive():
			out.append(actor)
	return out
