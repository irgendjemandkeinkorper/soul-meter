class_name UnitDefinition
extends Resource
## One row of the `units` table (issue #141, Elemental Architecture Section III).
##
## A unit is the tactical-layer identity of a combatant: the stat block the CT
## scheduler and the battlefield model read. PartyMember stays the field-layer
## roster row (portrait, bio, recruitment gates); UnitMigration derives a unit
## from a PartyMember rather than replacing it, so #66's portrait allowlist and
## the tavern recruitment path are untouched.
##
## SCHEMA ONLY. No unit is authored in shipped Pandora data by this issue.

@export var id: String = ""
@export var display_name: String = ""
## Short honorific/byname shown beside the name in the tactical UI.
@export var epithet: String = ""
@export var base_hp: int = 0
@export var base_mp: int = 0
## Base speed feeds the CT scheduler directly: every tick a participant gains
## charge equal to its speed (globals/combat/charge_time_scheduler.gd).
@export var base_spd: int = 0
@export var move: int = 0
@export var jump: int = 0
## Portrait REFERENCE, not a loaded resource. Deliberately an opaque id string:
## PartyMember already owns the only path that turns a serialized portrait into a
## Texture2D, behind the #66 extension allowlist. Units never load textures, so
## this table cannot become a second, weaker portrait-loading path.
@export var portrait_ref: String = ""
@export var vault_id: String = ""


func to_dict() -> Dictionary:
	return {
		"id": id,
		"display_name": display_name,
		"epithet": epithet,
		"base_hp": base_hp,
		"base_mp": base_mp,
		"base_spd": base_spd,
		"move": move,
		"jump": jump,
		"portrait_ref": portrait_ref,
		"vault_id": vault_id,
	}


static func from_dict(data: Dictionary) -> UnitDefinition:
	var unit := UnitDefinition.new()
	unit.id = str(data.get("id", ""))
	unit.display_name = str(data.get("display_name", ""))
	unit.epithet = str(data.get("epithet", ""))
	unit.base_hp = int(data.get("base_hp", 0))
	unit.base_mp = int(data.get("base_mp", 0))
	unit.base_spd = int(data.get("base_spd", 0))
	unit.move = int(data.get("move", 0))
	unit.jump = int(data.get("jump", 0))
	unit.portrait_ref = str(data.get("portrait_ref", ""))
	unit.vault_id = str(data.get("vault_id", ""))
	return unit
