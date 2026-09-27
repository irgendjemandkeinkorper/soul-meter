extends GdUnitTestSuite
## Explicit rendered QA: preserves each menu's own theme at both supported sizes.

var _state_before: Dictionary


func before_test() -> void:
	_state_before = GameState.to_dict().duplicate(true)
	GameState.inventory.clear()
	GameState.equipped_slots.clear()
	var vex := PartyMember.new()
	vex.id = GameState.PROTAGONIST_ID
	vex.display_name = "Vex"
	vex.epithet = "the Unwritten"
	vex.race = "Human"
	vex.char_class = "Mirrorblade"
	vex.hp = 20
	vex.max_hp = 20
	for attribute: String in DramgidSchema.ATTRIBUTE_IDS:
		vex.attributes[attribute] = 3
	vex.advancement_points = 3
	vex.major_element = "khash"
	vex.minor_element = "luth"
	vex.injuries["throat"] = {"injury_id": "throat-crushed", "instance_id": "throat-crushed@throat|ledger",
		"location_id": "throat", "severity": "serious", "applications": 1,
		"effects": {"voice_blocked": true}, "recovery": "untreated"}
	var serai := PartyMember.new()
	serai.id = "serai"
	serai.display_name = "Serai"
	serai.hp = 12
	serai.max_hp = 12
	serai.skill_tiers = {"mending": "trained"}
	GameState.set_party([vex, serai])
	GameState.set_gp(200)
	for id: String in [ItemIds.WEAPONS_FORGE_HAMMER, ItemIds.WEAPONS_TAUBSTUMMER_AXE,
		ItemIds.CONSUMABLES_HEARTHLOAF, ItemIds.MATERIALS_LOAMROOT_SPRIG,
		ItemIds.CONSUMABLES_BITTERLEAF_POULTICE]:
		GameState.inventory.create_and_add_item(id)
	Battle.controller = null
	Battle.ended = true
	DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path("user://qa"))


func after_test() -> void:
	GameState.from_dict(_state_before)


func test_menus_1080p() -> void:
	await _capture_menus(Vector2i(1920, 1080))


func test_menus_720p() -> void:
	await _capture_menus(Vector2i(1280, 720))


func _capture_menus(resolution: Vector2i) -> void:
	var viewport := auto_free(SubViewport.new()) as SubViewport
	viewport.render_target_update_mode = SubViewport.UPDATE_ALWAYS
	viewport.size = resolution
	add_child(viewport)
	for menu: String in ["character_sheet", "inventory", "shop"]:
		var screen := (load("res://ui/screens/%s.tscn" % menu) as PackedScene).instantiate() as Screen
		viewport.add_child(screen)
		screen.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
		if screen is ShopScreen:
			(screen as ShopScreen).configure_vendor("root-and-reed")
		if screen is InventoryScreen:
			var inventory := screen as InventoryScreen
			inventory._on_item_selected(GameState.inventory.get_items_with_prototype_id(ItemIds.WEAPONS_TAUBSTUMMER_AXE)[0])
			inventory._equip_selected()
		await _settle()
		await _capture(viewport, "%s-%d" % [menu, resolution.x])
		assert_bool(Rect2(Vector2.ZERO, Vector2(resolution)).encloses(screen.shell_back_button.get_global_rect())).override_failure_message("Back must stay inside %s" % menu).is_true()
		assert_bool(Rect2(Vector2.ZERO, Vector2(resolution)).encloses(screen.shell_hud_bar.get_global_rect())).override_failure_message("Footer must fit %s" % menu).is_true()
		assert_bool(Rect2(Vector2.ZERO, Vector2(resolution)).encloses(screen.shell_body.get_global_rect())).override_failure_message("Body must fit %s" % menu).is_true()
		if menu == "character_sheet":
			var scroll := screen.find_child("SheetColumn", true, false).get_parent() as ScrollContainer
			var injury := screen.find_child("Injury_throat", true, false) as Control
			scroll.ensure_control_visible(injury)
			await _settle()
			await _capture(viewport, "injuries-%d" % resolution.x)
			var treat := screen.find_child("FieldTreat_throat", true, false) as Button
			assert_bool(scroll.get_global_rect().encloses(treat.get_global_rect())).override_failure_message("Field treatment must fit its scroll viewport").is_true()
		if screen is ShopScreen:
			var treat := screen.find_child("Treat_%s_throat_herbalist-service" % GameState.PROTAGONIST_ID, true, false) as Button
			var catalog_scroll := screen.find_child("CatalogScroll", true, false) as ScrollContainer
			assert_bool(catalog_scroll.get_global_rect().encloses(treat.get_global_rect())).override_failure_message("Initial focused treatment must be visible").is_true()
			treat.pressed.emit()
			await _settle()
			await _capture(viewport, "shop-recovery-%d" % resolution.x)
			var notice := screen.find_child("TreatmentNotice", true, false) as Control
			assert_bool(Rect2(Vector2.ZERO, Vector2(resolution)).encloses(notice.get_global_rect())).is_true()
			assert_bool((notice.get_node("Column/Top/Dismiss") as Button).has_focus()).is_true()
			(notice.get_node("Column/Top/Dismiss") as Button).pressed.emit()
			await _settle()
			assert_bool(screen.shell_back_button.has_focus()).is_true()
			(screen as ShopScreen).configure_vendor("iron-and-thread")
			catalog_scroll.scroll_vertical = 0
			await _settle()
			await _capture(viewport, "equipment-shop-%d" % resolution.x)
		screen.free()


func _settle() -> void:
	await get_tree().create_timer(0.25).timeout
	for frame: int in 4:
		await get_tree().process_frame


func _capture(viewport: SubViewport, filename: String) -> void:
	RenderingServer.force_draw()
	await RenderingServer.frame_post_draw
	assert_int(viewport.get_texture().get_image().save_png("user://qa/%s.png" % filename)).is_equal(OK)
