extends GdUnitTestSuite
## Focused captures with authored companion/quest fixtures and isolated state.

var _state: Dictionary
var _quests: Dictionary
var _quest_resources: Dictionary
var _reputation: Dictionary
var _renown: Dictionary


func before_test() -> void:
	_state = GameState.to_dict().duplicate(true)
	_quests = QuestRegistry.to_dict().duplicate(true)
	_quest_resources = {}
	for quest: Quest in QuestRegistry.ALL_QUESTS:
		_quest_resources[quest.id] = quest.serialize().duplicate(true)
	_reputation = Reputation.to_dict().duplicate(true)
	_renown = Renown.to_dict().duplicate(true)
	Reputation.from_dict({})
	Renown.from_dict({})
	var members: Array[PartyMember] = []
	for member: PartyMember in GameState.recruitable_candidates():
		if member.id in ["serai-lun", "wyneth-hallow-tide", "old-grumbrand", "maura-greyfen", "ressa-quickfingers", "korrath-ninefold"]:
			members.append(member)
	GameState.set_party(members)
	var active := QuestRegistry.DORTHKOR_ROAD
	active.current_stage = 1
	active.objective_completed = false
	var completed := QuestRegistry.BELLHOUSE_REPAIR
	completed.current_stage = completed.required_flags.size()
	completed.objective_completed = true
	QuestRegistry.from_dict({
		"active": [{"id": active.id, "data": active.serialize()}],
		"completed": [{"id": completed.id, "data": completed.serialize()}],
	})
	Reputation.record("player", "mirror-choir", 12.0, "Kept the bell's last promise", "mirror-hall")
	Renown.gain_infamy("player", 3.0, "Let the broken oath travel ahead", "dorthkor-road")
	DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path("user://qa"))


func after_test() -> void:
	GameState.from_dict(_state)
	for quest: Quest in QuestRegistry.ALL_QUESTS:
		quest.deserialize(_quest_resources[quest.id])
	QuestRegistry.from_dict(_quests)
	Reputation.from_dict(_reputation)
	Renown.from_dict(_renown)
	UIManager.reset_reward_reveals()


func test_capture_1080p() -> void:
	await _capture_menus(Vector2i(1920, 1080))


func test_capture_720p() -> void:
	await _capture_menus(Vector2i(1280, 720))


func _capture_menus(resolution: Vector2i) -> void:
	var viewport := auto_free(SubViewport.new()) as SubViewport
	viewport.size = resolution
	viewport.render_target_update_mode = SubViewport.UPDATE_ALWAYS
	add_child(viewport)
	for menu: String in ["party", "journal"]:
		var screen := (load("res://ui/screens/%s.tscn" % menu) as PackedScene).instantiate() as Screen
		screen.theme = ThemeBuilder.build()
		viewport.add_child(screen)
		screen.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
		await get_tree().create_timer(0.3).timeout
		RenderingServer.force_draw()
		await RenderingServer.frame_post_draw
		assert_int(viewport.get_texture().get_image().save_png("user://qa/%s-%d.png" % [menu, resolution.x])).is_equal(OK)
		screen.free()
