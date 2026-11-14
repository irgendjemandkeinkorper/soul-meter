class_name HexMath
extends RefCounted
## Pure hex-grid maths for the hex grid wave (owner item 34, 2026-11-03;
## `docs/design/hex-grid-plan-2026-11-03.md`, slice H0). Nothing here knows about maps, tiles,
## screens or combat. `HexLayout` places hexes in the world, and `IsoGrid` (H1) and
## `GridBattlefieldModel` (H2) build on both.
##
## Coordinates are axial `(q, r)` in a `Vector2i`, for pointy-top hexes whose rows run left to
## right (ruling H-b). The third cube coordinate is `s = -q - r`. `r` grows one row down the
## screen, and `q` grows to the right along a row. Offset coordinates use "odd-r": odd rows sit
## half a hex to the right. They exist only for rectangular storage and bounds.
##
## Determinism: no RNG, and every tie breaks the same way, so the same query returns the same
## answer on every machine (save and replay determinism, §1.8 of the tactical architecture).

## The six neighbours, in screen order: E, NE, NW, W, SW, SE. A direction index is a position
## in this list, and `opposite(d)` is `(d + 3) % 6`.
const DIRECTIONS: Array[Vector2i] = [
	Vector2i(1, 0), Vector2i(1, -1), Vector2i(0, -1),
	Vector2i(-1, 0), Vector2i(-1, 1), Vector2i(0, 1),
]
const DIRECTION_COUNT := 6


## Steps between two hexes along the grid (each of the six moves counts one).
static func distance(a: Vector2i, b: Vector2i) -> int:
	var dq := a.x - b.x
	var dr := a.y - b.y
	return (absi(dq) + absi(dr) + absi(dq + dr)) / 2


static func neighbor(hex: Vector2i, direction: int) -> Vector2i:
	return hex + DIRECTIONS[posmod(direction, DIRECTION_COUNT)]


static func neighbors(hex: Vector2i) -> Array[Vector2i]:
	var result: Array[Vector2i] = []
	for offset: Vector2i in DIRECTIONS:
		result.append(hex + offset)
	return result


static func opposite(direction: int) -> int:
	return posmod(direction + 3, DIRECTION_COUNT)


## The direction index from `from` to an adjacent `to`, or -1 when they are not neighbours.
static func direction_to_neighbor(from: Vector2i, to: Vector2i) -> int:
	return DIRECTIONS.find(to - from)


## The direction index that best points from `from` toward any other hex: the first step of a
## line between them. Returns -1 when the two hexes are the same. Used for facing (FR-105a).
static func direction_toward(from: Vector2i, to: Vector2i) -> int:
	if from == to:
		return -1
	var path := line(from, to)
	return direction_to_neighbor(from, path[1])


## Rounds fractional axial coordinates to the hex that contains them (cube rounding).
static func round_axial(fractional: Vector2) -> Vector2i:
	return round_qr(fractional.x, fractional.y)


## `round_axial` on 64-bit scalars, for callers that must not lose precision to `Vector2`'s
## 32-bit floats far from the origin.
static func round_qr(q: float, r: float) -> Vector2i:
	var s := -q - r
	var rq := roundf(q)
	var rr := roundf(r)
	var rs := roundf(s)
	var dq := absf(rq - q)
	var dr := absf(rr - r)
	var ds := absf(rs - s)
	if dq > dr and dq > ds:
		rq = -rr - rs
	elif dr > ds:
		rr = -rq - rs
	return Vector2i(int(rq), int(rr))


## Every hex on the straight line from `a` to `b`, both ends included: `distance(a, b) + 1`
## hexes, each a neighbour of the one before. Ties on a hex edge always break the same way
## (a tiny fixed nudge), so a line is stable.
static func line(a: Vector2i, b: Vector2i) -> Array[Vector2i]:
	var steps := distance(a, b)
	var result: Array[Vector2i] = [a]
	if steps == 0:
		return result
	# 64-bit scalars: a Vector2 would round the nudge away a few hundred hexes from the origin.
	var dq := float(b.x - a.x)
	var dr := float(b.y - a.y)
	for i in range(1, steps + 1):
		var t := float(i) / float(steps)
		result.append(round_qr(a.x + 1e-6 + dq * t, a.y + 1e-6 + dr * t))
	return result


## The hexes exactly `radius` steps from `center`: `6 * radius` of them, or the centre alone
## for radius 0. They start south-west of the centre and run around in direction order.
static func ring(center: Vector2i, radius: int) -> Array[Vector2i]:
	var result: Array[Vector2i] = []
	if radius < 0:
		return result
	if radius == 0:
		result.append(center)
		return result
	var hex := center + DIRECTIONS[4] * radius
	for side in DIRECTION_COUNT:
		for _step in radius:
			result.append(hex)
			hex = hex + DIRECTIONS[side]
	return result


## Every hex within `radius` steps of `center`: `3 * radius * (radius + 1) + 1` of them,
## the centre first, then each ring outward.
static func within(center: Vector2i, radius: int) -> Array[Vector2i]:
	var result: Array[Vector2i] = []
	for ring_radius in range(0, radius + 1):
		result.append_array(ring(center, ring_radius))
	return result


## Axial to "odd-r" offset (column, row): odd rows sit half a hex to the right.
static func axial_to_offset(hex: Vector2i) -> Vector2i:
	return Vector2i(hex.x + (hex.y - (hex.y & 1)) / 2, hex.y)


static func offset_to_axial(offset: Vector2i) -> Vector2i:
	return Vector2i(offset.x - (offset.y - (offset.y & 1)) / 2, offset.y)
