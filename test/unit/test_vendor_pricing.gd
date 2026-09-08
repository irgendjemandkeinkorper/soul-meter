extends GdUnitTestSuite

const VendorData := preload("res://globals/vendor_registry.gd")
const VendorIdsData := preload("res://data/generated/vendor_ids.gd")

const PRICED_VENDOR_ID := VendorIdsData.IRON_AND_THREAD
const PRICED_ITEM_ID := ItemIds.WEAPONS_ROADWARDEN_SPEAR
const OTHER_VENDOR_ID := VendorIdsData.RIVET_AND_SPUR

var game_state_before_test: Dictionary
var reputation_before_test: Dictionary
var quests_before_test: Dictionary
var quest_inventory_listener_disconnected: bool = false


func before_test() -> void:
	game_state_before_test = GameState.to_dict().duplicate(true)
	reputation_before_test = Reputation.to_dict().duplicate(true)
	quests_before_test = QuestRegistry.to_dict().duplicate(true)
	var quest_listener := Callable(QuestRegistry, "_on_inventory_changed")
	quest_inventory_listener_disconnected = GameState.inventory_changed.is_connected(quest_listener)
	if quest_inventory_listener_disconnected:
		GameState.inventory_changed.disconnect(quest_listener)
	GameState.vendor_stock.clear()
	GameState.vendor_restock_cycles.clear()
	GameState.gp = 500
	GameState.flags.clear()
	Reputation.from_dict({})
	QuestRegistry.reset()


func after_test() -> void:
	GameState.from_dict(game_state_before_test)
	Reputation.from_dict(reputation_before_test)
	QuestRegistry.reset()
	QuestRegistry.from_dict(quests_before_test)
	if quest_inventory_listener_disconnected:
		GameState.inventory_changed.connect(Callable(QuestRegistry, "_on_inventory_changed"))


func test_iron_and_thread_buy_prices_follow_the_reputation_band() -> void:
	# Band pricing is the EXISTING production path: price_for() resolves the
	# live band and applies the vendor's authored band_price_modifiers.
	# This test pins that the live-band price tracks the band as reputation
	# moves, and that bands are strictly ordered hostile > ... > allied.
	var cases: Array[Dictionary] = [
		{"standing": -40.0, "band": &"hostile"},
		{"standing": -15.0, "band": &"cold"},
		{"standing": 0.0, "band": &"neutral"},
		{"standing": 15.0, "band": &"warm"},
		{"standing": 40.0, "band": &"allied"},
	]
	var previous_price := 0
	for case: Dictionary in cases:
		Reputation.from_dict({})
		var standing: float = float(case["standing"])
		if not is_zero_approx(standing):
			Reputation.record(
				"vex", FactionIds.IRON_COMPANIES, standing, "Set pricing band", "test"
			)
		var band: StringName = StringName(case["band"])
		assert_str(Reputation.band(FactionIds.IRON_COMPANIES)).is_equal(String(band))
		var live_price: int = VendorData.price_for(PRICED_VENDOR_ID, PRICED_ITEM_ID, true)
		assert_int(live_price).is_equal(
			VendorData.price_for(PRICED_VENDOR_ID, PRICED_ITEM_ID, true, band)
		)
		if previous_price > 0:
			assert_int(live_price).is_less(previous_price)
		previous_price = live_price


func test_displayed_stock_and_purchase_use_the_same_band_price() -> void:
	Reputation.record(
		"vex", FactionIds.IRON_COMPANIES, Reputation.BAND_WARM,
		"Reached warm Company standing", "test"
	)
	# Through the SAME barter both other paths apply. Display and purchase were
	# always consistent with each other; this baseline was the odd one out,
	# because the bare 3-arg form defaults barter to 0.
	var expected_price: int = VendorData.price_for(
		PRICED_VENDOR_ID, PRICED_ITEM_ID, true, &"", GameState.barter_ratio()
	)
	var displayed_price: int = _displayed_buy_price(PRICED_VENDOR_ID, PRICED_ITEM_ID)
	assert_int(displayed_price).is_equal(expected_price)

	var gp_before: int = GameState.gp
	var result: Dictionary = GameState.buy_from_vendor(PRICED_VENDOR_ID, PRICED_ITEM_ID)
	assert_bool(bool(result.get("ok", false))).is_true()
	assert_int(int(result.get("price", 0))).is_equal(expected_price)
	assert_int(GameState.gp).is_equal(gp_before - expected_price)


func test_unclaimed_bed_resolution_moves_iron_and_thread_price_through_reputation() -> void:
	Reputation.record(
		"vex", FactionIds.IRON_COMPANIES, 10.0,
		"Standing before the veteran's debt is answered", "test"
	)
	assert_str(Reputation.band(FactionIds.IRON_COMPANIES)).is_equal("neutral")
	var price_before: int = VendorData.price_for(PRICED_VENDOR_ID, PRICED_ITEM_ID, true)

	QuestRegistry.offer_side_quest(QuestRegistry.UNCLAIMED_BED)
	GameState.set_flag("dom_unclaimed_bed_identified", true)
	var resolved: bool = QuestRegistry.resolve_side_quest(
		QuestRegistry.UNCLAIMED_BED, "return-the-name"
	)

	assert_bool(resolved).is_true()
	assert_float(Reputation.standing(FactionIds.IRON_COMPANIES)).is_equal_approx(15.0, 0.001)
	assert_str(Reputation.band(FactionIds.IRON_COMPANIES)).is_equal("warm")
	assert_int(VendorData.price_for(PRICED_VENDOR_ID, PRICED_ITEM_ID, true)).is_less(price_before)


func test_a_different_factions_vendor_ignores_iron_companies_standing() -> void:
	# Held Flame Shrine trades only at warm+ ironbrand-sentinels standing:
	# first prove the gate actually refuses at neutral (non-vacuous — this
	# fails if the minimum_band gate is removed), then earn warm standing so
	# the test reaches a genuinely priced item.
	var refused: Dictionary = GameState.buy_from_vendor(
		VendorIdsData.HELD_FLAME_SHRINE, ItemIds.RELICS_VOTIVE_CINDER
	)
	assert_bool(bool(refused.get("ok", true))).is_false()
	assert_str(str(refused.get("reason", ""))).is_equal("trade_refused")
	Reputation.record(
		"vex", FactionIds.IRONBRAND_SENTINELS, Reputation.BAND_WARM,
		"Reached warm Sentinel standing", "test"
	)
	var shrine_id := VendorIdsData.HELD_FLAME_SHRINE
	var shrine_stock: Array[Dictionary] = GameState.available_vendor_stock(shrine_id)
	assert_array(shrine_stock).is_not_empty()
	var shrine_item := str(shrine_stock[0].get("id", ""))
	assert_str(shrine_item).is_not_empty()
	var price_before: int = VendorData.price_for(shrine_id, shrine_item, true)
	assert_int(price_before).is_greater(0)
	Reputation.record(
		"vex", FactionIds.IRON_COMPANIES, Reputation.BAND_ALLIED,
		"Reached allied Company standing", "test"
	)
	assert_int(VendorData.price_for(shrine_id, shrine_item, true)).is_equal(price_before)


func _displayed_buy_price(vendor_id: String, item_id: String) -> int:
	var stock: Array[Dictionary] = GameState.available_vendor_stock(vendor_id)
	for row: Dictionary in stock:
		if str(row.get("id", "")) == item_id:
			return int(row.get("buy_price", 0))
	return 0


## #284 / game-identity ruling 7 ("stats matter outside combat"). Barter is a
## STANDING modifier off Sway, not a per-transaction roll, because a price the
## player is shown has to be the price they are charged.
func test_barter_at_zero_leaves_every_shipped_price_exactly_as_it_was() -> void:
	assert_float(VendorData.barter_multiplier(true, 0.0)).override_failure_message(
		"adding barter must not move a single shipped price on its own"
	).is_equal(1.0)
	assert_float(VendorData.barter_multiplier(false, 0.0)).is_equal(1.0)


func test_barter_buys_cheaper_and_sells_dearer() -> void:
	var buy := VendorData.barter_multiplier(true, 1.0)
	var sell := VendorData.barter_multiplier(false, 1.0)

	assert_float(buy).is_less(1.0)
	assert_float(sell).is_greater(1.0)
	# Symmetric about 1.0, so a negotiator is never punished in one direction for
	# being rewarded in the other.
	assert_float(buy + sell).is_equal_approx(2.0, 0.0001)


## Monotone: a better negotiator is never charged more, at any ratio.
func test_a_better_negotiator_is_never_charged_more() -> void:
	var previous := VendorData.barter_multiplier(true, 0.0)
	for step: int in range(1, 11):
		var current := VendorData.barter_multiplier(true, float(step) / 10.0)
		assert_float(current).override_failure_message(
			"buy multiplier rose between ratio %.1f and %.1f" % [(step - 1) / 10.0, step / 10.0]
		).is_less_equal(previous)
		previous = current


func test_the_barter_ratio_clamps_outside_zero_to_one() -> void:
	assert_float(VendorData.barter_multiplier(true, 4.0)).is_equal(
		VendorData.barter_multiplier(true, 1.0)
	)
	assert_float(VendorData.barter_multiplier(true, -4.0)).is_equal(
		VendorData.barter_multiplier(true, 0.0)
	)


## The one that matters. A barter modifier applied to the shop display but not to
## the transaction is invisible until a player notices the silver does not add
## up — the same class of defect the combat forecast contract exists to prevent.
func test_the_displayed_price_is_the_price_charged() -> void:
	GameState.gp = 500
	var displayed: int = 0
	for row: Dictionary in GameState.available_vendor_stock(PRICED_VENDOR_ID):
		if str(row.get("id", "")) == PRICED_ITEM_ID:
			displayed = int(row["buy_price"])
			break
	assert_int(displayed).override_failure_message(
		"the priced fixture item is not on the vendor's shelf"
	).is_greater(0)

	var before := GameState.gp
	var result := GameState.buy_from_vendor(PRICED_VENDOR_ID, PRICED_ITEM_ID)

	assert_bool(bool(result["ok"])).override_failure_message(
		"the fixture purchase was refused: %s" % str(result.get("reason", ""))
	).is_true()
	assert_int(int(result["price"])).override_failure_message(
		"the shop displayed %d silver and the purchase charged something else" % displayed
	).is_equal(displayed)
	assert_int(before - GameState.gp).is_equal(displayed)


## An empty party barters at zero rather than erroring — shops are reachable
## from states where the party is not yet built.
func test_an_empty_party_barters_at_zero() -> void:
	var party_before := GameState.party.duplicate()
	GameState.party.clear()
	assert_float(GameState.barter_ratio()).is_equal(0.0)
	GameState.party.assign(party_before)

## Barter must roll the SAME person every other default skill check rolls.
## `party[0]` is not that person — the tavern picker can reorder the party — and
## a barter subject that quietly differs from the check subject would show up as
## prices that move when the player rearranges their line-up.
## The invariant #415 exists to protect — the price shown IS the price charged —
## had only ever been exercised at a barter ratio of ZERO, where every path
## trivially agrees. It took a full-suite run leaving a skilled protagonist
## behind for the gap to surface, and it surfaced as two unrelated-looking
## failures rather than as this one.
func test_the_displayed_price_is_the_charged_price_with_barter_live() -> void:
	var party_before := GameState.party.duplicate()
	var protagonist := PartyMember.new()
	protagonist.id = GameState.PROTAGONIST_ID
	protagonist.attributes["decorum"] = 5
	GameState.party.assign([protagonist])

	assert_float(GameState.barter_ratio()).override_failure_message(
		"barter is at zero, so this case degenerates into the one it was written to escape"
	).is_greater(0.0)

	var displayed: int = _displayed_buy_price(PRICED_VENDOR_ID, PRICED_ITEM_ID)
	var gp_before: int = GameState.gp
	var result: Dictionary = GameState.buy_from_vendor(PRICED_VENDOR_ID, PRICED_ITEM_ID)
	GameState.party.assign(party_before)

	assert_bool(bool(result.get("ok", false))).is_true()
	assert_int(int(result.get("price", 0))).override_failure_message(
		"the shop charged a different number than it displayed once barter was live"
	).is_equal(displayed)
	assert_int(gp_before - GameState.gp).is_equal(displayed)


func test_barter_rolls_the_protagonist_not_merely_the_first_party_slot() -> void:
	var party_before := GameState.party.duplicate()

	var protagonist := PartyMember.new()
	protagonist.id = GameState.PROTAGONIST_ID
	protagonist.attributes["decorum"] = 5
	var companion := PartyMember.new()
	companion.id = "test-companion"
	companion.attributes["decorum"] = 0

	GameState.party.assign([protagonist])
	var leading := GameState.barter_ratio()
	# Same people, protagonist no longer in slot 0.
	GameState.party.assign([companion, protagonist])
	var trailing := GameState.barter_ratio()
	GameState.party.assign(party_before)

	assert_float(leading).override_failure_message(
		"a skilled protagonist should barter above zero, or this case proves nothing"
	).is_greater(0.0)
	assert_float(trailing).override_failure_message(
		"reordering the party changed the price. Barter is reading party[0] again"
	).is_equal(leading)

