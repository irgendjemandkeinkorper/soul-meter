extends GdUnitTestSuite
## The lived-in dressing rules (owner 2026-11-02: "dense; small decor walkable"). Small decor
## never blocks; solid pieces block the cell they stand on; nothing standing enters a main
## route or a keep-clear zone; the same seed dresses a map the same way.

const DresserScript := preload("res://world/dressing/lived_in_dresser.gd")


func test_cells_round_trip_through_world_space() -> void:
	var origin := Vector2(1500, -780)
	for cell: Vector2i in [Vector2i.ZERO, Vector2i(3, 7), Vector2i(40, 12), Vector2i(104, 104)]:
		assert_vector(Vector2(DresserScript.cell_at(origin, DresserScript.cell_center(origin, cell)))).is_equal(Vector2(cell))


func test_the_same_seed_dresses_the_same_way_and_another_seed_does_not() -> void:
	var first := DresserScript.dress(_layout(), _catalog(), 7)
	var again := DresserScript.dress(_layout(), _catalog(), 7)
	var other := DresserScript.dress(_layout(), _catalog(), 8)
	assert_str(JSON.stringify(first["placements"])).is_equal(JSON.stringify(again["placements"]))
	assert_str(JSON.stringify(first["placements"])).is_not_equal(JSON.stringify(other["placements"]))


func test_nothing_standing_on_a_route_in_a_keep_clear_zone_or_outside_the_walls() -> void:
	var layout := _layout()
	var result := DresserScript.dress(layout, _catalog(), 11)
	var standing := (result["placements"] as Array).filter(func(row: Dictionary) -> bool: return row["layer"] == "props")
	assert_int(standing.size()).override_failure_message("the map gets dressed").is_greater(10)
	for row: Dictionary in standing:
		var at: Vector2 = row["position"]
		var cell := DresserScript.cell_at(layout["origin"], at)
		assert_bool((layout["corridor"] as Dictionary).has(cell)).override_failure_message("on the route: %s" % row["id"]).is_false()
		assert_bool((layout["occupied"] as Dictionary).has(cell)).override_failure_message("inside a building: %s" % row["id"]).is_false()
		assert_bool((layout["playable"] as Rect2).has_point(at)).is_true()
		for zone: Rect2 in layout["keep_clear"]:
			assert_bool(zone.has_point(at)).override_failure_message("in a keep-clear zone: %s" % row["id"]).is_false()


func test_solid_pieces_block_their_cell_and_walkable_decor_blocks_nothing() -> void:
	var layout := _layout()
	var result := DresserScript.dress(layout, _catalog(), 3)
	var blocked: Array[Vector2i] = result["blocked"]
	var solid_cells := {}
	for row: Dictionary in result["placements"]:
		if row["layer"] != "props":
			continue
		if row["solid"]:
			solid_cells[row["cell"]] = true
			assert_bool(blocked.has(row["cell"])).override_failure_message("solid %s blocks" % row["id"]).is_true()
	assert_int(blocked.size()).is_equal(solid_cells.size())
	assert_int(blocked.size()).override_failure_message("some wall bases are solid").is_greater(0)
	for cell: Vector2i in result["cover"]:
		assert_bool(blocked.has(cell)).override_failure_message("cover stands on a blocked cell").is_true()


func test_wall_base_clusters_sit_in_front_of_the_building() -> void:
	var layout := _layout()
	var result := DresserScript.dress(layout, _catalog(), 5)
	var front: Rect2 = (layout["structures"] as Array)[0]
	var near := (result["placements"] as Array).filter(func(row: Dictionary) -> bool:
		var at: Vector2 = row["position"]
		return row["layer"] == "props" and at.x >= front.position.x - 80.0 and at.x <= front.end.x + 80.0 \
			and at.y >= front.end.y - 8.0 and at.y <= front.end.y + 90.0)
	assert_int(near.size()).override_failure_message("the building front is dressed").is_greater_equal(3)


## A 40x40-cell yard: one building front, a route along one diagonal, a spawn zone.
func _layout() -> Dictionary:
	var origin := Vector2(0, 0)
	var cells := {}
	for y: int in 40:
		for x: int in 40:
			cells[Vector2i(x, y)] = true
	var building := Rect2(-200, 300, 400, 30)
	var occupied := {}
	for cell: Vector2i in cells:
		if building.grow(6.0).has_point(DresserScript.cell_center(origin, cell)):
			occupied[cell] = true
	var corridor := {}
	for i: int in 40:
		for d: int in range(-1, 2):
			corridor[Vector2i(i, clampi(i + d, 0, 39))] = true
	var playable := Rect2(-1200, 40, 2400, 1180)
	return {
		"origin": origin, "cells": cells, "occupied": occupied, "structures": [building],
		"keep_clear": [Rect2(Vector2(-700, 600), Vector2(160, 90))], "corridor": corridor,
		"playable": playable,
	}


func _catalog() -> Array[Dictionary]:
	var rows: Array[Dictionary] = []
	var add := func(id: String, category: String, placement: String, height: String) -> void:
		rows.append({"id": id, "texture": "res://%s.png" % id, "category": category,
			"placement": placement, "height_class": height, "content_height": 200.0})
	add.call("kf-ground-patch--wet-mud", "ground", "ground", "")
	add.call("kf-puddle--shallow", "ground", "ground", "")
	add.call("kf-scatter--straw", "ground", "ground", "")
	add.call("kf-ruts--straight", "ground", "ground", "")
	add.call("kf-barrel--upright", "wall-base", "solid", "waist")
	add.call("kf-crate--small", "wall-base", "solid", "knee")
	add.call("kf-bucket--wooden", "wall-base", "walkable", "small")
	add.call("kf-jars--clay-three", "wall-base", "walkable", "knee")
	add.call("kf-hay--bale", "yard", "solid", "knee")
	add.call("kf-cartwheel--leaning", "yard", "walkable", "waist")
	add.call("kf-weeds--tuft-a", "growth", "walkable", "small")
	add.call("kf-mushrooms--cluster", "growth", "walkable", "small")
	add.call("kf-bones--animal", "story", "walkable", "small")
	return rows
