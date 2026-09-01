extends GdUnitTestSuite

class HubNpc extends NPC:
	func _containing_scene_path() -> String:
		return NpcRoutines.HUB_SCENE


var _flags_before: Dictionary
var _reputation_before: Dictionary
var _world_clock_before: Dictionary


func before_test() -> void:
	_flags_before = GameState.flags.duplicate(true)
	_reputation_before = Reputation.to_dict()
	_world_clock_before = WorldClock.to_dict()
	GameState.flags = {}
	Reputation.from_dict({})
	# Recording reputation inside a test refreshes GameFlow's derived guard
	# properties, and from_dict() does NOT emit — so both ends must resync or
	# a cleared ledger leaks into later suites as a stale locked/unlocked gate.
	GameFlow._sync_reputation_guards()
	WorldClock.set_phase(&"morning", "test")


func after_test() -> void:
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
	assert_str(String(route["path"])).is_equal("res://dialogue/marshal_coiljaw.dialogue")
	assert_str(String(route["title"])).is_equal("hub")


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
