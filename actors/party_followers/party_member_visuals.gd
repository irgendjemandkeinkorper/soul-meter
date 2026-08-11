class_name PartyMemberVisuals
extends RefCounted
## Shared field/UI identity for the party. Every current party member (Vex +
## the 6 recruitable companions) has dedicated painterly unit art
## (assets/generated/sprites/units/), so this just resolves PartyMember.id
## through UnitArt rather than sampling a shared Kenney spritesheet.

const UnitArtScript := preload("res://globals/unit_art.gd")


static func ensure_portrait(member: PartyMember) -> Texture2D:
	if member.portrait != null:
		return member.portrait
	var resolved_id := UnitArtScript.resolve(member.id)
	var texture := load(UnitArtScript.texture_path(resolved_id)) as Texture2D
	member.portrait = texture
	return texture
