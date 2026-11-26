extends GdUnitTestSuite
## Quest-system sprint captures (docs/design/quest-system-sprint-2026-11-26.md): the journal
## mid-chapter, with every kind of quest active and completed quests showing how they ended.
## Writes JPGs to user://qa/quest-sprint/; copy the ones worth keeping into docs/qa/.

const OUT_DIR := "user://qa/quest-sprint"

var _state: Dictionary
var _quests: Dictionary
var _quest_resources: Dictionary
var _reputation: Dictionary
var _renown: Dictionary


func before_test() -> void:
	_state = GameState.to_dict().duplicate(true)
	_quests = QuestRegistry.to_dict().duplicate(true)
	_quest_resources = {}
	for quest: Quest in QuestRegistry.known_quests():
		_quest_resources[quest.id] = quest.serialize().duplicate(true)
	_reputation = Reputation.to_dict().duplicate(true)
	_renown = Renown.to_dict().duplicate(true)
	Reputation.from_dict({})
	Renown.from_dict({})
	seed_mid_chapter()
	DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path(OUT_DIR))


func after_test() -> void:
	GameState.from_dict(_state)
	for quest: Quest in QuestRegistry.known_quests():
		if _quest_resources.has(quest.id):
			quest.deserialize(_quest_resources[quest.id])
	QuestRegistry.from_dict(_quests)
	Reputation.from_dict(_reputation)
	Renown.from_dict(_renown)
	UIManager.reset_reward_reveals()


## After the Broken Muster ruling: the Roar open, two commissions and a companion in motion, and
## five quests entered, three of them with a recorded choice.
static func seed_mid_chapter() -> void:
	var living_tag: DomSideQuest = QuestRegistry.LIVING_TAG
	GameState.set_flag("chapter_one_resolution", "hold-both")
	GameState.set_flag(living_tag.resolution_flag, "restore-the-name")
	GameState.set_flag("field_debt_reward", "balance")
	var active: Array[Quest] = [
		QuestRegistry.UNANSWERED_ROAR,
		QuestRegistry.ASH_IN_THE_RAIN,
		QuestRegistry.STUB_LEDGE,
		QuestRegistry.SERAI_LUN_QUEST,
	]
	var completed: Array[Quest] = [
		QuestRegistry.DORTHKOR_ROAD,
		living_tag,
		QuestRegistry.FIELD_DEBT,
		QuestRegistry.STUB_CADENCE,
		QuestRegistry.BELLHOUSE_REPAIR,
	]
	var active_rows: Array[Dictionary] = []
	for quest: Quest in active:
		if quest is FlagQuest:
			(quest as FlagQuest).current_stage = 0
		quest.objective_completed = false
		active_rows.append({"id": quest.id, "data": quest.serialize()})
	var completed_rows: Array[Dictionary] = []
	for quest: Quest in completed:
		if quest is FlagQuest:
			(quest as FlagQuest).current_stage = (quest as FlagQuest).required_flags.size()
		quest.objective_completed = true
		completed_rows.append({"id": quest.id, "data": quest.serialize()})
	QuestRegistry.from_dict({"active": active_rows, "completed": completed_rows})


func test_capture_journal_1080p() -> void:
	await _capture_journal(Vector2i(1920, 1080))


func test_capture_journal_768p() -> void:
	await _capture_journal(Vector2i(1366, 768))


func _capture_journal(resolution: Vector2i) -> void:
	var viewport := auto_free(SubViewport.new()) as SubViewport
	viewport.size = resolution
	viewport.render_target_update_mode = SubViewport.UPDATE_ALWAYS
	add_child(viewport)
	var screen := (load("res://ui/screens/journal.tscn") as PackedScene).instantiate() as Screen
	screen.theme = ThemeBuilder.build()
	viewport.add_child(screen)
	screen.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	await get_tree().create_timer(0.3).timeout
	RenderingServer.force_draw()
	await RenderingServer.frame_post_draw
	var path := "%s/journal-%dx%d.jpg" % [OUT_DIR, resolution.x, resolution.y]
	assert_int(viewport.get_texture().get_image().save_jpg(path, 0.9)).is_equal(OK)
	screen.free()
