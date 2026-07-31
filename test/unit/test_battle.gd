extends GdUnitTestSuite

const BattleScript := preload("res://globals/battle.gd")

var battle
var original_party: Array[PartyMember] = []
var original_soul := 0.0
var original_flags: Dictionary
var original_reputation: Dictionary
var original_renown: Dictionary
var original_autosave_reason: String


func before_test() -> void:
	original_party = GameState.party.duplicate()
	original_soul = GameState.soul_meter
	original_flags = GameState.flags.duplicate(true)
	original_reputation = Reputation.to_dict().duplicate(true)
	original_renown = Renown.to_dict().duplicate(true)
	original_autosave_reason = SaveGame._pending_autosave_reason
	GameState.flags.clear()
	Reputation.from_dict({})
	Renown.from_dict({})
	SaveGame._pending_autosave_reason = ""
	GameState.party.clear()
	GameState.party.append(_member("Vex", 20, 8, 2))
	GameState.party.append(_member("Serai", 16, 6, 1))
	GameState.soul_meter = 50.0
	battle = auto_free(BattleScript.new())


func after_test() -> void:
	GameState.party.clear()
	for member in original_party:
		GameState.party.append(member)
	GameState.soul_meter = original_soul
	GameState.flags = original_flags
	Reputation.from_dict(original_reputation)
	Renown.from_dict(original_renown)
	SaveGame._pending_autosave_reason = original_autosave_reason


func test_start_builds_the_whole_party() -> void:
	battle.start(_enemy("Wight", 20, 4, 1))

	assert_int(battle.allies.size()).is_equal(2)
	assert_str(battle.current_ally().display_name).is_equal("Vex")
	assert_int(battle.enemies.size()).is_equal(1)


func test_each_party_member_acts_before_the_enemy_round() -> void:
	battle.start(_enemy("Wight", 40, 4, 1))
	battle.use_action(BattleScript.ACTION_STRIKE)

	assert_str(battle.current_ally().display_name).is_equal("Serai")
	assert_int(battle.allies[0].hp).is_equal(20)

	battle.use_action(BattleScript.ACTION_STRIKE)
	assert_str(battle.current_ally().display_name).is_equal("Vex")
	assert_int(battle.allies[0].hp).is_equal(18)


func test_aligned_actions_shift_balance_and_spend_soul() -> void:
	battle.start(_enemy("Wight", 40, 4, 1))
	battle.use_action(BattleScript.ACTION_DEFINITION)

	assert_int(battle.balance).is_equal(25)
	assert_float(GameState.soul_meter).is_equal_approx(47.0, 0.001)


func test_mundane_actions_pull_balance_toward_center() -> void:
	battle.start(_enemy("Wight", 40, 4, 1))
	battle.shift_balance(-50)
	battle.use_action(BattleScript.ACTION_STRIKE)

	assert_int(battle.balance).is_equal(-40)


func test_extreme_balance_empowers_matching_action_only() -> void:
	var attacker := BattleActor.new()
	attacker.attack = 7
	var target := BattleActor.new()
	target.defense = 2

	assert_int(BattleScript.calculate_damage(attacker, target, 2, 25, 60)).is_equal(9)
	assert_int(BattleScript.calculate_damage(attacker, target, 2, -25, 60)).is_equal(7)


func test_flee_commits_combat_hp_to_party() -> void:
	battle.start(_enemy("Wight", 40, 6, 1))
	battle.use_action(BattleScript.ACTION_GUARD)
	battle.use_action(BattleScript.ACTION_STRIKE)
	battle.flee()

	assert_int(GameState.party[0].hp).is_equal(battle.allies[0].hp)
	assert_int(GameState.party[0].hp).is_less(20)


func test_player_can_select_between_multiple_living_enemies() -> void:
	var foes: Array[BattleActor] = [_enemy("Wight", 20, 4, 1), _enemy("Boar", 20, 4, 1)]
	battle.start(foes)
	assert_str(battle.current_target().display_name).is_equal("Wight")

	battle.select_next_enemy()
	battle.use_action(BattleScript.ACTION_STRIKE)

	assert_str(battle.current_target().display_name).is_equal("Boar")
	assert_int(foes[0].hp).is_equal(20)
	assert_int(foes[1].hp).is_less(20)


func test_bloodbellow_named_resolution_requires_order_and_spends_soul() -> void:
	battle.start(EncounterIds.DORTHKOR_MUSTER)
	var named := _action(battle, &"speak-muster-name")
	assert_bool(battle.can_use(named)).is_false()
	battle.shift_balance(50)

	assert_bool(battle.use_action(&"speak-muster-name")).is_true()
	assert_str(battle.last_result.outcome_id).is_equal("named")
	assert_float(GameState.soul_meter).is_equal_approx(47.0, 0.001)
	assert_str(GameState.get_flag("dorthkor_muster_outcome")).is_equal("named")


func test_bloodbellow_release_requires_an_enemy_round_and_equilibrium() -> void:
	battle.start(EncounterIds.DORTHKOR_MUSTER)
	var release := _action(battle, &"release-bound-soldier")
	assert_bool(battle.can_use(release)).is_false()
	battle.enemy_rounds = 1
	battle.balance = 0

	assert_bool(battle.use_action(&"release-bound-soldier")).is_true()
	assert_str(battle.last_result.outcome_id).is_equal("released")


func test_bloodbellow_zero_hp_records_conventional_slain_outcome() -> void:
	battle.start(EncounterIds.DORTHKOR_MUSTER)
	battle.enemies[0].hp = 1

	battle.use_action(BattleScript.ACTION_STRIKE)

	assert_str(battle.last_result.outcome_id).is_equal("slain")
	assert_str(GameState.get_flag("dorthkor_muster_cause")).contains("by force")


func test_defeat_restores_half_health_without_story_resolution() -> void:
	battle.start(EncounterIds.DORTHKOR_MUSTER)
	for actor in battle.allies:
		actor.hp = 0
	battle._finish(BattleResult.State.DEFEAT, &"defeat")

	assert_int(GameState.party[0].hp).is_equal(10)
	assert_bool(GameState.get_flag("defeated_mustered_dead")).is_false()
	assert_float(Reputation.standing("ironbrand-sentinels")).is_equal(0.0)


func _action(source, id: StringName) -> CombatAction:
	for action in source.available_actions():
		if action.id == id:
			return action
	return null


func _member(name: String, hp: int, attack: int, defense: int) -> PartyMember:
	var member := PartyMember.new()
	member.display_name = name
	member.hp = hp
	member.max_hp = hp
	member.attack = attack
	member.defense = defense
	return member


func _enemy(name: String, hp: int, attack: int, defense: int) -> BattleActor:
	var actor := BattleActor.new()
	actor.display_name = name
	actor.hp = hp
	actor.max_hp = hp
	actor.attack = attack
	actor.defense = defense
	return actor
