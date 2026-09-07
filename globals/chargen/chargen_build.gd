class_name ChargenBuild
extends RefCounted
## The in-progress character (docs/architecture-chargen-dramgid.md §7.2).
##
## Pure model: no UI, no GameState writes. The wizard drives it; tests drive it directly.
## Every percentage it reports comes from SkillCheck.preview() on a scratch PartyMember
## built from the current choices, so the wizard, the sheet and combat share one formula.
## Creation skill points are spent through Advancement.step_cost() on that same scratch
## member (the ratified bands) and recorded per skill as a LIFO list of costs, so a refund
## at creation is exact. Nothing reaches the ledger until the screen calls
## Advancement.seed_creation_ledger() after the member has its id (§5).
##
## Choices that move a skill's base or tier (attributes, ancestry, class, kit, elements,
## background) reset the creation buys — the points are returned, never silently re-priced.

const TRAINED := "trained"

var ancestry_id := ""
var discipline_id := ""
var class_id := ""
## The ARMS skill the Kit trains — ClassCatalog.kit_skills[0] unless the card offers a
## choice (Ironbrand) and the player picked the other.
var kit_skill := ""
var major_element := ""
var minor_element := ""
## Wheel element of the Background's "Root Note of choice" Mastery; one of the held
## elements (defaults to the Major when the Major is set).
var mastery_element := ""
var attributes: Dictionary = DramgidSchema.default_attributes()
var background_id := ""
var display_name := ""
var epithet := ""
var flaw := ""
var likeness_id: String = str(ChargenData.LIKENESSES[0]["id"])
## skill_id → Array[int] of step costs, in purchase order.
var creation_buys: Dictionary = {}

var _scratch: PartyMember = null


# --- identity -----------------------------------------------------------------------------

func select_ancestry(id: String) -> void:
	if ancestry_id == id:
		return
	ancestry_id = id
	_invalidate(true)


func select_discipline(id: String) -> void:
	discipline_id = id
	_invalidate(false)


## Selecting a class sets the default Kit skill and, when no element has been chosen yet,
## pre-fills the class's suggested Major/Minor (editable on the Elements leaf).
func select_class(id: String) -> void:
	if class_id == id:
		return
	class_id = id
	kit_skill = ClassCatalog.default_kit_skill(id)
	if major_element.is_empty() and minor_element.is_empty():
		apply_suggested_elements()
	_invalidate(true)


func apply_suggested_elements() -> void:
	var entry := ClassCatalog.by_id(class_id)
	if entry.is_empty():
		return
	set_elements(str(entry.get("suggested_major", "")), str(entry.get("suggested_minor", "")))


func select_kit(arms_skill: String) -> bool:
	var offered: Array = ClassCatalog.by_id(class_id).get("kit_skills", [])
	if not arms_skill in offered:
		return false
	if kit_skill != arms_skill:
		kit_skill = arms_skill
		_invalidate(true)
	return true


func set_elements(major: String, minor: String) -> void:
	major_element = major
	minor_element = minor
	if not mastery_element.is_empty() and not mastery_element in held_elements():
		mastery_element = ""
	if mastery_element.is_empty() and not major_element.is_empty():
		mastery_element = major_element
	_invalidate(true)


func select_major(id: String) -> void:
	set_elements(id, minor_element)


func select_minor(id: String) -> void:
	set_elements(major_element, id)


func select_mastery(element: String) -> bool:
	if not element in held_elements():
		return false
	mastery_element = element
	_invalidate(false)
	return true


func select_background(id: String) -> void:
	if background_id == id:
		return
	background_id = id
	_invalidate(true)


func held_elements() -> PackedStringArray:
	var result := PackedStringArray()
	for element in [major_element, minor_element]:
		if not element.is_empty() and not result.has(element):
			result.append(element)
	return result


# --- attributes ---------------------------------------------------------------------------

## Sets one attribute inside [floor, cap] without overspending the budget. Returns false
## (and changes nothing) when the value is out of bounds or would exceed the budget.
func set_attribute(id: String, value: int) -> bool:
	if not DramgidSchema.ATTRIBUTES.has(id):
		return false
	if value < DramgidSchema.ATTRIBUTE_FLOOR or value > DramgidSchema.ATTRIBUTE_CAP:
		return false
	var current := int(attributes.get(id, DramgidSchema.ATTRIBUTE_FLOOR))
	if value - current > remaining_attribute_points():
		return false
	if value == current:
		return true
	attributes[id] = value
	_invalidate(true)
	return true


func step_attribute(id: String, delta: int) -> bool:
	return set_attribute(id, int(attributes.get(id, DramgidSchema.ATTRIBUTE_FLOOR)) + delta)


func remaining_attribute_points() -> int:
	return ChargenData.remaining_points(attributes)


func attributes_valid() -> bool:
	return ChargenData.is_valid_point_buy(attributes)


# --- skills -------------------------------------------------------------------------------

## The Fallout "tag" analog: Trained tiers granted by what the character IS (§5).
func granted_tiers() -> Dictionary:
	var tiers: Dictionary = {}
	for skill_id in ChargenData.background_by_id(background_id).get("skills", []):
		tiers[str(skill_id)] = TRAINED
	for skill_id in ChargenData.ancestry_by_id(ancestry_id).get("trained_skills", []):
		tiers[str(skill_id)] = TRAINED
	if not kit_skill.is_empty():
		tiers[kit_skill] = TRAINED
	for skill_id in held_tones():
		tiers[skill_id] = TRAINED
	return tiers


func held_tones() -> PackedStringArray:
	var result := PackedStringArray()
	for element in held_elements():
		var skill_id := DramgidSchema.tone_skill_for(element)
		if not skill_id.is_empty():
			result.append(skill_id)
	return result


## Every field and ARMS skill plus the held tones, in schema order (§3.3, R3).
func purchasable_skills() -> PackedStringArray:
	var result := PackedStringArray()
	for skill_id: String in DramgidSchema.SKILL_IDS:
		if DramgidSchema.is_tone_skill(skill_id) and not skill_id in held_tones():
			continue
		result.append(skill_id)
	return result


func creation_bonus_points() -> int:
	var bonus := int(ChargenData.ancestry_by_id(ancestry_id).get("creation_bonus_points", 0))
	# Flaw: +0 until the flaw table is enumerated (owner ruling R6).
	return bonus


func creation_pool() -> int:
	return DramgidSchema.creation_skill_pool(attributes, creation_bonus_points())


func points_spent() -> int:
	var total := 0
	for skill_id: String in creation_buys.keys():
		for cost in creation_buys[skill_id]:
			total += int(cost)
	return total


func points_remaining() -> int:
	return creation_pool() - points_spent()


func steps_bought(skill_id: String) -> int:
	return (creation_buys.get(skill_id, []) as Array).size()


func bought_percent(skill_id: String) -> float:
	return steps_bought(skill_id) * Advancement.STEP_PERCENT


## Advancement's gate shape: {allowed, blocked_by, cost, message}.
func can_buy(skill_id: String) -> Dictionary:
	if not DramgidSchema.is_skill(skill_id):
		return _gate(false, "unknown_skill", 0, "No such skill.")
	var member := scratch_member()
	if not Advancement.is_purchasable(member, skill_id):
		return _gate(false, "unheld_tone", 0, "Only the Major and Minor tones can be trained in Chapter 1.")
	var cost := Advancement.step_cost(member, skill_id)
	if cost < 0:
		return _gate(false, "effective_cap", 0,
			"Chapter 1 caps effective skill at %d%%." % int(Advancement.EFFECTIVE_CAP))
	if points_remaining() < cost:
		return _gate(false, "points", cost,
			"Needs %d creation point%s." % [cost, "" if cost == 1 else "s"])
	return _gate(true, "", cost, "")


func buy(skill_id: String) -> Dictionary:
	var gate := can_buy(skill_id)
	if not gate["allowed"]:
		return gate
	if not creation_buys.has(skill_id):
		creation_buys[skill_id] = []
	(creation_buys[skill_id] as Array).append(int(gate["cost"]))
	_scratch = null
	gate["new_percentage"] = preview_percent(skill_id)
	return gate


## Sells back the last step bought in `skill_id` at exactly what it cost (wizard only —
## in play, the Mirror Rewriting is the one refund).
func refund(skill_id: String) -> Dictionary:
	if steps_bought(skill_id) == 0:
		return _gate(false, "nothing_to_refund", 0, "No creation point spent here.")
	var costs: Array = creation_buys[skill_id]
	var refunded := int(costs.pop_back())
	if costs.is_empty():
		creation_buys.erase(skill_id)
	_scratch = null
	return {"allowed": true, "blocked_by": "", "cost": refunded, "message": "",
		"new_percentage": preview_percent(skill_id)}


func preview_percent(skill_id: String) -> float:
	return SkillCheck.preview(skill_id, scratch_member(), 0.0)


func tier_of(skill_id: String) -> String:
	return str(granted_tiers().get(skill_id, "untrained"))


# --- flow ---------------------------------------------------------------------------------

## {valid: bool, message: String} for one leaf (docs §7.1 gates).
func validate(step_id: StringName) -> Dictionary:
	match step_id:
		&"ancestry":
			return _verdict(not ancestry_id.is_empty(), "Choose a people.")
		&"discipline":
			return _verdict(not discipline_id.is_empty(), "Choose a Discipline — a body moves before a god notices it.")
		&"patron":
			if class_id.is_empty():
				return _verdict(false, "Choose a Patron.")
			if ClassCatalog.is_retired_pairing(class_id, discipline_id):
				return _verdict(false, "%s does not take %s — that pairing is retired." % [
					ClassCatalog.by_id(class_id).get("name", class_id),
					ChargenData.discipline_by_id(discipline_id).get("name", discipline_id)])
			if not kit_skill in (ClassCatalog.by_id(class_id).get("kit_skills", []) as Array):
				return _verdict(false, "Choose the Kit weapon.")
			return _verdict(true, "")
		&"elements":
			if major_element.is_empty():
				return _verdict(false, "Choose a Major element.")
			if not ChargenData.is_valid_element_pair(major_element, minor_element):
				return _verdict(false, "Major and Minor cannot be an opposed pair.")
			if not mastery_element in held_elements():
				return _verdict(false, "Choose the Root Note your Mastery sits on.")
			return _verdict(true, "")
		&"attributes":
			var remaining := remaining_attribute_points()
			if remaining > 0:
				return _verdict(false, "%d point%s left to place." % [remaining, "" if remaining == 1 else "s"])
			return _verdict(attributes_valid(), "The Seven Measures must sum to %d." % DramgidSchema.ATTRIBUTE_BUDGET)
		&"background":
			return _verdict(not background_id.is_empty(), "Choose a Background.")
		&"skills":
			return _verdict(points_remaining() >= 0, "Too many points spent.")
		&"identity":
			return _verdict(not display_name.strip_edges().is_empty(), "A name is required.")
		&"summary":
			for id in ChargenSteps.ids():
				if id == &"summary":
					continue
				var verdict := validate(id)
				if not verdict["valid"]:
					return verdict
			return _verdict(true, "")
	return _verdict(false, "Unknown step.")


func is_complete() -> bool:
	return validate(&"summary")["valid"]


## The member exactly as ACCEPT registers it (portrait and id are the screen's to set).
func to_party_member() -> PartyMember:
	var member := PartyMember.new()
	var ancestry := ChargenData.ancestry_by_id(ancestry_id)
	var class_entry := ClassCatalog.by_id(class_id)
	member.display_name = display_name.strip_edges()
	member.epithet = epithet.strip_edges()
	member.race = str(ancestry.get("name", ""))
	member.char_class = ClassCatalog.display_class(class_id)
	member.discipline = discipline_id
	member.patron = str(class_entry.get("patron", ""))
	member.class_id = class_id
	member.kit_weapon_skill = kit_skill
	member.kit_weapon = ""
	member.background = background_id
	member.flaw = flaw.strip_edges()
	member.starting_mastery = str(ChargenData.background_by_id(background_id).get("mastery", ""))
	member.mastery_element = mastery_element
	member.major_element = major_element
	member.minor_element = minor_element
	member.attributes = attributes.duplicate(true)
	member.skill_tiers = granted_tiers()
	member.skill_percentages = {}
	for skill_id: String in creation_buys.keys():
		member.skill_percentages[skill_id] = bought_percent(skill_id)
	member.advancement_points = maxi(points_remaining(), 0)
	member.bio = str(ancestry.get("trait", ""))
	member.level = 1
	DramgidDerived.recompute(member)
	member.hp = member.max_hp
	member.breath = member.breath_max
	return member


## skill_id → the ledger row Advancement.seed_creation_ledger() writes at ACCEPT.
func creation_ledger_rows() -> Dictionary:
	var rows: Dictionary = {}
	var tiers := granted_tiers()
	for skill_id: String in creation_buys.keys():
		var spent := 0
		for cost in creation_buys[skill_id]:
			spent += int(cost)
		rows[skill_id] = {
			"percentage": bought_percent(skill_id),
			"tier": str(tiers.get(skill_id, "untrained")),
			"advancement_points_spent": spent,
		}
	return rows


## A PartyMember built from the current choices, for previews. Rebuilt lazily whenever a
## choice changes; never registered anywhere.
func scratch_member() -> PartyMember:
	if _scratch == null:
		_scratch = to_party_member()
	return _scratch


# --- internals ----------------------------------------------------------------------------

func _invalidate(resets_buys: bool) -> void:
	_scratch = null
	if resets_buys and not creation_buys.is_empty():
		creation_buys.clear()


static func _gate(allowed: bool, blocked_by: String, cost: int, message: String) -> Dictionary:
	return {"allowed": allowed, "blocked_by": blocked_by, "cost": cost, "message": message}


static func _verdict(valid: bool, message: String) -> Dictionary:
	return {"valid": valid, "message": "" if valid else message}
