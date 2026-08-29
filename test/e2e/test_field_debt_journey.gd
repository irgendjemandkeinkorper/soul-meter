extends GdUnitTestSuite
## Happy-path coverage for the first immediately playable commission:
## accept → travel gate → defeat the field mob → loot proof → choose one reward.

const BattleScript := preload("res://globals/battle.gd")

var original_flags: Dictionary
var original_inventory: Dictionary
var original_reputation: Dictionary
var original_quests: Dictionary
var original_soul: float


func before_test() -> void:
	original_flags = GameState.flags.duplicate(true)
	original_inventory = GameState.inventory.serialize()
	original_reputation = Reputation.to_dict().duplicate(true)
	original_quests = QuestRegistry.to_dict().duplicate(true)
	original_soul = GameState.soul_meter
	GameState.flags.clear()
	GameState._seed_demo_data()
	GameState.soul_meter = 50.0
	Reputation.from_dict({})
	QuestRegistry.reset()


func after_test() -> void:
	GameState.flags = original_flags
	GameState.inventory.clear()
	GameState.inventory.deserialize(original_inventory)
	GameState.inventory_changed.emit()
	GameState.soul_meter = original_soul
	Reputation.from_dict(original_reputation)
	QuestRegistry.reset()
	QuestRegistry.from_dict(original_quests)


func test_accept_defeat_loot_return_and_choose_companies_reward() -> void:
	QuestRegistry.offer(QuestRegistry.FIELD_DEBT)
	assert_bool(QuestRegistry.is_active(QuestRegistry.FIELD_DEBT)).is_true()
	assert_bool(GameState.get_flag("tutorial_road_open")).is_true()

	var runner := scene_runner("res://world/test_room.tscn")
	await runner.simulate_frames(5)
	var proof: Pickup = runner.find_child("FieldDebtProof", true, false)
	assert_bool(proof._is_unlocked()).is_false()

	var battle := BattleScript.new()
	auto_free(battle)
	battle.start(&"bog-wight")
	battle.enemies[0].hp = 1
	# Grid battles roll to-hit (#169/#98) — strike until the battle ends.
	while not battle.ended:
		assert_bool(battle.use_action(BattleScript.ACTION_STRIKE)).is_true()
	assert_bool(GameState.get_flag("defeated_bog_wight")).is_true()
	assert_bool(proof._is_unlocked()).is_true()

	var player: Player = runner.find_child("Player", true, false)
	player.global_position = proof.global_position
	# Pickups are interactions now (E to take); drive the interaction directly,
	# the same pattern test_interactive_props uses.
	proof._apply_interaction()
	await runner.simulate_frames(10)
	assert_int(GameState.item_count(ItemIds.MATERIALS_LOAMROOT_SPRIG)).is_equal(1)
	assert_bool(GameState.get_flag("field_debt_proof_looted")).is_true()
	assert_bool(QuestRegistry.flags_met(QuestRegistry.FIELD_DEBT)).is_true()

	assert_bool(QuestRegistry.resolve_field_debt(&"companies")).is_true()
	assert_bool(QuestRegistry.is_done(QuestRegistry.FIELD_DEBT)).is_true()
	assert_str(GameState.get_flag("field_debt_reward")).is_equal("companies")
	assert_float(Reputation.standing("iron-companies")).is_equal_approx(12.0, 0.001)
	assert_float(Reputation.standing("the-registry")).is_equal_approx(-3.0, 0.001)
	assert_int(GameState.item_count(ItemIds.MATERIALS_LOAMROOT_SPRIG)).is_equal(0)


func test_all_four_field_debt_rewards_have_distinct_reputation_impacts() -> void:
	var reward_ids := [&"companies", &"seeders", &"registry", &"balance"]
	var signatures: Array[String] = []
	for reward_id in reward_ids:
		GameState.flags.clear()
		GameState.inventory.clear()
		Reputation.from_dict({})
		QuestRegistry.reset()
		QuestRegistry.offer(QuestRegistry.FIELD_DEBT)
		GameState.set_flag("defeated_bog_wight", true)
		GameState.set_flag("field_debt_proof_looted", true)
		GameState.inventory.create_and_add_item(ItemIds.MATERIALS_LOAMROOT_SPRIG)
		assert_bool(QuestRegistry.resolve_field_debt(reward_id)).is_true()
		var signature := "%d/%d/%d" % [
			roundi(Reputation.standing("iron-companies")),
			roundi(Reputation.standing("ssae-seeders")),
			roundi(Reputation.standing("the-registry")),
		]
		assert_bool(signatures.has(signature)).is_false()
		signatures.append(signature)
