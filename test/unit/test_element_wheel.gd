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
