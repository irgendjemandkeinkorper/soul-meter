extends GdUnitTestSuite
## Hollowmere, location 8 (C4 / #241): the scene the Weftlumin `hollowmere` package baked, the
## Dorthkor Road ↔ mere reed-track exits, and a second roster town that is not a fast-travel hub
## (three posted outsiders at a drowned mere). Pattern: `test/integration/test_long_verge.gd`;
## checklist: `docs/templates/location.md`.

const HOLLOWMERE := "res://world/hollowmere.tscn"
const DORTHKOR_ROAD := "res://world/dorthkor_road.tscn"
const SPAWN_TABLE := "res://canon/hollowmere/spawn_tables/hollowmere-still-water-ambient.json"
const POSTED_IDS: Array[String] = ["hollowmere-watcher", "hollowmere-envoy", "hollowmere-mender"]

var _game_state_before_test: Dictionary = {}


func before_test() -> void:
	_game_state_before_test = GameState.to_dict()


func after_test() -> void:
	# chapter_location.gd sets the arrival flag on ready; keep it out of the other suites.
	GameState.from_dict(_game_state_before_test)


func test_scene_carries_the_location_contract() -> void:
	var mere: Node2D = auto_free((load(HOLLOWMERE) as PackedScene).instantiate())
	add_child(mere)
	await get_tree().process_frame

	var script := mere.get_script() as Script
	assert_str(script.resource_path).is_equal("res://world/chapter_location.gd")
	assert_bool(mere.y_sort_enabled).is_true()
	for marker_name: String in [
		"SpawnDefault", "SpawnFromDorthkorRoad", "SpawnSlotReedShallows", "SpawnSlotDrownedCamp",
	]:
		assert_object(mere.get_node_or_null(marker_name) as Marker2D) \
			.override_failure_message("Hollowmere must carry the %s marker." % marker_name) \
			.is_not_null()
	# The placement anchors the seeder names, plus the landmarks the proposal names.
	for anchor_name: String in [
		"WatchPost", "InstrumentStake", "EnvoyFire",
		"WatchStilt", "ReportBoard", "ReedLanding", "DrownedShrine", "WrongSkyPool",
		"StiltHouseWest", "StiltHouseMid", "StiltHouseEast",
	]:
		assert_object(mere.find_child(anchor_name, true, false)) \
			.override_failure_message("Hollowmere must carry the %s anchor." % anchor_name) \
			.is_not_null()

	var exit_node := mere.get_node_or_null("ReedTrackToDorthkor") as TravelExit
	assert_object(exit_node).override_failure_message("ReedTrackToDorthkor exit missing.").is_not_null()
	if exit_node != null:
		assert_str(exit_node.target_scene).is_equal(DORTHKOR_ROAD)
		assert_str(String(exit_node.spawn_id)).is_equal("from_hollowmere")
		# Wilds off a road the player already reached: the track is open both ways.
		assert_array(exit_node.required_flags).is_empty()
		assert_object(LocationRegistry.by_scene(exit_node.target_scene)).is_not_null()

	var dressing := mere.get_node_or_null("HollowmereDressing")
	assert_object(dressing).is_not_null()
	if dressing != null:
		for layer_name: String in ["GroundDetails", "SoftDetails", "SolidProps"]:
			var layer := dressing.get_node_or_null(layer_name) as Node2D
			assert_object(layer).is_not_null()
			if layer != null:
				assert_int(layer.get_child_count()).is_greater_equal(1)
	assert_object(mere.get_node_or_null("OutdoorTownsfolk") as TownNpcSpawner).is_not_null()

	# The drowned camp's watch is a committed encounter placed the way encounter.md places one.
	var watch := mere.get_node_or_null("DrownedWatch") as Hostile
	assert_object(watch).is_not_null()
	if watch != null:
		assert_str(String(watch.group_id)).is_equal("bog-wight")
		assert_bool(EncounterCatalog.has_committed(String(watch.group_id))).is_true()
		assert_dict(EncounterCatalog.committed_archetype(String(watch.unit_id))).is_not_empty()


func test_registries_agree_on_hollowmere() -> void:
	var location := LocationRegistry.by_id(&"hollowmere")
	assert_object(location).is_not_null()
	if location == null:
		return
	assert_str(location.scene_path).is_equal(HOLLOWMERE)
	assert_str(location.arrival_flag).is_equal("chapter_hollowmere_reached")
	assert_bool(location.spawns.has(&"from_dorthkor_road")).is_true()
	assert_bool(LocationRegistry.no_combat_zone_by_scene(HOLLOWMERE)).is_false()
	assert_bool(LocationRegistry.DORTHKOR.spawns.has(&"from_hollowmere")).is_true()
	# §3 of docs/thinning-gradient.md: tier 3 on the wilds→front axis reads accord 55 (PROVISIONAL);
	# the proposal's "Phrases fail outright" is that row.
	assert_int(location.thinning_tier).is_equal(3)
	assert_float(location.harmonic_accord).is_equal(55.0)
	assert_str(location.respawn_policy).is_equal("wilderness")

	# Wilds, not a hub: no fast-travel row, but a world-map row with the reed-track route.
	assert_dict(FastTravelRegistry.by_id(&"hollowmere")).is_empty()
	assert_dict(FastTravelRegistry.by_scene(HOLLOWMERE)).is_empty()
	assert_array(FastTravelRegistry.validate()).is_empty()
	assert_str(str(WorldMapRegistry.location(&"hollowmere").get("scene_path", ""))).is_equal(HOLLOWMERE)
	var route := WorldMapRegistry.route_between(&"dorthkor-road", &"hollowmere")
	assert_dict(route).override_failure_message("route dorthkor-road-hollowmere missing").is_not_empty()
	for entry: Dictionary in route.get("encounter_table", []):
		assert_bool(EncounterCatalog.has_committed(String(entry["encounter_id"]))).is_true()
	# The Breach road stays what it was: the mere is a branch off it, not a change to it.
	assert_dict(WorldMapRegistry.route_between(&"dom", &"dorthkor-road")).is_not_empty()

	# A roster town that is not a fast-travel hub, like the Long Verge camp.
	var town_ids := NpcRoster.town_ids()
	assert_array(town_ids).contains(["dom", "kesselford", "ashlaren", "long_verge", "hollowmere"])
	var placements := NpcRoster.placements_for_scene(HOLLOWMERE)
	assert_array(placements.keys()).contains_exactly_in_any_order(POSTED_IDS)
	for npc_id: String in POSTED_IDS:
		assert_str(NpcRoutines.hub_scene(npc_id)).is_equal(HOLLOWMERE)
	# One routine (the Watcher's day) under the FR-504a cap; the other two declared agnostic.
	assert_bool(NpcRoutines.has_routine("hollowmere-watcher")).is_true()
	assert_int(NpcRoutines.present_phase_count("hollowmere-watcher")).is_greater_equal(2)
	for npc_id: String in ["hollowmere-envoy", "hollowmere-mender"]:
		assert_bool(NpcRoutines.DECLARED_PHASE_AGNOSTIC.has(npc_id)).is_true()


func test_spawn_table_anchors_exist_in_the_scene() -> void:
	var parsed: Variant = JSON.parse_string(FileAccess.get_file_as_string(SPAWN_TABLE))
	assert_bool(parsed is Dictionary).is_true()
	if not parsed is Dictionary:
		return
	var table := parsed as Dictionary
	assert_str(str(table.get("scene_path", ""))).is_equal(HOLLOWMERE)
	var mere: Node2D = auto_free((load(HOLLOWMERE) as PackedScene).instantiate())
	add_child(mere)
	await get_tree().process_frame
	var slots: Array = table.get("slots", [])
	assert_int(slots.size()).is_equal(2)
	for slot: Dictionary in slots:
		assert_object(mere.get_node_or_null(str(slot["anchor"])) as Marker2D) \
			.override_failure_message("spawn slot anchor %s missing" % slot["anchor"]).is_not_null()
		for entry: Dictionary in slot.get("entries", []):
			if entry.has("archetype_id"):
				assert_dict(EncounterCatalog.committed_archetype(str(entry["archetype_id"]))).is_not_empty()
	assert_array(SpawnMath.policy_violations(String(LocationRegistry.HOLLOWMERE.respawn_policy), table)).is_empty()


func test_dorthkor_road_carries_the_reverse_exit() -> void:
	var road: Node2D = auto_free((load(DORTHKOR_ROAD) as PackedScene).instantiate())
	add_child(road)
	await get_tree().process_frame
	assert_object(road.get_node_or_null("SpawnFromHollowmere") as Marker2D).is_not_null()
	var reed_track := road.get_node_or_null("ReedTrack") as TravelExit
	assert_object(reed_track).is_not_null()
	if reed_track != null:
		assert_str(reed_track.target_scene).is_equal(HOLLOWMERE)
		assert_str(String(reed_track.spawn_id)).is_equal("from_dorthkor_road")
		assert_array(reed_track.required_flags).is_empty()
	# The road's own exit home is untouched by the package.
	var home := road.get_node_or_null("ReturnToDom") as TravelExit
	assert_object(home).is_not_null()
	if home != null:
		assert_str(home.target_scene).is_equal("res://world/starting_town.tscn")


func test_the_posted_outsiders_spawn_from_the_hollowmere_roster_at_their_anchors() -> void:
	var runner := scene_runner(HOLLOWMERE)
	await runner.simulate_frames(5)
	var mere: Node2D = runner.scene()
	var spawned: Array[Node] = []
	_collect_group_members(mere, &"generated_townsfolk", spawned)
	assert_int(spawned.size()) \
		.override_failure_message("Hollowmere's three posted NPCs must spawn from its roster.") \
		.is_equal(POSTED_IDS.size())
	var placements := NpcRoster.placements_for_scene(HOLLOWMERE)
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
			NpcRoster.dialogue_route("hollowmere", "res://dialogue/hollowmere_townsfolk.dialogue", npc.dialogue_start)
		)
		assert_bool(FileAccess.file_exists(npc.dialogue_path)).is_true()
		var placement: Dictionary = placements.get(npc_id, {})
		var anchor := mere.find_child(str(placement.get("anchor", "")), true, false) as Node2D
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
			expected = mere.to_global(row["position"])
			where = "%s routine spot" % String(WorldClock.phase())
		assert_float(npc.global_position.distance_to(expected)) \
			.override_failure_message("%s must stand at its %s." % [npc_id, where]) \
			.is_less(180.0)
	assert_array(seen).contains_exactly_in_any_order(POSTED_IDS)


func test_npc_talk_prompt_only_shows_when_player_is_in_range() -> void:
	var runner := scene_runner(HOLLOWMERE)
	await runner.simulate_frames(5)
	var player: Node2D = runner.find_child("Player", true, false)
	# The Mender is phase-agnostic, so they stand at the instrument stake in every phase.
	var npc: Node2D = runner.find_child("HollowmereMender", true, false)
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
	var runner := scene_runner(HOLLOWMERE)
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
