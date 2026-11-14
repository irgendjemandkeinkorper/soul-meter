extends GdUnitTestSuite
## P1.3: the visible shop quote and the real ledger must agree as Sway changes.

const ShopScene := preload("res://ui/screens/shop.tscn")
const Fixture := preload("res://test/fixtures/barter_shop_fixture.gd")

var _fixture: Fixture
var _shop: ShopScreen


func before_test() -> void:
	_fixture = Fixture.new()
	_fixture.set_up()


func after_test() -> void:
	if is_instance_valid(_shop):
		_shop.free()
	_fixture.restore()


func test_visible_basket_prices_equal_gp_deltas_at_zero_mid_and_max_sway() -> void:
	await _open_shop()
	for sway: float in [0.0, 50.0, SkillCheck.MAX_EFFECTIVE_PERCENT]:
		assert_bool(_fixture.advance_to(sway)).is_true()
		assert_str(Fixture.readout(_shop).text).contains("SWAY %d%%" % int(sway))
		var total_buy := 0
		var total_sell := 0
		var gp_before := GameState.gp
		for row: Dictionary in _shop.catalog_entries():
			var item_id := str(row["id"])
			assert_array(Fixture.BASKET).contains([item_id])
			_assert_base_prices(row)
			var buy := Fixture.trade_button(_shop, item_id, true)
			assert_bool(buy.disabled).is_false()
			var displayed_buy := Fixture.displayed_price(buy)
			assert_int(displayed_buy).is_equal(int(row["buy_price"]))
			var before := GameState.gp
			buy.pressed.emit()
			assert_int(before - GameState.gp).is_equal(displayed_buy)
			assert_int(GameState.item_count(item_id)).is_equal(1)
			total_buy += displayed_buy
			var sell := Fixture.trade_button(_shop, item_id, false)
			assert_bool(sell.disabled).is_false()
			var displayed_sell := Fixture.displayed_price(sell)
			assert_int(displayed_sell).is_equal(int(row["sell_price"]))
			before = GameState.gp
			sell.pressed.emit()
			assert_int(GameState.gp - before).is_equal(displayed_sell)
			assert_int(GameState.item_count(item_id)).is_equal(0)
			total_sell += displayed_sell
		assert_int(_shop.catalog_entries().size()).is_equal(Fixture.BASKET.size())
		assert_int(gp_before - GameState.gp).is_equal(total_buy - total_sell)


func test_replacing_the_leader_updates_the_name_sway_and_prices_while_open() -> void:
	assert_bool(_fixture.advance_to(50.0)).is_true()
	await _open_shop()
	var before := Fixture.readout(_shop).text
	var previous_price := Fixture.displayed_price(Fixture.trade_button(_shop, Fixture.BASKET[0], true))
	var replacement := PartyMember.new()
	replacement.id = GameState.PROTAGONIST_ID
	replacement.display_name = "New Leader"
	GameState.set_party([replacement])
	assert_str(Fixture.readout(_shop).text).is_not_equal(before)
	assert_str(Fixture.readout(_shop).text).contains("New Leader").contains("SWAY 0%")
	assert_int(Fixture.displayed_price(Fixture.trade_button(_shop, Fixture.BASKET[0], true))).is_greater(previous_price)
	assert_bool(_fixture.leader.changed.is_connected(_shop._render_catalog)).is_false()


func test_a_leaving_shop_does_not_rebuild_on_a_party_change() -> void:
	assert_bool(_fixture.advance_to(50.0)).is_true()
	await _open_shop()
	var readout := Fixture.readout(_shop).text
	var first_row := _shop._catalog.get_child(0)
	var row_count := _shop._catalog.get_child_count()
	_shop.play_exit()
	var replacement := PartyMember.new()
	replacement.id = GameState.PROTAGONIST_ID
	replacement.display_name = "New Leader"
	GameState.set_party([replacement])
	# The fade-out keeps what it shows: same readout, same rows, none detached.
	assert_str(Fixture.readout(_shop).text).is_equal(readout)
	assert_int(_shop._catalog.get_child_count()).is_equal(row_count)
	assert_object(_shop._catalog.get_child(0)).is_same(first_row)
	assert_bool(first_row.is_inside_tree()).is_true()


func test_party_reordering_names_the_same_subject_that_sets_the_price() -> void:
	assert_bool(_fixture.advance_to(50.0)).is_true()
	await _open_shop()
	var before := Fixture.readout(_shop).text
	var companion := PartyMember.new()
	companion.id = "test-companion"
	companion.display_name = "Companion"
	companion.attributes["decorum"] = 10
	GameState.set_party([companion, _fixture.leader])
	assert_str(Fixture.readout(_shop).text).is_equal(before)
	assert_str(Fixture.readout(_shop).text).contains("Vex")


func test_zero_sway_and_no_leader_explain_the_unchanged_ratio() -> void:
	await _open_shop()
	assert_str(Fixture.readout(_shop).text).contains("SWAY 0%").contains("BUY ×1.00 / SELL ×1.00")
	var hint := _shop.find_child("BarterHint", true, false) as Label
	assert_bool(hint.visible).is_true()
	assert_str(hint.text).is_equal("NO BARTER ADJUSTMENT")
	GameState.set_party([])
	assert_str(Fixture.readout(_shop).text).contains("NO LEADER").contains("SWAY 0%")
	assert_bool(hint.visible).is_true()
	for row: Dictionary in _shop.catalog_entries():
		_assert_base_prices(row)


func test_advancement_and_mirror_rewriting_refresh_the_open_shop() -> void:
	await _open_shop()
	var before := Fixture.readout(_shop).text
	assert_bool(_fixture.advance_to(50.0)).is_true()
	assert_str(Fixture.readout(_shop).text).is_not_equal(before)
	assert_str(Fixture.readout(_shop).text).contains("SWAY 50%")
	assert_bool((_shop.find_child("BarterHint", true, false) as Label).visible).is_false()
	assert_bool(GameState.use_mirror_rewriting(_fixture.leader)["allowed"]).is_true()
	assert_str(Fixture.readout(_shop).text).is_equal(before)
	for row: Dictionary in _shop.catalog_entries():
		_assert_base_prices(row)


func test_karma_changes_refresh_effective_sway_and_the_actual_price() -> void:
	assert_bool(_fixture.advance_to(50.0)).is_true()
	await _open_shop()
	var before := Fixture.readout(_shop).text
	Renown.gain_karma("vex", 900.0, "Barter fixture", "test")
	assert_str(Fixture.readout(_shop).text).is_not_equal(before)
	assert_str(Fixture.readout(_shop).text).contains("SWAY 53%")
	var buy := Fixture.trade_button(_shop, Fixture.BASKET[0], true)
	var displayed := Fixture.displayed_price(buy)
	var gp_before := GameState.gp
	buy.pressed.emit()
	assert_int(gp_before - GameState.gp).is_equal(displayed)


func test_base_prices_keep_the_live_reputation_band() -> void:
	assert_bool(_fixture.advance_to(50.0)).is_true()
	await _open_shop()
	var previous := Fixture.displayed_price(Fixture.trade_button(_shop, Fixture.BASKET[0], true))
	Reputation.record("vex", FactionIds.IRON_COMPANIES, 15.0, "Barter fixture", "test")
	assert_int(Fixture.displayed_price(Fixture.trade_button(_shop, Fixture.BASKET[0], true))).is_less(previous)
	for row: Dictionary in _shop.catalog_entries():
		assert_int(int(row["base_buy_price"])).is_equal(VendorRegistry.price_for(Fixture.VENDOR_ID, str(row["id"]), true, &"warm"))
		assert_int(int(row["base_sell_price"])).is_equal(VendorRegistry.price_for(Fixture.VENDOR_ID, str(row["id"]), false, &"warm"))
		_assert_base_prices(row)


func test_a_refused_purchase_keeps_the_existing_reason_and_ledger() -> void:
	await _open_shop()
	var item_id := Fixture.BASKET[0]
	var buy := Fixture.trade_button(_shop, item_id, true)
	var stock_before := GameState.vendor_item_quantity(Fixture.VENDOR_ID, item_id)
	GameState.set_gp(0)
	buy.pressed.emit()
	assert_str((_shop.get("_status_label") as Label).text).contains("INSUFFICIENT_GP").contains("NEED")
	assert_int(GameState.gp).is_equal(0)
	assert_int(GameState.item_count(item_id)).is_equal(0)
	assert_int(GameState.vendor_item_quantity(Fixture.VENDOR_ID, item_id)).is_equal(stock_before)


func _open_shop() -> void:
	_shop = ShopScene.instantiate() as ShopScreen
	add_child(_shop)
	_shop.configure_vendor(Fixture.VENDOR_ID)
	for _frame: int in 3:
		await get_tree().process_frame


func _assert_base_prices(row: Dictionary) -> void:
	var base := _shop.find_child("BasePrice_" + str(row["id"]).replace("/", "_"), true, false) as Label
	var buy_changed := int(row["buy_price"]) != int(row["base_buy_price"])
	var sell_changed := int(row["sell_price"]) != int(row["base_sell_price"])
	if not buy_changed and not sell_changed:
		assert_object(base).is_null()
		return
	assert_object(base).is_not_null()
	if base == null:
		return
	assert_str(base.theme_type_variation).is_equal("MutedLabel")
	if buy_changed:
		assert_str(base.text).contains("BASE BUY  ·  %d SILVER" % int(row["base_buy_price"]))
	if sell_changed:
		assert_str(base.text).contains("BASE SELL  ·  %d SILVER" % int(row["base_sell_price"]))
