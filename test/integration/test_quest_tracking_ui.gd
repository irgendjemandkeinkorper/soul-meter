extends GdUnitTestSuite
## Q3 (docs/design/quest-system-sprint-2026-11-26.md): a Track toggle on each active journal
## entry, and the field HUD's one objective line following the tracked quest. The registry rules
## (active only, released on completion, saved) are in test/unit/test_quest_tracking.gd.

const HUD_SCENE := "res://ui/hud/field_hud.tscn"
const JOURNAL_SCENE := "res://ui/screens/journal.tscn"

var _flags: Dictionary
var _quests: Dictionary
var _quest_resources: Dictionary


func before_test() -> void:
	UIManager.close_all()
	get_tree().paused = false
	_flags = GameState.flags.duplicate(true)
	_quests = QuestRegistry.to_dict().duplicate(true)
	_quest_resources = {}
	for quest: Quest in QuestRegistry.known_quests():
		_quest_resources[quest.id] = quest.serialize().duplicate(true)
	QuestRegistry.reset()


func after_test() -> void:
	UIManager.close_all()
	get_tree().paused = false
	QuestRegistry.reset()
	for quest: Quest in QuestRegistry.known_quests():
		if _quest_resources.has(quest.id):
			quest.deserialize(_quest_resources[quest.id])
	QuestRegistry.from_dict(_quests)
	GameState.flags = _flags


func _activate(quests: Array[Quest]) -> void:
	var rows: Array[Dictionary] = []
	for quest: Quest in quests:
		if quest is FlagQuest:
			(quest as FlagQuest).current_stage = 0
		quest.objective_completed = false
		rows.append({"id": quest.id, "data": quest.serialize()})
	QuestRegistry.from_dict({"active": rows})


func _track_button(runner: GdUnitSceneRunner, quest: Quest) -> Button:
	var entry := runner.find_child("Quest%d" % quest.id, true, false)
	return null if entry == null else entry.find_child("TrackButton", true, false) as Button


func test_each_active_quest_can_be_tracked_one_at_a_time() -> void:
	var road := QuestRegistry.DORTHKOR_ROAD
	var tag: DomSideQuest = QuestRegistry.LIVING_TAG
	_activate([road, tag])
	var bell := QuestRegistry.BELLHOUSE_REPAIR
	bell.current_stage = bell.required_flags.size()
	bell.objective_completed = true
	var saved := QuestRegistry.to_dict()
	saved["completed"] = [{"id": bell.id, "data": bell.serialize()}]
	QuestRegistry.from_dict(saved)
	var runner := scene_runner(JOURNAL_SCENE)
	await runner.simulate_frames(2)

	var road_toggle := _track_button(runner, road)
	var tag_toggle := _track_button(runner, tag)
	assert_object(road_toggle).is_not_null()
	assert_object(tag_toggle).is_not_null()
	assert_object(_track_button(runner, bell)).override_failure_message(
		"a completed quest offered a Track toggle"
	).is_null()
	assert_str(road_toggle.text).is_equal("Track")
	assert_str(tag_toggle.text).is_equal("Track")

	tag_toggle.button_pressed = true
	assert_object(QuestRegistry.pinned_quest()).is_same(tag)
	assert_str(tag_toggle.text).is_equal("Tracking")

	road_toggle.button_pressed = true
	assert_object(QuestRegistry.pinned_quest()).is_same(road)
	assert_bool(tag_toggle.button_pressed).is_false()
	assert_str(tag_toggle.text).is_equal("Track")

	road_toggle.button_pressed = false
	assert_object(QuestRegistry.pinned_quest()).is_null()
	assert_str(road_toggle.text).is_equal("Track")


func test_the_journal_opens_showing_what_is_tracked() -> void:
	var tag: DomSideQuest = QuestRegistry.LIVING_TAG
	_activate([QuestRegistry.DORTHKOR_ROAD, tag])
	assert_bool(QuestRegistry.pin(tag)).is_true()
	var runner := scene_runner(JOURNAL_SCENE)
	await runner.simulate_frames(2)
	var toggle := _track_button(runner, tag)
	assert_bool(toggle.button_pressed).is_true()
	assert_str(toggle.text).is_equal("Tracking")


func test_the_objective_line_follows_the_tracked_quest_and_names_its_area() -> void:
	var tag: DomSideQuest = QuestRegistry.LIVING_TAG
	_activate([QuestRegistry.DORTHKOR_ROAD, tag])
	var runner := scene_runner(HUD_SCENE)
	await runner.simulate_frames(1)
	var objective := runner.find_child("Objective", true, false) as Label
	assert_str(objective.text).contains(ChapterOneProgress.title())

	assert_bool(QuestRegistry.pin(tag)).is_true()
	await runner.simulate_frames(1)
	# The bare HUD stands in no area, so it says where to go.
	assert_str(objective.text).is_equal(
		"THE LIVING TAG  ·  %s  ·  GO TO  Dom" % tag.objectives[0]
	)
	assert_bool(objective.text.contains("\n")).is_false()

	GameState.set_flag(tag.required_flags[0], true)
	await runner.simulate_frames(2)
	assert_str(objective.text).contains(tag.objectives[1])

	QuestRegistry.unpin()
	await runner.simulate_frames(1)
	assert_str(objective.text).contains(ChapterOneProgress.title())
	assert_str(objective.text).not_contains("THE LIVING TAG")


func test_in_dom_a_tracked_dom_quest_does_not_send_you_to_dom() -> void:
	var tag: DomSideQuest = QuestRegistry.LIVING_TAG
	_activate([tag])
	assert_bool(QuestRegistry.pin(tag)).is_true()
	var runner := scene_runner("res://world/starting_town.tscn")
	await runner.simulate_frames(3)
	var objective := runner.find_child("Objective", true, false) as Label
	assert_str(objective.text).is_equal("THE LIVING TAG  ·  %s" % tag.objectives[0])
