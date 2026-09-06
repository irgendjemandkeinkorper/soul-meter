class_name Resolution
extends RefCounted

## Deterministic combat resolution shared by forecast, replay, AI, and execution.
##
## This object never applies its returned writes. Callers may show them as a forecast or apply
## them later; both consumers receive the result of this one function. All inputs and outputs are
## plain dictionaries so they can be copied into saves and action logs without scene-tree state.

## PROVISIONAL FR-105a BALANCE VALUES (amendment §1.1).
## Keep the complete positional damage/hit table here so the required sweep review can retune it
## without searching through the resolver or battlefield consumers.
const PROVISIONAL_HEIGHT_DAMAGE_PER_STEP := 0.10
const PROVISIONAL_FACING_RULES := {
	&"front": {"damage_multiplier": 1.00, "hit_bonus": 0},
	&"side": {"damage_multiplier": 1.10, "hit_bonus": 8},
	&"back": {"damage_multiplier": 1.25, "hit_bonus": 15},
}
## PROVISIONAL to-hit curve (#169 owner ruling 2026-08-24, sweep candidate B — see
## tools/to_hit_sweep.gd and docs/gate-t2-evidence.md). Applies ONLY when the caller opts in
## via `to_hit_enabled` (grid combat provides positional context; legacy zone combat stays
## auto-hit). hit% = clamp(base + facing hit_bonus + height_mod_per_step * signed steps, lo, hi).
const PROVISIONAL_TO_HIT := {
	"base": 70,
	"height_mod_per_step": 4,
	"edge_mod_per_point": 2,  # owner 2026-08-24: + (attacker Edge - defender Edge) x 2%
	"clamp_lo": 5,
	"clamp_hi": 95,
}


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

	var target_element := ElementWheel.normalize(target.get("element_id", ""))
	var is_spell := bool(ability.get("is_spell", false))
	var fizzle_percent := 0.0
	var fizzle_roll := 0
	var fizzled := false
	var fizzle_overridden := false
	if is_spell:
		fizzle_percent = _fizzle_percent(context, composition, magnitude)
		# Seam v2: a class resource may pin the fizzle chance (Flamebinder's banked failure spends
		# for a guaranteed cast = 0). Same context at forecast and commit, so both see the pin.
		if context.has("fizzle_percent_override"):
			fizzle_percent = clampf(float(context.get("fizzle_percent_override", fizzle_percent)), 0.0, 100.0)
			fizzle_overridden = true
		fizzle_roll = _deterministic_fizzle_roll(context, ability_id, unit, target)
		fizzled = fizzle_roll <= fizzle_percent

	var breath_cost := maxi(int(ability.get("breath_cost", ability.get("mp_cost", 0))), 0)
	var breath_before := maxi(int(unit.get("breath", 0)), 0)
	var breath_spent := mini(breath_cost, breath_before) if is_spell else 0
	var soul_overreach := maxi(breath_cost - breath_spent, 0) if is_spell else 0
	var soul_before := maxf(float(context.get("soul_meter", 0.0)), 0.0)
	if is_spell and soul_before < float(soul_overreach):
		return _blocked(
			&"soul",
			"Requires %d Soul after Breath." % soul_overreach,
			{
				"type": &"soul",
				"minimum": soul_overreach,
				"delta": float(soul_overreach) - soul_before,
			}
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

	var wheel_distance := ElementWheel.distance(element_id, target_element)
	var relation := ElementMatrix.relation(element_id, target_element)
	var matrix_multiplier := float(
		ability.get("matrix_multiplier", ElementMatrix.damage_multiplier(element_id, target_element))
	)
	var facing: Dictionary = _dictionary(context.get("facing", {}))
	var positioning := positional_modifiers(
		int(context.get("height_advantage_steps", 0)),
		StringName(facing.get("id", &"front")),
	)
	var height_multiplier := float(positioning["height_multiplier"])
	var facing_multiplier := float(positioning["facing_multiplier"])
	var hit_bonus := int(positioning["hit_bonus"])
	var tile_multiplier := source_tile.action_multiplier(element_id)
	var to_hit_enabled := bool(context.get("to_hit_enabled", false))
	var signed_height_steps := int(context.get("height_advantage_steps", 0))
	var hit_chance := 100
	var hit_roll := 0
	var hit := true
	if to_hit_enabled:
		var edge_delta := int(unit.get("edge", 0)) - int(target.get("edge", 0))
		hit_chance = clampi(
			int(PROVISIONAL_TO_HIT["base"]) + hit_bonus
				+ int(PROVISIONAL_TO_HIT["height_mod_per_step"]) * signed_height_steps
				+ int(PROVISIONAL_TO_HIT["edge_mod_per_point"]) * edge_delta,
			int(PROVISIONAL_TO_HIT["clamp_lo"]),
			int(PROVISIONAL_TO_HIT["clamp_hi"]),
		)
		if bool(unit.get("hit", false)):
			hit = true
		else:
			hit_roll = _deterministic_hit_roll(context, ability_id, unit, target)
			hit = hit_roll <= hit_chance
	var power := maxi(int(ability.get("power", 0)), 0)
	var attack_scale := maxf(float(unit.get("attack_scale", 1.0)), 0.0)
	var target_aftertones := _aftertones(target.get("aftertones", []))
	var tempo_before := int(unit.get("tempo", 0))
	var tempo_after := tempo_before
	var target_tempo_before := int(target.get("tempo", 0))
	var target_tempo_after := target_tempo_before
	var consumed_aftertone := false
	var target_aftertones_before := target_aftertones.duplicate(true)
	var has_tham_bend := composition.rule_bends.has(&"creates_cover_anchors_aftertones")
	var has_khash_bend := composition.rule_bends.has(&"consumes_aftertone_for_burst")
	var has_zhem_bend := composition.rule_bends.has(&"cancels_and_zeroes_tempo")
	var has_khor_bend := composition.rule_bends.has(&"extends_durations_holds_notes") or composition.elements.has(&"khor")
	# PROVISIONAL R1: every successful elemental cast lays one centre-element Aftertone on the
	# target. The legacy ability keys remain optional overrides for authored exceptions only.
	var lays_aftertone := is_spell and not fizzled
	if ability.has("aftertone") or ability.has("aftertone_element"):
		lays_aftertone = bool(ability.get("aftertone", true)) and not fizzled
	# PROVISIONAL R3: the interim producer tracks the previous successful cast element.
	var previous_element := ElementWheel.normalize(unit.get("last_cast_element", ""))
	if is_spell:
		tempo_after = tempo_before + 1 if not fizzled and previous_element == element_id and previous_element != &"" else 0
	if not fizzled and has_khash_bend:
		for index: int in target_aftertones.size():
			if not bool(target_aftertones[index].get("anchored", false)):
				target_aftertones.remove_at(index)
				consumed_aftertone = true
				power += 1 # PROVISIONAL: absent vault burst magnitude, use +1.
				break
	if not fizzled and composition.triad_effect_id == &"everything_burns_at_once":
		var clearable := _aftertones(unit.get("aftertones", [])).size() + target_aftertones.size()
		power += clearable
	if not fizzled and has_zhem_bend:
		target_aftertones.clear()
		target_tempo_after = 0
	if lays_aftertone:
		var aftertone_element := ElementWheel.normalize(ability.get("aftertone_element", composition.center_element if composition.center_element != &"" else element_id))
		var aftertone_rounds := maxi(int(ability.get("aftertone_rounds", 2)), 1)
		target_aftertones.append({
			"element": aftertone_element,
			"remaining_rounds": aftertone_rounds,
			"held": false,
			"anchored": false,
		})
	if not fizzled and has_tham_bend:
		for aftertone: Dictionary in target_aftertones:
			aftertone["anchored"] = true
	var held_caster_aftertones := _aftertones(unit.get("aftertones", []))
	if not fizzled and has_khor_bend and not held_caster_aftertones.is_empty():
		# PROVISIONAL R2: Khor is caster-side and holds only the caster's most recent laying.
		held_caster_aftertones[held_caster_aftertones.size() - 1]["held"] = true

	var breakdown: Array[Dictionary] = [
		_step("power", "Power", float(power)),
		_step("attack_scale", "Attack scale", attack_scale),
		_step("element_matrix", "Element matrix: %s" % String(relation), matrix_multiplier),
		_step("height", "Height advantage", height_multiplier),
		_step("facing", "Facing: %s" % str(positioning["facing"]), facing_multiplier),
		_step("tile_charge", "Source tile charge", tile_multiplier),
	]
	if not fizzled and composition.triad_effect_id == &"everything_burns_at_once":
		var cinderfall_count := _aftertones(unit.get("aftertones", [])).size() + _aftertones(target.get("aftertones", [])).size()
		if cinderfall_count > 0:
			breakdown.append(_step("cinderfall_burst", "Cinderfall cleared Aftertones", float(cinderfall_count), "add"))
	if consumed_aftertone:
		breakdown.append(_step("aftertone_burst", "Khash Aftertone burst", 1.0, "add"))
	var scaled_damage := float(power) * attack_scale * matrix_multiplier
	scaled_damage *= height_multiplier
	scaled_damage *= facing_multiplier
	scaled_damage *= tile_multiplier

	var target_strike: Dictionary = {"allowed": true, "bonus_damage": 0}
	if not fizzled:
		target_strike = target_tile.strike(element_id)
		if not bool(target_strike.get("allowed", false)):
			return _blocked(
				StringName(target_strike.get("blocked_by", &"tile_state")),
				str(target_strike.get("message", "The target tile rejects this strike.")),
				_dictionary(target_strike.get("nearest_unblock", {}))
			)
	var detonation_bonus := int(target_strike.get("bonus_damage", 0))
	if detonation_bonus != 0:
		breakdown.append(_step("detonation", "Target tile detonation", float(detonation_bonus), "add"))
	if to_hit_enabled:
		breakdown.append(_step(
			"to_hit", "To-hit: %d%% (rolled %d)" % [hit_chance, hit_roll],
			1.0 if hit else 0.0,
		))
	# Seam v2 hidden draw (Stormbearer Attribution): the resource hands over a table and a seed
	# key; the row is drawn from the same deterministic source as the fizzle/hit rolls, so the
	# forecast and the commit draw the same row. The FORECAST PANEL hides it ("?") unless
	# `reveal` is set; the calculation itself is identical either way.
	var hidden_draw := _dictionary(context.get("hidden_draw", {}))
	var draw_result: Dictionary = {}
	var draw_bonus := 0
	if not hidden_draw.is_empty() and not fizzled and hit:
		var rows: Array = hidden_draw.get("rows", []) if hidden_draw.get("rows") is Array else []
		if not rows.is_empty():
			var draw_roll := _deterministic_draw_roll(
				context, ability_id, unit, target, str(hidden_draw.get("seed_key", ""))
			)
			var row := _dictionary(rows[(draw_roll - 1) % rows.size()])
			draw_bonus = int(row.get("bonus_damage", 0))
			draw_result = {
				"table_id": str(hidden_draw.get("table_id", "")),
				"seed_key": str(hidden_draw.get("seed_key", "")),
				"roll": draw_roll,
				"row_id": str(row.get("id", "")),
				"row": row.duplicate(true),
			}
			breakdown.append(_step("hidden_draw", "Hidden draw: %s" % str(row.get("id", "?")), float(draw_bonus), "add"))
	var damage := maxi(roundi(scaled_damage) + detonation_bonus + draw_bonus, 0)
	if fizzled:
		hit = false
		damage = 0
	elif not hit:
		# A miss still pays CT and still leaves source residue (the cast happened), but deals
		# no damage and does not detonate the target tile.
		damage = 0

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
		var working_element := (
			composition.center_element if composition.center_element != &"" else element_id
		)
		# PROVISIONAL (#215): fizzle leaves the same +1 charge as a landed cast, but in the
		# Wheel-opposite element. The owner has not ratified a different residue amount.
		var residue_element := ElementWheel.opposite(working_element) if fizzled else working_element
		var residue := source_tile.apply_residue(residue_element)
		if not bool(residue.get("allowed", false)):
			return _blocked(
				StringName(residue.get("blocked_by", &"tile_state")),
				str(residue.get("message", "The source tile rejects residue.")),
				_dictionary(residue.get("nearest_unblock", {}))
			)
		var source_after := source_tile.to_dict()
		if source_before != source_after:
			writes.append(_tile_write("residue", source_before, source_after))

	if hit and not target_tile_data.is_empty():
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

	if is_spell and breath_cost > 0:
		writes.append({
			"kind": "breath",
			"target_id": str(unit.get("id", "")),
			"before": breath_before,
			"after": breath_before - breath_spent,
			"delta": -breath_spent,
		})
	if target_aftertones != target_aftertones_before:
		writes.append({
			"kind": "aftertones",
			"target_id": str(target.get("id", "")),
			"before": _aftertones(target.get("aftertones", [])),
			"after": target_aftertones.duplicate(true),
		})
	if consumed_aftertone:
		writes.append({"kind": "aftertone_spent", "target_id": str(target.get("id", "")), "count": 1})
	if has_khor_bend and held_caster_aftertones != _aftertones(unit.get("aftertones", [])):
		writes.append({
			"kind": "aftertones",
			"target_id": str(unit.get("id", "")),
			"before": _aftertones(unit.get("aftertones", [])),
			"after": held_caster_aftertones,
		})
	if is_spell and (tempo_after != tempo_before or fizzled):
		writes.append({
			"kind": "tempo",
			"target_id": str(unit.get("id", "")),
			"before": int(unit.get("tempo", 0)),
			"after": tempo_after,
			"delta": tempo_after - int(unit.get("tempo", 0)),
		})
	if is_spell and not fizzled:
		writes.append({
			"kind": "last_cast_element",
			"target_id": str(unit.get("id", "")),
			"before": String(unit.get("last_cast_element", "")),
			"after": String(element_id),
		})
	if has_zhem_bend and target_tempo_after != target_tempo_before:
		writes.append({
			"kind": "tempo",
			"target_id": str(target.get("id", "")),
			"before": target_tempo_before,
			"after": target_tempo_after,
			"delta": target_tempo_after - target_tempo_before,
		})
	if ability.has("tempo_delta") and not has_zhem_bend:
		var tempo_delta := int(ability.get("tempo_delta", 0))
		writes.append({
			"kind": "tempo",
			"target_id": str(unit.get("id", "")),
			"before": int(unit.get("tempo", 0)),
			"after": int(unit.get("tempo", 0)) + tempo_delta,
			"delta": tempo_delta,
		})
	if not fizzled and composition.triad_effect_id != &"":
		writes.append({
			"kind": "triad_effect",
			"target_id": str(unit.get("id", "")),
			"effect_id": String(composition.triad_effect_id),
			"parameters": composition.unique_effect_parameters.duplicate(true),
		})
	var soul_failure_cost := (
		ElementMatrix.soul_on_failure(element_id, target_element) if fizzled else 0
	)
	var total_soul_cost := float(soul_overreach + soul_failure_cost)
	if is_spell and total_soul_cost > 0.0:
		var soul_after := maxf(soul_before - total_soul_cost, 0.0)
		writes.append({
			"kind": "soul_meter",
			"target_id": "soul_meter",
			"before": soul_before,
			"after": soul_after,
			"delta": soul_after - soul_before,
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
		"fizzled": fizzled,
		"fizzle_percent": fizzle_percent,
		"fizzle_roll": fizzle_roll,
		"hit": hit,
		"hit_chance": hit_chance,
		"hit_roll": hit_roll,
		"hit_bonus": hit_bonus,
		"positioning": positioning.duplicate(true),
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
		"fizzle_overridden": fizzle_overridden,
		"hidden_draw": draw_result,
		"reveal": bool(context.get("reveal", false)),
	}
	if bool(context.get("reveal", false)):
		# Seam v2 reveal channel (Lensbearer Clarity, Triad Dayspring): what the panel may show
		# beyond the public forecast. Presence of this key is the panel's cue; the numbers are
		# the same ones the calculation above used.
		result["revealed"] = {
			"fizzle_percent": fizzle_percent,
			"target_element": String(target_element),
			"relation": String(relation),
			"attunements": _dictionary(target.get("attunements", {})).duplicate(true),
			"hidden_draw_row_id": str(draw_result.get("row_id", "")),
		}
	if context.has("weakness_id"):
		result["weakness_id"] = StringName(context.get("weakness_id", ""))
		result["weakness"] = _dictionary(context.get("weakness", {})).duplicate(true)
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
	var context := {
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
		"height_advantage_steps": int(target_tile.get("height_advantage_steps", 0)),
		"to_hit_enabled": bool(battle_unit.get("to_hit_enabled", false)),
		"caster_context": _dictionary(battle_unit.get("caster_context", {})),
	}
	if battle_unit.has("weakness_id"):
		context["weakness_id"] = battle_unit.get("weakness_id", "")
		context["weakness"] = _dictionary(battle_unit.get("weakness", {})).duplicate(true)
	return resolve(context)


static func positional_modifiers(
	height_advantage_steps: int, facing_id: StringName
) -> Dictionary:
	var normalized_facing := facing_id if PROVISIONAL_FACING_RULES.has(facing_id) else &"front"
	var facing_rule: Dictionary = PROVISIONAL_FACING_RULES[normalized_facing]
	var favorable_steps := maxi(height_advantage_steps, 0)
	return {
		"height_advantage_steps": favorable_steps,
		"height_multiplier": 1.0 + float(favorable_steps) * PROVISIONAL_HEIGHT_DAMAGE_PER_STEP,
		"facing": normalized_facing,
		"facing_multiplier": float(facing_rule["damage_multiplier"]),
		"hit_bonus": int(facing_rule["hit_bonus"]),
	}


## Deterministic 1..100 roll. Pure function of the identifying context so that repeated
## resolution of the same action (forecast, replay, the 64x determinism test) always returns
## the same result, while distinct ticks/actors/seeds decorrelate.
static func _deterministic_hit_roll(
	context: Dictionary, ability_id: String, unit: Dictionary, target: Dictionary
) -> int:
	var key := "%d|%d|%s|%s|%s|%s" % [
		int(context.get("seed", 0)),
		int(context.get("tick", 0)),
		str(context.get("battle_id", "")),
		ability_id,
		str(unit.get("id", "")),
		str(target.get("id", "")),
	]
	var rng := RandomNumberGenerator.new()
	rng.seed = hash(key)
	return rng.randi_range(1, 100)


static func _deterministic_fizzle_roll(
	context: Dictionary, ability_id: String, unit: Dictionary, target: Dictionary
) -> int:
	var key := "fizzle|%d|%d|%s|%s|%s|%s" % [
		int(context.get("seed", 0)),
		int(context.get("tick", 0)),
		str(context.get("battle_id", "")),
		ability_id,
		str(unit.get("id", "")),
		str(target.get("id", "")),
	]
	var rng := RandomNumberGenerator.new()
	rng.seed = hash(key)
	return rng.randi_range(1, 100)


## Seam v2: hidden-draw roll, keyed like the fizzle roll plus the resource's `seed_key` so two
## resources drawing on the same cast decorrelate while forecast and commit agree.
static func _deterministic_draw_roll(
	context: Dictionary, ability_id: String, unit: Dictionary, target: Dictionary, seed_key: String
) -> int:
	var key := "draw|%s|%d|%d|%s|%s|%s|%s" % [
		seed_key,
		int(context.get("seed", 0)),
		int(context.get("tick", 0)),
		str(context.get("battle_id", "")),
		ability_id,
		str(unit.get("id", "")),
		str(target.get("id", "")),
	]
	var rng := RandomNumberGenerator.new()
	rng.seed = hash(key)
	return rng.randi_range(1, 100)


static func _fizzle_percent(
	context: Dictionary, composition: CompositionResult, magnitude: StringName
) -> float:
	var inputs: Dictionary = _dictionary(context.get("fizzle", {}))
	var breadth := String(inputs.get("breadth", _composition_breadth(composition)))
	var default_strain := (
		composition.distance_steps
		if composition.kind == CompositionResult.Kind.STRAINED_CHORD
		else 0
	)
	var strain := int(inputs.get("strain", inputs.get("strain_steps", default_strain)))
	var service := SkillCheckService.new()
	var percent := service.fizzle_percent(
		float(inputs.get("agreement_integrity", 100.0)),
		breadth,
		strain,
		str(inputs.get("magnitude", magnitude)),
		int(inputs.get("pitch", 2)),
		bool(inputs.get("mastery", false)),
		str(inputs.get("patron", "")),
	)
	service.free()
	return percent


static func _composition_breadth(composition: CompositionResult) -> StringName:
	match composition.kind:
		CompositionResult.Kind.TONE:
			return &"tone"
		CompositionResult.Kind.CHORD, CompositionResult.Kind.STRAINED_CHORD:
			return &"chord"
		CompositionResult.Kind.TRIAD:
			return &"triad"
	return &""


static func _ability_elements(ability: Dictionary, fallback: StringName) -> Array[StringName]:
	var result: Array[StringName] = []
	var authored: Variant = ability.get("elements", [])
	if authored is Array:
		for element: Variant in authored:
			result.append(ElementWheel.normalize(element))
	if result.is_empty():
		result.append(fallback)
	return result


static func _aftertones(value: Variant) -> Array[Dictionary]:
	var result: Array[Dictionary] = []
	if value is Array:
		for entry: Variant in value as Array:
			if entry is Dictionary:
				result.append((entry as Dictionary).duplicate(true))
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
