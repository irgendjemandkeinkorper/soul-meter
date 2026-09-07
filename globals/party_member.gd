class_name PartyMember
extends Resource
## One member of the player's party. Instanced in code for now (GameState seeds demo data).

## PROVISIONAL base-tier pool from docs/casting-economy.md; keep this value aligned
## with that numeric sweep until class-tier Breath values are ratified.
const DEFAULT_BREATH_MAX := 15

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
## Class id ("ironbrand") — `patron` above holds the deity DISPLAY name ("Kero"), the
## roster/registry vocabulary (docs/architecture-chargen-dramgid.md §6.3, ruling R4).
@export var class_id: String = ""
## The ARMS skill the class Kit trains, and the Kit weapon prototype id once Pandora seeds
## it (F3a-5). Combat resolves equipment → Kit → bare hands in F3c.
@export var kit_weapon_skill: String = ""
@export var kit_weapon: String = ""
## Wheel element of the Background's "Root Note of choice" Mastery (empty = none yet).
@export var mastery_element: String = ""

@export var level: int = 1
@export var xp: int = 0
## Unspent point-buy advancement points (#98, D3; granted by story milestones —
## see GameState.grant_milestone_level and globals/advancement.gd).
@export var advancement_points: int = 0
@export var hp: int = 10
@export var max_hp: int = 10
@export var breath: int = DEFAULT_BREATH_MAX
@export var breath_max: int = DEFAULT_BREATH_MAX
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
		"class_id": class_id,
		"kit_weapon_skill": kit_weapon_skill,
		"kit_weapon": kit_weapon,
		"mastery_element": mastery_element,
		"level": level,
		"xp": xp,
		"advancement_points": advancement_points,
		"hp": hp,
		"max_hp": max_hp,
		"breath": breath,
		"breath_max": breath_max,
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
	member.class_id = str(data.get("class_id", ""))
	member.kit_weapon_skill = str(data.get("kit_weapon_skill", ""))
	member.kit_weapon = str(data.get("kit_weapon", ""))
	member.mastery_element = str(data.get("mastery_element", ""))
	member.level = int(data.get("level", 1))
	member.xp = maxi(int(data.get("xp", 0)), 0)
	member.advancement_points = maxi(int(data.get("advancement_points", 0)), 0)
	member.hp = int(data.get("hp", 10))
	member.max_hp = int(data.get("max_hp", 10))
	member.breath_max = maxi(int(data.get("breath_max", DEFAULT_BREATH_MAX)), 0)
	member.breath = clampi(int(data.get("breath", member.breath_max)), 0, member.breath_max)
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


## Reads a DRAMGID attribute. Until save schema 8 rewrites every row, a member may carry
## legacy keys ("forge") while a caller asks for the DRAMGID id ("muster"), or the reverse
## (a legacy dialogue check against a chargen-built member) — both answer through
## DramgidSchema.ATTRIBUTE_RENAMES.
func attribute_value(attribute_id: StringName) -> int:
	var key := String(attribute_id)
	if attributes.has(key):
		return int(attributes[key])
	if attributes.has(attribute_id):
		return int(attributes[attribute_id])
	var canonical := DramgidSchema.canonical_attribute_id(key)
	if not canonical.is_empty() and canonical != key and attributes.has(canonical):
		return int(attributes[canonical])
	var legacy := DramgidSchema.legacy_attribute_id(key)
	if not legacy.is_empty() and attributes.has(legacy):
		return int(attributes[legacy])
	return 0


static func _dictionary_from_save(value: Variant) -> Dictionary:
	return value.duplicate(true) if value is Dictionary else {}
