class_name DisciplineProfile
extends RefCounted
## What a Combat Discipline does in a fight (calling and measures S4,
## docs/design/calling-and-measures-2026-11-25.md). Canon (dramgid-vault
## systems/ten-patron-classes.md §Combat Disciplines): a Discipline governs movement, reach,
## elevation and baseline verbs; it never touches Gauge, fizzle or a signature Resource, and a
## Patron never sets movement cost or elevation.
##
## PROVISIONAL — no Discipline number is ratified (#132; owner-decisions item 51). Each effect
## rides a seam combat already has, so the whole layer is this table:
##   Chordblade  footwork: every path costs `move_cost_percent` less (the mirror of a leg injury).
##   Thamshaper  footing: holding the higher ground is worth `height_hit_pp` more to hit, and a foe
##               attacking up at a Thamshaper pays the same.
##   Hushwarden  stillness: cells within `hush_radius` of a standing warden are hushed — no tile
##               charges or feeds a Song there (TileState.hush). The fizzle tax canon also gives
##               the field waits on who it taxes (owner question), so it is not built.
## A unit without a member Discipline (enemies, authored companions) has none of these.

const PROVISIONAL := {
	"chordblade": {"move_cost_percent": -20},
	"thamshaper": {"height_hit_pp": 4},
	"hushwarden": {"hush_radius": 1},
}


static func of(actor: BattleActor) -> String:
	if actor == null or actor.source_member == null:
		return ""
	var id := actor.source_member.discipline.to_lower()
	return id if PROVISIONAL.has(id) else ""


static func _number(actor: BattleActor, key: String) -> int:
	return int((PROVISIONAL.get(of(actor), {}) as Dictionary).get(key, 0))


## Rows in the same shape as CombatInjury.move_cost_modifiers(), so the move quote lists both.
static func move_cost_modifiers(actor: BattleActor) -> Array[Dictionary]:
	var result: Array[Dictionary] = []
	var percent := _number(actor, "move_cost_percent")
	if percent != 0:
		result.append({"id": "discipline", "label": "%s footwork" % _name(actor), "percent": percent})
	return result


## The Thamshaper's footing term for one attack, as an accuracy modifier row; {} when neither
## side's Discipline speaks to this height difference. `height_steps` is signed, attacker-up > 0.
static func footing_modifiers(attacker: BattleActor, target: BattleActor, height_steps: int) -> Array[Dictionary]:
	var result: Array[Dictionary] = []
	if height_steps > 0 and _number(attacker, "height_hit_pp") != 0:
		result.append({"id": "discipline", "label": "%s footing" % _name(attacker),
			"percentage_points": _number(attacker, "height_hit_pp")})
	if height_steps < 0 and _number(target, "height_hit_pp") != 0:
		result.append({"id": "discipline", "label": "%s footing (target)" % _name(target),
			"percentage_points": -_number(target, "height_hit_pp")})
	return result


static func hush_radius(actor: BattleActor) -> int:
	return _number(actor, "hush_radius")


## True when `cell` lies inside any standing warden's field among `actors`.
static func is_hushed(cell: Vector2i, actors: Array[BattleActor], battlefield: Object) -> bool:
	for actor: BattleActor in actors:
		var radius := hush_radius(actor)
		if radius <= 0 or not actor.is_alive():
			continue
		var at: Variant = battlefield.call("cell_of", actor)
		if at is Vector2i and GridMetric.distance(at as Vector2i, cell) <= radius:
			return true
	return false


## One line for chargen and the sheet: what the Discipline does in a fight.
static func summary(discipline_id: String) -> String:
	var row: Dictionary = PROVISIONAL.get(discipline_id, {})
	match discipline_id:
		"chordblade":
			return "In a fight: every path costs %d%% less." % -int(row["move_cost_percent"])
		"thamshaper":
			return "In a fight: +%d%% to hit from higher ground, and a foe below pays %d%%." % [
				int(row["height_hit_pp"]), int(row["height_hit_pp"])]
		"hushwarden":
			return "In a fight: cells within %d of you are hushed — no tile charges or feeds a Song there." % int(row["hush_radius"])
	return ""


static func _name(actor: BattleActor) -> String:
	return of(actor).capitalize()
