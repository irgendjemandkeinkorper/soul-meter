extends GdUnitTestSuite
## The Long Verge, location 7 (C3 / #240): the scene the Weftlumin `long-verge` package baked,
## the Dom ↔ Verge ↔ Kesselford moor-road exits, and the first roster town that is not a
## fast-travel hub (a Company camp on a wilds road). Pattern: `test/integration/test_ashlaren.gd`;
## checklist: `docs/templates/location.md`.

const LONG_VERGE := "res://world/long_verge.tscn"
const DOM := "res://world/starting_town.tscn"
const KESSELFORD := "res://world/kesselford.tscn"
const SPAWN_TABLE := "res://canon/long_verge/spawn_tables/long-verge-black-band-ambient.json"
const CAMP_IDS: Array[String] = [
	"long-verge-paymaster", "long-verge-cairn-warden", "long-verge-sergeant",
	"long-verge-old-soldier", "long-verge-recruit",
]

var _game_state_before_test: Dictionary = {}


func before_test() -> void:
	_game_state_before_test = GameState.to_dict()


func after_test() -> void:
	# chapter_location.gd sets the arrival flag on ready; keep it out of the other suites.
	GameState.from_dict(_game_state_before_test)


func test_scene_carries_the_location_contract() -> void:
	var verge: Node2D = auto_free((load(LONG_VERGE) as PackedScene).instantiate())
	add_child(verge)
	await get_tree().process_frame

	var script := verge.get_script() as Script
	assert_str(script.resource_path).is_equal("res://world/chapter_location.gd")
	assert_bool(verge.y_sort_enabled).is_true()
	for marker_name: String in [
		"SpawnDefault", "SpawnFromDom", "SpawnFromKesselford",
		"SpawnSlotBlackBand", "SpawnSlotGraveMound",
	]:
		assert_object(verge.get_node_or_null(marker_name) as Marker2D) \
			.override_failure_message("The Long Verge must carry the %s marker." % marker_name) \
			.is_not_null()
	# The placement anchors the seeder names, plus the landmarks the proposal names.
	for anchor_name: String in [
		"PaymastersTent", "BlackBandCairn", "MusterDrum", "CampFire", "GraveMarker",
		"SplitStone", "FreshBandCairn", "MileCairnWest", "MileCairnMid", "MileCairnEast",
	]:
		assert_object(verge.find_child(anchor_name, true, false)) \
			.override_failure_message("The Long Verge must carry the %s anchor." % anchor_name) \
			.is_not_null()

	for pair: Array in [["RoadToDom", DOM], ["RoadToKesselford", KESSELFORD]]:
		var exit_node := verge.get_node_or_null(String(pair[0])) as TravelExit
		assert_object(exit_node).override_failure_message("%s exit missing." % pair[0]).is_not_null()
		if exit_node == null:
			continue
		assert_str(exit_node.target_scene).is_equal(String(pair[1]))
		assert_str(String(exit_node.spawn_id)).is_equal("from_long_verge")
		# Wilds between two hubs: the road is open both ways once you are on it.
		assert_array(exit_node.required_flags).is_empty()
		assert_object(LocationRegistry.by_scene(exit_node.target_scene)).is_not_null()

	var dressing := verge.get_node_or_null("LongVergeDressing")
	assert_object(dressing).is_not_null()
	if dressing != null:
		for layer_name: String in ["GroundDetails", "SoftDetails", "SolidProps"]:
			var layer := dressing.get_node_or_null(layer_name) as Node2D
			assert_object(layer).is_not_null()
			if layer != null:
				assert_int(layer.get_child_count()).is_greater_equal(1)
	assert_object(verge.get_node_or_null("OutdoorTownsfolk") as TownNpcSpawner).is_not_null()

	# The grave's watch is a committed encounter placed the way encounter.md places one.
	var watch := verge.get_node_or_null("GraveWatch") as Hostile
	assert_object(watch).is_not_null()
	if watch != null:
		assert_str(String(watch.group_id)).is_equal("bog-wight")
		assert_bool(EncounterCatalog.has_committed(String(watch.group_id))).is_true()
		assert_dict(EncounterCatalog.committed_archetype(String(watch.unit_id))).is_not_empty()


func test_registries_agree_on_the_long_verge() -> void:
	var location := LocationRegistry.by_id(&"long_verge")
	assert_object(location).is_not_null()
	if location == null:
		return
	assert_str(location.scene_path).is_equal(LONG_VERGE)
	assert_str(location.arrival_flag).is_equal("chapter_long_verge_reached")
	assert_bool(location.spawns.has(&"from_dom")).is_true()
	assert_bool(location.spawns.has(&"from_kesselford")).is_true()
	assert_bool(LocationRegistry.no_combat_zone_by_scene(LONG_VERGE)).is_false()
	assert_bool(LocationRegistry.DOM.spawns.has(&"from_long_verge")).is_true()
	assert_bool(LocationRegistry.KESSELFORD.spawns.has(&"from_long_verge")).is_true()
	# §3 of docs/thinning-gradient.md: the first field zone reads tier 1 / accord 85 (PROVISIONAL).
	assert_int(location.thinning_tier).is_equal(1)
	assert_float(location.harmonic_accord).is_equal(85.0)
	assert_str(location.respawn_policy).is_equal("wilderness")

	# Wilds, not a hub: no fast-travel row, but a world-map row with a route to each neighbour.
	assert_dict(FastTravelRegistry.by_id(&"long_verge")).is_empty()
	assert_dict(FastTravelRegistry.by_scene(LONG_VERGE)).is_empty()
	assert_array(FastTravelRegistry.validate()).is_empty()
	assert_str(str(WorldMapRegistry.location(&"long-verge").get("scene_path", ""))).is_equal(LONG_VERGE)
	for pair: Array in [[&"dom", &"long-verge"], [&"long-verge", &"kesselford"]]:
		var route := WorldMapRegistry.route_between(pair[0], pair[1])
		assert_dict(route).override_failure_message("route %s-%s missing" % pair).is_not_empty()
		for entry: Dictionary in route.get("encounter_table", []):
			assert_bool(EncounterCatalog.has_committed(String(entry["encounter_id"]))).is_true()
	# The kept road below stays: the Verge is a second way between the hubs, not a detour on the first.
	assert_dict(WorldMapRegistry.route_between(&"dom", &"kesselford")).is_not_empty()

	# The first roster town that is not a fast-travel hub.
	var town_ids := NpcRoster.town_ids()
	assert_array(town_ids).contains(["dom", "kesselford", "ashlaren", "long_verge"])
	var placements := NpcRoster.placements_for_scene(LONG_VERGE)
	assert_array(placements.keys()).contains_exactly_in_any_order(CAMP_IDS)
	for npc_id: String in CAMP_IDS:
		assert_str(NpcRoutines.hub_scene(npc_id)).is_equal(LONG_VERGE)
	# Two routines (paymaster, cairn warden) under the FR-504a cap; the rest declared agnostic.
	assert_bool(NpcRoutines.has_routine("long-verge-paymaster")).is_true()
	assert_bool(NpcRoutines.has_routine("long-verge-cairn-warden")).is_true()
	assert_int(NpcRoutines.present_phase_count("long-verge-paymaster")).is_greater_equal(2)
	for npc_id: String in ["long-verge-sergeant", "long-verge-old-soldier", "long-verge-recruit"]:
		assert_bool(NpcRoutines.DECLARED_PHASE_AGNOSTIC.has(npc_id)).is_true()


func test_spawn_table_anchors_exist_in_the_scene() -> void:
	var parsed: Variant = JSON.parse_string(FileAccess.get_file_as_string(SPAWN_TABLE))
	assert_bool(parsed is Dictionary).is_true()
	if not parsed is Dictionary:
		return
	var table := parsed as Dictionary
	assert_str(str(table.get("scene_path", ""))).is_equal(LONG_VERGE)
	var verge: Node2D = auto_free((load(LONG_VERGE) as PackedScene).instantiate())
	add_child(verge)
	await get_tree().process_frame
	var slots: Array = table.get("slots", [])
	assert_int(slots.size()).is_equal(2)
	for slot: Dictionary in slots:
		assert_object(verge.get_node_or_null(str(slot["anchor"])) as Marker2D) \
			.override_failure_message("spawn slot anchor %s missing" % slot["anchor"]).is_not_null()
		for entry: Dictionary in slot.get("entries", []):
			if entry.has("archetype_id"):
				assert_dict(EncounterCatalog.committed_archetype(str(entry["archetype_id"]))).is_not_empty()
	assert_array(SpawnMath.policy_violations(String(LocationRegistry.LONG_VERGE.respawn_policy), table)).is_empty()


func test_dom_and_kesselford_carry_the_reverse_exits() -> void:
	var dom: Node2D = auto_free((load(DOM) as PackedScene).instantiate())
	add_child(dom)
	await get_tree().process_frame
	assert_object(dom.get_node_or_null("SpawnFromLongVerge") as Marker2D).is_not_null()
	var moor_road := dom.get_node_or_null("MoorRoad") as TravelExit
	assert_object(moor_road).is_not_null()
	if moor_road != null:
		assert_str(moor_road.target_scene).is_equal(LONG_VERGE)
		assert_str(String(moor_road.spawn_id)).is_equal("from_dom")
		# The same tutorial gate as the Ford Road: nobody leaves Dom before the commission.
		assert_array(moor_road.required_flags).contains(["tutorial_road_open", "chapter_one_free_roam"])

	var kesselford: Node2D = auto_free((load(KESSELFORD) as PackedScene).instantiate())
	add_child(kesselford)
	await get_tree().process_frame
	assert_object(kesselford.get_node_or_null("SpawnFromLongVerge") as Marker2D).is_not_null()
	var moor_track := kesselford.get_node_or_null("MoorTrack") as TravelExit
	assert_object(moor_track).is_not_null()
	if moor_track != null:
		assert_str(moor_track.target_scene).is_equal(LONG_VERGE)
		assert_str(String(moor_track.spawn_id)).is_equal("from_kesselford")
		assert_array(moor_track.required_flags).is_empty()


func test_the_camp_spawns_from_the_long_verge_roster_at_its_anchors() -> void:
	var runner := scene_runner(LONG_VERGE)
	await runner.simulate_frames(5)
	var verge: Node2D = runner.scene()
	var spawned: Array[Node] = []
	_collect_group_members(verge, &"generated_townsfolk", spawned)
	assert_int(spawned.size()) \
		.override_failure_message("The Verge's five camp NPCs must spawn from its roster.") \
		.is_equal(CAMP_IDS.size())
	var placements := NpcRoster.placements_for_scene(LONG_VERGE)
	var seen: Array[String] = []
	for node: Node in spawned:
		var npc := node as NPC
		assert_object(npc).is_not_null()
		if npc == null:
			continue
		var npc_id := str(npc.get_meta(&"npc_id", ""))
		seen.append(npc_id)
		# C25 (#262): the authored location file wins per title, the generated one is the fallback.
		assert_str(npc.dialogue_path).is_equal(
			NpcRoster.dialogue_route("long_verge", "res://dialogue/long_verge_townsfolk.dialogue", npc.dialogue_start)
		)
		assert_bool(FileAccess.file_exists(npc.dialogue_path)).is_true()
		var placement: Dictionary = placements.get(npc_id, {})
		var anchor := verge.find_child(str(placement.get("anchor", "")), true, false) as Node2D
		assert_object(anchor).is_not_null()
		if anchor == null:
			continue
		# A routined NPC stands at this phase's routine position (scene coordinates, grid-snapped);
		# the others at their placement anchor.
		var expected := anchor.global_position
		var where := anchor.name
		if NpcRoutines.has_routine(npc_id):
			var row := NpcRoutines.placement(npc_id, WorldClock.phase())
			if not bool(row.get("present", false)):
				continue
			expected = verge.to_global(row["position"])
			where = "%s routine spot" % String(WorldClock.phase())
		assert_float(npc.global_position.distance_to(expected)) \
			.override_failure_message("%s must stand at its %s." % [npc_id, where]) \
			.is_less(180.0)
	assert_array(seen).contains_exactly_in_any_order(CAMP_IDS)


func test_npc_talk_prompt_only_shows_when_player_is_in_range() -> void:
	var runner := scene_runner(LONG_VERGE)
	await runner.simulate_frames(5)
	var player: Node2D = runner.find_child("Player", true, false)
	# The sergeant is phase-agnostic, so he stands at the muster drum in every phase.
	var npc: Node2D = runner.find_child("LongVergeSergeant", true, false)
	assert_object(npc).is_not_null()
	if npc == null:
		return
	## NPC builds this Label in code, so Godot auto-names it "@Label@<id>".
	var prompt: Label = npc.find_child("@Label@*", true, false)
	assert_bool(prompt.visible).is_false()
	player.global_position = npc.global_position
	await runner.simulate_frames(20)
	assert_bool(prompt.visible).is_true()


func test_player_moves_right_when_holding_move_right() -> void:
	var runner := scene_runner(LONG_VERGE)
	var player: Node2D = runner.find_child("Player", true, false)
	var ground := runner.find_child("IsometricGround", true, false) as TileMapLayer
	var start_x: float = player.global_position.x
	runner.simulate_action_press("move_right")
	await runner.simulate_frames(30)
	runner.simulate_action_release("move_right")
	for frame in 120:
		await runner.simulate_frames(1)
		var current_cell: Vector2i = ground.local_to_map(ground.to_local(player.global_position))
		var current_center: Vector2 = ground.to_global(ground.map_to_local(current_cell))
		if player.global_position.is_equal_approx(current_center):
			break
	assert_float(player.global_position.x).is_greater(start_x)


func _collect_group_members(node: Node, group: StringName, found: Array[Node]) -> void:
	if node.is_in_group(group):
		found.append(node)
	for child: Node in node.get_children():
		_collect_group_members(child, group, found)
