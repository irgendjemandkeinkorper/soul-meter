extends GdUnitTestSuite

const BuildingDoorScene := preload("res://actors/building_door/building_door.tscn")
const BuildingInteriorScene := preload("res://world/interiors/building_interior.tscn")
const PlayerScene := preload("res://actors/player/player.tscn")
const SaveGameScript := preload("res://globals/save_game.gd")
const FLOOR_TEXTURE_PATH := "res://assets/generated/sprites/world/dom-interior-floor--wood-panel.png"
const WALL_TEXTURE_PATH := "res://assets/generated/sprites/world/dom-interior-wall--brick.png"

var _game_state_before: Dictionary = {}
var _reputation_before: Dictionary = {}
var _renown_before: Dictionary = {}
var _quests_before: Dictionary = {}
var _target_scene_before := ""
var _target_spawn_before: StringName = &"default"
var _pending_position_before := Vector2.ZERO
var _has_pending_position_before := false
var _pending_spawn_before: StringName = &"default"
var _current_scene_before: Node
var _test_save_paths: Array[String] = []


func before_test() -> void:
	_game_state_before = GameState.to_dict()
	_reputation_before = Reputation.to_dict()
	_renown_before = Renown.to_dict()
	_quests_before = QuestRegistry.to_dict()
	_target_scene_before = GameFlow._target_scene
	_target_spawn_before = GameFlow._target_spawn_id
	_pending_position_before = SaveGame.pending_player_position
	_has_pending_position_before = SaveGame.has_pending_player_position
	_pending_spawn_before = SaveGame.pending_spawn_id
	_current_scene_before = get_tree().current_scene
	_test_save_paths.clear()
	SaveGame.has_pending_player_position = false
	SaveGame.pending_spawn_id = &"default"


func after_test() -> void:
	if get_tree().current_scene != _current_scene_before:
		get_tree().current_scene = _current_scene_before
	_remove_test_saves()
	GameState.from_dict(_game_state_before)
	Reputation.from_dict(_reputation_before)
	Renown.from_dict(_renown_before)
	QuestRegistry.from_dict(_quests_before)
	GameFlow._target_scene = _target_scene_before
	GameFlow._target_spawn_id = _target_spawn_before
	SaveGame.pending_player_position = _pending_position_before
	SaveGame.has_pending_player_position = _has_pending_position_before
	SaveGame.pending_spawn_id = _pending_spawn_before


func test_shared_interior_keeps_contract_and_loads_palette_modulated_textures() -> void:
	for texture_path: String in [FLOOR_TEXTURE_PATH, WALL_TEXTURE_PATH]:
		var exists_for_export := (
			ResourceLoader.exists(texture_path) or FileAccess.file_exists(texture_path)
		)
		assert_bool(exists_for_export) \
			.override_failure_message("Interior texture is missing: %s" % texture_path) \
			.is_true()
		var loaded_texture := load(texture_path) as Texture2D if exists_for_export else null
		assert_object(loaded_texture) \
			.override_failure_message("Interior texture does not load as Texture2D: %s" % texture_path) \
			.is_not_null()

	var interior := auto_free(BuildingInteriorScene.instantiate()) as BuildingInterior
	interior.exit_transition_id = &"registry_archive_exit"
	add_child(interior)
	assert_object(interior.get_node_or_null("Player")).is_not_null()
	assert_object(interior.get_node_or_null("ExitDoor")).is_not_null()
	assert_object(interior.get_node_or_null("FieldHUD")).is_not_null()

	var floor := interior.get_node_or_null("Floor") as Polygon2D
	assert_object(floor).is_not_null()
	if floor != null:
		assert_object(floor.texture).is_not_null()
		if floor.texture != null:
			assert_str(floor.texture.resource_path).is_equal(FLOOR_TEXTURE_PATH)
		assert_int(floor.texture_repeat).is_equal(CanvasItem.TEXTURE_REPEAT_ENABLED)
		assert_object(floor.color).is_equal(interior.floor_color)

	for wall_name: String in ["WallTop", "WallBottom", "WallLeft", "WallRight"]:
		var wall := interior.get_node_or_null(wall_name) as Polygon2D
		assert_object(wall) \
			.override_failure_message("Shared interior is missing textured node %s." % wall_name) \
			.is_not_null()
		if wall == null:
			continue
		assert_object(wall.texture).is_not_null()
		if wall.texture != null:
			assert_str(wall.texture.resource_path).is_equal(WALL_TEXTURE_PATH)
		assert_int(wall.texture_repeat).is_equal(CanvasItem.TEXTURE_REPEAT_ENABLED)
		assert_object(wall.color).is_equal(interior.accent_color)


func test_all_registered_interiors_load_with_collision_spawns_exit_and_placement_markers() -> void:
	var saves = auto_free(SaveGameScript.new())
	var diagnostics: Array[String] = []
	saves.spawn_marker_diagnostic.connect(
		func(severity: String, marker_name: String, scene_path: String) -> void:
			diagnostics.append("%s:%s:%s" % [severity, marker_name, scene_path])
	)
	for entry: BuildingTransitionDefinition in BuildingTransitionRegistry.ENTRIES:
		var packed := load(entry.destination_scene) as PackedScene
		assert_object(packed).is_not_null()
		var interior := auto_free(packed.instantiate()) as Node2D
		add_child(interior)
		var player := interior.find_child("Player", true, false) as Player
		var spawn_default := interior.find_child("SpawnDefault", true, false) as Marker2D
		var spawn_entry := interior.find_child("SpawnEntry", true, false) as Marker2D
		var exit_door := interior.find_child("ExitDoor", true, false) as BuildingDoor
		var door_sprite := exit_door.get_node("DoorSprite") as Sprite2D
		var walls := interior.find_child("Walls", true, false)
		assert_object(player).is_not_null()
		assert_object(spawn_default).is_not_null()
		assert_object(spawn_entry).is_not_null()
		assert_object(exit_door).is_not_null()
		assert_object(walls).is_not_null()
		assert_object(interior.find_child("VendorSpot", true, false)).is_not_null()
		assert_object(interior.find_child("NpcSpot", true, false)).is_not_null()
		assert_int(_valid_collision_shape_count(walls)).is_equal(4)
		assert_str(exit_door.transition_id).is_equal(
			String(BuildingTransitionRegistry.exit_for(entry.building_id).id)
		)
		assert_vector(spawn_entry.global_position).is_equal(entry.destination_spawn_position)
		assert_float(spawn_entry.global_position.y).is_less(door_sprite.global_position.y - 24.0)
		diagnostics.clear()
		saves.has_pending_player_position = false
		saves.pending_spawn_id = entry.spawn_id
		saves.apply_pending_location(interior)
		assert_array(diagnostics).is_empty()
		assert_vector(player.global_position).is_equal(spawn_entry.global_position)


func test_interior_backdrop_covers_full_hd_without_changing_gameplay_scale() -> void:
	var runner := scene_runner("res://world/interiors/registry_archive.tscn")
	var player := runner.find_child("Player", true, false) as Player
	var camera := player.get_node("Camera2D") as Camera2D
	var backdrop := runner.find_child("Backdrop", true, false) as Polygon2D
	var viewport_size := Vector2(
		float(ProjectSettings.get_setting("display/window/size/viewport_width")),
		float(ProjectSettings.get_setting("display/window/size/viewport_height")),
	)
	var visible_world_size := viewport_size / camera.zoom
	var room_center := Vector2(player.camera_bounds.get_center())
	var backdrop_bounds := _polygon_bounds(backdrop.polygon)

	assert_vector(camera.zoom).is_equal(Vector2.ONE)
	assert_float(backdrop_bounds.position.x).is_less_equal(
		room_center.x - visible_world_size.x * 0.5
	)
	assert_float(backdrop_bounds.position.y).is_less_equal(
		room_center.y - visible_world_size.y * 0.5
	)
	assert_float(backdrop_bounds.end.x).is_greater_equal(
		room_center.x + visible_world_size.x * 0.5
	)
	assert_float(backdrop_bounds.end.y).is_greater_equal(
		room_center.y + visible_world_size.y * 0.5
	)


func test_interior_collision_prevents_the_player_from_leaving_through_a_wall() -> void:
	var runner := scene_runner("res://world/interiors/registry_archive.tscn")
	var player := runner.find_child("Player", true, false) as Player
	var start_y: float = player.global_position.y
	runner.simulate_action_press("move_down")
	await runner.simulate_frames(90)
	runner.simulate_action_release("move_down")
	assert_float(player.global_position.y).is_greater(start_y)
	assert_float(player.global_position.y).is_less(600.0)


func test_registry_archive_round_trip_returns_to_its_matching_town_spawn() -> void:
	_round_trip(&"registry_archive")


func test_players_house_round_trip_returns_to_its_matching_town_spawn() -> void:
	_round_trip(&"players_house")


func test_item_shop_round_trip_returns_to_its_matching_town_spawn() -> void:
	_round_trip(&"item_shop")


func test_bell_house_stays_locked_until_its_existing_quest_flag_then_round_trips() -> void:
	GameState.flags.erase("dom_bell_quest_open")
	var original_target: String = GameFlow._target_scene
	var door := _make_door(&"bell_house_enter")
	var player := auto_free(PlayerScene.instantiate()) as Player
	door._on_body(player, true)
	assert_bool(door._is_unlocked()).is_false()
	assert_bool(door._try_travel()).is_false()
	assert_str(GameFlow._target_scene).is_equal(original_target)
	GameState.set_flag("dom_bell_quest_open", true)
	assert_bool(door._is_unlocked()).is_true()
	_round_trip(&"bell_house")


func test_cask_warehouse_stays_locked_until_the_casks_are_traced_then_round_trips() -> void:
	GameState.flags.erase("dom_dishonest_casks_traced")
	var entry := BuildingTransitionRegistry.entry_for(&"cask_warehouse")
	var source := _make_scene(entry.source_scene)
	var door := _find_transition_door(source, entry.id)
	var player := source.find_child("Player", true, false) as Player
	var original_target: String = GameFlow._target_scene
	door._on_body(player, true)
	assert_bool(door._is_unlocked()).is_false()
	assert_bool(door._try_travel()).is_false()
	assert_str(GameFlow._target_scene).is_equal(original_target)
	GameState.set_flag("dom_dishonest_casks_traced", true)
	assert_bool(door._is_unlocked()).is_true()
	_round_trip(&"cask_warehouse")


func test_garrison_yard_stays_locked_until_iron_companies_standing_is_warm() -> void:
	Reputation.from_dict({})
	var entry := BuildingTransitionRegistry.entry_for(&"garrison_yard")
	var source := _make_scene(entry.source_scene)
	var door := _find_transition_door(source, entry.id)
	var player := source.find_child("Player", true, false) as Player
	var original_target: String = GameFlow._target_scene
	door._on_body(player, true)
	assert_bool(door._is_unlocked()).is_false()
	assert_bool(door._try_travel()).is_false()
	assert_str(GameFlow._target_scene).is_equal(original_target)
	Reputation.record("player", "iron-companies", 15.0, "test gate", "dom")
	assert_bool(door._is_unlocked()).is_true()
	_round_trip(&"garrison_yard")


func test_starting_town_wires_all_ten_registry_entries_and_return_spawns() -> void:
	var town := _make_town()
	var town_entries := BuildingTransitionRegistry.entries_from(GameFlow.TOWN_SCENE)
	var entrance_count := 0
	for child: Node in town.get_children():
		var candidate := child as BuildingDoor
		if candidate != null and String(candidate.transition_id).ends_with("_enter"):
			entrance_count += 1
	assert_int(town_entries.size()).is_equal(10)
	assert_int(entrance_count).is_equal(town_entries.size())

	for entry: BuildingTransitionDefinition in town_entries:
		var door := _find_transition_door(town, entry.id)
		var anchor := town.find_child(String(entry.source_anchor), true, false)
		var exit := BuildingTransitionRegistry.exit_for(entry.building_id)
		var marker := town.find_child(_spawn_marker_name(exit.spawn_id), true, false) as Marker2D
		assert_object(door).is_not_null()
		assert_object(anchor).is_not_null()
		assert_vector(door.position).is_equal(entry.source_position)
		assert_object(marker).is_not_null()
		assert_vector(marker.position).is_equal(exit.destination_spawn_position)


func test_all_ten_wired_town_doors_complete_a_real_scene_round_trip() -> void:
	GameState.set_flag("dom_bell_quest_open", true)
	for entry: BuildingTransitionDefinition in BuildingTransitionRegistry.entries_from(
		GameFlow.TOWN_SCENE
	):
		_round_trip(entry.building_id)


func test_all_ten_additional_transitions_complete_a_real_scene_round_trip() -> void:
	GameState.set_flag("dom_dishonest_casks_traced", true)
	GameState.set_flag("deep_trial_open", true)
	Reputation.from_dict({})
	Reputation.record("player", "iron-companies", 15.0, "test gate", "dom")
	var round_trip_count := 0
	for entry: BuildingTransitionDefinition in BuildingTransitionRegistry.ENTRIES:
		if entry.source_scene == GameFlow.TOWN_SCENE:
			continue
		_round_trip(entry.building_id)
		round_trip_count += 1
	assert_int(round_trip_count).is_equal(10)


func test_starting_town_hides_debug_markers_behind_rendered_props() -> void:
	var town := _make_town()
	var interactable_count := 0
	for child: Node in town.get_children():
		var interactable := child as SMInteractable
		if interactable == null:
			continue
		interactable_count += 1
		var marker := interactable.get_node("Marker") as CanvasItem
		var accent := interactable.get_node("Accent") as CanvasItem
		assert_bool(marker.visible).is_false()
		assert_bool(accent.visible).is_false()
	assert_int(interactable_count).is_equal(10)

	for sprite_name in [
		"NoticeBoardSprite",
		"BellInspectionLantern",
		"RiverShrineLantern",
		"ItemShopBench",
		"EquipmentShopBanner",
		"GarrisonBanner",
		"TownHallBanner",
		"ChefsHousePot",
		"PlayersHouseLantern",
		"SavePointLantern",
	]:
		var prop := town.find_child(sprite_name, true, false) as Sprite2D
		assert_object(prop).is_not_null()
		assert_object(prop.texture).is_not_null()

	for entry: BuildingTransitionDefinition in BuildingTransitionRegistry.entries_from(
		GameFlow.TOWN_SCENE
	):
		var door := _find_transition_door(town, entry.id)
		var panel := door.get_node("DoorPanel") as CanvasItem
		var threshold := door.get_node("Threshold") as CanvasItem
		assert_bool(panel.visible).is_false()
		assert_bool(threshold.visible).is_false()
		# The painterly facade art draws its own door, so there's no separate
		# placeholder door sprite to hide behind any more (removed alongside
		# the Dom revamp wave-2 art) — verify the facade itself is present
		# and textured instead.
		var building_node := town.find_child(String(entry.source_anchor), true, false)
		assert_object(building_node).is_not_null()
		var facade := building_node.find_child("Facade", true, false) as Sprite2D
		assert_object(facade).is_not_null()
		assert_object(facade.texture).is_not_null()


func test_direct_door_supports_a_minimum_reputation_band_gate() -> void:
	Reputation.from_dict({})
	var door := auto_free(BuildingDoorScene.instantiate()) as BuildingDoor
	door.destination_scene = GameFlow.TOWN_SCENE
	door.destination_location_id = &"dom"
	door.reputation_faction = "mirror-choir"
	door.minimum_reputation_band = &"warm"
	add_child(door)
	assert_bool(door._is_unlocked()).is_false()
	Reputation.record("player", "mirror-choir", 15.0, "test gate", "test")
	assert_bool(door._is_unlocked()).is_true()


func test_save_load_inside_an_interior_restores_scene_and_player_position() -> void:
	var entry := BuildingTransitionRegistry.entry_for(&"registry_stacks")
	var packed := load(entry.destination_scene) as PackedScene
	var interior := auto_free(packed.instantiate()) as Node2D
	get_tree().root.add_child(interior)
	get_tree().current_scene = interior
	var player := interior.find_child("Player", true, false) as Player
	var saved_position := Vector2(612, 442)
	player.global_position = saved_position
	GameFlow._target_scene = entry.destination_scene
	GameFlow._target_spawn_id = entry.spawn_id

	var saves = auto_free(SaveGameScript.new())
	add_child(saves)
	_configure_test_paths(saves)
	# SaveGame no longer writes GameFlow's private target state; it emits a
	# LoadDestination that GameFlow resolves. The autoload wires this in _ready(),
	# so a detached instance must mirror that wiring to exercise the same path.
	saves.load_requested.connect(GameFlow.load_destination)
	assert_bool(saves.save()).is_true()
	GameFlow._target_scene = GameFlow.TOWN_SCENE
	GameFlow._target_spawn_id = &"default"
	player.global_position = Vector2.ZERO
	assert_bool(saves.load_save()).is_true()
	assert_str(GameFlow._target_scene).is_equal(entry.destination_scene)
	assert_str(GameFlow._target_spawn_id).is_equal(String(entry.spawn_id))
	assert_bool(saves.has_pending_player_position).is_true()

	var restored := auto_free(packed.instantiate()) as Node2D
	add_child(restored)
	var restored_player := restored.find_child("Player", true, false) as Player
	saves.apply_pending_location(restored)
	assert_vector(restored_player.global_position).is_equal(saved_position)


func _round_trip(building_id: StringName) -> void:
	var entry := BuildingTransitionRegistry.entry_for(building_id)
	var exit := BuildingTransitionRegistry.exit_for(building_id)
	var source := _make_scene(entry.source_scene)
	var door := _find_transition_door(source, entry.id)
	var player := source.find_child("Player", true, false) as Player
	assert_vector(door.position).is_equal(entry.source_position)
	door._on_body(player, true)
	assert_bool(door._try_travel()).is_true()
	assert_str(GameFlow._target_scene).is_equal(entry.destination_scene)
	assert_str(GameFlow._target_spawn_id).is_equal(String(entry.spawn_id))
	assert_str(SaveGame.pending_spawn_id).is_equal(String(entry.spawn_id))

	var packed := load(entry.destination_scene) as PackedScene
	var interior := auto_free(packed.instantiate()) as Node2D
	add_child(interior)
	SaveGame.apply_pending_location(interior)
	var interior_player := interior.find_child("Player", true, false) as Player
	var entry_marker := interior.find_child("SpawnEntry", true, false) as Marker2D
	assert_vector(interior_player.global_position).is_equal(entry_marker.global_position)
	var exit_door := interior.find_child("ExitDoor", true, false) as BuildingDoor
	exit_door._on_body(interior_player, true)
	assert_bool(exit_door._try_travel()).is_true()
	assert_str(GameFlow._target_scene).is_equal(exit.destination_scene)
	assert_str(GameFlow._target_spawn_id).is_equal(String(exit.spawn_id))

	var source_player := source.find_child("Player", true, false) as Player
	var return_marker := source.find_child(
		_spawn_marker_name(exit.spawn_id), true, false
	) as Marker2D
	assert_object(return_marker).is_not_null()
	assert_vector(return_marker.position).is_equal(exit.destination_spawn_position)
	SaveGame.apply_pending_location(source)
	assert_vector(source_player.global_position).is_equal(return_marker.global_position)


func _make_town() -> Node2D:
	return _make_scene(GameFlow.TOWN_SCENE)


func _make_scene(scene_path: String) -> Node2D:
	var packed := load(scene_path) as PackedScene
	assert_object(packed).is_not_null()
	var scene := auto_free(packed.instantiate()) as Node2D
	add_child(scene)
	return scene


func _find_transition_door(scene: Node, transition_id: StringName) -> BuildingDoor:
	for child: Node in scene.find_children("*", "", true, false):
		var door := child as BuildingDoor
		if door != null and door.transition_id == transition_id:
			return door
	fail("no BuildingDoor with transition id '%s'" % transition_id)
	return null


func _make_door(transition_id: StringName) -> BuildingDoor:
	var door := auto_free(BuildingDoorScene.instantiate()) as BuildingDoor
	door.transition_id = transition_id
	add_child(door)
	return door


func _polygon_bounds(points: PackedVector2Array) -> Rect2:
	if points.is_empty():
		return Rect2()
	var minimum := points[0]
	var maximum := points[0]
	for point: Vector2 in points:
		minimum.x = minf(minimum.x, point.x)
		minimum.y = minf(minimum.y, point.y)
		maximum.x = maxf(maximum.x, point.x)
		maximum.y = maxf(maximum.y, point.y)
	return Rect2(minimum, maximum - minimum)


func _valid_collision_shape_count(walls: Node) -> int:
	var count := 0
	for child: Node in walls.get_children():
		var shape := child as CollisionShape2D
		if shape != null and not shape.disabled and shape.shape != null:
			count += 1
	return count


func _spawn_marker_name(spawn_id: StringName) -> String:
	var result := "Spawn"
	for part: String in String(spawn_id).replace("-", "_").split("_", false):
		result += part.capitalize().replace(" ", "")
	return result


func _configure_test_paths(saves: Node) -> void:
	var prefix := OS.get_temp_dir().path_join(
		"soul-meter-building-save-%s" % Time.get_ticks_usec()
	)
	saves.save_path = prefix + ".save"
	saves.temp_path = prefix + ".save.tmp"
	saves.backup_path = prefix + ".save.bak"
	_test_save_paths = [saves.save_path, saves.temp_path, saves.backup_path]
	_remove_test_saves()


func _remove_test_saves() -> void:
	for path: String in _test_save_paths:
		if FileAccess.file_exists(path):
			DirAccess.remove_absolute(ProjectSettings.globalize_path(path))
