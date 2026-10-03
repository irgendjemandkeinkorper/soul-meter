extends GdUnitTestSuite
## Rendered evidence for task 10B: the herbalist shop with a treatable serious injury and
## an exact quote, at the 1920×1080 design frame. Output: user://qa/treatment-shop-1920.png.

const ShopScene := preload("res://ui/screens/shop.tscn")

var _state_before: Dictionary


func before_test() -> void:
	_state_before = GameState.to_dict().duplicate(true)
	GameState.party.clear()
	var vex := PartyMember.new()
	vex.id = "vex"
	vex.display_name = "Vex"
	vex.hp = 20
	vex.max_hp = 20
	vex.injuries["throat"] = {"injury_id": "throat-crushed", "instance_id": "throat-crushed@throat|cap",
		"location_id": "throat", "severity": "serious", "applications": 1, "effects": {"voice_blocked": true}}
	GameState.party.append(vex)
	GameState.set_gp(20)
	Battle.controller = null
	Battle.ended = true


func after_test() -> void:
	GameState.from_dict(_state_before)


func test_capture_treatment_section() -> void:
	var viewport := auto_free(SubViewport.new()) as SubViewport
	viewport.render_target_update_mode = SubViewport.UPDATE_ALWAYS
	viewport.size = Vector2i(1920, 1080)
	add_child(viewport)
	var shop := ShopScene.instantiate() as ShopScreen
	shop.theme = ThemeBuilder.build()
	viewport.add_child(shop)
	await get_tree().process_frame
	shop.configure_vendor("root-and-reed")
	shop.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	for _frame: int in 5:
		await get_tree().process_frame
	var button := shop.find_child("Treat_vex_throat_herbalist-service", true, false) as Button
	assert_object(button).is_not_null()
	assert_bool(shop.get_global_rect().encloses(button.get_global_rect())).is_true()
	DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path("user://qa"))
	RenderingServer.force_draw()
	await RenderingServer.frame_post_draw
	assert_int(viewport.get_texture().get_image().save_png("user://qa/treatment-shop-1920.png")).is_equal(OK)
	button.pressed.emit()
	for _frame: int in 5:
		await get_tree().process_frame
	var notice := shop.find_child("TreatmentNotice", true, false) as PanelContainer
	assert_bool(notice.visible).is_true()
	assert_bool(shop.get_global_rect().encloses(notice.get_global_rect())).is_true()
	assert_object(shop.find_child("Treat_vex_throat_herbalist-service", true, false)).is_null()
	RenderingServer.force_draw()
	await RenderingServer.frame_post_draw
	assert_int(viewport.get_texture().get_image().save_png("user://qa/recovery-shop-1920.png")).is_equal(OK)
