extends GdUnitTestSuite

## #136 — the element interaction table.
##
## The acceptance bar is not "the numbers are right"; the numbers are PROVISIONAL
## (GitHub #133). It is that the two wheel-distance axes stay separate: the
## caster's composition span (fizzle/Vär, no target) and the target relation
## (damage/fizzle/Soul, no composition) must never share a lookup or a distance.
## The double-count guards below are the load-bearing cases in this suite.

const MATRIX_JSON_PATH := "res://data/generated/element_matrix.json"
const WHEEL_SIZE := 10
## The five canon diametrics, from the vault's wheel order. Written out here on
## purpose: if the generator's topology ever drifts, this literal is the tripwire.
const CANON_CLASH_PAIRS := [
	["vekh", "sul"],
	["vel", "mozh"],
	["luth", "khash"],
	["khor", "zhem"],
	["zhur", "tham"],
]


# ─── Coverage: every ordered pair resolves exactly once ──────────────────────


func test_every_ordered_pair_resolves_exactly_once() -> void:
	var seen := {}
	for row: Dictionary in ElementMatrixRows.PAIR_ROWS:
		var key := "%s|%s" % [row["attack_element"], row["defend_element"]]
		assert_bool(seen.has(key)).override_failure_message("Duplicate pair %s" % key).is_false()
		seen[key] = true
	assert_int(seen.size()).is_equal(WHEEL_SIZE * WHEEL_SIZE)

	for attack_element: StringName in ElementWheel.ORDER:
		for defend_element: StringName in ElementWheel.ORDER:
			assert_bool(seen.has("%s|%s" % [attack_element, defend_element])).is_true()


func test_the_matrix_topology_is_derived_from_the_wheel() -> void:
	assert_array(ElementMatrixRows.WHEEL_ORDER).is_equal(ElementWheel.ORDER)
	for row: Dictionary in ElementMatrixRows.PAIR_ROWS:
		assert_int(int(row["distance"])).is_equal(
			ElementWheel.distance(row["attack_element"], row["defend_element"])
		)


func test_both_relation_tables_are_total_over_the_wheel_radius() -> void:
	for table: Array[Dictionary] in [
		ElementMatrixRows.TARGET_RELATION_ROWS, ElementMatrixRows.CASTER_RELATION_ROWS
	]:
		var distances: Array[int] = []
		for row: Dictionary in table:
			distances.append(int(row["distance"]))
		assert_array(distances).is_equal([0, 1, 2, 3, 4, 5])


# ─── Clash pairs are the five canon diametrics ───────────────────────────────


func test_clash_pairs_are_the_five_canon_diametrics() -> void:
	var expected: Array[String] = []
	for pair: Array in CANON_CLASH_PAIRS:
		var sorted_pair := pair.duplicate()
		sorted_pair.sort()
		expected.append("%s|%s" % [sorted_pair[0], sorted_pair[1]])
	expected.sort()

	var actual: Array[String] = []
	for pair: Array in ElementMatrix.clash_pairs():
		actual.append("%s|%s" % [pair[0], pair[1]])
	actual.sort()

	assert_array(actual).is_equal(expected)


func test_clash_is_the_only_relation_at_the_far_side_of_the_wheel() -> void:
	for pair: Array in CANON_CLASH_PAIRS:
		assert_str(ElementMatrix.relation(pair[0], pair[1])).is_equal("clash")
		assert_str(ElementMatrix.relation(pair[1], pair[0])).is_equal("clash")
	assert_str(ElementMatrix.relation("sul", "sul")).is_equal("same")
	assert_str(ElementMatrix.relation("sul", "vel")).is_equal("neighbour")
	assert_str(ElementMatrix.relation("sul", "luth")).is_equal("neutral")


# ─── The ratified gamble curve, as data ──────────────────────────────────────


func test_the_target_axis_carries_the_ratified_gamble_curve() -> void:
	# sul walking clockwise round the wheel gives distances 0..5 in order.
	var walk := ["sul", "vel", "luth", "khor", "tham", "vekh"]
	var damage := [0.5, 0.75, 1.0, 1.1, 1.2, 1.35]
	var fizzle := [0.0, 3.0, 6.0, 9.0, 12.0, 15.0]
	var soul := [0, 0, 1, 2, 3, 5]
	for distance in range(walk.size()):
		var target: String = walk[distance]
		assert_float(ElementMatrix.damage_multiplier("sul", target)).is_equal_approx(
			damage[distance], 0.001
		)
		assert_float(ElementMatrix.fizzle_add("sul", target)).is_equal_approx(
			fizzle[distance], 0.001
		)
		assert_int(ElementMatrix.soul_on_failure("sul", target)).is_equal(soul[distance])


func test_the_multipliers_are_marked_provisional() -> void:
	assert_bool(ElementMatrixRows.PROVISIONAL).is_true()
	var data := _json(MATRIX_JSON_PATH)
	assert_bool(data["provisional"]).is_true()
	assert_str(data["vault_id"]).is_equal("magic-system")


func test_an_unattuned_target_is_neutral_on_every_term() -> void:
	assert_float(ElementMatrix.damage_multiplier("sul", "")).is_equal_approx(1.0, 0.001)
	assert_float(ElementMatrix.fizzle_add("sul", "")).is_equal_approx(0.0, 0.001)
	assert_int(ElementMatrix.soul_on_failure("sul", "")).is_equal(0)
	assert_str(ElementMatrix.relation("sul", "not-an-element")).is_equal("none")


# ─── CHORD is caster-side; everything else is target-side ────────────────────


func test_chord_keys_off_caster_attunement_not_target_attunement() -> void:
	# Adjacent to the caster's attunement -> CHORD. The target is irrelevant.
	assert_float(ElementMatrix.chord_bonus("sul", "vel")).is_equal_approx(1.15, 0.001)
	assert_float(ElementMatrix.chord_bonus("sul", "sul")).is_equal_approx(1.0, 0.001)
	assert_float(ElementMatrix.chord_bonus("sul", "vekh")).is_equal_approx(1.0, 0.001)
	# And it is not reachable through the target axis: adjacency to a TARGET is
	# NEIGHBOUR (x0.75), never CHORD.
	assert_str(ElementMatrix.relation("sul", "vel")).is_equal("neighbour")
	assert_float(ElementMatrix.damage_multiplier("sul", "vel")).is_equal_approx(0.75, 0.001)


func test_the_caster_axis_never_prices_fizzle_or_soul() -> void:
	for row: Dictionary in ElementMatrixRows.CASTER_RELATION_ROWS:
		assert_float(float(row["fizzle_add"])).is_equal_approx(0.0, 0.001)
		assert_int(int(row["soul_on_failure"])).is_equal(0)


func test_the_two_axes_multiply_orthogonally() -> void:
	# caster attuned to vel (adjacent -> CHORD x1.15) casting sul into a
	# vekh-attuned target (opposed -> x1.35). 1.15 * 1.35 = 1.5525.
	assert_float(ElementMatrix.final_damage_multiplier("sul", "vel", "vekh")).is_equal_approx(
		1.5525, 0.0001
	)
	# Same caster relation, same-attuned target: 1.15 * 0.50.
	assert_float(ElementMatrix.final_damage_multiplier("sul", "vel", "sul")).is_equal_approx(
		0.575, 0.0001
	)
	# No chord: the target term stands alone.
	assert_float(ElementMatrix.final_damage_multiplier("sul", "vekh", "vekh")).is_equal_approx(
		1.35, 0.0001
	)


# ─── The double-count guards (the point of #136) ─────────────────────────────


func test_composition_resolver_output_is_unchanged_by_target_relation() -> void:
	# CompositionResolver has no target parameter, so "vary the target" means
	# resolving the same composition while the *matrix* says wildly different
	# things about every possible target. Nothing about the compose-time result
	# may move.
	var elements: Array[StringName] = [&"sul", &"luth"]
	var baseline := CompositionResolver.resolve(elements, &"phrase")
	for target_attunement: StringName in ElementWheel.ORDER:
		# Touch the target axis for this target, then re-resolve.
		var _multiplier := ElementMatrix.damage_multiplier(&"sul", target_attunement)
		var _fizzle := ElementMatrix.fizzle_add(&"sul", target_attunement)
		var _soul := ElementMatrix.soul_on_failure(&"sul", target_attunement)
		var again := CompositionResolver.resolve(elements, &"phrase")
		assert_int(again.kind).is_equal(baseline.kind)
		assert_int(again.distance_steps).is_equal(baseline.distance_steps)
		assert_int(again.span_steps).is_equal(baseline.span_steps)
		assert_int(again.var_cost).is_equal(baseline.var_cost)
		assert_str(again.status_id).is_equal(baseline.status_id)
		assert_bool(again.fizzle_requested).is_equal(baseline.fizzle_requested)


func test_composition_resolver_still_takes_no_target_parameter() -> void:
	# The structural boundary. If a target argument is ever added here, the two
	# axes can be fed the same distance and #136's bug becomes reachable.
	var signatures := CompositionResolver.new().get_method_list()
	for method: Dictionary in signatures:
		if str(method["name"]) != "resolve":
			continue
		var argument_names: Array[String] = []
		for argument: Dictionary in method["args"]:
			argument_names.append(str(argument["name"]))
		assert_array(argument_names).is_equal(["elements", "magnitude", "caster_context"])
		for argument_name: String in argument_names:
			assert_bool(argument_name.contains("target")).is_false()


func test_the_strain_ladder_and_the_relation_curve_are_different_tables() -> void:
	# strain_add prices composition span (caster, no target); the matrix fizzle
	# column prices reach at a target. They are authored in different Pandora
	# roots and they disagree numerically at every step past adjacency — so an
	# implementer who wires one into the other's slot fails this test.
	var fizzle_table: Dictionary = _json("res://data/generated/fizzle_table.json")["strain_add"]
	var relation_fizzle := {}
	for row: Dictionary in ElementMatrixRows.TARGET_RELATION_ROWS:
		relation_fizzle[int(row["distance"])] = float(row["fizzle_add"])

	assert_float(float(fizzle_table["0"])).is_equal_approx(0.0, 0.001)
	assert_float(float(fizzle_table["2"])).is_equal_approx(6.0, 0.001)
	assert_float(float(fizzle_table["3"])).is_equal_approx(12.0, 0.001)
	assert_float(float(fizzle_table["4"])).is_equal_approx(18.0, 0.001)
	# Distances 1, 3, 4 disagree between the two ladders; only 0 and 2 coincide.
	assert_float(float(relation_fizzle[1])).is_not_equal(float(fizzle_table["1"]))
	assert_float(float(relation_fizzle[3])).is_not_equal(float(fizzle_table["3"]))
	assert_float(float(relation_fizzle[4])).is_not_equal(float(fizzle_table["4"]))
	# And the matrix reaches distance 5, which the strain ladder does not have
	# at all — an opposed composition is rejected before it can be strained.
	assert_bool(relation_fizzle.has(5)).is_true()
	assert_bool(fizzle_table.has("5")).is_false()


func test_the_matrix_does_not_republish_the_composition_span_terms() -> void:
	# Nothing named strain/span/var may appear in the generated matrix, or the
	# two axes would be readable from one artifact and eventually one lookup.
	var text := FileAccess.get_file_as_string(MATRIX_JSON_PATH).to_lower()
	for forbidden: String in ["strain_add", "span_steps", "var_cost", "breadth_add"]:
		assert_bool(text.contains(forbidden)).override_failure_message(
			"The element matrix must not carry the compose-time term '%s'" % forbidden
		).is_false()


func _json(path: String) -> Dictionary:
	var parsed: Variant = JSON.parse_string(FileAccess.get_file_as_string(path))
	assert_bool(parsed is Dictionary).is_true()
	return parsed
