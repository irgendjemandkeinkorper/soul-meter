extends GdUnitTestSuite
## Unit tests for Battle UI log message formatting helpers in ui/screens/battle.gd.

const BattleScreen := preload("res://ui/screens/battle.gd")


func test_format_attack_survived_counterattack() -> void:
	# Scenario: Player attacks enemy, enemy survives and counterattacks, both survive.
	var log_text := BattleScreen.format_attack(
		"Dom",         # player_name
		"Bog Wight",   # enemy_name
		20,            # enemy_hp_before
		15,            # enemy_hp_after
		20,            # enemy_max_hp
		10,            # player_hp_before
		8,             # player_hp_after
		10             # player_max_hp
	)

	assert_str(log_text).contains("Dom attacks Bog Wight, dealing 5 damage (Bog Wight HP: 15/20).")
	assert_str(log_text).contains("Bog Wight counterattacks, dealing 2 damage (Dom HP: 8/10).")
	assert_str(log_text).not_contains("is defeated")
	assert_str(log_text).not_contains("falls")


func test_format_attack_victory() -> void:
	# Scenario: Player attacks enemy and defeats them. No counterattack.
	var log_text := BattleScreen.format_attack(
		"Dom",
		"Bog Wight",
		5,
		0,
		20,
		10,
		10,
		10
	)

	assert_str(log_text).contains("Dom attacks Bog Wight, dealing 5 damage (Bog Wight HP: 0/20).")
	assert_str(log_text).contains("Bog Wight is defeated.")
	assert_str(log_text).not_contains("counterattacks")


func test_format_attack_defeat_by_counterattack() -> void:
	# Scenario: Player attacks enemy, enemy counterattacks and defeats player.
	var log_text := BattleScreen.format_attack(
		"Dom",
		"Bog Wight",
		15,
		10,
		20,
		5,
		0,
		10
	)

	assert_str(log_text).contains("Dom attacks Bog Wight, dealing 5 damage (Bog Wight HP: 10/20).")
	assert_str(log_text).contains("Bog Wight counterattacks, dealing 5 damage (Dom HP: 0/10).")
	assert_str(log_text).contains("Dom falls. The fight is over.")


func test_format_defend_mitigated() -> void:
	# Scenario: Player defends, enemy attacks. Mitigated damage is applied and blocked amount shown.
	# Enemy Attack = 10, Player Defense = 4. Unmitigated = 6. Mitigated = 3.
	var log_text := BattleScreen.format_defend(
		"Dom",
		"Bog Wight",
		20,            # player_hp_before
		17,            # player_hp_after
		20,            # player_max_hp
		10,            # enemy_attack
		4              # player_defense
	)

	assert_str(log_text).contains("Dom braces! Mitigates incoming damage from Bog Wight.")
	assert_str(log_text).contains("Dom takes 3 damage (blocked 3) (Dom HP: 17/20).")
	assert_str(log_text).not_contains("falls")


func test_format_defend_mitigated_to_minimum() -> void:
	# Scenario: Player defends but unmitigated damage is already 1. Mitigated is also 1 (minimum).
	# Enemy Attack = 5, Player Defense = 4. Unmitigated = 1. Mitigated = 1.
	var log_text := BattleScreen.format_defend(
		"Dom",
		"Bog Wight",
		20,
		19,
		20,
		5,
		4
	)

	assert_str(log_text).contains("Dom braces! Mitigates incoming damage from Bog Wight.")
	assert_str(log_text).contains("Dom takes 1 damage (mitigated to minimum) (Dom HP: 19/20).")


func test_format_defend_defeat() -> void:
	# Scenario: Player defends but is defeated by the incoming mitigated damage.
	var log_text := BattleScreen.format_defend(
		"Dom",
		"Bog Wight",
		2,
		0,
		20,
		10,
		4
	)

	assert_str(log_text).contains("Dom braces! Mitigates incoming damage from Bog Wight.")
	assert_str(log_text).contains("Dom takes 2 damage (blocked 4) (Dom HP: 0/20).")
	assert_str(log_text).contains("Dom falls. The fight is over.")
