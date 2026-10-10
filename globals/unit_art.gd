class_name UnitArt
extends RefCounted
## Resolves the ratified painterly unit art (docs/art-aesthetics-bible.md),
## generated per-unit into assets/generated/sprites/units/<id>/. This is the
## successor to the deterministic Kenney3D "mini-characters" kit
## (assets/generated/sprites/isometric_sprite_catalog.gd) for every
## field-facing character/creature sprite: party, Dom NPCs, enemies.

const ROOT := "res://assets/generated/sprites/units"

## Feet sit ~9px above the 256px canvas bottom on average across the batch
## (measured from the generated set's alpha bounding boxes); this offset
## lands that ground-contact point at the node's local origin.
const PIVOT_OFFSET := Vector2(0.0, -119.0)

## Field-scene character scale (owner directive 2026-08-31): world actors draw
## at roughly half art size so the maps read much larger around them. Kept as the
## fallback for sprites with no measurable texture.
const WORLD_SCALE := 0.55

## Owner decision 2026-10-05 (docs/art/fallout2-unification-spec.md): an adult actor
## occupies ~112 px on screen at camera zoom 1. Unit art fills its 256 px canvas
## whatever the subject, so the scale comes from each texture's drawn height, not
## one shared factor (one shared factor drew a rat as tall as a person).
const TARGET_ACTOR_HEIGHT_PX := 112.0
## Deliberate exceptions to the adult height, in on-screen px. Ordinary animals
## only; Dramgid creatures keep the adult height until their size is ratified.
const UNIT_HEIGHT_PX := {
	"fauna-rat": 18.0,
	"fauna-crow": 24.0,
	"fauna-stray-dog": 46.0,
}

static var _drawn_heights: Dictionary = {}  ## texture/region key -> drawn px height


## Shrink a field actor's visual toward its ground-contact origin so it draws at its
## target height. Multiplies the sprite's position/offset/scale (so the feet stay
## planted at the node origin) and sets the shadow's scale. The first call records the
## sprite's unscaled state; later calls (after a texture swap) recompute from it, so
## repeated calls never compound. Clear the `unit_art_world_scaled` meta after
## resetting a sprite's absolutes to record a new unscaled state.
static func apply_world_scale(sprite: Sprite2D, shadow: CanvasItem = null) -> void:
	if sprite == null:
		return
	if not sprite.has_meta(&"unit_art_world_scaled"):
		sprite.set_meta(&"unit_art_world_scaled", true)
		sprite.set_meta(&"unit_art_base", [sprite.position, sprite.offset, sprite.scale])
	var base: Array = sprite.get_meta(&"unit_art_base")
	var factor := world_scale_for(sprite, base[2])
	sprite.texture_filter = CanvasItem.TEXTURE_FILTER_LINEAR
	sprite.position = base[0] * factor
	sprite.offset = base[1] * factor
	sprite.scale = base[2] * factor
	if shadow != null:
		# Absolute, not multiplied: NPC re-dress paths reset the sprite but not
		# the shadow, and a compounding shadow would shrink on every re-dress.
		shadow.scale = Vector2.ONE * factor


## The factor that draws `sprite`'s current texture at its target height, given the
## sprite's unscaled `base_scale`.
static func world_scale_for(sprite: Sprite2D, base_scale: Vector2) -> float:
	var drawn := _drawn_height(sprite) * absf(base_scale.y)
	if drawn <= 0.0:
		return WORLD_SCALE
	return target_height_for(sprite.texture) / drawn


static func target_height_for(texture: Texture2D) -> float:
	if texture == null:
		return TARGET_ACTOR_HEIGHT_PX
	var unit_id := texture.resource_path.get_base_dir().get_file()
	return float(UNIT_HEIGHT_PX.get(unit_id, TARGET_ACTOR_HEIGHT_PX))


## Height in texture px of the sprite's visible (non-transparent) pixels, cached per
## texture and region. Falls back to the full frame when the image is unreadable.
static func _drawn_height(sprite: Sprite2D) -> float:
	var texture := sprite.texture
	if texture == null:
		return 0.0
	var region := sprite.region_rect if sprite.region_enabled else Rect2()
	var key := "%s|%d|%s" % [texture.resource_path, texture.get_instance_id() if texture.resource_path.is_empty() else 0, region]
	if _drawn_heights.has(key):
		return _drawn_heights[key]
	var height := region.size.y if region.has_area() else float(texture.get_height())
	var image := texture.get_image()
	if image != null:
		if image.is_compressed():
			image = image.duplicate() as Image
			image.decompress()
		if region.has_area():
			image = image.get_region(Rect2i(region))
		var used := image.get_used_rect()
		if used.has_area():
			height = float(used.size.y)
	_drawn_heights[key] = height
	return height

## Ambient/anonymous figures with no individually-named art (legacy
## hand-placed NPCs without a matching unit, generic crowd fill).
const FALLBACK_POOL: PackedStringArray = [
	"crowd-acolyte-a", "crowd-acolyte-b", "crowd-beggar-a", "crowd-dockworker-a",
	"crowd-dockworker-b", "crowd-guard-a", "crowd-guard-b", "crowd-guard-c",
	"crowd-laborer-a", "crowd-laborer-b", "crowd-merchant-a", "crowd-merchant-b",
]


## Combat rows name allies by display_name and enemies by archetype_id; this maps
## either to a unit-art id (shared by CombatOverlay and the six-region
## BattleStageRegion — keep them on this one mapping).
const ALLY_UNIT_IDS_BY_NAME := {
	"Vex": "vex",
	"Vex the Unbowed": "vex",
	"Serai-Lun": "serai-lun",
	"Old Grumbrand": "old-grumbrand",
	"Wyneth Hallow-Tide": "wyneth-hallow-tide",
	"Ressa Quickfingers": "ressa-quickfingers",
	"Korrath Ninefold": "korrath-ninefold",
	"Maura Greyfen": "maura-greyfen",
}


static func combat_unit_id(side: StringName, archetype_id: String, display_name: String) -> String:
	if side == &"enemy":
		return archetype_id
	return str(ALLY_UNIT_IDS_BY_NAME.get(display_name, display_name))


static func texture_path(unit_id: String) -> String:
	return "%s/%s/%s--idle--se--f00.png" % [ROOT, unit_id, unit_id]


## A portrait bust is never a walking sprite. Chargen already authors a field
## counterpart for each likeness; preserve that identity across menus and combat.
static func field_unit_id(member_id: String, portrait_path: String = "") -> String:
	if portrait_path.begins_with("res://assets/generated/portraits/player/"):
		var likeness := portrait_path.get_file().get_basename()
		var unit_id := ChargenData.likeness_fallback_unit(likeness)
		if has_unit(unit_id):
			return unit_id
	elif portrait_path.begins_with(ROOT + "/"):
		var unit_id := portrait_path.get_base_dir().get_file()
		if has_unit(unit_id):
			return unit_id
	return resolve(member_id)


static func has_unit(unit_id: String) -> bool:
	return not unit_id.is_empty() and ResourceLoader.exists(texture_path(unit_id))


## Deterministic fallback for a unit id with no dedicated art (e.g. a legacy
## NPC or an out-of-batch creature) — same seed always picks the same crowd
## figure rather than reshuffling every reload.
static func fallback_for(seed_key: String) -> String:
	return FALLBACK_POOL[posmod(seed_key.hash(), FALLBACK_POOL.size())]


## Resolves to the unit's own art if it exists, otherwise a deterministic
## crowd fallback — never the old Kenney-kit placeholder.
static func resolve(unit_id: String) -> String:
	if has_unit(unit_id):
		return unit_id
	return fallback_for(unit_id)
