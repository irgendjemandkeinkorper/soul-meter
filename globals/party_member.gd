class_name PartyMember
extends Resource
## One member of the player's party. Instanced in code for now (GameState seeds demo data).

@export var id: String = ""
@export var display_name: String = "Unnamed"
@export var epithet: String = ""
@export var race: String = ""
@export var char_class: String = ""

## Character-creation identity fields (#98/#129, ratified against
## dramgid-vault `systems/character-creation.md` + `systems/ten-patron-classes.md`).
## `race` above doubles as the ancestry id/name (kept for save/back-compat with the
## existing recruit roster); the rest are new. All default empty for the existing
## hand-authored recruits and for `PartyMember.new()` in tests — only chargen-built
## members populate them.
@export var discipline: String = ""
@export var patron: String = ""
## Lore-vault entity id (dramgid-vault characters/<id>.md). Empty = no canon entry yet.
@export var vault_id: String = ""
@export var background: String = ""
@export var flaw: String = ""
@export var starting_mastery: String = ""
@export var major_element: String = ""
@export var minor_element: String = ""

@export var level: int = 1
@export var hp: int = 10
@export var max_hp: int = 10
@export var attack: int = 5
@export var defense: int = 2
@export_multiline var bio: String = ""
@export var portrait: Texture2D

## Governing attributes and advancement contributions for the twelve ratified
## skills. Keys are lower-case canonical ids; SkillCheck owns the derivation.
@export var attributes: Dictionary = {}
@export var skill_percentages: Dictionary = {}
@export var skill_tiers: Dictionary = {}

## Tavern recruitment gates (see ui/screens/tavern.gd and globals/renown.gd).
## 0 means "open to anyone" — most candidates leave these at the default.
@export var min_reputation: float = 0.0
@export var min_infamy: float = 0.0


func to_dict() -> Dictionary:
	return {
		"id": id,
		"display_name": display_name,
		"epithet": epithet,
		"race": race,
		"char_class": char_class,
		"discipline": discipline,
		"patron": patron,
		"background": background,
		"flaw": flaw,
		"starting_mastery": starting_mastery,
		"major_element": major_element,
		"minor_element": minor_element,
		"level": level,
		"hp": hp,
		"max_hp": max_hp,
		"attack": attack,
		"defense": defense,
		"bio": bio,
		"portrait_path": portrait.resource_path if portrait else "",
		"attributes": attributes.duplicate(true),
		"skill_percentages": skill_percentages.duplicate(true),
		"skill_tiers": skill_tiers.duplicate(true),
		"min_reputation": min_reputation,
		"min_infamy": min_infamy,
	}


static func from_dict(data: Dictionary) -> PartyMember:
	var member := PartyMember.new()
	member.id = str(data.get("id", ""))
	member.display_name = str(data.get("display_name", "Unnamed"))
	member.epithet = str(data.get("epithet", ""))
	member.race = str(data.get("race", ""))
	member.char_class = str(data.get("char_class", ""))
	member.discipline = str(data.get("discipline", ""))
	member.patron = str(data.get("patron", ""))
	member.background = str(data.get("background", ""))
	member.flaw = str(data.get("flaw", ""))
	member.starting_mastery = str(data.get("starting_mastery", ""))
	member.major_element = str(data.get("major_element", ""))
	member.minor_element = str(data.get("minor_element", ""))
	member.level = int(data.get("level", 1))
	member.hp = int(data.get("hp", 10))
	member.max_hp = int(data.get("max_hp", 10))
	member.attack = int(data.get("attack", 5))
	member.defense = int(data.get("defense", 2))
	member.bio = str(data.get("bio", ""))
	member.attributes = _dictionary_from_save(data.get("attributes", {}))
	member.skill_percentages = _dictionary_from_save(data.get("skill_percentages", {}))
	member.skill_tiers = _dictionary_from_save(data.get("skill_tiers", {}))
	var portrait_path := str(data.get("portrait_path", ""))
	if not portrait_path.is_empty() and portrait_path.begins_with("res://") and not ".." in portrait_path:
		# SECURITY: Prevent arbitrary resource loading vulnerability.
		# A maliciously crafted save file could specify a .gd script, .tscn scene,
		# or .tres resource file with executable code, which gets parsed/run during load().
		# We restrict paths to res://, deny traversal (..), check that the file exists,
		# and restrict the file extension to safe texture/image extensions before loading.
		var ext := portrait_path.get_extension().to_lower()
		# Portrait paths are authored as source image resources by the game. Godot's
		# .import metadata and .ctex cache files are generated implementation details,
		# not portrait paths emitted by PartyMember.to_dict(), so they stay rejected.
		if ext in ["png", "jpg", "jpeg", "svg", "webp", "tga"]:
			if FileAccess.file_exists(portrait_path):
				var res = load(portrait_path)
				if res is Texture2D:
					member.portrait = res
	member.min_reputation = float(data.get("min_reputation", 0.0))
	member.min_infamy = float(data.get("min_infamy", 0.0))
	return member


static func _dictionary_from_save(value: Variant) -> Dictionary:
	return value.duplicate(true) if value is Dictionary else {}
