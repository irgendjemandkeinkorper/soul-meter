class_name ShopScreen
extends Screen
## Responsive storefront catalog for Dom's first-area shops.
## GP is a placeholder ledger for the first purchase flow. Each button buys one
## unit, immediately updates the carry count, and leaves the player in the shop.

const ITEM_STOCK := [
	{
		"id": ItemIds.CONSUMABLES_LOAM_BREAD,
		"name": "Loam Bread",
		"description": "Dense compost-city fare from Loamgate. Restores a little vigor.",
		"use": "field food / consumable",
		"price": 8,
	},
	{
		"id": ItemIds.MATERIALS_CINDER_INK_VIAL,
		"name": "Cinder-Ink Vial",
		"description": "Ash-bound tattoo ink; names written in it resist the Waning's slow erasure.",
		"use": "ritual material / writing",
		"price": 24,
	},
	{
		"id": ItemIds.TOOLS_SOUL_GAUGE,
		"name": "Soul Gauge",
		"description": "A brass-and-glass dial that reads a soul's integrity — and what magic has spent.",
		"use": "field tool / soul reading",
		"price": 60,
	},
]

const EQUIPMENT_STOCK := [
	{
		"id": ItemIds.WEAPONS_TAUBSTUMMER_AXE,
		"name": "Taubstummer Axe",
		"description": "A sealed soul-weapon of the Last Great War; its edge remembers what it unmade.",
		"use": "main-hand weapon",
		"price": 90,
	},
	{
		"id": ItemIds.TOOLS_SOUL_GAUGE,
		"name": "Soul Gauge",
		"description": "A brass-and-glass dial that reads a soul's integrity — and what magic has spent.",
		"use": "field tool / soul reading",
		"price": 60,
	},
	{
		"id": ItemIds.RELICS_CAPTURED_REFLECTION,
		"name": "Captured Reflection",
		"description": "An obsidian shard that shows a room lit by a sky that does not exist.",
		"use": "relic / unknown function",
		"price": 70,
	},
]

var _shop_type := "items"
var _catalog: VBoxContainer
var _gp_label: Label
var _status_label: Label


func _build() -> void:
	var vbox := _make_window("Shop", Vector2(760, 560))
	var header := HBoxContainer.new()
	header.add_theme_constant_override("separation", DS.SPACE_5)
	vbox.add_child(header)
	var header_note := Label.new()
	header_note.text = "PLACEHOLDER LEDGER"
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


func configure_shop(shop_type: String) -> void:
	_shop_type = shop_type if shop_type in ["items", "equipment"] else "items"
	if _catalog != null:
		_render_catalog()


func _render_catalog() -> void:
	if _catalog == null:
		return
	for child in _catalog.get_children():
		_catalog.remove_child(child)
		child.queue_free()

	var is_equipment := _shop_type == "equipment"
	var shop_name := "IRON & THREAD" if is_equipment else "LOAM & LANTERN"
	var subtitle := (
		"Equipment, fittings, and field tools for a soul-bound party."
		if is_equipment
		else "Provisions, ritual supplies, and practical goods for the road."
	)
	_catalog.add_child(_section(shop_name))
	var intro := Label.new()
	intro.text = subtitle
	intro.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	_catalog.add_child(intro)
	var note := Label.new()
	note.text = "ONE UNIT PER PURCHASE  ·  GP is a temporary currency for this menu pass"
	note.theme_type_variation = "MutedLabel"
	note.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	_catalog.add_child(note)
	_catalog.add_child(HSeparator.new())

	var stock: Array = EQUIPMENT_STOCK if is_equipment else ITEM_STOCK
	for entry in stock:
		_add_stock_entry(entry)


func _add_stock_entry(entry: Dictionary) -> void:
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
	var price := int(entry["price"])
	var buy := _menu_button(top, "BUY  ·  %d GP" % price, _buy.bind(entry))
	buy.custom_minimum_size = Vector2(170, DS.CONTROL_H)
	buy.disabled = not GameState.can_afford(price)
	var meta := Label.new()
	meta.text = "%s  ·  CARRY %d  ·  %d GP" % [
		str(entry["use"]).to_upper(),
		GameState.item_count(str(entry["id"])),
		price,
	]
	meta.theme_type_variation = "MutedLabel"
	row.add_child(meta)
	var description := Label.new()
	description.text = str(entry["description"])
	description.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	row.add_child(description)
	_catalog.add_child(row)


func _buy(entry: Dictionary) -> void:
	var price := int(entry["price"])
	if not GameState.can_afford(price):
		_status_label.text = "INSUFFICIENT GP  ·  NEED %d  ·  HAVE %d" % [price, GameState.gp]
		_render_catalog()
		return
	var item: InventoryItem = GameState.inventory.create_and_add_item(str(entry["id"]))
	if item == null:
		_status_label.text = "PURCHASE FAILED  ·  THE INVENTORY CANNOT HOLD THIS ITEM"
		return
	if not GameState.spend_gp(price):
		GameState.remove_items(str(entry["id"]), 1)
		_status_label.text = "PURCHASE FAILED  ·  GP LEDGER UNCHANGED"
		return
	_status_label.text = "PURCHASED  ·  %s  ·  -%d GP" % [str(entry["name"]).to_upper(), price]
	_render_catalog()


func _update_gp_label(value: int) -> void:
	if _gp_label != null:
		_gp_label.text = "GP  %03d" % value
