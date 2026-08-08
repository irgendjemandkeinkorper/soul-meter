class_name Weather
extends RefCounted
## Global attunement that ticks once per full measure (16 CT ticks). Issue #140,
## `docs/prd-amendment-tactical-layer.md` Tactical Layer T1 — Rules & data model.
##
## RULES (issue body): each full measure, tiles charged in the weather's element gain +1
## charge; tiles charged in that element's Clash lose 1. A Stormfront feeds Strom-charged
## tiles and starves Terra-charged tiles. Weather is authored per map
## (`maps.weather_default`) and can shift mid-battle on scripted beats.
##
## WHY it drives `TileState` instead of duplicating it: `globals/combat/tile_state.gd` already
## owns per-tile charge, residue, detonation and per-tile Hush. Weather's "+1 to a matching
## charge" reuses `TileState.apply_residue()` verbatim (same cap, same per-tile-Hush guard,
## same refusal shape) rather than re-deriving that arithmetic here. The "-1 to the clash
## charge" side has no equivalent op on `TileState` — draining is not casting residue, and
## `TileState.strike()` is the wrong shape (it detonates for bonus damage and always zeroes,
## neither of which weather does). Nothing else in `TileState` models "remove exactly one
## charge", so this file adjusts `charge_level`/`charge_element_id` directly for that one case.
## FOLLOW-UP: a `TileState.drain_charge(amount)` op would let Weather stop touching those
## fields directly; not added here because `tile_state.gd` is another agent's file this task.
##
## WHY the clash element always comes from `ElementWheel.distance() == 5`, never a table: same
## reasoning as `TileState`'s header — one source of truth for the Wheel-of-Ten geometry.
##
## NAMING — "Hush" is overloaded on purpose by the issue and deliberately un-overloaded here:
## `weather_hush` (this file) is the GLOBAL weather state from the issue's Constraints section
## ("no charge moves at all"). `TileState.hush` is the Hushwarden discipline's LOCAL field on
## one tile. They are independent and both are honored: a weather application still walks every
## tile and lets `TileState.hush` block that tile individually even when `weather_hush` is
## false, and `weather_hush` blocks the whole measure even where no tile is locally hushed.
##
## WHY this is pure data/logic (`RefCounted`, no scene tree): Gate T criterion 7 (determinism)
## and criterion 8 (save/load) — see `tile_state.gd`'s header for the identical argument. No
## RNG anywhere in this file.
##
## SCOPE — this file owns weather's OWN state (current element, Hush, tick phase within the
## measure) and the per-measure tile effect. It does not decide who calls `tick()` or how often;
## wiring `tick()` into `combat_controller.gd` or a battlefield model, and the scripted-beat
## authoring hook alongside the encounter pipeline (FR-108) the issue calls out, are deferred —
## not implemented here.

const TileState := preload("res://globals/combat/tile_state.gd")

## `ElementWheel.distance()` between two elements that are diametrically opposed — "Clash" per
## `ui/theme/ds.gd`'s Wheel-of-Ten comment. Mirrors `TileState.CLASH_WHEEL_DISTANCE`; both read
## the same geometry from `ElementWheel`, so this is not a second source of truth for the pair,
## just the same constant restated where it's used.
const CLASH_WHEEL_DISTANCE := 5

## No element is a valid "no weather authored" sentinel — same convention as
## `TileState.UNCHARGED`, and for the same reason (`ElementWheel.normalize()` never produces it).
const UNCHARGED := &""

## The weather's current element. `UNCHARGED` means no weather has been authored/shifted in yet,
## which is a legal, inert state (the measure still ticks; `_apply_measure()` just has nothing
## to feed or starve).
var element_id: StringName = UNCHARGED

## The GLOBAL weather Hush state from the issue's Constraints ("no charge moves at all —
## residue is suspended, detonations impossible"). Distinct from `TileState.hush` — see the
## file-header NAMING note. Setting this does NOT stop `tick()`'s counter; it only makes the
## next measure boundary apply nothing.
var weather_hush: bool = false

## Ticks elapsed since the last applied measure; wraps at `TurnScheduler.TICKS_PER_MEASURE`.
## Persisted so a save/load round trip resumes mid-measure rather than re-aligning to tick 0
## (Gate T criterion 8 — "weather phase" must survive save and load).
var _ticks_since_application: int = 0
## Total ticks this `Weather` has ever seen. Diagnostic/test evidence only; not required by any
## rule, but cheap and useful for proving the 16-tick cadence never drifts.
var _total_ticks: int = 0
## Total measures for which `_apply_measure()` actually ran (whether or not it moved charge —
## i.e. incremented even while `weather_hush` blocks the effect). Diagnostic/test evidence for
## "exactly one application per 16 ticks".
var _measures_applied: int = 0


static func create(starting_element_id: StringName = UNCHARGED, starts_hushed: bool = false) -> Weather:
	var weather := Weather.new()
	if starting_element_id != UNCHARGED:
		weather.set_element(starting_element_id)
	weather.weather_hush = starts_hushed
	return weather


## Sets (or mid-battle shifts on a scripted beat — see file header) the weather's element.
## Validated against `ElementsData` the same way `TileState._normalize_known()` validates
## charge/strike elements, so an unrecognized string never silently becomes "weather".
func set_element(new_element_id: StringName) -> Dictionary:
	var normalized := ElementWheel.normalize(new_element_id)
	var definition := ElementsData.element(normalized)
	if definition.id == UNCHARGED:
		return _blocked(
			&"unknown_element", "Element %s is not on the Wheel." % new_element_id, {}
		)
	element_id = normalized
	return _allowed({"element_id": element_id})


func set_hush(active: bool) -> void:
	weather_hush = active


func ticks_since_application() -> int:
	return _ticks_since_application


func total_ticks() -> int:
	return _total_ticks


func measures_applied() -> int:
	return _measures_applied


## Advances weather by one CT tick. The counter always advances — including while
## `weather_hush` is true — so Hush suspends charge movement without stopping the clock (issue
## acceptance line 2). Every 16th call (`TurnScheduler.TICKS_PER_MEASURE`, reused rather than
## redefined) resolves exactly one weather application over `tiles` and resets the phase; every
## other call is a no-op tick that reports `applied == false`. A partial measure — fewer than 16
## ticks since the last application, including at save/load boundaries — never applies anything
## (issue acceptance line 1).
func tick(tiles: Array[TileState] = []) -> Dictionary:
	_total_ticks += 1
	_ticks_since_application += 1
	if _ticks_since_application < TurnScheduler.TICKS_PER_MEASURE:
		return {
			"applied": false,
			"ticks_since_application": _ticks_since_application,
			"total_ticks": _total_ticks,
		}

	_ticks_since_application = 0
	_measures_applied += 1
	var result := _apply_measure(tiles)
	result["applied"] = true
	result["measures_applied"] = _measures_applied
	result["total_ticks"] = _total_ticks
	return result


func to_dict() -> Dictionary:
	return {
		"element_id": String(element_id),
		"weather_hush": weather_hush,
		"ticks_since_application": _ticks_since_application,
		"total_ticks": _total_ticks,
		"measures_applied": _measures_applied,
	}


static func from_dict(data: Dictionary) -> Weather:
	var weather := Weather.new()
	weather.element_id = StringName(str(data.get("element_id", "")))
	weather.weather_hush = bool(data.get("weather_hush", false))
	weather._ticks_since_application = int(data.get("ticks_since_application", 0))
	weather._total_ticks = int(data.get("total_ticks", 0))
	weather._measures_applied = int(data.get("measures_applied", 0))
	return weather


# ---- measure application ----


## Runs the once-per-measure effect over `tiles`. Refuses (distinctly from `TileState`'s own
## `&"hush"`) when weather itself is Hush; otherwise walks every tile, letting each tile's own
## `TileState.hush` (Hushwarden field) block that tile individually — weather Hush and tile Hush
## are independent and both honored (see file-header NAMING note).
func _apply_measure(tiles: Array[TileState]) -> Dictionary:
	if weather_hush:
		return _blocked(
			&"weather_hush",
			"Weather is Hush; no charge moves this measure.",
			{"element_id": String(element_id)},
		)
	if element_id == UNCHARGED:
		return _allowed({"charged_tiles": 0, "drained_tiles": 0, "locally_hushed_tiles": 0})

	var charged := 0
	var drained := 0
	var locally_hushed := 0
	for tile in tiles:
		if tile == null or not tile.is_charged():
			continue
		if tile.hush:
			locally_hushed += 1
			continue
		if tile.charge_element_id == element_id:
			# Reuses TileState's own cap/refusal-aware growth rather than re-deriving it — see
			# file header. Same element charging itself is never the PLACEHOLDER cross-element
			# overwrite path.
			tile.apply_residue(element_id)
			charged += 1
		elif ElementWheel.distance(tile.charge_element_id, element_id) == CLASH_WHEEL_DISTANCE:
			# TileState owns the cap, the Hush guard and the clear-at-zero rule.
			tile.drain_charge(1)
			drained += 1

	return _allowed({
		"charged_tiles": charged,
		"drained_tiles": drained,
		"locally_hushed_tiles": locally_hushed,
	})


# ---- helpers ----


## Mirrors `TileState._allowed()` / `CastingGate._allowed()` / `TurnScheduler._allowed()` — one
## refusal shape across the whole tactical layer (FR-606).
static func _allowed(extra: Dictionary = {}) -> Dictionary:
	var result := {"allowed": true, "blocked_by": &"", "nearest_unblock": {}, "message": ""}
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
