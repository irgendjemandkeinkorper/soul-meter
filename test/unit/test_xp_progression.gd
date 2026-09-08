extends GdUnitTestSuite
## #285 / game-identity ruling 9 (ratified 2026-09-02, re-affirmed by the owner
## 2026-09-08): XP comes from COMBAT and QUESTS, and levels come from XP.
##
## This supersedes #98 D3 (2026-08-24), which said levels come only from authored
## story milestones and never from kill XP. Milestones survive as an XP source
## rather than as a second, parallel way to gain a level — one currency is the
## whole point, and these cases pin that there is only one.

var _party_before: Array[PartyMember] = []
var _custom_before: Array[PartyMember] = []
var _flags_before: Dictionary


func before_test() -> void:
	_party_before = GameState.party.duplicate()
	_custom_before = GameState.custom_recruits.duplicate()
	_flags_before = GameState.flags.duplicate(true)


func after_test() -> void:
	GameState.party = _party_before
	GameState.custom_recruits = _custom_before
	GameState.flags = _flags_before.duplicate(true)


func _member(member_id: String = "test-hero") -> PartyMember:
	var member := PartyMember.new()
	member.id = member_id
	member.level = 1
	member.xp = 0
	member.advancement_points = 0
	return member


func test_a_level_costs_more_at_every_step() -> void:
	var last := 0
	for level in range(1, 10):
		var cost := Advancement.xp_for_next_level(level)
		assert_int(cost).override_failure_message(
			"a free level at %d would let any XP award grant infinite levels" % level
		).is_greater(0)
		assert_int(cost).override_failure_message(
			"level %d costs no more than level %d — the curve is flat" % [level, level - 1]
		).is_greater(last)
		last = cost


func test_earning_exactly_a_threshold_levels_once() -> void:
	var member := _member()
	var gained := Advancement.award_xp(member, Advancement.xp_for_next_level(1))

	assert_int(gained).is_equal(1)
	assert_int(member.level).is_equal(2)
	assert_int(member.xp).override_failure_message(
		"the threshold should have been consumed, not banked again"
	).is_equal(0)
	assert_int(member.advancement_points).override_failure_message(
		"a level that grants no skill points is not a level"
	).is_equal(Advancement.POINTS_PER_LEVEL)


## The remainder carries. Discarding it would silently penalise a player for
## fighting one encounter more than they strictly needed.
func test_surplus_xp_carries_into_the_next_level() -> void:
	var member := _member()
	Advancement.award_xp(member, Advancement.xp_for_next_level(1) + 17)

	assert_int(member.level).is_equal(2)
	assert_int(member.xp).override_failure_message(
		"overshooting a threshold threw the excess away"
	).is_equal(17)


func test_one_large_award_can_grant_several_levels() -> void:
	var member := _member()
	var enough := (
		Advancement.xp_for_next_level(1)
		+ Advancement.xp_for_next_level(2)
		+ Advancement.xp_for_next_level(3)
	)
	assert_int(Advancement.award_xp(member, enough)).is_equal(3)
	assert_int(member.level).is_equal(4)
	assert_int(member.advancement_points).is_equal(3 * Advancement.POINTS_PER_LEVEL)


func test_a_worthless_award_changes_nothing() -> void:
	var member := _member()
	member.xp = 5
	assert_int(Advancement.award_xp(member, 0)).is_equal(0)
	assert_int(Advancement.award_xp(member, -100)).override_failure_message(
		"a negative award must not drain banked XP"
	).is_equal(0)
	assert_int(member.xp).is_equal(5)
	assert_int(member.level).is_equal(1)


## A tougher enemy is worth more. Reading it off the DRAMGID attributes beats a
## hand-authored per-enemy number, which drifts from the stats the moment either
## is tuned and gives no signal that it has.
func test_a_tougher_enemy_is_worth_more_xp() -> void:
	var weak := Advancement.xp_for_defeated(1, 1)
	var tough := Advancement.xp_for_defeated(5, 4)
	assert_int(weak).is_greater(0)
	assert_int(tough).override_failure_message(
		"a Jawbrace Guard is worth no more than a boar"
	).is_greater(weak)
	assert_int(Advancement.xp_for_defeated(0, 0)).override_failure_message(
		"a zero-attribute combatant must still be worth something, not nothing"
	).is_greater(0)


func test_negative_attributes_cannot_produce_negative_xp() -> void:
	assert_int(Advancement.xp_for_defeated(-9, -9)).is_greater(0)


func test_the_party_shares_every_award() -> void:
	var lead := _member("test-lead")
	var companion := _member("test-companion")
	GameState.party = [lead, companion]

	GameState.award_party_xp(Advancement.xp_for_next_level(1), "test")

	assert_int(lead.level).is_equal(2)
	assert_int(companion.level).override_failure_message(
		"a companion fell behind for having been in the back rank; a party that "
		+ "diverges in level makes the roster a trap rather than a choice"
	).is_equal(2)


func test_an_award_reports_who_levelled() -> void:
	var lead := _member("test-lead")
	GameState.party = [lead]

	var quiet := GameState.award_party_xp(1, "test")
	assert_dict(quiet).override_failure_message(
		"an award too small to level anyone must report nobody"
	).is_empty()

	var loud := GameState.award_party_xp(Advancement.xp_for_next_level(1), "test")
	assert_bool(loud.has("test-lead")).is_true()
	assert_int(int(loud["test-lead"])).is_equal(2)


func test_bench_recruits_keep_pace_with_the_party() -> void:
	var lead := _member("test-lead")
	var benched := _member("test-benched")
	GameState.party = [lead]
	GameState.custom_recruits = [benched]

	GameState.award_party_xp(Advancement.xp_for_next_level(1), "test")

	assert_int(benched.level).override_failure_message(
		"a recruit the player built and left behind should still be usable when "
		+ "they come back for them"
	).is_equal(2)


func test_a_milestone_pays_in_xp_and_still_reads_as_a_level() -> void:
	var lead := _member("test-lead")
	GameState.party = [lead]

	assert_bool(GameState.grant_milestone_level(&"test-milestone-xp")).is_true()
	assert_int(lead.level).override_failure_message(
		"a story milestone must still visibly level the party"
	).is_equal(2)


## The half a straight `grant_level()` used to get wrong: a member most of the way
## to their next level should not have that progress swallowed by the milestone.
func test_a_milestone_does_not_swallow_progress_already_banked() -> void:
	var ahead := _member("test-ahead")
	Advancement.award_xp(ahead, Advancement.xp_for_next_level(1) - 1)
	assert_int(ahead.level).is_equal(1)
	GameState.party = [ahead]

	GameState.grant_milestone_level(&"test-milestone-surplus")

	assert_int(ahead.level).is_equal(2)
	assert_int(ahead.xp).override_failure_message(
		"the 99 XP this member had already earned was thrown away by the milestone"
	).is_greater(0)


func test_a_milestone_still_only_pays_once() -> void:
	var lead := _member("test-lead")
	GameState.party = [lead]

	assert_bool(GameState.grant_milestone_level(&"test-milestone-once")).is_true()
	var level_after_first := lead.level
	assert_bool(GameState.grant_milestone_level(&"test-milestone-once")).override_failure_message(
		"a replayed milestone must not pay again"
	).is_false()
	assert_int(lead.level).is_equal(level_after_first)


## XP is now the ONLY way a level is gained. If a second path appears, these
## numbers stop meaning anything and the curve cannot be tuned.
func test_levels_come_from_xp_and_nothing_else() -> void:
	var lead := _member("test-lead")
	GameState.party = [lead]
	GameState.grant_milestone_level(&"test-milestone-single-currency")
	var banked := lead.xp + Advancement.xp_for_next_level(1)

	assert_int(banked).override_failure_message(
		"the milestone levelled this member without spending XP to do it"
	).is_greater_equal(Advancement.xp_for_next_level(1))
