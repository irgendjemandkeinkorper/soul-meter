class_name ShopScreen
extends Screen
## Pandora-backed storefront for Dom's vendor economy.

const VendorData := preload("res://globals/vendor_registry.gd")
const VendorIdsData := preload("res://data/generated/vendor_ids.gd")
const LEGACY_SHOPS := {
	"items": VendorIdsData.LOAM_AND_LANTERN,
	"equipment": VendorIdsData.IRON_AND_THREAD,
}

var _vendor_id := VendorIdsData.LOAM_AND_LANTERN
var _catalog: VBoxContainer
var _gp_label: Label
var _status_label: Label


func _build() -> void:
	var vbox := _make_window("Shop", Vector2(760, 560))
	var header := HBoxContainer.new()
	header.add_theme_constant_override("separation", DS.SPACE_5)
	vbox.add_child(header)
	var header_note := Label.new()
	header_note.text = "VENDOR LEDGER"
	header_note.theme_type_variation = "EyebrowLabel"
	header.add_child(header_note)
	var header_spacer := Control.new()
	header_spacer.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	header.add_child(header_spacer)
	_gp_label = Label.new()
	_gp_label.theme_type_variation = "StatLabel"
	header.add_child(_gp_label)
	_update_gp_label(GameState.gp)
	GameState.gp_changed.connect(_update_gp_label)

	_status_label = Label.new()
	_status_label.theme_type_variation = "MutedLabel"
	_status_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	vbox.add_child(_status_label)

	_catalog = VBoxContainer.new()
	_catalog.add_theme_constant_override("separation", 12)
	_catalog.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	vbox.add_child(_catalog)
	_add_back_button(vbox)
	_render_catalog()


## Keeps the two existing starting-town doors compatible without hardcoded stock.
func configure_shop(shop_type: String) -> void:
	if LEGACY_SHOPS.has(shop_type):
		_vendor_id = LEGACY_SHOPS[shop_type]
	elif not VendorData.vendor(shop_type).is_empty():
		_vendor_id = shop_type
	else:
		_vendor_id = VendorIdsData.LOAM_AND_LANTERN
	if _catalog != null:
		_render_catalog()


func configure_vendor(vendor_id: String) -> void:
	configure_shop(vendor_id)


func vendor_id() -> String:
	return _vendor_id


func catalog_entries() -> Array[Dictionary]:
	return GameState.available_vendor_stock(_vendor_id)


func _render_catalog() -> void:
	if _catalog == null:
		return
	for child in _catalog.get_children():
		_catalog.remove_child(child)
		child.queue_free()

	var vendor := VendorData.vendor(_vendor_id)
	if vendor.is_empty():
		_catalog.add_child(_section("VENDOR UNAVAILABLE"))
		return
	var band := VendorData.current_band(_vendor_id)
	var status := GameState.vendor_trade_status(_vendor_id)
	_catalog.add_child(_section(str(vendor["display_name"]).to_upper()))
	var intro := Label.new()
	intro.text = "%s  ·  %s STANDING" % [str(vendor["site_name"]), String(band).to_upper()]
	intro.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	_catalog.add_child(intro)
	var restock: Dictionary = vendor.get("restock", {})
	var note := Label.new()
	note.text = "%s  ·  RESTOCK %s" % [
		"OFFERINGS" if str(vendor.get("trade_mode", "")) == "offering" else "BUY / SELL",
		str(restock.get("mode", "unknown")).replace("_", " ").to_upper(),
	]
	note.theme_type_variation = "MutedLabel"
	note.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	_catalog.add_child(note)
	_catalog.add_child(HSeparator.new())

	if not bool(status.get("allowed", false)):
		var refusal := Label.new()
		refusal.text = str(status.get("reason", "TRADE UNAVAILABLE"))
		refusal.theme_type_variation = "MutedLabel"
		refusal.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
		_catalog.add_child(refusal)
		return

	var stock := catalog_entries()
	if stock.is_empty():
		var empty := Label.new()
		empty.text = "NO STOCK IS AVAILABLE AT THIS STANDING."
		empty.theme_type_variation = "MutedLabel"
		_catalog.add_child(empty)
		return
	for entry: Dictionary in stock:
		_add_stock_entry(entry, str(vendor.get("trade_mode", "commerce")))


func _add_stock_entry(entry: Dictionary, trade_mode: String) -> void:
	var row := VBoxContainer.new()
	row.add_theme_constant_override("separation", 3)
	row.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	var top := HBoxContainer.new()
	top.add_theme_constant_override("separation", DS.SPACE_4)
	row.add_child(top)
	var title := Label.new()
	title.text = str(entry["name"])
	title.theme_type_variation = "HeadingLabel"
	title.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	top.add_child(title)

	var item_id := str(entry["id"])
	var quantity := int(entry["quantity"])
	var buy_price := int(entry["buy_price"])
	var buy_verb := "OFFER" if trade_mode == "offering" else "BUY"
	var buy := _menu_button(top, "%s  ·  %d GP" % [buy_verb, buy_price], _buy.bind(entry))
	buy.custom_minimum_size = Vector2(155, DS.CONTROL_H)
	buy.disabled = quantity <= 0 or not GameState.can_afford(buy_price)

	var sell_price := int(entry["sell_price"])
	if trade_mode == "commerce" and VendorData.accepts_sales(_vendor_id, item_id):
		var sell := _menu_button(top, "SELL  ·  %d GP" % sell_price, _sell.bind(entry))
		sell.custom_minimum_size = Vector2(155, DS.CONTROL_H)
		sell.disabled = GameState.item_count(item_id) <= 0

	var use_label := str(entry.get("equip_slot", entry.get("rarity", "item"))).replace("_", " ")
	var meta := Label.new()
	meta.text = "%s  ·  STOCK %d  ·  CARRY %d" % [
		use_label.to_upper(),
		quantity,
		GameState.item_count(item_id),
	]
	meta.theme_type_variation = "MutedLabel"
	row.add_child(meta)
	var description := Label.new()
	description.text = str(entry["description"])
	description.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	row.add_child(description)
	_catalog.add_child(row)


func _buy(entry: Dictionary) -> void:
	var result := GameState.buy_from_vendor(_vendor_id, str(entry["id"]))
	if not bool(result.get("ok", false)):
		_status_label.text = _failure_text(result)
		_render_catalog()
		return
	_status_label.text = "PURCHASED  ·  %s  ·  -%d GP" % [
		str(entry["name"]).to_upper(), int(result["price"])
	]
	_render_catalog()


func _sell(entry: Dictionary) -> void:
	var result := GameState.sell_to_vendor(_vendor_id, str(entry["id"]))
	if not bool(result.get("ok", false)):
		_status_label.text = _failure_text(result)
		_render_catalog()
		return
	_status_label.text = "SOLD  ·  %s  ·  +%d GP" % [
		str(entry["name"]).to_upper(), int(result["price"])
	]
	_render_catalog()


func _failure_text(result: Dictionary) -> String:
	var message := str(result.get("message", ""))
	if not message.is_empty():
		return "%s  ·  %s" % [str(result.get("reason", "FAILED")).to_upper(), message]
	return str(result.get("reason", "TRANSACTION FAILED")).replace("_", " ").to_upper()


func _update_gp_label(value: int) -> void:
	if _gp_label != null:
		_gp_label.text = "GP  %03d" % value
