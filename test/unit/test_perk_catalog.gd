extends GdUnitTestSuite
## #285 slice 1: patron-class perks as canon → Pandora → generated data, the pick rules
## (levels 2 / 4 / 6, one pick each, in order) and the gates (owner items 2 and 22).

const SeedPandora := preload("res://tools/seed_pandora.gd")

var _renown_before: Dictionary


func before_test() -> void:
	_renown_before = Renown.to_dict().duplicate(true)
	Renown.from_dict({})


func after_test() -> void:
	Renown.from_dict(_renown_before)


func _member(class_id: String, level: int) -> PartyMember:
	var member := PartyMember.new()
	member.display_name = "Vex"
	member.class_id = class_id
	member.level = level
	return member


func _first_at(class_id: String, level: int, gated: bool = false) -> String:
	for row: Dictionary in PerkCatalog.for_class(class_id):
		var has_gate := not (
			str(row["minimum_fame_tier"]).is_empty() and str(row["minimum_karma_tier"]).is_empty()
			and str(row["maximum_karma_tier"]).is_empty()
		)
		if int(row["level"]) == level and has_gate == gated:
			return str(row["id"])
	return ""


func test_every_class_has_a_resource_perk_a_signature_and_a_capstone_pair() -> void:
	assert_int(PerkCatalog.all().size()).is_equal(ClassCatalog.ids().size() * 4)
	for class_id: String in ClassCatalog.ids():
		var levels: Array[int] = []
		for row: Dictionary in PerkCatalog.for_class(class_id):
			levels.append(int(row["level"]))
		assert_array(levels).override_failure_message(class_id).is_equal([2, 4, 6, 6])
		assert_str(_first_at(class_id, 6, true)).override_failure_message(
			"%s needs one gated capstone" % class_id
		).is_not_empty()
		assert_str(_first_at(class_id, 6, false)).override_failure_message(
			"%s needs one ungated capstone" % class_id
		).is_not_empty()


func test_generated_perks_match_canon_field_for_field() -> void:
	var canon: Array[Dictionary] = SeedPandora.CanonReader.load("perks")
	assert_int(canon.size()).is_equal(PerkCatalog.all().size())
	for document: Dictionary in canon:
		var row := PerkCatalog.definition(str(document["id"]))
		assert_bool(row.is_empty()).override_failure_message(str(document["id"])).is_false()
		for field: String in document:
			if field == "schema":
				continue
			var generated: Variant = row.get(field)
			var authored: Variant = document[field]
			if field == "level":
				# JSON has one number type: both sides arrive as floats.
				generated = int(generated)
				authored = int(authored)
			assert_str(str(generated)).override_failure_message(
				"%s.%s" % [document["id"], field]
			).is_equal(str(authored))


func test_the_rule_of_three_accepts_canon_and_refuses_each_break() -> void:
	var classes: Array[Dictionary] = SeedPandora.CanonReader.load("classes")
	var perks: Array[Dictionary] = SeedPandora.CanonReader.load("perks")
	assert_bool(SeedPandora.perks_are_valid(perks, classes)).is_true()

	var cases: Array[Array] = [
		["class_id", "nobody", "CANON-SEED: perk 'mirrorblade-second-footing' names unknown class 'nobody'."],
		["slot", "flourish", "CANON-SEED: perk 'mirrorblade-second-footing' has unknown slot 'flourish'."],
		["level", 4.0, "CANON-SEED: perk 'mirrorblade-second-footing' is a resource perk and must sit at level 2."],
		["minimum_fame_tier", "Famous", "CANON-SEED: perk 'mirrorblade-second-footing' gates on unknown tier 'Famous' (minimum_fame_tier)."],
	]
	for case: Array in cases:
		var broken: Array[Dictionary] = []
		for row: Dictionary in perks:
			broken.append(row.duplicate(true))
		for row: Dictionary in broken:
			if row["id"] == "mirrorblade-second-footing":
				row[case[0]] = case[1]
		await assert_error(SeedPandora.perks_are_valid.bind(broken, classes)).is_push_error(case[2])
		assert_bool(SeedPandora.perks_are_valid(broken, classes)).is_false()

	var short: Array[Dictionary] = []
	for row: Dictionary in perks:
		if row["id"] != _first_at("ironbrand", 6, false):
			short.append(row)
	await assert_error(SeedPandora.perks_are_valid.bind(short, classes)).is_push_error(
		"CANON-SEED: class 'ironbrand' needs 2 perk(s) at level 6, has 1."
	)


func test_picks_open_at_two_four_and_six_and_are_taken_in_order() -> void:
	var member := _member("ironbrand", 1)
	assert_int(PerkCatalog.pending_level(member)).is_equal(0)
	assert_array(PerkCatalog.offers(member)).is_empty()

	member.level = 5
	assert_int(PerkCatalog.pending_level(member)).override_failure_message(
		"a member who jumped levels picks the level-2 perk first"
	).is_equal(2)
	assert_int(PerkCatalog.offers(member).size()).is_equal(1)
	assert_bool(PerkCatalog.pick(member, _first_at("ironbrand", 4))["allowed"]).is_false()
	assert_bool(PerkCatalog.pick(member, _first_at("ironbrand", 2))["allowed"]).is_true()
	assert_int(PerkCatalog.pending_level(member)).is_equal(4)
	assert_bool(PerkCatalog.pick(member, _first_at("ironbrand", 4))["allowed"]).is_true()
	assert_int(PerkCatalog.pending_level(member)).override_failure_message(
		"level 6 is not reached yet"
	).is_equal(0)

	member.level = 6
	assert_int(PerkCatalog.offers(member).size()).is_equal(2)
	assert_bool(PerkCatalog.pick(member, _first_at("ironbrand", 6, false))["allowed"]).is_true()
	assert_int(PerkCatalog.pending_level(member)).is_equal(0)
	assert_bool(PerkCatalog.pick(member, _first_at("ironbrand", 6, true))["allowed"]).override_failure_message(
		"one capstone, not both"
	).is_false()
	assert_int(member.perk_ids.size()).is_equal(3)


func test_pick_refuses_another_class_unknown_ids_and_classless_members() -> void:
	var member := _member("ironbrand", 2)
	var other := PerkCatalog.pick(member, _first_at("mirrorblade", 2))
	assert_bool(other["allowed"]).is_false()
	assert_str(str(other["reason"])).is_equal("wrong_class")
	assert_str(str(PerkCatalog.pick(member, "no-such-perk")["reason"])).is_equal("unknown_perk")

	var companion := _member("", 6)
	assert_int(PerkCatalog.pending_level(companion)).is_equal(0)
	assert_array(PerkCatalog.offers(companion)).is_empty()
	assert_int(member.perk_ids.size()).is_equal(0)


func test_a_fame_gate_holds_until_the_tier_is_reached() -> void:
	var member := _member("mirrorblade", 6)
	member.perk_ids = PackedStringArray([_first_at("mirrorblade", 2), _first_at("mirrorblade", 4)])
	var gated := _first_at("mirrorblade", 6, true)
	assert_str(str(PerkCatalog.definition(gated)["minimum_fame_tier"])).is_equal("Known")

	var refused := PerkCatalog.pick(member, gated)
	assert_bool(refused["allowed"]).is_false()
	assert_str(str(refused["reason"])).is_equal("gated")
	assert_str(str(refused["message"])).is_equal("Needs Fame: Known or more.")

	Renown.gain_reputation("vex", Renown.FAME_TIER_FLOORS[2], "test: made a name")
	assert_bool(Renown.fame_tier_at_least("Known")).is_true()
	assert_str(PerkCatalog.gate_refusal(PerkCatalog.definition(gated))).is_empty()
	assert_bool(PerkCatalog.pick(member, gated)["allowed"]).is_true()


## Owner item 22, `perks karma gate: wait`: until Karma has writers the Karma-gated capstones
## are offered ungated; their gate stays authored in canon.
func test_karma_gates_wait_while_karma_has_no_writers() -> void:
	assert_bool(PerkCatalog.KARMA_GATES_LIVE).is_false()
	var member := _member("ironbrand", 6)
	member.perk_ids = PackedStringArray([_first_at("ironbrand", 2), _first_at("ironbrand", 4)])
	var gated := _first_at("ironbrand", 6, true)
	assert_str(str(PerkCatalog.definition(gated)["maximum_karma_tier"])).is_equal("Troubled")
	assert_bool(Renown.karma_tier_at_most("Troubled")).is_false()
	assert_str(PerkCatalog.gate_refusal(PerkCatalog.definition(gated))).is_empty()
	assert_bool(PerkCatalog.pick(member, gated)["allowed"]).is_true()


func test_text_falls_back_to_the_english_source_and_keys_are_stable() -> void:
	var perk := PerkCatalog.definition("ironbrand-thick-hide")
	assert_str(PerkCatalog.key_for("ironbrand-thick-hide", "name")).is_equal("PERK_IRONBRAND_THICK_HIDE_NAME")
	assert_str(PerkCatalog.key_for("ironbrand-thick-hide", "blurb")).is_equal("PERK_IRONBRAND_THICK_HIDE_BLURB")
	assert_str(PerkCatalog.display_name(perk)).is_equal("Thick Hide")
	assert_str(PerkCatalog.blurb(perk)).is_equal("Raises the Scar cap.")
	var pot := FileAccess.get_file_as_string("res://data/generated/items.pot")
	assert_str(pot).contains('msgid "PERK_IRONBRAND_THICK_HIDE_NAME"')
