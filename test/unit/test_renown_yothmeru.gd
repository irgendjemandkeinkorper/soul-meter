extends GdUnitTestSuite
## Yothmeru on Renown — RFC-0007, docs/architecture-dramgid.md §3.7.
##
## The two things this suite exists to protect: the tier ladders match the RFC
## exactly at their boundaries, and adding Yothmeru did not move the Reputation
## and Infamy totals the tavern recruit gates read.

const REP_GATE := 10.0  ## GameState._make_member: Korrath Ninefold
const INFAMY_GATE := 8.0  ## GameState._make_member: Maura Greyfen

var _saved: Dictionary = {}
var _saved_party: Array[PartyMember] = []


func before_test() -> void:
	_saved = Renown.to_dict()
	_saved_party = GameState.party.duplicate()
	Renown.from_dict({})


func after_test() -> void:
	GameState.party = _saved_party
	Renown.from_dict(_saved)


## The protagonist is where the multipliers are read from, so a test that cares
## about scaling states the attributes rather than inheriting whatever New Game
## happened to build.
func _given_protagonist(doctrine: int, decorum: int) -> void:
	var member := PartyMember.new()
	member.id = GameState.PROTAGONIST_ID
	member.display_name = "Test Subject"
	member.attributes = {
		"doctrine": doctrine,
		"decorum": decorum,
	}
	var party: Array[PartyMember] = [member]
	GameState.party = party


# --- tier ladders (RFC-0007 §3) ---------------------------------------------


func test_karma_tiers_match_the_rfc_at_every_boundary() -> void:
	# Floors are inclusive, so each boundary belongs to the tier ABOVE it. The
	# RFC's written ranges share endpoints ("-250 to -50", "-50 to 50"); this is
	# the reading that partitions them without overlap.
	var expected := {
		-1000.0: "Damned", -601.0: "Damned",
		-600.0: "Cruel", -251.0: "Cruel",
		-250.0: "Troubled", -51.0: "Troubled",
		-50.0: "Uncertain", 0.0: "Uncertain", 49.0: "Uncertain",
		50.0: "Upright", 249.0: "Upright",
		250.0: "Virtuous", 599.0: "Virtuous",
		600.0: "Exalted", 1000.0: "Exalted",
	}
	for score: float in expected:
		_given_protagonist(10, 10)  # scale 1.0, so base lands unchanged
		Renown.from_dict({})
		Renown.gain_karma("player", score, "boundary probe")
		assert_str(Renown.karma_tier()).override_failure_message(
			"Karma %s should read %s" % [score, expected[score]]
		).is_equal(str(expected[score]))


func test_fame_tiers_match_the_rfc_at_every_boundary() -> void:
	var expected := {
		0.0: "Unknown", 49.0: "Unknown",
		50.0: "Whispered", 199.0: "Whispered",
		200.0: "Known", 449.0: "Known",
		450.0: "Renowned", 749.0: "Renowned",
		750.0: "Legendary", 1000.0: "Legendary",
	}
	for score: float in expected:
		Renown.from_dict({})
		Renown.gain_reputation("player", score, "boundary probe")
		assert_str(Renown.fame_tier()).override_failure_message(
			"Fame %s should read %s" % [score, expected[score]]
		).is_equal(str(expected[score]))


func test_karma_tier_offset_is_the_signed_distance_from_uncertain() -> void:
	# RFC-0007 §6: Uncertain 0, Upright/Troubled ±1, Virtuous/Cruel ±2,
	# Exalted/Damned ±3 — the value Sway and Bellow read.
	var expected := {
		-900.0: -3, -400.0: -2, -100.0: -1, 0.0: 0, 100.0: 1, 400.0: 2, 900.0: 3,
	}
	for score: float in expected:
		_given_protagonist(10, 10)
		Renown.from_dict({})
		Renown.gain_karma("player", score, "offset probe")
		assert_int(Renown.karma_tier_offset()).override_failure_message(
			"Karma %s should offset by %s" % [score, expected[score]]
		).is_equal(int(expected[score]))


func test_a_fresh_ledger_reads_uncertain_and_unknown() -> void:
	assert_float(Renown.karma_total()).is_equal_approx(0.0, 0.001)
	assert_str(Renown.karma_tier()).is_equal("Uncertain")
	assert_int(Renown.karma_tier_offset()).is_equal(0)
	assert_str(Renown.fame_tier()).is_equal("Unknown")


# --- the shift formula (RFC-0007 §4) ----------------------------------------


func test_karma_applies_the_doctrine_multiplier_and_records_both_figures() -> void:
	_given_protagonist(4, 2)
	var event := Renown.gain_karma("player", -40.0, "Betrayed an ally")
	# base × Doctrine / 10 — the RFC's formula, as written.
	assert_float(event.base).is_equal_approx(-40.0, 0.001)
	assert_float(event.applied).is_equal_approx(-16.0, 0.001)
	assert_float(Renown.karma_total()).is_equal_approx(-16.0, 0.001)


func test_karma_is_clamped_to_the_rfc_range() -> void:
	_given_protagonist(10, 10)
	Renown.gain_karma("player", 5000.0, "Saved everyone, repeatedly")
	assert_float(Renown.karma_total()).is_equal_approx(Renown.KARMA_MAX, 0.001)
	Renown.gain_karma("player", -50000.0, "Undid all of it")
	assert_float(Renown.karma_total()).is_equal_approx(Renown.KARMA_MIN, 0.001)


func test_fame_shift_is_recorded_with_the_decorum_and_witness_multipliers() -> void:
	_given_protagonist(2, 5)
	var event := Renown.gain_reputation("player", 30.0, "Generous public act", "dom", 0.5)
	# abs(base) × witness_factor × Decorum / 10.
	assert_float(event.fame_shift).is_equal_approx(30.0 * 0.5 * 0.5, 0.001)
	assert_float(event.witness_factor).is_equal_approx(0.5, 0.001)


func test_an_unwitnessed_act_still_moves_the_meter_but_produces_no_fame() -> void:
	# RFC-0007's banking case: genuinely virtuous, structurally unwitnessed.
	_given_protagonist(5, 5)
	var event := Renown.gain_reputation("player", 25.0, "Banked Harmony", "dom", 0.0)
	assert_float(event.fame_shift).is_equal_approx(0.0, 0.001)
	assert_float(Renown.reputation()).is_equal_approx(25.0, 0.001)


func test_infamy_records_a_positive_fame_shift_from_a_negative_act() -> void:
	# Fame is magnitude only, "independent of Karma's sign" (RFC-0007 §3).
	_given_protagonist(2, 10)
	var event := Renown.gain_infamy("player", 40.0, "Murdered an innocent")
	assert_float(event.fame_shift).is_equal_approx(40.0, 0.001)


func test_a_missing_protagonist_scales_by_one_rather_than_zero() -> void:
	# An unrecorded consequence is worse than an unscaled one.
	GameState.party.clear()
	var event := Renown.gain_karma("player", 40.0, "Saved a stranger")
	assert_float(event.applied).is_equal_approx(40.0, 0.001)


func test_an_unmigrated_character_scales_by_the_attribute_floor() -> void:
	# Doctrine is new and has no legacy name, so a pre-v8 character reads 0 for
	# it. Owner ruling 5 puts migrated characters at the floor; reading 0 would
	# freeze Karma at zero instead of scaling it.
	var member := PartyMember.new()
	member.id = GameState.PROTAGONIST_ID
	member.attributes = {"forge": 3, "anchor": 3}
	var party: Array[PartyMember] = [member]
	GameState.party = party
	var event := Renown.gain_karma("player", 100.0, "Pre-migration act")
	var floor_scale := float(DramgidSchema.ATTRIBUTE_FLOOR) / Renown.ATTRIBUTE_SCALE_DIVISOR
	assert_float(event.applied).is_equal_approx(100.0 * floor_scale, 0.001)


# --- the gates must not move ------------------------------------------------


func test_reputation_and_infamy_totals_are_the_authored_values() -> void:
	# The load-bearing guarantee of §3.7: Yothmeru must not rescale the meters
	# the recruit gates read. Decorum 2 would otherwise shrink these by 5x.
	_given_protagonist(2, 2)
	Renown.gain_reputation("player", 12.0, "Made the Deep Trial answer to both lines", "dom")
	Renown.gain_infamy("player", 5.0, "Threatened a grove-tender", "field")
	assert_float(Renown.reputation()).is_equal_approx(12.0, 0.001)
	assert_float(Renown.infamy()).is_equal_approx(5.0, 0.001)


func test_the_shipped_recruit_gates_still_open_on_their_authored_grants() -> void:
	# Dom's authored reputation grants at their lowest useful Decorum.
	_given_protagonist(2, 2)
	Renown.gain_reputation("player", 12.0, "Made the Deep Trial answer to both lines", "dom")
	assert_bool(Renown.reputation() >= REP_GATE).override_failure_message(
		"Korrath Ninefold's gate no longer opens on Dom's authored grant"
	).is_true()

	Renown.from_dict({})
	Renown.gain_infamy("player", 5.0, "Threatened a grove-tender", "field")
	Renown.gain_infamy("player", 4.0, "Took living Loam specimens", "field")
	assert_bool(Renown.infamy() >= INFAMY_GATE).override_failure_message(
		"Maura Greyfen's gate no longer opens on the authored infamy grants"
	).is_true()


func test_fame_is_reputation_plus_infamy() -> void:
	_given_protagonist(2, 2)
	Renown.gain_reputation("player", 30.0, "a", "dom")
	Renown.gain_infamy("player", 25.0, "b", "dom")
	assert_float(Renown.fame()).is_equal_approx(55.0, 0.001)


func test_karma_is_independent_of_the_other_two_meters() -> void:
	_given_protagonist(10, 10)
	Renown.gain_karma("player", -150.0, "Murdered an innocent")
	assert_float(Renown.reputation()).is_equal_approx(0.0, 0.001)
	assert_float(Renown.infamy()).is_equal_approx(0.0, 0.001)
	assert_float(Renown.fame()).is_equal_approx(0.0, 0.001)


# --- decay (RFC-0007 §5) ----------------------------------------------------


func test_only_the_extreme_tiers_decay() -> void:
	for score: float in [-500.0, -100.0, 0.0, 100.0, 500.0]:
		_given_protagonist(10, 10)
		Renown.from_dict({})
		Renown.gain_karma("player", score, "settle")
		Renown.decay_one_day(-1)
		assert_float(Renown.karma_total()).override_failure_message(
			"Karma %s is not an extreme tier and must not erode" % score
		).is_equal_approx(score, 0.001)


func test_damned_and_exalted_drift_toward_their_boundary() -> void:
	_given_protagonist(10, 10)
	Renown.gain_karma("player", 800.0, "Exalted")
	Renown.decay_one_day(-1)
	var after := Renown.karma_total()
	assert_bool(after < 800.0).override_failure_message("Exalted should decay").is_true()
	assert_bool(after > 600.0).override_failure_message(
		"decay must never cross back past the boundary"
	).is_true()

	Renown.from_dict({})
	Renown.gain_karma("player", -800.0, "Damned")
	Renown.decay_one_day(-1)
	var below := Renown.karma_total()
	assert_bool(below > -800.0).override_failure_message("Damned should decay").is_true()
	assert_bool(below < -600.0).override_failure_message(
		"decay must never cross back past the boundary"
	).is_true()


func test_decay_is_asymptotic_and_never_reaches_the_boundary() -> void:
	_given_protagonist(10, 10)
	Renown.gain_karma("player", 900.0, "Exalted")
	for _day: int in 400:
		Renown.decay_one_day(-1)
	assert_bool(Renown.karma_total() > 600.0).override_failure_message(
		"400 days of decay crossed the Exalted boundary; it must only approach it"
	).is_true()
	assert_str(Renown.karma_tier()).is_equal("Exalted")


func test_seven_days_of_decay_equals_the_weekly_fraction() -> void:
	# The per-day rate is defined so that seven of them compound to exactly
	# DECAY_FRACTION_PER_WEEK of the excess — the unit the RFC states.
	_given_protagonist(10, 10)
	Renown.gain_karma("player", 1000.0, "Exalted")
	var excess := 1000.0 - 600.0
	for _day: int in Renown.DAYS_PER_WEEK:
		Renown.decay_one_day(-1)
	var expected := 600.0 + excess * (1.0 - Renown.DECAY_FRACTION_PER_WEEK)
	assert_float(Renown.karma_total()).is_equal_approx(expected, 0.01)


func test_legendary_fame_decays_without_touching_the_gated_meters() -> void:
	_given_protagonist(10, 10)
	Renown.gain_reputation("player", 900.0, "Legendary")
	Renown.decay_one_day(-1)
	assert_bool(Renown.fame() < 900.0).override_failure_message(
		"Legendary Fame should decay"
	).is_true()
	assert_bool(Renown.fame() > 750.0).is_true()
	# The decay rides its own ledger kind, so the meter the gates read is intact.
	assert_float(Renown.reputation()).is_equal_approx(900.0, 0.001)


func test_the_same_world_day_only_decays_once() -> void:
	_given_protagonist(10, 10)
	Renown.gain_karma("player", 900.0, "Exalted")
	Renown.decay_one_day(4)
	var after_first := Renown.karma_total()
	Renown.decay_one_day(4)
	assert_float(Renown.karma_total()).override_failure_message(
		"a repeated call for the same world day double-decayed"
	).is_equal_approx(after_first, 0.001)
	Renown.decay_one_day(5)
	assert_bool(Renown.karma_total() < after_first).is_true()


func test_decay_appends_to_the_ledger_rather_than_editing_a_total() -> void:
	_given_protagonist(10, 10)
	Renown.gain_karma("player", 900.0, "Exalted")
	Renown.decay_one_day(-1)
	var karma_events := Renown.why(&"karma", 5)
	assert_int(karma_events.size()).is_equal(2)
	assert_str(karma_events[0].actor).is_equal(Renown.DECAY_ACTOR)
	assert_bool(karma_events[0].delta < 0.0).is_true()


# --- WorldClock wiring ------------------------------------------------------


func test_the_clock_announces_a_day_change_only_when_the_day_rolls_over() -> void:
	var clock := WorldClock
	var saved := clock.to_dict()
	clock.reset()
	var days: Array[int] = []
	var on_day := func(_previous: int, current: int) -> void: days.append(current)
	clock.day_changed.connect(on_day)

	for _phase_step: int in WorldClock.PHASES.size():
		clock.advance("test")
	assert_array(days).override_failure_message(
		"four phase advances are exactly one day"
	).is_equal([1] as Array[int])

	clock.day_changed.disconnect(on_day)
	clock.from_dict(saved)


func test_restoring_the_clock_does_not_look_like_a_day_passing() -> void:
	# Loading a save must not age the world — decay is a consequence of play.
	var clock := WorldClock
	var saved := clock.to_dict()
	var fired := [false]
	var on_day := func(_previous: int, _current: int) -> void: fired[0] = true
	clock.day_changed.connect(on_day)

	clock.from_dict({"phase": "night", "phase_count": 8})
	clock.reset()
	assert_bool(fired[0]).override_failure_message(
		"from_dict()/reset() emitted day_changed; only advance() may"
	).is_false()

	clock.day_changed.disconnect(on_day)
	clock.from_dict(saved)


# --- persistence ------------------------------------------------------------


func test_a_round_trip_preserves_every_axis() -> void:
	_given_protagonist(4, 3)
	Renown.gain_reputation("player", 30.0, "a", "dom", 0.5)
	Renown.gain_infamy("player", 12.0, "b", "dom")
	Renown.gain_karma("player", -200.0, "c", "dom")
	var before := {
		"reputation": Renown.reputation(),
		"infamy": Renown.infamy(),
		"karma": Renown.karma_total(),
		"fame": Renown.fame(),
	}
	var payload := Renown.to_dict()

	Renown.from_dict({})
	Renown.from_dict(payload)

	assert_float(Renown.reputation()).is_equal_approx(float(before["reputation"]), 0.001)
	assert_float(Renown.infamy()).is_equal_approx(float(before["infamy"]), 0.001)
	assert_float(Renown.karma_total()).is_equal_approx(float(before["karma"]), 0.001)
	assert_float(Renown.fame()).is_equal_approx(float(before["fame"]), 0.001)


func test_a_round_trip_preserves_the_recorded_scaling_figures() -> void:
	_given_protagonist(4, 3)
	Renown.gain_reputation("player", 30.0, "a", "dom", 0.5)
	var before: RenownEvent = Renown.history(1)[0]

	Renown.from_dict(Renown.to_dict())
	var after: RenownEvent = Renown.history(1)[0]

	assert_float(after.base).is_equal_approx(before.base, 0.001)
	assert_float(after.applied).is_equal_approx(before.applied, 0.001)
	assert_float(after.fame_shift).is_equal_approx(before.fame_shift, 0.001)
	assert_float(after.witness_factor).is_equal_approx(before.witness_factor, 0.001)


func test_a_pre_yothmeru_save_loads_with_its_totals_intact() -> void:
	# Rows written before Yothmeru carry no base/applied/fame_shift keys. The
	# meters they feed must be exactly what they were, or every existing save
	# would come back with different recruit gates.
	var legacy := {
		"next_order": 2,
		"log": [
			{
				"actor": "player", "kind": "reputation", "delta": 12.0,
				"cause": "Cleared the first ledge", "scene": "dom", "at": 1, "order": 0,
			},
			{
				"actor": "player", "kind": "infamy", "delta": 9.0,
				"cause": "Took living Loam specimens", "scene": "field", "at": 2, "order": 1,
			},
		],
	}
	Renown.from_dict(legacy)
	assert_float(Renown.reputation()).is_equal_approx(12.0, 0.001)
	assert_float(Renown.infamy()).is_equal_approx(9.0, 0.001)
	assert_float(Renown.karma_total()).is_equal_approx(0.0, 0.001)
	# base/applied default to the delta, which is what actually happened.
	var restored: RenownEvent = Renown.history(2)[1]
	assert_float(restored.base).is_equal_approx(12.0, 0.001)
	assert_float(restored.applied).is_equal_approx(12.0, 0.001)


func test_a_round_trip_does_not_replay_a_day_that_was_already_decayed() -> void:
	_given_protagonist(10, 10)
	Renown.gain_karma("player", 900.0, "Exalted")
	Renown.decay_one_day(3)
	var after_decay := Renown.karma_total()

	Renown.from_dict(Renown.to_dict())
	Renown.decay_one_day(3)
	assert_float(Renown.karma_total()).override_failure_message(
		"loading and re-ticking the same world day decayed twice"
	).is_equal_approx(after_decay, 0.001)


func test_why_reports_karma_reasons_newest_first() -> void:
	_given_protagonist(10, 10)
	Renown.gain_karma("player", -20.0, "Casual public cruelty")
	Renown.gain_karma("player", 25.0, "Banked Harmony to repair a zone")
	var reasons := Renown.why(&"karma", 2)
	assert_int(reasons.size()).is_equal(2)
	assert_str(reasons[0].cause).is_equal("Banked Harmony to repair a zone")
	assert_str(reasons[1].cause).is_equal("Casual public cruelty")


func test_an_unknown_kind_in_a_save_is_replayed_rather_than_dropped() -> void:
	# The ledger is append-only: a row we cannot classify still has to survive.
	Renown.from_dict({
		"next_order": 1,
		"log": [{
			"actor": "player", "kind": "not-a-meter", "delta": 7.0,
			"cause": "forward-compat probe", "scene": "dom", "at": 1, "order": 0,
		}],
	})
	assert_int(Renown.history().size()).is_equal(1)
	assert_float(Renown.reputation()).is_equal_approx(7.0, 0.001)
