class_name CompositionResult
extends RefCounted

enum Kind { INVALID, TONE, CHORD, STRAINED_CHORD, TRIAD, CLASH, OPPOSED }

var kind: Kind = Kind.INVALID
var status_id: StringName = &"invalid"
var magnitude: StringName = &""
var elements: Array[StringName] = []
var center_element: StringName = &""
var span_steps: int = 0
var distance_steps: int = 0
var var_cost: int = 0
var impositions: Array[StringName] = []
var imposition_entries: Array[Dictionary] = []
var imposition_strength: StringName = &""
var rule_bends: Array[StringName] = []
var damage_components: Array[StringName] = []
var unique_effect_id: StringName = &""
var triad_effect_id: StringName = &""
var unique_effect_parameters: Dictionary = {}
var fizzle_requested: bool = false
var self_inflicted_discord: bool = false
var rejected: bool = false
var failure_id: StringName = &""
var caster_context: Dictionary = {}
var allowed: bool = true
var blocked_by: StringName = &""
var nearest_unblock: Dictionary = {}
var casting_gate: Dictionary = {}


func is_resolved() -> bool:
	return kind == Kind.TONE or kind == Kind.CHORD or kind == Kind.STRAINED_CHORD or kind == Kind.TRIAD


func is_castable() -> bool:
	return is_resolved() and allowed


func is_clash() -> bool:
	return kind == Kind.CLASH


func is_opposed() -> bool:
	return kind == Kind.OPPOSED


func to_dict() -> Dictionary:
	return {
		"kind": kind,
		"status_id": status_id,
		"magnitude": magnitude,
		"elements": elements.duplicate(),
		"center_element": center_element,
		"span_steps": span_steps,
		"distance_steps": distance_steps,
		"var_cost": var_cost,
		"impositions": impositions.duplicate(),
		"imposition_entries": imposition_entries.duplicate(true),
		"imposition_strength": imposition_strength,
		"rule_bends": rule_bends.duplicate(),
		"damage_components": damage_components.duplicate(),
		"unique_effect_id": unique_effect_id,
		"triad_effect_id": triad_effect_id,
		"unique_effect_parameters": unique_effect_parameters.duplicate(true),
		"fizzle_requested": fizzle_requested,
		"self_inflicted_discord": self_inflicted_discord,
		"rejected": rejected,
		"failure_id": failure_id,
		"allowed": allowed,
		"blocked_by": blocked_by,
		"nearest_unblock": nearest_unblock.duplicate(true),
	}
