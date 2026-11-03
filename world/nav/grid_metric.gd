class_name GridMetric
extends RefCounted
## How combat counts steps on the grid (owner item 34, hex slice H2;
## `docs/design/hex-grid-plan-2026-11-03.md`, "How the rules carry over").
##
## On the square grid a step is one cell, and distance is Chebyshev: the eight neighbours are all
## one step away. On hexes (`soul_meter/grid/hex`) a step is one hex, half a cell side, and
## distance counts hex steps, so a range is a near-circle.
##
## Every authored number keeps its value: reaches, radii and pushes are written in cells, and
## they convert here, at one place, so a hex fight covers the same ground as a square one.
## - Reach: a reach of 1 (melee, touch) stays 1, touching hexes. A reach of 2 or more doubles.
## - Radius: always doubles, so "within 1" still holds the ring around the centre.
##
## The project setting is the one switch: the field grid, the battlefield model and this class
## all read it, so they always agree.


static func hex() -> bool:
	return IsoGrid.hex_enabled()


## Steps between two cells: Chebyshev on squares, hex steps on hexes.
static func distance(a: Vector2i, b: Vector2i) -> int:
	if hex():
		return HexMath.distance(a, b)
	return maxi(absi(a.x - b.x), absi(a.y - b.y))


## An authored reach in cells, in steps of this grid. Melee and touch (1) stay touching.
static func reach(cells: int) -> int:
	if not hex() or cells <= 1:
		return cells
	return cells * 2


## An authored radius in cells, in steps of this grid.
static func radius(cells: int) -> int:
	return cells * 2 if hex() else cells


## The steps one move can take from a cell.
static func neighbor_offsets() -> Array[Vector2i]:
	return HexMath.DIRECTIONS if hex() else IsoGrid.NEIGHBOR_OFFSETS


## The cells exactly `steps` away, in a fixed order.
static func ring(center: Vector2i, steps: int) -> Array[Vector2i]:
	if hex():
		return HexMath.ring(center, steps)
	var cells: Array[Vector2i] = []
	if steps <= 0:
		cells.append(center)
		return cells
	for dy in range(-steps, steps + 1):
		for dx in range(-steps, steps + 1):
			if maxi(absi(dx), absi(dy)) == steps:
				cells.append(center + Vector2i(dx, dy))
	return cells


## Every cell within `steps` of the centre, the centre included.
static func within(center: Vector2i, steps: int) -> Array[Vector2i]:
	if hex():
		return HexMath.within(center, steps)
	var cells: Array[Vector2i] = []
	for dy in range(-steps, steps + 1):
		for dx in range(-steps, steps + 1):
			cells.append(center + Vector2i(dx, dy))
	return cells


## The unit step from `from` toward `to` when `to` lies on one of the grid's straight lines
## through `from` (the four square cardinals, or the six hex axes); otherwise zero. Pushes and
## pulls move along these lines.
static func straight_step(from: Vector2i, to: Vector2i) -> Vector2i:
	var delta := to - from
	if delta == Vector2i.ZERO:
		return Vector2i.ZERO
	if hex():
		var steps := HexMath.distance(from, to)
		for direction: Vector2i in HexMath.DIRECTIONS:
			if direction * steps == delta:
				return direction
		return Vector2i.ZERO
	if (delta.x == 0) != (delta.y == 0):
		return delta.sign()
	return Vector2i.ZERO


## The step from `from` that heads most directly toward `to`: on squares the sign of the delta,
## which may be diagonal; on hexes the first step of the hex line.
static func step_toward(from: Vector2i, to: Vector2i) -> Vector2i:
	if from == to:
		return Vector2i.ZERO
	if hex():
		return HexMath.DIRECTIONS[HexMath.direction_toward(from, to)]
	return (to - from).sign()
