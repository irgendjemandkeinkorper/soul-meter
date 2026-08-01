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

## Tavern recruitment gates (see ui/screens/tavern.gd and globals/renown.gd).
## 0 means "open to anyone" — most candidates leave these at the default.
@export var min_reputation: float = 0.0
@export var min_infamy: float = 0.0


func to_dict() -> Dictionary:
	return {
		"id": id,
		"display_name": display_name,
		"race": race,
		"char_class": char_class,
		"level": level,
		"hp": hp,
		"max_hp": max_hp,
		"attack": attack,
		"defense": defense,
		"bio": bio,
		"portrait_path": portrait.resource_path if portrait else "",
		"min_reputation": min_reputation,
		"min_infamy": min_infamy,
	}


static func from_dict(data: Dictionary) -> PartyMember:
	var member := PartyMember.new()
	member.id = str(data.get("id", ""))
	member.display_name = str(data.get("display_name", "Unnamed"))
	member.race = str(data.get("race", ""))
	member.char_class = str(data.get("char_class", ""))
	member.level = int(data.get("level", 1))
	member.hp = int(data.get("hp", 10))
	member.max_hp = int(data.get("max_hp", 10))
	member.attack = int(data.get("attack", 5))
	member.defense = int(data.get("defense", 2))
	member.bio = str(data.get("bio", ""))
	var portrait_path := str(data.get("portrait_path", ""))
	if not portrait_path.is_empty() and portrait_path.begins_with("res://") and not ".." in portrait_path:
		# SECURITY: Prevent arbitrary resource loading vulnerability.
		# A maliciously crafted save file could specify a .gd script, .tscn scene,
		# or .tres resource file with executable code, which gets parsed/run during load().
		# We restrict paths to res://, deny traversal (..), check that the file exists,
		# and restrict the file extension to safe texture/image extensions before loading.
		var ext := portrait_path.get_extension().to_lower()
		if ext in ["png", "jpg", "jpeg", "svg", "webp", "tga", "import", "ctex"]:
			if FileAccess.file_exists(portrait_path):
				var res = load(portrait_path)
				if res is Texture2D:
					member.portrait = res
	member.min_reputation = float(data.get("min_reputation", 0.0))
	member.min_infamy = float(data.get("min_infamy", 0.0))
	return member
