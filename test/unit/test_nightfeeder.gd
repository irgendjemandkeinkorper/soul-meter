extends GdUnitTestSuite
## Vekh concealment cards (Blindside, Shroud, Eclipse Procession), the short-blade and thrown
## cards (Quick Cut, Open Seam, Blinding Throw) and the Nightfeeder kit (Fed in the Dark,
## Blindside Bite, Eclipse Feast) on the Vhorr Hunger engine.

const NO_FIZZLE := {"fizzle": {"harmonic_accord": 100.0, "pitch": 10}}
const FEEDER_CELLS := {"feeder": Vector2i(1, 1), "ally": Vector2i(0, 0), "enemy": Vector2i(2, 1)}


# ─── Blades and grit ─────────────────────────────────────────────────────────


func test_blinding_throw_deals_no_damage_and_blinds_for_one_checkpoint() -> void:
	var battle := _battle({"feeder": Vector2i(0, 1), "ally": Vector2i(0, 0), "enemy": Vector2i(3, 1)})
	var controller: CombatController = battle["controller"]
	var enemy: BattleActor = battle["enemy"]
	var outcome := controller.submit_action(&"blinding-throw", enemy)
	assert_bool(outcome["allowed"]).is_true()
	assert_int(enemy.hp).is_equal(60)
	assert_bool(LightField.is_blinded(enemy)).is_true()
	assert_bool(_saw(battle, &"blinded_applied")).is_true()
	assert_int(_hunger(battle).hunger).is_equal(0)
	_end_round(battle)
	assert_bool(LightField.is_blinded(enemy)).is_false()


func test_blinding_throw_reaches_three_cells() -> void:
	var battle := _battle({"feeder": Vector2i(0, 1), "ally": Vector2i(0, 0), "enemy": Vector2i(4, 1)})
	var controller: CombatController = battle["controller"]
	var refused := controller.query_action(controller.action_by_id(&"blinding-throw"), battle["enemy"])
	assert_str(String(refused["blocked_by"])).is_equal("blocked_by_range")


func test_a_blinded_attacker_gets_no_facing_edge() -> void:
	var battle := _battle(FEEDER_CELLS)
	var controller: CombatController = battle["controller"]
	var feeder: BattleActor = battle["feeder"]
	var enemy: BattleActor = battle["enemy"]
	assert_bool(battle["grid"].set_facing(enemy, &"n")["allowed"]).is_true()
	var open := controller.forecast_context(feeder, enemy, controller.action_by_id(&"quick-cut"))
	assert_str(String((open["facing"] as Dictionary).get("id", ""))).is_equal("side")
	LightField.apply_blinded(feeder, &"someone")
	var blind := controller.forecast_context(feeder, enemy, controller.action_by_id(&"quick-cut"))
	assert_str(String((blind["facing"] as Dictionary).get("id", ""))).is_equal("front")


func test_quick_cut_and_open_seam_seed_hunger() -> void:
	var battle := _battle(FEEDER_CELLS)
	var controller: CombatController = battle["controller"]
	var enemy: BattleActor = battle["enemy"]
	assert_bool(battle["grid"].set_facing(enemy, &"n")["allowed"]).is_true()
	assert_bool(controller.submit_action(&"quick-cut", enemy)["allowed"]).is_true()
	assert_int(_hunger(battle).hunger).is_equal(1)
	assert_array(_hunger(battle).pending_dot_targets).contains([String(enemy.combat_id)])
	assert_bool(controller.submit_action(&"open-seam", enemy)["allowed"]).is_true()
	assert_int(_hunger(battle).hunger).is_equal(2)


func test_open_seam_needs_the_side_or_rear_and_ignores_one_point_of_defense() -> void:
	var battle := _battle(FEEDER_CELLS)
	var controller: CombatController = battle["controller"]
	var feeder: BattleActor = battle["feeder"]
	var enemy: BattleActor = battle["enemy"]
	enemy.defense = 3
	# Feeder at (1,1) strikes eastward; an enemy facing west looks straight at it.
	assert_bool(battle["grid"].set_facing(enemy, &"w")["allowed"]).is_true()
	var refused := controller.query_action(controller.action_by_id(&"open-seam"), enemy)
	assert_str(String(refused["blocked_by"])).is_equal("facing")
	assert_bool(battle["grid"].set_facing(enemy, &"n")["allowed"]).is_true()
	var cut := controller.submit_action(&"quick-cut", enemy)
	assert_bool(cut["allowed"]).is_true()
	var cut_damage := 60 - enemy.hp
	feeder.action_points = 8
	var hp_before := enemy.hp
	var seam := controller.submit_action(&"open-seam", enemy)
	assert_bool(seam["allowed"]).is_true()
	assert_int(hp_before - enemy.hp).is_equal(cut_damage + 1)


# ─── Blindside ───────────────────────────────────────────────────────────────


func test_blindside_prepares_only_its_caster_and_is_spent_by_the_next_working() -> void:
	var battle := _battle(FEEDER_CELLS)
	var controller: CombatController = battle["controller"]
	var feeder: BattleActor = battle["feeder"]
	var enemy: BattleActor = battle["enemy"]
	var wrong := controller.query_action(controller.action_by_id(&"blindside"), battle["ally"], NO_FIZZLE)
	assert_str(String(wrong["blocked_by"])).is_equal("target")
	var outcome := controller.submit_action(&"blindside", feeder, NO_FIZZLE)
	assert_bool(outcome["allowed"]).is_true()
	if bool((outcome["resolution"] as Dictionary)["fizzled"]):
		return
	assert_bool(_saw(battle, &"blindside_armed")).is_true()
	assert_bool(bool(controller.blindside_armed(feeder).get("bite", true))).is_false()
	assert_bool(battle["grid"].set_facing(enemy, &"n")["allowed"]).is_true()
	assert_bool(controller.submit_action(&"quick-cut", enemy)["allowed"]).is_true()
	assert_bool(controller.blindside_armed(feeder).is_empty()).is_true()
	assert_bool(_saw(battle, &"blindside_spent")).is_true()


func test_blindside_expires_after_two_checkpoints() -> void:
	var battle := _battle(FEEDER_CELLS)
	var controller: CombatController = battle["controller"]
	var feeder: BattleActor = battle["feeder"]
	var outcome := controller.submit_action(&"blindside", feeder, NO_FIZZLE)
	if bool((outcome["resolution"] as Dictionary)["fizzled"]):
		return
	_end_round(battle)
	assert_bool(controller.blindside_armed(feeder).is_empty()).is_false()
	_end_round(battle)
	assert_bool(controller.blindside_armed(feeder).is_empty()).is_true()
	assert_bool(_saw(battle, &"blindside_expired")).is_true()


# ─── Nightfeeder T2: Blindside Bite ──────────────────────────────────────────


func test_blindside_bite_belongs_to_vhorr() -> void:
	var battle := _battle(FEEDER_CELLS, "Kero")
	var controller: CombatController = battle["controller"]
	var refused := controller.query_action(controller.action_by_id(&"blindside-bite"), battle["feeder"], NO_FIZZLE)
	assert_str(String(refused["blocked_by"])).is_equal("class_resource")


func test_blindside_bite_lets_open_seam_land_on_a_blinded_target_from_the_front_as_flanked() -> void:
	var battle := _battle(FEEDER_CELLS)
	var controller: CombatController = battle["controller"]
	var feeder: BattleActor = battle["feeder"]
	var enemy: BattleActor = battle["enemy"]
	assert_bool(battle["grid"].set_facing(enemy, &"w")["allowed"]).is_true()
	var bite := controller.submit_action(&"blindside-bite", feeder, NO_FIZZLE)
	assert_bool(bite["allowed"]).is_true()
	if bool((bite["resolution"] as Dictionary)["fizzled"]):
		return
	assert_bool(bool(controller.blindside_armed(feeder).get("bite", false))).is_true()
	# Not yet Blinded: the angle still rules.
	var refused := controller.query_action(controller.action_by_id(&"open-seam"), enemy)
	assert_str(String(refused["blocked_by"])).is_equal("facing")
	LightField.apply_blinded(enemy, &"an-ally")
	var forecast := controller.forecast_context(feeder, enemy, controller.action_by_id(&"open-seam"))
	assert_str(String((forecast["facing"] as Dictionary).get("id", ""))).is_equal("side")
	var seam := controller.submit_action(&"open-seam", enemy)
	assert_bool(seam["allowed"]).is_true()
	assert_bool(bool(seam["flanked"])).is_true()
	assert_bool(controller.blindside_armed(feeder).is_empty()).is_true()
	# Consumed by the attempt: a second Open Seam from the front is refused again.
	feeder.action_points = 8
	var again := controller.query_action(controller.action_by_id(&"open-seam"), enemy)
	assert_str(String(again["blocked_by"])).is_equal("facing")


# ─── Shroud and Eclipse Procession ───────────────────────────────────────────


func test_shroud_conceals_friendly_signatures_inside_for_two_checkpoints() -> void:
	var battle := _battle({"feeder": Vector2i(0, 1), "ally": Vector2i(2, 0), "enemy": Vector2i(3, 2)})
	var controller: CombatController = battle["controller"]
	var ally: BattleActor = battle["ally"]
	var enemy: BattleActor = battle["enemy"]
	var outcome := controller.submit_action(&"shroud", null, _with_cells([[2, 1]], NO_FIZZLE))
	assert_bool(outcome["allowed"]).is_true()
	if bool(outcome["fizzled"]):
		return
	assert_bool(_saw(battle, &"shroud_raised")).is_true()
	assert_bool(_visible(controller, ally)).is_false()
	assert_bool(_visible(controller, enemy)).is_true()
	assert_bool(_visible(controller, battle["feeder"])).is_true()
	assert_bool(controller.light.is_lit_cell(Vector2i(2, 1))).is_false()
	var snapshot := controller.snapshot()
	assert_int(((snapshot["light"] as Dictionary)["shrouds"] as Array).size()).is_equal(1)
	assert_int(((snapshot["light"] as Dictionary)["fields"] as Array).size()).is_equal(0)
	_end_round(battle)
	assert_bool(_visible(controller, ally)).is_false()
	_end_round(battle)
	assert_bool(_visible(controller, ally)).is_true()
	assert_bool(_saw(battle, &"shroud_expired")).is_true()


func test_revelation_beats_a_shroud_x1() -> void:
	var battle := _battle({"feeder": Vector2i(0, 1), "ally": Vector2i(2, 0), "enemy": Vector2i(3, 2)})
	var controller: CombatController = battle["controller"]
	var ally: BattleActor = battle["ally"]
	var outcome := controller.submit_action(&"shroud", null, _with_cells([[2, 1]], NO_FIZZLE))
	if bool(outcome["fizzled"]):
		return
	assert_bool(_visible(controller, ally)).is_false()
	LightField.apply_exposed(ally, &"sul")
	assert_bool(_visible(controller, ally)).is_true()


func test_eclipse_procession_follows_its_caster_and_spends_the_refrain() -> void:
	var battle := _battle({"feeder": Vector2i(1, 1), "ally": Vector2i(3, 0), "enemy": Vector2i(6, 2)}, "Vhorr", 2)
	var controller: CombatController = battle["controller"]
	var feeder: BattleActor = battle["feeder"]
	var ally: BattleActor = battle["ally"]
	var wrong := controller.query_action(controller.action_by_id(&"eclipse-procession"), null, _with_cells([[2, 1]], NO_FIZZLE))
	assert_str(String(wrong["blocked_by"])).is_equal("target")
	var outcome := controller.submit_action(&"eclipse-procession", null, _with_cells([[1, 1]], NO_FIZZLE))
	assert_bool(outcome["allowed"]).is_true()
	if bool(outcome["fizzled"]):
		return
	assert_bool(_visible(controller, ally)).is_false()
	assert_bool(battle["grid"].displace(feeder, Vector2i(0, 2))["allowed"]).is_true()
	assert_bool(_visible(controller, ally)).is_true()
	assert_bool(battle["grid"].displace(feeder, Vector2i(2, 2))["allowed"]).is_true()
	assert_bool(_visible(controller, ally)).is_false()
	feeder.action_points = 8
	feeder.breath = 60
	var again := controller.query_action(controller.action_by_id(&"eclipse-procession"), null, _with_cells([[2, 2]], NO_FIZZLE))
	assert_str(String(again["blocked_by"])).is_equal("refrain_spent")
	_end_round(battle)
	assert_bool(_visible(controller, ally)).is_true()


# ─── Nightfeeder T1: Fed in the Dark ─────────────────────────────────────────


func test_a_jam_cannot_trace_hunger_to_a_source_hidden_by_its_own_veil() -> void:
	var battle := _battle(FEEDER_CELLS)
	var controller: CombatController = battle["controller"]
	var feeder: BattleActor = battle["feeder"]
	var enemy: BattleActor = battle["enemy"]
	assert_bool(battle["grid"].set_facing(enemy, &"n")["allowed"]).is_true()
	assert_bool(controller.submit_action(&"quick-cut", enemy)["allowed"]).is_true()
	LightField.apply_veiled(feeder, feeder.combat_id)
	var refused := controller.request_cancel(enemy.combat_id, feeder.combat_id)
	assert_str(String(refused["blocked_by"])).is_equal("source_untraceable")
	assert_int(controller.deferred_entries().size()).is_equal(1)
	# Revelation ends the cover.
	LightField.apply_exposed(feeder, enemy.combat_id)
	var jammed := controller.request_cancel(enemy.combat_id, feeder.combat_id)
	assert_bool(jammed["allowed"]).is_true()
	assert_int(controller.deferred_entries().size()).is_equal(0)


func test_a_veil_from_someone_else_does_not_hide_the_source() -> void:
	var battle := _battle(FEEDER_CELLS)
	var controller: CombatController = battle["controller"]
	var feeder: BattleActor = battle["feeder"]
	var enemy: BattleActor = battle["enemy"]
	assert_bool(battle["grid"].set_facing(enemy, &"n")["allowed"]).is_true()
	assert_bool(controller.submit_action(&"quick-cut", enemy)["allowed"]).is_true()
	LightField.apply_veiled(feeder, battle["ally"].combat_id)
	assert_bool(controller.request_cancel(enemy.combat_id, feeder.combat_id)["allowed"]).is_true()


func test_own_shroud_hides_the_source_but_not_a_kero_caster() -> void:
	var battle := _battle({"feeder": Vector2i(1, 1), "ally": Vector2i(0, 0), "enemy": Vector2i(2, 1)}, "Kero")
	var controller: CombatController = battle["controller"]
	var feeder: BattleActor = battle["feeder"]
	var enemy: BattleActor = battle["enemy"]
	assert_bool(controller.enqueue_deferred({
		"source_id": String(feeder.combat_id), "label": "hunger_dot", "delay_rounds": 1,
		"effect": {"writes": [{"kind": "dot", "target_id": String(enemy.combat_id), "amount": 1}]},
	})["allowed"]).is_true()
	controller.light.create_shroud(feeder.combat_id, Vector2i(1, 1), 1, 1)
	assert_bool(_visible(controller, feeder)).is_false()
	# Not a Hunger owner: the passive is Vhorr's alone.
	assert_bool(controller.request_cancel(enemy.combat_id, feeder.combat_id)["allowed"]).is_true()


# ─── Nightfeeder T3: Eclipse Feast ───────────────────────────────────────────


func test_eclipse_feast_needs_the_triad_gate() -> void:
	var battle := _battle(FEEDER_CELLS, "Vhorr", 0)
	var controller: CombatController = battle["controller"]
	var gated := controller.query_action(controller.action_by_id(&"eclipse-feast"), null, _with_cells([[1, 1]], NO_FIZZLE))
	assert_str(String(gated["blocked_by"])).is_equal("var_harmony")


func test_eclipse_feast_ticks_every_owned_hunger_chain_inside_once_more_at_the_checkpoint() -> void:
	var battle := _battle(FEEDER_CELLS, "Vhorr", 2)
	var controller: CombatController = battle["controller"]
	var feeder: BattleActor = battle["feeder"]
	var enemy: BattleActor = battle["enemy"]
	assert_bool(battle["grid"].set_facing(enemy, &"n")["allowed"]).is_true()
	assert_bool(controller.submit_action(&"quick-cut", enemy)["allowed"]).is_true()
	var after_cut := enemy.hp
	assert_int(_hunger(battle).hunger).is_equal(1)
	feeder.action_points = 8
	var outcome := controller.submit_action(&"eclipse-feast", null, _with_cells([[1, 1]], NO_FIZZLE))
	assert_bool(outcome["allowed"]).is_true()
	if bool(outcome["fizzled"]):
		return
	assert_bool(bool(outcome["feast_armed"])).is_true()
	_end_round(battle)
	# One extra tick at the checkpoint (1) plus the queued chain firing at the round start (1).
	assert_bool(_saw(battle, &"eclipse_feast_tick")).is_true()
	assert_int(enemy.hp).is_equal(after_cut - 2)
	assert_int(_hunger(battle).hunger).is_equal(3)
	# One checkpoint only.
	var before_second := enemy.hp
	_end_round(battle)
	assert_int((battle["events"] as Array[StringName]).count(&"eclipse_feast_tick")).is_equal(1)
	assert_int(enemy.hp).is_equal(before_second - 3)


func test_eclipse_feast_skips_a_chain_whose_target_stands_outside_the_shroud() -> void:
	# After the Procession starts the two are carried apart further than an enemy turn can
	# close, so the chain's target is outside the moving shroud at the checkpoint.
	var battle := _battle({"feeder": Vector2i(1, 1), "ally": Vector2i(1, 0), "enemy": Vector2i(2, 1)}, "Vhorr", 2)
	var controller: CombatController = battle["controller"]
	var feeder: BattleActor = battle["feeder"]
	var enemy: BattleActor = battle["enemy"]
	assert_bool(battle["grid"].set_facing(enemy, &"n")["allowed"]).is_true()
	assert_bool(controller.submit_action(&"quick-cut", enemy)["allowed"]).is_true()
	feeder.action_points = 8
	var outcome := controller.submit_action(&"eclipse-feast", null, _with_cells([[1, 1]], NO_FIZZLE))
	if bool(outcome["fizzled"]):
		return
	assert_bool(battle["grid"].displace(feeder, Vector2i(6, 1))["allowed"]).is_true()
	assert_bool(battle["grid"].displace(enemy, Vector2i(0, 1))["allowed"]).is_true()
	var after_cut := enemy.hp
	_end_round(battle)
	assert_bool(_saw(battle, &"eclipse_feast_tick")).is_false()
	assert_int(enemy.hp).is_equal(after_cut - 1)


# ─── Save ─────────────────────────────────────────────────────────────────────


func test_armed_blindside_and_feast_survive_a_save_round_trip() -> void:
	var battle := _battle(FEEDER_CELLS, "Vhorr", 2)
	var controller: CombatController = battle["controller"]
	var feeder: BattleActor = battle["feeder"]
	var bite := controller.submit_action(&"blindside-bite", feeder, NO_FIZZLE)
	if bool((bite["resolution"] as Dictionary)["fizzled"]):
		return
	feeder.action_points = 8
	var feast := controller.submit_action(&"eclipse-feast", null, _with_cells([[1, 1]], NO_FIZZLE))
	if bool(feast["fizzled"]):
		return
	var data := controller.class_resources_to_dict()
	assert_bool(data.has("__vekh__")).is_true()
	var restored := _battle(FEEDER_CELLS, "Vhorr", 2)
	var other: CombatController = restored["controller"]
	other.restore_class_resources(data)
	assert_bool(bool(other.blindside_armed(restored["feeder"]).get("bite", false))).is_true()
	assert_int(other.light.shrouds().size()).is_equal(1)
	assert_bool(_visible(other, restored["ally"])).is_false()


# ─── helpers ──────────────────────────────────────────────────────────────────


func _hunger(battle: Dictionary) -> VhorrHunger:
	return (battle["feeder"] as BattleActor).class_resource as VhorrHunger


func _visible(controller: CombatController, actor: BattleActor) -> bool:
	var snapshot := controller.snapshot()
	for row: Dictionary in (snapshot["allies"] as Array) + (snapshot["enemies"] as Array):
		if String(row.get("id", "")) == String(actor.combat_id):
			return bool(row.get("discord_signatures_visible", true))
	assert_bool(false).override_failure_message("Combatant missing from snapshot.").is_true()
	return true


func _battle(cells: Dictionary, patron: String = "Vhorr", harmony: int = 0) -> Dictionary:
	var rules := (load("res://data/combat/combat_rules.tres") as CombatRules).duplicate(true) as CombatRules
	rules.use_charge_time = false
	rules.base_action_points = 8
	var grid := GridBattlefieldModel.new()
	grid.configure(rules)
	grid.build_grid(_grid_ground())
	var feeder := _actor("Feeder", 60, 12, 0)
	feeder.breath = 60
	feeder.attributes = {"harmony": harmony, "alacrity": 4}
	feeder.defining_effects = {"hit": true}
	feeder.source_member = _member("feeder-test", patron, 60)
	var ally := _actor("Second", 60, 8, 0)
	ally.breath = 30
	ally.source_member = _member("second-test", "Kero", 30)
	var enemy := _actor("Dummy", 60, 1, 0)
	var placements := {feeder: cells["feeder"], ally: cells["ally"], enemy: cells["enemy"]}
	var enemies: Array[BattleActor] = [enemy]
	assert_bool(grid.configure_initial_cells(placements)["allowed"]).is_true()
	var controller := CombatController.new()
	controller.configure(CombatActionCatalog.all(), grid, rules)
	var events: Array[StringName] = []
	controller.event_emitted.connect(func(event: CombatEvent) -> void: events.append(event.type))
	controller.start([feeder, ally], enemies, &"nightfeeder-test")
	return {"controller": controller, "feeder": feeder, "ally": ally, "enemy": enemy, "grid": grid, "events": events}


func _member(id: String, patron: String, breath_max: int) -> PartyMember:
	var member := PartyMember.new()
	member.id = id
	member.patron = patron
	member.breath_max = breath_max
	return member


## The feeder acts first each round; ending the feeder's and ally's turns lets the enemy act
## and closes the round (one checkpoint), then the next round opens on the feeder.
func _end_round(battle: Dictionary) -> void:
	var controller: CombatController = battle["controller"]
	var guard := 0
	while guard < 4:
		guard += 1
		assert_bool(controller.end_turn()).is_true()
		if controller.active_actor() == battle["feeder"]:
			return
	assert_bool(false).override_failure_message("Round did not return to the feeder.").is_true()


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


## Seven by three cells, flat.
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
