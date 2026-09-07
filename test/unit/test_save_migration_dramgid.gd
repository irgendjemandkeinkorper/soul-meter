extends GdUnitTestSuite
## Schema 8 -> 9, the DRAMGID migration (`docs/architecture-dramgid.md` §2.1).
##
## The rename half is mechanical, but two things in it can lose player property and so
## are tested harder than the rest: Alchemy's advancement points (DRAMGID deletes the
## skill, and §2.1 step 2 refuses to delete what was paid for it) and the expert-reroll
## keys, whose skill id sits behind a scene path that carries its own colons.

const LEGACY_ATTRIBUTES: Dictionary = {
	"forge": 4, "edge": 3, "anchor": 3, "pitch": 4, "voice": 3, "spark": 3,
}


func _member(overrides: Dictionary = {}) -> Dictionary:
	var member: Dictionary = {
		"id": "iris",
		"display_name": "Iris Illepah",
		"level": 3,
		"advancement_points": 2,
		"max_hp": 24,
		"attack": 7,
		"defense": 3,
		"breath_max": 6,
		"attributes": LEGACY_ATTRIBUTES.duplicate(),
		"skill_percentages": {"athletics": 20.0, "persuasion": 15.0, "tone_khash": 10.0},
		"skill_tiers": {"athletics": "trained", "persuasion": "expert"},
	}
	member.merge(overrides, true)
	return member


func _payload(members: Array, extras: Dictionary = {}) -> Dictionary:
	var payload: Dictionary = {
		"schema_version": 8,
		"game_state": {
			"party": members,
			"custom_recruits": [],
			"skills": {},
		},
	}
	payload.merge(extras, true)
	return payload


func _prepared(payload: Dictionary) -> Dictionary:
	var result: Dictionary = SaveMigrations.prepare(payload)
	assert_bool(result["ok"]).override_failure_message(
		"migration refused the fixture: %s" % result["error"]
	).is_true()
	return result["payload"]


func _first_member(payload: Dictionary) -> Dictionary:
	return (_prepared(payload)["game_state"]["party"] as Array)[0]


func test_the_six_legacy_attributes_take_their_dramgid_names() -> void:
	var attributes: Dictionary = _first_member(_payload([_member()]))["attributes"]
	assert_int(int(attributes["muster"])).is_equal(4)
	assert_int(int(attributes["alacrity"])).is_equal(3)
	assert_int(int(attributes["grit"])).is_equal(3)
	assert_int(int(attributes["intuition"])).is_equal(4)
	assert_int(int(attributes["decorum"])).is_equal(3)
	assert_int(int(attributes["reason"])).is_equal(3)
	for legacy_id: String in DramgidSchema.ATTRIBUTE_RENAMES.keys():
		assert_bool(attributes.has(legacy_id)).override_failure_message(
			"legacy attribute '%s' survived the migration" % legacy_id
		).is_false()


func test_doctrine_arrives_at_the_point_buy_floor_and_completes_the_budget() -> void:
	# The legacy six were bought against 20 points; floor-2 Doctrine lands the row on
	# DRAMGID's 22, so a player-created member stays a legal build across the migration.
	var attributes: Dictionary = _first_member(_payload([_member()]))["attributes"]
	assert_int(int(attributes["doctrine"])).is_equal(DramgidSchema.ATTRIBUTE_FLOOR)
	var total := 0
	for value: Variant in attributes.values():
		total += int(value)
	assert_int(total).is_equal(DramgidSchema.ATTRIBUTE_BUDGET)


func test_a_member_that_already_has_doctrine_keeps_its_own_value() -> void:
	var authored: Dictionary = LEGACY_ATTRIBUTES.duplicate()
	authored["doctrine"] = 5
	var attributes: Dictionary = _first_member(
		_payload([_member({"attributes": authored})])
	)["attributes"]
	assert_int(int(attributes["doctrine"])).is_equal(5)


func test_an_empty_attribute_block_does_not_gain_an_invented_doctrine() -> void:
	# A member with no attributes at all is corrupt, and the loader's validator has to
	# still see that rather than a migration quietly handing it one legal-looking stat.
	var attributes: Dictionary = _first_member(
		_payload([_member({"attributes": {}})])
	)["attributes"]
	assert_bool(attributes.is_empty()).is_true()


func test_legacy_skill_ids_are_renamed_in_percentages_and_tiers() -> void:
	var member: Dictionary = _first_member(_payload([_member()]))
	var percentages: Dictionary = member["skill_percentages"]
	var tiers: Dictionary = member["skill_tiers"]
	assert_float(float(percentages["strain"])).is_equal(20.0)
	assert_float(float(percentages["sway"])).is_equal(15.0)
	assert_str(str(tiers["strain"])).is_equal("trained")
	assert_str(str(tiers["sway"])).is_equal("expert")
	assert_bool(percentages.has("athletics")).is_false()
	assert_bool(percentages.has("persuasion")).is_false()


func test_tone_and_dramgid_native_ids_pass_through_untouched() -> void:
	var already: Dictionary = _member({
		"skill_percentages": {"tone_khash": 10.0, "strain": 30.0, "blades": 25.0},
	})
	var percentages: Dictionary = _first_member(_payload([already]))["skill_percentages"]
	assert_float(float(percentages["tone_khash"])).is_equal(10.0)
	assert_float(float(percentages["strain"])).is_equal(30.0)
	assert_float(float(percentages["blades"])).is_equal(25.0)


func test_alchemy_leaves_the_member_entirely() -> void:
	var alchemist: Dictionary = _member({
		"skill_percentages": {"alchemy": 25.0},
		"skill_tiers": {"alchemy": "trained"},
	})
	var member: Dictionary = _first_member(_payload([alchemist]))
	assert_bool((member["skill_percentages"] as Dictionary).has("alchemy")).is_false()
	assert_bool((member["skill_tiers"] as Dictionary).has("alchemy")).is_false()


func test_the_ledger_decides_the_alchemy_refund_when_it_has_a_row() -> void:
	var alchemist: Dictionary = _member({"skill_percentages": {"alchemy": 25.0}})
	var payload: Dictionary = _payload([alchemist])
	payload["game_state"]["skills"] = {
		"iris": {"alchemy": {"percentage": 25.0, "tier": "trained", "advancement_points_spent": 9}},
	}
	assert_int(int(_first_member(payload)["advancement_points"])).is_equal(2 + 9)


func test_without_a_ledger_row_the_cost_curve_prices_the_refund() -> void:
	var alchemist: Dictionary = _member({"skill_percentages": {"alchemy": 25.0}})
	var expected := Advancement.points_spent_for_percentage(0.0, 25.0)
	assert_int(expected).override_failure_message(
		"the cost curve priced 25% at nothing, so this test proves nothing"
	).is_greater(0)
	assert_int(int(_first_member(_payload([alchemist]))["advancement_points"])).is_equal(
		2 + expected
	)


func test_a_member_who_never_bought_alchemy_is_refunded_nothing() -> void:
	assert_int(int(_first_member(_payload([_member()]))["advancement_points"])).is_equal(2)


func test_the_actor_keyed_skill_ledger_is_renamed_and_loses_alchemy() -> void:
	var payload: Dictionary = _payload([_member()])
	payload["game_state"]["skills"] = {
		"iris": {
			"persuasion": {"percentage": 15.0, "advancement_points_spent": 4},
			"alchemy": {"percentage": 25.0, "advancement_points_spent": 9},
		},
	}
	var ledger: Dictionary = _prepared(payload)["game_state"]["skills"]
	var rows: Dictionary = ledger["iris"]
	assert_bool(rows.has("sway")).is_true()
	assert_int(int((rows["sway"] as Dictionary)["advancement_points_spent"])).is_equal(4)
	assert_bool(rows.has("persuasion")).is_false()
	assert_bool(rows.has("alchemy")).is_false()


func test_an_expert_reroll_key_is_renamed_only_in_its_last_segment() -> void:
	# The scene path carries its own colon, so splitting from the left would rewrite
	# "res" as if it were the skill id and throw the rest of the key away.
	var payload: Dictionary = _payload([_member()], {
		"skill_check": {
			"expert_rerolls_used": {"res://world/test_room.tscn:iris:persuasion": 1},
		},
	})
	var used: Dictionary = _prepared(payload)["skill_check"]["expert_rerolls_used"]
	assert_bool(used.has("res://world/test_room.tscn:iris:sway")).override_failure_message(
		"expected the renamed key, got %s" % [used.keys()]
	).is_true()
	assert_int(int(used["res://world/test_room.tscn:iris:sway"])).is_equal(1)


func test_an_expert_reroll_key_for_a_deleted_skill_is_dropped() -> void:
	var payload: Dictionary = _payload([_member()], {
		"skill_check": {"expert_rerolls_used": {"res://a.tscn:iris:alchemy": 1}},
	})
	var used: Dictionary = _prepared(payload)["skill_check"]["expert_rerolls_used"]
	assert_bool(used.is_empty()).is_true()


func test_xp_is_added_when_missing_and_left_alone_when_present() -> void:
	assert_int(int(_first_member(_payload([_member()]))["xp"])).is_equal(0)
	assert_int(
		int(_first_member(_payload([_member({"xp": 450})]))["xp"])
	).is_equal(450)


func test_derived_stats_are_carried_across_unchanged() -> void:
	# §2.1 step 6 asks for these to be recomputed, but the formulas are §6's and still
	# unratified. Until then the migration must not move a save's combat numbers.
	var member: Dictionary = _first_member(_payload([_member()]))
	assert_int(int(member["max_hp"])).is_equal(24)
	assert_int(int(member["attack"])).is_equal(7)
	assert_int(int(member["defense"])).is_equal(3)
	assert_int(int(member["breath_max"])).is_equal(6)


func test_custom_recruits_are_migrated_alongside_the_party() -> void:
	var payload: Dictionary = _payload([])
	payload["game_state"]["custom_recruits"] = [_member({"id": "homebrew"})]
	var recruit: Dictionary = (
		_prepared(payload)["game_state"]["custom_recruits"] as Array
	)[0]
	assert_int(int((recruit["attributes"] as Dictionary)["muster"])).is_equal(4)
	assert_bool((recruit["skill_percentages"] as Dictionary).has("strain")).is_true()


func test_migrating_an_already_migrated_payload_changes_nothing_further() -> void:
	# The rename tables pass unknown ids through, which is what makes the whole chain
	# safe to re-run — but the Alchemy refund is a WRITE, so a second pass over the
	# same save must not pay it twice.
	var alchemist: Dictionary = _member({"skill_percentages": {"alchemy": 25.0}})
	var once: Dictionary = _prepared(_payload([alchemist]))
	var twice: Dictionary = _prepared(once)
	var first: Dictionary = (once["game_state"]["party"] as Array)[0]
	var second: Dictionary = (twice["game_state"]["party"] as Array)[0]
	assert_int(int(second["advancement_points"])).is_equal(int(first["advancement_points"]))
	assert_int(
		int((second["attributes"] as Dictionary)["doctrine"])
	).is_equal(int((first["attributes"] as Dictionary)["doctrine"]))


func test_the_envelope_reports_schema_nine() -> void:
	assert_int(int(_prepared(_payload([_member()]))["schema_version"])).is_equal(9)
