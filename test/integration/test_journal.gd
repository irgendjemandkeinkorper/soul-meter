extends GdUnitTestSuite

const JournalUI := preload("res://ui/screens/journal.gd")

var _quest_pools_before: Dictionary
var _quest_resources_before: Dictionary
var _reputation_before: Dictionary
var _renown_before: Dictionary


func before_test() -> void:
	UIManager.close_all()
	UIManager.reset_reward_reveals()
	get_tree().paused = false
	_quest_pools_before = QuestRegistry.to_dict().duplicate(true)
	_quest_resources_before = {}
	for quest: Quest in QuestRegistry.ALL_QUESTS:
		_quest_resources_before[quest.id] = quest.serialize().duplicate(true)
	_reputation_before = Reputation.to_dict().duplicate(true)
	_renown_before = Renown.to_dict().duplicate(true)
	QuestRegistry.reset()
	Reputation.from_dict({})
	Renown.from_dict({})


func after_test() -> void:
	UIManager.close_all()
	UIManager.reset_reward_reveals()
	get_tree().paused = false
	for quest: Quest in QuestRegistry.ALL_QUESTS:
		if _quest_resources_before.has(quest.id):
			quest.deserialize(_quest_resources_before[quest.id])
	QuestRegistry.from_dict(_quest_pools_before)
	Reputation.from_dict(_reputation_before)
	Renown.from_dict(_renown_before)


func test_lists_active_and_completed_quests_with_journal_context() -> void:
	_seed_quest_states()
	var runner := scene_runner("res://ui/screens/journal.tscn")
	await runner.simulate_frames(2)

	var active := runner.find_child("ActiveQuests", true, false) as VBoxContainer
	var completed := runner.find_child("CompletedQuests", true, false) as VBoxContainer
	assert_object(active).is_not_null()
	assert_object(completed).is_not_null()

	var active_text := _label_text(active)
	assert_str(active_text).contains("The Broken Muster")
	assert_str(active_text).contains("Break the demon vanguard.")
	assert_str(active_text).contains("GIVEN BY  ·  Themka Gaath")
	assert_str(active_text).contains("WHERE  ·  Dorthkor Road")
	assert_str(active_text).contains("STATE  ·  Active")

	var completed_text := _label_text(completed)
	assert_str(completed_text).contains("The Bell That Won't Ring")
	assert_str(completed_text).contains("Return to Sella Varn with what you found.")
	assert_str(completed_text).contains("GIVEN BY  ·  Sella Varn")
	assert_str(completed_text).contains("WHERE  ·  Dom bell house")
	assert_str(completed_text).contains("STATE  ·  Completed")


func test_every_registered_quest_has_giver_and_location_metadata() -> void:
	for quest: Quest in QuestRegistry.ALL_QUESTS:
		assert_str(JournalUI.quest_giver(quest)).is_not_equal("Unentered")
		assert_str(JournalUI.quest_location(quest)).is_not_equal("Unentered")


func test_recorded_causes_appear_and_opening_journal_is_read_only() -> void:
	_seed_quest_states()
	Reputation.record(
		"player", "mirror-choir", 12.0, "Kept the bell's last promise", "mirror-hall"
	)
	Renown.gain_infamy(
		"player", 3.0, "Let the broken oath travel ahead", "dorthkor-road"
	)
	var quests_before := QuestRegistry.to_dict().duplicate(true)
	var reputation_before := Reputation.to_dict().duplicate(true)
	var renown_before := Renown.to_dict().duplicate(true)

	var runner := scene_runner("res://ui/screens/journal.tscn")
	await runner.simulate_frames(2)
	var recent := runner.find_child("RecentConsequences", true, false) as VBoxContainer
	assert_object(recent).is_not_null()
	var recap := _label_text(recent)
	assert_str(recap).contains("Kept the bell's last promise")
	assert_str(recap).contains("Mirror Choir")
	assert_str(recap).contains("Mirror Hall")
	assert_str(recap).contains("Let the broken oath travel ahead")
	assert_str(recap).contains("Infamy +3.0")

	assert_dict(QuestRegistry.to_dict()).is_equal(quests_before)
	assert_dict(Reputation.to_dict()).is_equal(reputation_before)
	assert_dict(Renown.to_dict()).is_equal(renown_before)


func test_journal_tree_has_no_local_theme_overrides() -> void:
	_seed_quest_states()
	Reputation.record("player", "mirror-choir", 1.0, "Test cause", "test-room")
	var runner := scene_runner("res://ui/screens/journal.tscn")
	await runner.simulate_frames(2)
	var journal := runner.find_child("QuestColumns", true, false) as Node
	assert_object(journal).is_not_null()
	if journal == null:
		return
	while journal.get_parent() is Control:
		journal = journal.get_parent()
	var overrides: Array[String] = []
	_collect_theme_overrides(journal, overrides)
	assert_array(overrides).is_empty()


func test_q_action_opens_the_journal_during_gameplay() -> void:
	var has_q_binding := false
	for input_event: InputEvent in InputMap.action_get_events(&"open_journal"):
		if input_event is InputEventKey:
			var key_event := input_event as InputEventKey
			if key_event.physical_keycode == KEY_Q:
				has_q_binding = true
	assert_bool(has_q_binding).is_true()

	var runner := scene_runner("res://world/test_room.tscn")
	await runner.simulate_frames(5)
	var world := runner.find_child("Player", true, false) as Node
	while world != null and world.name != "TestRoom":
		world = world.get_parent()
	assert_object(world).is_not_null()
	if world == null:
		return
	var previous_current_scene := get_tree().current_scene
	get_tree().current_scene = world
	var open_event := InputEventAction.new()
	open_event.action = &"open_journal"
	open_event.pressed = true
	UIManager._unhandled_input(open_event)
	await runner.simulate_frames(2)
	assert_bool(UIManager.is_open()).is_true()
	if not UIManager.is_open():
		get_tree().current_scene = previous_current_scene
		return
	var journal: Control = UIManager._stack.back()
	assert_str(journal.scene_file_path).is_equal("res://ui/screens/journal.tscn")
	var standing_button := journal.find_child("OpenStandingButton", true, false) as Button
	assert_object(standing_button).is_not_null()
	if standing_button == null:
		get_tree().current_scene = previous_current_scene
		return
	standing_button.pressed.emit()
	await runner.simulate_frames(2)
	assert_int(UIManager._stack.size()).is_equal(2)
	if UIManager._stack.size() != 2:
		get_tree().current_scene = previous_current_scene
		return
	var standing: Control = UIManager._stack.back()
	assert_str(standing.scene_file_path).is_equal("res://ui/screens/standing.tscn")
	var standing_overrides: Array[String] = []
	_collect_theme_overrides(standing, standing_overrides)
	assert_array(standing_overrides).is_empty()
	get_tree().current_scene = previous_current_scene


func _seed_quest_states() -> void:
	var active := QuestRegistry.DORTHKOR_ROAD
	active.current_stage = 1
	active.objective_completed = false
	var completed := QuestRegistry.BELLHOUSE_REPAIR
	completed.current_stage = completed.required_flags.size()
	completed.objective_completed = true
	QuestRegistry.from_dict(
		{
			"active": [{"id": active.id, "data": active.serialize()}],
			"completed": [{"id": completed.id, "data": completed.serialize()}],
		}
	)


func _label_text(root: Node) -> String:
	var lines: PackedStringArray = []
	_collect_label_text(root, lines)
	return "\n".join(lines)


func _collect_label_text(node: Node, lines: PackedStringArray) -> void:
	if node is Label:
		lines.append((node as Label).text)
	for child: Node in node.get_children():
		_collect_label_text(child, lines)


func _collect_theme_overrides(node: Node, found: Array[String]) -> void:
	if node is Control:
		var control := node as Control
		for property: Dictionary in control.get_property_list():
			var property_name := str(property.get("name", ""))
			if not property_name.begins_with("theme_override_"):
				continue
			var item_name := StringName(property_name.get_slice("/", 1))
			var has_override := false
			if property_name.begins_with("theme_override_colors/"):
				has_override = control.has_theme_color_override(item_name)
			elif property_name.begins_with("theme_override_constants/"):
				has_override = control.has_theme_constant_override(item_name)
			elif property_name.begins_with("theme_override_fonts/"):
				has_override = control.has_theme_font_override(item_name)
			elif property_name.begins_with("theme_override_font_sizes/"):
				has_override = control.has_theme_font_size_override(item_name)
			elif property_name.begins_with("theme_override_icons/"):
				has_override = control.has_theme_icon_override(item_name)
			elif property_name.begins_with("theme_override_styles/"):
				has_override = control.has_theme_stylebox_override(item_name)
			if has_override:
				found.append("%s: %s" % [str(control.get_path()), property_name])
	for child: Node in node.get_children():
		_collect_theme_overrides(child, found)
