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
