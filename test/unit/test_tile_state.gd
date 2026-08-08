extends GdUnitTestSuite
## Issue #139 — TileState: per-tile element charge, residue and detonation.
## Covers the issue's own acceptance line (clash strike on a charge-2 tile deals +18 and
## zeroes the tile; residue accumulates and caps at 3; Hush suspends both), plus the
## round-trip and determinism properties Gate T criteria 7 and 8 require.

const TileState := preload("res://globals/combat/tile_state.gd")

## Suul/Daar are a Clash pair per `ui/theme/ds.gd`'s Wheel-of-Ten comment
## ("Clashes: Suul/Daar, Bloei/Molm, Aqua/Scor, Khor/Nul, Terra/Strom").
const CHARGE_ELEMENT := &"suul"
const CLASH_ELEMENT := &"daar"
## Bloei is Chord-adjacent to Suul, not Clash — used to prove a non-clash strike never
## detonates.
const CHORD_ELEMENT := &"bloei"


func test_residue_accumulates_and_caps_at_three() -> void:
	var tile := TileState.create(&"battle-1", 2, 3)

	var first := tile.apply_residue(CHARGE_ELEMENT)
	assert_bool(first["allowed"]).is_true()
	assert_int(tile.charge_level).is_equal(1)

	tile.apply_residue(CHARGE_ELEMENT)
	var third := tile.apply_residue(CHARGE_ELEMENT)
	assert_int(tile.charge_level).is_equal(3)
	assert_bool(third["capped"]).is_true()

	var fourth := tile.apply_residue(CHARGE_ELEMENT)
	assert_int(tile.charge_level).is_equal(3)
	assert_bool(fourth["capped"]).is_true()
	assert_str(String(tile.charge_element_id)).is_equal(String(CHARGE_ELEMENT))


func test_clash_strike_on_charge_two_tile_deals_eighteen_and_zeroes() -> void:
	var tile := TileState.create(&"battle-1", 4, 4)
	tile.apply_residue(CHARGE_ELEMENT)
	tile.apply_residue(CHARGE_ELEMENT)
	assert_int(tile.charge_level).is_equal(2)

	var result := tile.strike(CLASH_ELEMENT)

	assert_bool(result["allowed"]).is_true()
	assert_bool(result["detonated"]).is_true()
	assert_int(result["bonus_damage"]).is_equal(18)
	assert_int(tile.charge_level).is_equal(0)
	assert_str(String(tile.charge_element_id)).is_equal("")
	assert_bool(tile.is_charged()).is_false()


func test_non_clash_strike_does_not_detonate() -> void:
	var tile := TileState.create(&"battle-1", 1, 1)
	tile.apply_residue(CHARGE_ELEMENT)
	tile.apply_residue(CHARGE_ELEMENT)

	var result := tile.strike(CHORD_ELEMENT)

	assert_bool(result["detonated"]).is_false()
	assert_int(result["bonus_damage"]).is_equal(0)
	assert_int(tile.charge_level).is_equal(2)


func test_hush_suppresses_residue_and_detonation() -> void:
	var tile := TileState.create(&"battle-1", 5, 5)
	tile.apply_residue(CHARGE_ELEMENT)
	tile.apply_residue(CHARGE_ELEMENT)
	tile.hush = true

	var residue_result := tile.apply_residue(CHARGE_ELEMENT)
	assert_bool(residue_result["allowed"]).is_false()
	assert_str(String(residue_result["blocked_by"])).is_equal("hush")
	assert_int(tile.charge_level).is_equal(2)

	var strike_result := tile.strike(CLASH_ELEMENT)
	assert_bool(strike_result["allowed"]).is_false()
	assert_str(String(strike_result["blocked_by"])).is_equal("hush")
	assert_bool(strike_result["detonated"]).is_false()
	assert_int(tile.charge_level).is_equal(2)


func test_action_multiplier_scales_with_charge_in_matching_element_only() -> void:
	var tile := TileState.create(&"battle-1", 0, 0)
	tile.apply_residue(CHARGE_ELEMENT)
	tile.apply_residue(CHARGE_ELEMENT)
	tile.apply_residue(CHARGE_ELEMENT)

	assert_float(tile.action_multiplier(CHARGE_ELEMENT)).is_equal_approx(1.3, 0.0001)
	assert_float(tile.action_multiplier(CLASH_ELEMENT)).is_equal_approx(1.0, 0.0001)

	tile.hush = true
	assert_float(tile.action_multiplier(CHARGE_ELEMENT)).is_equal_approx(1.0, 0.0001)


func test_unknown_element_is_refused_distinctly_from_hush() -> void:
	var tile := TileState.create(&"battle-1", 0, 0)

	var result := tile.apply_residue(&"not_a_real_element")

	assert_bool(result["allowed"]).is_false()
	assert_str(String(result["blocked_by"])).is_equal("unknown_element")
	assert_bool(tile.is_charged()).is_false()


func test_to_dict_from_dict_round_trip_is_lossless() -> void:
	var tile := TileState.create(&"battle-7", 6, 9, 2)
	tile.apply_residue(CHARGE_ELEMENT)
	tile.apply_residue(CHARGE_ELEMENT)
	tile.hush = true

	var restored := TileState.from_dict(tile.to_dict())

	assert_str(String(restored.battle_id)).is_equal(String(tile.battle_id))
	assert_int(restored.x).is_equal(tile.x)
	assert_int(restored.y).is_equal(tile.y)
	assert_str(String(restored.charge_element_id)).is_equal(String(tile.charge_element_id))
	assert_int(restored.charge_level).is_equal(tile.charge_level)
	assert_int(restored.height_delta).is_equal(tile.height_delta)
	assert_bool(restored.hush).is_equal(tile.hush)
	assert_that(restored.to_dict()).is_equal(tile.to_dict())


func test_determinism_repeated_runs_produce_identical_results() -> void:
	var operations: Callable = func() -> Dictionary:
		var tile := TileState.create(&"battle-9", 3, 3)
		tile.apply_residue(CHARGE_ELEMENT)
		tile.apply_residue(CHARGE_ELEMENT)
		var strike_result := tile.strike(CLASH_ELEMENT)
		return {
			"tile": tile.to_dict(),
			"strike_allowed": strike_result["allowed"],
			"detonated": strike_result["detonated"],
			"bonus_damage": strike_result["bonus_damage"],
		}

	var first: Dictionary = operations.call()
	for _iteration in range(10):
		var repeat: Dictionary = operations.call()
		assert_that(repeat).is_equal(first)


func test_drain_charge_shaves_one_level_without_detonating() -> void:
	var tile := TileState.new()
	tile.apply_residue(&"suul")
	tile.apply_residue(&"suul")
	assert_int(tile.charge_level).is_equal(2)

	var result: Dictionary = tile.drain_charge(1)

	# A drain is not a strike: no detonation, no bonus damage, charge survives.
	assert_bool(bool(result.get("allowed", false))).is_true()
	assert_int(int(result.get("drained", 0))).is_equal(1)
	assert_bool(bool(result.get("cleared", true))).is_false()
	assert_int(tile.charge_level).is_equal(1)
	assert_str(String(tile.charge_element_id)).is_equal("suul")


func test_drain_charge_clears_the_element_at_zero() -> void:
	var tile := TileState.new()
	tile.apply_residue(&"suul")

	var result: Dictionary = tile.drain_charge(1)

	assert_bool(bool(result.get("cleared", false))).is_true()
	assert_bool(tile.is_charged()).is_false()


func test_drain_charge_is_refused_under_a_hushwarden_field() -> void:
	# Hush suspends ALL charge movement, drains included. Weather's clash drain
	# reaches tiles through this method, so the guard has to live here rather
	# than in every caller.
	var tile := TileState.new()
	tile.apply_residue(&"suul")
	tile.hush = true

	var result: Dictionary = tile.drain_charge(1)

	assert_bool(bool(result.get("allowed", true))).is_false()
	assert_str(String(result.get("blocked_by", ""))).is_equal("hush")
	assert_int(tile.charge_level).is_equal(1)
