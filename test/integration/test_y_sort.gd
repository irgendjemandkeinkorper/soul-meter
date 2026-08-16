extends GdUnitTestSuite
## Verifies the isometric depth-sorting rules from
## docs/architecture-tactical-and-navigation.md §2.4 hold for the two
## occupied world scenes (world/starting_town.tscn, world/test_room.tscn).
##
## This project runs headless in CI, so there is no way to *see* a sprite pop
## in front of a building. Godot's Y-sort reordering itself happens inside
## the renderer and is not queryable from script, so these tests assert the
## scene-tree PRECONDITIONS that make correct sorting possible/guaranteed:
## the common-parent flag, the ground's fixed z_index staying out of the
## sort, and every sortable sprite's origin sitting at its feet (not its
## centre). We did NOT visually confirm on-screen occlusion in this
## environment — see the task report for that caveat.

const WORLD_SCENES := [
	"res://world/starting_town.tscn",
	"res://world/test_room.tscn",
]
const UnitArtScript := preload("res://globals/unit_art.gd")

## Background/ground elements are deliberately kept OUTSIDE y-sorting via a
## fixed z_index (rule 2). Everything else at the top level of a world scene
## is expected to participate in y-sort with a neutral (0) z_index so that
## the player and props can occlude each other purely by y-position.
const EXPECTED_BACKGROUND_Z_INDEX := {
	"Shoreline": -15,
	"Waterline": -14,
	"WaterBackdrop": -20,
	"IsometricGround": -10,
	"Floor": -20,
}


func test_world_scene_roots_enable_y_sort_on_the_common_parent() -> void:
	for scene_path in WORLD_SCENES:
		var runner := scene_runner(scene_path)
		var root := runner.scene()
		assert_bool(root.y_sort_enabled) \
			.override_failure_message("%s root must set y_sort_enabled = true" % scene_path) \
			.is_true()


func test_ground_layer_keeps_fixed_z_index_and_is_not_itself_y_sorted() -> void:
	for scene_path in WORLD_SCENES:
		var runner := scene_runner(scene_path)
		var ground: TileMapLayer = runner.find_child("IsometricGround", true, false)
		assert_object(ground).is_not_null()
		assert_int(ground.z_index).is_equal(-10)
		# The ground itself is a leaf layer, not a container of sortable
		# sprites, so it must not enable y-sort of its own.
		assert_bool(ground.y_sort_enabled).is_false()


func test_no_stray_z_index_breaks_top_level_y_sort() -> void:
	# z_index takes priority over Y-sort in Godot: any top-level sibling with
	# a non-zero z_index can never be correctly occluded by (or occlude) the
	# player, regardless of position. Only the known background/ground
	# elements are allowed a fixed z_index; everything else must stay at the
	# neutral default so sorting is decided purely by feet position.
	for scene_path in WORLD_SCENES:
		var runner := scene_runner(scene_path)
		var root: Node2D = runner.scene()
		for child in root.get_children():
			if not (child is CanvasItem):
				continue
			var expected: int = EXPECTED_BACKGROUND_Z_INDEX.get(child.name, 0)
			assert_int(child.z_index) \
				.override_failure_message(
					"%s: %s has z_index %d, expected %d — this would defeat y-sort" % [
						scene_path, child.name, child.z_index, expected
					]
				) \
				.is_equal(expected)


func test_player_sprite_origin_is_at_the_feet_not_the_centre() -> void:
	var runner := scene_runner("res://world/test_room.tscn")
	var player: Node2D = runner.find_child("Player", true, false)
	var sprite: Sprite2D = player.find_child("Sprite2D", true, false)
	# The sprite must be drawn ABOVE the node's own origin (negative local Y)
	# so that the actor's Node2D position — the value y-sort compares — sits
	# at the feet, not the sprite's vertical centre.
	assert_float(sprite.position.y).is_less(0.0)


func test_npc_and_enemy_sprite_origins_are_at_the_feet() -> void:
	var runner := scene_runner("res://world/test_room.tscn")
	for name in ["IrisIllepah", "BogWight", "LoamBoar"]:
		var actor: Node2D = runner.find_child(name, true, false)
		var sprite: Sprite2D = actor.find_child("Sprite2D", true, false)
		assert_object(sprite) \
			.override_failure_message("%s has no Sprite2D child" % name) \
			.is_not_null()
		# The old negative-node-position expectation was stale after UnitArt moved grounding to offset.
		assert_vector(sprite.offset) \
			.override_failure_message("%s's painterly art must be offset to its feet" % name) \
			.is_equal(UnitArtScript.PIVOT_OFFSET)


func test_actors_own_local_y_sort_does_not_leak_a_fixed_z_index() -> void:
	# Player/NPC/Enemy each enable y_sort_enabled on themselves too — that is
	# correct (it sorts their own Shadow vs Sprite2D children) and distinct
	# from rule 1, which is about the WORLD scene's common parent. What rule
	# 1 forbids is a *fixed* z_index on the sortable sprite itself.
	var runner := scene_runner("res://world/test_room.tscn")
	for name in ["Player", "IrisIllepah", "BogWight"]:
		var actor: Node2D = runner.find_child(name, true, false)
		assert_int(actor.z_index) \
			.override_failure_message("%s must not pin a fixed z_index" % name) \
			.is_equal(0)


func test_building_group_and_its_door_prop_can_occlude_the_player() -> void:
	# Regression guard for the bug this issue fixed: several decorative
	# "door" and accent sprites in starting_town.tscn (e.g.
	# RegistryArchiveDoorSprite) were pinned to z_index = 2, which always
	# drew them in front of the player no matter where the player stood.
	# That defeats "a prop hides the player when the player stands above it,
	# and the player hides the prop when the player stands below it," since
	# z_index outranks y-sort. Assert they now sit in the shared z_index = 0
	# bucket alongside the player and building groups, so occlusion is
	# decided purely by feet position (y-sort).
	var runner := scene_runner("res://world/starting_town.tscn")
	var player: Node2D = runner.find_child("Player", true, false)
	var building: Node2D = runner.find_child("RegistryArchive", true, false)
	# RegistryArchiveDoorSprite was stale after the Dom rework nested the prop as ArchiveDoor.
	var door_prop: Node2D = building.find_child("ArchiveDoor", true, false)

	assert_object(player).is_not_null()
	assert_object(building).is_not_null()
	assert_object(door_prop).is_not_null()

	assert_int(player.z_index).is_equal(0)
	assert_int(building.z_index).is_equal(0)
	assert_int(door_prop.z_index).is_equal(0)

	# The door prop sits a little "south" (larger y / closer to camera) of
	# the building's own origin, so with equal z_index it correctly draws
	# in front of the building block via y-sort.
	assert_float(door_prop.global_position.y).is_greater(building.global_position.y)
