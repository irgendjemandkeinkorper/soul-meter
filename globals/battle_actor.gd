class_name BattleActor
extends Resource
## Runtime combatant. Party actors retain their party_index so damage can be
## committed back to GameState when combat ends.

@export var display_name: String = ""
@export var hp: int = 10
@export var max_hp: int = 10
@export var attack: int = 5
@export var defense: int = 2
@export_range(-1, 1) var balance_affinity: int = 0
@export var balance_pressure: int = 12
## GameState flag to set on a win, so a defeated enemy actor doesn't respawn
## a fight. Empty for the player's own BattleActor.
@export var defeated_flag: String = ""

## Reputation consequence for beating/losing to this actor. Mirrors
## FetchQuest's reward_* fields (quests/fetch_quest.gd) — empty faction means
## no-op, so most BattleActors (including the player's own) can leave these
## unset. Fleeing has no consequence here; only a clean win or loss does.
@export var win_faction: String = ""
@export var win_delta: float = 0.0
@export var win_cause: String = ""
@export var loss_faction: String = ""
@export var loss_delta: float = 0.0
@export var loss_cause: String = ""

var party_index: int = -1
var guarding := false


func is_alive() -> bool:
	return hp > 0
