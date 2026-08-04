extends GdUnitTestSuite

const SaveGameScript := preload("res://globals/save_game.gd")
const VendorData := preload("res://globals/vendor_registry.gd")
const VendorIdsData := preload("res://data/generated/vendor_ids.gd")

var game_state_before_test: Dictionary
var reputation_before_test: Dictionary
var quest_inventory_listener_disconnected := false


func before_test() -> void:
	game_state_before_test = GameState.to_dict()
	reputation_before_test = Reputation.to_dict()
	var quest_listener := Callable(QuestRegistry, "_on_inventory_changed")
	quest_inventory_listener_disconnected = GameState.inventory_changed.is_connected(quest_listener)
	if quest_inventory_listener_disconnected:
		GameState.inventory_changed.disconnect(quest_listener)
	GameState.vendor_stock.clear()
	GameState.vendor_restock_cycles.clear()
	GameState.gp = 500
	Reputation.from_dict({})


func after_test() -> void:
	GameState.from_dict(game_state_before_test)
	Reputation.from_dict(reputation_before_test)
	if quest_inventory_listener_disconnected:
		GameState.inventory_changed.connect(Callable(QuestRegistry, "_on_inventory_changed"))


func test_twelve_generated_vendors_have_authored_economy_fields() -> void:
	var vendors := VendorData.all_vendors()
	assert_int(vendors.size()).is_equal(12)
	var ids := {}
	var npc_ids := {}
	for vendor: Dictionary in vendors:
		var vendor_id := str(vendor["id"])
		var npc_id := str(vendor["npc_id"])
		assert_bool(StableIds.is_valid(StableIds.VENDOR, vendor_id)).is_true()
		assert_bool(StableIds.is_valid(StableIds.ACTOR, npc_id)).is_true()
		assert_bool(StableIds.is_valid(StableIds.ZONE, str(vendor["site_id"]))).is_true()
		assert_bool(str(vendor["site_name"]).is_empty()).is_false()
		assert_bool(vendor["stock"] is Array).is_true()
		assert_bool(vendor["stock"].is_empty()).is_false()
		assert_bool(vendor["band_price_modifiers"] is Dictionary).is_true()
		assert_bool(vendor["restock"] is Dictionary).is_true()
		assert_bool(str(vendor["restock"].get("mode", "")).is_empty()).is_false()
		ids[vendor_id] = true
		npc_ids[npc_id] = true
	assert_int(ids.size()).is_equal(12)
	assert_int(npc_ids.size()).is_equal(12)


func test_fr_402_has_at_least_three_explicit_band_gated_reactions() -> void:
	var reactions := VendorData.band_gated_reactions()
	assert_int(reactions.size()).is_greater(2)
	var reaction_vendors := {}
	for reaction: Dictionary in reactions:
		reaction_vendors[str(reaction["vendor_id"])] = true
		assert_bool(str(reaction.get("kind", "")).is_empty()).is_false()
		assert_bool(str(reaction.get("message", "")).is_empty()).is_false()
	assert_int(reaction_vendors.size()).is_greater(2)


func test_band_changes_prices_and_generated_stock() -> void:
	var cold_price := VendorData.price_for(
		VendorIdsData.LOAM_AND_LANTERN, ItemIds.CONSUMABLES_LOAM_BREAD, true, &"cold"
	)
	var warm_price := VendorData.price_for(
		VendorIdsData.LOAM_AND_LANTERN, ItemIds.CONSUMABLES_LOAM_BREAD, true, &"warm"
	)
	assert_int(cold_price).is_greater(warm_price)
	assert_bool(
		_stock_contains(
			VendorData.stock_for(VendorIdsData.LOAM_AND_LANTERN, &"neutral"),
			ItemIds.TOOLS_SOUL_GAUGE
		)
	).is_false()
	assert_bool(
		_stock_contains(
			VendorData.stock_for(VendorIdsData.LOAM_AND_LANTERN, &"warm"),
			ItemIds.TOOLS_SOUL_GAUGE
		)
	).is_true()


func test_buy_moves_gp_item_and_vendor_stock_atomically() -> void:
	var item_id := ItemIds.CONSUMABLES_LOAM_BREAD
	var gp_before := GameState.gp
	var item_before := GameState.item_count(item_id)
	var stock_before := GameState.vendor_item_quantity(VendorIdsData.LOAM_AND_LANTERN, item_id)
	var result := GameState.buy_from_vendor(VendorIdsData.LOAM_AND_LANTERN, item_id)
	assert_bool(result["ok"]).is_true()
	assert_int(GameState.gp).is_equal(gp_before - int(result["price"]))
	assert_int(GameState.item_count(item_id)).is_equal(item_before + 1)
	assert_int(GameState.vendor_item_quantity(VendorIdsData.LOAM_AND_LANTERN, item_id)).is_equal(
		stock_before - 1
	)


func test_sell_moves_item_gp_and_vendor_stock_atomically() -> void:
	var item_id := ItemIds.CONSUMABLES_LOAM_BREAD
	var gp_before := GameState.gp
	var item_before := GameState.item_count(item_id)
	var stock_before := GameState.vendor_item_quantity(VendorIdsData.LOAM_AND_LANTERN, item_id)
	var result := GameState.sell_to_vendor(VendorIdsData.LOAM_AND_LANTERN, item_id)
	assert_bool(result["ok"]).is_true()
	assert_int(GameState.gp).is_equal(gp_before + int(result["price"]))
	assert_int(GameState.item_count(item_id)).is_equal(item_before - 1)
	assert_int(GameState.vendor_item_quantity(VendorIdsData.LOAM_AND_LANTERN, item_id)).is_equal(
		stock_before + 1
	)


func test_insufficient_gp_never_goes_negative_or_moves_stock() -> void:
	var item_id := ItemIds.MATERIALS_CINDER_INK_VIAL
	var price := VendorData.price_for(VendorIdsData.LOAM_AND_LANTERN, item_id, true)
	GameState.gp = price - 1
	var item_before := GameState.item_count(item_id)
	var stock_before := GameState.vendor_item_quantity(VendorIdsData.LOAM_AND_LANTERN, item_id)
	var result := GameState.buy_from_vendor(VendorIdsData.LOAM_AND_LANTERN, item_id)
	assert_bool(result["ok"]).is_false()
	assert_str(result["reason"]).is_equal("insufficient_gp")
	assert_int(GameState.gp).is_equal(price - 1)
	assert_int(GameState.gp).is_greater(-1)
	assert_int(GameState.item_count(item_id)).is_equal(item_before)
	assert_int(GameState.vendor_item_quantity(VendorIdsData.LOAM_AND_LANTERN, item_id)).is_equal(
		stock_before
	)


func test_vendor_sale_into_full_grid_fails_without_spending_or_losing_stock() -> void:
	GameState.inventory.clear()
	var grid := GridConstraint.new()
	grid.size = Vector2i(1, 1)
	GameState.inventory.add_child(grid)
	assert_object(
		GameState.inventory.create_and_add_item(ItemIds.CONSUMABLES_LOAM_BREAD)
	).is_not_null()
	var item_id := ItemIds.MATERIALS_CINDER_INK_VIAL
	var gp_before := GameState.gp
	var stock_before := GameState.vendor_item_quantity(VendorIdsData.LOAM_AND_LANTERN, item_id)
	var result := GameState.buy_from_vendor(VendorIdsData.LOAM_AND_LANTERN, item_id)
	assert_bool(result["ok"]).is_false()
	assert_str(result["reason"]).is_equal("inventory_full")
	assert_int(GameState.gp).is_equal(gp_before)
	assert_int(GameState.item_count(item_id)).is_equal(0)
	assert_int(GameState.vendor_item_quantity(VendorIdsData.LOAM_AND_LANTERN, item_id)).is_equal(
		stock_before
	)
	GameState.inventory.remove_child(grid)
	grid.free()


func test_band_gated_shrine_refuses_then_accepts_after_standing_changes() -> void:
	var vendor_id := VendorIdsData.HELD_FLAME_SHRINE
	var item_id := ItemIds.RELICS_VOTIVE_CINDER
	var refused := GameState.buy_from_vendor(vendor_id, item_id)
	assert_bool(refused["ok"]).is_false()
	assert_bool(refused["allowed"]).is_false()
	assert_str(refused["reason"]).is_equal("trade_refused")
	assert_str(refused["blocked_by"]).is_equal("reputation_band")
	assert_str(refused["nearest_unblock"]["type"]).is_equal("reputation_band")
	assert_str(refused["nearest_unblock"]["faction_id"]).is_equal(
		FactionIds.IRONBRAND_SENTINELS
	)
	assert_str(refused["nearest_unblock"]["current"]).is_equal("neutral")
	assert_str(refused["nearest_unblock"]["minimum"]).is_equal("warm")
	assert_int(refused["nearest_unblock"]["delta"]).is_equal(1)
	Reputation.record(
		"vex", FactionIds.IRONBRAND_SENTINELS, Reputation.BAND_WARM,
		"Honored the Sentinel watch", "test"
	)
	assert_str(Reputation.band(FactionIds.IRONBRAND_SENTINELS)).is_equal("warm")
	var accepted := GameState.buy_from_vendor(vendor_id, item_id)
	assert_bool(accepted["ok"]).is_true()
	assert_bool(accepted["allowed"]).is_true()
	assert_str(accepted["blocked_by"]).is_empty()
	assert_dict(accepted["nearest_unblock"]).is_empty()


func test_low_standing_fence_closes_when_company_standing_recovers() -> void:
	Reputation.record("vex", FactionIds.IRON_COMPANIES, -20.0, "Broke company trust", "test")
	var open_status := VendorData.trade_status(VendorIdsData.UNDERSTEP_EXCHANGE)
	assert_bool(open_status["allowed"]).is_true()
	assert_bool(open_status["open"]).is_true()
	Reputation.record("vex", FactionIds.IRON_COMPANIES, 20.0, "Repaid the company debt", "test")
	assert_str(Reputation.band(FactionIds.IRON_COMPANIES)).is_equal("neutral")
	var closed_status := VendorData.trade_status(VendorIdsData.UNDERSTEP_EXCHANGE)
	assert_bool(closed_status["allowed"]).is_false()
	assert_bool(closed_status["open"]).is_false()
	assert_str(closed_status["blocked_by"]).is_equal("reputation_band")
	assert_str(closed_status["nearest_unblock"]["maximum"]).is_equal("cold")
	assert_int(closed_status["nearest_unblock"]["delta"]).is_equal(1)


func test_gp_inventory_and_vendor_stock_round_trip_through_save_envelope() -> void:
	var saves = auto_free(SaveGameScript.new())
	var item_id := ItemIds.CONSUMABLES_LOAM_BREAD
	var result := GameState.buy_from_vendor(VendorIdsData.LOAM_AND_LANTERN, item_id)
	assert_bool(result["ok"]).is_true()
	var expected_gp := GameState.gp
	var expected_items := GameState.item_count(item_id)
	var expected_stock := GameState.vendor_item_quantity(VendorIdsData.LOAM_AND_LANTERN, item_id)
	var payload := {
		"version": SaveGameScript.FORMAT_VERSION,
		"schema_version": SaveGameScript.SCHEMA_VERSION,
		"id_schemas": StableIds.schema_manifest(),
		"scene": GameFlow.TOWN_SCENE,
		"game_state": GameState.to_dict(),
		"reputation": Reputation.to_dict(),
		"renown": {},
		"quests": {},
	}

	GameState.gp = 0
	GameState.inventory.clear()
	GameState.vendor_stock.clear()
	var prepared: Dictionary = saves._prepare_for_load(payload)
	assert_bool(prepared["ok"]).is_true()
	assert_bool(GameState.from_dict(prepared["payload"]["game_state"])).is_true()
	assert_int(GameState.gp).is_equal(expected_gp)
	assert_int(GameState.item_count(item_id)).is_equal(expected_items)
	assert_int(GameState.vendor_item_quantity(VendorIdsData.LOAM_AND_LANTERN, item_id)).is_equal(
		expected_stock
	)


func test_restock_policy_restores_authored_quantity_and_persists_cycle() -> void:
	var vendor_id := VendorIdsData.LOAM_AND_LANTERN
	var item_id := ItemIds.CONSUMABLES_LOAM_BREAD
	var base_quantity := GameState.vendor_item_quantity(vendor_id, item_id)
	assert_bool(GameState.buy_from_vendor(vendor_id, item_id)["ok"]).is_true()
	assert_int(GameState.vendor_item_quantity(vendor_id, item_id)).is_equal(base_quantity - 1)
	assert_bool(GameState.restock_vendor(vendor_id, 1)).is_true()
	assert_int(GameState.vendor_item_quantity(vendor_id, item_id)).is_equal(base_quantity)
	assert_int(GameState.vendor_restock_cycles[vendor_id]).is_equal(1)
	assert_bool(GameState.restock_vendor(vendor_id, 1)).is_false()


func _stock_contains(stock: Array[Dictionary], item_id: String) -> bool:
	for row: Dictionary in stock:
		if str(row.get("id", "")) == item_id:
			return true
	return false
