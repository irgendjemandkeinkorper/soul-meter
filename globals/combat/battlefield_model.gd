class_name BattlefieldModel
extends RefCounted
## Positioning interface consumed by CombatController. Action resolution only
## speaks these opaque position/profile/shape APIs, so a grid can replace zones.


## FR-105a seam (architecture doc §1.5). `use_grid_battlefield` selects the global
## default; `Battle` may instead supply a grid model for an encounter that authors
## grid data. Encounters without that data still use this factory unchanged.
static func create_default(rules: CombatRules) -> BattlefieldModel:
	const ZONE_PATH := "res://globals/combat/zone_battlefield_model.gd"
	const GRID_PATH := "res://globals/combat/grid_battlefield_model.gd"
	var path := ZONE_PATH
	if rules != null and rules.use_grid_battlefield:
		path = GRID_PATH
	var script := load(path) as Script
	# The grid model does not exist yet (issue #137). Until it lands, flipping
	# `use_grid_battlefield` would otherwise load null and crash on `.new()`.
	# Fall back loudly instead: amendment §8.1 requires the zone model to stay
	# the working fallback, and a fallback that only works in one direction is
	# not a fallback.
	if script == null:
		push_warning(
			"BattlefieldModel: %s is missing; falling back to the zone model." % path
		)
		script = load(ZONE_PATH) as Script
	var model := script.new() as BattlefieldModel
	model.configure(rules)
	return model


func configure(_rules: CombatRules) -> void:
	pass


func setup(_allies: Array[BattleActor], _enemies: Array[BattleActor]) -> void:
	push_error("BattlefieldModel.setup() must be implemented.")


func position_of(_actor: BattleActor) -> StringName:
	return &""


func side_of(_actor: BattleActor) -> StringName:
	return &""


func has_combatant(_actor: BattleActor) -> bool:
	return false


func combatants_on_side(_side: StringName) -> Array[BattleActor]:
	return []


## Places ONE combatant mid-battle at `position` on `side`, the inverse of
## `remove_combatant()`. Same-map combat D5 admits mobs into a running fight, so composition can
## no longer be fixed at `setup()` time. `position` is an opaque handle in this model's own
## vocabulary (the grid model reads `c:x,y,elev`; the zone model reads a zone name).
func admit_combatant(
	_actor: BattleActor, _position: StringName, _side: StringName
) -> Dictionary:
	return _blocked(&"composition", "Positioning model cannot admit combatants.", {})


func remove_combatant(_actor: BattleActor) -> Dictionary:
	return _blocked(&"composition", "Positioning model cannot remove combatants.", {})


func transfer_combatant(_actor: BattleActor, _new_side: StringName) -> Dictionary:
	return _blocked(&"composition", "Positioning model cannot transfer combatants.", {})


func move(_actor: BattleActor, _destination: StringName) -> Dictionary:
	return _blocked(&"position", "Positioning model does not support movement.", {})


func move_query(_actor: BattleActor, _destination: StringName) -> Dictionary:
	return _blocked(&"position", "Positioning model does not support movement.", {})


func target_query(
	_actor: BattleActor, _target: BattleActor, _profile: StringName
) -> Dictionary:
	return _blocked(&"target", "Positioning model does not support targeting.", {})


func cover_bonus(_actor: BattleActor, _target: BattleActor) -> int:
	return 0


## Cover granted to a combatant hypothetically standing at an opaque position. Positional AI
## uses this query without learning a concrete model's geometry or handle representation.
func cover_bonus_at(_attacker: BattleActor, _target_position: StringName) -> int:
	return 0


func set_cover(_cell: Vector2i, _grants_cover: bool = true) -> void:
	pass


## Authors a solid obstacle that blocks line of fire without changing elevation or passability
## semantics elsewhere. Models without cells ignore it.
func set_obstacle(_cell: Vector2i, _blocks_fire: bool = true) -> void:
	pass


## Authored physical visibility of a cell: &"clear", &"dim" or &"obscured". Purely physical
## (light, smoke, fog); elemental Weather, Witness Light and Shroud never write it.
func set_visibility(_cell: Vector2i, _level: StringName) -> Dictionary:
	return _blocked(&"position", "This battlefield has no cells to author.", {"type": &"cells"})


func visibility_at(_cell: Vector2i) -> StringName:
	return &"clear"


## One composed physical visibility result for a shot from `actor` at `target`:
## `{level, causes: [{cell, level}]}`. Overlapping causes compose as the WORST level, never a
## sum, so the same loss of sight is never counted twice. Cell-less models are always clear.
func visibility_between(_actor: BattleActor, _target: BattleActor) -> Dictionary:
	return {"level": &"clear", "causes": []}


## Whether low cover between `actor` and `target` hides the target's cover-hidden anatomy:
## `{covered: bool, cell: Vector2i (when covered), seen_over: bool}`. Only the grid model has
## the geometry; zones report no cover so every authored location stays exposed.
func location_cover(_actor: BattleActor, _target: BattleActor) -> Dictionary:
	return {"covered": false, "seen_over": false}


func flank_bonus(_actor: BattleActor, _target: BattleActor) -> int:
	return 0


func targets_for(
	_actor: BattleActor, _primary: BattleActor, _shape: StringName
) -> Array[BattleActor]:
	return []


## Presentation snapshot of the static terrain, one Dictionary per cell
## ({x, y, height_delta, cliff}), consumed by CombatEvent snapshots for the
## battle-interface stage region. Models without cells report none.
func tiles_snapshot() -> Array[Dictionary]:
	return []


## What this model can express. A consumer branches on capabilities, never on
## type — no `is_grid()`. The zone model reports each spatial capability as
## false and stays fully functional (architecture doc §1.3-1.4).
func capabilities() -> Dictionary:
	return {
		"cells": false,
		"elevation": false,
		"facing": false,
		"occupancy": false,
		"line_of_sight": false,
		"path_cost": false,
	}


## Structured description of an opaque position handle. A consumer reads only
## the named fields that capabilities() declared for the active model; it must
## never build, split, or pattern-match the handle itself.
func describe_position(_position: StringName) -> Dictionary:
	return {}


## Each position this actor can legally reach with `ct_budget` charge time.
func reachable_positions(_actor: BattleActor, _ct_budget: int) -> Array[StringName]:
	return []


## Path cost in the refusal shape. Adds {"ct_cost": int, "path": Array[StringName]}
## when allowed is true.
func path_query(_actor: BattleActor, _destination: StringName) -> Dictionary:
	return _blocked(&"position", "Positioning model does not support paths.", {})


## Facing. The zone model refuses to set facing; capabilities() declares this.
func facing_of(_actor: BattleActor) -> StringName:
	return &""


func set_facing(_actor: BattleActor, _facing: StringName) -> Dictionary:
	return _blocked(&"facing", "Positioning model does not support facing.", {})


## Line of sight, in the refusal shape. `blocked_by` must separate
## &"blocked_by_elevation" from &"blocked_by_occupancy" from &"blocked_by_range" —
## a single &"no_los" destroys the refusal taxonomy (amendment §2.2, FR-606).
func line_of_sight(_actor: BattleActor, _target: BattleActor) -> Dictionary:
	return _allowed()


## The actor occupying a position, or null.
func occupant_of(_position: StringName) -> BattleActor:
	return null


## Elevation delta, target minus actor. The zone model always returns 0.
func elevation_delta(_actor: BattleActor, _target: BattleActor) -> int:
	return 0


## The cell an actor stands on, or null when this model has no cells or the actor is absent.
## Consumers still branch on `capabilities().cells`; this is a convenience over
## `describe_position(position_of(actor))`, never a second handle format.
func cell_of(_actor: BattleActor) -> Variant:
	return null


## Legality of one cell for area workings, in the refusal shape:
## `{allowed, in_bounds, passable, occupant_id}`. Models without cells refuse.
func cell_query(_cell: Vector2i) -> Dictionary:
	return _blocked(&"position", "Positioning model has no cells.", {"type": &"cells"})


## Forced displacement (a pull or a shove): seats `actor` on `cell` with no path or CT cost.
## The caller has validated the destination; this refuses only what it cannot represent.
func displace(_actor: BattleActor, _cell: Vector2i) -> Dictionary:
	return _blocked(&"position", "Positioning model does not support displacement.", {})


## Line of sight from an actor to a CELL (an area mark), same taxonomy as `line_of_sight()`.
func line_of_sight_to_cell(_actor: BattleActor, _cell: Vector2i) -> Dictionary:
	return _allowed()


## Line of sight between two cells, from a remembered cast position rather than a live actor.
func line_of_sight_between_cells(_from: Vector2i, _to: Vector2i) -> Dictionary:
	return _allowed()


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
