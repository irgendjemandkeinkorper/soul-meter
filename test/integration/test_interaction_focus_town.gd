extends GdUnitTestSuite
## #665: Dom's townsfolk and signs sit over five building thresholds (the Town Hall, Bell House,
## Registry Archive, Equipment Shop, Trial Hall). Before InteractionFocus, the later node in the
## tree took E there, so the player read the ledger or greeted a townsperson and the door never
## opened; no spot inside the Town Hall's range was clear.

const TOWN_SCENE_PATH := "res://world/starting_town.tscn"
const BALLOON_SCRIPT := "res://ui/dialogue/dialogue_balloon.gd"
## Keeps the Town Hall door from travelling, so the test reads where E went without a scene change.
const HELD_GATE := "test_interaction_focus_held_gate"

var _game_state_before: Dictionary = {}
var _reputation_before: Dictionary = {}
var _zhavar_before: Dictionary = {}


func before_test() -> void:
	# The townsfolk suite's quiet world: no rumor or band rewiring of who stands where.
	_game_state_before = GameState.to_dict().duplicate(true)
	_reputation_before = Reputation.to_dict().duplicate(true)
	_zhavar_before = SaveGame.zhavar.duplicate(true)
	SaveGame.zhavar.clear()
	Reputation.from_dict({})
	InteractionFocus._in_range.clear()


func after_test() -> void:
	for balloon: Node in _balloons():
		balloon.queue_free()
	get_tree().paused = false
	InteractionFocus._in_range.clear()
	GameState.from_dict(_game_state_before)
	Reputation.from_dict(_reputation_before)
	SaveGame.zhavar = _zhavar_before.duplicate(true)


func test_every_dom_door_takes_interact_from_its_centre_and_hides_rival_prompts() -> void:
	var runner := scene_runner(TOWN_SCENE_PATH)
	await runner.simulate_frames(3)
	var town := runner.scene()
	var player := town.find_child("Player", true, false) as Player
	var doors: Array[Node] = town.find_children("*", "BuildingDoor", true, false)
	doors.append_array(town.find_children("*", "TavernDoor", true, false))
	assert_int(doors.size()).is_greater_equal(8)
	var rivals_seen := 0
	var failures := PackedStringArray()
	for node: Node in doors:
		var door := node as Node2D
		player.global_position = door.global_position
		await _physics(6)
		if not bool(door.get("_player_in_range")) or not InteractionFocus.takes_interact(door):
			failures.append("%s does not take E from its own centre" % door.name)
		for rival: Node2D in _world_targets(town):
			if not bool(rival.get("_player_in_range")):
				continue
			rivals_seen += 1
			if InteractionFocus.takes_interact(rival):
				failures.append("%s takes E on %s's threshold" % [rival.name, door.name])
			if (rival.get("_prompt") as Label).visible:
				failures.append("%s shows its prompt on %s's threshold" % [rival.name, door.name])
	assert_array(failures).is_empty()
	# The overlap this guards is real in the shipped town (TownHallEntrance alone has five).
	assert_int(rivals_seen).is_greater_equal(5)


func test_e_on_the_town_hall_threshold_reaches_the_door_not_the_ledger_or_townsfolk() -> void:
	var runner := scene_runner(TOWN_SCENE_PATH)
	await runner.simulate_frames(3)
	var town := runner.scene()
	var player := town.find_child("Player", true, false) as Player
	var door := town.find_child("TownHallEntrance", true, false) as BuildingDoor
	var ledger := town.find_child("TownHallDoor", true, false) as SMInteractable
	door.required_flag = HELD_GATE
	player.global_position = door.global_position
	await _physics(6)
	assert_bool(ledger._player_in_range).override_failure_message(
		"the ledger's range must cover the threshold for this test to mean anything"
	).is_true()
	runner.simulate_action_pressed("interact")
	await runner.simulate_frames(5)
	assert_str(ledger._prompt.text).is_not_equal(tr(ledger.interaction_text))
	assert_array(_balloons()).override_failure_message(
		"a townsperson answered E on the Town Hall threshold"
	).is_empty()
	assert_bool(get_tree().paused).is_false()

	# One step off the threshold, E belongs to the townsfolk and signs again.
	player.global_position = door.global_position + Vector2(0.0, 140.0)
	await _physics(6)
	assert_bool(door._player_in_range).is_false()


func _world_targets(town: Node) -> Array[Node2D]:
	var targets: Array[Node2D] = []
	for node: Node in town.find_children("*", "NPC", true, false):
		targets.append(node as Node2D)
	for node: Node in town.find_children("*", "SMInteractable", true, false):
		targets.append(node as Node2D)
	return targets


func _balloons() -> Array[Node]:
	var found: Array[Node] = []
	for node: Node in get_tree().root.find_children("*", "CanvasLayer", true, false):
		var script := node.get_script() as Script
		if script != null and script.resource_path == BALLOON_SCRIPT:
			found.append(node)
	return found


func _physics(count: int) -> void:
	for _i: int in count:
		await get_tree().physics_frame
