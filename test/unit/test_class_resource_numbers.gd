extends GdUnitTestSuite
## B11 (#234): pins the class-resource numeric sweep.
##
## Two jobs. First, the sweep's models are PURE and DETERMINISTIC — the tables in
## `docs/class-resources-numbers.md` are only worth reading if re-running the tool
## reproduces them exactly. Second, the doc and the shipped constants cannot
## drift apart: every PROVISIONAL constant is asserted to appear in the doc's
## summary table with its live value, so changing a number without updating the
## review packet fails here.

const Sweep := preload("res://tools/class_resource_sweep.gd")
const NUMBERS_DOC := "res://docs/class-resources-numbers.md"


func test_the_models_are_deterministic() -> void:
	# Run every model twice. Any RNG, any engine read, any dictionary-order
	# dependence shows up as a mismatch here rather than as a doc that quietly
	# stops matching the tool.
	assert_dict(Sweep.scar_bank(10, 1.0, 5)).is_equal(Sweep.scar_bank(10, 1.0, 5))
	assert_dict(Sweep.token_bank(10, 35.0, 3, 0)).is_equal(Sweep.token_bank(10, 35.0, 3, 0))
	assert_dict(Sweep.hunger_curve(10, 5)).is_equal(Sweep.hunger_curve(10, 5))
	assert_dict(Sweep.balance_tradeoff(9.0, 35.0, 1.25)) \
		.is_equal(Sweep.balance_tradeoff(9.0, 35.0, 1.25))
	assert_dict(Sweep.table_stats([1, 1, 2, 2, 3, 6])).is_equal(Sweep.table_stats([1, 1, 2, 2, 3, 6]))


func test_the_scar_bank_matches_the_documented_row() -> void:
	# docs/class-resources-numbers.md §3, the "1.0 hits/round, 10 rounds" row.
	var row := Sweep.scar_bank(10, 1.0, 5)
	assert_int(int(row["banked"])).is_equal(5)
	assert_int(int(row["wasted"])).is_equal(5)
	assert_int(int(row["capped_at_round"])).is_equal(5)

	var proposed := Sweep.scar_bank(10, 1.0, 3)
	assert_int(int(proposed["capped_at_round"])).override_failure_message(
		"the case for MAX_SCARS 3 is that it is REACHED under pressure"
	).is_equal(3)

	# The shipped cap does not bind at the survivable hit rate — that is the
	# finding the recommendation rests on.
	var occasional := Sweep.scar_bank(10, 0.5, 5)
	assert_int(int(occasional["wasted"])).is_zero()
	assert_int(int(occasional["capped_at_round"])).is_equal(10)


func test_the_hunger_curve_matches_the_documented_table() -> void:
	# §4. The tick in round r is min(r - 1, cap), so the totals are exact.
	assert_int(int(Sweep.hunger_curve(10, 3)["total_dot"])).is_equal(24)
	assert_int(int(Sweep.hunger_curve(10, 5)["total_dot"])).is_equal(35)
	assert_int(int(Sweep.hunger_curve(14, 5)["total_dot"])).is_equal(55)
	assert_int(int(Sweep.hunger_curve(14, 8)["total_dot"])).is_equal(76)

	# The recommendation: at cap 3 the DoT never finishes the top of the enemy
	# HP band inside a normal battle; at the shipped 5 it does.
	assert_int(int(Sweep.hunger_curve(10, 3)["kills_36hp_by_round"])).is_zero()
	assert_int(int(Sweep.hunger_curve(14, 5)["kills_36hp_by_round"])).is_equal(11)


func test_token_bank_shows_the_class_is_inert_at_hub_accord() -> void:
	# §7. 9% is the Song fizzle at accord 95 (Dom) from the ratified formula.
	assert_int(int(Sweep.token_bank(10, 9.0, 3, 0)["banked"])).override_failure_message(
		"a Flamebinder banking tokens in Dom would invalidate the §7 flag"
	).is_zero()
	assert_int(int(Sweep.token_bank(10, 35.0, 3, 0)["banked"])).is_equal(3)
	assert_int(int(Sweep.token_bank(10, 35.0, 3, 0)["wasted"])).is_zero()
	assert_int(int(Sweep.token_bank(10, 95.0, 3, 0)["wasted"])).is_equal(6)


func test_the_balance_tradeoff_splits_small_and_large_magnitudes() -> void:
	# §7's table: at the shipped 1.25 / -15 the small magnitudes are worth
	# going Unbalanced for and the large ones are not.
	assert_bool(bool(Sweep.balance_tradeoff(3.0, 10.0, 1.25)["worth_it"])).is_true()
	assert_bool(bool(Sweep.balance_tradeoff(5.0, 20.0, 1.25)["worth_it"])).is_true()
	assert_bool(bool(Sweep.balance_tradeoff(9.0, 35.0, 1.25)["worth_it"])).is_false()
	assert_bool(bool(Sweep.balance_tradeoff(14.0, 55.0, 1.25)["worth_it"])).is_false()

	# The clamp flag: once both sides sit at MAX_EFFECTIVE_PERCENT the accord
	# penalty stops costing anything and the multiplier is free.
	assert_bool(bool(Sweep.balance_tradeoff(95.0, 95.0, 1.25)["worth_it"])).is_true()


func test_the_attribution_table_stats_match_the_documented_candidates() -> void:
	var shipped := Sweep.table_stats([1, 2, 3])
	assert_int(int(shipped["spread"])).is_equal(2)
	assert_float(float(shipped["mean"])).is_equal(2.0)

	var tailed := Sweep.table_stats([1, 1, 2, 2, 3, 6])
	assert_int(int(tailed["min"])).is_equal(1)
	assert_int(int(tailed["max"])).is_equal(6)
	assert_int(int(tailed["spread"])).is_equal(5)
	assert_float(float(tailed["mean"])).is_equal(2.5)

	assert_dict(Sweep.table_stats([])).is_equal(
		{"rows": 0, "min": 0, "max": 0, "mean": 0.0, "spread": 0}
	)


func test_the_shipped_table_is_what_the_sweep_says_it_is() -> void:
	# The doc's §6 stats describe OfshutjeAttribution.EFFECT_TABLE, so read the
	# real table rather than a copy that could fall out of step with it.
	var bonuses: Array = []
	for row: Dictionary in OfshutjeAttribution.EFFECT_TABLE:
		bonuses.append(int(row.get("bonus_damage", 0)))
	assert_dict(Sweep.table_stats(bonuses)).is_equal(Sweep.table_stats([1, 2, 3]))


func test_every_provisional_constant_is_in_the_review_packet() -> void:
	# The doc is the owner-review packet for these numbers. A constant that
	# changes without its row changing leaves the packet lying, so pin the pair.
	var file := FileAccess.open(NUMBERS_DOC, FileAccess.READ)
	assert_object(file).override_failure_message(
		"%s is missing — B11's review packet is the deliverable" % NUMBERS_DOC
	).is_not_null()
	var doc := file.get_as_text()
	file.close()

	var shipped: Dictionary = {
		"`IronbrandScars.MAX_SCARS`": str(IronbrandScars.MAX_SCARS),
		"`VicoarInstructiveFailure.MAX_TOKENS`": str(VicoarInstructiveFailure.MAX_TOKENS),
		"`VhorrHunger.MAX_HUNGER`": str(VhorrHunger.MAX_HUNGER),
		"`VhorrHunger.BREATH_REFUND`": str(VhorrHunger.BREATH_REFUND),
		"`HaerenNameLedger.BREATH_REFUND`": str(HaerenNameLedger.BREATH_REFUND),
		"`StuidClarity.MAX_CLARITY`": str(StuidClarity.MAX_CLARITY),
		"`PazzahLedger.MAX_ENTRIES`": str(PazzahLedger.MAX_ENTRIES),
		"`IzhakelThreads.MAX_THREADS`": str(IzhakelThreads.MAX_THREADS),
		"`MaiiamBalance.UNBALANCED_AFTER_STREAK`": str(MaiiamBalance.UNBALANCED_AFTER_STREAK),
		"`MaiiamBalance.UNBALANCED_DAMAGE_MULTIPLIER`":
			str(MaiiamBalance.UNBALANCED_DAMAGE_MULTIPLIER),
		"`MaiiamBalance.UNBALANCED_FIZZLE_INTEGRITY_PENALTY`":
			str(MaiiamBalance.UNBALANCED_FIZZLE_INTEGRITY_PENALTY),
		"`SkillCheckService.FIZZLE_FLOOR_PERCENT`": str(SkillCheckService.FIZZLE_FLOOR_PERCENT),
	}
	for constant: String in shipped:
		var row := "| %s | %s |" % [constant, shipped[constant]]
		assert_bool(doc.contains(row)).override_failure_message(
			"%s no longer matches its row in %s — expected a line containing '%s'"
			% [constant, NUMBERS_DOC, row]
		).is_true()

	# The table's row count is asserted separately: it is a size, not a value.
	assert_bool(doc.contains(
		"| `OfshutjeAttribution.EFFECT_TABLE` | %d rows |" % OfshutjeAttribution.EFFECT_TABLE.size()
	)).is_true()


func test_every_shipped_constant_sits_inside_its_swept_range() -> void:
	# A constant moved outside the grid the tool sweeps makes the doc's tables
	# silently irrelevant to the live value.
	_assert_swept(IronbrandScars.MAX_SCARS, Sweep.SCAR_CAPS, "MAX_SCARS")
	_assert_swept(VicoarInstructiveFailure.MAX_TOKENS, Sweep.TOKEN_CAPS, "MAX_TOKENS")
	_assert_swept(VhorrHunger.MAX_HUNGER, Sweep.HUNGER_CAPS, "MAX_HUNGER")
	_assert_swept(StuidClarity.MAX_CLARITY, Sweep.CLARITY_CAPS, "MAX_CLARITY")
	_assert_swept(PazzahLedger.MAX_ENTRIES, Sweep.ENTRY_CAPS, "MAX_ENTRIES")
	_assert_swept(IzhakelThreads.MAX_THREADS, Sweep.THREAD_CAPS, "MAX_THREADS")
	_assert_swept(VhorrHunger.BREATH_REFUND, Sweep.BREATH_REFUNDS, "VhorrHunger.BREATH_REFUND")
	_assert_swept(
		HaerenNameLedger.BREATH_REFUND, Sweep.BREATH_REFUNDS, "HaerenNameLedger.BREATH_REFUND"
	)
	assert_array(Sweep.BALANCE_MULTIPLIERS).contains(
		[MaiiamBalance.UNBALANCED_DAMAGE_MULTIPLIER]
	)
	assert_array(Sweep.BALANCE_PENALTIES).contains(
		[MaiiamBalance.UNBALANCED_FIZZLE_INTEGRITY_PENALTY]
	)


func _assert_swept(value: int, candidates: Array, label: String) -> void:
	assert_bool(candidates.has(value)).override_failure_message(
		"%s is %d, which tools/class_resource_sweep.gd never sweeps (%s)"
		% [label, value, candidates]
	).is_true()
