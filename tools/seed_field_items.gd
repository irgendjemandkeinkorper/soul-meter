extends Node
## Owner-accepted 2026-10-31 item packet, inventory rulings 2026-11-01.
## Run through scripts/seed_field_items.sh. Idempotent: names identify entities
## within the existing Items categories; Pandora remains the source of truth.

const ITEM_ROWS: Array[Dictionary] = [
	{
		"category": "Materials",
		"name": "Forge Coal",
		"description": "A small sack of coal chips, black dust worked into the seams.",
		"base_price": 8,
		"weight": 0.5,
		"grid_size": Vector2i(1, 1),
		"max_stack_size": 5,
	},
	{
		"category": "Materials",
		"name": "Leather Offcuts",
		"description": "Trimmed leather scraps bundled for straps and small repairs.",
		"base_price": 6,
		"weight": 0.2,
		"grid_size": Vector2i(1, 1),
		"max_stack_size": 10,
	},
	{
		"category": "Tools",
		"name": "Rivet Punch",
		"description": "A short iron punch with a head flattened by repeated blows.",
		"base_price": 13,
		"weight": 0.3,
		"grid_size": Vector2i(1, 1),
		"max_stack_size": 1,
	},
	{
		"category": "Materials",
		"name": "Grain Meal",
		"description": "A paper packet of coarsely ground grain, dust caught in every fold.",
		"base_price": 6,
		"weight": 0.5,
		"grid_size": Vector2i(1, 1),
		"max_stack_size": 5,
	},
	{
		"category": "Materials",
		"name": "Sackcloth",
		"description": "A folded square of coarse sacking with the old seam picked out.",
		"base_price": 6,
		"weight": 0.2,
		"grid_size": Vector2i(1, 1),
		"max_stack_size": 10,
	},
	{
		"category": "Tools",
		"name": "Grain Scoop",
		"description": "A small wooden scoop, its lip worn smooth by grain.",
		"base_price": 10,
		"weight": 0.3,
		"grid_size": Vector2i(1, 1),
		"max_stack_size": 1,
	},
	{
		"category": "Materials",
		"name": "Ferry Line",
		"description": "A short coil of rough cord with both ends tightly bound.",
		"base_price": 8,
		"weight": 0.4,
		"grid_size": Vector2i(1, 1),
		"max_stack_size": 10,
	},
	{
		"category": "Materials",
		"name": "Lamp Wicks",
		"description": "A bundle of trimmed wicks wrapped against the damp.",
		"base_price": 6,
		"weight": 0.1,
		"grid_size": Vector2i(1, 1),
		"max_stack_size": 10,
	},
	{
		"category": "Materials",
		"name": "Stopper Wax",
		"description": "A small cake of plain wax for sealing the necks of flasks.",
		"base_price": 6,
		"weight": 0.1,
		"grid_size": Vector2i(1, 1),
		"max_stack_size": 10,
	},
	{
		"category": "Consumables",
		"name": "Road Crusts",
		"description": "Dry brown loaf ends wrapped for a long walk.",
		"base_price": 5,
		"weight": 0.2,
		"grid_size": Vector2i(1, 1),
		"max_stack_size": 10,
	},
	{
		"category": "Tools",
		"name": "Tent Pegs",
		"description": "A pair of short wooden pegs with old cord marks below the heads.",
		"base_price": 9,
		"weight": 0.3,
		"grid_size": Vector2i(1, 1),
		"max_stack_size": 5,
	},
	{
		"category": "Tools",
		"name": "Map Case",
		"description": "A narrow leather case with a rubbed flap and a dry lining.",
		"base_price": 13,
		"weight": 0.2,
		"grid_size": Vector2i(1, 2),
		"max_stack_size": 1,
	},
	{
		"category": "Materials",
		"name": "Cut Reeds",
		"description": "A hand-sized bundle of dried reeds, trimmed and tied at the butt.",
		"base_price": 6,
		"weight": 0.3,
		"grid_size": Vector2i(1, 1),
		"max_stack_size": 10,
	},
	{
		"category": "Materials",
		"name": "Net Cord",
		"description": "A short hank of fine cord with the old knots worked loose.",
		"base_price": 6,
		"weight": 0.2,
		"grid_size": Vector2i(1, 1),
		"max_stack_size": 10,
	},
	{
		"category": "Tools",
		"name": "Netting Needle",
		"description": "A flat wooden needle with a slot for carrying net cord.",
		"base_price": 13,
		"weight": 0.1,
		"grid_size": Vector2i(1, 1),
		"max_stack_size": 1,
	},
	{
		"category": "Consumables",
		"name": "Cloth Bandage",
		"description": "A clean strip of cloth rolled tightly for binding a small wound.",
		"base_price": 10,
		"weight": 0.2,
		"grid_size": Vector2i(1, 1),
		"max_stack_size": 10,
	},
	{
		"category": "Materials",
		"name": "Repair Splints",
		"description": "Thin wooden strips bundled for patching cracked handles and cases.",
		"base_price": 6,
		"weight": 0.2,
		"grid_size": Vector2i(1, 1),
		"max_stack_size": 10,
	},
	{
		"category": "Tools",
		"name": "Stitching Thimble",
		"description": "A small metal finger cap, its crown pitted by a heavy needle.",
		"base_price": 9,
		"weight": 0.1,
		"grid_size": Vector2i(1, 1),
		"max_stack_size": 1,
	},
]


func _ready() -> void:
	await get_tree().process_frame
	if not Pandora.is_loaded():
		Pandora.load_data()
	for row: Dictionary in ITEM_ROWS:
		var category := _category_by_name(row["category"])
		assert(category != null, "Missing Items/%s category" % row["category"])
		_upsert(category, row)
	Pandora.save_data()
	print("FIELD-ITEM-SEED: %d accepted field items present." % ITEM_ROWS.size())
	get_tree().quit()


func _category_by_name(category_name: String) -> PandoraCategory:
	for category: PandoraCategory in Pandora.get_all_categories():
		if category.get_entity_name() == category_name:
			return category
	return null


func _upsert(category: PandoraCategory, row: Dictionary) -> void:
	var entity: PandoraEntity = null
	for candidate: PandoraEntity in Pandora.get_all_entities(category):
		if not candidate is PandoraCategory and candidate.get_entity_name() == row["name"]:
			entity = candidate
			break
	if entity == null:
		entity = Pandora.create_entity(row["name"], category)
	var values := {
		"Display Name": row["name"],
		"Description": row["description"],
		"Base Price": row["base_price"],
		"Weight": row["weight"],
		"Grid Size": row["grid_size"],
		"Max Stack Size": row["max_stack_size"],
		# Ordinary food, materials and repair tools follow their common peers.
		"Rarity": "common",
		"Equip Slot": "",
		"Flavour": "",
	}
	for property_name: String in values:
		var property := entity.get_entity_property(property_name)
		assert(property != null, "Missing Pandora property '%s'" % property_name)
		property.set_default_value(values[property_name])
