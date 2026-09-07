extends GdUnitTestSuite
## E1.7 (#328): bounds, determinism, and what ±10 of accord is actually worth.
##
## The last group matters most. A background variation is only a good idea if its effect on the
## ratified fizzle formula is proportionate, and that is a question the design note cannot answer
## on its own — so it is checked here against the real `SkillCheckService`.

const Accord := preload("res://globals/combat/accord_math.gd")

# Mirrors of the lists their owners hold, used only as test inputs.
const WHEEL := ["suul", "bloei", "aqua", "khor", "terra", "daar", "molm", "scor", "nul", "strom"]
const PHASES := ["morning", "afternoon", "evening", "night"]
const RUNGS := ["low", "rising", "tolling", "ringing", "unprecedented"]


func test_variation_never_leaves_the_ratified_bound() -> void:
	for world_seed in [0, 1, 7919, 2147483, -55]:
		for day in range(0, 40):
			for phase in PHASES.size():
				for rung in RUNGS.size():
					for distance in range(0, Accord.MAX_WHEEL_DISTANCE + 1):
						var value: float = Accord.variation(world_seed, day, phase, rung, distance)
						assert_float(value).override_failure_message(
							"variation(%d, %d, %d, %d, %d) = %f is outside ±10"
							% [world_seed, day, phase, rung, distance, value]
						).is_between(Accord.MIN_VARIATION, Accord.MAX_VARIATION)


func test_the_same_inputs_always_give_the_same_number() -> void:
	# Forecast == resolution rests on this. A phase or weather tick may land between the two, and
	# the frozen context is only worth freezing if the function reading it cannot drift.
	for _repeat in 3:
		assert_float(Accord.variation(4242, 17, 2, 3, 1)).is_equal(
			Accord.variation(4242, 17, 2, 3, 1)
		)
	assert_float(Accord.drift(4242, 17, 2)).is_equal(Accord.drift(4242, 17, 2))


func test_drift_actually_varies_with_each_of_its_three_inputs() -> void:
	# A hash that ignored an argument would still be deterministic and still be in bounds, and
	# every other test here would still pass. This is the one that would catch it.
	var base_value: float = Accord.drift(1000, 5, 1)
	var differs_by_seed: bool = false
	var differs_by_day: bool = false
	var differs_by_phase: bool = false
	for offset in range(1, 12):
		differs_by_seed = differs_by_seed or Accord.drift(1000 + offset, 5, 1) != base_value
		differs_by_day = differs_by_day or Accord.drift(1000, 5 + offset, 1) != base_value
	for phase in PHASES.size():
		differs_by_phase = differs_by_phase or Accord.drift(1000, 5, phase) != base_value
	assert_bool(differs_by_seed).override_failure_message("drift ignores world_seed").is_true()
	assert_bool(differs_by_day).override_failure_message("drift ignores day_index").is_true()
	assert_bool(differs_by_phase).override_failure_message("drift ignores phase").is_true()


func test_drift_is_centred_rather_than_biased_one_way() -> void:
	# Not a statistical claim, just a sanity check that the wobble is a wobble: over a year of
	# days it should not act as a hidden global penalty or bonus.
	var total: float = 0.0
	var samples: int = 0
	for day in range(0, 365):
		for phase in PHASES.size():
			total += Accord.drift(99, day, phase)
			samples += 1
	var mean: float = total / float(samples)
	assert_float(absf(mean)).override_failure_message(
		"drift averages %f over a year, which is a standing modifier, not a wobble" % mean
	).is_less(0.5)


func test_the_zhavar_never_helps() -> void:
	var previous: float = 1.0
	for rung in RUNGS.size():
		var pressure: float = Accord.zhavar_pressure(rung)
		assert_float(pressure).override_failure_message(
			"rung %s must not raise accord" % RUNGS[rung]
		).is_less_equal(0.0)
		assert_float(pressure).override_failure_message(
			"each rung toward the Wound must cost at least as much as the last"
		).is_less(previous)
		previous = pressure
	assert_float(Accord.zhavar_pressure(0)).is_equal(0.0)


func test_matching_weather_helps_and_opposite_weather_hurts() -> void:
	assert_float(Accord.element_sympathy(0)).is_equal(Accord.SYMPATHY_RANGE)
	assert_float(Accord.element_sympathy(Accord.MAX_WHEEL_DISTANCE)).is_equal(
		-Accord.SYMPATHY_RANGE
	)
	# Monotonic in between, so "further round the wheel" always means "worse".
	var previous: float = INF
	for distance in range(0, Accord.MAX_WHEEL_DISTANCE + 1):
		var value: float = Accord.element_sympathy(distance)
		assert_float(value).is_less(previous)
		previous = value


func test_wheel_distance_wraps_and_treats_an_unknown_element_as_neutral() -> void:
	assert_int(Accord.wheel_distance(0, 0, 10)).is_equal(0)
	assert_int(Accord.wheel_distance(0, 5, 10)).is_equal(5)
	assert_int(Accord.wheel_distance(0, 9, 10)).override_failure_message(
		"the wheel is a ring: position 9 is one step from position 0, not nine"
	).is_equal(1)
	assert_int(Accord.wheel_distance(8, 1, 10)).is_equal(3)
	# A weather element that is not on the wheel must not be able to stop a battle.
	assert_int(Accord.wheel_distance(-1, 3, 10)).is_equal(3)


func test_variation_for_resolves_ids_and_survives_an_unknown_one() -> void:
	var resolved: float = Accord.variation_for(
		12, &"evening", &"tolling", &"molm", &"molm", 77, WHEEL, PHASES, RUNGS
	)
	var direct: float = Accord.variation(77, 12, 2, 2, 0)
	assert_float(resolved).is_equal(direct)

	var unknown: float = Accord.variation_for(
		12, &"not_a_phase", &"not_a_rung", &"not_an_element", &"molm", 77, WHEEL, PHASES, RUNGS
	)
	assert_float(unknown).override_failure_message(
		"unknown ids must fall back to neutral, not produce NAN or throw"
	).is_between(Accord.MIN_VARIATION, Accord.MAX_VARIATION)


func test_the_breakdown_sums_to_the_total_and_reports_clamping() -> void:
	var parts: Dictionary = Accord.variation_breakdown(5, 5, 0, 4, 5)
	assert_float(
		float(parts["drift"]) + float(parts["zhavar"]) + float(parts["sympathy"])
	).is_equal_approx(float(parts["raw"]), 0.0001)
	assert_float(float(parts["total"])).is_equal(
		clampf(float(parts["raw"]), Accord.MIN_VARIATION, Accord.MAX_VARIATION)
	)


func test_accord_at_clamps_to_the_legal_range() -> void:
	assert_float(Accord.accord_at(95.0, 10.0, 10.0)).is_equal(100.0)
	assert_float(Accord.accord_at(5.0, -10.0, -10.0)).is_equal(0.0)
	assert_float(Accord.accord_at(70.0, -5.0, 3.0)).is_equal(68.0)


func test_saturation_lint_fires_exactly_where_the_clamp_starts_swallowing_intent() -> void:
	assert_array(Accord.saturation_warnings(80.0, -5.0, 5.0)).override_failure_message(
		"a location with headroom on both sides must not warn"
	).is_empty()

	var high: PackedStringArray = Accord.saturation_warnings(95.0, 0.0, 5.0, "dom")
	assert_int(high.size()).is_equal(1)
	assert_str(high[0]).contains("saturates high")
	assert_str(high[0]).contains("dom")

	var low: PackedStringArray = Accord.saturation_warnings(4.0, -6.0, 0.0, "wound-lip")
	assert_int(low.size()).is_equal(1)
	assert_str(low[0]).contains("saturates low")

	# A location can be pinned at both ends at once only if the band is impossible; report both.
	assert_int(Accord.saturation_warnings(50.0, -60.0, 60.0).size()).is_equal(2)


func test_ten_points_of_accord_swings_a_refrain_far_harder_than_a_note() -> void:
	# The sweep the design note is written against, run against the ratified formula rather than
	# quoted from it. `magnitude_mult` multiplies the whole base, so the SAME ±10 of background
	# variation is a rounding error on a Note and a swing on a Refrain. This is the measurement
	# that makes ±10 provisional rather than settled.
	var swings: Dictionary = _swings(100.0, 90.0)
	assert_float(float(swings["note"])).is_less(float(swings["phrase"]))
	assert_float(float(swings["phrase"])).is_less(float(swings["song"]))
	assert_float(float(swings["song"])).is_less(float(swings["refrain"]))
	assert_float(float(swings["refrain"])).override_failure_message(
		"a Refrain should feel the weather far more than a Note does; measured %s" % str(swings)
	).is_greater(float(swings["note"]) * 2.5)


func test_the_fizzle_cap_makes_accord_inert_for_big_castings_in_a_thinned_zone() -> void:
	# A known and deliberate consequence, pinned so it cannot change silently. `fizzle_percent`
	# clamps at 95, and in a thinned zone a Song or Refrain is already pinned there — so ±10 of
	# background variation changes nothing at all for exactly the castings, in exactly the
	# places, where the world being hostile ought to matter most.
	#
	# It is recorded here rather than fixed because fixing it means moving the ratified cap,
	# which is not this issue's to move. E6.1 should decide whether that is acceptable.
	var thinned: Dictionary = _swings(40.0, 30.0)
	assert_float(float(thinned["song"])).override_failure_message(
		"if the cap ever stops binding here, the design note's caveat is out of date: %s"
		% str(thinned)
	).is_equal(0.0)
	assert_float(float(thinned["refrain"])).is_equal(0.0)
	# Small castings still register, which is why the effect is easy to miss in play.
	assert_float(float(thinned["note"])).is_greater(0.0)
	assert_float(float(thinned["phrase"])).is_greater(0.0)


## Fizzle-percent difference between two accord values, per magnitude.
func _swings(high_accord: float, low_accord: float) -> Dictionary:
	var service := SkillCheckService.new()
	var swings: Dictionary = {}
	for magnitude: String in ["note", "phrase", "song", "refrain"]:
		swings[magnitude] = absf(
			service.fizzle_percent(low_accord, "single", 0, magnitude, 2, false, "")
			- service.fizzle_percent(high_accord, "single", 0, magnitude, 2, false, "")
		)
	service.free()
	return swings
