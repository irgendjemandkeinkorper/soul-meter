extends GdUnitTestSuite

class HubNpc extends NPC:
	func _containing_scene_path() -> String:
		return NpcRoutines.HUB_SCENE


var _flags_before: Dictionary
var _reputation_before: Dictionary
var _world_clock_before: Dictionary
var _soul_before: float


func before_test() -> void:
	_flags_before = GameState.flags.duplicate(true)
	_reputation_before = Reputation.to_dict()
	_world_clock_before = WorldClock.to_dict()
	_soul_before = GameState.soul_meter
	GameState.flags = {}
	Reputation.from_dict({})
	# Recording reputation inside a test refreshes GameFlow's derived guard
	# properties, and from_dict() does NOT emit — so both ends must resync or
	# a cleared ledger leaks into later suites as a stale locked/unlocked gate.
	GameFlow._sync_reputation_guards()
	WorldClock.set_phase(&"morning", "test")


func after_test() -> void:
	GameState.soul_meter = _soul_before
	GameState.flags = _flags_before
	Reputation.from_dict(_reputation_before)
	GameFlow._sync_reputation_guards()
	WorldClock.from_dict(_world_clock_before)


func test_registry_is_bounded_and_unknown_npc_has_no_reaction() -> void:
	assert_int(NpcReactions.reaction_count()).is_between(1, NpcReactions.REACTION_CAP)
	assert_bool(NpcReactions.resolve("no-such-npc").is_empty()).is_true()
	for npc_id: String in NpcReactions.REACTIONS:
		for rule: Dictionary in NpcReactions.rules_for(npc_id):
			assert_bool(NpcReactions.rule_is_valid(rule)).is_true()


func test_reaction_presence_wins_and_routine_still_supplies_position() -> void:
	WorldClock.set_phase(&"night", "test")
	GameState.set_flag("dom_bellhouse_inspected", true)
	var npc := _make_hub_npc("sella-varn", "res://dialogue/sella_varn.dialogue", "start")
	# Sella's routine says absent at night; the matching reaction says present.
	assert_bool(npc.visible).is_true()
	assert_int(npc.collision_layer).is_greater(0)
	assert_int(int(npc.process_mode)).is_not_equal(Node.PROCESS_MODE_DISABLED)

	WorldClock.set_phase(&"morning", "test")
	var morning: Dictionary = NpcRoutines.placement("sella-varn", &"morning")
	assert_vector(npc.global_position).is_equal(morning["position"])


func test_flag_signal_switches_to_existing_alternate_dialogue_route() -> void:
	var npc := _make_hub_npc(
		"branek-coiljaw", "res://dialogue/marshal_coiljaw.dialogue", "start"
	)
	assert_str(String(npc._resolved_dialogue_route()["title"])).is_equal("start")
	GameState.set_flag("zhavar_tolling_wilds", true)
	var route: Dictionary = npc._resolved_dialogue_route()
	var resource: DialogueResource = route.get("resource") as DialogueResource
	var expected_resource: DialogueResource = ResourceLoader.load(
		"res://dialogue/marshal_coiljaw.dialogue"
	) as DialogueResource
	assert_bool(resource == expected_resource).is_true()
	assert_str(String(route["title"])).is_equal("hub")


func test_committed_dialogue_load_failure_names_attempted_path() -> void:
	var npc: HubNpc = _make_hub_npc(
		"unreadable-committed", "res://dialogue/iris_illepah.dialogue", "start"
	)
	npc.npc_name = "Gate Tester"
	var route: Dictionary = npc._resolved_dialogue_route()
	route["resource"] = null
	route["error"] = "unreadable"
	var message: String = str(npc.call("_dialogue_load_failure_message", route))

	assert_str(message).is_equal(
		"NPC 'Gate Tester' could not load dialogue 'res://dialogue/iris_illepah.dialogue'."
	)


func test_campaign_dialogue_load_failure_names_campaign_source() -> void:
	var npc: HubNpc = _make_hub_npc("campaign-npc", "", "campaign_greeting")
	npc.npc_name = "Campaign Tester"
	# One diagnostic key for both provenances: a committed res:// path and a
	# campaign package file are both reported through `source`, so the route
	# never grows a second way to say where a resource came from.
	var route: Dictionary = {
		"source": "user://campaigns/gate/dialogue/greeting.dialogue",
		"title": "campaign_greeting",
		"error": "unreadable",
	}
	var message: String = str(npc.call("_dialogue_load_failure_message", route))

	assert_str(message).is_equal(
		"NPC 'Campaign Tester' could not load dialogue "
		+ "'user://campaigns/gate/dialogue/greeting.dialogue'."
	)


func test_npc_without_reaction_row_keeps_authored_behavior_on_live_signals() -> void:
	var npc := _make_hub_npc("unregistered-npc", "res://dialogue/iris_illepah.dialogue", "start")
	# Simulate unrelated scene-owned state applied after _ready(). Signals that
	# exist only for the reaction mechanism must not reset an unregistered NPC.
	npc.visible = false
	npc.collision_layer = 0
	npc.dialogue_path = "res://dialogue/toma_reedhand.dialogue"
	npc.dialogue_start = "hub"
	GameState.set_flag("zhavar_tolling_wilds", true)
	Reputation.record("player", "dom", 15.0, "test", "test")
	assert_bool(npc.visible).is_false()
	assert_int(npc.collision_layer).is_zero()
	assert_str(npc.dialogue_path).is_equal("res://dialogue/toma_reedhand.dialogue")
	assert_str(npc.dialogue_start).is_equal("hub")


func test_reaction_revived_npc_lands_in_the_same_place_however_it_got_there() -> void:
	# Gate finding 3. Sella's routine is ABSENT at night, so it supplies no
	# position; the reaction then makes her present. Without a deterministic
	# anchor she would simply keep wherever she last stood, so arrival HISTORY
	# would decide where she is — a fresh night load and an evening→night
	# transition would put the same NPC in different places.
	GameState.set_flag("dom_bellhouse_inspected", true)

	WorldClock.set_phase(&"night", "test")
	var fresh := _make_hub_npc("sella-varn", "res://dialogue/sella_varn.dialogue", "start")
	assert_bool(fresh.visible).is_true()
	var fresh_position := fresh.global_position

	WorldClock.set_phase(&"evening", "test")
	var walked := _make_hub_npc("sella-varn", "res://dialogue/sella_varn.dialogue", "start")
	var evening: Dictionary = NpcRoutines.placement("sella-varn", &"evening")
	assert_vector(walked.global_position).is_equal(evening["position"])
	WorldClock.set_phase(&"night", "test")
	assert_bool(walked.visible).is_true()

	assert_vector(walked.global_position) \
		.override_failure_message(
			"A reaction-revived NPC's position must not depend on how it arrived"
		) \
		.is_equal(fresh_position)


func _make_hub_npc(id: String, path: String, title: String) -> HubNpc:
	var npc := auto_free(HubNpc.new()) as HubNpc
	npc.npc_id = id
	npc.dialogue_path = path
	npc.dialogue_start = title
	var sprite := Sprite2D.new()
	sprite.name = "Sprite2D"
	npc.add_child(sprite)
	add_child(npc)
	return npc


func test_a_hollowing_rule_matches_only_while_the_protagonist_is_hollowed() -> void:
	# #286, the NPC-read surface: the world notices without the player choosing
	# to raise it. GameState owns the state; NpcReactions only reads it.
	assert_bool(GameState.is_hollowing()).is_false()
	assert_bool(NpcReactions.resolve("hadrik-vale").is_empty()).is_true()

	GameState.set_flag(GameState.HUSKED_FLAG, true)

	var rule := NpcReactions.resolve("hadrik-vale")
	assert_bool(rule.is_empty()).is_false()
	assert_str(str(rule["dialogue_title"])).is_equal("hollowed")


func test_a_hollowing_route_names_a_title_the_dialogue_file_actually_has() -> void:
	# A reaction that routes to a title nobody authored is a dead end at
	# runtime and silent in every other test.
	for npc_id: String in NpcReactions.REACTIONS:
		for rule: Dictionary in NpcReactions.rules_for(npc_id):
			var path := str(rule.get("dialogue_path", ""))
			if path.is_empty():
				continue
			var file := FileAccess.open(path, FileAccess.READ)
			assert_object(file).override_failure_message(
				"'%s' routes to a missing dialogue file %s" % [npc_id, path]
			).is_not_null()
			var source := file.get_as_text()
			file.close()
			assert_bool(source.contains("~ %s" % str(rule["dialogue_title"]))).override_failure_message(
				"'%s' routes to title '%s', which %s does not define"
				% [npc_id, rule["dialogue_title"], path]
			).is_true()


func test_a_rule_gating_only_on_hollowing_is_valid_and_a_non_bool_one_is_not() -> void:
	var route := {
		"dialogue_path": "res://dialogue/hadrik_vale.dialogue",
		"dialogue_title": "hollowed",
	}
	var hollowing_only: Dictionary = route.duplicate()
	hollowing_only["hollowing"] = true
	assert_bool(NpcReactions.rule_is_valid(hollowing_only)).is_true()

	var not_a_bool: Dictionary = route.duplicate()
	not_a_bool["hollowing"] = "yes"
	assert_bool(NpcReactions.rule_is_valid(not_a_bool)).is_false()

	# Unchanged: a rule that gates on nothing at all is still refused.
	assert_bool(NpcReactions.rule_is_valid(route)).is_false()


func test_a_false_hollowing_gate_is_a_usable_condition() -> void:
	var rule := {"hollowing": false, "present": true}
	assert_bool(NpcReactions.rule_is_valid(rule)).is_true()
	assert_bool(NpcReactions._matches(rule)).is_true()

	GameState.set_flag(GameState.HUSKED_FLAG, true)

	assert_bool(NpcReactions._matches(rule)).is_false()


## --- FR-402 band-gated reactions (#257) -------------------------------------

const CANON_CHARACTERS := "res://canon/dom/characters"

## Band gates whose faction cannot yet REACH its band from authored content.
## A tripwire, not an allowance: when a quest or encounter finally moves one of
## these factions far enough, `test_no_band_gate_is_unreachable_content` starts
## failing and this list is what gets shortened. Canon named the band for all
## five reactions (`hook_summary`); three of the factions it named are simply
## not written to often enough yet.
const UNREACHABLE_BAND_GATES: Array[String] = [
	"rennen", "shattersteel-concord", "wayfare-menders"
]


func test_every_canon_declared_reputation_reaction_is_wired() -> void:
	# `canon/dom/characters/*.json` marks five NPCs
	# `"involvement": "reputation_reaction"` and spells the faction and band out
	# in `hook_summary`. Before #257 not one of them had a rule: canon authored
	# the reaction, and the runtime never read it.
	var declared := _declared_reputation_reactions()
	assert_int(declared.size()).override_failure_message(
		"canon declares no reputation_reaction NPCs — the read is broken, not the data"
	).is_greater_equal(5)
	for npc_id: String in declared:
		var rules := NpcReactions.rules_for(npc_id)
		assert_bool(rules.is_empty()).override_failure_message(
			"'%s' is declared a reputation_reaction in canon with no rule" % npc_id
		).is_false()
		var gated := false
		for rule: Dictionary in rules:
			if str(rule.get("reputation_faction", "")) == str(declared[npc_id]):
				gated = true
		assert_bool(gated).override_failure_message(
			"'%s' has a rule, but none gates on its own faction '%s'"
			% [npc_id, declared[npc_id]]
		).is_true()


func test_a_band_gate_opens_only_at_or_above_its_band() -> void:
	assert_bool(NpcReactions.resolve("raika-toll").is_empty()).override_failure_message(
		"a neutral standing must not open the warm route"
	).is_true()

	# BAND_WARM is 15.0 — one point short is still shut.
	Reputation.record("player", "ironbrand-sentinels", Reputation.BAND_WARM - 1.0, "test", "test")
	assert_bool(NpcReactions.resolve("raika-toll").is_empty()).is_true()

	Reputation.record("player", "ironbrand-sentinels", 1.0, "test", "test")
	var rule := NpcReactions.resolve("raika-toll")
	assert_bool(rule.is_empty()).is_false()
	assert_str(str(rule["dialogue_title"])).is_equal("dom_raika_toll_warm")


func test_a_band_gate_stays_open_above_its_band() -> void:
	# `band_at_least` is a FLOOR: allied must not fall through the warm gate.
	Reputation.record("player", "iron-companies", Reputation.BAND_ALLIED + 5.0, "test", "test")
	assert_str(String(Reputation.band("iron-companies"))).is_equal("allied")
	assert_bool(NpcReactions.resolve("edda-broadmark").is_empty()).is_false()


func test_a_spawned_townsfolk_npc_resolves_its_reaction_from_node_meta() -> void:
	# TownNpcSpawner gives its 60 generated townsfolk their identity as node
	# META, never as the exported `npc_id`. Every band reaction authored for
	# them was dead until `_refresh_world_state()` resolved identity the same
	# way the quest router already did.
	var npc := _make_spawned_npc(
		"raika-toll", "res://dialogue/dom_townsfolk.dialogue", "dom_raika_toll"
	)
	assert_str(npc.npc_id).is_empty()
	assert_str(npc.dialogue_start).is_equal("dom_raika_toll")

	Reputation.record("player", "ironbrand-sentinels", 20.0, "test", "test")

	assert_str(npc.dialogue_start).override_failure_message(
		"a spawned NPC never reached its own reaction"
	).is_equal("dom_raika_toll_warm")
	assert_str(npc.dialogue_path).is_equal(NpcReactions.BAND_REACTION_DIALOGUE)


func test_a_band_route_does_not_hand_edit_the_generated_townsfolk_file() -> void:
	# `dialogue/dom_townsfolk.dialogue` is written by tools/generate_gloot.gd.
	# A band route authored into it is lost on the next regeneration, so no
	# reputation-gated rule may point at it.
	for npc_id: String in NpcReactions.REACTIONS:
		for rule: Dictionary in NpcReactions.rules_for(npc_id):
			if str(rule.get("reputation_faction", "")).is_empty():
				continue
			assert_str(str(rule.get("dialogue_path", ""))).override_failure_message(
				"'%s' routes a band reaction into the GENERATED townsfolk file" % npc_id
			).is_not_equal("res://dialogue/dom_townsfolk.dialogue")


func test_dom_has_at_least_three_band_gated_reactions() -> void:
	# FR-402: every hub has >= 3 reactions gated on Reputation.band().
	var gated: Array[String] = []
	for npc_id: String in NpcReactions.REACTIONS:
		for rule: Dictionary in NpcReactions.rules_for(npc_id):
			if not str(rule.get("reputation_faction", "")).is_empty():
				gated.append(npc_id)
				break
	assert_array(gated).has_size(6)


func test_no_band_gate_is_unreachable_content() -> void:
	# A gate on a faction the player cannot move far enough is a route nobody
	# ever sees. Every gated faction is checked against the best standing
	# authored content can actually produce.
	var reachable := _best_authored_standing()
	var unreachable: Array[String] = []
	for npc_id: String in NpcReactions.REACTIONS:
		for rule: Dictionary in NpcReactions.rules_for(npc_id):
			var faction := str(rule.get("reputation_faction", ""))
			if faction.is_empty():
				continue
			var band := StringName(rule.get("minimum_reputation_band", &"neutral"))
			var best := float(reachable.get(faction, 0.0))
			assert_bool(reachable.has(faction)).override_failure_message(
				"'%s' gates on '%s', which no authored content ever writes"
				% [npc_id, faction]
			).is_true()
			if int(Reputation.BAND_RANK[_band_of(best)]) < int(Reputation.BAND_RANK[band]):
				if not unreachable.has(faction):
					unreachable.append(faction)
	unreachable.sort()
	var expected := UNREACHABLE_BAND_GATES.duplicate()
	expected.sort()
	assert_array(unreachable).override_failure_message(
		"the set of unreachable band gates changed; update UNREACHABLE_BAND_GATES"
	).is_equal(expected)


## `Reputation.band()` reads the live ledger; this asks the same question of a
## hypothetical standing, so the thresholds still come from Reputation.
func _band_of(standing: float) -> StringName:
	if standing <= Reputation.BAND_HOSTILE:
		return &"hostile"
	if standing <= Reputation.BAND_COLD:
		return &"cold"
	if standing >= Reputation.BAND_ALLIED:
		return &"allied"
	if standing >= Reputation.BAND_WARM:
		return &"warm"
	return &"neutral"


func _declared_reputation_reactions() -> Dictionary:
	var declared: Dictionary = {}
	for filename: String in DirAccess.get_files_at(CANON_CHARACTERS):
		if filename.get_extension().to_lower() != "json":
			continue
		var file := FileAccess.open(CANON_CHARACTERS.path_join(filename), FileAccess.READ)
		if file == null:
			continue
		var parsed: Variant = JSON.parse_string(file.get_as_text())
		file.close()
		if not parsed is Dictionary:
			continue
		var document: Dictionary = parsed
		if str(document.get("involvement", "")) == "reputation_reaction":
			declared[str(document["id"])] = str(document.get("faction_id", ""))
	return declared


## The best standing authored content can produce per faction: the highest
## single outcome each side quest can pay, plus every positive `Reputation.record`
## a committed dialogue file can fire. Encounter wins are deliberately excluded —
## they are repeatable, so counting them would make every gate trivially
## reachable and the tripwire meaningless.
func _best_authored_standing() -> Dictionary:
	var totals: Dictionary = {}
	for quest: DomSideQuest in QuestRegistry.DOM_SIDE_QUESTS:
		var best: Dictionary = {}
		for index in quest.outcome_faction_ids.size():
			var faction := quest.outcome_faction_ids[index]
			if faction.is_empty() or index >= quest.outcome_reputation_deltas.size():
				continue
			var delta := float(quest.outcome_reputation_deltas[index])
			best[faction] = maxf(float(best.get(faction, 0.0)), delta)
		for faction: String in best:
			totals[faction] = float(totals.get(faction, 0.0)) + float(best[faction])
	var pattern := RegEx.create_from_string(
		'Reputation\\.record\\("[a-z]+", *"([a-z-]+)", *(-?[0-9.]+)'
	)
	for filename: String in DirAccess.get_files_at("res://dialogue"):
		if not filename.ends_with(".dialogue"):
			continue
		var file := FileAccess.open("res://dialogue".path_join(filename), FileAccess.READ)
		if file == null:
			continue
		var source := file.get_as_text()
		file.close()
		for match_result: RegExMatch in pattern.search_all(source):
			var delta := float(match_result.get_string(2))
			if delta <= 0.0:
				continue
			var faction := match_result.get_string(1)
			totals[faction] = float(totals.get(faction, 0.0)) + delta
	return totals


func _make_spawned_npc(id: String, path: String, title: String) -> HubNpc:
	var npc := auto_free(HubNpc.new()) as HubNpc
	npc.set_meta(&"npc_id", id)
	npc.dialogue_path = path
	npc.dialogue_start = title
	var sprite := Sprite2D.new()
	sprite.name = "Sprite2D"
	npc.add_child(sprite)
	add_child(npc)
	return npc
