extends GdUnitTestSuite

const VendorData := preload("res://globals/vendor_registry.gd")
const VendorIdsData := preload("res://data/generated/vendor_ids.gd")
const VENDOR := VendorIdsData.LOAM_AND_LANTERN
var runtime_before: Dictionary


func before_test() -> void:
	runtime_before = SaveGame.capture_runtime_state()
	SaveGame.world_structures.from_dict({})
	Reputation.from_dict({})
	GameState.gp = 500


func after_test() -> void:
	SaveGame.restore_runtime_state(runtime_before)


func test_closed_premises_refuse_trade_and_preserve_stock_and_money() -> void:
	SaveGame.world_structures.register_structure("test-market", 10, 4)
	SaveGame.world_structures.register_service(VENDOR, "test-market", "item-shop")
	var quantity := GameState.vendor_item_quantity(VENDOR, ItemIds.CONSUMABLES_LOAM_BREAD)
	var money := GameState.gp
	SaveGame.world_structures.damage("test-market", 10, WorldClock.phase_count)
	var status := VendorData.trade_status(VENDOR, &"neutral")
	assert_bool(status["allowed"]).is_false()
	assert_str(String(status.get("blocked_by"))).is_equal("structure")
	GameState.buy_from_vendor(VENDOR, ItemIds.CONSUMABLES_LOAM_BREAD)
	assert_int(GameState.gp).is_equal(money)
	assert_int(GameState.vendor_item_quantity(VENDOR, ItemIds.CONSUMABLES_LOAM_BREAD)).is_equal(quantity)
	assert_array(GameState.available_vendor_stock(VENDOR)).is_empty()


func test_unregistered_merchants_keep_their_existing_trade_rules() -> void:
	assert_bool(VendorData.trade_status(VENDOR, &"neutral")["allowed"]).is_true()
	assert_bool(VendorData.trade_status(VENDOR, &"hostile")["allowed"]).is_false()


func test_relocated_merchant_has_one_service_site_and_keeps_stock_and_standing_rules() -> void:
	var state = SaveGame.world_structures
	state.register_structure("test-market", 10, 4)
	state.register_service(VENDOR, "test-market", "item-shop", "dom")
	GameState.vendor_item_quantity(VENDOR, ItemIds.CONSUMABLES_LOAM_BREAD)
	var stock_before: Dictionary = GameState.vendor_stock.duplicate(true)
	assert_bool(VendorData.trade_status(VENDOR, &"neutral", "item-shop")["allowed"]).is_true()
	state.damage("test-market", 10, WorldClock.phase_count)
	assert_bool(VendorData.trade_status(VENDOR, &"neutral", "item-shop")["allowed"]).is_false()
	assert_bool(VendorData.trade_status(VENDOR, &"neutral", "dom")["allowed"]).is_true()
	assert_bool(VendorData.trade_status(VENDOR, &"hostile", "dom")["allowed"]).is_false()
	state.advance(WorldClock.phase_count + 4)
	assert_bool(VendorData.trade_status(VENDOR, &"neutral", "item-shop")["allowed"]).is_true()
	assert_bool(VendorData.trade_status(VENDOR, &"neutral", "dom")["allowed"]).is_false()
	assert_dict(GameState.vendor_stock).is_equal(stock_before)
