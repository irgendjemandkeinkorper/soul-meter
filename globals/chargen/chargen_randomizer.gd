class_name ChargenRandomizer
extends RefCounted
## Rolls through the same model API as the wizard. The caller supplies the RNG so a seed
## is reproducible. Name, epithet and flaw are the player's own text and are carried over
## unchanged: there is no player-name pool, and NPC identities must not be reused.


static func roll(rng: RandomNumberGenerator, current: ChargenBuild) -> ChargenBuild:
	var result := ChargenBuild.new()
	var ancestry: Dictionary = ChargenData.ANCESTRIES[rng.randi_range(0, ChargenData.ANCESTRIES.size() - 1)]
	result.select_ancestry(str(ancestry["id"]))
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

	result.display_name = current.display_name
	result.epithet = current.epithet
	result.flaw = current.flaw
	var likenesses := _likenesses_for(str(ancestry["name"]))
	result.likeness_id = str(likenesses[rng.randi_range(0, likenesses.size() - 1)]["id"])

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


## Likeness labels open with their people ("Kaan Liftwright"); keep the rolled likeness
## within the rolled ancestry, falling back to the whole gallery if none match.
static func _likenesses_for(ancestry_name: String) -> Array[Dictionary]:
	var matches: Array[Dictionary] = []
	for entry: Dictionary in ChargenData.LIKENESSES:
		var people := str(entry["label"]).get_slice(" ", 0)
		if ancestry_name.contains(people):
			matches.append(entry)
	return matches if not matches.is_empty() else ChargenData.LIKENESSES
