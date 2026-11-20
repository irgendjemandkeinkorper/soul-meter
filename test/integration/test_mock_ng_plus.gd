extends GdUnitTestSuite
## #652 gap 5, owner item 48(c): the mock NG+ rollover. The chapter-complete screen arms a block
## (the chapter's style points and a completion marker), the title says so, and the next New
## Game starts over carrying it, which is what wakes the NG+ echo lines. The Mirror Shop
## (FR-801) is M10 work and is not part of this. Once the chapter is in free roam, the pause
## menu offers the same rollover, because Continue Exploring never brings that screen back.

const SaveGameScript := preload("res://globals/save_game.gd")
const CHAPTER_COMPLETE := preload("res://ui/screens/chapter_complete.gd")
const MAIN_MENU_SCENE := "res://ui/screens/main_menu.tscn"
const TEST_ROOM_SCENE := "res://world/test_room.tscn"

var saves
var _ng_plus_before: Dictionary
var _state_before: Dictionary
var _reputation_before: Dictionary
var _renown_before: Dictionary
var _quests_before: Dictionary
var _skill_check_before: Dictionary
var _world_clock_before: Dictionary
var _save_paths_before: Array[String] = []


func before_test() -> void:
	_ng_plus_before = SaveGame.ng_plus.duplicate(true)
	_state_before = GameState.to_dict()
	_reputation_before = Reputation.to_dict()
	_renown_before = Renown.to_dict()
	_quests_before = QuestRegistry.to_dict()
	_skill_check_before = SkillCheck.to_dict()
	_world_clock_before = WorldClock.to_dict()
	_save_paths_before = [SaveGame.save_path, SaveGame.temp_path, SaveGame.backup_path]
	# A private SaveGame: its `load_requested` reaches nothing, so `new_game()` loads no scene.
	saves = auto_free(SaveGameScript.new())
	var prefix := OS.get_temp_dir().path_join("soul-meter-mock-ng-plus-%s" % Time.get_ticks_usec())
	saves.save_path = prefix + ".save"
	saves.temp_path = prefix + ".save.tmp"
	saves.backup_path = prefix + ".save.bak"


func after_test() -> void:
	for path: String in [
		saves.save_path, saves.temp_path, saves.backup_path,
		SaveGame.save_path, SaveGame.temp_path, SaveGame.backup_path,
	]:
		if path not in _save_paths_before and FileAccess.file_exists(path):
			DirAccess.remove_absolute(path)
	SaveGame.save_path = _save_paths_before[0]
	SaveGame.temp_path = _save_paths_before[1]
	SaveGame.backup_path = _save_paths_before[2]
	SaveGame.ng_plus = _ng_plus_before
	SaveGame._armed_ng_plus = {}
	GameState.from_dict(_state_before)
	Reputation.from_dict(_reputation_before)
	Renown.from_dict(_renown_before)
	QuestRegistry.from_dict(_quests_before)
	SkillCheck.from_dict(_skill_check_before)
	WorldClock.from_dict(_world_clock_before)


func test_the_block_carries_the_chapters_style_points_and_a_completion_marker() -> void:
	SaveGame.ng_plus = NGPlus.default_block()
	SaveGame.ng_plus["style_points"] = 37
	var first: Dictionary = CHAPTER_COMPLETE.mock_ng_plus_block()
	assert_int(int(first["style_points"])).is_equal(37)
	assert_int(int(first["completion_metadata"]["chapter_completions"])).is_equal(1)
	assert_bool(bool(first["completion_metadata"]["mock"])).is_true()
	assert_bool(NGPlus.is_active(first)).is_true()
	# A second rollover counts the second completion.
	SaveGame.ng_plus = first
	var second: Dictionary = CHAPTER_COMPLETE.mock_ng_plus_block()
	assert_int(int(second["completion_metadata"]["chapter_completions"])).is_equal(2)


func test_new_game_applies_an_armed_block_once() -> void:
	var applied: Array[Dictionary] = []
	saves.ng_plus_applied.connect(func(block: Dictionary) -> void: applied.append(block))
	saves.arm_ng_plus({
		"style_points": 37,
		"completion_metadata": {"chapter_completions": 1, "mock": true},
	})
	assert_bool(saves.ng_plus_armed()).is_true()

	saves.new_game()
	assert_bool(NGPlus.is_active(saves.ng_plus)).is_true()
	assert_int(int(saves.ng_plus["style_points"])).is_equal(37)
	assert_bool(saves.ng_plus_armed()).is_false()
	assert_int(applied.size()).is_equal(1)

	# The next ordinary New Game is a first run again.
	saves.new_game()
	assert_bool(NGPlus.is_active(saves.ng_plus)).is_false()
	assert_int(applied.size()).is_equal(1)


func test_a_load_drops_an_armed_block() -> void:
	saves.new_game()
	assert_bool(saves.save()).is_true()
	saves.arm_ng_plus({"completion_metadata": {"chapter_completions": 1}})
	assert_bool(saves.load_save()).is_true()
	assert_bool(saves.ng_plus_armed()).is_false()


func test_a_mock_rollover_wakes_the_echo_lines() -> void:
	SaveGame.ng_plus = NGPlus.default_block()
	saves.arm_ng_plus(CHAPTER_COMPLETE.mock_ng_plus_block())
	saves.new_game()
	SaveGame.ng_plus = saves.ng_plus
	var resource: DialogueResource = load("res://dialogue/hadrik_vale.dialogue")
	var line: DialogueLine = await DialogueManager.get_next_dialogue_line(resource, "hub")
	var echo: DialogueResponse = null
	for response: DialogueResponse in line.responses:
		if "reflection" in response.text.to_lower():
			echo = response
	assert_object(echo).is_not_null()
	assert_bool(echo.is_allowed).is_true()


func test_the_title_says_when_a_rollover_is_armed() -> void:
	var plain: Node = auto_free((load(MAIN_MENU_SCENE) as PackedScene).instantiate())
	add_child(plain)
	await await_idle_frame()
	assert_object(plain.find_child("MockNgPlusNotice", true, false)).is_null()

	SaveGame.arm_ng_plus({"style_points": 37, "completion_metadata": {"chapter_completions": 1}})
	var armed: Node = auto_free((load(MAIN_MENU_SCENE) as PackedScene).instantiate())
	add_child(armed)
	await await_idle_frame()
	var notice := armed.find_child("MockNgPlusNotice", true, false) as Label
	assert_object(notice).is_not_null()
	assert_str(notice.text).contains("37 style points")


func test_the_pause_menu_offers_the_rollover_only_in_free_roam() -> void:
	# The autoload's own save goes to a scratch file, not the tester's save.
	SaveGame.save_path = saves.save_path + ".autoload"
	SaveGame.temp_path = saves.temp_path + ".autoload"
	SaveGame.backup_path = saves.backup_path + ".autoload"
	SaveGame.ng_plus = NGPlus.default_block()
	var runner := scene_runner(TEST_ROOM_SCENE)
	await runner.simulate_frames(10)

	var mid_chapter := UIManager.open(GameFlow.PAUSE_MENU, false, true)
	await runner.simulate_frames(2)
	assert_object(mid_chapter.find_child("BeginMockNgPlus", true, false)).is_null()
	UIManager.close_all()
	await runner.simulate_frames(2)

	_reach_free_roam()
	var free_roam := UIManager.open(GameFlow.PAUSE_MENU, false, true)
	await runner.simulate_frames(2)
	var button := free_roam.find_child("BeginMockNgPlus", true, false) as Button
	assert_object(button).is_not_null()
	button.pressed.emit()
	assert_bool(SaveGame.ng_plus_armed()).is_true()
	var armed: Dictionary = SaveGame.armed_ng_plus()
	assert_int(int(armed["completion_metadata"]["chapter_completions"])).is_equal(1)
	assert_bool(FileAccess.file_exists(SaveGame.save_path)).is_true()

	UIManager.close_all()
	await runner.simulate_frames(2)


## The critical path's facts, as `test_chapter_one_progress` sets them.
func _reach_free_roam() -> void:
	var candidates := GameState.recruitable_candidates()
	GameState.set_companions([candidates[0], candidates[1]])
	QuestRegistry.offer(QuestRegistry.DORTHKOR_ROAD)
	for flag in QuestRegistry.DORTHKOR_ROAD.required_flags:
		GameState.set_flag(flag, true)
	QuestSystem.update_quest(QuestRegistry.DORTHKOR_ROAD)
	GameState.set_flag("chapter_one_resolution", "hold-both")
	GameState.set_flag("chapter_one_free_roam", true)
	assert_int(ChapterOneProgress.current_stage()).is_equal(ChapterOneProgress.Stage.FREE_ROAM)
