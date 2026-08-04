class_name PartyMemberVisuals
extends RefCounted
## Shared field/UI identity for the prototype party. The Kenney pack is a
## single atlas, so PartyMember.portrait carries an AtlasTexture region rather
## than every view maintaining its own companion-to-sprite lookup.

const CHARACTER_SHEET: Texture2D = preload(
	"res://assets/kenney/characters/roguelike-characters/Spritesheet/roguelikeChar_transparent.png"
)
const DEFAULT_REGION := Rect2(17, 102, 16, 16)
const PORTRAIT_REGIONS: Dictionary = {
	"vex": Rect2(0, 102, 16, 16),
	"serai-lun": Rect2(17, 102, 16, 16),
	"old-grumbrand": Rect2(0, 119, 16, 16),
	"wyneth-hallow-tide": Rect2(17, 119, 16, 16),
	"ressa-quickfingers": Rect2(0, 136, 16, 16),
	"korrath-ninefold": Rect2(17, 136, 16, 16),
	"maura-greyfen": Rect2(0, 153, 16, 16),
}


static func ensure_portrait(member: PartyMember) -> Texture2D:
	if member.portrait != null:
		return member.portrait
	var portrait := AtlasTexture.new()
	portrait.atlas = CHARACTER_SHEET
	portrait.region = region_for(member.id)
	portrait.filter_clip = true
	member.portrait = portrait
	return portrait


static func region_for(member_id: String) -> Rect2:
	return PORTRAIT_REGIONS.get(member_id, DEFAULT_REGION) as Rect2
