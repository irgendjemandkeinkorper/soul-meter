class_name WeftluminBrushes
extends RefCounted
## Brush geometry for the data-layer painters (`docs/architecture-in-game-editor.md` §4.6.3).
##
## Pure cell arithmetic in ONE layer's own cell space: no layer, no scene, no bus. The painter
## converts the pointer into that space first, so a brush never has to know whether its layer is
## scaled, offset or shares the ground's lattice.

enum Shape { CELL, RECT, LINE, FILL }

const LABELS: Array[String] = ["Cell", "Rect", "Line", "Fill"]
## A fill that runs away (an unbounded region, a wrong layer) refuses instead of painting the map.
const FILL_LIMIT := 8192
## Diamond-down neighbours sharing an edge. Fill is edge-connected, so it never leaks through a
## diagonal gap between two painted cells.
const EDGE_NEIGHBOURS: Array[Vector2i] = [
	Vector2i(1, 0), Vector2i(-1, 0), Vector2i(0, 1), Vector2i(0, -1),
]


## Every cell of the inclusive rectangle spanned by `a` and `b`, row by row.
static func rect(a: Vector2i, b: Vector2i) -> Array[Vector2i]:
	var cells: Array[Vector2i] = []
	for y: int in range(mini(a.y, b.y), maxi(a.y, b.y) + 1):
		for x: int in range(mini(a.x, b.x), maxi(a.x, b.x) + 1):
			cells.append(Vector2i(x, y))
	return cells


## Bresenham's line from `a` to `b`, both ends included, with no gaps along either axis.
static func line(a: Vector2i, b: Vector2i) -> Array[Vector2i]:
	var cells: Array[Vector2i] = []
	var delta := Vector2i(absi(b.x - a.x), -absi(b.y - a.y))
	var step := Vector2i(1 if a.x < b.x else -1, 1 if a.y < b.y else -1)
	var error: int = delta.x + delta.y
	var cursor := a
	while true:
		cells.append(cursor)
		if cursor == b:
			break
		var doubled: int = 2 * error
		if doubled >= delta.y:
			error += delta.y
			cursor.x += step.x
		if doubled <= delta.x:
			error += delta.x
			cursor.y += step.y
	return cells


## The cells a CELL, RECT or LINE gesture from `anchor` to `current` covers. FILL is not a
## two-point shape; see `fill()`.
static func shape_cells(shape: Shape, anchor: Vector2i, current: Vector2i) -> Array[Vector2i]:
	match shape:
		Shape.RECT:
			return rect(anchor, current)
		Shape.LINE:
			return line(anchor, current)
	return [current]


## Edge-connected cells reachable from `start` whose tile equals the start cell's, inside
## `bounds`. `tile_at` is `(cell: Vector2i) -> Array` (`[]` for an empty cell). Returns
## `{cells: Array[Vector2i], truncated: bool}`; a truncated fill must be refused, not applied.
static func fill(
	start: Vector2i, tile_at: Callable, bounds: Rect2i, limit: int = FILL_LIMIT
) -> Dictionary:
	var cells: Array[Vector2i] = []
	if not bounds.has_point(start):
		return {"cells": cells, "truncated": false}
	var target: Array = tile_at.call(start)
	var seen: Dictionary = {start: true}
	var pending: Array[Vector2i] = [start]
	while not pending.is_empty():
		var cell: Vector2i = pending.pop_back()
		cells.append(cell)
		if cells.size() > limit:
			return {"cells": [] as Array[Vector2i], "truncated": true}
		for offset: Vector2i in EDGE_NEIGHBOURS:
			var next: Vector2i = cell + offset
			if seen.has(next) or not bounds.has_point(next):
				continue
			seen[next] = true
			if tile_at.call(next) == target:
				pending.append(next)
	cells.sort()
	return {"cells": cells, "truncated": false}
