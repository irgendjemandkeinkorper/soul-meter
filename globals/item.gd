class_name Item
extends Resource
## A single inventory item definition. Instanced in code for now (GameState seeds demo
## data); later these become .tres resources authored in the editor or generated from the vault.

@export var id: String = ""
@export var display_name: String = "Item"
## weapon / relic / tool / consumable / material / misc
@export var category: String = "misc"
@export var stackable: bool = false
@export_multiline var description: String = ""
@export var icon: Texture2D
