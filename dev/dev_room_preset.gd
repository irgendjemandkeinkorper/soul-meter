extends Resource
## Editable input to the normal character, inventory and advancement APIs.
## No class_name: release builds must not register an export-excluded script.

@export_group("Protagonist — ChargenBuild choices")
@export var display_name: String = "DEV"
@export var ancestry_id: String = "vael"
@export var discipline_id: String = "chordblade"
@export var class_id: String = "mirrorblade"
@export var background_id: String = "dom-storm-coast"
@export var likeness_id: String = "likeness_01"
## Empty uses the selected class's suggested elements.
@export var major_element: String = ""
@export var minor_element: String = ""
@export var attributes: Dictionary = {
	"doctrine": 3, "reason": 3, "alacrity": 4, "muster": 3,
	"grit": 3, "intuition": 3, "decorum": 3,
}
@export_group("Party and supplies")
## IDs returned by GameState.recruitable_candidates(); empty is a solo protagonist.
@export var companion_ids: PackedStringArray = []
## ItemIds values (e.g. weapons/forge_hammer) -> count, split into legal stacks.
@export var items: Dictionary = {}
@export_range(0, 1000000) var silver: int = 500
@export_range(1, 6) var level: int = 1
## Extra XP after reaching level through the normal curve; may grant further levels.
@export_range(0, 1000000) var xp: int = 0
@export_range(0.0, 100.0) var soul: float = 50.0
@export var flags: PackedStringArray = []


func character_build() -> ChargenBuild:
	var build := ChargenBuild.new()
	build.select_ancestry(ancestry_id)
	build.select_discipline(discipline_id)
	build.select_class(class_id)
	build.select_background(background_id)
	if not major_element.is_empty():
		build.set_elements(major_element, minor_element)
	for attribute: String in attributes:
		build.set_attribute(attribute, int(attributes[attribute]))
	build.display_name = display_name
	build.likeness_id = likeness_id
	return build


func validation_error() -> String:
	if ChargenData.ancestry_by_id(ancestry_id).is_empty() \
			or ChargenData.discipline_by_id(discipline_id).is_empty() \
			or ClassCatalog.by_id(class_id).is_empty() \
			or ChargenData.background_by_id(background_id).is_empty():
		return "Unknown character choice."
	if not ChargenData.is_valid_point_buy(attributes):
		return "Attributes must use the normal chargen point budget and bounds."
	if not character_build().is_complete():
		return str(character_build().validate(&"summary")["message"])
	var ids_script: Script = load("res://data/generated/item_ids.gd")
	var known_items: Array = ids_script.get_script_constant_map().values()
	for item_id: Variant in items:
		if not item_id is String or not known_items.has(item_id) \
				or not items[item_id] is int or int(items[item_id]) <= 0:
			return "Expected an ItemIds value and a positive integer count: %s" % item_id
	var known_companions: Array[String] = []
	for member: PartyMember in GameState.recruitable_candidates():
		if not GameState.custom_recruits.has(member):
			known_companions.append(member.id)
	var seen: Array[String] = []
	for id: String in companion_ids:
		if not known_companions.has(id) or seen.has(id):
			return "Unknown or duplicate companion: %s" % id
		seen.append(id)
	if level < 1 or level > Advancement.CHAPTER_LEVEL_CAP or xp < 0 or silver < 0:
		return "Level, XP or silver is outside the supported range."
	if not is_finite(soul) or soul < 0.0 or soul > 100.0:
		return "Soul must be between 0 and 100."
	return ""
