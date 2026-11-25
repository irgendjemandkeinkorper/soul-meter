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

	roll_measures(rng, result)
	result.select_background(str(ChargenData.BACKGROUNDS[rng.randi_range(0, ChargenData.BACKGROUNDS.size() - 1)]["id"]))

	result.display_name = current.display_name
	result.epithet = current.epithet
	result.flaw = current.flaw
	var likenesses := _likenesses_for(str(ancestry["name"]))
	result.likeness_id = str(likenesses[rng.randi_range(0, likenesses.size() - 1)]["id"])

	# Buy last: changing ancestry, kit, elements, attributes or background refunds
	# creation purchases. can_buy() owns the price bands, held-tone gate and cap.
	spend_creation_points(rng, result)
	return result


## ROLL THIS TAB: rolls only the fields one register tab owns (ChargenSteps.TABS) and keeps
## the rest. The result stays legal: the Calling roll is drawn as a whole (a class retired
## with the rolled Discipline never comes up), and set_elements() keeps the Mastery on a held
## tone. Purchases a change refunds are left unspent (they carry into play) rather than
## re-bought behind the player's back; only the Measures roll spends the pool.
static func roll_tab(rng: RandomNumberGenerator, current: ChargenBuild, tab_id: StringName) -> ChargenBuild:
	var fresh := roll(rng, current)
	var result := current.copy()
	match tab_id:
		&"origin":
			result.select_ancestry(fresh.ancestry_id)
			result.select_background(fresh.background_id)
		&"calling":
			result.select_discipline(fresh.discipline_id)
			result.select_class(fresh.class_id)
			result.select_kit(fresh.kit_skill)
			result.set_elements(fresh.major_element, fresh.minor_element)
			result.select_mastery(fresh.mastery_element)
		&"measures":
			# Rolled for this build's own class (the fresh roll drew a class of its own).
			for attribute_id: String in DramgidSchema.ATTRIBUTE_IDS:
				result.set_attribute(attribute_id, DramgidSchema.ATTRIBUTE_FLOOR)
			roll_measures(rng, result)
			for skill_id: String in result.creation_buys.keys():
				while result.steps_bought(skill_id) > 0:
					result.refund(skill_id)
			spend_creation_points(rng, result)
		&"name":
			var ancestry_name := str(ChargenData.ancestry_by_id(result.ancestry_id).get("name", ""))
			var likenesses := _likenesses_for(ancestry_name)
			result.likeness_id = str(likenesses[rng.randi_range(0, likenesses.size() - 1)]["id"])
	return result


## Calling and measures S5: what a class leans on, strongest first — its patron measure, then
## the measure behind its Kit skill, then Intuition (every class casts its held tones).
static func class_leanings(class_id: String, kit_skill: String) -> PackedStringArray:
	var leanings := PackedStringArray()
	for attribute_id: String in [
		ClassCatalog.patron_measure(class_id),
		DramgidSchema.governing_attribute(kit_skill) if not kit_skill.is_empty() else "",
		String(DramgidSchema.ATTR_INTUITION),
	]:
		if not attribute_id.is_empty() and attribute_id not in leanings:
			leanings.append(attribute_id)
	return leanings


## Roll weights (PROVISIONAL): the leanings 4, 3 and 2 in order, every other measure 1, so a
## rolled character usually reads as their class without ever being forced to.
const LEANING_WEIGHTS: Array[int] = [4, 3, 2]


## Spends the unplaced measure points one at a time, weighted toward the class's leanings.
static func roll_measures(rng: RandomNumberGenerator, result: ChargenBuild) -> void:
	var leanings := class_leanings(result.class_id, result.kit_skill)
	while result.remaining_attribute_points() > 0:
		var available: PackedStringArray = []
		var weights: PackedInt32Array = []
		var total := 0
		for attribute_id: String in DramgidSchema.ATTRIBUTE_IDS:
			if int(result.attributes[attribute_id]) >= DramgidSchema.ATTRIBUTE_CAP:
				continue
			var rank := leanings.find(attribute_id)
			var weight := LEANING_WEIGHTS[rank] if rank >= 0 and rank < LEANING_WEIGHTS.size() else 1
			available.append(attribute_id)
			weights.append(weight)
			total += weight
		var pick := rng.randi_range(0, total - 1)
		for index in available.size():
			pick -= weights[index]
			if pick < 0:
				result.step_attribute(available[index], 1)
				break


## The SUGGEST spread: the patron measure to the cap, the Kit's measure to 4, then one point at
## a time to 3 across Intuition, Grit, Alacrity, Reason, Decorum, Muster and Doctrine. Placed
## from the floor; the player's other picks are untouched.
const SUGGEST_ORDER: PackedStringArray = [
	"intuition", "grit", "alacrity", "reason", "decorum", "muster", "doctrine",
]


static func suggest_measures(result: ChargenBuild) -> void:
	for attribute_id: String in DramgidSchema.ATTRIBUTE_IDS:
		result.set_attribute(attribute_id, DramgidSchema.ATTRIBUTE_FLOOR)
	var leanings := class_leanings(result.class_id, result.kit_skill)
	var patron := ClassCatalog.patron_measure(result.class_id)
	if not patron.is_empty():
		_raise_toward(result, patron, DramgidSchema.ATTRIBUTE_CAP)
	if not result.kit_skill.is_empty():
		_raise_toward(result, DramgidSchema.governing_attribute(result.kit_skill), 4)
	var placed := true
	while result.remaining_attribute_points() > 0 and placed:
		placed = false
		for attribute_id: String in SUGGEST_ORDER:
			if result.remaining_attribute_points() <= 0:
				break
			if int(result.attributes[attribute_id]) < 3 and result.step_attribute(attribute_id, 1):
				placed = true
	# Anything still unplaced (a spread whose leanings already sit at 3+) tops up in order.
	for attribute_id: String in leanings + SUGGEST_ORDER:
		while result.remaining_attribute_points() > 0 and result.step_attribute(attribute_id, 1):
			pass


static func _raise_toward(result: ChargenBuild, attribute_id: String, target: int) -> void:
	while int(result.attributes[attribute_id]) < target and result.remaining_attribute_points() > 0:
		if not result.step_attribute(attribute_id, 1):
			return


## Spends whatever creation points are left on random legal buys (the roll's last step; the
## register also re-spends rolled points a later choice refunded).
static func spend_creation_points(rng: RandomNumberGenerator, result: ChargenBuild) -> void:
	while result.points_remaining() > 0:
		var affordable: PackedStringArray = []
		for skill_id: String in result.purchasable_skills():
			if result.can_buy(skill_id)["allowed"]:
				affordable.append(skill_id)
		# The creation pool is smaller than the available one-point field/ARMS buys.
		assert(not affordable.is_empty(), "Creation points must have a legal purchase.")
		result.buy(affordable[rng.randi_range(0, affordable.size() - 1)])


## Likeness labels open with their people ("Kaan Liftwright"); keep the rolled likeness
## within the rolled ancestry, falling back to the whole gallery if none match.
static func _likenesses_for(ancestry_name: String) -> Array[Dictionary]:
	var matches: Array[Dictionary] = []
	for entry: Dictionary in ChargenData.LIKENESSES:
		var people := str(entry["label"]).get_slice(" ", 0)
		if ancestry_name.contains(people):
			matches.append(entry)
	return matches if not matches.is_empty() else ChargenData.LIKENESSES
