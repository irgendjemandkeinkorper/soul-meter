extends GdUnitTestSuite
## Rendered check of a read enemy's turn-order marker (#285 slice 5, Sacred Clarity).


## AP round: the read is taken and rendered from the live controller. CT: the same intent row in
## the CT strip's shape (in this two-actor fight the hound is next, so a live CT read is spent
## before a frame could show it; that path is covered by test_enemy_intents.gd).
func test_read_enemy_marker_shows_its_intent_inside_the_strip() -> void:
	for use_charge_time: bool in [false, true]:
		await _capture(use_charge_time)


func _capture(use_charge_time: bool) -> void:
	var rules := (load("res://data/combat/combat_rules.tres") as CombatRules).duplicate(true) as CombatRules
	rules.use_charge_time = false
	var tile_set := TileSet.new()
	tile_set.tile_size = Vector2i(64, 32)
	var source := TileSetAtlasSource.new()
	source.texture = ImageTexture.create_from_image(Image.create(64, 32, false, Image.FORMAT_RGBA8))
	source.texture_region_size = tile_set.tile_size
	source.create_tile(Vector2i.ZERO)
	tile_set.add_source(source, 0)
	var ground := auto_free(TileMapLayer.new()) as TileMapLayer
	ground.tile_set = tile_set
	ground.set_cell(Vector2i(0, 0), 0, Vector2i.ZERO)
	ground.set_cell(Vector2i(1, 0), 0, Vector2i.ZERO)
	var grid := GridBattlefieldModel.new()
	grid.configure(rules)
	grid.build_grid(ground)
	var stuid := BattleActor.new()
	stuid.display_name = "Stuid"
	stuid.hp = 30
	stuid.max_hp = 30
	stuid.attack = 6
	stuid.source_member = PartyMember.new()
	stuid.source_member.id = "intent-capture-stuid"
	stuid.source_member.patron = "Stuid"
	stuid.source_member.perk_ids = PackedStringArray(["lensbearer-sacred-clarity"])
	var enemy := BattleActor.new()
	enemy.display_name = "Reed Hound"
	enemy.hp = 30
	enemy.max_hp = 30
	enemy.attack = 7
	var controller := CombatController.new()
	controller.configure(CombatActionCatalog.all(), grid, rules)
	controller.start([stuid], [enemy], &"intent-capture")
	for step in 10:
		if controller.state == CombatController.State.ALLY_TURN:
			break
		controller.end_turn()
	assert_bool(controller.submit_action(&"sacred-clarity", enemy).allowed).is_true()
	var viewport := auto_free(SubViewport.new()) as SubViewport
	viewport.render_target_update_mode = SubViewport.UPDATE_ALWAYS
	add_child(viewport)
	var interface := (load("res://ui/hud/battle_interface.tscn") as PackedScene).instantiate() as BattleInterface
	interface.theme = ThemeBuilder.build()
	viewport.add_child(interface)
	await get_tree().process_frame
	interface.bind_controller(controller)
	var snapshot := CombatEvent.new()
	snapshot.type = &"battle_snapshot"
	snapshot.data = {"snapshot": controller.snapshot()}
	if use_charge_time:
		var rows: Array = []
		for row: Dictionary in snapshot.data["snapshot"]["turn_order"]:
			rows.append({
				"actor_id": row["actor_id"], "display_name": row["display_name"],
				"charge": 100 if rows.is_empty() else 72, "intent": row.get("intent", {}),
			})
		snapshot.data["snapshot"]["turn_order"] = rows
	interface.consume_event(snapshot)
	DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path("user://qa"))
	viewport.size = Vector2i(1920, 1080)
	interface.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	for _frame: int in 5:
		await get_tree().process_frame
	var marker: Label = null
	for child: Node in interface.turn_timeline.markers.get_children():
		if (child as Label).text.begins_with("Reed Hound"):
			marker = child as Label
	assert_object(marker).is_not_null()
	assert_str(marker.text).contains("→ Stuid")
	assert_bool(interface.get_global_rect().encloses(marker.get_global_rect())).is_true()
	assert_bool(interface.turn_timeline.get_global_rect().encloses(marker.get_global_rect())).is_true()
	RenderingServer.force_draw()
	await RenderingServer.frame_post_draw
	var capture := viewport.get_texture().get_image()
	var mode := "ct" if use_charge_time else "ap"
	assert_int(capture.save_png("user://qa/intent-marker-%s.png" % mode)).is_equal(OK)
	viewport.queue_free()
