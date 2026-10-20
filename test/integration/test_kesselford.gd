extends GdUnitTestSuite
## Kesselford, hub 2 (C1 / #238): the scene the Weftlumin `kesselford` package baked, its two
## interiors, the Dom ↔ Kesselford exits, and the hub-widened townsfolk pipeline (per-hub roster,
## spawner, routines). Pattern: `test/integration/test_field_room.gd`; checklist:
## `docs/templates/location.md`.

const KESSELFORD := "res://world/kesselford.tscn"
const DOM := "res://world/starting_town.tscn"
const WAYHOUSE := "res://world/interiors/kesselford_wayhouse.tscn"
const CHANDLERY := "res://world/interiors/kesselford_chandlery.tscn"
const OUTDOOR_IDS: Array[String] = [
	"kesselford-bell-ringer", "kesselford-ferry-keeper",
	"kesselford-mender-pair-elder", "kesselford-mender-pair-junior",
]

var _game_state_before_test: Dictionary = {}


func before_test() -> void:
	_game_state_before_test = GameState.to_dict()


func after_test() -> void:
	# chapter_location.gd sets the arrival flag on ready; keep it out of the other suites.
	GameState.from_dict(_game_state_before_test)


func test_scene_carries_the_location_contract() -> void:
	var town: Node2D = auto_free((load(KESSELFORD) as PackedScene).instantiate())
	add_child(town)
	await get_tree().process_frame

	var script := town.get_script() as Script
	assert_str(script.resource_path).is_equal("res://world/chapter_location.gd")
	assert_bool(town.y_sort_enabled).is_true()
	for marker_name: String in [
		"SpawnDefault", "SpawnFromDom", "SpawnFromKesselfordWayhouse",
		"SpawnFromKesselfordChandlery", "SpawnSlotFarBank",
	]:
		assert_object(town.get_node_or_null(marker_name) as Marker2D) \
			.override_failure_message("Kesselford must carry the %s marker." % marker_name) \
			.is_not_null()
	for anchor_name: String in ["FerryStage", "FloodBell", "MenderStone", "WayhouseDoor", "ChandleryDoor"]:
		assert_object(town.find_child(anchor_name, true, false)) \
			.override_failure_message("Kesselford must carry the %s placement anchor." % anchor_name) \
			.is_not_null()

	var exit_node := town.get_node_or_null("RoadToDom") as TravelExit
	assert_object(exit_node).is_not_null()
	if exit_node != null:
		assert_str(exit_node.target_scene).is_equal(DOM)
		assert_str(String(exit_node.spawn_id)).is_equal("from_kesselford")
		assert_object(LocationRegistry.by_scene(exit_node.target_scene)).is_not_null()
	for pair: Array in [["WayhouseDoor", &"kesselford_wayhouse_enter"], ["ChandleryDoor", &"kesselford_chandlery_enter"]]:
		var door := town.get_node_or_null(String(pair[0])) as BuildingDoor
		assert_object(door).is_not_null()
		if door == null:
			continue
		assert_str(String(door.transition_id)).is_equal(String(pair[1]))
		var transition := BuildingTransitionRegistry.by_id(pair[1])
		assert_object(transition).is_not_null()
		if transition != null:
			assert_str(transition.source_scene).is_equal(KESSELFORD)
			assert_str(String(transition.source_anchor)).is_equal(String(pair[0]))
			assert_bool(ResourceLoader.exists(transition.destination_scene)).is_true()

	var dressing := town.get_node_or_null("KesselfordDressing")
	assert_object(dressing).is_not_null()
	if dressing != null:
		for layer_name: String in ["GroundDetails", "SoftDetails", "SolidProps"]:
			var layer := dressing.get_node_or_null(layer_name) as Node2D
			assert_object(layer).is_not_null()
			if layer != null:
				assert_int(layer.get_child_count()).is_greater_equal(1)
	assert_object(town.get_node_or_null("OutdoorTownsfolk") as TownNpcSpawner).is_not_null()


func test_registries_agree_on_kesselford() -> void:
	var location := LocationRegistry.by_id(&"kesselford")
	assert_object(location).is_not_null()
	if location == null:
		return
	assert_str(location.scene_path).is_equal(KESSELFORD)
	assert_str(location.arrival_flag).is_equal("chapter_kesselford_reached")
	assert_bool(location.spawns.has(&"from_dom")).is_true()
	assert_bool(location.spawns.has(&"from_kesselford_wayhouse")).is_true()
	assert_bool(location.spawns.has(&"from_kesselford_chandlery")).is_true()
	assert_bool(LocationRegistry.no_combat_zone_by_scene(KESSELFORD)).is_false()
	assert_bool(LocationRegistry.no_combat_zone_by_scene(WAYHOUSE)).is_true()
	assert_bool(LocationRegistry.DOM.spawns.has(&"from_kesselford")).is_true()

	var hub := FastTravelRegistry.by_id(&"kesselford")
	assert_str(str(hub.get("scene_path", ""))).is_equal(KESSELFORD)
	assert_array(FastTravelRegistry.validate()).is_empty()
	assert_dict(WorldMapRegistry.route_between(&"dom", &"kesselford")).is_not_empty()
	assert_str(str(WorldMapRegistry.location(&"kesselford").get("scene_path", ""))).is_equal(KESSELFORD)

	var town_ids := NpcRoster.town_ids()
	assert_array(town_ids).contains(["dom", "kesselford"])
	var placements := NpcRoster.placements_for_scene(KESSELFORD)
	assert_array(placements.keys()).contains_exactly_in_any_order(OUTDOOR_IDS)
	for npc_id: String in ["kesselford-ferry-keeper", "kesselford-bell-ringer", "kesselford-mender-pair-elder"]:
		assert_str(NpcRoutines.hub_scene(npc_id)).is_equal(KESSELFORD)


func test_dom_carries_the_reverse_exit() -> void:
	var town: Node2D = auto_free((load(DOM) as PackedScene).instantiate())
	add_child(town)
	await get_tree().process_frame
	assert_object(town.get_node_or_null("SpawnFromKesselford") as Marker2D).is_not_null()
	var exit_node := town.get_node_or_null("FordRoad") as TravelExit
	assert_object(exit_node).is_not_null()
	if exit_node == null:
		return
	assert_str(exit_node.target_scene).is_equal(KESSELFORD)
	assert_str(String(exit_node.spawn_id)).is_equal("from_dom")
	assert_array(exit_node.required_flags).contains(["tutorial_road_open", "chapter_one_free_roam"])


func test_townsfolk_spawn_from_the_kesselford_roster_at_their_anchors() -> void:
	var runner := scene_runner(KESSELFORD)
	await runner.simulate_frames(5)
	var town: Node2D = runner.scene()
	var spawned: Array[Node] = []
	_collect_group_members(town, &"generated_townsfolk", spawned)
	assert_int(spawned.size()) \
		.override_failure_message("Kesselford's four outdoor townsfolk must spawn from its roster.") \
		.is_equal(OUTDOOR_IDS.size())
	var placements := NpcRoster.placements_for_scene(KESSELFORD)
	var seen: Array[String] = []
	for node: Node in spawned:
		var npc := node as NPC
		assert_object(npc).is_not_null()
		if npc == null:
			continue
		# Generated townsfolk carry their roster id as metadata (see TownNpcSpawner).
		var npc_id := str(npc.get_meta(&"npc_id", ""))
		seen.append(npc_id)
		# C25 (#262): the authored location file wins per title, the generated one is the fallback.
		assert_str(npc.dialogue_path).is_equal(
			NpcRoster.dialogue_route("kesselford", "res://dialogue/kesselford_townsfolk.dialogue", npc.dialogue_start)
		)
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
	var runner := scene_runner(KESSELFORD)
	await runner.simulate_frames(5)
	var player: Node2D = runner.find_child("Player", true, false)
	var npc: Node2D = runner.find_child("KesselfordMenderPairElder", true, false)
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
	var runner := scene_runner(KESSELFORD)
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


func test_interiors_populate_from_the_kesselford_roster() -> void:
	var wayhouse: Node2D = auto_free((load(WAYHOUSE) as PackedScene).instantiate())
	add_child(wayhouse)
	await get_tree().process_frame
	var room := wayhouse.get_node_or_null("Room") as BuildingInterior
	assert_object(room).is_not_null()
	if room == null:
		return
	assert_str(String(room.exit_transition_id)).is_equal("kesselford_wayhouse_exit")
	var exit_transition := BuildingTransitionRegistry.by_id(&"kesselford_wayhouse_exit")
	assert_object(exit_transition).is_not_null()
	if exit_transition != null:
		assert_str(exit_transition.destination_scene).is_equal(KESSELFORD)
		assert_str(String(exit_transition.spawn_id)).is_equal("from_kesselford_wayhouse")
		assert_object(room.get_node_or_null(NodePath(String(exit_transition.source_anchor).trim_prefix("Room/")))) \
			.is_not_null()
	var indoor: Array[String] = []
	for node: Node in room.find_children("*", "NPC", true, false):
		var npc := node as NPC
		if npc != null and npc.npc_id.begins_with("kesselford-"):
			indoor.append(npc.npc_id)
	assert_array(indoor).contains_exactly_in_any_order(["kesselford-wayhouse-keeper", "kesselford-grain-factor"])

	var chandlery: Node2D = auto_free((load(CHANDLERY) as PackedScene).instantiate())
	add_child(chandlery)
	await get_tree().process_frame
	var shop := chandlery.get_node_or_null("Room") as BuildingInterior
	assert_object(shop).is_not_null()
	if shop == null:
		return
	assert_str(String(shop.exit_transition_id)).is_equal("kesselford_chandlery_exit")
	var vendors: Array[String] = []
	for node: Node in shop.find_children("*", "NPC", true, false):
		var npc := node as NPC
		if npc != null and not npc.vendor_id.is_empty():
			vendors.append(npc.vendor_id)
	assert_array(vendors).contains_exactly(["ford-chandlery"])


func _collect_group_members(node: Node, group: StringName, found: Array[Node]) -> void:
	if node.is_in_group(group):
		found.append(node)
	for child: Node in node.get_children():
		_collect_group_members(child, group, found)
