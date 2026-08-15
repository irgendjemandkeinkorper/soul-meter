extends GdUnitTestSuite

const SaveGameScript := preload("res://globals/save_game.gd")
const TavernDoorScene := preload("res://actors/tavern_door/tavern_door.tscn")
const TavernInteriorScene := preload("res://world/interiors/dom_tavern.tscn")
const PlayerScene := preload("res://actors/player/player.tscn")

var _game_state_before: Dictionary
var _target_scene_before: String
var _target_spawn_before: StringName
var _current_scene_before: Node
var _test_save_paths: Array[String] = []


func before_test() -> void:
	_game_state_before = GameState.to_dict()
	_target_scene_before = GameFlow._target_scene
	_target_spawn_before = GameFlow._target_spawn_id
	_current_scene_before = get_tree().current_scene
	UIManager.close_all()
	get_tree().paused = false


func after_test() -> void:
	UIManager.close_all()
	get_tree().paused = false
	if get_tree().current_scene != _current_scene_before:
		get_tree().current_scene = _current_scene_before
	for path: String in _test_save_paths:
		if FileAccess.file_exists(path):
			DirAccess.remove_absolute(ProjectSettings.globalize_path(path))
	GameState.from_dict(_game_state_before)
	GameFlow._target_scene = _target_scene_before
	GameFlow._target_spawn_id = _target_spawn_before


func test_tavern_door_counter_party_picker_and_exit_complete_the_round_trip() -> void:
	assert_array(GameFlow.GAMEPLAY_SCENES).contains([GameFlow.TAVERN_SCENE])
	var door := auto_free(TavernDoorScene.instantiate()) as TavernDoor
	var town_player := auto_free(PlayerScene.instantiate()) as Player
	add_child(door)
	add_child(town_player)
	door._on_body(town_player, true)
	assert_bool(door._try_travel()).is_true()
	assert_str(GameFlow._target_scene).is_equal(GameFlow.TAVERN_SCENE)
	assert_str(GameFlow._target_spawn_id).is_equal("entry")

	var interior := auto_free(TavernInteriorScene.instantiate()) as DomTavern
	add_child(interior)
	SaveGame.apply_pending_location(interior)
	var interior_player := interior.get_node("Player") as Player
	assert_vector(interior_player.position).is_equal(
		(interior.get_node("SpawnEntry") as Marker2D).position
	)

	interior._on_counter_body(interior_player, true)
	var picker := interior._try_open_picker()
	assert_object(picker).is_not_null()
	assert_str(picker.scene_file_path).is_equal("res://ui/screens/tavern.tscn")

	var chosen_ids: Array[String] = []
	for index: int in picker._checks.size():
		var check := picker._checks[index] as CheckBox
		if not check.disabled and chosen_ids.size() < 2:
			check.set_pressed_no_signal(true)
			chosen_ids.append(picker._candidates[index].id)
	assert_int(chosen_ids.size()).is_equal(2)
	picker._on_confirm()
	assert_array(GameState.companions().map(func(member: PartyMember) -> String: return member.id)).contains_exactly(chosen_ids)

	interior._on_exit_body_entered(interior_player)
	assert_str(GameFlow._target_scene).is_equal(GameFlow.TOWN_SCENE)
	assert_str(GameFlow._target_spawn_id).is_equal("from_tavern")
	var town := auto_free((load(GameFlow.TOWN_SCENE) as PackedScene).instantiate()) as Node2D
	add_child(town)
	SaveGame.apply_pending_location(town)
	assert_vector((town.find_child("Player") as Player).position).is_equal(
		(town.find_child("SpawnFromTavern") as Marker2D).position
	)
	assert_array(GameState.companions().map(func(member: PartyMember) -> String: return member.id)).contains_exactly(chosen_ids)


func test_save_load_inside_tavern_restores_scene_and_player_position() -> void:
	var interior := auto_free(TavernInteriorScene.instantiate()) as DomTavern
	get_tree().root.add_child(interior)
	get_tree().current_scene = interior
	var player := interior.get_node("Player") as Player
	var saved_position := Vector2(604, 438)
	player.position = saved_position

	var saves: Variant = auto_free(SaveGameScript.new())
	add_child(saves)
	_configure_test_paths(saves)
	saves.load_requested.connect(GameFlow.load_destination)
	assert_bool(saves._in_gameplay_scene()).is_true()
	assert_bool(saves.save()).is_true()
	GameFlow._target_scene = GameFlow.TOWN_SCENE
	assert_bool(saves.load_save()).is_true()
	assert_str(GameFlow._target_scene).is_equal(GameFlow.TAVERN_SCENE)
	assert_bool(saves.has_pending_player_position).is_true()

	var restored := auto_free(TavernInteriorScene.instantiate()) as DomTavern
	add_child(restored)
	saves.apply_pending_location(restored)
	assert_vector((restored.get_node("Player") as Player).position).is_equal(saved_position)


func _configure_test_paths(saves: Node) -> void:
	var stem := "user://test_tavern_interior_%s" % str(Time.get_ticks_usec())
	saves.save_path = stem + ".save"
	saves.temp_path = stem + ".tmp"
	saves.backup_path = stem + ".bak"
	_test_save_paths.append_array([saves.save_path, saves.temp_path, saves.backup_path])
