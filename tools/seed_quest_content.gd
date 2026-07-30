extends Node
## seed_quest_content.gd — one-off, idempotent addition of the "Loamroot Sprig"
## quest-fetch item to the already-seeded Items/Materials category.
## Run headless: register as a temp autoload, run once, remove (see
## tools/seed_pandora.gd's header for the same convention). Safe to rerun —
## no-ops if the entity already exists. Kept separate from seed_pandora.gd
## since that script aborts outright once any roots exist.
## PANDORA IS CANONICAL for *game data*; data lands in res://data.pandora.

func _ready() -> void:
	await get_tree().process_frame
	if not Pandora.is_loaded():
		Pandora.load_data()

	var materials := _find_category("Materials")
	if materials == null:
		push_error("SEED: no 'Materials' category found — run tools/seed_pandora.gd first.")
		get_tree().quit(1)
		return

	for e in Pandora.get_all_entities(materials):
		if e.get_entity_name() == "Loamroot Sprig":
			print("SEED: Loamroot Sprig already exists — no-op.")
			get_tree().quit()
			return

	var ent := Pandora.create_entity("Loamroot Sprig", materials)
	_assign(ent, "Display Name", "Loamroot Sprig")
	_assign(ent, "Description", "A pale root cutting, still warm from the Loam. Iris wants a few for the grove.")
	_assign(ent, "Max Stack Size", 5)
	_assign(ent, "Weight", 0.1)
	_assign(ent, "Grid Size", Vector2i(1, 1))
	_assign(ent, "Equip Slot", "")
	_assign(ent, "Rarity", "common")
	_assign(ent, "Flavour", "It roots wherever it lands. That is the trouble with it.")

	Pandora.save_data()
	print("SEED: Loamroot Sprig added to Materials.")
	get_tree().quit()


func _find_category(name: String) -> PandoraCategory:
	for c in Pandora.get_all_categories():
		if c.get_entity_name() == name:
			return c as PandoraCategory
	return null


func _assign(ent: PandoraEntity, prop_name: String, value: Variant) -> void:
	var prop := ent.get_entity_property(prop_name)
	if prop == null:
		push_error("SEED: no property '%s' on %s" % [prop_name, ent.get_entity_name()])
		return
	prop.set_default_value(value)
