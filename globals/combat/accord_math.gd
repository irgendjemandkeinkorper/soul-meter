class_name AccordMath
extends RefCounted
## Background variation of Harmonic Accord, and the saturation lint that keeps it honest
## (`docs/architecture-in-game-editor.md` §4.11; design note: `docs/harmonic-accord.md`).
##
## Harmonic Accord is Agreement Integrity renamed (#329). This file answers one question: by how
## much does the world's own condition move a location's authored accord on a given day, before
## any zone or cell is considered?
##
## **Pure and deterministic.** No autoloads, no resources, no RNG object — the same inputs give
## the same number in the editor, in a forecast, in resolution, and in a headless replay a month
## later. `Battle.forecast_context()` freezes `(day_index, phase, weather, cell)` when a forecast
## is built and resolution reuses that exact context, so forecast == resolution holds by
## construction even if a phase or weather tick lands between the two. That guarantee is only
## worth anything if the function itself cannot drift, which is why nothing here reads state.
##
## **Canon is not duplicated here.** The wheel order, the phase list and the Zhavar ladder all
## live in data or in the globals that own them. The functions below take indices and distances;
## the `*_for` convenience overloads take those lists as parameters. Mirroring a copy of the
## wheel in this file would be one more thing to drift.
##
## ALL NUMBERS BELOW ARE **PROVISIONAL**. #328 owns the shape; balance owns the values.

## The bound the architecture note fixes at ±10 and the saturation lint is written against.
const MAX_VARIATION := 10.0
const MIN_VARIATION := -10.0

## The day's own condition: a deterministic wobble that is neither good nor bad on average.
const DRIFT_RANGE := 4.0

## The front's pull. Never positive — the Zhavar does not help anyone.
const ZHAVAR_PENALTY_PER_RUNG := 1.0

## Weather element against the location's patron element.
const SYMPATHY_RANGE := 2.0

## Ten elements on the wheel, so the farthest two are five steps apart.
const MAX_WHEEL_DISTANCE := 5

## Odd 32-bit constants; the mixing below is a small integer hash, not a PRNG, because a PRNG
## would carry position between calls and this must depend on nothing but its arguments.
const _MIX_A := 0x9E3779B1
const _MIX_B := 0x85EBCA77
const _MIX_C := 0xC2B2AE3D


## Total background variation, clamped to the ratified bound.
##
## The three terms are kept separate and individually inspectable because a single opaque number
## cannot be argued with: when a location plays badly, the owner needs to see whether it was the
## day, the front, or the weather.
static func variation(
	world_seed: int,
	day_index: int,
	phase_index: int,
	zhavar_rung_index: int,
	wheel_distance_steps: int
) -> float:
	return clampf(
		(
			drift(world_seed, day_index, phase_index)
			+ zhavar_pressure(zhavar_rung_index)
			+ element_sympathy(wheel_distance_steps)
		),
		MIN_VARIATION,
		MAX_VARIATION,
	)


## The named parts of a variation, for the overlay and for the design note's tables.
static func variation_breakdown(
	world_seed: int,
	day_index: int,
	phase_index: int,
	zhavar_rung_index: int,
	wheel_distance_steps: int
) -> Dictionary:
	var drift_value: float = drift(world_seed, day_index, phase_index)
	var zhavar_value: float = zhavar_pressure(zhavar_rung_index)
	var sympathy_value: float = element_sympathy(wheel_distance_steps)
	var raw: float = drift_value + zhavar_value + sympathy_value
	return {
		"drift": drift_value,
		"zhavar": zhavar_value,
		"sympathy": sympathy_value,
		"raw": raw,
		"total": clampf(raw, MIN_VARIATION, MAX_VARIATION),
		"clamped": not is_equal_approx(raw, clampf(raw, MIN_VARIATION, MAX_VARIATION)),
	}


## The signature the issue names, resolving ids against lists the caller owns. `wheel_order`,
## `phases` and `zhavar_rungs` come from the element matrix, WorldClock and SaveGame; an id that
## is not in its list resolves to the neutral position rather than throwing, because a missing
## weather element must not be able to stop a battle.
static func variation_for(
	day_index: int,
	phase: StringName,
	zhavar_rung: StringName,
	weather_element: StringName,
	patron_element: StringName,
	world_seed: int,
	wheel_order: Array,
	phases: Array,
	zhavar_rungs: Array
) -> float:
	return variation(
		world_seed,
		day_index,
		maxi(phases.find(phase), 0),
		maxi(zhavar_rungs.find(zhavar_rung), 0),
		wheel_distance(
			wheel_order.find(weather_element), wheel_order.find(patron_element), wheel_order.size()
		),
	)


## Deterministic wobble in [-DRIFT_RANGE, +DRIFT_RANGE] from the world seed, the day and the
## phase, and nothing else.
static func drift(world_seed: int, day_index: int, phase_index: int) -> float:
	var mixed: int = _mix(world_seed, day_index, phase_index)
	# 0..2^20 gives plenty of distinct values without the sign bit or float precision mattering.
	var unit: float = float(mixed & 0xFFFFF) / float(0xFFFFF)
	return (unit * 2.0 - 1.0) * DRIFT_RANGE


## 0 at the calmest rung, one penalty step per rung above it. Never positive.
static func zhavar_pressure(zhavar_rung_index: int) -> float:
	return -float(maxi(zhavar_rung_index, 0)) * ZHAVAR_PENALTY_PER_RUNG


## +SYMPATHY_RANGE when the weather matches the location's patron element, falling linearly to
## -SYMPATHY_RANGE at the far side of the wheel. Weather that agrees with a place makes casting
## there easier; weather that opposes it does the reverse.
static func element_sympathy(wheel_distance_steps: int) -> float:
	var steps: float = clampf(float(wheel_distance_steps), 0.0, float(MAX_WHEEL_DISTANCE))
	return SYMPATHY_RANGE - (steps / float(MAX_WHEEL_DISTANCE)) * (SYMPATHY_RANGE * 2.0)


## Ring distance between two wheel positions, 0..size/2. An index of -1 (element not on the
## wheel) is treated as neutral: half the maximum, contributing nothing either way.
static func wheel_distance(first_index: int, second_index: int, wheel_size: int) -> int:
	if first_index < 0 or second_index < 0 or wheel_size <= 0:
		return int(round(float(MAX_WHEEL_DISTANCE) / 2.0))
	var raw: int = absi(first_index - second_index)
	return mini(raw, wheel_size - raw)


## The §4.11 composition, clamped to the legal accord range.
static func accord_at(base_adjusted: float, zone_delta: float, variation_value: float) -> float:
	return clampf(base_adjusted + zone_delta + variation_value, 0.0, 100.0)


## Warns when the clamp in `accord_at()` would start swallowing authored intent.
##
## A clamp is not a safety net here, it is a silencer: once a location sits where +10 of good
## weather cannot move it, the authored accord and the zone deltas stop meaning anything and the
## place plays the same on every day of the year. The bake lints for it so the author hears
## about it instead of wondering why their zone does nothing.
static func saturation_warnings(
	base_adjusted: float, min_zone_delta: float, max_zone_delta: float, location_id: String = ""
) -> PackedStringArray:
	var warnings := PackedStringArray()
	var label: String = location_id if not location_id.is_empty() else "this location"
	var ceiling: float = base_adjusted + max_zone_delta + MAX_VARIATION
	var floor_value: float = base_adjusted + min_zone_delta + MIN_VARIATION
	if ceiling > 100.0:
		warnings.append(
			(
				"%s saturates high: %.1f + %.1f + %.1f = %.1f > 100, so good weather and "
				+ "positive zones stop registering."
			)
			% [label, base_adjusted, max_zone_delta, MAX_VARIATION, ceiling]
		)
	if floor_value < 0.0:
		warnings.append(
			(
				"%s saturates low: %.1f + %.1f + %.1f = %.1f < 0, so the front and hostile "
				+ "weather stop registering."
			)
			% [label, base_adjusted, min_zone_delta, MIN_VARIATION, floor_value]
		)
	return warnings


static func _mix(world_seed: int, day_index: int, phase_index: int) -> int:
	var value: int = (world_seed * _MIX_A) ^ (day_index * _MIX_B) ^ (phase_index * _MIX_C)
	value ^= value >> 15
	value = (value * _MIX_B) & 0x7FFFFFFF
	value ^= value >> 13
	return value & 0x7FFFFFFF
