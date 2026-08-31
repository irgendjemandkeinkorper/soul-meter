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
## at roughly half art size so the maps read much larger around them. Applies to
## every field-facing character sprite (player, NPCs, villagers, followers,
## field enemies); battle-stage and portrait rendering are untouched.
const WORLD_SCALE := 0.55


## Shrink a field actor's visual toward its ground-contact origin. Multiplies the
## sprite's position/offset/scale (so the feet stay planted at the node origin)
## and the shadow's scale. Call exactly once, AFTER the sprite's texture, offset,
## and scale are in their final unscaled state — calling twice compounds.
static func apply_world_scale(sprite: Sprite2D, shadow: CanvasItem = null) -> void:
	if sprite == null or sprite.has_meta(&"unit_art_world_scaled"):
		return
	sprite.set_meta(&"unit_art_world_scaled", true)
	sprite.position *= WORLD_SCALE
	sprite.offset *= WORLD_SCALE
	sprite.scale *= WORLD_SCALE
	if shadow != null:
		# Absolute, not multiplied: NPC re-dress paths reset the sprite but not
		# the shadow, and a compounding shadow would shrink on every re-dress.
		shadow.scale = Vector2.ONE * WORLD_SCALE

## Ambient/anonymous figures with no individually-named art (legacy
## hand-placed NPCs without a matching unit, generic crowd fill).
const FALLBACK_POOL: PackedStringArray = [
	"crowd-acolyte-a", "crowd-acolyte-b", "crowd-beggar-a", "crowd-dockworker-a",
	"crowd-dockworker-b", "crowd-guard-a", "crowd-guard-b", "crowd-guard-c",
	"crowd-laborer-a", "crowd-laborer-b", "crowd-merchant-a", "crowd-merchant-b",
]


## Combat rows name allies by display_name and enemies by archetype_id; this maps
## either to a unit-art id (shared by ui/screens/battle_stage.gd and the
## six-region BattleStageRegion — keep them on this one mapping).
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


static func has_unit(unit_id: String) -> bool:
	return not unit_id.is_empty() and FileAccess.file_exists(texture_path(unit_id))


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
