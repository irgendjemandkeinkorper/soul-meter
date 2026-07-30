class_name BattleActor
extends Resource
## One side of a battle encounter (player or enemy). Deliberately minimal —
## no GodotGAS, no status effects; just HP/attack/defense for the combat
## scaffold. Ephemeral per-encounter, not synced back to PartyMember.hp.

@export var display_name: String = ""
@export var hp: int = 10
@export var max_hp: int = 10
@export var attack: int = 5
@export var defense: int = 2
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
