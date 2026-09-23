extends GdUnitTestSuite
## Rendered evidence for task 10C: the character sheet's Injuries section with a qualified
## practitioner and one supply unit, at the 1920×1080 design frame.

var _state_before: Dictionary


func before_test() -> void:
	UIManager.close_all()
	_state_before = GameState.to_dict().duplicate(true)
	var vex := PartyMember.new()
	vex.id = GameState.PROTAGONIST_ID
	vex.display_name = "Vex"
	vex.hp = 9
	vex.max_hp = 20
	vex.injuries["throat"] = {"injury_id": "throat-crushed", "instance_id": "throat-crushed@throat|cap",
		"location_id": "throat", "severity": "serious", "applications": 1, "effects": {"voice_blocked": true}, "recovery": "untreated"}
	var serai := PartyMember.new()
	serai.id = "serai"
	serai.display_name = "Serai"
	serai.hp = 12
	serai.skill_tiers = {"mending": "trained"}
	GameState.party = [vex, serai]
	GameState.inventory.create_and_add_item(ItemIds.CONSUMABLES_BITTERLEAF_POULTICE)
	Battle.controller = null
	Battle.ended = true


func after_test() -> void:
	UIManager.close_all()
	GameState.from_dict(_state_before)


func test_capture_injuries_section() -> void:
	var viewport := auto_free(SubViewport.new()) as SubViewport
	viewport.render_target_update_mode = SubViewport.UPDATE_ALWAYS
	viewport.size = Vector2i(1920, 1080)
	add_child(viewport)
	var sheet := (load("res://ui/screens/character_sheet.tscn") as PackedScene).instantiate() as Control
	sheet.theme = ThemeBuilder.build()
	viewport.add_child(sheet)
	await get_tree().process_frame
	sheet.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	for _frame: int in 5:
		await get_tree().process_frame
	var scroll := sheet.find_child("SheetColumn", true, false).get_parent() as ScrollContainer
	var section := sheet.find_child("Injury_throat", true, false) as Control
	scroll.scroll_vertical = int(section.position.y) - 80
	for _frame: int in 3:
		await get_tree().process_frame
	var button := sheet.find_child("FieldTreat_throat", true, false) as Button
	assert_object(button).is_not_null()
	var why := sheet.find_child("InjuryWhy_throat", true, false) as Label
	assert_bool(button.disabled).override_failure_message(why.text if why != null else "no reason label").is_false()
	assert_bool(sheet.get_global_rect().encloses(button.get_global_rect())).is_true()
	DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path("user://qa"))
	RenderingServer.force_draw()
	await RenderingServer.frame_post_draw
	assert_int(viewport.get_texture().get_image().save_png("user://qa/field-treatment-1920.png")).is_equal(OK)
	button.pressed.emit()
	for _frame: int in 5:
		await get_tree().process_frame
	var notice := sheet.find_child("TreatmentNotice", true, false) as PanelContainer
	assert_bool(notice.visible).is_true()
	assert_bool(sheet.get_global_rect().encloses(notice.get_global_rect())).is_true()
	assert_object(sheet.find_child("Injury_throat", true, false)).is_null()
	RenderingServer.force_draw()
	await RenderingServer.frame_post_draw
	assert_int(viewport.get_texture().get_image().save_png("user://qa/recovery-field-1920.png")).is_equal(OK)
