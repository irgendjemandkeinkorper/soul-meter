class_name Resolution
extends RefCounted

## Deterministic combat resolution shared by forecast, replay, AI, and execution.
##
## This object never applies its returned writes. Callers may show them as a forecast or apply
## them later; both consumers receive the result of this one function. All inputs and outputs are
## plain dictionaries so they can be copied into saves and action logs without scene-tree state.


static func resolve(context: Dictionary) -> Dictionary:
	var unit: Dictionary = _dictionary(context.get("unit", {}))
	var ability: Dictionary = _dictionary(context.get("ability", {}))
	var target: Dictionary = _dictionary(context.get("target", {}))
	if ability.is_empty():
		return _blocked(&"ability", "Unknown combat ability.", {"type": "known_ability"})

	var ability_id := str(ability.get("id", ""))
	var element_id := ElementWheel.normalize(ability.get("element_id", ""))
	if ElementsData.element(element_id).id.is_empty():
		return _blocked(
			&"unknown_element",
			"Ability %s has an element that is not on the Wheel." % ability_id,
			{"type": "known_element", "element_id": String(element_id)}
		)

	var elements := _ability_elements(ability, element_id)
	var magnitude := ElementWheel.normalize(ability.get("magnitude", &"note"))
	# Composition is resolved without caster state so it cannot fall back to an autoload. The
	# casting gate is then queried explicitly with the caller-provided, data-only context.
	var composition := CompositionResolver.resolve(elements, magnitude)
	if not composition.is_resolved():
		return _blocked(
			composition.failure_id,
			"Ability %s has an invalid element composition." % ability_id,
			{"type": "valid_composition"}
		)

	var caster_context: Dictionary = _dictionary(context.get("caster_context", {})).duplicate(true)
	var harmony := int(unit.get("harmony", caster_context.get("harmony", 0)))
	var casting_gate := CastingGate.query(composition, harmony, caster_context)
	if not bool(casting_gate.get("allowed", false)):
		return _blocked(
			StringName(casting_gate.get("blocked_by", &"casting_gate")),
			str(casting_gate.get("message", "The ability cannot be cast.")),
			_dictionary(casting_gate.get("nearest_unblock", {}))
		)

	var weather := Weather.from_dict(_dictionary(context.get("weather", {})))
	var source_tile_data: Dictionary = _dictionary(context.get("source_tile", {}))
	var target_tile_data: Dictionary = _dictionary(context.get("target_tile", {}))
	var source_tile := TileState.from_dict(source_tile_data)
	var target_tile := TileState.from_dict(target_tile_data)
	if weather.weather_hush:
		# Weather owns global Hush; TileState owns the actual suppression rules. Applying Hush to
		# these private clones reuses those rules without mutating or reimplementing either object.
		source_tile.hush = true
		target_tile.hush = true

	var target_element := ElementWheel.normalize(target.get("element_id", ""))
	var wheel_distance := ElementWheel.distance(element_id, target_element)
	var relation := ElementMatrix.relation(element_id, target_element)
	var matrix_multiplier := float(
		ability.get("matrix_multiplier", ElementMatrix.damage_multiplier(element_id, target_element))
	)
	var facing: Dictionary = _dictionary(context.get("facing", {}))
	var facing_multiplier := float(facing.get("multiplier", 1.0))
	var tile_multiplier := source_tile.action_multiplier(element_id)
	var power := maxi(int(ability.get("power", 0)), 0)
	var attack_scale := maxf(float(unit.get("attack_scale", 1.0)), 0.0)

	var breakdown: Array[Dictionary] = [
		_step("power", "Power", float(power)),
		_step("attack_scale", "Attack scale", attack_scale),
		_step("element_matrix", "Element matrix: %s" % String(relation), matrix_multiplier),
		_step("facing", "Facing: %s" % str(facing.get("id", "neutral")), facing_multiplier),
		_step("tile_charge", "Source tile charge", tile_multiplier),
	]
	var scaled_damage := float(power) * attack_scale * matrix_multiplier
	scaled_damage *= facing_multiplier
	scaled_damage *= tile_multiplier

	var target_strike := target_tile.strike(element_id)
	if not bool(target_strike.get("allowed", false)):
		return _blocked(
			StringName(target_strike.get("blocked_by", &"tile_state")),
			str(target_strike.get("message", "The target tile rejects this strike.")),
			_dictionary(target_strike.get("nearest_unblock", {}))
		)
	var detonation_bonus := int(target_strike.get("bonus_damage", 0))
	if detonation_bonus != 0:
		breakdown.append(_step("detonation", "Target tile detonation", float(detonation_bonus), "add"))
	var damage := maxi(roundi(scaled_damage) + detonation_bonus, 0)

	var writes: Array[Dictionary] = []
	var hp_before := maxi(int(target.get("hp", 0)), 0)
	var hp_after := maxi(hp_before - damage, 0)
	writes.append({
		"kind": "hp",
		"target_id": str(target.get("id", "")),
		"before": hp_before,
		"after": hp_after,
		"delta": hp_after - hp_before,
	})

	if not source_tile_data.is_empty():
		var source_before := source_tile_data.duplicate(true)
		var residue := source_tile.apply_residue(element_id)
		if not bool(residue.get("allowed", false)):
			return _blocked(
				StringName(residue.get("blocked_by", &"tile_state")),
				str(residue.get("message", "The source tile rejects residue.")),
				_dictionary(residue.get("nearest_unblock", {}))
			)
		var source_after := source_tile.to_dict()
		if source_before != source_after:
			writes.append(_tile_write("residue", source_before, source_after))

	if not target_tile_data.is_empty():
		var target_after := target_tile.to_dict()
		if target_tile_data != target_after:
			writes.append(_tile_write("detonation", target_tile_data, target_after))

	# TODO(#193): Wait-action CT cost is an owner decision. Only an explicit authored cost is used;
	# absent data is the conservative no-op.
	var ct_cost := maxi(int(ability.get("ct_cost", 0)), 0)
	if unit.has("ct") and ct_cost > 0:
		var ct_before := int(unit.get("ct", 0))
		writes.append({
			"kind": "ct",
			"target_id": str(unit.get("id", "")),
			"before": ct_before,
			"after": maxi(ct_before - ct_cost, 0),
			"delta": -mini(ct_cost, maxi(ct_before, 0)),
		})

	# TODO(#195): Flag semantics are unanswered; flags are carried by neither calculations nor writes.
	# TODO(#189): Reroll persistence is unanswered; resolution is deterministic and performs no rerolls.
	# TODO(#132): Discipline effects are unanswered; they conservatively contribute no modifier.
	var result := {
		"allowed": true,
		"blocked_by": "",
		"nearest_unblock": {},
		"message": "",
		"battle_id": str(context.get("battle_id", "")),
		"tick": int(context.get("tick", 0)),
		"seed": int(context.get("seed", 0)),
		"ability_id": ability_id,
		"damage": damage,
		"breakdown": breakdown,
		"element_relationship": {
			"attack_element": String(element_id),
			"defend_element": String(target_element),
			"distance": wheel_distance,
			"relation": String(relation),
		},
		"composition": composition.to_dict(),
		"casting_gate": casting_gate.duplicate(true),
		"writes": writes,
	}
	result["action_log"] = {
		"battle_id": result["battle_id"],
		"tick": result["tick"],
		"seed": result["seed"],
		"deltas": writes.duplicate(true),
	}
	return result


## Compatibility with issue #142's four-argument API. It only adapts data into [method resolve];
## no second forecast/resolution implementation exists.
static func resolve_action(
	battle_unit: Dictionary, ability: Dictionary, target_tile: Dictionary, seed: int
) -> Dictionary:
	return resolve({
		"battle_id": str(battle_unit.get("battle_id", target_tile.get("battle_id", ""))),
		"tick": int(battle_unit.get("tick", 0)),
		"seed": seed,
		"unit": battle_unit,
		"ability": ability,
		"target": _dictionary(target_tile.get("target", target_tile.get("unit", {}))),
		"source_tile": _dictionary(battle_unit.get("tile_state", {})),
		"target_tile": _dictionary(target_tile.get("tile_state", target_tile)),
		"weather": _dictionary(battle_unit.get("weather", {})),
		"facing": _dictionary(target_tile.get("facing", {})),
		"caster_context": _dictionary(battle_unit.get("caster_context", {})),
	})


static func _ability_elements(ability: Dictionary, fallback: StringName) -> Array[StringName]:
	var result: Array[StringName] = []
	var authored: Variant = ability.get("elements", [])
	if authored is Array:
		for element: Variant in authored:
			result.append(ElementWheel.normalize(element))
	if result.is_empty():
		result.append(fallback)
	return result


static func _step(id: String, label: String, value: float, operation: String = "multiply") -> Dictionary:
	return {"id": id, "label": label, "operation": operation, "value": value}


static func _tile_write(operation: String, before: Dictionary, after: Dictionary) -> Dictionary:
	return {
		"kind": "tile_state",
		"operation": operation,
		"battle_id": str(after.get("battle_id", before.get("battle_id", ""))),
		"x": int(after.get("x", before.get("x", 0))),
		"y": int(after.get("y", before.get("y", 0))),
		"before": before.duplicate(true),
		"after": after.duplicate(true),
	}


static func _dictionary(value: Variant) -> Dictionary:
	return value if value is Dictionary else {}


static func _blocked(
	blocked_by: StringName, message: String, nearest_unblock: Dictionary
) -> Dictionary:
	return {
		"allowed": false,
		"blocked_by": String(blocked_by),
		"nearest_unblock": nearest_unblock.duplicate(true),
		"message": message,
	}
