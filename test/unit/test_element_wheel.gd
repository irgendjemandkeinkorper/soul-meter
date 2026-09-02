extends GdUnitTestSuite

func test_normalize_index_and_circular_distance() -> void:
	assert_str(String(ElementWheel.normalize(" Suul "))).is_equal(" suul ")
	assert_int(ElementWheel.index_of(&"suul")).is_equal(0)
	assert_int(ElementWheel.distance(&"suul", &"strom")).is_equal(1)
	assert_int(ElementWheel.distance(&"unknown", &"suul")).is_equal(-1)

func test_span_rejects_unknown_or_duplicate_and_finds_outer_gap() -> void:
	assert_int(ElementWheel.span([])).is_equal(0)
	assert_int(ElementWheel.span([&"suul", &"suul"])).is_equal(-1)
	assert_int(ElementWheel.span([&"suul", &"aqua", &"terra"])).is_equal(4)
	assert_int(ElementWheel.span([&"missing", &"aqua"])).is_equal(-1)

func test_contains_opposed_pair_only_for_diametric_elements() -> void:
	assert_bool(ElementWheel.contains_opposed_pair([&"suul", &"daar"])).is_true()
	assert_bool(ElementWheel.contains_opposed_pair([&"suul", &"bloei"])).is_false()

func test_opposite_returns_the_element_at_wheel_distance_five() -> void:
	assert_str(String(ElementWheel.opposite(&"suul"))).is_equal("daar")
	assert_str(String(ElementWheel.opposite(&"daar"))).is_equal("suul")
	assert_int(ElementWheel.distance(&"strom", ElementWheel.opposite(&"strom"))).is_equal(5)
	assert_str(String(ElementWheel.opposite(&"unknown"))).is_empty()



# ─── Wheel algebra, table-driven over the whole wheel ────────────────────────
#
# The wheel is the single source of truth for distance, span, and opposition.
# These tests walk ElementWheel.ORDER itself rather than naming elements, so a
# regenerated wheel order is exercised without editing the suite.


func test_distance_is_symmetric_and_wraps_the_short_way_round() -> void:
	var wheel_size: int = ElementWheel.ORDER.size()
	for first_index in range(wheel_size):
		for second_index in range(wheel_size):
			var first: StringName = ElementWheel.ORDER[first_index]
			var second: StringName = ElementWheel.ORDER[second_index]
			var forward: int = ElementWheel.distance(first, second)
			var backward: int = ElementWheel.distance(second, first)
			assert_int(forward).is_equal(backward)
			var raw: int = absi(first_index - second_index)
			assert_int(forward).is_equal(mini(raw, wheel_size - raw))
			assert_bool(forward >= 0 and forward <= wheel_size / 2).is_true()


func test_every_element_has_exactly_one_diametric_opposite() -> void:
	# Opposition (distance 5) is what contains_opposed_pair keys on; the wheel
	# must pair every element with exactly one opposite or the clash pairs
	# drift from canon.
	var wheel_size: int = ElementWheel.ORDER.size()
	for first: StringName in ElementWheel.ORDER:
		var opposites: Array[StringName] = []
		for second: StringName in ElementWheel.ORDER:
			if ElementWheel.distance(first, second) == wheel_size / 2:
				opposites.append(second)
		assert_int(opposites.size()).override_failure_message(
			"Element '%s' should have exactly one opposite" % first
		).is_equal(1)
		assert_bool(ElementWheel.contains_opposed_pair([first, opposites[0]])).is_true()


func test_span_of_two_elements_equals_their_distance() -> void:
	# For a pair, the outer span IS the distance; the strain ladder and the
	# clash cap both read this number, so the two notions must never diverge.
	var wheel_size: int = ElementWheel.ORDER.size()
	for first_index in range(wheel_size):
		for second_index in range(first_index + 1, wheel_size):
			var first: StringName = ElementWheel.ORDER[first_index]
			var second: StringName = ElementWheel.ORDER[second_index]
			assert_int(ElementWheel.span([first, second])).is_equal(
				ElementWheel.distance(first, second)
			)


func test_every_ratified_triad_fits_inside_the_two_step_cap() -> void:
	# The composition cap is span <= 2. Every triad ratified in ElementsData
	# must satisfy it, or CompositionResolver would clash on a canon triad.
	for triad: TriadDefinition in ElementsData.all_triads():
		assert_int(triad.elements.size()).is_equal(3)
		var triad_span: int = ElementWheel.span(triad.elements)
		assert_bool(triad_span >= 0 and triad_span <= 2).override_failure_message(
			"Ratified triad '%s' has span %d, outside the two-step cap"
			% [triad.id, triad_span]
		).is_true()
		assert_bool(ElementWheel.contains_opposed_pair(triad.elements)).is_false()
