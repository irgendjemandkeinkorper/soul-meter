extends GdUnitTestSuite

const REVEAL_PATH := "res://ui/components/reward_reveal.tscn"


func before_test() -> void:
	UIManager.reset_reward_reveals()


func after_test() -> void:
	UIManager.reset_reward_reveals()


func test_reward_reveal_places_every_changed_reward_front_and_center() -> void:
	var packed := load(REVEAL_PATH) as PackedScene
	assert_object(packed).is_not_null()
	if packed == null:
		return
	var reveal: Node = auto_free(packed.instantiate())
	add_child(reveal)
	reveal.present(_full_reward_summary(), true)
	await get_tree().process_frame

	assert_bool(reveal.visible).is_true()
	assert_str(reveal.get_node("SafeArea/Center/RewardPanel/Content/Column/QuestTitle").text).is_equal(
		"The Broken Muster"
	)
	assert_str(reveal.get_node("SafeArea/Center/RewardPanel/Content/Column/Resolution").text).contains(
		"Held both fronts"
	)
	var entries: Node = reveal.get_node("SafeArea/Center/RewardPanel/Content/Column/Entries")
	assert_int(entries.get_child_count()).is_equal(5)
	var visible_text := _descendant_label_text(entries)
	assert_str(visible_text).contains("LOOT")
	assert_str(visible_text).contains("FACTION INFLUENCE")
	assert_str(visible_text).contains("RENOWN")
	assert_str(visible_text).contains("CURRENCY")
	assert_str(visible_text).contains("MILESTONE")
	assert_str(visible_text).contains("+7")
	assert_str(visible_text).contains("-2")
	var faction_row := entries.get_child(1) as PanelContainer
	var faction_amount := faction_row.get_child(0).get_child(2) as Label
	assert_int(faction_amount.get_theme_font_size("font_size")).is_equal(DS.FS_600)


func test_reduced_motion_keeps_information_and_focus_without_animation() -> void:
	var reveal: Node = auto_free((load(REVEAL_PATH) as PackedScene).instantiate())
	add_child(reveal)
	reveal.present(_full_reward_summary(), true)
	await get_tree().process_frame

	var panel := reveal.get_node("SafeArea/Center/RewardPanel") as Control
	var continue_button := reveal.get_node(
		"SafeArea/Center/RewardPanel/Content/Column/Continue"
	) as Button
	assert_bool(reveal.is_animation_active()).is_false()
	assert_object(panel.scale).is_equal(Vector2.ONE)
	assert_float(panel.modulate.a).is_equal_approx(1.0, 0.001)
	assert_bool(continue_button.has_focus()).is_true()


func test_standard_motion_animates_the_panel_and_reward_rows() -> void:
	var reveal: Node = auto_free((load(REVEAL_PATH) as PackedScene).instantiate())
	add_child(reveal)
	reveal.present(_full_reward_summary(), false)
	var panel := reveal.get_node("SafeArea/Center/RewardPanel") as Control
	assert_float(panel.scale.x).is_equal_approx(0.94, 0.001)
	await get_tree().process_frame

	assert_bool(reveal.is_animation_active()).is_true()

	reveal.dismiss()
	await get_tree().create_timer(0.25, true).timeout


func test_continue_dismisses_the_modal_and_emits_once() -> void:
	var reveal: Node = auto_free((load(REVEAL_PATH) as PackedScene).instantiate())
	add_child(reveal)
	var dismissals: Array[bool] = []
	reveal.dismissed.connect(func() -> void: dismissals.append(true))
	reveal.present(_full_reward_summary(), true)
	await get_tree().process_frame

	var continue_button := reveal.get_node(
		"SafeArea/Center/RewardPanel/Content/Column/Continue"
	) as Button
	continue_button.pressed.emit()
	await get_tree().process_frame

	assert_bool(reveal.visible).is_false()
	assert_int(dismissals.size()).is_equal(1)


func test_ui_manager_queues_reward_summaries_without_replacing_the_visible_one() -> void:
	var first := _full_reward_summary()
	first["quest_name"] = "First Reckoning"
	var second := _full_reward_summary()
	second["quest_name"] = "Second Reckoning"

	QuestRegistry.quest_rewards_granted.emit(first)
	await get_tree().process_frame
	var reveal := UIManager.get_node_or_null("RewardReveal")
	assert_object(reveal).is_not_null()
	if reveal == null:
		return
	var title := reveal.get_node(
		"SafeArea/Center/RewardPanel/Content/Column/QuestTitle"
	) as Label
	assert_str(title.text).is_equal("First Reckoning")

	QuestRegistry.quest_rewards_granted.emit(second)
	await get_tree().process_frame
	assert_str(title.text).is_equal("First Reckoning")

	reveal.dismiss()
	await get_tree().create_timer(0.5, true).timeout
	assert_bool(reveal.visible).is_true()
	assert_str(title.text).is_equal("Second Reckoning")

	reveal.dismiss()
	await get_tree().create_timer(0.5, true).timeout


func _full_reward_summary() -> Dictionary:
	return {
		"quest_name": "The Broken Muster",
		"resolution_label": "Held both fronts",
		"entries": [
			{"kind": "item", "id": "weapons/roadwarden_spear", "label": "Roadwarden Spear", "amount": 1, "detail": "New equipment"},
			{"kind": "faction", "id": "iron-companies", "delta": 7.0, "detail": "They remember the ruling"},
			{"kind": "renown", "id": "renown", "delta": 10.0, "detail": "Dom knows the company"},
			{"kind": "currency", "id": "gold", "label": "Company silver", "delta": -2.0, "detail": "Road levy paid"},
			{"kind": "level", "id": "milestone-level", "delta": 1.0, "detail": "Milestone level gained"},
		],
	}


func _descendant_label_text(node: Node) -> String:
	var rows: PackedStringArray = []
	if node is Label:
		rows.append((node as Label).text)
	for child in node.get_children():
		rows.append(_descendant_label_text(child))
	return "\n".join(rows)
