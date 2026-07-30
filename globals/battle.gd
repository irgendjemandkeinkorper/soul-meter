extends Node
## Battle — minimal turn-based combat scaffold (design doc §6: the
## field->battle->turn-based structure is canon; the Balance Gauge / defining-
## strikes combat *identity* is still an unratified [PROPOSAL] and is
## deliberately NOT implemented here). No GodotGAS, no hitbox/hurtbox — this
## is a menu-driven HP/attack/defense exchange, wired end-to-end so a real
## combat identity can be layered on top later.
##
## GameFlow owns *when* battle happens (the state chart); this autoload owns
## the combat math itself, same separation Reputation keeps from GameFlow.

signal battle_started
signal turn_resolved
signal battle_ended(won: bool, fled: bool)

var player: BattleActor
var enemy: BattleActor
var defending := false


func start(enemy_actor: BattleActor) -> void:
	var lead: PartyMember = GameState.party[0] if not GameState.party.is_empty() else null
	player = BattleActor.new()
	if lead:
		player.display_name = lead.display_name
		player.hp = lead.hp
		player.max_hp = lead.max_hp
		player.attack = lead.attack
		player.defense = lead.defense
	enemy = enemy_actor
	defending = false
	battle_started.emit()


func player_attack() -> void:
	if enemy == null or player == null:
		return
	enemy.hp = maxi(0, enemy.hp - maxi(1, player.attack - enemy.defense))
	if enemy.hp <= 0:
		battle_ended.emit(true, false)
		return
	_resolve_enemy_turn()
	turn_resolved.emit()


func player_defend() -> void:
	if player == null:
		return
	defending = true
	_resolve_enemy_turn()
	turn_resolved.emit()


func flee() -> void:
	battle_ended.emit(false, true)


func _resolve_enemy_turn() -> void:
	if enemy == null or player == null:
		return
	var incoming := maxi(1, enemy.attack - player.defense)
	if defending:
		incoming = maxi(1, incoming / 2)
	player.hp = maxi(0, player.hp - incoming)
	defending = false
	if player.hp <= 0:
		battle_ended.emit(false, false)
