class_name AccordZone
extends Node2D
## A spatial Harmonic Accord override (#349, architecture §4.11; owner ruling 2026-10-11:
## AccordZone is a placeable). It is a DATA volume, not a trigger: it has no signals, no
## collision and no runtime behaviour beyond reading whether it has been re-Agreed (#520). `FieldMap.zone_delta(cell)` sums the `accord_delta` of
## every zone that covers a cell; Hush/Waning Loom pressure is derived from that same delta
## (`AccordMath.loom_strength()`), so there is no separate strength field.
##
## The volume is a rectangle in the field's own cell space, centred on the cell under the
## node's position (Weftlumin snaps placement to a cell centre). Half extents of 2 and 1 cover
## a 5 x 3 block of cells.

const GROUP := &"accord_zone"

## Added to the location's base accord on every covered cell. Negative thins the Loom there.
@export_range(-100, 100, 1) var accord_delta: int = 0
## Optional (#520, `docs/places-reagreed-packet.md`): names this zone as a place that can be
## re-Agreed. A quest outcome that lists the id in `restores_agreement` lifts the zone's
## negative delta for good. Empty keeps the zone plain authored data.
@export var agreement_id: StringName = &""
## Optional elemental default for the covered cells ("this swamp corner is Mozh"); empty keeps
## the location's `weather_default`.
@export var element_default: StringName = &""
## Cells covered on each side of the anchor cell along the cell x axis. 0 covers one column.
@export_range(0, 32, 1) var half_width_cells: int = 2
## Cells covered on each side of the anchor cell along the cell y axis. 0 covers one row.
@export_range(0, 32, 1) var half_height_cells: int = 2


func _enter_tree() -> void:
	add_to_group(GROUP)


## Whether a quest outcome has re-Agreed this zone (`AccordMath.agreement_flag()` in GameState).
func is_reagreed() -> bool:
	return agreement_id != &"" and GameState.flag_is_true(AccordMath.agreement_flag(agreement_id))


## The delta this zone contributes now: a re-Agreed zone stops thinning the Loom (owner ruling
## 2026-10-29: the full negative delta lifts, permanently). A positive delta is never lifted.
func effective_delta() -> int:
	return 0 if accord_delta < 0 and is_reagreed() else accord_delta


## Whether `cell` lies inside this zone when the zone is anchored at `anchor_cell`.
func covers(cell: Vector2i, anchor_cell: Vector2i) -> bool:
	var offset := cell - anchor_cell
	return absi(offset.x) <= maxi(half_width_cells, 0) and absi(offset.y) <= maxi(half_height_cells, 0)


## Every covered cell for `anchor_cell`, row-major. For overlays and capture only.
func covered_cells(anchor_cell: Vector2i) -> Array[Vector2i]:
	var cells: Array[Vector2i] = []
	var half_w := maxi(half_width_cells, 0)
	var half_h := maxi(half_height_cells, 0)
	for y in range(-half_h, half_h + 1):
		for x in range(-half_w, half_w + 1):
			cells.append(anchor_cell + Vector2i(x, y))
	return cells
