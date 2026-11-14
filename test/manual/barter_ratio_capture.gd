extends GdUnitTestSuite
## P1.3 acceptance: one open shop, the same basket, Sway 0% then 95%.
## Run through scripts/test.sh with a display. PNGs: user://qa/barter-sway-{00,95}-1920.png.
## Headless runs exercise the same layout/accounting assertions without producing PNGs.

const ShopScene := preload("res://ui/screens/shop.tscn")
const Fixture := preload("res://test/fixtures/barter_shop_fixture.gd")

var _fixture: Fixture
var _viewport: SubViewport


func before_test() -> void:
	_fixture = Fixture.new()
	_fixture.set_up()


func after_test() -> void:
	if is_instance_valid(_viewport):
		_viewport.free()
	_fixture.restore()


func test_capture_live_barter_and_reconcile_the_same_basket() -> void:
	var capture_images := DisplayServer.get_name() != "headless"
	if not capture_images:
		print("BARTER-CAPTURE: headless accounting only; no PNGs rendered.")
	_viewport = SubViewport.new()
	_viewport.render_target_update_mode = SubViewport.UPDATE_ALWAYS
	_viewport.size = Vector2i(1920, 1080)
	add_child(_viewport)
	var shop := ShopScene.instantiate() as ShopScreen
	_viewport.add_child(shop)
	shop.configure_vendor(Fixture.VENDOR_ID)
	shop.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	var directory := ProjectSettings.globalize_path("user://qa")
	assert_int(DirAccess.make_dir_recursive_absolute(directory)).is_equal(OK)
	var readouts: Array[String] = []
	var buy_totals: Array[int] = []
	var sell_totals: Array[int] = []
	for sway: float in [0.0, SkillCheck.MAX_EFFECTIVE_PERCENT]:
		shop.configure_vendor(Fixture.VENDOR_ID)
		assert_bool(_fixture.advance_to(sway)).is_true()
		GameState.set_gp(5000)
		for _frame: int in 5:
			await get_tree().process_frame
		var readout := Fixture.readout(shop)
		assert_bool(readout.is_visible_in_tree()).is_true()
		assert_bool(shop.get_global_rect().encloses(readout.get_global_rect())).is_true()
		assert_str(readout.text).contains("SWAY %d%%" % int(sway))
		readouts.append(readout.text)
		var buy_total := 0
		var sell_total := 0
		var catalog_scroll := shop.find_child("CatalogScroll", true, false) as ScrollContainer
		var initial_stock: Dictionary = {}
		for item_id: String in Fixture.BASKET:
			var buy := Fixture.trade_button(shop, item_id, true)
			var sell := Fixture.trade_button(shop, item_id, false)
			assert_object(buy).is_not_null()
			assert_object(sell).is_not_null()
			assert_bool(catalog_scroll.get_global_rect().encloses(buy.get_global_rect())).is_true()
			assert_bool(catalog_scroll.get_global_rect().encloses(sell.get_global_rect())).is_true()
			buy_total += Fixture.displayed_price(buy)
			sell_total += Fixture.displayed_price(sell)
			initial_stock[item_id] = GameState.vendor_item_quantity(Fixture.VENDOR_ID, item_id)
		var path := "user://qa/barter-sway-%02d-1920.png" % int(sway)
		if capture_images:
			RenderingServer.force_draw()
			await RenderingServer.frame_post_draw
			assert_int(_viewport.get_texture().get_image().save_png(path)).is_equal(OK)
			print("BARTER-CAPTURE: saved %s" % ProjectSettings.globalize_path(path))
		var gp_before := GameState.gp
		for item_id: String in Fixture.BASKET:
			var buy := Fixture.trade_button(shop, item_id, true)
			var buy_price := Fixture.displayed_price(buy)
			var before := GameState.gp
			buy.pressed.emit()
			assert_int(before - GameState.gp).is_equal(buy_price)
			assert_int(GameState.item_count(item_id)).is_equal(1)
			var sell := Fixture.trade_button(shop, item_id, false)
			var sell_price := Fixture.displayed_price(sell)
			before = GameState.gp
			sell.pressed.emit()
			assert_int(GameState.gp - before).is_equal(sell_price)
			assert_int(GameState.item_count(item_id)).is_equal(0)
			assert_int(GameState.vendor_item_quantity(Fixture.VENDOR_ID, item_id)).is_equal(int(initial_stock[item_id]))
		assert_int(gp_before - GameState.gp).is_equal(buy_total - sell_total)
		buy_totals.append(buy_total)
		sell_totals.append(sell_total)
		print("BARTER-CAPTURE: sway=%d%% buy=%d sell=%d net=%d; %s" % [
			int(sway), buy_total, sell_total, gp_before - GameState.gp,
			readout.text,
		])
	assert_str(readouts[0]).is_not_equal(readouts[1])
	assert_int(buy_totals[1]).is_less(buy_totals[0])
	assert_int(sell_totals[1]).is_greater(sell_totals[0])
