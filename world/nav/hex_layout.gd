class_name HexLayout
extends RefCounted
## Where hexes sit in the world for the 64x32 iso view (owner item 34, 2026-11-03;
## `docs/design/hex-grid-plan-2026-11-03.md`, slice H0). Pure geometry: no tiles, no maps.
## H1's `IsoGrid` hex mode builds one from its ground layer's origin.
##
## The ground is drawn 2:1. "Flat" space undoes that: x stays, y doubles. In flat space a 64x32
## cell is a square of side 32 * sqrt(2) turned 45 degrees, and the hexes are regular and
## pointy-top, with rows running left to right (ruling H-b). The screen squashes them 2:1 like
## the cells.
##
## Hex size (ruling H-a, "Fallout scale"): a step between neighbouring hexes is half a cell side,
## so two hex steps cover the ground of one cell step. That makes "1 AP walks 2 hexes" (ruling
## H-a2) cover today's ground. A hex is about 23 px wide on screen, the rows step down about
## 10 px, and there are about 4.6 hexes to a cell.

const CELL_SIZE := Vector2(64.0, 32.0)
## Flat-space side of one cell: the diagonal of the 64 px diamond over sqrt(2).
const CELL_SIDE := 45.254833995939045
## Centre-to-centre distance of neighbouring hexes in flat space: half a cell side.
const DEFAULT_STEP := CELL_SIDE / 2.0
const SQRT3 := 1.7320508075688772
## Screen y is flat y times this (the 2:1 iso squash).
const SQUASH := 0.5
## Hex slice H3: edge `i` of `corners()` runs from corner `i` to corner `i + 1`. It is shared with
## the neighbour `HexMath.DIRECTIONS[EDGE_NEIGHBOR[i]]`: NE, E, SE, SW, W, NW, clockwise from the
## top. The field grid and the reach rings draw an edge once, or only where a set of hexes ends.
const EDGE_NEIGHBOR: Array[int] = [1, 0, 5, 4, 3, 2]

## World position of hex (0, 0)'s centre.
var origin := Vector2.ZERO
## Flat-space centre-to-centre distance of neighbouring hexes.
var step := DEFAULT_STEP


func _init(layout_origin: Vector2 = Vector2.ZERO, hex_step: float = DEFAULT_STEP) -> void:
	origin = layout_origin
	step = hex_step


## Centre-to-corner distance in flat space.
func corner_radius() -> float:
	return step / SQRT3


func hex_to_world(hex: Vector2i) -> Vector2:
	var flat_x := step * (hex.x + hex.y * 0.5)
	var flat_y := step * SQRT3 * 0.5 * hex.y
	return origin + Vector2(flat_x, flat_y * SQUASH)


## The hex containing a world position.
func world_to_hex(world: Vector2) -> Vector2i:
	var local_x := float(world.x) - origin.x
	var flat_y := (float(world.y) - origin.y) / SQUASH
	var r := flat_y / (step * SQRT3 * 0.5)
	var q := local_x / step - r * 0.5
	return HexMath.round_qr(q, r)


## The six corners of a hex in world space, clockwise from the top (pointy-top: the first corner
## is straight above the centre). `inset` 0 gives the true corners; 0.5 pulls each halfway in.
func corners(hex: Vector2i, inset: float = 0.0) -> PackedVector2Array:
	var center := hex_to_world(hex)
	var radius := corner_radius() * (1.0 - inset)
	var points := PackedVector2Array()
	for i in HexMath.DIRECTION_COUNT:
		var angle := deg_to_rad(-90.0 + 60.0 * i)
		points.append(center + Vector2(cos(angle) * radius, sin(angle) * radius * SQUASH))
	return points


## The points H1 tests against the square blocking layer to derive a solid hex: the centre,
## then the six corners pulled halfway in (plan, "Derived solids").
func sample_points(hex: Vector2i) -> PackedVector2Array:
	var points := PackedVector2Array([hex_to_world(hex)])
	points.append_array(corners(hex, 0.5))
	return points


## Every hex whose centre lies inside a world rectangle, row by row from the top, left to right.
func hexes_in_rect(world_rect: Rect2) -> Array[Vector2i]:
	var result: Array[Vector2i] = []
	var row_height := step * SQRT3 * 0.5 * SQUASH
	var top := ceili((world_rect.position.y - origin.y) / row_height)
	var bottom := floori((world_rect.end.y - origin.y) / row_height)
	for r in range(top, bottom + 1):
		var row_shift := r * 0.5
		var left := ceili((world_rect.position.x - origin.x) / step - row_shift)
		var right := floori((world_rect.end.x - origin.x) / step - row_shift)
		for q in range(left, right + 1):
			var hex := Vector2i(q, r)
			if world_rect.has_point(hex_to_world(hex)):
				result.append(hex)
	return result
