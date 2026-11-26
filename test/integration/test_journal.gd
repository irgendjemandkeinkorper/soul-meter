extends GdUnitTestSuite

const JournalUI := preload("res://ui/screens/journal.gd")

var _quest_pools_before: Dictionary
var _quest_resources_before: Dictionary
var _reputation_before: Dictionary
var _renown_before: Dictionary
var _flags_before: Dictionary


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
	_flags_before = GameState.flags.duplicate(true)
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
	GameState.flags = _flags_before


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
	# U3: one who/where line; an ACTIVE quest carries no state badge.
	assert_str(active_text).contains("Themka Gaath  ·  Dorthkor Road")
	assert_str(active_text).not_contains("ACTIVE")

	var completed_text := _label_text(completed)
	assert_str(completed_text).contains("The Bell That Won't Ring")
	# Q1: a completed quest no longer prints its turn-in step. The bell quest records no choice,
	# so its entry is the title, the state and the who/where line.
	assert_str(completed_text).not_contains("Return to Sella Varn with what you found.")
	assert_str(completed_text).contains("Sella Varn  ·  Dom bell house")
	assert_str(completed_text).contains("COMPLETED")


## Q1: a resolved side quest shows the choice the player made, with what the world shows for it
## on the tooltip, instead of "Return to Droma Flintjaw and decide the armor's fate."
func test_completed_quests_show_how_they_ended() -> void:
	var side: DomSideQuest = QuestRegistry.LIVING_TAG
	var stub: StubSideQuest = QuestRegistry.STUB_CADENCE
	var muster := QuestRegistry.DORTHKOR_ROAD
	for quest: FlagQuest in [side, stub, muster]:
		quest.current_stage = quest.required_flags.size()
		quest.objective_completed = true
	GameState.set_flag(side.resolution_flag, "restore-the-name")
	GameState.set_flag("chapter_one_resolution", "hold-both")
	QuestRegistry.from_dict(
		{
			"completed": [
				{"id": side.id, "data": side.serialize()},
				{"id": stub.id, "data": stub.serialize()},
				{"id": muster.id, "data": muster.serialize()},
			],
		}
	)
	var runner := scene_runner("res://ui/screens/journal.tscn")
	await runner.simulate_frames(2)

	var completed := runner.find_child("CompletedQuests", true, false) as VBoxContainer
	var completed_text := _label_text(completed)
	assert_str(completed_text).contains(side.outcome_labels[1])
	assert_str(completed_text).not_contains(side.objectives[side.objectives.size() - 1])
	var stub_entry := completed.find_child("Quest%d" % stub.id, true, false)
	assert_str(_label_text(stub_entry)).contains("TO BE CONTINUED")
	assert_str(_label_text(stub_entry)).not_contains("COMPLETED")
	assert_str(completed_text).contains("Dom accepts the cost of holding both fronts.")
	assert_str(completed_text).not_contains("Return to Marshal Coiljaw in Dom.")

	var side_entry := completed.find_child("Quest%d" % side.id, true, false)
	var outcome := side_entry.find_child("QuestOutcome", true, false) as Label
	assert_object(outcome).is_not_null()
	assert_str(outcome.tooltip_text).is_equal(side.outcome_readbacks[1])
	assert_int(outcome.mouse_filter).is_equal(Control.MOUSE_FILTER_PASS)


## Q1: the main thread leads, commissions follow, companions' own quests close the column.
func test_active_quests_list_the_main_thread_first_and_companions_last() -> void:
	var companion := QuestRegistry.SERAI_LUN_QUEST
	var commission: DomSideQuest = QuestRegistry.ASH_IN_THE_RAIN
	var main := QuestRegistry.UNANSWERED_ROAR
	QuestRegistry.from_dict(
		{
			"active": [
				{"id": companion.id, "data": companion.serialize()},
				{"id": commission.id, "data": commission.serialize()},
				{"id": main.id, "data": main.serialize()},
			],
		}
	)
	var runner := scene_runner("res://ui/screens/journal.tscn")
	await runner.simulate_frames(2)

	var active := runner.find_child("ActiveQuests", true, false) as VBoxContainer
	var order: Array[String] = []
	for child: Node in active.get_children():
		if child.name.begins_with("Quest"):
			order.append(str(child.name))
	assert_array(order).is_equal(
		["Quest%d" % main.id, "Quest%d" % commission.id, "Quest%d" % companion.id]
	)


func test_every_registered_quest_has_giver_and_location_metadata() -> void:
	# known_quests(): the stubs show in the journal too, so they need the same who/where line.
	for quest: Quest in QuestRegistry.known_quests():
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
