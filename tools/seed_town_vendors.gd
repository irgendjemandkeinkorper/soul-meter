extends Node
## Idempotent Pandora migration for Dom's authored vendor economy.
##
## The NPC roster is owned by the parallel town-roster task. These records use
## stable, provisional NPC ids and deliberately do not create NPC entities,
## personalities, or dialogue.

const VENDOR_PROPERTIES := [
	["Vendor Id", "string"],
	["Display Name", "string"],
	["NPC Id", "string"],
	["Site Id", "string"],
	["Site Name", "string"],
	["Faction Id", "string"],
	["Trade Mode", "string"],
	["Buy Modifier", "float"],
	["Sell Modifier", "float"],
	["Minimum Band", "string"],
	["Maximum Band", "string"],
	["Band Price Modifiers", "string"],
	["Inventory", "string"],
	["Restock", "string"],
	["Band Reactions", "string"],
]

const EXISTING_ITEM_PRICES := {
	"Taubstummer Axe": 90,
	"Captured Reflection": 70,
	"Soul Gauge": 60,
	"Loam Bread": 8,
	"Cinder-Ink Vial": 24,
	"QUINE Shard": 120,
	"Loamroot Sprig": 6,
}


func _ready() -> void:
	await get_tree().process_frame
	if not Pandora.is_loaded():
		Pandora.load_data()

	var items := _root_by_name("Items")
	if items == null:
		push_error("VENDOR-SEED: no Items root — run tools/seed_pandora.gd first.")
		get_tree().quit(1)
		return
	_ensure_property(items, "Base Price", "int")
	_seed_items(items)

	var vendors := _ensure_root("Vendors", VENDOR_PROPERTIES)
	_seed_vendors(vendors)
	Pandora.save_data()
	print("VENDOR-SEED: 12 Dom vendors and economy items present.")
	get_tree().quit()


func _seed_items(items_root: PandoraCategory) -> void:
	for entity: PandoraEntity in Pandora.get_all_entities(items_root):
		if entity is PandoraCategory:
			continue
		if EXISTING_ITEM_PRICES.has(entity.get_entity_name()):
			_assign(entity, "Base Price", EXISTING_ITEM_PRICES[entity.get_entity_name()])

	var categories := {}
	for category_name in ["Consumables", "Materials", "Relics", "Tools", "Weapons"]:
		categories[category_name] = _category_by_name(category_name)
		assert(categories[category_name] != null, "Missing Items/%s category" % category_name)

	for row: Dictionary in _item_rows():
		var category: PandoraCategory = categories[row["category"]]
		_upsert(category, row["name"], row["values"])


func _item_rows() -> Array[Dictionary]:
	return [
		_item(
			"Consumables", "Bitterleaf Poultice", 14,
			"A sharp-smelling leaf pack used to bind small field wounds.",
			"Bitter first. Better second.", 5, 0.2, Vector2i(1, 1), "common"
		),
		_item(
			"Consumables", "Loam-Smoked Eel", 10,
			"River eel cured over damp loamwood for a long road ration.",
			"Smoke, salt, and a trace of the city beneath the city.", 5, 0.4,
			Vector2i(1, 1), "common"
		),
		_item(
			"Consumables", "Salted Riverfish", 7,
			"A small riverfish packed in coarse salt and market paper.",
			"The Four Arms feed more people than the roads do.", 10, 0.3,
			Vector2i(1, 1), "common"
		),
		_item(
			"Consumables", "Hearthloaf", 5,
			"A soft brown loaf baked for the same-day market.",
			"Best before the bells finish arguing with one another.", 10, 0.4,
			Vector2i(1, 1), "common"
		),
		_item(
			"Materials", "Scribe's Vellum", 9,
			"A trimmed vellum folio sized for contracts and field notes.",
			"Margins cost extra. Consequences do not.", 10, 0.1,
			Vector2i(1, 1), "common"
		),
		_item(
			"Materials", "Binding Thread", 6,
			"Waxed thread for repairs, bindings, and light field stitching.",
			"Strong enough to hold leather; not promises.", 10, 0.1,
			Vector2i(1, 1), "common"
		),
		_item(
			"Materials", "Iron Rivets", 11,
			"A counted packet of uniform rivets from Dom's company forges.",
			"Every head bears four shallow strikes.", 10, 0.5,
			Vector2i(1, 1), "common"
		),
		_item(
			"Materials", "Grave Salt", 18,
			"Dark mineral salt used to preserve herbs and mark uneasy thresholds.",
			"It clumps near the recently dead.", 5, 0.2, Vector2i(1, 1), "uncommon"
		),
		_item(
			"Materials", "Lamp Oil", 7,
			"A stoppered flask of clean-burning oil for road lanterns.",
			"The bottle promises six hours. Wind negotiates.", 10, 0.5,
			Vector2i(1, 1), "common"
		),
		_item(
			"Relics", "Votive Cinder", 12,
			"A shrine cinder sealed in wax after an offering is witnessed.",
			"Not bought. Not quite given.", 10, 0.1, Vector2i(1, 1), "uncommon"
		),
		_item(
			"Tools", "Lockpick Roll", 22,
			"A compact roll of picks, shims, and a narrow tension bar.",
			"Sold for lawful doors, naturally.", 1, 0.4, Vector2i(1, 2), "uncommon"
		),
		_item(
			"Tools", "Surveyor's Chalk", 9,
			"Weather-resistant chalk for route marks and measured circles.",
			"A line is only useful if someone agrees where it begins.", 5, 0.2,
			Vector2i(1, 1), "common"
		),
		_item(
			"Tools", "Field Needle", 13,
			"A heavy repair needle kept in a fitted wooden case.",
			"For canvas, hide, and emergencies no one describes at supper.", 1, 0.1,
			Vector2i(1, 1), "common"
		),
		_item(
			"Weapons", "Roadwarden Spear", 55,
			"A practical ash-shaft spear with an Iron Company pattern head.",
			"Long enough to make a roadside disagreement reconsider.", 1, 3.0,
			Vector2i(1, 3), "common", "main_hand"
		),
		_item(
			"Weapons", "Forge Hammer", 42,
			"A balanced smith's hammer heavy enough for desperate field use.",
			"A tool until the moment it is not.", 1, 2.5, Vector2i(2, 2), "common",
			"main_hand"
		),
	]


func _item(
	category: String,
	item_name: String,
	base_price: int,
	description: String,
	flavour: String,
	max_stack_size: int,
	weight: float,
	grid_size: Vector2i,
	rarity: String,
	equip_slot: String = ""
) -> Dictionary:
	return {
		"category": category,
		"name": item_name,
		"values": {
			"Display Name": item_name,
			"Description": description,
			"Base Price": base_price,
			"Max Stack Size": max_stack_size,
			"Weight": weight,
			"Grid Size": grid_size,
			"Equip Slot": equip_slot,
			"Rarity": rarity,
			"Flavour": flavour,
		},
	}


func _seed_vendors(root: PandoraCategory) -> void:
	var standard_prices := {
		"hostile": {"buy": 1.35, "sell": 0.55},
		"cold": {"buy": 1.15, "sell": 0.75},
		"neutral": {"buy": 1.0, "sell": 1.0},
		"warm": {"buy": 0.9, "sell": 1.1},
		"allied": {"buy": 0.8, "sell": 1.2},
	}
	var fence_prices := {
		"hostile": {"buy": 0.85, "sell": 1.1},
		"cold": {"buy": 0.95, "sell": 1.0},
		"neutral": {"buy": 1.2, "sell": 0.7},
		"warm": {"buy": 1.3, "sell": 0.6},
		"allied": {"buy": 1.4, "sell": 0.5},
	}
	var rows: Array[Dictionary] = [
		_vendor(
			"loam-and-lantern", "Loam & Lantern", "dom-general-store-keeper",
			"dom/item-shop", "ItemShop building", "iron-companies", "commerce",
			1.0, 0.45, "cold", "", standard_prices,
			[
				_stock("consumables/loam_bread", 12),
				_stock("materials/cinder_ink_vial", 5),
				_stock("materials/lamp_oil", 8),
				_stock("tools/soul_gauge", 1, "warm"),
			],
			_restock("daily", 1),
			[_reaction("pricing", "Cold standing adds the company-risk markup.", "", "cold")]
		),
		_vendor(
			"iron-and-thread", "Iron & Thread", "dom-smith", "dom/equipment-shop",
			"EquipmentShop building", "iron-companies", "commerce", 1.05, 0.5,
			"neutral", "", standard_prices,
			[
				_stock("weapons/roadwarden_spear", 3),
				_stock("weapons/forge_hammer", 2),
				_stock("materials/iron_rivets", 8),
				_stock("weapons/taubstummer_axe", 1, "allied"),
			],
			_restock("weekly", 7),
			[
				_reaction("refusal", "Iron & Thread requires neutral company standing.", "", "cold"),
				_reaction("stock", "Allied standing opens the sealed-weapon case.", "allied", ""),
			]
		),
		_vendor(
			"root-and-reed", "Root & Reed", "dom-herbalist", "dom/east-market-herbs",
			"East Market herb stall", "iron-companies", "commerce", 0.95, 0.4,
			"cold", "", standard_prices,
			[
				_stock("consumables/bitterleaf_poultice", 8),
				_stock("materials/loamroot_sprig", 6),
				_stock("materials/grave_salt", 3, "warm"),
			],
			_restock("every_two_days", 2),
			[_reaction("stock", "Warm standing opens the grave-salt drawer.", "warm", "")]
		),
		_vendor(
			"four-arms-fish", "Four Arms Fish", "dom-fishmonger", "dom/south-market-fish",
			"South Market fish stall", "iron-companies", "commerce", 0.9, 0.35,
			"hostile", "", standard_prices,
			[
				_stock("consumables/salted_riverfish", 16),
				_stock("consumables/loam_smoked_eel", 8),
			],
			_restock("daily", 1), []
		),
		_vendor(
			"ashline-scriptorium", "Ashline Scriptorium", "dom-scribe",
			"dom/town-hall-scribe", "Town Hall arcade scribe stall", "iron-companies",
			"commerce", 1.0, 0.5, "neutral", "", standard_prices,
			[
				_stock("materials/scribes_vellum", 10),
				_stock("materials/cinder_ink_vial", 4, "warm"),
				_stock("tools/surveyors_chalk", 5),
			],
			_restock("every_three_days", 3),
			[_reaction("stock", "Warm standing releases reserved cinder-ink.", "warm", "")]
		),
		_vendor(
			"understep-exchange", "Understep Exchange", "dom-fence",
			"dom/understep-night-stall", "Understep Alley night stall", "iron-companies",
			"commerce", 1.1, 0.65, "hostile", "cold", fence_prices,
			[
				_stock("tools/lockpick_roll", 2),
				_stock("relics/captured_reflection", 1, "hostile", "hostile"),
				_stock("relics/quine_shard", 1, "hostile", "hostile"),
			],
			_restock("never", 0),
			[_reaction("refusal", "The Exchange closes once company standing reaches neutral.", "neutral", "")]
		),
		_vendor(
			"held-flame-shrine", "Shrine of the Held Flame", "dom-shrine-keeper",
			"dom/central-shrine", "Central shrine", "ironbrand-sentinels", "offering",
			1.0, 0.0, "warm", "", standard_prices,
			[
				_stock("relics/votive_cinder", 3, "warm"),
				_stock("relics/captured_reflection", 1, "allied"),
			],
			_restock("weekly", 7),
			[
				_reaction("opening", "The offering shelf opens at warm Sentinel standing.", "warm", ""),
				_reaction("stock", "Allied standing opens the witnessed-relic niche.", "allied", ""),
			]
		),
		_vendor(
			"hearthloaf-bakery", "Hearthloaf Bakery", "dom-baker",
			"dom/west-market-bakery", "West Market bakery stall", "iron-companies",
			"commerce", 0.85, 0.3, "hostile", "", standard_prices,
			[
				_stock("consumables/hearthloaf", 18),
				_stock("consumables/loam_bread", 8),
			],
			_restock("daily", 1), []
		),
		_vendor(
			"rivet-and-spur", "Rivet & Spur", "dom-armorer", "dom/garrison-armorer",
			"Garrison forecourt armorer stall", "iron-companies", "commerce", 1.0, 0.5,
			"neutral", "", standard_prices,
			[
				_stock("materials/iron_rivets", 12),
				_stock("weapons/roadwarden_spear", 2),
				_stock("weapons/forge_hammer", 1, "warm"),
			],
			_restock("weekly", 7),
			[_reaction("stock", "Warm standing opens the fitted-tool rack.", "warm", "")]
		),
		_vendor(
			"needle-and-hide", "Needle & Hide", "dom-clothier", "dom/market-row-clothier",
			"Market Row clothier stall", "iron-companies", "commerce", 0.95, 0.45,
			"cold", "", standard_prices,
			[
				_stock("materials/binding_thread", 12),
				_stock("tools/field_needle", 5),
				_stock("materials/cinder_ink_vial", 2, "warm"),
			],
			_restock("every_three_days", 3), []
		),
		_vendor(
			"quiet-gear", "Quiet Gear", "dom-tinker", "dom/south-market-tinker",
			"South Market tinker stall", "iron-companies", "commerce", 1.05, 0.5,
			"cold", "", standard_prices,
			[
				_stock("tools/field_needle", 3),
				_stock("tools/surveyors_chalk", 6),
				_stock("tools/soul_gauge", 1, "warm"),
				_stock("tools/lockpick_roll", 1, "cold", "cold"),
			],
			_restock("every_three_days", 3),
			[_reaction("stock", "Cold standing exposes an unregistered tool roll.", "cold", "cold")]
		),
		_vendor(
			"wayfarers-measure", "Wayfarer's Measure", "dom-provisioner",
			"dom/east-gate-provisioner", "East Gate provisioner stall", "iron-companies",
			"commerce", 1.0, 0.4, "neutral", "", standard_prices,
			[
				_stock("consumables/hearthloaf", 8),
				_stock("consumables/loam_smoked_eel", 5),
				_stock("materials/lamp_oil", 6),
				_stock("tools/surveyors_chalk", 4),
			],
			_restock("every_two_days", 2), []
		),
	]
	for row in rows:
		_upsert(root, row["entity_name"], row["values"])


func _vendor(
	vendor_id: String,
	display_name: String,
	npc_id: String,
	site_id: String,
	site_name: String,
	faction_id: String,
	trade_mode: String,
	buy_modifier: float,
	sell_modifier: float,
	minimum_band: String,
	maximum_band: String,
	band_prices: Dictionary,
	stock: Array,
	restock: Dictionary,
	reactions: Array
) -> Dictionary:
	return {
		"entity_name": display_name,
		"values": {
			"Vendor Id": vendor_id,
			"Display Name": display_name,
			"NPC Id": npc_id,
			"Site Id": site_id,
			"Site Name": site_name,
			"Faction Id": faction_id,
			"Trade Mode": trade_mode,
			"Buy Modifier": buy_modifier,
			"Sell Modifier": sell_modifier,
			"Minimum Band": minimum_band,
			"Maximum Band": maximum_band,
			"Band Price Modifiers": JSON.stringify(band_prices),
			"Inventory": JSON.stringify(stock),
			"Restock": JSON.stringify(restock),
			"Band Reactions": JSON.stringify(reactions),
		},
	}


func _stock(
	item_id: String,
	quantity: int,
	minimum_band: String = "",
	maximum_band: String = ""
) -> Dictionary:
	return {
		"item_id": item_id,
		"quantity": quantity,
		"minimum_band": minimum_band,
		"maximum_band": maximum_band,
	}


func _restock(mode: String, interval: int) -> Dictionary:
	return {"mode": mode, "interval": interval}


func _reaction(
	kind: String,
	message: String,
	minimum_band: String = "",
	maximum_band: String = ""
) -> Dictionary:
	return {
		"kind": kind,
		"message": message,
		"minimum_band": minimum_band,
		"maximum_band": maximum_band,
	}


func _ensure_root(name: String, properties: Array) -> PandoraCategory:
	var root := _root_by_name(name)
	if root == null:
		root = Pandora.create_category(name)
	for property_spec in properties:
		_ensure_property(root, property_spec[0], property_spec[1])
	return root


func _ensure_property(root: PandoraCategory, property_name: String, type_name: String) -> void:
	if not root.has_entity_property(property_name):
		Pandora.create_property(root, property_name, type_name)


func _root_by_name(name: String) -> PandoraCategory:
	for root: PandoraCategory in Pandora.get_all_roots():
		if root.get_entity_name() == name:
			return root
	return null


func _category_by_name(name: String) -> PandoraCategory:
	for category: PandoraCategory in Pandora.get_all_categories():
		if category.get_entity_name() == name:
			return category
	return null


func _upsert(root: PandoraCategory, entity_name: String, values: Dictionary) -> void:
	var entity: PandoraEntity = null
	for candidate: PandoraEntity in Pandora.get_all_entities(root):
		if not candidate is PandoraCategory and candidate.get_entity_name() == entity_name:
			entity = candidate
			break
	if entity == null:
		entity = Pandora.create_entity(entity_name, root)
	for property_name: String in values:
		_assign(entity, property_name, values[property_name])


func _assign(entity: PandoraEntity, property_name: String, value: Variant) -> void:
	var property := entity.get_entity_property(property_name)
	assert(property != null, "Missing Pandora property '%s' on %s" % [property_name, entity.get_entity_name()])
	property.set_default_value(value)
