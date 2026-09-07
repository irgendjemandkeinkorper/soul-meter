extends GdUnitTestSuite
## E1.6 (#327): weight invariants, RNG discipline, and what the policy bounds actually produce.
##
## The RNG cases matter as much as the arithmetic. §4.10 reproduces a slot roll by seeding one
## generator from `hash([world_seed, table_id, slot_id, day_index])`, which only works if the
## helpers consume a fixed number of draws — so the draw count is asserted, not assumed.

const Spawn := preload("res://globals/world/spawn_math.gd")

# The table §4.10 uses in its own example, so the note's numbers can be read against the spec's.
const WILDERNESS_ENTRIES := [
	{"archetype_id": "bog-wight", "weight": 40},
	{"archetype_id": "loam-boar", "weight": 40},
	{"empty": true, "weight": 20},
]
const RUNGS := ["low", "rising", "tolling", "ringing", "unprecedented"]


func test_normalized_drops_unpickable_entries_and_shares_sum_to_one() -> void:
	var entries: Array = [
		{"archetype_id": "bog-wight", "weight": 3},
		{"archetype_id": "ghost-entry", "weight": 0},
		{"archetype_id": "negative-entry", "weight": -5},
		{"empty": true, "weight": 1},
		"not a dictionary",
	]
	var table: Array = Spawn.normalized(entries)
	assert_int(table.size()).override_failure_message(
		"a zero-weight entry can never be picked; it must not survive normalisation"
	).is_equal(2)
	var total_share: float = 0.0
	for entry: Dictionary in table:
		total_share += float(entry["share"])
	assert_float(total_share).is_equal_approx(1.0, 0.0001)
	assert_float(Spawn.empty_share(entries)).is_equal_approx(0.25, 0.0001)


func test_the_same_seed_always_rolls_the_same_slot() -> void:
	# The whole persistence design rests on this: a slot re-rolled on the same day must give the
	# same answer, or leaving and returning would reshuffle the map.
	for trial: int in 50:
		var first := RandomNumberGenerator.new()
		var second := RandomNumberGenerator.new()
		first.seed = hash([4242, "loamroot-grove-ambient", "hollow-east", trial])
		second.seed = first.seed
		var a: Dictionary = Spawn.pick(WILDERNESS_ENTRIES, first)
		var b: Dictionary = Spawn.pick(WILDERNESS_ENTRIES, second)
		assert_int(int(a["index"])).is_equal(int(b["index"]))
		assert_int(Spawn.pack_size({"min": 1, "max": 3}, first)).is_equal(
			Spawn.pack_size({"min": 1, "max": 3}, second)
		)


func test_pick_and_pack_size_each_consume_exactly_one_draw() -> void:
	# A helper that quietly took two draws would still be deterministic on its own and would still
	# pass every distribution test here, while silently desynchronising anything drawing after it.
	var rng := RandomNumberGenerator.new()
	rng.seed = 99
	var control := RandomNumberGenerator.new()
	control.seed = 99

	Spawn.pick(WILDERNESS_ENTRIES, rng)
	control.randi_range(1, 100)
	assert_int(rng.state).override_failure_message("pick() must consume exactly one draw").is_equal(
		control.state
	)

	Spawn.pack_size({"min": 1, "max": 4}, rng)
	control.randi_range(1, 10)
	assert_int(rng.state).override_failure_message(
		"pack_size() must consume exactly one draw"
	).is_equal(control.state)


func test_an_unusable_table_clears_the_slot_without_touching_the_stream() -> void:
	# A table that failed validation must not be able to stop a scene loading, and must not shift
	# the draws every later slot in the same scene depends on.
	var rng := RandomNumberGenerator.new()
	rng.seed = 7
	var before: int = rng.state
	var result: Dictionary = Spawn.pick([], rng)
	assert_bool(bool(result["empty"])).is_true()
	assert_int(int(result["index"])).is_equal(-1)
	assert_int(rng.state).is_equal(before)
	assert_int(Spawn.pack_size({"min": 2, "max": 2}, rng)).is_equal(2)
	assert_int(rng.state).override_failure_message(
		"a single-value range has nothing to draw"
	).is_equal(before)


func test_picks_land_on_their_authored_shares() -> void:
	var counts: Dictionary = {}
	var trials: int = 20000
	for trial: int in trials:
		var rng := RandomNumberGenerator.new()
		rng.seed = hash([12345, "loamroot-grove-ambient", "hollow-east", trial])
		var got: Dictionary = Spawn.pick(WILDERNESS_ENTRIES, rng)
		var key: String = "empty" if bool(got["empty"]) else String(got["archetype_id"])
		counts[key] = int(counts.get(key, 0)) + 1
	assert_float(float(counts["bog-wight"]) / float(trials)).is_between(0.38, 0.42)
	assert_float(float(counts["loam-boar"]) / float(trials)).is_between(0.38, 0.42)
	assert_float(float(counts["empty"]) / float(trials)).is_between(0.18, 0.22)


func test_pack_size_stays_in_range_and_leans_small() -> void:
	var counts: Dictionary = {1: 0, 2: 0, 3: 0}
	for trial: int in 6000:
		var rng := RandomNumberGenerator.new()
		rng.seed = hash(["pack", trial])
		var size: int = Spawn.pack_size({"min": 1, "max": 3}, rng)
		assert_int(size).is_between(1, 3)
		counts[size] = int(counts[size]) + 1
	assert_int(int(counts[1])).override_failure_message(
		"the smallest pack must be the most common; a uniform roll would make a three-pack as "
		+ "likely as a lone creature and a map of those reads as a swarm"
	).is_greater(int(counts[2]))
	assert_int(int(counts[2])).is_greater(int(counts[3]))
	assert_float(Spawn.expected_pack_size({"min": 1, "max": 3})).is_equal_approx(1.6667, 0.001)


func test_pack_size_handles_a_reversed_or_missing_range() -> void:
	var rng := RandomNumberGenerator.new()
	rng.seed = 3
	assert_int(Spawn.pack_size({"min": 5, "max": 2}, rng)).is_equal(5)
	assert_int(Spawn.pack_size({}, rng)).is_equal(1)
	assert_int(Spawn.pack_size({"min": 0, "max": 0}, rng)).override_failure_message(
		"a slot that spawns cannot spawn nothing; that is what the empty sentinel is for"
	).is_equal(1)


func test_thinning_only_adds_weight_and_never_to_the_empty_sentinel() -> void:
	var authored: Array = Spawn.scaled_weights(WILDERNESS_ENTRIES, 0)
	for tier: int in range(0, Spawn.MAX_THINNING_TIER + 1):
		var scaled: Array = Spawn.scaled_weights(WILDERNESS_ENTRIES, tier)
		for index: int in scaled.size():
			assert_int(int(scaled[index]["weight"])).override_failure_message(
				"thinning must never suppress something the author placed"
			).is_greater_equal(int(authored[index]["weight"]))
			if bool(scaled[index]["empty"]):
				assert_int(int(scaled[index]["weight"])).override_failure_message(
					"the sentinel carries no archetype and so has no danger rank to scale"
				).is_equal(int(authored[index]["weight"]))


func test_tier_zero_returns_the_authored_weights_exactly() -> void:
	# The property that keeps the coupling owner-tunable rather than baked in.
	var authored: Array = Spawn.normalized(WILDERNESS_ENTRIES)
	var scaled: Array = Spawn.scaled_weights(WILDERNESS_ENTRIES, 0)
	for index: int in authored.size():
		assert_int(int(scaled[index]["weight"])).is_equal(int(authored[index]["weight"]))


func test_a_thinned_map_is_both_more_dangerous_and_less_often_quiet() -> void:
	var previous_empty: float = 1.0
	for tier: int in range(0, Spawn.MAX_THINNING_TIER + 1):
		var scaled: Array = Spawn.scaled_weights(WILDERNESS_ENTRIES, tier)
		var share: float = Spawn.empty_share(scaled)
		assert_float(share).override_failure_message(
			"nearer the Wound a slot should roll 'nothing here' less often, not more"
		).is_less(previous_empty)
		previous_empty = share
	assert_float(Spawn.empty_share(Spawn.scaled_weights(WILDERNESS_ENTRIES, 3))).is_equal_approx(
		0.1538, 0.001
	)


func test_thinning_moves_a_small_table_and_a_large_one_by_the_same_amount() -> void:
	# The reason the step is a share of the table's own total rather than the flat +1 the travel
	# director adds. On §4.10's own 40/40/20 example that flat step is worth 1.7 points at tier 3,
	# which is invisible in play; on a 4/4/2 table it is worth 15. One constant cannot mean both.
	var large: Array = Spawn.scaled_weights(WILDERNESS_ENTRIES, 3)
	var small: Array = Spawn.scaled_weights(
		[
			{"archetype_id": "bog-wight", "weight": 4},
			{"archetype_id": "loam-boar", "weight": 4},
			{"empty": true, "weight": 2},
		],
		3
	)
	for index: int in large.size():
		assert_float(float(small[index]["share"])).override_failure_message(
			"the same thinning tier must mean the same mix whatever scale the weights use"
		).is_equal_approx(float(large[index]["share"]), 0.01)


func test_respawn_cadence_saturates_and_the_zhavar_ladder_lands_on_the_cap_instead() -> void:
	# Pinned because it is a limitation, not a bug. Cadence is counted in whole days and a
	# `limited` slot must be at least 3, so the ladder runs out of room after two rungs and
	# `tolling`, `ringing` and `unprecedented` become the same instruction.
	var days: Array[int] = []
	for rung: int in RUNGS.size():
		days.append(Spawn.respawn_days(3, rung))
	assert_array(days).is_equal([3, 2, 1, 1, 1])
	assert_int(Spawn.respawn_days(1, 4)).override_failure_message(
		"nothing refills more than once a day, whatever the front is doing"
	).is_equal(Spawn.MIN_RESPAWN_DAYS)

	# So the visible term is the cap: more things at once, which the player can see.
	var caps: Array[int] = []
	for rung: int in RUNGS.size():
		caps.append(Spawn.max_alive_for("wilderness", rung))
	assert_array(caps).override_failure_message(
		"the ladder needs an outlet that does not saturate; %s" % str(caps)
	).is_equal([12, 14, 16, 18, 20])


func test_the_front_never_opens_a_town_and_never_promotes_a_settled_map() -> void:
	for rung: int in RUNGS.size():
		assert_int(Spawn.max_alive_for("none", rung)).override_failure_message(
			"nothing about the front may put spawns in a respawn_policy \"none\" scene"
		).is_equal(0)
		assert_int(Spawn.max_alive_for("limited", rung)).override_failure_message(
			"raising a settled map's ceiling would quietly turn it into wilderness"
		).is_equal(Spawn.MAX_ALIVE_DEFAULTS["limited"])
	assert_int(Spawn.max_alive_default("typo-policy")).override_failure_message(
		"an unknown policy must get the strictest answer, not the most permissive"
	).is_equal(0)
	assert_int(Spawn.max_alive_for("wilderness", 2, 6)).is_equal(10)


func test_a_none_location_refuses_every_table_and_a_lawful_limited_one_passes() -> void:
	var lawful: Dictionary = {
		"id": "jawbrace-ambient",
		"slots": [
			{
				"id": "north-lane",
				"respawn_days": 3,
				"pack_size": {"min": 1, "max": 2},
				"entries": [
					{"archetype_id": "loam-boar", "weight": 50}, {"empty": true, "weight": 50}
				],
			}
		],
	}
	assert_array(Spawn.policy_violations("limited", lawful)).is_empty()
	assert_array(Spawn.policy_violations("wilderness", lawful)).is_empty()
	var refused: PackedStringArray = Spawn.policy_violations("none", lawful)
	assert_int(refused.size()).is_equal(1)
	assert_str(refused[0]).contains("respawn_policy")


func test_each_limited_bound_reports_itself_separately() -> void:
	var unlawful: Dictionary = {
		"id": "overreaching",
		"slots": [
			{
				"id": "a",
				"respawn_days": 1,
				"pack_size": {"min": 1, "max": 4},
				"entries": [
					{"archetype_id": "bog-wight", "weight": 90}, {"empty": true, "weight": 10}
				],
			},
			{"id": "b", "respawn_days": 3, "pack_size": {"min": 1, "max": 1}, "entries": []},
			{"id": "c", "respawn_days": 3, "pack_size": {"min": 1, "max": 1}, "entries": []},
		],
	}
	var problems: PackedStringArray = Spawn.policy_violations("limited", unlawful)
	var joined: String = "\n".join(problems)
	assert_str(joined).contains("3 slots")
	assert_str(joined).contains("respawns every 1 day")
	assert_str(joined).contains("packs up to 4")
	assert_str(joined).contains("empty only 10%")


func test_the_two_policies_land_where_the_design_note_says_they_do() -> void:
	# The density sweep the note is written against. A `limited` location at its own bounds
	# averages a shade over one creature per eligible visit and refills at most every three days —
	# close enough to `none` that the policy earns its name.
	var limited_entries: Array = [
		{"archetype_id": "loam-boar", "weight": 50}, {"empty": true, "weight": 50}
	]
	var limited_per_slot: float = Spawn.expected_spawns_per_slot(
		limited_entries, {"min": 1, "max": 2}
	)
	assert_float(limited_per_slot * float(Spawn.LIMITED_MAX_SLOTS)).is_equal_approx(1.333, 0.01)

	# Wilderness needs nine slots before the default cap starts biting, so `max_alive` is a
	# backstop against a dense map rather than a limit an ordinary one runs into.
	var wilderness_per_slot: float = Spawn.expected_spawns_per_slot(
		WILDERNESS_ENTRIES, {"min": 1, "max": 3}
	)
	assert_float(wilderness_per_slot).is_equal_approx(1.333, 0.01)
	assert_float(float(Spawn.max_alive_default("wilderness")) / wilderness_per_slot).is_equal_approx(
		9.0, 0.1
	)
