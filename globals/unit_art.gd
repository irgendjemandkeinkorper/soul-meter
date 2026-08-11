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

## Ambient/anonymous figures with no individually-named art (legacy
## hand-placed NPCs without a matching unit, generic crowd fill).
const FALLBACK_POOL: PackedStringArray = [
	"crowd-acolyte-a", "crowd-acolyte-b", "crowd-beggar-a", "crowd-dockworker-a",
	"crowd-dockworker-b", "crowd-guard-a", "crowd-guard-b", "crowd-guard-c",
	"crowd-laborer-a", "crowd-laborer-b", "crowd-merchant-a", "crowd-merchant-b",
]


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
