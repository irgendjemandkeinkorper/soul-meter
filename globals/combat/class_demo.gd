class_name ClassDemo
extends RefCounted
## The 5v5 class demo (owner ruling 2026-11-02: "a demo of 5 v 5 battle with 1 of each class";
## "you lead 5, AI runs 5"). Ten members, one per class, built through ChargenBuild so each is
## a legal character, deterministically (no rolls), and named for their class: a demo invents
## no names. Debug builds only; it never touches the player's party or save.
##
## The split is balanced by role: each side has a front-liner, a healer or buffer, and two
## workers of status. It is a starting point for the owner's balance pass, not a ruling.
##
## Each member wears a different chargen likeness (the ten LIKENESSES, in class order) so the
## ten bodies on the field can be told apart; there is no per-class art yet.

const PLAYER_SIDE: Array[String] = ["ironbrand", "river-mother", "lensbearer", "mirrorblade", "oathclock"]
const AI_SIDE: Array[String] = ["husk-bearer", "flamebinder", "stormbearer", "locksmirk", "threadwalker"]
const ENCOUNTER_ID := &"debug_class_demo_5v5"
## Screen steps between the two lines (the first enemy seat is this many steps right of the lead).
const FORMATION_GAP := 5


## A legal level-1 member of `class_id`: the class's suggested tones (Locksmirk suggests none,
## so the Wheel's first non-clashing pair), Mastery on the Major, the first people and
## background, the first Discipline the class takes, and the Seven Measures placed evenly.
static func member(class_id: String) -> PartyMember:
	var build := ChargenBuild.new()
	build.likeness_id = _likeness_for(class_id)
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
	var built := build.to_party_member()
	built.id = "class-demo-%s" % class_id
	# The likeness's field body doubles as the portrait, the way PartyMemberVisuals falls back
	# when a member has no plate; field_unit_id() reads the body back off this path.
	built.portrait = load(UnitArt.texture_path(ChargenData.likeness_fallback_unit(build.likeness_id))) as Texture2D
	return built


static func party(class_ids: Array[String]) -> Array[PartyMember]:
	var members: Array[PartyMember] = []
	for class_id: String in class_ids:
		members.append(member(class_id))
	return members


## The demo's encounter: the AI side as class rows (EncounterCatalog builds each through
## `member()`), with no spoils and no reputation stake.
static func encounter_definition() -> Dictionary:
	var rows: Array = []
	for class_id: String in AI_SIDE:
		rows.append({"class_id": class_id})
	return {
		"id": String(ENCOUNTER_ID), "display_name": "Class demo", "enemies": rows, "spoils": [],
		# Two facing lines with room between them, so the first round is a walk-in, not a scrum.
		"formation": {"lines": true, "gap": FORMATION_GAP},
	}


## Seats the player's five as the party (the first stands in as the protagonist, whose id the
## field's lead body answers to) and registers the AI five as a debug encounter. The caller
## owns the sandbox around this: it replaces the live party.
static func prepare() -> bool:
	if not EncounterCatalog.register_debug_encounter(ENCOUNTER_ID, encounter_definition()):
		return false
	seat_player_side()
	return true


## Seats the player's five as the live party, the first as the protagonist. The Kesselford
## walk uses it alone: the same five, no fight.
static func seat_player_side() -> void:
	var members := party(PLAYER_SIDE)
	members[0].id = GameState.PROTAGONIST_ID
	GameState.set_party(members)


static func _likeness_for(class_id: String) -> String:
	var all := PLAYER_SIDE + AI_SIDE
	var index := maxi(0, all.find(class_id))
	return str(ChargenData.LIKENESSES[index % ChargenData.LIKENESSES.size()]["id"])


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
