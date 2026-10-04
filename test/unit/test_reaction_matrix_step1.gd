extends GdUnitTestSuite
## Reaction matrix step 1 on the material substrate: timber and stone objects, Kindle and
## Firebreak on objects, Douse (L2), Wet refusing ignition (H2), Reclaim on burning vs ruined
## material (M4), Sever on a Firebreak (Z6), and the material checkpoint order.

const NO_FIZZLE := {"fizzle": {"harmonic_accord": 100.0, "pitch": 10}}


func test_kindle_on_timber_deals_three_integrity_and_ignites_it() -> void:
	var battle := _battle()
	var controller: CombatController = battle["controller"]
	var caster: BattleActor = battle["caster"]
	var preview := controller.query_action(controller.action_by_id(&"kindle"), null, _on("timber", NO_FIZZLE))
	assert_bool(preview["allowed"]).is_true()
	assert_int(int((preview["object"] as Dictionary)["object_damage"])).is_equal(3)
	assert_str(String((preview["object"] as Dictionary)["ignition_refusal"])).is_equal("")
	var breath_before := caster.breath
	var outcome := controller.submit_action(&"kindle", null, _on("timber", NO_FIZZLE))
	assert_bool(outcome["allowed"]).is_true()
	if bool(outcome["fizzled"]):
		return
	assert_int(caster.breath).is_equal(breath_before - 3)
	var timber := controller.material_object("timber")
	assert_int(int(timber["integrity"])).is_equal(27)
	assert_bool(bool(timber["burning"])).is_true()
	assert_bool(_saw(battle, &"object_ignited")).is_true()
	assert_bool(bool(battle["grid"].cell_query(Vector2i(2, 1))["passable"])).is_false()


func test_kindle_on_stone_is_rejected_before_payment() -> void:
	var battle := _battle()
	var controller: CombatController = battle["controller"]
	var caster: BattleActor = battle["caster"]
	var breath_before := caster.breath
	var refused := controller.query_action(controller.action_by_id(&"kindle"), null, _on("stone", NO_FIZZLE))
	assert_str(String(refused["blocked_by"])).is_equal("no_effect")
	assert_bool(controller.submit_action(&"kindle", null, _on("stone", NO_FIZZLE))["allowed"]).is_false()
	assert_int(caster.breath).is_equal(breath_before)
	assert_int(int(controller.material_object("stone")["integrity"])).is_equal(30)


func test_burning_timber_loses_three_per_checkpoint_and_douse_wets_it() -> void:
	var battle := _battle()
	var controller: CombatController = battle["controller"]
	if not _kindle(battle, "timber"):
		return
	_end_round(battle)
	var timber := controller.material_object("timber")
	assert_int(int(timber["integrity"])).is_equal(24)
	assert_int(int(timber["fuel"])).is_equal(8)
	assert_bool(_saw(battle, &"object_burn_tick")).is_true()
	var doused := controller.submit_action(&"douse", null, _on("timber", NO_FIZZLE))
	assert_bool(doused["allowed"]).is_true()
	if bool(doused["fizzled"]):
		return
	timber = controller.material_object("timber")
	assert_bool(bool(timber["burning"])).is_false()
	assert_int(int(timber["wet_checkpoints"])).is_equal(2)
	assert_bool(_saw(battle, &"object_doused")).is_true()
	_end_round(battle)
	assert_int(int(controller.material_object("timber")["integrity"])).is_equal(24)
	# H2: fire on Wet material still lands its direct hit but does not ignite.
	battle["caster"].action_points = 8
	var again := controller.submit_action(&"kindle", null, _on("timber", NO_FIZZLE))
	if bool(again["fizzled"]):
		return
	assert_str(String((again["thermal"] as Dictionary)["ignition_refusal"])).is_equal("wet")
	timber = controller.material_object("timber")
	assert_int(int(timber["integrity"])).is_equal(21)
	assert_bool(bool(timber["burning"])).is_false()
	assert_bool(_saw(battle, &"ignition_refused")).is_true()
	_end_round(battle)
	assert_int(int(controller.material_object("timber")["wet_checkpoints"])).is_equal(0)
	assert_bool(_saw(battle, &"wet_expired")).is_true()


func test_collapse_ends_the_fire_and_opens_the_footprint() -> void:
	var battle := _battle()
	var controller: CombatController = battle["controller"]
	if not _kindle(battle, "timber"):
		return
	(controller.material.objects["timber"] as Dictionary)["integrity"] = 2
	_end_round(battle)
	var timber := controller.material_object("timber")
	assert_bool(bool(timber["ruined"])).is_true()
	assert_bool(bool(timber["burning"])).is_false()
	assert_int(int(timber["integrity"])).is_equal(0)
	assert_bool(_saw(battle, &"object_collapsed")).is_true()
	assert_bool(bool(battle["grid"].cell_query(Vector2i(2, 1))["passable"])).is_true()
	# A ruined object is not a new ignition target.
	battle["caster"].action_points = 8
	var refused := controller.query_action(controller.action_by_id(&"kindle"), null, _on("timber", NO_FIZZLE))
	assert_str(String(refused["blocked_by"])).is_equal("no_effect")


func test_a_firebreak_across_timber_ignites_it_without_a_direct_hit() -> void:
	var battle := _battle()
	var controller: CombatController = battle["controller"]
	var outcome := controller.submit_action(&"firebreak", null, _with_cells([[2, 0], [2, 1], [2, 2]], NO_FIZZLE))
	assert_bool(outcome["allowed"]).is_true()
	if bool(outcome["fizzled"]):
		return
	assert_array(outcome["ignited_objects"]).contains(["timber"])
	var timber := controller.material_object("timber")
	assert_int(int(timber["integrity"])).is_equal(30)
	assert_bool(bool(timber["burning"])).is_true()
	assert_bool(controller.fire.is_burning_cell(Vector2i(2, 1))).is_true()
	assert_int(int(controller.material_object("stone")["integrity"])).is_equal(30)


func test_douse_on_timber_under_a_firebreak_leaves_the_line_which_reignites_after_wet_expires() -> void:
	var battle := _battle()
	var controller: CombatController = battle["controller"]
	var caster: BattleActor = battle["caster"]
	# Round 1: quench and wet the timber. Round 2: lay the line over it. The Wet runs out at
	# the second checkpoint while the line still has one to go, so the line relights it.
	var doused := controller.submit_action(&"douse", null, _on("timber", NO_FIZZLE))
	if bool(doused["fizzled"]):
		return
	_end_round(battle)
	caster.breath = 60
	var line := controller.submit_action(&"firebreak", null, _with_cells([[2, 0], [2, 1], [2, 2]], NO_FIZZLE))
	if bool(line["fizzled"]):
		return
	assert_bool(bool(controller.material_object("timber")["burning"])).is_false()
	assert_bool(controller.fire.is_burning_cell(Vector2i(2, 1))).is_true()
	_end_round(battle)
	var timber := controller.material_object("timber")
	assert_int(int(timber["wet_checkpoints"])).is_equal(0)
	assert_bool(bool(timber["burning"])).is_true()
	assert_bool(controller.fire.is_burning_cell(Vector2i(2, 1))).is_true()


func test_sever_ends_the_firebreak_but_the_timber_keeps_burning() -> void:
	var battle := _battle()
	var controller: CombatController = battle["controller"]
	var caster: BattleActor = battle["caster"]
	var no_line := controller.query_action(controller.action_by_id(&"sever"), null, NO_FIZZLE)
	assert_str(String(no_line["blocked_by"])).is_equal("no_target")
	var line := controller.submit_action(&"firebreak", null, _with_cells([[2, 0], [2, 1], [2, 2]], NO_FIZZLE))
	if bool(line["fizzled"]):
		return
	var line_id := int((line["line"] as Dictionary)["id"])
	caster.action_points = 8
	var options := {"line_id": line_id}
	options.merge(NO_FIZZLE)
	var severed := controller.submit_action(&"sever", null, options)
	assert_bool(severed["allowed"]).is_true()
	if bool(severed["fizzled"]):
		return
	assert_bool(bool(severed["severed"])).is_true()
	assert_bool(controller.fire.is_empty()).is_true()
	assert_bool(_saw(battle, &"line_severed")).is_true()
	assert_bool(bool(controller.material_object("timber")["burning"])).is_true()
	_end_round(battle)
	assert_int(int(controller.material_object("timber")["integrity"])).is_equal(27)


func test_sever_is_refused_out_of_reach() -> void:
	var battle := _battle()
	var controller: CombatController = battle["controller"]
	var caster: BattleActor = battle["caster"]
	assert_bool(battle["grid"].displace(caster, Vector2i(1, 1))["allowed"]).is_true()
	var line := controller.submit_action(&"firebreak", null, _with_cells([[5, 0], [5, 1], [5, 2]], NO_FIZZLE))
	assert_bool(line["allowed"]).is_true()
	if bool(line["fizzled"]):
		return
	caster.action_points = 8
	var options := {"line_id": int((line["line"] as Dictionary)["id"])}
	assert_bool(controller.query_action(controller.action_by_id(&"sever"), null, options)["allowed"]).is_true()
	assert_bool(battle["grid"].displace(caster, Vector2i(0, 1))["allowed"]).is_true()
	var far := controller.query_action(controller.action_by_id(&"sever"), null, options)
	assert_str(String(far["blocked_by"])).is_equal("blocked_by_range")


func test_reclaim_rejects_burning_material_and_takes_ruined_material_once() -> void:
	var battle := _battle()
	var controller: CombatController = battle["controller"]
	var caster: BattleActor = battle["caster"]
	caster.breath = 20
	var intact := controller.query_action(controller.action_by_id(&"reclaim"), null, _on("timber", NO_FIZZLE))
	assert_str(String(intact["blocked_by"])).is_equal("not_a_source")
	if not _kindle(battle, "timber"):
		return
	caster.action_points = 8
	var burning := controller.query_action(controller.action_by_id(&"reclaim"), null, _on("timber", NO_FIZZLE))
	assert_str(String(burning["blocked_by"])).is_equal("not_a_source")
	assert_str(String((burning["nearest_unblock"] as Dictionary)["reason"])).is_equal("burning")
	(controller.material.objects["timber"] as Dictionary)["integrity"] = 1
	_end_round(battle)
	assert_bool(bool(controller.material_object("timber")["ruined"])).is_true()
	var breath_before := caster.breath
	var claimed := controller.submit_action(&"reclaim", null, _on("timber", NO_FIZZLE))
	assert_bool(claimed["allowed"]).is_true()
	if bool(claimed["fizzled"]):
		return
	assert_int(int(claimed["restored"])).is_equal(9)
	assert_int(caster.breath).is_equal(breath_before - 6 + 9)
	caster.action_points = 8
	var again := controller.query_action(controller.action_by_id(&"reclaim"), null, _on("timber", NO_FIZZLE))
	assert_str(String(again["blocked_by"])).is_equal("not_a_source")
	assert_str(String((again["nearest_unblock"] as Dictionary)["reason"])).is_equal("already_claimed")


func test_reclaim_is_clamped_by_capacity() -> void:
	var battle := _battle()
	var controller: CombatController = battle["controller"]
	var caster: BattleActor = battle["caster"]
	(controller.material.objects["timber"] as Dictionary)["integrity"] = 0
	(controller.material.objects["timber"] as Dictionary)["ruined"] = true
	caster.breath = 58
	var claimed := controller.submit_action(&"reclaim", null, _on("timber", NO_FIZZLE))
	if bool(claimed["fizzled"]):
		return
	# 58 − 6 = 52 leaves room for 8 of the 9.
	assert_int(int(claimed["restored"])).is_equal(8)
	assert_int(caster.breath).is_equal(60)


func test_rot_the_brace_ignores_wet_and_rejects_stone() -> void:
	var battle := _battle()
	var controller: CombatController = battle["controller"]
	var caster: BattleActor = battle["caster"]
	var stone := controller.query_action(controller.action_by_id(&"rot-the-brace"), null, _on("stone", NO_FIZZLE))
	assert_str(String(stone["blocked_by"])).is_equal("no_effect")
	var doused := controller.submit_action(&"douse", null, _on("timber", NO_FIZZLE))
	if bool(doused["fizzled"]):
		return
	caster.action_points = 8
	var rotted := controller.submit_action(&"rot-the-brace", null, _on("timber", NO_FIZZLE))
	assert_bool(rotted["allowed"]).is_true()
	if bool(rotted["fizzled"]):
		return
	assert_int(int(controller.material_object("timber")["integrity"])).is_equal(21)
	assert_bool(bool(controller.material_object("timber")["wet_checkpoints"] > 0)).is_true()


func test_crown_release_hits_an_object_on_a_mark_for_nine_and_ignites_it() -> void:
	var battle := _battle("Kero", 2)
	var controller: CombatController = battle["controller"]
	var outcome := controller.submit_action(&"crown-of-embers", null, _with_cells([[2, 1], [3, 1], [3, 2]], NO_FIZZLE))
	assert_bool(outcome["allowed"]).is_true()
	if bool(outcome["fizzled"]):
		return
	assert_int(int(controller.material_object("timber")["integrity"])).is_equal(30)
	_end_round(battle)
	assert_bool(_saw(battle, &"crown_released")).is_true()
	var timber := controller.material_object("timber")
	assert_int(int(timber["integrity"])).is_equal(21)
	assert_bool(bool(timber["burning"])).is_true()


func test_materials_survive_a_save_round_trip_with_their_footprint() -> void:
	var battle := _battle()
	var controller: CombatController = battle["controller"]
	if not _kindle(battle, "timber"):
		return
	var data := controller.class_resources_to_dict()
	assert_bool(data.has("__materials__")).is_true()
	var restored := _battle()
	var other: CombatController = restored["controller"]
	other.material.reset()
	other.restore_class_resources(data)
	var timber := other.material_object("timber")
	assert_int(int(timber["integrity"])).is_equal(27)
	assert_bool(bool(timber["burning"])).is_true()
	assert_bool(bool(restored["grid"].cell_query(Vector2i(2, 1))["passable"])).is_false()


# ─── helpers ──────────────────────────────────────────────────────────────────


func _on(object_id: String, extra: Dictionary = {}) -> Dictionary:
	var options := {"object_id": object_id}
	options.merge(extra)
	return options


func _kindle(battle: Dictionary, object_id: String) -> bool:
	var controller: CombatController = battle["controller"]
	var outcome := controller.submit_action(&"kindle", null, _on(object_id, NO_FIZZLE))
	assert_bool(outcome["allowed"]).is_true()
	return not bool(outcome.get("fizzled", false))


func _battle(patron: String = "Kero", harmony: int = 0) -> Dictionary:
	var rules := (load("res://data/combat/combat_rules.tres") as CombatRules).duplicate(true) as CombatRules
	rules.use_charge_time = false
	rules.base_action_points = 8
	var grid := GridBattlefieldModel.new()
	grid.configure(rules)
	grid.build_grid(_grid_ground())
	var caster := _actor("Caster", 60, 12, 0)
	caster.breath = 60
	caster.attributes = {"harmony": harmony, "alacrity": 4}
	caster.defining_effects = {"hit": true}
	caster.source_member = _member("caster-test", patron, 60)
	var ally := _actor("Second", 60, 8, 0)
	ally.breath = 30
	ally.source_member = _member("second-test", "Kero", 30)
	var enemy := _actor("Dummy", 60, 1, 0)
	var placements := {caster: Vector2i(0, 1), ally: Vector2i(0, 0), enemy: Vector2i(6, 2)}
	var enemies: Array[BattleActor] = [enemy]
	assert_bool(grid.configure_initial_cells(placements)["allowed"]).is_true()
	var controller := CombatController.new()
	controller.configure(CombatActionCatalog.all(), grid, rules)
	var events: Array[StringName] = []
	controller.event_emitted.connect(func(event: CombatEvent) -> void: events.append(event.type))
	controller.start([caster, ally], enemies, &"matrix-test")
	assert_bool(controller.place_material("timber", Vector2i(2, 1), MaterialField.KIND_TIMBER, "Barricade")["allowed"]).is_true()
	assert_bool(controller.place_material("stone", Vector2i(3, 0), MaterialField.KIND_STONE, "Stone control")["allowed"]).is_true()
	return {"controller": controller, "caster": caster, "ally": ally, "enemy": enemy, "grid": grid, "events": events}


func _member(id: String, patron: String, breath_max: int) -> PartyMember:
	var member := PartyMember.new()
	member.id = id
	member.patron = patron
	member.breath_max = breath_max
	return member


func _end_round(battle: Dictionary) -> void:
	var controller: CombatController = battle["controller"]
	var guard := 0
	while guard < 4:
		guard += 1
		assert_bool(controller.end_turn()).is_true()
		if controller.active_actor() == battle["caster"]:
			return
	assert_bool(false).override_failure_message("Round did not return to the caster.").is_true()


func _saw(battle: Dictionary, type: StringName) -> bool:
	return (battle["events"] as Array[StringName]).has(type)


func _with_cells(cells: Array, extra: Dictionary = {}) -> Dictionary:
	var data: Array[Dictionary] = []
	for pair: Array in cells:
		data.append({"x": int(pair[0]), "y": int(pair[1])})
	var options := {"cells": data}
	options.merge(extra)
	return options


func _actor(name: String, hp: int, attack: int, defense: int) -> BattleActor:
	var actor := BattleActor.new()
	actor.display_name = name
	actor.hp = hp
	actor.max_hp = hp
	actor.attack = attack
	actor.defense = defense
	return actor


func _grid_ground() -> TileMapLayer:
	var tile_set := TileSet.new()
	tile_set.tile_size = Vector2i(64, 32)
	var image := Image.create(64, 32, false, Image.FORMAT_RGBA8)
	var source := TileSetAtlasSource.new()
	source.texture = ImageTexture.create_from_image(image)
	source.texture_region_size = Vector2i(64, 32)
	source.create_tile(Vector2i.ZERO)
	tile_set.add_source(source, 0)
	var layer := auto_free(TileMapLayer.new()) as TileMapLayer
	layer.tile_set = tile_set
	for x: int in 7:
		for y: int in 3:
			layer.set_cell(Vector2i(x, y), 0, Vector2i.ZERO)
	return layer
