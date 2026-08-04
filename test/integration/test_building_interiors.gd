extends GdUnitTestSuite

const BuildingDoorScene := preload("res://actors/building_door/building_door.tscn")
const PlayerScene := preload("res://actors/player/player.tscn")
const SaveGameScript := preload("res://globals/save_game.gd")

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


func test_all_ten_interiors_load_with_collision_spawns_exit_and_placement_markers() -> void:
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
		diagnostics.clear()
		saves.has_pending_player_position = false
		saves.pending_spawn_id = entry.spawn_id
		saves.apply_pending_location(interior)
		assert_array(diagnostics).is_empty()
		assert_vector(player.global_position).is_equal(spawn_entry.global_position)


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
	var entry := BuildingTransitionRegistry.entry_for(&"registry_archive")
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
	var door := _make_door(entry.id)
	var player := auto_free(PlayerScene.instantiate()) as Player
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
	assert_str(GameFlow._target_scene).is_equal(GameFlow.TOWN_SCENE)
	assert_str(GameFlow._target_spawn_id).is_equal(String(exit.spawn_id))

	var town: Node2D = auto_free(Node2D.new())
	town.name = "ProgrammaticTown"
	var town_player := PlayerScene.instantiate() as Player
	town_player.name = "Player"
	town.add_child(town_player)
	var default_marker := Marker2D.new()
	default_marker.name = "SpawnDefault"
	default_marker.position = Vector2(80, 80)
	town.add_child(default_marker)
	var return_marker := Marker2D.new()
	return_marker.name = _spawn_marker_name(exit.spawn_id)
	return_marker.position = exit.destination_spawn_position
	town.add_child(return_marker)
	SaveGame.apply_pending_location(town)
	assert_vector(town_player.global_position).is_equal(exit.destination_spawn_position)


func _make_door(transition_id: StringName) -> BuildingDoor:
	var door := auto_free(BuildingDoorScene.instantiate()) as BuildingDoor
	door.transition_id = transition_id
	add_child(door)
	return door


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
