class_name ClassDemo
extends RefCounted
## The 5v5 class demo (owner ruling 2026-11-02: "a demo of 5 v 5 battle with 1 of each class";
## "you lead 5, AI runs 5"). Ten members, one per class, built through ChargenBuild so each is
## a legal character, deterministically (no rolls), and named for their class: a demo invents
## no names. Debug builds only; it never touches the player's party or save.
##
## The split is balanced by role: each side has a front-liner, a healer or buffer, and two
## workers of status. It is a starting point for the owner's balance pass, not a ruling.

const PLAYER_SIDE: Array[String] = ["ironbrand", "river-mother", "lensbearer", "mirrorblade", "oathclock"]
const AI_SIDE: Array[String] = ["husk-bearer", "flamebinder", "stormbearer", "locksmirk", "threadwalker"]
const ENCOUNTER_ID := &"debug_class_demo_5v5"


## A legal level-1 member of `class_id`: the class's suggested tones (Locksmirk suggests none,
## so the Wheel's first non-clashing pair), Mastery on the Major, the first people and
## background, the first Discipline the class takes, and the Seven Measures placed evenly.
static func member(class_id: String) -> PartyMember:
	var build := ChargenBuild.new()
	build.select_ancestry(str(ChargenData.ANCESTRIES[0]["id"]))
	build.select_background(str(ChargenData.BACKGROUNDS[0]["id"]))
	build.select_class(class_id)
	for discipline: Dictionary in ChargenData.DISCIPLINES:
		if not ClassCatalog.is_retired_pairing(class_id, str(discipline["id"])):
			build.select_discipline(str(discipline["id"]))
			break
	build.apply_suggested_elements()
	if build.major_element.is_empty():
		var pair := _first_open_pair()
		build.set_elements(pair[0], pair[1])
	build.select_mastery(build.major_element)
	_place_measures(build)
	build.display_name = str(ClassCatalog.by_id(class_id).get("name", class_id))
	return build.to_party_member()


static func party(class_ids: Array[String]) -> Array[PartyMember]:
	var members: Array[PartyMember] = []
	for class_id: String in class_ids:
		members.append(member(class_id))
	return members


static func _first_open_pair() -> Array[String]:
	for i: int in DS.WHEEL.size():
		for j: int in range(i + 1, DS.WHEEL.size()):
			var a := str(DS.WHEEL[i]["id"])
			var b := str(DS.WHEEL[j]["id"])
			if ChargenData.is_valid_element_pair(a, b):
				return [a, b]
	return [str(DS.WHEEL[0]["id"]), ""]


## Round-robin +1 across the Seven Measures until the budget is spent.
static func _place_measures(build: ChargenBuild) -> void:
	var guard := 0
	while build.remaining_attribute_points() > 0 and guard < 200:
		var placed := false
		for id: String in DramgidSchema.ATTRIBUTE_IDS:
			if build.remaining_attribute_points() <= 0:
				break
			if build.step_attribute(id, 1):
				placed = true
		if not placed:
			break
		guard += 1
