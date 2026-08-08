class_name CastingGate
extends RefCounted

## Breadth gates for Elements & Music. This is a query only: it does not
## consume Breath, spend Vär, or mutate the composition.

const CHORD_MIN_HARMONY := 0
const TRIAD_MIN_HARMONY := 2


static func query(
	composition: Variant, harmony: int, caster_context: Dictionary = {}
) -> Dictionary:
	if bool(caster_context.get("husked", false)):
		return _blocked_husked(clampi(harmony, -5, 5), caster_context)
	if not composition is CompositionResult:
		return query_breadth(StringName(composition), harmony, &"", caster_context)
	var result: CompositionResult = composition
	var breadth := StringName("")
	match result.kind:
		CompositionResult.Kind.TONE:
			breadth = &"tone"
		CompositionResult.Kind.CHORD, CompositionResult.Kind.STRAINED_CHORD:
			breadth = &"chord"
		CompositionResult.Kind.TRIAD:
			breadth = &"triad"
		_:
			return _allowed(harmony, -1)
	return query_breadth(breadth, harmony, result.magnitude, caster_context)


static func query_breadth(
	breadth: StringName,
	harmony: int,
	magnitude: StringName = &"",
	caster_context: Dictionary = {}
) -> Dictionary:
	var current := clampi(harmony, -5, 5)
	if bool(caster_context.get("husked", false)):
		return _blocked_husked(current, caster_context)
	var normalized := String(breadth).to_lower()
	if normalized == "tone":
		return _allowed(current, -1)

	var solo := bool(caster_context.get("solo", caster_context.get("is_solo", false)))
	var mastery := bool(
		caster_context.get("mastery", caster_context.get("has_mastery", false))
	)
	if normalized == "chord":
		if current >= CHORD_MIN_HARMONY or (solo and mastery):
			return _allowed(current, CHORD_MIN_HARMONY)
		if solo and not mastery:
			return _blocked(
				&"solo_mastery",
				current,
				CHORD_MIN_HARMONY,
				&"mastery"
			)
		return _blocked(&"var_harmony", current, CHORD_MIN_HARMONY, &"var_harmony")

	if normalized == "triad":
		var highest_mastery := bool(
			caster_context.get(
				"highest_mastery",
				caster_context.get(
					"has_highest_mastery", caster_context.get("mastery_is_highest", false)
				)
			)
		)
		var breath_tier := String(
			caster_context.get(
				"breath_tier",
				caster_context.get(
					"breath_cost_tier", caster_context.get("breath_cost", magnitude)
				)
			)
		).to_lower()
		var refrain_cost := breath_tier == "refrain"
		if current >= TRIAD_MIN_HARMONY or (solo and highest_mastery and refrain_cost):
			return _allowed(current, TRIAD_MIN_HARMONY)
		if solo and not highest_mastery:
			return _blocked(
				&"solo_mastery",
				current,
				TRIAD_MIN_HARMONY,
				&"highest_mastery"
			)
		if solo and highest_mastery and not refrain_cost:
			return _blocked(
				&"breath_tier",
				current,
				TRIAD_MIN_HARMONY,
				&"refrain"
			)
		return _blocked(&"var_harmony", current, TRIAD_MIN_HARMONY, &"var_harmony")

	return _allowed(current, -1)


static func _allowed(current: int, minimum: int) -> Dictionary:
	return {
		"allowed": true,
		"blocked_by": &"",
		"nearest_unblock": {},
		"current_harmony": current,
		"required_harmony": minimum,
	}


## M4.3 — husking-while-alive (cosmology/souls.md). A husked caster has "no
## pattern left to spend": every breadth is refused, not just chord/triad.
## Callers pass husked state via caster_context (see
## GameState.husked_casting_context()); this gate does not read GameState
## directly to keep CastingGate a pure query. FR-606 requires naming the
## system and the nearest unblock condition — recovery CONTENT (a quest,
## dialogue) is authored later, so nearest_unblock only names the recovery
## system and, if known, the permanent recovery ceiling.
static func _blocked_husked(current: int, caster_context: Dictionary = {}) -> Dictionary:
	var nearest_unblock: Dictionary = {"type": &"husked_recovery"}
	var ceiling: Variant = caster_context.get("husked_recovery_ceiling", null)
	if ceiling != null:
		nearest_unblock["ceiling"] = float(ceiling)
	return {
		"allowed": false,
		"blocked_by": &"husked",
		"nearest_unblock": nearest_unblock,
		"message": (
			"The Soul Gauge is husked — there is no pattern left to spend. "
			+ "Recovery is slow, partial, and social."
		),
		"current_harmony": current,
		"required_harmony": -1,
	}


static func _blocked(
	blocked_by: StringName, current: int, minimum: int, requirement: StringName
) -> Dictionary:
	var delta := maxi(minimum - current, 0)
	return {
		"allowed": false,
		"blocked_by": blocked_by,
		"nearest_unblock": {
			"type": requirement,
			"minimum": minimum,
			"delta": delta,
		},
		"current_harmony": current,
		"required_harmony": minimum,
	}
