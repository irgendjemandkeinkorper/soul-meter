extends GdUnitTestSuite

const ENCOUNTER_IDS: Array[StringName] = [
	EncounterIds.PHASE2_DEMON,
	EncounterIds.PHASE2_UNDEAD,
	EncounterIds.PHASE2_MIXED_WHIPSAW,
	EncounterIds.PHASE2_SPEECH_WINNABLE,
	EncounterIds.PHASE2_STABILIZER_SHOWCASE,
]
const BUILD_IDS: Array[StringName] = [&"martial", &"caster", &"talker", &"balanced-refusal"]


## Owner 2026-11-03 (item 33): fights roll fresh dice and can crit, so clearability is a win
## rate, not one roll: every build must win at least WIN_RATE_FLOOR of SEEDED_FIGHTS fights
## per encounter, each seeded like a real fight's dice.
const SEEDED_FIGHTS := 40
const WIN_RATE_FLOOR := 0.8


func test_all_four_build_fixtures_clear_all_five_gate_t1_encounters() -> void:
	for build_id: StringName in BUILD_IDS:
		for encounter_id: StringName in ENCOUNTER_IDS:
			var wins := 0
			var lost: Dictionary = {}
			for fight: int in SEEDED_FIGHTS:
				var result := _self_play(encounter_id, build_id, true, _fight_seed(fight))
				if int(result.get("result", -1)) == CombatController.ResultState.VICTORY:
					wins += 1
				elif lost.is_empty():
					lost = result
				if build_id == &"caster":
					assert_int(int(result.get("cast_resolutions", 0)))\
						.override_failure_message("Caster never resolved a spell in %s" % encounter_id)\
						.is_greater(0)
			print("GATE_T1 grid=%s build=%s encounter=%s wins=%d/%d" % [
				"hex" if GridMetric.hex() else "square", build_id, encounter_id, wins, SEEDED_FIGHTS,
			])
			assert_float(float(wins) / float(SEEDED_FIGHTS))\
				.override_failure_message("%s cleared %s in %d of %d fights; first loss: %s" % [
					build_id, encounter_id, wins, SEEDED_FIGHTS, lost])\
				.is_greater_equal(WIN_RATE_FLOOR)


## The n-th gate fight's dice: spread, non-zero, and the same every run.
static func _fight_seed(fight: int) -> int:
	return (fight + 1) * 104729


func test_talker_uses_the_authored_speech_resolution() -> void:
	var result := _self_play(EncounterIds.PHASE2_SPEECH_WINNABLE, &"talker", true)
	assert_str(String(result.get("outcome_id", ""))).is_equal("released")
	assert_array(result.get("actions", [])).contains([&"phase2-release-binding"])


func test_stabilizer_showcase_rewards_stillpoint_center_holding() -> void:
	var held := _self_play(EncounterIds.PHASE2_STABILIZER_SHOWCASE, &"balanced-refusal", true)
	var ignored := _self_play(EncounterIds.PHASE2_STABILIZER_SHOWCASE, &"balanced-refusal", false)
	assert_int(int(held.get("remaining_hp", 0)))\
		.override_failure_message("Stillpoint did not improve the stabilizer outcome")\
		.is_greater(int(ignored.get("remaining_hp", 0)))
	assert_int(int(held.get("balance_locks", 0))).is_greater(0)


func _self_play(
	encounter_id: StringName, build_id: StringName, use_stillpoint: bool, fight_seed: int = 0
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
	var cast_abilities: Array[AbilityDefinition] = []
	var tactical_tables: TacticalTables = null
	if build_id == &"caster":
		cast_abilities = [TacticalTables.shared().ability(TacticalIds.ABILITY_NOTE_ZHUR)]
		tactical_tables = _cast_tables_for_actor(ally, cast_abilities, "gate-t1-caster")

	var result := {
		"result": -1,
		"outcome_id": &"",
		"actions": [],
		"balance_locks": 0,
		"balance_changes": [],
		"balance_bands": [],
		"damage": [],
		"cast_resolutions": 0,
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
				var resolution: Dictionary = event.data.get("resolution", {})
				if str(resolution.get("ability_id", "")).begins_with("note-"):
					result["cast_resolutions"] = int(result["cast_resolutions"]) + 1
				if event.target_id == ally.combat_id:
					result["damage"].append(int(event.data.get("damage", 0)))
			elif event.type == &"balance_locked":
				result["balance_locks"] = int(result["balance_locks"]) + 1
			elif event.type == &"balance_changed":
				result["balance_changes"].append(int(event.data.get("balance", 0)))
			elif event.type == &"balance_band_changed":
				result["balance_bands"].append(StringName(event.data.get("band_id", "")))
	)
	controller.configure(
		actions,
		_grid_model(2, 4),
		_ct_rules(),
		null,
		cast_abilities,
		tactical_tables,
	)
	controller.fight_seed = fight_seed
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
			if build_id == &"caster" and int(result["cast_resolutions"]) == 0:
				action_id = &"gate-t1-cast"
			elif build_id == &"balanced-refusal":
				action_id = &"gate-t1-neutral-attack"
			elif build_id == &"talker" and encounter_id == EncounterIds.PHASE2_SPEECH_WINNABLE:
				action_id = &"phase2-release-binding"
			var options := (
				{"ability_id": "note-zhur"} if action_id == &"gate-t1-cast" else {}
			)
			if _close_in(controller, ally, target, action_id, options):
				guard += 1
				continue
			var submitted := controller.submit_action(action_id, target, options)
			if not bool(submitted.get("allowed", false)):
				result["refusal"] = submitted
				break
		guard += 1

	result["remaining_hp"] = ally.hp
	result["turns"] = guard
	return result


## Positional competence (owner 2026-08-24, with #169's to-hit): a representative
## player faces their target. Without this the fixtures donate free flank arcs to
## the live enemy positional AI and stop representing play. The model names the facing, so
## the same helper serves the square grid and hexes (owner item 34).
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
	battlefield.set_facing(ally, GridBattlefieldModel.facing_for_delta(delta))


## Hexes (owner item 34): the board's two columns stand one cell apart, which is two hexes, and
## melee needs touching hexes. A foe that holds back is then out of reach of a player who never
## moves, so on hexes the representative player first walks to the cheapest stand from which
## the action is allowed (or, failing that, as close as the turn allows). Squares seat the foes
## adjacent, so this never runs there and the square gate is unchanged. True when it moved.
func _close_in(
	controller: CombatController, ally: BattleActor, target: BattleActor, action_id: StringName, options: Dictionary
) -> bool:
	if not GridMetric.hex() or target == null:
		return false
	var action := controller.action_by_id(action_id)
	var direct := controller.query_action_for(ally, action, target, options)
	if bool(direct.get("allowed", false)):
		return false
	if not StringName(str(direct.get("blocked_by", ""))) in [&"position", &"blocked_by_range"]:
		return false
	var battlefield := controller.battlefield
	var target_cell: Variant = battlefield.cell_of(target)
	var here: Variant = battlefield.cell_of(ally)
	if not (target_cell is Vector2i) or not (here is Vector2i):
		return false
	var best := {}
	var best_key := []
	for row: Dictionary in controller.reachable_for(ally):
		var cell: Vector2i = battlefield.describe_position(StringName(row["destination"]))["cell"]
		battlefield.probe_cell(ally, cell)
		var allowed := bool(controller.query_action_for(ally, action, target, options).get("allowed", false))
		battlefield.clear_probe(ally)
		var distance := GridMetric.distance(cell, target_cell as Vector2i)
		# Allowed stands first, then nearer the foe, then cheaper, then by name.
		var key := [0 if allowed else 1, distance, int(row.get("ct_cost", 0)), String(row["destination"])]
		if best.is_empty() or key < best_key:
			best = row
			best_key = key
	if best.is_empty() or (int(best_key[0]) == 1 and int(best_key[1]) >= GridMetric.distance(here as Vector2i, target_cell as Vector2i)):
		return false
	var moved := controller.submit_action(CombatController.ACTION_MOVE, null, {"destination": best["destination"]})
	return bool(moved.get("allowed", false))


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
	actor.source_member = PartyMember.new()
	actor.source_member.id = String(build_id)
	if build_id == &"caster":
		actor.breath = 99
	return actor


## Gate T's caster uses the shipped CAST seam and the loadout-authored Zhur Note.
func _caster_fixture_action() -> CombatAction:
	var action := CombatActionCatalog.by_id(&"cast-seam")
	action.id = &"gate-t1-cast"
	action.display_name = "Gate T Cast"
	return action


func _cast_tables_for_actor(
	actor: BattleActor, abilities: Array[AbilityDefinition], unit_id: String
) -> TacticalTables:
	actor.source_member = PartyMember.new()
	actor.source_member.id = unit_id
	var tables := TacticalTables.new()
	var loadout := UnitLoadout.create(unit_id)
	for ability: AbilityDefinition in abilities:
		tables.abilities[ability.id] = ability
		loadout.action_ability_ids.append(ability.id)
	tables.loadouts[unit_id] = loadout
	return tables


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
