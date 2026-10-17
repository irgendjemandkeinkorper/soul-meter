extends GdUnitTestSuite
## Ashlaren, hub 3 (C2 / #239): the scene the Weftlumin `ashlaren` package baked, its two
## interiors, the Kesselford ↔ Ashlaren grain-road exits, and the per-hub townsfolk pipeline
## (roster, spawner, routines). Pattern: `test/integration/test_kesselford.gd`; checklist:
## `docs/templates/location.md`.

const ASHLAREN := "res://world/ashlaren.tscn"
const KESSELFORD := "res://world/kesselford.tscn"
const WEIGHING_HALL := "res://world/interiors/ashlaren_weighing_hall.tscn"
const MILLHOUSE := "res://world/interiors/ashlaren_millhouse.tscn"
const OUTDOOR_IDS: Array[String] = [
	"ashlaren-bell-warden", "ashlaren-ghorr-steward", "ashlaren-warehouse-watch",
]

var _game_state_before_test: Dictionary = {}


func before_test() -> void:
	_game_state_before_test = GameState.to_dict()


func after_test() -> void:
	# chapter_location.gd sets the arrival flag on ready; keep it out of the other suites.
	GameState.from_dict(_game_state_before_test)


func test_scene_carries_the_location_contract() -> void:
	var town: Node2D = auto_free((load(ASHLAREN) as PackedScene).instantiate())
	add_child(town)
	await get_tree().process_frame

	var script := town.get_script() as Script
	assert_str(script.resource_path).is_equal("res://world/chapter_location.gd")
	assert_bool(town.y_sort_enabled).is_true()
	for marker_name: String in [
		"SpawnDefault", "SpawnFromKesselford", "SpawnFromAshlarenWeighingHall",
		"SpawnFromAshlarenMillhouse", "SpawnSlotFieldMargin",
	]:
		assert_object(town.get_node_or_null(marker_name) as Marker2D) \
			.override_failure_message("Ashlaren must carry the %s marker." % marker_name) \
			.is_not_null()
	for anchor_name: String in ["ShrineBell", "WeighingBoard", "SealedSackCrates", "WeighingHallDoor", "MillhouseDoor"]:
		assert_object(town.find_child(anchor_name, true, false)) \
			.override_failure_message("Ashlaren must carry the %s placement anchor." % anchor_name) \
			.is_not_null()

	var exit_node := town.get_node_or_null("RoadToKesselford") as TravelExit
	assert_object(exit_node).is_not_null()
	if exit_node != null:
		assert_str(exit_node.target_scene).is_equal(KESSELFORD)
		assert_str(String(exit_node.spawn_id)).is_equal("from_ashlaren")
		assert_object(LocationRegistry.by_scene(exit_node.target_scene)).is_not_null()
	for pair: Array in [["WeighingHallDoor", &"ashlaren_weighing_hall_enter"], ["MillhouseDoor", &"ashlaren_millhouse_enter"]]:
		var door := town.get_node_or_null(String(pair[0])) as BuildingDoor
		assert_object(door).is_not_null()
		if door == null:
			continue
		assert_str(String(door.transition_id)).is_equal(String(pair[1]))
		var transition := BuildingTransitionRegistry.by_id(pair[1])
		assert_object(transition).is_not_null()
		if transition != null:
			assert_str(transition.source_scene).is_equal(ASHLAREN)
			assert_str(String(transition.source_anchor)).is_equal(String(pair[0]))
			assert_bool(ResourceLoader.exists(transition.destination_scene)).is_true()

	var dressing := town.get_node_or_null("AshlarenDressing")
	assert_object(dressing).is_not_null()
	if dressing != null:
		for layer_name: String in ["GroundDetails", "SoftDetails", "SolidProps"]:
			var layer := dressing.get_node_or_null(layer_name) as Node2D
			assert_object(layer).is_not_null()
			if layer != null:
				assert_int(layer.get_child_count()).is_greater_equal(1)
	assert_object(town.get_node_or_null("OutdoorTownsfolk") as TownNpcSpawner).is_not_null()


func test_registries_agree_on_ashlaren() -> void:
	var location := LocationRegistry.by_id(&"ashlaren")
	assert_object(location).is_not_null()
	if location == null:
		return
	assert_str(location.scene_path).is_equal(ASHLAREN)
	assert_str(location.arrival_flag).is_equal("chapter_ashlaren_reached")
	assert_bool(location.spawns.has(&"from_kesselford")).is_true()
	assert_bool(location.spawns.has(&"from_ashlaren_weighing_hall")).is_true()
	assert_bool(location.spawns.has(&"from_ashlaren_millhouse")).is_true()
	assert_bool(LocationRegistry.no_combat_zone_by_scene(ASHLAREN)).is_false()
	assert_bool(LocationRegistry.no_combat_zone_by_scene(WEIGHING_HALL)).is_true()
	assert_bool(LocationRegistry.KESSELFORD.spawns.has(&"from_ashlaren")).is_true()
	# §3 of docs/thinning-gradient.md: tier 0 reads 95; the interiors inherit the hub's accord.
	assert_float(location.harmonic_accord).is_equal(95.0)
	assert_float(LocationRegistry.ASHLAREN_MILLHOUSE.harmonic_accord).is_equal(95.0)

	var hub := FastTravelRegistry.by_id(&"ashlaren")
	assert_str(str(hub.get("scene_path", ""))).is_equal(ASHLAREN)
	assert_array(FastTravelRegistry.validate()).is_empty()
	assert_dict(WorldMapRegistry.route_between(&"kesselford", &"ashlaren")).is_not_empty()
	assert_str(str(WorldMapRegistry.location(&"ashlaren").get("scene_path", ""))).is_equal(ASHLAREN)

	var town_ids := NpcRoster.town_ids()
	assert_array(town_ids).contains(["dom", "kesselford", "ashlaren"])
	var placements := NpcRoster.placements_for_scene(ASHLAREN)
	assert_array(placements.keys()).contains_exactly_in_any_order(OUTDOOR_IDS)
	for npc_id: String in OUTDOOR_IDS:
		assert_str(NpcRoutines.hub_scene(npc_id)).is_equal(ASHLAREN)


func test_kesselford_carries_the_reverse_exit() -> void:
	var town: Node2D = auto_free((load(KESSELFORD) as PackedScene).instantiate())
	add_child(town)
	await get_tree().process_frame
	assert_object(town.get_node_or_null("SpawnFromAshlaren") as Marker2D).is_not_null()
	var exit_node := town.get_node_or_null("GrainRoad") as TravelExit
	assert_object(exit_node).is_not_null()
	if exit_node == null:
		return
	assert_str(exit_node.target_scene).is_equal(ASHLAREN)
	assert_str(String(exit_node.spawn_id)).is_equal("from_kesselford")
	# Hub to hub along a kept road: no tutorial gate on this side (Dom's Ford Road carries it).
	assert_array(exit_node.required_flags).is_empty()


func test_townsfolk_spawn_from_the_ashlaren_roster_at_their_anchors() -> void:
	var runner := scene_runner(ASHLAREN)
	await runner.simulate_frames(5)
	var town: Node2D = runner.scene()
	var spawned: Array[Node] = []
	_collect_group_members(town, &"generated_townsfolk", spawned)
	assert_int(spawned.size()) \
		.override_failure_message("Ashlaren's three outdoor townsfolk must spawn from its roster.") \
		.is_equal(OUTDOOR_IDS.size())
	var placements := NpcRoster.placements_for_scene(ASHLAREN)
	var seen: Array[String] = []
	for node: Node in spawned:
		var npc := node as NPC
		assert_object(npc).is_not_null()
		if npc == null:
			continue
		# Generated townsfolk carry their roster id as metadata (see TownNpcSpawner).
		var npc_id := str(npc.get_meta(&"npc_id", ""))
		seen.append(npc_id)
		assert_str(npc.dialogue_path).is_equal("res://dialogue/ashlaren_townsfolk.dialogue")
		assert_bool(FileAccess.file_exists(npc.dialogue_path)).is_true()
		var placement: Dictionary = placements.get(npc_id, {})
		var anchor := town.find_child(str(placement.get("anchor", "")), true, false) as Node2D
		assert_object(anchor).is_not_null()
		if anchor == null:
			continue
		# A routined NPC stands at this phase's routine position (hub coordinates, grid-snapped);
		# the others at their placement anchor.
		var expected := anchor.global_position
		var where := anchor.name
		if NpcRoutines.has_routine(npc_id):
			var row := NpcRoutines.placement(npc_id, WorldClock.phase())
			if not bool(row.get("present", false)):
				continue
			expected = town.to_global(row["position"])
			where = "%s routine spot" % String(WorldClock.phase())
		assert_float(npc.global_position.distance_to(expected)) \
			.override_failure_message("%s must stand at its %s." % [npc_id, where]) \
			.is_less(180.0)
	assert_array(seen).contains_exactly_in_any_order(OUTDOOR_IDS)


func test_npc_talk_prompt_only_shows_when_player_is_in_range() -> void:
	var runner := scene_runner(ASHLAREN)
	await runner.simulate_frames(5)
	var player: Node2D = runner.find_child("Player", true, false)
	# The warehouse watch is phase-agnostic, so it stands at its anchor in every phase.
	var npc: Node2D = runner.find_child("AshlarenWarehouseWatch", true, false)
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
	var runner := scene_runner(ASHLAREN)
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


func test_interiors_populate_from_the_ashlaren_roster() -> void:
	var hall: Node2D = auto_free((load(WEIGHING_HALL) as PackedScene).instantiate())
	add_child(hall)
	await get_tree().process_frame
	var room := hall.get_node_or_null("Room") as BuildingInterior
	assert_object(room).is_not_null()
	if room == null:
		return
	assert_str(String(room.exit_transition_id)).is_equal("ashlaren_weighing_hall_exit")
	var exit_transition := BuildingTransitionRegistry.by_id(&"ashlaren_weighing_hall_exit")
	assert_object(exit_transition).is_not_null()
	if exit_transition != null:
		assert_str(exit_transition.destination_scene).is_equal(ASHLAREN)
		assert_str(String(exit_transition.spawn_id)).is_equal("from_ashlaren_weighing_hall")
		assert_object(room.get_node_or_null(NodePath(String(exit_transition.source_anchor).trim_prefix("Room/")))) \
			.is_not_null()
	assert_array(_indoor_townsfolk(room)).contains_exactly_in_any_order(["ashlaren-head-factor", "ashlaren-weigh-clerk"])

	var millhouse: Node2D = auto_free((load(MILLHOUSE) as PackedScene).instantiate())
	add_child(millhouse)
	await get_tree().process_frame
	var taproom := millhouse.get_node_or_null("Room") as BuildingInterior
	assert_object(taproom).is_not_null()
	if taproom == null:
		return
	assert_str(String(taproom.exit_transition_id)).is_equal("ashlaren_millhouse_exit")
	assert_array(_indoor_townsfolk(taproom)).contains_exactly(["ashlaren-miller"])
	var vendors: Array[String] = []
	for node: Node in taproom.find_children("*", "NPC", true, false):
		var npc := node as NPC
		if npc != null and not npc.vendor_id.is_empty():
			vendors.append(npc.vendor_id)
	assert_array(vendors).contains_exactly(["flat-bell-provisions"])


## Roster townsfolk in `room` (the vendor's counter NPC is seeded separately and skipped).
func _indoor_townsfolk(room: BuildingInterior) -> Array[String]:
	var indoor: Array[String] = []
	for node: Node in room.find_children("*", "NPC", true, false):
		var npc := node as NPC
		if npc != null and npc.npc_id.begins_with("ashlaren-") and npc.vendor_id.is_empty():
			indoor.append(npc.npc_id)
	return indoor


func _collect_group_members(node: Node, group: StringName, found: Array[Node]) -> void:
	if node.is_in_group(group):
		found.append(node)
	for child: Node in node.get_children():
		_collect_group_members(child, group, found)
