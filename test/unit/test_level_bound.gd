extends GdUnitTestSuite
## Owner ruling 2026-10-09: wild respawns stay farmable, but leveling is bounded so
## grinding cannot outrun the campaign. A hard Chapter 1 level cap, and kill XP scaled
## per member by their level against the foe's. Quest XP is never scaled.

var _party_before: Array[PartyMember] = []
var _custom_before: Array[PartyMember] = []


func before_test() -> void:
	_party_before = GameState.party.duplicate()
	_custom_before = GameState.custom_recruits.duplicate()


func after_test() -> void:
	GameState.party = _party_before
	GameState.custom_recruits = _custom_before


func _member(member_id: String, level: int) -> PartyMember:
	var member := PartyMember.new()
	member.id = member_id
	member.level = level
	member.xp = 0
	member.advancement_points = 0
	return member


func test_no_award_carries_a_member_past_the_chapter_cap() -> void:
	var member := _member("capped", 1)
	Advancement.award_xp(member, 1_000_000)
	assert_int(member.level).is_equal(Advancement.CHAPTER_LEVEL_CAP)
	assert_int(member.xp).override_failure_message("XP past the cap must not bank").is_equal(0)
	assert_int(Advancement.award_xp(member, 1_000_000)).is_equal(0)
	assert_int(member.level).is_equal(Advancement.CHAPTER_LEVEL_CAP)


func test_an_even_fight_pays_the_full_kill() -> void:
	assert_float(Advancement.kill_xp_multiplier(4, 4)).is_equal(1.0)
	# Bog-wight: grit 2 + muster 2 -> foe level 2.
	assert_int(Advancement.kill_xp_for(2, 2, 2)).is_equal(Advancement.xp_for_defeated(2, 2))


func test_an_out_levelled_foe_pays_less_down_to_the_floor() -> void:
	var last := 2.0
	for level: int in range(3, 12):
		var share := Advancement.kill_xp_multiplier(level, 2)
		assert_float(share).is_less_equal(last)
		assert_float(share).is_greater_equal(Advancement.KILL_XP_FLOOR)
		last = share
	assert_float(Advancement.kill_xp_multiplier(20, 2)).is_equal(Advancement.KILL_XP_FLOOR)
	assert_int(Advancement.kill_xp_for(20, 0, 0)).override_failure_message("a kill never pays nothing").is_greater_equal(1)


func test_a_member_behind_the_foe_catches_up_to_the_ceiling() -> void:
	assert_float(Advancement.kill_xp_multiplier(1, 2)).is_greater(1.0)
	assert_float(Advancement.kill_xp_multiplier(1, 20)).is_equal(Advancement.KILL_XP_CEILING)


func test_each_member_earns_by_their_own_level() -> void:
	var veteran := _member("veteran", 6)
	var recruit := _member("recruit", 1)
	GameState.party = [veteran, recruit] as Array[PartyMember]
	GameState.custom_recruits = [] as Array[PartyMember]
	var wight: Array[Vector2i] = [Vector2i(2, 2)]
	var veteran_share := GameState.kill_xp_for_member(veteran, wight)
	var recruit_share := GameState.kill_xp_for_member(recruit, wight)
	GameState.award_party_kill_xp(wight, "test")
	assert_int(veteran.xp).is_equal(veteran_share)
	assert_int(recruit.xp).is_equal(recruit_share)
	assert_int(recruit_share).override_failure_message("the recruit behind the curve must catch up").is_greater(veteran_share)


func test_quest_xp_is_never_scaled() -> void:
	var veteran := _member("veteran", 6)
	var recruit := _member("recruit", 1)
	GameState.party = [veteran, recruit] as Array[PartyMember]
	GameState.custom_recruits = [] as Array[PartyMember]
	GameState.award_party_xp(Advancement.XP_PER_QUEST, "test")
	assert_int(veteran.xp).is_equal(Advancement.XP_PER_QUEST)
	assert_int(recruit.xp).is_equal(Advancement.XP_PER_QUEST)


func test_a_battle_reports_what_the_lead_earned() -> void:
	var lead := _member("lead", 6)
	GameState.party = [lead] as Array[PartyMember]
	var wight: Array[Vector2i] = [Vector2i(2, 2)]
	assert_int(GameState.kill_xp_for_lead(wight)).is_equal(GameState.kill_xp_for_member(lead, wight))
	assert_int(GameState.kill_xp_for_lead(wight)).is_less(Advancement.xp_for_defeated(2, 2))
