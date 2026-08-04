class_name CompositionResolver
extends RefCounted

## Pure Elements & Music composition algebra.
##
## This layer describes effects only. It never rolls fizzle, spends Vär, applies
## statuses, or executes a Triad effect. It does query the optional casting gate
## when caster_context includes the caster's harmony and gate prerequisites.
##
## The ratified notes use "span" for the hard two-step composition cap while
## also defining 2–4-step Strained Chords. Chord distance is therefore kept as
## its own strain distance; the cap is applied to the outer span of a Triad (or
## any other three-element composition). This preserves both acceptance gates
## until the canon wording is reconciled by the human owner.

const VALID_MAGNITUDES: Array[StringName] = [&"note", &"phrase", &"song", &"refrain"]


static func resolve(
	elements: Array[StringName],
	magnitude: StringName,
	caster_context: Dictionary = {}
) -> CompositionResult:
	var result := CompositionResult.new()
	result.magnitude = ElementWheel.normalize(magnitude)
	result.caster_context = caster_context.duplicate(true)
	result.elements = _normalize_elements(elements)

	if not VALID_MAGNITUDES.has(result.magnitude):
		return _reject(result, &"invalid_magnitude")
	if result.elements.size() < 1 or result.elements.size() > 3:
		return _reject(result, &"invalid_element_count")
	if _has_unknown_element(result.elements):
		return _reject(result, &"unknown_element")
	if result.elements.size() != _unique_count(result.elements):
		return _reject(result, &"duplicate_element")

	result.span_steps = ElementWheel.span(result.elements)
	if ElementWheel.contains_opposed_pair(result.elements):
		result.kind = CompositionResult.Kind.OPPOSED
		result.status_id = &"opposed"
		result.rejected = true
		result.failure_id = &"opposed_elements"
		return result

	match result.elements.size():
		1:
			return _apply_casting_gate(_resolve_tone(result))
		2:
			return _apply_casting_gate(_resolve_chord(result))
		3:
			return _apply_casting_gate(_resolve_triad(result))
	return _reject(result, &"invalid_element_count")


static func _resolve_tone(result: CompositionResult) -> CompositionResult:
	result.kind = CompositionResult.Kind.TONE
	result.status_id = &"tone"
	result.imposition_strength = &"full"
	result.fizzle_requested = true
	_add_element_rule_bend(result, result.elements[0])
	_add_imposition(result, result.elements[0], &"full")
	return result


static func _resolve_chord(result: CompositionResult) -> CompositionResult:
	result.distance_steps = ElementWheel.distance(result.elements[0], result.elements[1])
	if result.distance_steps < 0:
		return _reject(result, &"unknown_element")
	if result.distance_steps >= 2:
		result.kind = CompositionResult.Kind.STRAINED_CHORD
		result.status_id = &"strained_chord"
		result.imposition_strength = &"weakened"
		result.var_cost = result.distance_steps
	else:
		result.kind = CompositionResult.Kind.CHORD
		result.status_id = &"chord"
		result.imposition_strength = &"full"
	result.fizzle_requested = true

	var selected := _selected_chord_imposition(result)
	if result.kind == CompositionResult.Kind.STRAINED_CHORD:
		_add_imposition(result, result.elements[0], &"weakened")
		_add_imposition(result, result.elements[1], &"weakened")
	else:
		_add_imposition(result, selected, &"full")
	_add_element_rule_bend(result, result.elements[0])
	_add_element_rule_bend(result, result.elements[1])
	return result


static func _resolve_triad(result: CompositionResult) -> CompositionResult:
	if result.span_steps > 2:
		return _clash(result)
	var definition := ElementsData.triad_for_elements(result.elements)
	if definition.id.is_empty():
		return _reject(result, &"unsupported_triad")

	result.kind = CompositionResult.Kind.TRIAD
	result.status_id = &"triad"
	result.center_element = definition.center_element
	result.imposition_strength = &"amplified"
	result.unique_effect_id = definition.unique_effect_id
	result.unique_effect_parameters = definition.unique_effect_parameters.duplicate(true)
	result.fizzle_requested = true
	_add_imposition(result, definition.center_element, &"amplified")
	for element in result.elements:
		_add_element_rule_bend(result, element)
	return result


static func _clash(result: CompositionResult) -> CompositionResult:
	result.kind = CompositionResult.Kind.CLASH
	result.status_id = &"clash"
	result.self_inflicted_discord = true
	result.rejected = true
	result.fizzle_requested = false
	result.failure_id = &"span_exceeds_two"
	return result


static func _reject(result: CompositionResult, reason: StringName) -> CompositionResult:
	result.kind = CompositionResult.Kind.INVALID
	result.status_id = &"invalid"
	result.rejected = true
	result.failure_id = reason
	return result


static func _apply_casting_gate(result: CompositionResult) -> CompositionResult:
	if not result.is_resolved() or not _has_gate_context(result.caster_context):
		return result
	var harmony := int(
		result.caster_context.get(
			"var_harmony", result.caster_context.get("harmony", _harmony_from_game_state(result))
		)
	)
	var gate := CastingGate.query(result, harmony, result.caster_context)
	result.casting_gate = gate.duplicate(true)
	result.allowed = bool(gate.get("allowed", false))
	result.blocked_by = StringName(gate.get("blocked_by", ""))
	result.nearest_unblock = gate.get("nearest_unblock", {}).duplicate(true)
	if not result.allowed:
		result.rejected = true
		result.failure_id = &"casting_gate"
	return result


static func _has_gate_context(context: Dictionary) -> bool:
	for key in [
		"var_harmony", "harmony", "caster_id", "solo", "mastery", "highest_mastery",
		"is_solo", "has_mastery", "has_highest_mastery", "mastery_is_highest",
		"breath_tier", "breath_cost_tier", "breath_cost"
	]:
		if context.has(key):
			return true
	return false


static func _harmony_from_game_state(result: CompositionResult) -> int:
	if not result.caster_context.has("caster_id"):
		return 0
	var main_loop := Engine.get_main_loop()
	if main_loop is SceneTree:
		var state: Node = main_loop.root.get_node_or_null("GameState")
		if state != null and state.has_method("get_var_harmony"):
			return int(state.call("get_var_harmony", str(result.caster_context["caster_id"])))
	return 0


static func _selected_chord_imposition(result: CompositionResult) -> StringName:
	for key in [&"imposition_element", &"chosen_imposition_element", &"selected_imposition"]:
		if result.caster_context.has(key):
			var requested := ElementWheel.normalize(result.caster_context[key])
			if result.elements.has(requested):
				return requested
	for element in result.elements:
		if not ElementsData.element(element).imposition_id.is_empty():
			return element
	return result.elements[0]


static func _add_imposition(result: CompositionResult, element_id: StringName, strength: StringName) -> void:
	var element := ElementsData.element(element_id)
	if element.id.is_empty() or element.imposition_id.is_empty():
		return
	result.impositions.append(element.imposition_id)
	result.imposition_entries.append({
		"element": element.id,
		"imposition": element.imposition_id,
		"strength": strength,
	})
	if element.deals_damage:
		result.damage_components.append(element.id)


static func _add_element_rule_bend(result: CompositionResult, element_id: StringName) -> void:
	var element := ElementsData.element(element_id)
	if not element.id.is_empty():
		result.rule_bends.append(element.rule_bend_id)


static func _normalize_elements(elements: Array[StringName]) -> Array[StringName]:
	var normalized: Array[StringName] = []
	for element in elements:
		normalized.append(ElementWheel.normalize(element))
	return normalized


static func _has_unknown_element(elements: Array[StringName]) -> bool:
	for element in elements:
		if ElementsData.element(element).id.is_empty():
			return true
	return false


static func _unique_count(elements: Array[StringName]) -> int:
	var unique: Array[StringName] = []
	for element in elements:
		if not unique.has(element):
			unique.append(element)
	return unique.size()
