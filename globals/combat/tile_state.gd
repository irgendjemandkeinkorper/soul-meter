class_name TileState
extends RefCounted
## Per-tile element charge, residue and detonation — the tactical-layer mechanic the
## amendment calls "the board remembers what was cast on it; that is the game." Issue #139,
## `docs/prd-amendment-tactical-layer.md` §2.2 (FR-606 refusal taxonomy) and §5 (Gate T
## criteria 7 determinism, 8 save/load).
##
## WHY this is a separate object from `map_tiles`: the issue's shape table draws a hard line
## between immutable content (`map_tiles`: height, terrain, base element) and the thin mutable
## battle layer over it (`tile_state`: charge, residue, detonation, Hush). Collapsing them would
## make replays and forecasting expensive, because every forecast would have to diff against
## authored content instead of a small per-battle delta. `TileState` models ONLY that delta —
## one instance per `(battle_id, x, y)` — and never touches `map_tiles`.
##
## WHY it is pure data/logic (`RefCounted`, no scene tree): the board renderer must stay a pure
## consumer of `CombatEvent`s (issue "Constraints"), and Gate T criterion 7 requires the same
## inputs to produce identical results. A node in the tree invites frame-order and signal-timing
## nondeterminism; a plain object called with explicit inputs cannot drift.
##
## WHY element identities are never hardcoded here: `globals/elements/` (`ElementWheel`,
## `ElementsData`) is the one place the Wheel of Ten and its Chord/Clash geometry are defined.
## Duplicating element ids or the clash relationship here would create a second source of truth
## that could silently disagree with the casting side of the same Wheel.
##
## WHY the refusal shape matches `CastingGate` / `TurnScheduler._blocked()`: FR-606 (amendment
## §2.2) mandates ONE taxonomy for "why was this denied", with a `blocked_by` that distinguishes
## reasons instead of collapsing them into a generic failure. `hush` needs its own `blocked_by`
## because it is a distinct refusal from "nothing charged here" or "unknown element" — Gate T
## criterion 6's comprehension question ("explain what just happened on that tile") depends on
## that distinction surviving to the UI.
##
## PLACEHOLDER, reported per the amendment's §10.1 block on authoring `element_matrix`: applying
## residue of an element DIFFERENT from a tile's current charge overwrites the tile to the new
## element at charge 1, rather than blending, stacking, or refusing. That is not a balance
## decision — it is the absence of one. A real cross-element interaction table is exactly what
## `element_matrix` would encode, and that authoring is blocked. Do not treat this overwrite
## behavior as ratified; revisit it when `element_matrix` unblocks.

## Casting leaves at most this much residue on a tile (issue "Rules": "0-3").
const MAX_CHARGE_LEVEL := 3
## Acting from a tile charged in your ability's element multiplies damage by
## `1 + ACTION_MULTIPLIER_PER_CHARGE * charge` (issue "Rules"). This is stated explicitly by the
## issue, not an interaction-matrix number, so it is not subject to the §10.1 block.
const ACTION_MULTIPLIER_PER_CHARGE := 0.10
## Clash detonation bonus damage is `charge * DETONATION_MULTIPLIER` (issue "Rules").
const DETONATION_MULTIPLIER := 9
## `ElementWheel.distance()` between two elements that are diametrically opposed — "Clash" per
## `ui/theme/ds.gd`'s Wheel-of-Ten comment and `globals/elements/composition_result.gd`'s
## `Kind.CLASH`. Striking a charge with its Clash element is what detonates it.
const CLASH_WHEEL_DISTANCE := 5

## No element is a valid, normalized "uncharged" sentinel, since `ElementWheel.normalize()`
## never produces it and `ElementsData.element(&"")` resolves to the empty default definition.
const UNCHARGED := &""

var battle_id: StringName = &""
var x: int = 0
var y: int = 0
var charge_element_id: StringName = UNCHARGED
var charge_level: int = 0
## Authored `map_tiles.height` plus any battle-time change (e.g. Thamshaper). Carried here,
## not on `map_tiles`, for the same immutable-content-vs-battle-layer reason as charge.
var height_delta: int = 0
## Static terrain cover carried into the live tile snapshot.
var cover: bool = false
## Hushwarden fields: "no charge moves at all — residue is suspended, detonations impossible"
## (issue "Constraints"). Reads (`is_charged()`, `action_multiplier()`) still answer honestly
## while hushed; only the mutating operations refuse.
var hush: bool = false


static func create(
	battle_id: StringName, x: int, y: int, height_delta: int = 0, cover: bool = false
) -> TileState:
	var tile := TileState.new()
	tile.battle_id = battle_id
	tile.x = x
	tile.y = y
	tile.height_delta = height_delta
	tile.cover = cover
	return tile


func is_charged() -> bool:
	return charge_level > 0 and charge_element_id != UNCHARGED


## Applies +1 residue of `element_id`, the element the caster's ability just resolved with.
## Same-element residue accumulates and caps at `MAX_CHARGE_LEVEL`. See the file-header
## PLACEHOLDER note for what happens across a different existing charge.
func apply_residue(element_id: StringName) -> Dictionary:
	var normalized := _normalize_known(element_id)
	if normalized == UNCHARGED:
		return _blocked(&"unknown_element", "Element %s is not on the Wheel." % element_id, {})
	if hush:
		return _blocked(
			&"hush",
			"Hushwarden field suppresses charge; residue cannot be applied.",
			{"element_id": normalized}
		)

	var cross_element := is_charged() and charge_element_id != normalized
	if cross_element:
		# PLACEHOLDER overwrite — see file header. Not a ratified interaction rule.
		charge_element_id = normalized
		charge_level = 1
	else:
		charge_element_id = normalized
		charge_level = mini(charge_level + 1, MAX_CHARGE_LEVEL)

	return _allowed({
		"charge_element_id": charge_element_id,
		"charge_level": charge_level,
		"capped": charge_level == MAX_CHARGE_LEVEL,
		"cross_element_placeholder": cross_element,
	})


## Damage multiplier for acting from this tile with `element_id`. Not a refusal: attacking from
## an uncharged tile, or in an off-element, is always legal — it simply carries no bonus, so this
## returns a plain multiplier rather than the `{allowed,...}` shape. Hush suppresses the bonus
## the same as it suppresses every other charge effect.
func action_multiplier(element_id: StringName) -> float:
	if hush or not is_charged():
		return 1.0
	var normalized := ElementWheel.normalize(element_id)
	if normalized != charge_element_id:
		return 1.0
	return 1.0 + ACTION_MULTIPLIER_PER_CHARGE * float(charge_level)


## Resolves a strike against this tile with `element_id`. Detonates (charge * 9 bonus damage,
## tile drops to zero) when `element_id` is this tile's charge's Clash element. Hush makes
## detonation impossible entirely, per the issue's Constraints section.
func strike(element_id: StringName) -> Dictionary:
	var normalized := _normalize_known(element_id)
	if normalized == UNCHARGED:
		return _blocked(&"unknown_element", "Element %s is not on the Wheel." % element_id, {})
	if hush:
		var refusal := _blocked(
			&"hush",
			"Hushwarden field suppresses charge; detonation is impossible.",
			{"element_id": normalized}
		)
		refusal["detonated"] = false
		refusal["bonus_damage"] = 0
		return refusal

	if not is_charged():
		return _allowed({"detonated": false, "bonus_damage": 0})

	var distance := ElementWheel.distance(normalized, charge_element_id)
	if distance != CLASH_WHEEL_DISTANCE:
		return _allowed({"detonated": false, "bonus_damage": 0})

	var charge_before := charge_level
	var bonus_damage := charge_before * DETONATION_MULTIPLIER
	charge_level = 0
	charge_element_id = UNCHARGED
	return _allowed({
		"detonated": true,
		"bonus_damage": bonus_damage,
		"charge_before": charge_before,
	})


func clear_charge() -> void:
	charge_level = 0
	charge_element_id = UNCHARGED


## Remove `amount` charge without detonating, clearing the element at zero.
##
## WHY this exists separately from `strike()`: a strike DETONATES — it pays bonus
## damage and always zeroes the tile. Weather's clash drain is not a detonation;
## it shaves one level and leaves the rest standing. Without this operation
## `Weather` reached into `charge_level` and `charge_element_id` directly, which
## put the cap, the Hush guard and the clear-at-zero rule in two places.
func drain_charge(amount: int = 1) -> Dictionary:
	if hush:
		return _blocked(
			&"hush",
			"Hushwarden field suppresses charge; it cannot be drained.",
			{"requires": "hush_lifted"}
		)
	if not is_charged():
		return _allowed({"drained": 0, "cleared": false})
	var before := charge_level
	charge_level = maxi(charge_level - maxi(amount, 0), 0)
	var cleared := charge_level <= 0
	if cleared:
		clear_charge()
	return _allowed({"drained": before - charge_level, "cleared": cleared})


func to_dict() -> Dictionary:
	return {
		"battle_id": String(battle_id),
		"x": x,
		"y": y,
		"charge_element_id": String(charge_element_id),
		"charge_level": charge_level,
		"height_delta": height_delta,
		"cover": cover,
		"hush": hush,
	}


static func from_dict(data: Dictionary) -> TileState:
	var tile := TileState.new()
	tile.battle_id = StringName(str(data.get("battle_id", "")))
	tile.x = int(data.get("x", 0))
	tile.y = int(data.get("y", 0))
	tile.charge_element_id = StringName(str(data.get("charge_element_id", "")))
	tile.charge_level = int(data.get("charge_level", 0))
	tile.height_delta = int(data.get("height_delta", 0))
	tile.cover = bool(data.get("cover", false))
	tile.hush = bool(data.get("hush", false))
	return tile


# ---- helpers ----


## Normalizes and validates against `ElementsData` so an unrecognized string never silently
## becomes a charge — see "Element identities come from globals/elements/" in the issue.
## Returns `UNCHARGED` on an unknown element; callers turn that into a `&"unknown_element"`
## refusal rather than inventing a new string constant to represent it.
func _normalize_known(element_id: StringName) -> StringName:
	var normalized := ElementWheel.normalize(element_id)
	var definition := ElementsData.element(normalized)
	if definition.id == UNCHARGED:
		return UNCHARGED
	return normalized


## Mirrors `CastingGate._allowed()` / `TurnScheduler._allowed()` — one refusal shape across
## casting, turn order and tile charge is what lets FR-606 answer "why can't I do this?" with a
## single code path.
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
