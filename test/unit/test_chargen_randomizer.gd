extends GdUnitTestSuite

var _original_skills: Dictionary


func before_test() -> void:
	_original_skills = GameState.skills.duplicate(true)
	GameState.skills = {}


func after_test() -> void:
	GameState.skills = _original_skills


func test_200_seeds_pass_confirm_validation_spend_every_point_and_vary_every_choice() -> void:
	var current := ChargenBuild.new()
	current.display_name = "Sera"
	var rng := RandomNumberGenerator.new()
	var variants: Dictionary = {}
	for seed_value: int in 200:
		rng.seed = seed_value
		var build := ChargenRandomizer.roll(rng, current)
		# This is the exact model gate used by the screen's ACCEPT path.
		assert_bool(build.is_complete()).override_failure_message("seed %d: %s" % [
			seed_value, build.validate(&"summary")["message"]]).is_true()
		for step_id: StringName in ChargenSteps.ids():
			assert_bool(build.validate(step_id)["valid"]).override_failure_message(
				"seed %d, leaf %s" % [seed_value, step_id]).is_true()
		assert_int(build.remaining_attribute_points()).is_equal(0)
		assert_int(build.points_remaining()).is_equal(0)
		assert_int(build.points_spent()).is_equal(build.creation_pool())
		for value: int in build.attributes.values():
			assert_bool(value >= DramgidSchema.ATTRIBUTE_FLOOR and value <= DramgidSchema.ATTRIBUTE_CAP).is_true()
		for skill_id: String in build.creation_buys:
			assert_bool(build.purchasable_skills().has(skill_id)).is_true()
			assert_bool(build.preview_percent(skill_id) <= Advancement.EFFECTIVE_CAP).is_true()
		assert_str(build.display_name).is_equal("Sera")
		var people := str(ChargenData.likeness_by_id(build.likeness_id)["label"]).get_slice(" ", 0)
		var ancestry_name := ""
		for entry: Dictionary in ChargenData.ANCESTRIES:
			if entry["id"] == build.ancestry_id:
				ancestry_name = str(entry["name"])
		assert_bool(ancestry_name.contains(people)).override_failure_message(
			"seed %d: likeness %s outside ancestry %s" % [seed_value, build.likeness_id, ancestry_name]
		).is_true()
		var choices := {
			"ancestry": build.ancestry_id, "discipline": build.discipline_id,
			"class": build.class_id, "kit": build.kit_skill,
			"major": build.major_element, "minor": build.minor_element,
			"mastery": build.mastery_element, "attributes": str(build.attributes),
			"background": build.background_id, "skills": str(build.creation_buys),
			"likeness": build.likeness_id,
		}
		for choice: String in choices:
			if not variants.has(choice):
				variants[choice] = {}
			variants[choice][choices[choice]] = true
	for choice: String in variants:
		assert_int((variants[choice] as Dictionary).size()).override_failure_message(
			"%s must vary across seeds" % choice).is_greater(1)


func test_same_seed_reproduces_every_field_and_purchase() -> void:
	var rng := RandomNumberGenerator.new()
	var current := ChargenBuild.new()
	for seed_value: int in [0, 37, 199]:
		rng.seed = seed_value
		var first := ChargenRandomizer.roll(rng, current)
		rng.seed = seed_value
		var second := ChargenRandomizer.roll(rng, current)
		assert_dict(_snapshot(second)).is_equal(_snapshot(first))


func test_identity_text_is_never_rolled_including_blank_fields() -> void:
	var rng := RandomNumberGenerator.new()
	var current := ChargenBuild.new()
	current.display_name = " Sera "
	current.epithet = "the unbowed"
	current.flaw = "Will not leave a debt uncounted"
	var rolled := ChargenRandomizer.roll(rng, current)
	assert_str(rolled.display_name).is_equal(current.display_name)
	assert_str(rolled.epithet).is_equal(current.epithet)
	assert_str(rolled.flaw).is_equal(current.flaw)
	assert_bool(rolled.is_complete()).is_true()

	rolled = ChargenRandomizer.roll(rng, ChargenBuild.new())
	assert_str(rolled.display_name).is_equal("")
	assert_str(rolled.epithet).is_equal("")
	assert_str(rolled.flaw).is_equal("")
	# Randomize must not bypass the existing required-name rule.
	assert_bool(rolled.validate(&"identity")["valid"]).is_false()


func test_reroll_replaces_purchases_without_mutating_the_previous_build() -> void:
	var rng := RandomNumberGenerator.new()
	rng.seed = 31
	var current := ChargenRandomizer.roll(rng, ChargenBuild.new())
	var original := _snapshot(current)
	var rolled := ChargenRandomizer.roll(rng, current)
	assert_dict(_snapshot(current)).is_equal(original)
	assert_bool(_snapshot(rolled) == original).is_false()
	assert_int(rolled.points_remaining()).is_equal(0)
	# Refund and replay the purchases through the public gate: every recorded cost
	# must still be legal for the final attributes, tags and held tones.
	var purchases := rolled.creation_buys.duplicate(true)
	for skill_id: String in purchases:
		while rolled.steps_bought(skill_id) > 0:
			assert_bool(rolled.refund(skill_id)["allowed"]).is_true()
	assert_int(rolled.points_remaining()).is_equal(rolled.creation_pool())
	for skill_id: String in purchases:
		for cost: int in purchases[skill_id]:
			var bought := rolled.buy(skill_id)
			assert_bool(bought["allowed"]).is_true()
			assert_int(bought["cost"]).is_equal(cost)
	assert_int(rolled.points_remaining()).is_equal(0)


static func _snapshot(build: ChargenBuild) -> Dictionary:
	var snapshot := build.to_party_member().to_dict()
	snapshot["likeness_id"] = build.likeness_id
	snapshot["creation_buys"] = build.creation_buys.duplicate(true)
	return snapshot
