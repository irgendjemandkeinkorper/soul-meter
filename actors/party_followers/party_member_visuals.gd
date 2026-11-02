class_name PartyMemberVisuals
extends RefCounted
## Shared field/UI identity for named and player-created party members.
## UI keeps the authored portrait; field actors use the paired full-body art.

const UnitArtScript := preload("res://globals/unit_art.gd")

## Sprite busts already cut, by sprite path: the field HUD redraws on every party change.
static var _busts: Dictionary = {}


static func field_texture(member: PartyMember) -> Texture2D:
	if member == null:
		return null
	var portrait_path := member.portrait.resource_path if member.portrait != null else ""
	var unit_id := UnitArtScript.field_unit_id(member.id, portrait_path)
	return load(UnitArtScript.texture_path(unit_id)) as Texture2D


static func ensure_portrait(member: PartyMember) -> Texture2D:
	if member.portrait != null:
		return member.portrait
	var texture := portrait_texture(member)
	member.portrait = texture
	return texture


## The member's portrait without writing it back: the field HUD only reads party state.
static func portrait_texture(member: PartyMember) -> Texture2D:
	if member == null:
		return null
	if member.portrait != null:
		return member.portrait
	return load(UnitArtScript.texture_path(UnitArtScript.resolve(member.id))) as Texture2D


## A head-and-shoulders view for small frames (the field HUD's party strip). An authored bust
## comes back as is; a member who only has a walking sprite (a 256 px frame, figure head to
## foot) gets the top of the figure, cut square around its centre.
static func bust_texture(member: PartyMember) -> Texture2D:
	var texture := portrait_texture(member)
	if texture == null or not texture.resource_path.begins_with(UnitArtScript.ROOT):
		return texture
	if _busts.has(texture.resource_path):
		return _busts[texture.resource_path]
	var image := texture.get_image()
	if image == null or image.is_empty():
		return texture
	var figure := image.get_used_rect()
	if figure.size.x <= 0 or figure.size.y <= 0:
		return texture
	var side := clampi(roundi(figure.size.y * 0.42), 32, image.get_height())
	var centre_x := figure.position.x + (figure.size.x >> 1)
	var left := clampi(centre_x - (side >> 1), 0, maxi(0, image.get_width() - side))
	var bust := AtlasTexture.new()
	bust.atlas = texture
	bust.region = Rect2(left, figure.position.y, side, side)
	_busts[texture.resource_path] = bust
	return bust
