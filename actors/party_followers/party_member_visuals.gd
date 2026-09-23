class_name PartyMemberVisuals
extends RefCounted
## Shared field/UI identity for named and player-created party members.
## UI keeps the authored portrait; field actors use the paired full-body art.

const UnitArtScript := preload("res://globals/unit_art.gd")


static func field_texture(member: PartyMember) -> Texture2D:
	if member == null:
		return null
	var portrait_path := member.portrait.resource_path if member.portrait != null else ""
	var unit_id := UnitArtScript.field_unit_id(member.id, portrait_path)
	return load(UnitArtScript.texture_path(unit_id)) as Texture2D


static func ensure_portrait(member: PartyMember) -> Texture2D:
	if member.portrait != null:
		return member.portrait
	var resolved_id := UnitArtScript.resolve(member.id)
	var texture := load(UnitArtScript.texture_path(resolved_id)) as Texture2D
	member.portrait = texture
	return texture
