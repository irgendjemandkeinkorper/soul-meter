class_name PartyMember
extends Resource
## One member of the player's party. Instanced in code for now (GameState seeds demo data).

@export var id: String = ""
@export var display_name: String = "Unnamed"
@export var race: String = ""
@export var char_class: String = ""
@export var level: int = 1
@export var hp: int = 10
@export var max_hp: int = 10
@export var attack: int = 5
@export var defense: int = 2
@export_multiline var bio: String = ""
@export var portrait: Texture2D
