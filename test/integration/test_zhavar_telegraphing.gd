extends GdUnitTestSuite
## FR-308 (#259, C22): the ladder is telegraphed, and the toll happens once.
##
## The three outputs the PRD names are rumor lines, an ambient cue and one
## scripted tolling event. The ambient cue is pinned by
## `test/unit/test_zhavar_telegraph.gd`; this covers the other two and the
## ladder transitions that drive all three.

const TOLL_SCENE := preload("res://actors/zhavar_toll/zhavar_toll.tscn")
const RUMOR_DIALOGUE := "res://dialogue/dom_zhavar_rumors.dialogue"

const ZONE := "wilds"

var _zhavar_backup: Dictionary = {}
var _flags_backup: Dictionary = {}


func before_test() -> void:
	_zhavar_backup = SaveGame.zhavar.duplicate(true)
	_flags_backup = GameState.flags.duplicate(true)
	SaveGame.zhavar.clear()
	GameState.set_flag(ZhavarToll.witness_flag(ZONE), false)


func after_test() -> void:
	SaveGame.zhavar = _zhavar_backup.duplicate(true)
	GameState.flags = _flags_backup.duplicate(true)


func _raise_to(rung: String) -> void:
	var rungs: Array = SaveGame.ZHAVAR_RUNGS
	while rungs.find(SaveGame.zhavar_rung(ZONE)) < rungs.find(rung):
		SaveGame.raise_zhavar(ZONE)


func _toll() -> ZhavarToll:
	var toll: ZhavarToll = auto_free(TOLL_SCENE.instantiate())
	add_child(toll)
	return toll


# --- The ladder ---------------------------------------------------------------


func test_the_ladder_climbs_one_rung_per_authored_beat_and_stops_at_the_top() -> void:
	# Chapter 1's transitions are AUTHORED, never computed (`save_game.gd`'s
	# FR-308 note). What this pins is that a beat moves exactly one rung.
	var seen: Array[String] = []
	for _step in SaveGame.ZHAVAR_RUNGS.size() + 1:
		seen.append(SaveGame.raise_zhavar(ZONE))

	assert_array(seen).is_equal(
		["rising", "tolling", "ringing", "unprecedented", "unprecedented", "unprecedented"]
	)


func test_reaching_tolling_sets_the_durable_flag_the_reactions_key_on() -> void:
	_raise_to("rising")
	assert_bool(bool(GameState.get_flag("zhavar_tolling_%s" % ZONE, false))).is_false()

	SaveGame.raise_zhavar(ZONE)

	assert_bool(bool(GameState.get_flag("zhavar_tolling_%s" % ZONE, false))).is_true()


# --- The scripted tolling event ------------------------------------------------


func test_the_toll_is_inert_below_tolling() -> void:
	_raise_to("rising")

	var toll: ZhavarToll = _toll()

	assert_bool(toll.is_due()).is_false()
	assert_bool(bool(GameState.get_flag(ZhavarToll.witness_flag(ZONE), false))).is_false()


func test_arriving_in_a_tolling_zone_fires_the_event_once() -> void:
	# The rung is normally raised in Dom, where the player is not standing. So
	# arrival is the common trigger, and it must fire on _ready().
	_raise_to("tolling")
	var heard: Array[String] = []

	var toll: ZhavarToll = _toll()
	toll.tolled.connect(func(zone: String) -> void: heard.append(zone))

	assert_bool(bool(GameState.get_flag(ZhavarToll.witness_flag(ZONE), false))).is_true()
	assert_bool(toll.is_due()).is_false()
	# Connected after _ready(), so the signal count is checked on the RE-entry
	# below; what matters here is that the first instance consumed the event.
	assert_array(heard).is_empty()


func test_re_entering_the_wilds_does_not_replay_the_toll() -> void:
	_raise_to("tolling")
	_toll()

	var returning: ZhavarToll = _toll()
	var heard: Array[String] = []
	returning.tolled.connect(func(zone: String) -> void: heard.append(zone))
	returning._toll_if_due()

	assert_array(heard).override_failure_message(
		"the scripted tolling event replayed on a second visit"
	).is_empty()


func test_the_toll_fires_live_when_the_rung_rises_while_the_player_is_there() -> void:
	_raise_to("rising")
	var toll: ZhavarToll = _toll()
	var heard: Array[String] = []
	toll.tolled.connect(func(zone: String) -> void: heard.append(zone))

	SaveGame.raise_zhavar(ZONE)

	assert_array(heard).is_equal([ZONE])


func test_another_zone_rising_does_not_toll_this_one() -> void:
	var toll: ZhavarToll = _toll()
	var heard: Array[String] = []
	toll.tolled.connect(func(zone: String) -> void: heard.append(zone))

	SaveGame.raise_zhavar("dom")
	SaveGame.raise_zhavar("dom")

	assert_array(heard).is_empty()


func test_a_save_that_skipped_past_tolling_is_still_owed_the_toll() -> void:
	# The ladder is one-way and a rung can be raised anywhere, so "equal to
	# tolling" would strand a save at ringing with an event it can never collect.
	_raise_to("ringing")

	var toll: ZhavarToll = _toll()

	assert_bool(bool(GameState.get_flag(ZhavarToll.witness_flag(ZONE), false))).is_true()


func test_the_witness_flag_is_written_before_the_stroke_finishes() -> void:
	# A quit or a scene change during the 3.6s decay must still count as
	# witnessed; the alternative is an event that replays on every walk-in.
	_raise_to("tolling")

	var toll: ZhavarToll = _toll()

	assert_bool(bool(GameState.get_flag(ZhavarToll.witness_flag(ZONE), false))).is_true()
	assert_bool(toll.is_due()).is_false()


# --- Rumor lines ---------------------------------------------------------------


func test_no_rumor_route_is_reachable_before_the_zone_rises() -> void:
	for npc_id: String in _rumor_npc_ids():
		assert_dict(NpcReactions.resolve(npc_id)).override_failure_message(
			"'%s' gossips about the Zhavar before anything has happened" % npc_id
		).is_empty()


func test_rising_opens_the_rising_rumors_and_leaves_the_tolling_ones_shut() -> void:
	_raise_to("rising")

	assert_str(_title("nalla-gatebeat")).is_equal("dom_nalla_gatebeat_rising")
	assert_str(_title("kessa-nightrail")).is_equal("dom_kessa_nightrail_rising")
	assert_str(_title("tern-hollowbeat")).is_empty()
	assert_str(_title("yssra-coldnet")).is_empty()


func test_tolling_opens_every_rumor_and_promotes_the_speaker_who_has_both() -> void:
	# The gate is a FLOOR, and `resolve()` returns the first match, so Nalla's
	# louder rule is listed first. A rising-first order would pin her forever.
	_raise_to("tolling")

	assert_str(_title("nalla-gatebeat")).override_failure_message(
		"the rumor floor pinned Nalla to her quieter line after the zone tolled"
	).is_equal("dom_nalla_gatebeat_tolling")
	assert_str(_title("kessa-nightrail")).is_equal("dom_kessa_nightrail_rising")
	assert_str(_title("tern-hollowbeat")).is_equal("dom_tern_hollowbeat_tolling")
	assert_str(_title("yssra-coldnet")).is_equal("dom_yssra_coldnet_tolling")


func test_every_rumor_route_names_a_title_the_dialogue_file_actually_has() -> void:
	# A reaction pointing at a title that does not exist is silent at runtime:
	# the NPC simply says nothing, which looks exactly like a working gate.
	var source: FileAccess = FileAccess.open(RUMOR_DIALOGUE, FileAccess.READ)
	assert_object(source).is_not_null()
	var text: String = source.get_as_text()
	source.close()

	for npc_id: String in _rumor_npc_ids():
		for rule: Dictionary in NpcReactions.rules_for(npc_id):
			assert_bool(text.contains("~ %s" % rule["dialogue_title"])).override_failure_message(
				"'%s' routes to missing title '%s'" % [npc_id, rule["dialogue_title"]]
			).is_true()


func test_every_rumor_rule_passes_the_registry_validator() -> void:
	for npc_id: String in _rumor_npc_ids():
		for rule: Dictionary in NpcReactions.rules_for(npc_id):
			assert_bool(NpcReactions.rule_is_valid(rule)).override_failure_message(
				"'%s' carries an invalid rumor rule: %s" % [npc_id, rule]
			).is_true()


func test_half_a_rung_gate_is_refused_in_both_directions() -> void:
	# A zone with no floor fires at "low", which is every save from its first
	# frame. A floor with no zone never fires at all. Both look like content.
	var base: Dictionary = {
		"dialogue_path": RUMOR_DIALOGUE, "dialogue_title": "dom_kessa_nightrail_rising"
	}
	var zone_only: Dictionary = base.duplicate()
	zone_only["zhavar_zone"] = ZONE
	var rung_only: Dictionary = base.duplicate()
	rung_only["minimum_zhavar_rung"] = "rising"
	var bad_rung: Dictionary = base.duplicate()
	bad_rung["zhavar_zone"] = ZONE
	bad_rung["minimum_zhavar_rung"] = "deafening"
	var bad_zone: Dictionary = base.duplicate()
	bad_zone["zhavar_zone"] = " not a zone "
	bad_zone["minimum_zhavar_rung"] = "rising"

	assert_bool(NpcReactions.rule_is_valid(zone_only)).is_false()
	assert_bool(NpcReactions.rule_is_valid(rung_only)).is_false()
	assert_bool(NpcReactions.rule_is_valid(bad_rung)).is_false()
	assert_bool(NpcReactions.rule_is_valid(bad_zone)).is_false()


func _rumor_npc_ids() -> Array[String]:
	return ["nalla-gatebeat", "kessa-nightrail", "tern-hollowbeat", "yssra-coldnet"]


func _title(npc_id: String) -> String:
	return str(NpcReactions.resolve(npc_id).get("dialogue_title", ""))
