extends GdUnitTestSuite
## Quest-system sprint captures (docs/design/quest-system-sprint-2026-11-26.md): the journal
## mid-chapter, with every kind of quest active and completed quests showing how they ended, and
## Dom's field HUD following a tracked quest, with the field notice for a quest taken up.
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
	# Q3: one commission tracked, so the journal shows a toggle in each state.
	QuestRegistry.pin(QuestRegistry.ASH_IN_THE_RAIN)


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


func test_capture_field_tracking_1080p() -> void:
	var window_before := get_tree().root.size
	get_tree().root.size = Vector2i(1920, 1080)
	var runner := scene_runner("res://world/starting_town.tscn")
	await runner.simulate_frames(6)
	await get_tree().create_timer(0.5).timeout
	# A Dom commission tracked in Dom: its step, and no GO TO.
	await _capture_viewport("field-tracked-dom-1920x1080")

	# A Hollowmere quest taken up and tracked from Dom: the notice, then GO TO.
	QuestRegistry.offer(QuestRegistry.INSTRUMENT_STAKE)
	QuestRegistry.pin(QuestRegistry.INSTRUMENT_STAKE)
	await get_tree().create_timer(0.6).timeout
	await _capture_viewport("field-tracked-elsewhere-1920x1080")
	get_tree().root.size = window_before


func _capture_viewport(name: String) -> void:
	# Boot leaves the title menu loaded under the test runner; it is not part of the field.
	var hidden: Array[CanvasItem] = []
	for child: Node in get_tree().root.get_children():
		if child is CanvasItem and child.scene_file_path == GameFlow.MAIN_MENU_SCENE:
			if (child as CanvasItem).visible:
				(child as CanvasItem).visible = false
				hidden.append(child as CanvasItem)
		for layer: Node in child.get_children():
			if child.scene_file_path == GameFlow.MAIN_MENU_SCENE and layer is CanvasLayer:
				if (layer as CanvasLayer).visible:
					(layer as CanvasLayer).visible = false
					hidden.append(null)
					layer.set_meta(&"capture_hidden", true)
	RenderingServer.force_draw()
	await RenderingServer.frame_post_draw
	var path := "%s/%s.jpg" % [OUT_DIR, name]
	assert_int(get_viewport().get_texture().get_image().save_jpg(path, 0.9)).is_equal(OK)
	for item: CanvasItem in hidden:
		if item != null:
			item.visible = true
	for child: Node in get_tree().root.get_children():
		for layer: Node in child.get_children():
			if layer.has_meta(&"capture_hidden"):
				(layer as CanvasLayer).visible = true
				layer.remove_meta(&"capture_hidden")
