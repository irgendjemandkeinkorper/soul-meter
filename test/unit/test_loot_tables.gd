extends GdUnitTestSuite
## #284 / game-identity ruling 7 ("stats matter outside combat"). Verb 4 of 4.
##
## Weighted loot tables with optional skill-gated rows. Two properties carry the
## design: the draw is a PURE function of its seed (so a container cannot be
## re-rolled by walking away, and two players on one seed find the same thing),
## and a gated row is genuinely gated (so the check is a reward, not decoration).

const ROAD := &"road-cache"
const HOARD := &"wight-hoard"


func _passing(table_id: StringName) -> Dictionary:
	var outcomes := {}
	for skill: String in LootTableRegistry.skills_required(table_id):
		outcomes[skill] = true
	return outcomes


func _item_ids(contents: Array[Dictionary]) -> PackedStringArray:
	var ids := PackedStringArray()
	for row: Dictionary in contents:
		ids.append(str(row["item_id"]))
	return ids


func test_every_shipped_table_is_internally_coherent() -> void:
	var ids := LootTableRegistry.table_ids()
	assert_int(ids.size()).is_greater(0)
	for table_id: StringName in ids:
		var definition := LootTableRegistry.table(table_id)
		var rows: Array = definition["rows"]
		assert_int(int(definition["rolls"])).override_failure_message(
			"table %s draws nothing" % table_id
		).is_greater(0)
		var ungated := 0
		for row: Dictionary in rows:
			if str(row.get("skill", "")).is_empty():
				ungated += 1
		assert_int(ungated).override_failure_message(
			"table %s draws %d rows from only %d ungated ones"
			% [table_id, int(definition["rolls"]), ungated]
		).is_greater_equal(int(definition["rolls"]))
		for row: Dictionary in rows:
			assert_int(int(row.get("quantity", 1))).is_greater(0)
			if str(row.get("skill", "")).is_empty():
				assert_int(int(row["weight"])).override_failure_message(
					"a zero-weight ungated row in %s can never be drawn" % table_id
				).is_greater(0)
			else:
				# A gated row is granted, not drawn, so a weight on one is a
				# number with no effect — and reads as if it had one.
				assert_bool(row.has("weight")).override_failure_message(
					"gated row '%s' in %s carries a weight that does nothing"
					% [str(row["item_id"]), table_id]
				).is_false()


## Guards the table against the item catalogue. A typo'd item id produces a
## container that silently holds nothing, which looks exactly like bad luck.
func test_every_row_names_a_real_item() -> void:
	var catalogue: Dictionary = VendorRegistry.ITEMS_DATA.data
	for table_id: StringName in LootTableRegistry.table_ids():
		for row: Dictionary in LootTableRegistry.table(table_id)["rows"]:
			var item_id := str(row["item_id"])
			assert_bool(catalogue.has(item_id)).override_failure_message(
				"table %s names item '%s', which is not in the generated catalogue"
				% [table_id, item_id]
			).is_true()


func test_every_gated_row_names_a_real_dramgid_skill() -> void:
	for table_id: StringName in LootTableRegistry.table_ids():
		for skill: String in LootTableRegistry.skills_required(table_id):
			assert_bool(DramgidSchema.is_skill(skill)).override_failure_message(
				"table %s gates a row behind '%s', which is not a DRAMGID skill" % [table_id, skill]
			).is_true()


## The determinism guarantee, stated directly. Without it a player could reload
## until a container held what they wanted, which makes every weight meaningless.
func test_the_same_seed_and_outcomes_always_give_the_same_contents() -> void:
	var outcomes := _passing(ROAD)
	var first := LootTableRegistry.roll(ROAD, 12345, outcomes)
	for _repeat in 8:
		assert_array(LootTableRegistry.roll(ROAD, 12345, outcomes)).override_failure_message(
			"the same seed gave different contents — the container is re-rollable"
		).is_equal(first)


func test_different_seeds_can_give_different_contents() -> void:
	# Not a guarantee about any particular pair, but across a spread the table
	# must vary — a "weighted" draw that ignores its seed is a constant.
	var outcomes := _passing(ROAD)
	var seen := {}
	for candidate in 40:
		seen[str(_item_ids(LootTableRegistry.roll(ROAD, candidate, outcomes)))] = true
	assert_int(seen.size()).override_failure_message(
		"40 different seeds produced one outcome; the roll is ignoring the seed"
	).is_greater(1)


func test_a_container_seed_is_stable_and_distinguishes_containers() -> void:
	assert_int(LootTableRegistry.seed_for_container("crate-a")).is_equal(
		LootTableRegistry.seed_for_container("crate-a")
	)
	assert_int(LootTableRegistry.seed_for_container("crate-a")).override_failure_message(
		"two containers sharing a table would hold identical contents"
	).is_not_equal(LootTableRegistry.seed_for_container("crate-b"))


func test_a_failed_skill_check_withholds_its_row() -> void:
	var gated := LootTableRegistry.skills_required(HOARD)
	assert_int(gated.size()).override_failure_message(
		"this case needs a table with gated rows"
	).is_greater(0)

	var withheld: Dictionary = {}
	for skill: String in gated:
		withheld[skill] = false

	var gated_items := PackedStringArray()
	for row: Dictionary in LootTableRegistry.table(HOARD)["rows"]:
		if not str(row.get("skill", "")).is_empty():
			gated_items.append(str(row["item_id"]))

	for candidate in 40:
		for item_id: String in _item_ids(LootTableRegistry.roll(HOARD, candidate, withheld)):
			assert_bool(gated_items.has(item_id)).override_failure_message(
				"'%s' is gated behind a failed check but was handed over anyway" % item_id
			).is_false()


## The other half, and the rule the design turns on: **passing a check can only
## ever ADD.** An earlier draft mixed gated rows into the weighted pool, which
## changed the distribution of every other row — on the shipped road-cache seed a
## failed `sounding` gave hearthloaf and a passed one gave salted riverfish. A
## strictly better searcher, strictly different loot, indistinguishable from a bug.
func test_passing_a_check_only_ever_adds_to_what_failing_would_give() -> void:
	for table_id: StringName in LootTableRegistry.table_ids():
		var gated := LootTableRegistry.skills_required(table_id)
		if gated.is_empty():
			continue
		var withheld := {}
		var passed := {}
		for skill: String in gated:
			withheld[skill] = false
			passed[skill] = true
		for candidate in 60:
			var without := _item_ids(LootTableRegistry.roll(table_id, candidate, withheld))
			var with := _item_ids(LootTableRegistry.roll(table_id, candidate, passed))
			for item_id: String in without:
				assert_bool(with.has(item_id)).override_failure_message(
					(
						"seed %d on %s: passing the search REMOVED '%s'. Gated rows are "
						+ "competing in the weighted pool again"
					)
					% [candidate, table_id, item_id]
				).is_true()
			assert_int(with.size()).is_greater_equal(without.size())


## And the reward must actually be reachable, or the check is a tax with nothing
## behind it and the whole mechanic is theatre.
func test_a_passed_check_yields_its_row_every_time() -> void:
	var outcomes := _passing(HOARD)
	var gated_items := PackedStringArray()
	for row: Dictionary in LootTableRegistry.table(HOARD)["rows"]:
		if not str(row.get("skill", "")).is_empty():
			gated_items.append(str(row["item_id"]))

	for candidate in 20:
		var ids := _item_ids(LootTableRegistry.roll(HOARD, candidate, outcomes))
		for item_id: String in gated_items:
			assert_bool(ids.has(item_id)).override_failure_message(
				"beat every check on seed %d and '%s' still did not appear" % [candidate, item_id]
			).is_true()


## Without replacement. With it, a 30-weight row would routinely fill a two-roll
## container with two loaves, which reads to a player as a bug rather than luck.
func test_a_draw_never_returns_the_same_row_twice() -> void:
	var outcomes := _passing(ROAD)
	for candidate in 60:
		var ids := _item_ids(LootTableRegistry.roll(ROAD, candidate, outcomes))
		var distinct := {}
		for item_id: String in ids:
			distinct[item_id] = true
		assert_int(distinct.size()).override_failure_message(
			"seed %d drew duplicates: %s" % [candidate, str(ids)]
		).is_equal(ids.size())


## The WEIGHTED draw is capped at `rolls`; granted rows ride on top of it, so the
## ceiling is rolls + however many checks the player beat.
func test_the_weighted_draw_never_exceeds_the_authored_roll_count() -> void:
	var withheld := {}
	for skill: String in LootTableRegistry.skills_required(ROAD):
		withheld[skill] = false
	var rolls := int(LootTableRegistry.table(ROAD)["rolls"])
	for candidate in 40:
		assert_int(LootTableRegistry.roll(ROAD, candidate, withheld).size()).is_equal(rolls)


## Failing every gated check must not shrink the container below its roll count —
## the ungated rows still fill it. A player who fails a search finds ordinary
## supplies, not an empty crate.
func test_failing_every_check_still_fills_the_container() -> void:
	var withheld := {}
	for skill: String in LootTableRegistry.skills_required(ROAD):
		withheld[skill] = false
	var rolls := int(LootTableRegistry.table(ROAD)["rolls"])
	for candidate in 20:
		assert_int(LootTableRegistry.roll(ROAD, candidate, withheld).size()).override_failure_message(
			"failing a search emptied the crate rather than withholding one row"
		).is_equal(rolls)


func test_an_unknown_table_rolls_nothing_rather_than_erroring() -> void:
	assert_bool(LootTableRegistry.has_table(&"no-such-table")).is_false()
	assert_array(LootTableRegistry.roll(&"no-such-table", 1)).is_empty()


func test_skills_required_is_stable_and_deduplicated() -> void:
	for table_id: StringName in LootTableRegistry.table_ids():
		var first := LootTableRegistry.skills_required(table_id)
		assert_array(LootTableRegistry.skills_required(table_id)).is_equal(first)
		var distinct := {}
		for skill: String in first:
			distinct[skill] = true
		assert_int(distinct.size()).is_equal(first.size())


## The gated rows must not all ride one attribute, or the table set rewards a
## single stat wearing several names.
func test_the_shipped_tables_gate_on_more_than_one_attribute() -> void:
	var attributes := {}
	for table_id: StringName in LootTableRegistry.table_ids():
		for skill: String in LootTableRegistry.skills_required(table_id):
			attributes[str(DramgidSchema.SKILLS[skill]["attribute"])] = true
	assert_int(attributes.size()).override_failure_message(
		"every gated row across every table rides %s" % str(attributes.keys())
	).is_greater(1)


## `granted_rows` and `roll` must agree, or a caller that resolves the search
## separately from the base draw (as Chest does) hands out different loot than a
## caller that rolls both at once.
func test_granted_rows_matches_what_a_full_roll_adds() -> void:
	for table_id: StringName in LootTableRegistry.table_ids():
		var gated := LootTableRegistry.skills_required(table_id)
		if gated.is_empty():
			continue
		var passed := {}
		var withheld := {}
		for skill: String in gated:
			passed[skill] = true
			withheld[skill] = false
		var earned := _item_ids(LootTableRegistry.granted_rows(table_id, passed))
		for candidate in 30:
			var base := _item_ids(LootTableRegistry.roll(table_id, candidate, withheld))
			var full := _item_ids(LootTableRegistry.roll(table_id, candidate, passed))
			var difference := PackedStringArray()
			for item_id: String in full:
				if not base.has(item_id):
					difference.append(item_id)
			assert_array(difference).override_failure_message(
				"seed %d on %s: a full roll added %s but granted_rows reports %s"
				% [candidate, table_id, str(difference), str(earned)]
			).is_equal(earned)


func test_granted_rows_is_empty_when_nothing_passed() -> void:
	for table_id: StringName in LootTableRegistry.table_ids():
		var withheld := {}
		for skill: String in LootTableRegistry.skills_required(table_id):
			withheld[skill] = false
		assert_array(LootTableRegistry.granted_rows(table_id, withheld)).is_empty()
