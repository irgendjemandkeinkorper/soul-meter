class_name ChargenRandomizer
extends RefCounted
## Rolls through the same model API as the wizard. The caller supplies the RNG and
## existing identity pools so a seed is reproducible and missing prose stays untouched.


static func roll(rng: RandomNumberGenerator, current: ChargenBuild, pools: Dictionary) -> ChargenBuild:
	var result := ChargenBuild.new()
	result.select_ancestry(str(ChargenData.ANCESTRIES[rng.randi_range(0, ChargenData.ANCESTRIES.size() - 1)]["id"]))
	result.select_discipline(str(ChargenData.DISCIPLINES[rng.randi_range(0, ChargenData.DISCIPLINES.size() - 1)]["id"]))
	var classes: Array[Dictionary] = []
	for entry: Dictionary in ClassCatalog.ALL:
		if not ClassCatalog.is_retired_pairing(str(entry["id"]), result.discipline_id):
			classes.append(entry)
	var class_entry: Dictionary = classes[rng.randi_range(0, classes.size() - 1)]
	result.select_class(str(class_entry["id"]))
	var kits: Array = class_entry["kit_skills"]
	result.select_kit(str(kits[rng.randi_range(0, kits.size() - 1)]))

	var major := str(ElementWheel.ORDER[rng.randi_range(0, ElementWheel.ORDER.size() - 1)])
	var minors: PackedStringArray = []
	for element: StringName in ElementWheel.ORDER:
		if ChargenData.is_valid_element_pair(major, str(element)):
			minors.append(str(element))
	result.set_elements(major, minors[rng.randi_range(0, minors.size() - 1)])
	var held := result.held_elements()
	result.select_mastery(held[rng.randi_range(0, held.size() - 1)])

	while result.remaining_attribute_points() > 0:
		var available: PackedStringArray = []
		for attribute_id: String in DramgidSchema.ATTRIBUTE_IDS:
			if int(result.attributes[attribute_id]) < DramgidSchema.ATTRIBUTE_CAP:
				available.append(attribute_id)
		result.step_attribute(available[rng.randi_range(0, available.size() - 1)], 1)
	result.select_background(str(ChargenData.BACKGROUNDS[rng.randi_range(0, ChargenData.BACKGROUNDS.size() - 1)]["id"]))

	result.display_name = _pick_text(rng, pools, "display_name", current.display_name)
	result.epithet = _pick_text(rng, pools, "epithet", current.epithet)
	result.flaw = _pick_text(rng, pools, "flaw", current.flaw)
	result.likeness_id = str(ChargenData.LIKENESSES[rng.randi_range(0, ChargenData.LIKENESSES.size() - 1)]["id"])

	# Buy last: changing ancestry, kit, elements, attributes or background refunds
	# creation purchases. can_buy() owns the price bands, held-tone gate and cap.
	while result.points_remaining() > 0:
		var affordable: PackedStringArray = []
		for skill_id: String in result.purchasable_skills():
			if result.can_buy(skill_id)["allowed"]:
				affordable.append(skill_id)
		# The creation pool is smaller than the available one-point field/ARMS buys.
		assert(not affordable.is_empty(), "Creation points must have a legal purchase.")
		result.buy(affordable[rng.randi_range(0, affordable.size() - 1)])
	return result


## Read only the existing NPC identity properties; never synthesize names or prose.
## Sorting removes Pandora traversal order from seeded results. Empty pools leave
## the corresponding current field unchanged (including an intentionally blank field).
static func identity_pools() -> Dictionary:
	var pools: Dictionary = {}
	var properties := {"display_name": "Display Name", "epithet": "Epithet", "flaw": "Flaw"}
	for field: String in properties:
		var values: PackedStringArray = []
		for root: PandoraCategory in Pandora.get_all_roots():
			if root.get_entity_name() != "NPCs":
				continue
			for entity: PandoraEntity in Pandora.get_all_entities(root):
				var property: String = properties[field]
				if not entity.has_entity_property(property):
					continue
				var value := entity.get_string(property)
				if not value.strip_edges().is_empty() and not values.has(value):
					values.append(value)
		values.sort()
		pools[field] = values
	return pools


static func _pick_text(rng: RandomNumberGenerator, pools: Dictionary, field: String, fallback: String) -> String:
	var values: PackedStringArray = pools.get(field, PackedStringArray())
	return fallback if values.is_empty() else values[rng.randi_range(0, values.size() - 1)]
