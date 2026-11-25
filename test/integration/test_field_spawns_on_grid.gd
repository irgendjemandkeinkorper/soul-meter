extends GdUnitTestSuite
## #649: every party spawn in a field must stand on a walkable cell of that field's grid. Dom's
## ground once covered only its western strip, so its new-game spawn and twelve other spawns
## were off the grid. A journey ambush then could not seat the party, and click-to-move from
## the spawn found no route.
##
## The grid is built the way ClickMoveController builds it. A marker counts when its cell is
## inside the grid and not blocked.
##
## Known exceptions, each still failing; the test fails when one starts passing, so the list
## cannot go stale. All are inside the grid on a blocked cell, outside #649's approved scope
## (Dom's grid coverage), and reported on its PR:
## - Dom's `SpawnFromRiverShrine` stands 20 px south of the shrine door, on the shrine's rock.
##   Before #649 it was off the grid. The walkable ground is north of the door.
## - Dorthkor Road's `SpawnFromHollowmere`, a walk-in arrival spawn.
## - Three `SpawnSlot*` markers: Weftlumin spawn-table anchors for NPCs and hostiles, not party
##   spawns.
const KNOWN_BLOCKED := {
	"starting_town.tscn:SpawnFromRiverShrine": true,
	"dorthkor_road.tscn:SpawnFromHollowmere": true,
	"ashlaren.tscn:SpawnSlotFieldMargin": true,
	"long_verge.tscn:SpawnSlotGraveMound": true,
	"hollowmere.tscn:SpawnSlotReedShallows": true,
}

const FIELD_SCENES: Array[String] = [
	"res://world/starting_town.tscn",
	"res://world/dorthkor_road.tscn",
	"res://world/kesselford.tscn",
	"res://world/ashlaren.tscn",
	"res://world/long_verge.tscn",
	"res://world/hollowmere.tscn",
	"res://world/wound_lip.tscn",
	"res://world/test_room.tscn",
]


func test_every_spawn_marker_stands_on_a_walkable_cell() -> void:
	var problems: PackedStringArray = []
	var still_blocked := {}
	for path: String in FIELD_SCENES:
		var root := (load(path) as PackedScene).instantiate() as Node2D
		add_child(root)
		await get_tree().process_frame
		var ground := root.find_child("IsometricGround", true, false) as TileMapLayer
		var blocking := root.find_child("Blocking", true, false) as TileMapLayer
		var grid := IsoGrid.new()
		grid.build(ground, blocking, ClickMoveController.STATIC_CLEARANCE_CELLS, true)
		for child: Node in root.get_children():
			if not (child is Marker2D and String(child.name).begins_with("Spawn")):
				continue
			var key := "%s:%s" % [path.get_file(), child.name]
			var cell := grid.world_to_cell((child as Marker2D).global_position)
			if not grid.is_in_bounds(cell):
				problems.append("%s: cell %s is outside the grid" % [key, cell])
			elif grid.is_point_solid(cell):
				if KNOWN_BLOCKED.has(key):
					still_blocked[key] = true
				else:
					problems.append("%s: cell %s is blocked" % [key, cell])
		root.free()
	for key: String in KNOWN_BLOCKED:
		if not still_blocked.has(key):
			problems.append("%s now stands on a walkable cell: remove it from KNOWN_BLOCKED" % key)
	assert_array(Array(problems)).override_failure_message("\n".join(problems)).is_empty()
