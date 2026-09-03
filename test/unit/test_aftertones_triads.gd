extends GdUnitTestSuite

const ResolutionScript := preload("res://globals/combat/resolution.gd")


func test_aftertones_tick_and_anchoring() -> void:
	var actor := BattleActor.new()
	actor.aftertones = [{"element": &"suul", "remaining_rounds": 2, "anchored": false}]
	actor.tick_aftertones()
	assert_int(actor.aftertones[0]["remaining_rounds"]).is_equal(1)
	actor.aftertones[0]["anchored"] = true
	actor.tick_aftertones()
	assert_int(actor.aftertones[0]["remaining_rounds"]).is_equal(1)


func test_rule_bends_anchor_consume_clear_and_hold_notes() -> void:
	var terra := _resolve(&"terra", [], [{"element": &"suul", "remaining_rounds": 2}])
	assert_bool(_has_aftertone(terra, true)).is_true()
	var scor := _resolve(&"scor", [], [{"element": &"suul", "remaining_rounds": 2}])
	assert_int(scor["damage"]).is_equal(2)
	assert_bool(_has_aftertone(scor, false)).is_true()
	var nul := _resolve(&"nul", [], [{"element": &"suul", "remaining_rounds": 2}], 3)
	assert_bool(_has_write(nul, "tempo")).is_true()
	assert_int(_aftertone_write_after(nul).size()).is_equal(1)
	var khor := _resolve(&"khor", [{"element": &"suul", "remaining_rounds": 2}], [])
	assert_bool(_has_held_aftertone(khor)).is_true()


func test_every_pandora_triad_emits_its_declarative_effect() -> void:
	for triad: TriadDefinition in ElementsData.all_triads():
		var controller := _live_controller(triad)
		var outcome := _submit_triad(controller, triad)
		assert_bool(bool(outcome.get("allowed", false))).is_true()
		assert_str(str(outcome["resolution"]["composition"]["triad_effect_id"])).is_equal(str(triad.unique_effect_id))


func test_stillpoint_applies_balance_consumer() -> void:
	var controller := _live_controller(ElementsData.triad(&"stillpoint"))
	controller.balance = 3
	_submit_triad(controller, ElementsData.triad(&"stillpoint"))
	assert_int(controller.balance).is_equal(0)


func test_founding_anchors_everyone_and_freezes_duration() -> void:
	var controller := _live_controller(ElementsData.triad(&"founding"))
	controller.allies[0].aftertones = [{"element": "suul", "remaining_rounds": 2, "held": true}]
	_submit_triad(controller, ElementsData.triad(&"founding"))
	assert_bool(controller.enemies[0].aftertones[0]["anchored"]).is_true()
	assert_int(controller.duration_freeze_until_round).is_equal(controller.round_number + 1)
	controller.allies[0].aftertones.append({"element": "nul", "remaining_rounds": 1, "anchored": true})
	controller.round_number = controller.duration_freeze_until_round + 1
	controller._expire_temporary_effects()
	assert_bool(bool(controller.allies[0].aftertones[0].get("anchored", false))).is_false()
	assert_bool(bool(controller.allies[0].aftertones[1].get("anchored", false))).is_true()


func test_vault_caster_aftertones_are_anchored() -> void:
	var controller := _live_controller(ElementsData.triad(&"vault"))
	controller.allies[0].aftertones = [{"remaining_rounds": 2}]
	var grid := GridBattlefieldModel.new()
	grid.configure(controller.rules)
	grid.build_grid(_vault_ground())
	grid.setup(controller.allies, controller.enemies)
	controller.battlefield = grid
	assert_int(grid.cover_bonus(controller.allies[0], controller.enemies[0])).is_equal(0)
	_submit_triad(controller, ElementsData.triad(&"vault"))
	assert_bool(controller.allies[0].aftertones[0]["anchored"]).is_true()
	assert_int(grid.cover_bonus(controller.allies[0], controller.enemies[0])).is_equal(
		controller.rules.cover_defense_bonus
	)


func _vault_ground() -> TileMapLayer:
	var layer := auto_free(TileMapLayer.new()) as TileMapLayer
	var tile_set := TileSet.new()
	tile_set.tile_size = Vector2i(64, 32)
	var image := Image.create(64, 32, false, Image.FORMAT_RGBA8)
	var source := TileSetAtlasSource.new()
	source.texture = ImageTexture.create_from_image(image)
	source.texture_region_size = Vector2i(64, 32)
	source.create_tile(Vector2i.ZERO)
	tile_set.add_source(source, 0)
	layer.tile_set = tile_set
	layer.set_cell(Vector2i(0, 0), 0, Vector2i.ZERO)
	layer.set_cell(Vector2i(1, 0), 0, Vector2i.ZERO)
	return layer


func test_pyre_converts_dead_enemies_and_spent_aftertones_to_breath() -> void:
	var controller := _live_controller(ElementsData.triad(&"pyre"))
	controller.enemies[0].hp = 1
	controller.spent_aftertones = 1
	_submit_triad(controller, ElementsData.triad(&"pyre"))
	assert_int(controller.allies[0].breath).is_equal(2)


func test_cinderfall_clears_both_sides() -> void:
	var controller := _live_controller(ElementsData.triad(&"cinderfall"))
	controller.allies[0].aftertones = [{"remaining_rounds": 2}]
	controller.enemies[0].aftertones = [{"remaining_rounds": 2}, {"remaining_rounds": 2}]
	_submit_triad(controller, ElementsData.triad(&"cinderfall"))
	assert_int(controller.allies[0].aftertones.size()).is_equal(0)


func test_thunderhead_marks_allies_as_hit() -> void:
	var controller := _live_controller(ElementsData.triad(&"thunderhead"))
	_submit_triad(controller, ElementsData.triad(&"thunderhead"))
	assert_bool(controller.allies[0].defining_effects["hit"]).is_true()
	controller.round_number = controller.thunderhead_hit_until_round + 1
	controller._expire_temporary_effects()
	assert_bool(controller.allies[0].defining_effects.has("hit")).is_false()


func test_dayspring_reveals_the_caster_side() -> void:
	var controller := _live_controller(ElementsData.triad(&"dayspring"))
	_submit_triad(controller, ElementsData.triad(&"dayspring"))
	assert_int(controller.revealed_until_round).is_equal(controller.round_number)


func test_barrow_conceals_the_caster_side() -> void:
	var controller := _live_controller(ElementsData.triad(&"barrow"))
	_submit_triad(controller, ElementsData.triad(&"barrow"))
	assert_int(controller.concealed_until_round).is_equal(controller.round_number)


func test_rivermouth_opens_zone_boundaries_for_the_side() -> void:
	var controller := _live_controller(ElementsData.triad(&"rivermouth"))
	_submit_triad(controller, ElementsData.triad(&"rivermouth"))
	assert_int(controller.allies[0].defining_effects["range_bonus"]).is_equal(1)
	controller.round_number = controller.range_bonus_until_round + 1
	controller._expire_temporary_effects()
	assert_bool(controller.allies[0].defining_effects.has("range_bonus")).is_false()


func test_fruiting_extends_friendly_aftertones() -> void:
	var controller := _live_controller(ElementsData.triad(&"fruiting"))
	controller.allies[0].aftertones = [{"remaining_rounds": 2, "held": true}]
	_submit_triad(controller, ElementsData.triad(&"fruiting"))
	assert_int(controller.allies[0].aftertones[0]["remaining_rounds"]).is_equal(3)


func _live_controller(triad: TriadDefinition) -> CombatController:
	var controller := CombatController.new()
	var ally := BattleActor.new()
	ally.combat_id = &"ally-0"
	ally.side = &"ally"
	ally.attributes["harmony"] = 5
	ally.attributes["pitch"] = 5
	ally.source_member = PartyMember.new()
	ally.source_member.id = "triad-caster"
	var enemy := BattleActor.new()
	enemy.combat_id = &"enemy-0"
	enemy.side = &"enemy"
	controller.allies = [ally]
	controller.enemies = [enemy]
	var ability := AbilityDefinition.new()
	ability.id = "triad-" + String(triad.id)
	ability.element_id = triad.center_element
	ability.elements = triad.elements.duplicate()
	ability.magnitude = &"song"
	ability.power = 1
	var tables := TacticalTables.new()
	tables.abilities[ability.id] = ability
	var loadout := UnitLoadout.create("triad-caster")
	loadout.action_ability_ids.append(ability.id)
	tables.loadouts["triad-caster"] = loadout
	var rules := load("res://data/combat/combat_rules.tres") as CombatRules
	controller.configure([CombatActionCatalog.by_id(&"cast-seam")], BattlefieldModel.create_default(rules), rules, null, [ability], tables)
	controller.start([ally], [enemy], &"triad-live")
	return controller


func _submit_triad(controller: CombatController, triad: TriadDefinition) -> Dictionary:
	return controller.submit_action(
		&"cast-seam",
		controller.enemies[0],
		{"ability_id": "triad-" + String(triad.id), "fizzle": {"agreement_integrity": 100.0, "pitch": 100, "mastery": true}},
	)


func _resolve(element: StringName, aftertones: Array, target_aftertones: Array = [], tempo: int = 0) -> Dictionary:
	return ResolutionScript.resolve({
		"unit": {"id": "caster", "harmony": 10, "aftertones": aftertones, "tempo": tempo},
		"ability": {"id": "bend", "element_id": element, "magnitude": "note", "power": 1, "is_spell": true},
		"target": {"id": "target", "hp": 10, "element_id": "suul", "aftertones": target_aftertones, "tempo": tempo},
	})


func _has_write(result: Dictionary, kind: String) -> bool:
	for write: Dictionary in result.get("writes", []):
		if str(write.get("kind", "")) == kind:
			return true
	return false


func _has_aftertone(result: Dictionary, anchored: bool) -> bool:
	for write: Dictionary in result.get("writes", []):
		if write.get("kind", "") == "aftertones":
			for aftertone: Dictionary in write.get("after", []):
				if bool(aftertone.get("anchored", false)) == anchored:
					return true
	return false


func _aftertone_write_after(result: Dictionary) -> Array:
	for write: Dictionary in result.get("writes", []):
		if write.get("kind", "") == "aftertones":
			return write.get("after", []) as Array
	return []


func _has_held_aftertone(result: Dictionary) -> bool:
	for write: Dictionary in result.get("writes", []):
		if write.get("kind", "") == "aftertones":
			for aftertone: Dictionary in write.get("after", []):
				if bool(aftertone.get("held", false)):
					return true
	return false
