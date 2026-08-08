class_name ElementMatrix
extends RefCounted

## The element interaction table (#136) — read-only runtime API over the
## generated `ElementMatrixRows` constants.
##
## ─── THE ONE RULE THIS FILE EXISTS TO ENFORCE ───────────────────────────────
## There are TWO axes that both measure wheel distance, and they must NEVER
## share a lookup table or a `distance` variable:
##
##   COMPOSE TIME (caster-side, no target known)
##     `CompositionResolver.resolve(elements, magnitude, caster_context)` prices
##     the caster's own composition span — `strain_add` → fizzle%, `var_cost` →
##     Vär. It takes NO target parameter, and it must not gain one.
##     This file's contribution to compose time is `chord_bonus()` only, which
##     reads CASTER_RELATION_ROWS and knows nothing about any target.
##
##   RESOLVE TIME (target-side, post-hit)
##     `damage_multiplier()` / `fizzle_add()` / `soul_on_failure()` read
##     PAIR_ROWS, keyed on (working's element, TARGET's attunement).
##
## The two never meet except in the final product:
##     final = base × chord_bonus(...) × damage_multiplier(...)
## which is what `final_damage_multiplier()` computes. If you ever find yourself
## computing a wheel distance once and feeding it to both a fizzle penalty and a
## damage multiplier, you have written the bug this table was built to prevent.
## See GitHub #133 and docs/prd-amendment-tactical-layer.md §9.2.
##
## Multipliers are PROVISIONAL (second tuning pass tracked in that document's
## §1.1); the shape of the curve is canon. A rebalance edits the Pandora
## "Element Relations" entities and regenerates — never this file.

## Returned when either side has no attunement, or names an element off the
## wheel. Neutral on every term: an unattuned target is neither resisted nor
## exposed, and nothing is charged for reaching at it.
const IDENTITY_ROW := {
	"distance": -1,
	"relation": &"none",
	"damage_multiplier": 1.0,
	"fizzle_add": 0.0,
	"soul_on_failure": 0,
}

## Wheel distance at which a working sits diametrically opposite an attunement.
const CLASH_DISTANCE := 5

static var _cache_built := false
## Resolve-time lookup: "attack|defend" -> row. Never read by the caster axis.
static var _target_by_pair: Dictionary = {}
## Compose-time lookup: caster distance -> row. Never read by the target axis.
static var _caster_by_distance: Dictionary = {}


static func _build_cache() -> void:
	if _cache_built:
		return
	_target_by_pair.clear()
	for row: Dictionary in ElementMatrixRows.PAIR_ROWS:
		_target_by_pair[_pair_key(row["attack_element"], row["defend_element"])] = row
	_caster_by_distance.clear()
	for row: Dictionary in ElementMatrixRows.CASTER_RELATION_ROWS:
		_caster_by_distance[int(row["distance"])] = row
	_cache_built = true


static func _pair_key(attack_element: Variant, defend_element: Variant) -> String:
	return "%s|%s" % [ElementWheel.normalize(attack_element), ElementWheel.normalize(defend_element)]


# ─── Resolve time: keyed on the TARGET's attunement ──────────────────────────

## The full interaction row for a working's element striking a target attuned to
## `target_attunement`. Returns IDENTITY_ROW when the target is unattuned.
static func target_relation(attack_element: Variant, target_attunement: Variant) -> Dictionary:
	_build_cache()
	var row: Variant = _target_by_pair.get(_pair_key(attack_element, target_attunement))
	if row == null:
		return IDENTITY_ROW.duplicate(true)
	return (row as Dictionary).duplicate(true)


## `same` / `neighbour` / `neutral` / `clash`, or `none` when unattuned.
static func relation(attack_element: Variant, target_attunement: Variant) -> StringName:
	return StringName(target_relation(attack_element, target_attunement)["relation"])


## The target-side damage multiplier. Apply post-hit, outside the caster's
## composition maths.
static func damage_multiplier(attack_element: Variant, target_attunement: Variant) -> float:
	return float(target_relation(attack_element, target_attunement)["damage_multiplier"])


## Percentage points added to fizzle for reaching at this target. Additive and
## applied OUTSIDE the magnitude multiply, beside pitch/mastery reductions —
## inside it, a high-magnitude cast pins to the 95% clamp and the gamble is lost.
## This is NOT `strain_add`: that prices composition span and has no target.
static func fizzle_add(attack_element: Variant, target_attunement: Variant) -> float:
	return float(target_relation(attack_element, target_attunement)["fizzle_add"])


## Soul spent when a cast at this target FAILS. Nothing is charged when it lands.
static func soul_on_failure(attack_element: Variant, target_attunement: Variant) -> int:
	return int(target_relation(attack_element, target_attunement)["soul_on_failure"])


## The five canon diametrics, as sorted unordered pairs.
static func clash_pairs() -> Array[Array]:
	_build_cache()
	var seen := {}
	var pairs: Array[Array] = []
	for row: Dictionary in ElementMatrixRows.PAIR_ROWS:
		if int(row["distance"]) != CLASH_DISTANCE:
			continue
		# Sort as String, never as StringName: StringName's `<` compares by
		# internal pointer, so a StringName sort is nondeterministic ordering,
		# not alphabetical, and the pair key would not deduplicate.
		var ends: Array[String] = [str(row["attack_element"]), str(row["defend_element"])]
		ends.sort()
		var key := "%s|%s" % [ends[0], ends[1]]
		if seen.has(key):
			continue
		seen[key] = true
		var pair: Array[StringName] = [StringName(ends[0]), StringName(ends[1])]
		pairs.append(pair)
	return pairs


# ─── Compose time: keyed on the CASTER's attunement ──────────────────────────

## The caster-side row for a working's element against the CASTER's own
## attunement. Deliberately a different table from the target axis — it prices
## adjacency (CHORD) and nothing else, and never charges fizzle or Soul.
static func caster_relation(attack_element: Variant, caster_attunement: Variant) -> Dictionary:
	_build_cache()
	var distance := ElementWheel.distance(attack_element, caster_attunement)
	var row: Variant = _caster_by_distance.get(distance)
	if row == null:
		return IDENTITY_ROW.duplicate(true)
	return (row as Dictionary).duplicate(true)


## The CHORD bonus — ×1.15 when the working sits adjacent to the caster's own
## attunement, ×1.0 otherwise. Caster-side: it takes no target and must never be
## folded into the target multiplier.
static func chord_bonus(attack_element: Variant, caster_attunement: Variant) -> float:
	return float(caster_relation(attack_element, caster_attunement)["damage_multiplier"])


# ─── The only place the two axes meet ────────────────────────────────────────

## `chord_bonus × target damage_multiplier`. The two terms multiply
## orthogonally; neither is derived from the other's distance.
static func final_damage_multiplier(
	attack_element: Variant, caster_attunement: Variant, target_attunement: Variant
) -> float:
	return (
		chord_bonus(attack_element, caster_attunement)
		* damage_multiplier(attack_element, target_attunement)
	)
