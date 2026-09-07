extends GdUnitTestSuite
## `docs/architecture-dramgid.md` §6 — pins the derived-stat freeze.
##
## Three jobs: the frozen formulas produce the documented grids; the migration
## report in `docs/dramgid-numbers.md` §2 still holds against the party
## `GameState` actually builds; and the sweep tool's mirror of that party is
## honest. The tool cannot read `GameState` — autoload identifiers do not exist
## in a `--script` run — so this suite is where the mirror is checked.

const Sweep := preload("res://tools/dramgid_derived_sweep.gd")
const Derived := preload("res://globals/stats/dramgid_derived.gd")
const Schema := preload("res://globals/stats/dramgid_schema.gd")

const HP_TOLERANCE := 0.15


func test_the_derived_grid_matches_the_document() -> void:
	# docs/dramgid-numbers.md §2, §3, §4, §5 — the "after" rows.
	assert_array(Sweep.across_range(Derived.max_hp)).is_equal([24, 30, 36, 42])
	assert_array(Sweep.across_range(Derived.breath_max)).is_equal([15, 18, 21, 24])
	assert_array(Sweep.across_range(Derived.attack)).is_equal([4, 6, 8, 10])
	assert_array(Sweep.across_range(Derived.defense)).is_equal([2, 3, 4, 5])


func test_no_formula_lets_the_floor_fall_below_half_the_cap() -> void:
	# §1: a bare `point x step` puts the floor at 40% of the cap, which makes an
	# attribute mandatory rather than meaningful. HP and Breath are the two the
	# player cannot opt out of, so they carry a base term.
	assert_float(Sweep.spread(Sweep.across_range(Derived.max_hp))).is_less_equal(2.0)
	assert_float(Sweep.spread(Sweep.across_range(Derived.breath_max))).is_less_equal(2.0)


func test_the_breath_pool_keeps_its_two_chosen_properties() -> void:
	# §3. Both are exact, not approximate — that is the whole argument for the
	# numbers, so a change to either must fail here.
	assert_int(Derived.breath_max(Schema.ATTRIBUTE_FLOOR)).override_failure_message(
		"minimum Intuition must reproduce today's flat 15, or existing casters regress"
	).is_equal(15)
	assert_int(Derived.breath_max(Schema.ATTRIBUTE_CAP)).override_failure_message(
		"maximum Intuition must buy exactly one Refrain (24 Breath)"
	).is_equal(24)


func test_the_hp_floor_clears_the_weakest_authored_enemy() -> void:
	# §2. Under `grit * 8` a minimum-Grit character started on 16 against
	# enemies of 14-36 HP.
	assert_int(Derived.max_hp(Schema.ATTRIBUTE_FLOOR)).is_greater(14)


func test_the_attack_range_contains_the_authored_party() -> void:
	# §4: a created character maxing Muster must not be strictly worse than the
	# pre-made protagonist, who is authored at attack 9.
	var attacks := Sweep.across_range(Derived.attack)
	assert_int(int(attacks[attacks.size() - 1])).is_greater_equal(9)


func test_the_shipped_party_still_migrates_within_fifteen_percent() -> void:
	# §2's migration report, recomputed against the party GameState BUILDS
	# rather than against the sweep's mirror of it.
	var derived := Sweep.across_range(Derived.max_hp)
	for member: PartyMember in _shipped_party():
		var fit := Sweep.nearest_point(member.max_hp, derived)
		assert_float(absf(float(fit["error"]))).override_failure_message(
			"'%s' authored HP %d has no point-buy fit within 15%% (nearest %d)"
			% [member.id, member.max_hp, int(fit["value"])]
		).is_less_equal(HP_TOLERANCE)


func test_the_sweep_mirror_of_the_shipped_party_is_honest() -> void:
	# tools/dramgid_derived_sweep.gd cannot read GameState, so it carries a
	# copy. A copy nobody checks is how a migration report starts describing a
	# party that no longer exists.
	var live: Dictionary = {}
	for member: PartyMember in _shipped_party():
		live[member.id] = [member.max_hp, member.attack, member.defense]

	assert_int(Sweep.SHIPPED_PARTY.size()).override_failure_message(
		"the sweep mirrors %d members; GameState builds %d"
		% [Sweep.SHIPPED_PARTY.size(), live.size()]
	).is_equal(live.size())

	for row: Array in Sweep.SHIPPED_PARTY:
		var member_id := str(row[0])
		assert_bool(live.has(member_id)).override_failure_message(
			"the sweep mirrors '%s', which GameState no longer builds" % member_id
		).is_true()
		assert_array([int(row[1]), int(row[2]), int(row[3])]).override_failure_message(
			"'%s' drifted: sweep says %s, GameState says %s"
			% [member_id, [row[1], row[2], row[3]], live.get(member_id, [])]
		).is_equal(live[member_id])


func test_recompute_writes_every_derived_stat_and_clamps_the_pools() -> void:
	var member := PartyMember.new()
	member.attributes = {
		Schema.ATTR_GRIT: 4,
		Schema.ATTR_MUSTER: 5,
		Schema.ATTR_ALACRITY: 3,
		Schema.ATTR_INTUITION: 2,
	}
	member.hp = 999
	member.breath = 999

	Derived.recompute(member)

	assert_int(member.max_hp).is_equal(36)
	assert_int(member.attack).is_equal(10)
	assert_int(member.defense).is_equal(3)
	assert_int(member.breath_max).is_equal(15)
	assert_int(member.hp).is_equal(36)
	assert_int(member.breath).is_equal(15)


func test_a_created_character_is_not_worse_than_the_pre_made_protagonist() -> void:
	# The live consumer: ChargenBuild.to_party_member() calls recompute(). This
	# is the regression the §4 change exists to prevent.
	var built := PartyMember.new()
	built.attributes = {
		Schema.ATTR_GRIT: Schema.ATTRIBUTE_CAP,
		Schema.ATTR_MUSTER: Schema.ATTRIBUTE_CAP,
		Schema.ATTR_ALACRITY: Schema.ATTRIBUTE_CAP,
		Schema.ATTR_INTUITION: Schema.ATTRIBUTE_CAP,
	}
	Derived.recompute(built)

	var protagonist := GameState.protagonist()
	assert_object(protagonist).is_not_null()
	assert_int(built.attack).override_failure_message(
		"a maxed-Muster created character deals less than the pre-made protagonist"
	).is_greater_equal(protagonist.attack)


func test_the_unfrozen_formulas_are_absent_on_purpose() -> void:
	# §7 and the class doc: ct_speed / to-hit / the damage power term are NOT
	# here while their consumers still read `edge`. A helper appearing before
	# §3.9 lands is a stranded formula, and this is where that gets caught.
	var probe: RefCounted = Derived.new()
	assert_bool(probe.has_method("ct_speed")).override_failure_message(
		"ct_speed() landed before §3.9 moved CombatRules off `edge` — see docs/dramgid-numbers.md §7"
	).is_false()
	assert_str(String(CombatRules.new().charge_speed_attribute)).override_failure_message(
		"CombatRules moved off `edge`; §3.9 is unblocked and §7 can now be applied"
	).is_equal("edge")


func _shipped_party() -> Array[PartyMember]:
	var members: Array[PartyMember] = []
	var protagonist := GameState.protagonist()
	if protagonist != null:
		members.append(protagonist)
	for candidate: PartyMember in GameState.recruitable_candidates():
		if candidate.max_hp > 0:
			members.append(candidate)
	return members
