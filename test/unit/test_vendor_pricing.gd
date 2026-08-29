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
	var expected_price: int = VendorData.price_for(PRICED_VENDOR_ID, PRICED_ITEM_ID, true)
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
	# Held Flame Shrine trades only at warm+ ironbrand-sentinels standing, so
	# earn that first — the test must actually reach a priced item, never
	# pass by exiting on an empty stock list.
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
