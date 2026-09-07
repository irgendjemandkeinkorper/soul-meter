extends GdUnitTestSuite
## #98 advancement system: D3 point-buy costs/caps, milestone leveling, D5 respec.

var _saved_skills: Dictionary
var _saved_flags: Dictionary
var _saved_party: Array[PartyMember]


func before_test() -> void:
	_saved_skills = GameState.skills.duplicate(true)
	_saved_flags = GameState.flags.duplicate(true)
	_saved_party = GameState.party.duplicate()
	GameState.skills = {}


func after_test() -> void:
	GameState.skills = _saved_skills
	GameState.flags = _saved_flags
	GameState.party = _saved_party


func _member(attr: int = 2, tier: String = "untrained") -> PartyMember:
	var member := PartyMember.new()
	member.id = "advancement-probe"
	member.display_name = "Probe"
	member.attributes = {"lore": attr, "edge": attr, "spark": attr, "voice": attr,
		"forge": attr, "anchor": attr, "pitch": attr}
	member.skill_tiers = {"lore": tier}
	return member


func test_step_cost_bands_follow_resulting_effective_percent() -> void:
	# attr 2 -> base 16%; +5 lands at 21 -> band 1.
	var low := _member(2)
	assert_int(Advancement.step_cost(low, "lore")).is_equal(1)

	# attr 5, Trained: 40 + 20 = 60; +5 -> 65 -> band 2.
	var mid := _member(5, "trained")
	assert_int(Advancement.step_cost(mid, "lore")).is_equal(2)

	# attr 5, Expert: 40 + 35 = 75; +5 -> 80 -> band 3.
	var high := _member(5, "expert")
	assert_int(Advancement.step_cost(high, "lore")).is_equal(3)


func test_removed_skill_refund_uses_the_advancement_cost_curve() -> void:
	assert_int(Advancement.points_spent_for_percentage(40.0, 20.0)).is_equal(6)
	assert_int(Advancement.points_spent_for_percentage(75.0, 10.0)).is_equal(6)


func test_cap_blocks_purchases_past_95_effective() -> void:
	var member := _member(5, "expert")  # effective 75
	member.advancement_points = 99
	for _step in 4:  # 80, 85, 90, 95
		assert_bool(bool(Advancement.buy(member, "lore").get("allowed", false))).is_true()
	var blocked := Advancement.buy(member, "lore")
	assert_bool(bool(blocked.get("allowed", false))).is_false()
	assert_str(str(blocked.get("blocked_by", ""))).is_equal("effective_cap")
	assert_float(SkillCheck.preview("lore", member, 0.0)).is_equal_approx(95.0, 0.001)


func test_buy_moves_points_percentages_and_ledger_together() -> void:
	var member := _member(2)
	member.advancement_points = 3
	var result := Advancement.buy(member, "lore")
	assert_bool(bool(result.get("allowed", false))).is_true()
	assert_int(member.advancement_points).is_equal(2)
	assert_float(float(member.skill_percentages.get("lore", 0.0))).is_equal_approx(5.0, 0.001)
	var row: Dictionary = GameState.skills["advancement-probe"]["lore"]
	assert_float(float(row["percentage"])).is_equal_approx(5.0, 0.001)
	assert_int(int(row["advancement_points_spent"])).is_equal(1)


func test_insufficient_points_is_refused_with_gate_shape() -> void:
	var member := _member(2)
	member.advancement_points = 0
	var result := Advancement.buy(member, "lore")
	assert_bool(bool(result.get("allowed", false))).is_false()
	assert_str(str(result.get("blocked_by", ""))).is_equal("points")


func test_only_held_tones_are_purchasable() -> void:
	var member := PartyMember.new()
	member.id = "advancement-tones"
	member.attributes = {"intuition": 3}
	member.major_element = "khash"
	member.minor_element = "mozh"
	member.advancement_points = 6
	assert_bool(Advancement.is_purchasable(member, "tone_khash")).is_true()
	assert_bool(Advancement.is_purchasable(member, "tone_luth")).is_false()
	assert_bool(Advancement.is_purchasable(member, "heft")).is_true()
	assert_bool(Advancement.held_tones(member).has("tone_mozh")).is_true()
	var refused := Advancement.buy(member, "tone_luth")
	assert_bool(refused["allowed"]).is_false()
	assert_str(str(refused["blocked_by"])).is_equal("unheld_tone")
	assert_int(member.advancement_points).is_equal(6)
	assert_bool(Advancement.buy(member, "tone_khash")["allowed"]).is_true()
	assert_float(float(member.skill_percentages["tone_khash"])).is_equal(5.0)


func test_seed_creation_ledger_writes_lowercase_rows_the_validator_accepts() -> void:
	var member := PartyMember.new()
	member.id = "advancement-seed"
	member.skill_tiers = {"heft": "trained"}
	member.skill_percentages = {"heft": 10.0, "recall": 5.0}
	Advancement.seed_creation_ledger(member, {
		"heft": {"percentage": 10.0, "tier": "Trained", "advancement_points_spent": 4},
		"recall": {"percentage": 5.0, "tier": "untrained", "advancement_points_spent": 1},
	})
	var row: Dictionary = GameState.skills["advancement-seed"]["heft"]
	assert_str(str(row["tier"])).is_equal("trained")
	assert_int(int(row["advancement_points_spent"])).is_equal(4)
	assert_int(Advancement.total_points_spent(member)).is_equal(5)
	assert_bool(GameState._is_known_skill_tier("trained")).is_true()
	assert_bool(GameState._is_known_skill_tier("Trained")).is_true()
	assert_bool(GameState._is_known_skill_tier("master")).is_false()
	var refund := Advancement.mirror_rewriting(member)
	assert_int(refund["refunded_points"]).is_equal(5)
	assert_float(float(member.skill_percentages["heft"])).is_equal(0.0)

	var orphan := PartyMember.new()
	Advancement.seed_creation_ledger(orphan, {"heft": {"percentage": 5.0}})
	assert_bool(GameState.skills.has("")).is_false()


func test_grant_level_awards_ratified_points() -> void:
	var member := _member(2)
	Advancement.grant_level(member)
	assert_int(member.level).is_equal(2)
	assert_int(member.advancement_points).is_equal(Advancement.POINTS_PER_LEVEL)


func test_milestone_leveling_is_idempotent_and_levels_the_roster() -> void:
	var lead := _member(2)
	GameState.party = [lead] as Array[PartyMember]
	assert_bool(GameState.grant_milestone_level(&"probe-milestone")).is_true()
	assert_int(lead.level).is_equal(2)
	assert_bool(GameState.grant_milestone_level(&"probe-milestone")).is_false()
	assert_int(lead.level).is_equal(2)


func test_mirror_rewriting_refunds_everything_once_per_chapter() -> void:
	var member := _member(2)
	GameState.party = [member] as Array[PartyMember]
	member.advancement_points = 5
	Advancement.buy(member, "lore")
	Advancement.buy(member, "lore")
	assert_int(member.advancement_points).is_equal(3)

	var result := GameState.use_mirror_rewriting(member)
	assert_bool(bool(result.get("allowed", false))).is_true()
	assert_int(int(result.get("refunded_points", 0))).is_equal(2)
	assert_int(member.advancement_points).is_equal(5)
	assert_float(float(member.skill_percentages.get("lore", 0.0))).is_equal_approx(0.0, 0.001)

	var second := GameState.use_mirror_rewriting(member)
	assert_bool(bool(second.get("allowed", false))).is_false()
	assert_str(str(second.get("blocked_by", ""))).is_equal("chapter_limit")


func test_advancement_points_survive_party_member_round_trip() -> void:
	var member := _member(2)
	member.advancement_points = 4
	var restored := PartyMember.from_dict(member.to_dict())
	assert_int(restored.advancement_points).is_equal(4)
