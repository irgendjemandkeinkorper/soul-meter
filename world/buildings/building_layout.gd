class_name BuildingLayout
extends Resource
## A walk-in building's floor plan as text, one character per ground cell (owner list item 35,
## layouts ruled 2026-11-04). `BuildingPlan` reads it: `#` wall, `W` window, `D` doorway, `.`
## floor, a space for outside, and the furniture letters of `BuildingPlan.FURNITURE`. Rows run
## from the back of the building to its front; a building on a map may turn its layout.

@export var rows := PackedStringArray()


## The plan of this layout turned `quarter_turns` times (`BuildingPlan.turned`).
func plan(quarter_turns := 0) -> BuildingPlan:
	return BuildingPlan.from_rows(rows, quarter_turns)
