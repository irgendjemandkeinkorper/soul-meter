extends GdUnitTestSuite

const ENCOUNTER_IDS: Array[StringName] = [
	EncounterIds.PHASE2_DEMON,
	EncounterIds.PHASE2_UNDEAD,
	EncounterIds.PHASE2_MIXED_WHIPSAW,
	EncounterIds.PHASE2_SPEECH_WINNABLE,
	EncounterIds.PHASE2_STABILIZER_SHOWCASE,
]
const BUILD_IDS: Array[StringName] = [&"martial", &"caster", &"talker", &"balanced-refusal"]


func test_all_four_build_fixtures_clear_all_five_gate_t1_encounters() -> void:
	for build_id: StringName in BUILD_IDS:
		for encounter_id: StringName in ENCOUNTER_IDS:
			var result := _self_play(encounter_id, build_id, true)
			assert_int(int(result.get("result", -1)))\
				.override_failure_message("%s did not clear %s: %s" % [build_id, encounter_id, result])\
				.is_equal(CombatController.ResultState.VICTORY)


func test_talker_uses_the_authored_speech_resolution() -> void:
	var result := _self_play(EncounterIds.PHASE2_SPEECH_WINNABLE, &"talker", true)
	assert_str(String(result.get("outcome_id", ""))).is_equal("released")
	assert_array(result.get("actions", [])).contains([&"phase2-release-binding"])


func test_stabilizer_showcase_rewards_stillpoint_center_holding() -> void:
	var held := _self_play(EncounterIds.PHASE2_STABILIZER_SHOWCASE, &"balanced-refusal", true)
	var ignored := _self_play(EncounterIds.PHASE2_STABILIZER_SHOWCASE, &"balanced-refusal", false)
	assert_int(int(held.get("remaining_hp", 0)))\
		.override_failure_message("Stillpoint made the stabilizer outcome worse: %s vs %s" % [held, ignored])\
		.is_greater_equal(int(ignored.get("remaining_hp", 0)))
	assert_int(int(held.get("balance_locks", 0))).is_greater(0)


func _self_play(
	encounter_id: StringName, build_id: StringName, use_stillpoint: bool
) -> Dictionary:
	var ally := _build_actor(build_id)
	var enemies := EncounterCatalog.make_actors(encounter_id)
	var controller := CombatController.new()
	var actions := CombatActionCatalog.all()
	for row: Dictionary in EncounterCatalog.context_actions(encounter_id):
		actions.append(CombatAction.from_context_row(row))
	if build_id == &"caster":
		actions.append(_caster_fixture_action())
	elif build_id == &"balanced-refusal":
		actions.append(_neutral_attack_fixture_action())

	var result := {
		"result": -1,
		"outcome_id": &"",
		"actions": [],
		"balance_locks": 0,
		"balance_changes": [],
		"balance_bands": [],
		"damage": [],
	}
	controller.battle_finished.connect(
		func(state: CombatController.ResultState, outcome_id: StringName) -> void:
			result["result"] = state
			result["outcome_id"] = outcome_id
	)
	controller.event_emitted.connect(
		func(event: CombatEvent) -> void:
			if event.type == &"action_resolved":
				result["actions"].append(StringName(event.data.get("action_id", "")))
				if event.target_id == ally.combat_id:
					result["damage"].append(int(event.data.get("damage", 0)))
			elif event.type == &"balance_locked":
				result["balance_locks"] = int(result["balance_locks"]) + 1
			elif event.type == &"balance_changed":
				result["balance_changes"].append(int(event.data.get("balance", 0)))
			elif event.type == &"balance_band_changed":
				result["balance_bands"].append(StringName(event.data.get("band_id", "")))
	)
	controller.configure(actions, _grid_model(2, 4), _ct_rules())
	controller.start([ally], enemies, encounter_id)

	var guard := 0
	while controller.state != CombatController.State.FINISHED and guard < 160:
		if controller.state == CombatController.State.ALLY_TURN:
			if build_id == &"balanced-refusal" and use_stillpoint:
				var stillpoint := ElementsData.triad(&"stillpoint")
				controller.apply_balance_effect(stillpoint.unique_effect_parameters, ally)
			var target := _first_living(enemies)
			_face_toward(controller, ally, target)
			var action_id := &"strike"
			if build_id == &"caster":
				action_id = &"gate-t1-cast"
			elif build_id == &"balanced-refusal":
				action_id = &"gate-t1-neutral-attack"
			elif build_id == &"talker" and encounter_id == EncounterIds.PHASE2_SPEECH_WINNABLE:
				action_id = &"phase2-release-binding"
			var submitted := controller.submit_action(action_id, target)
			if not bool(submitted.get("allowed", false)):
				result["refusal"] = submitted
				break
		guard += 1

	result["remaining_hp"] = ally.hp
	result["turns"] = guard
	return result


const _FACING_ORDER: Array[StringName] = [&"e", &"se", &"s", &"sw", &"w", &"nw", &"n", &"ne"]


## Positional competence (owner 2026-08-24, with #169's to-hit): a representative
## player faces their target. Without this the fixtures donate free flank arcs to
## the live enemy positional AI and stop representing play.
func _face_toward(controller: CombatController, ally: BattleActor, target: BattleActor) -> void:
	if target == null:
		return
	var battlefield := controller.battlefield
	var ally_position: Dictionary = battlefield.describe_position(battlefield.position_of(ally))
	var target_position: Dictionary = battlefield.describe_position(battlefield.position_of(target))
	if not ally_position.has("cell") or not target_position.has("cell"):
		return
	var delta: Vector2i = (target_position["cell"] as Vector2i) - (ally_position["cell"] as Vector2i)
	if delta == Vector2i.ZERO:
		return
	var index := int(round(atan2(delta.y, delta.x) / (PI / 4.0)))
	index = ((index % _FACING_ORDER.size()) + _FACING_ORDER.size()) % _FACING_ORDER.size()
	battlefield.set_facing(ally, _FACING_ORDER[index])


func _build_actor(build_id: StringName) -> BattleActor:
	var rows := {
		&"martial": {"hp": 52, "attack": 11, "defense": 6, "edge": 4},
		&"caster": {"hp": 48, "attack": 9, "defense": 5, "edge": 5},
		&"talker": {"hp": 50, "attack": 9, "defense": 6, "edge": 4},
		&"balanced-refusal": {"hp": 52, "attack": 9, "defense": 4, "edge": 3},
	}
	var row: Dictionary = rows[build_id]
	var actor := BattleActor.new()
	actor.display_name = String(build_id)
	actor.max_hp = int(row["hp"])
	actor.hp = actor.max_hp
	actor.attack = int(row["attack"])
	actor.defense = int(row["defense"])
	actor.attributes = {&"edge": int(row["edge"])}
	return actor


## Gate T's parallel-run fixtures are explicitly test-only. This promotes the existing Cast
## seam with its authored cost/verb/range into a single-element attack so the real elemental
## resolution path is exercised without shipping a placeholder spell or choosing player canon.
func _caster_fixture_action() -> CombatAction:
	var action := CombatActionCatalog.by_id(&"cast-seam")
	action.id = &"gate-t1-cast"
	action.display_name = "Gate T Elemental Note"
	action.kind = CombatAction.Kind.ATTACK
	action.element_id = &"strom"
	return action


## A control attack for the stabilizer comparison. Strike's automatic 10-point centre pull is
## removed so the control does not receive centre-holding for free; cost and damage stay authored.
func _neutral_attack_fixture_action() -> CombatAction:
	var action := CombatActionCatalog.by_id(&"strike")
	action.id = &"gate-t1-neutral-attack"
	action.display_name = "Gate T Neutral Attack"
	action.center_pull = 0
	return action


func _first_living(actors: Array[BattleActor]) -> BattleActor:
	for actor: BattleActor in actors:
		if actor.is_alive():
			return actor
	return null


func _ct_rules() -> CombatRules:
	var rules := CombatRules.new()
	rules.use_charge_time = true
	rules.base_charge_speed = 25
	rules.attribute_points_per_speed = 2
	return rules


func _grid_model(width: int, height: int) -> GridBattlefieldModel:
	var tile_set := TileSet.new()
	tile_set.tile_size = Vector2i(64, 32)
	var image := Image.create(64, 32, false, Image.FORMAT_RGBA8)
	var source := TileSetAtlasSource.new()
	source.texture = ImageTexture.create_from_image(image)
	source.texture_region_size = Vector2i(64, 32)
	source.create_tile(Vector2i.ZERO)
	tile_set.add_source(source, 0)
	var ground := auto_free(TileMapLayer.new()) as TileMapLayer
	ground.tile_set = tile_set
	for y in height:
		for x in width:
			ground.set_cell(Vector2i(x, y), 0, Vector2i.ZERO)
	var model := GridBattlefieldModel.new()
	model.configure(_ct_rules())
	model.build_grid(ground)
	return model
