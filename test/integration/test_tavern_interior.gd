extends GdUnitTestSuite

const SaveGameScript := preload("res://globals/save_game.gd")
const TavernDoorScene := preload("res://actors/tavern_door/tavern_door.tscn")
const TavernInteriorScene := preload("res://world/interiors/dom_tavern.tscn")
const PlayerScene := preload("res://actors/player/player.tscn")
const AMBIENT_VILLAGER_GROUP := &"ambient_villager"
const PATRON_FRAME_BUDGET := 360

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


func test_ambient_patrons_remain_inside_their_authored_bounds() -> void:
	var runner := scene_runner("res://world/interiors/dom_tavern.tscn")
	await runner.simulate_frames(2)
	var patrons_root := runner.find_child("AmbientPatrons", true, false)
	assert_object(patrons_root).is_not_null()
	var patrons: Array[Node] = []
	if patrons_root != null:
		for child: Node in patrons_root.get_children():
			if child.is_in_group(AMBIENT_VILLAGER_GROUP):
				patrons.append(child)
	assert_int(patrons.size()) \
		.override_failure_message("The tavern must contain 2-4 ambient patrons.") \
		.is_between(2, 4)

	var observations: Array[Dictionary] = []
	for patron_node: Node in patrons:
		var patron := patron_node as Node2D
		var has_bounds_method := patron != null and patron.has_method("authored_world_bounds")
		assert_bool(has_bounds_method) \
			.override_failure_message("Tavern patron %s must expose authored bounds." % patron_node.name) \
			.is_true()
		var bounds := Rect2()
		if has_bounds_method:
			bounds = patron.call("authored_world_bounds") as Rect2
		observations.append({
			"patron": patron,
			"bounds": bounds.grow(1.0),
			"remained_in_bounds": has_bounds_method and bounds.grow(1.0).has_point(patron.position),
		})

	for _frame_index: int in range(PATRON_FRAME_BUDGET):
		await runner.simulate_frames(1)
		for observation: Dictionary in observations:
			var patron: Node2D = observation["patron"] as Node2D
			if not bool(observation["remained_in_bounds"]):
				continue
			observation["remained_in_bounds"] = (
				is_instance_valid(patron)
				and (observation["bounds"] as Rect2).has_point(patron.position)
			)

	# gdUnit assertions do not abort, so every patron gets a final assertion.
	var all_patrons_remained_in_bounds := not observations.is_empty()
	for observation: Dictionary in observations:
		var patron: Node2D = observation["patron"] as Node2D
		var patron_name := String(patron.name) if is_instance_valid(patron) else "freed patron"
		var remained_in_bounds := bool(observation["remained_in_bounds"])
		all_patrons_remained_in_bounds = all_patrons_remained_in_bounds and remained_in_bounds
		assert_bool(remained_in_bounds) \
			.override_failure_message(
				"%s left its authored bounds within %d simulated frames."
				% [patron_name, PATRON_FRAME_BUDGET]
			) \
			.is_true()
	assert_bool(all_patrons_remained_in_bounds).is_true()


func _configure_test_paths(saves: Node) -> void:
	var stem := "user://test_tavern_interior_%s" % str(Time.get_ticks_usec())
	saves.save_path = stem + ".save"
	saves.temp_path = stem + ".tmp"
	saves.backup_path = stem + ".bak"
	_test_save_paths.append_array([saves.save_path, saves.temp_path, saves.backup_path])
