extends GdUnitTestSuite
## Integration tests for actors/player/click_move_controller.gd (GH #162,
## docs/architecture-tactical-and-navigation.md §2.5).
##
## The refusal test exercises the FULL real world/starting_town.tscn scene
## through gdUnit4's SceneRunner: a real simulated mouse click flows through
## the engine's normal input dispatch into `_unhandled_input`, exactly like a
## player click would in-game — this is deliberate. GH #162's own trap
## warning says a refusal that only a unit test sees "does not exist"; that
## test proves the refusal fires from a real click on the real scene, not
## merely that the controller function returns a dictionary.
##
## The walking tests (path-around-a-building, WASD cancel, facing direction)
## instead run against an ISOLATED fixture: the real `IsometricGround` and
## `Blocking` `TileMapLayer`s duplicated straight out of starting_town.tscn
## (so the obstacle data — the actual painted building footprints — is the
## real thing), plus a fresh `player.tscn` instance, with none of the town's
## ~35 spawned townsfolk or decorative props in the tree. Those aren't part
## of `Blocking` (the architecture doc's single source of truth for
## passability, §2.3) and were never going to be known to `IsoGrid` — a
## `CharacterBody2D` can still physically collide with one mid-route, which
## is a real property of the populated town scene but has nothing to do with
## this controller. Isolating the fixture keeps these tests about what this
## issue actually owns: routing around a *painted obstacle*.


const TOWN_SCENE_PATH := "res://world/starting_town.tscn"
const PLAYER_SCENE_PATH := "res://actors/player/player.tscn"


## Converts a world position to the current viewport's screen space via the
## viewport's own canvas_transform, so the click lands on the target
## regardless of the player's camera position/smoothing state at the time.
func _screen_position(viewport: Viewport, world_position: Vector2) -> Vector2:
	return viewport.canvas_transform * world_position


## Builds a fixture with the REAL Ground/Blocking data from starting_town.tscn
## (both self-build their tiles procedurally in `_ready()`, so duplicating
## them and re-parenting is enough to get the same obstacle layout) and a
## fresh player, with no other scene content. Returns
## {player, controller, grid, ground, blocking}.
func _isolated_town_fixture() -> Dictionary:
	var town := (load(TOWN_SCENE_PATH) as PackedScene).instantiate()
	var ground: TileMapLayer = (town.find_child("IsometricGround", true, false) as TileMapLayer).duplicate()
	var blocking: TileMapLayer = (town.find_child("Blocking", true, false) as TileMapLayer).duplicate()
	town.queue_free()

	var fixture: Node2D = auto_free(Node2D.new())
	fixture.name = "IsolatedTownFixture"
	fixture.add_child(ground)
	fixture.add_child(blocking)
	var player := (load(PLAYER_SCENE_PATH) as PackedScene).instantiate() as CharacterBody2D
	fixture.add_child(player)

	var runner := scene_runner(fixture)
	await runner.simulate_frames(5)

	var grid := IsoGrid.new()
	grid.build(ground, blocking, 0, true)

	var controller: ClickMoveController = player.find_child("ClickMoveController", true, false)
	return {
		"runner": runner,
		"player": player,
		"controller": controller,
		"grid": grid,
	}


func test_click_paths_the_player_around_a_building() -> void:
	var fixture := await _isolated_town_fixture()
	var runner: GdUnitSceneRunner = fixture["runner"]
	var player: CharacterBody2D = fixture["player"]
	var controller: ClickMoveController = fixture["controller"]
	var grid: IsoGrid = fixture["grid"]

	# The old (20,25)->(24,38) coordinates predated Dom's 3400x2200 layout rework
	# and now cross open ground; this pair straddles a current painted building footprint.
	var start_cell := Vector2i(20, 10)
	var destination_cell := Vector2i(35, 12)
	player.global_position = grid.cell_to_world(start_cell)
	await runner.simulate_frames(2)
	# A straight line between the two cells crosses at least one solid cell —
	# proves this is a genuine detour, not a walk across open ground.
	var crosses_solid := false
	var steps := 30
	for i in range(steps + 1):
		var t := float(i) / float(steps)
		var cell := Vector2i(
			roundi(lerpf(float(start_cell.x), float(destination_cell.x), t)),
			roundi(lerpf(float(start_cell.y), float(destination_cell.y), t))
		)
		if grid.is_point_solid(cell):
			crosses_solid = true
			break
	assert_bool(crosses_solid) \
		.override_failure_message("test fixture regression: the straight line no longer crosses a building") \
		.is_true()

	var destination_world := grid.cell_to_world(destination_cell)
	var result := controller.request_move_to(destination_world)
	assert_bool(result.get("allowed")).is_true()
	assert_bool(controller.has_path()).is_true()

	# The old 400-frame budget was stale for the longer current-layout detour.
	for _batch in range(40):
		await runner.simulate_frames(25)
		if not controller.has_path():
			break

	assert_float(player.global_position.distance_to(destination_world)).is_less(20.0)
	# The path is finished, not just "close enough while still queued".
	assert_bool(controller.has_path()).is_false()


func test_unreachable_click_refusal_reaches_the_player_seam() -> void:
	var runner := scene_runner(TOWN_SCENE_PATH)
	await runner.simulate_frames(10)

	# gdUnit4 boots the whole project under test, including
	# `run/main_scene` (main_menu.tscn), which stays parented at
	# `/root/MainMenu` — a full-screen Control with the default STOP mouse
	# filter — alongside our loaded StartingTown. Left alone it silently
	# swallows every simulated click before it ever reaches the world scene.
	# That's a test-harness artifact of running two scenes under one
	# viewport, not something to touch in game code.
	# Hiding only a node named "MainMenu" is not enough in a FULL suite run:
	# earlier suites leave their own root-level Controls behind, and ANY
	# full-screen Control with the default STOP mouse filter swallows the click
	# before it reaches the world. Neutralise every root-level Control that is
	# not our scene, so this test does not depend on suite ordering.
	_silence_root_controls(runner.scene())

	var player: CharacterBody2D = runner.find_child("Player", true, false)
	var blocking: TileMapLayer = runner.find_child("Blocking", true, false)
	var ground: TileMapLayer = runner.find_child("IsometricGround", true, false)
	var controller: ClickMoveController = player.find_child("ClickMoveController", true, false)

	var grid := IsoGrid.new()
	grid.build(ground, blocking, 0, true)

	# The old (21,6) target predated Dom's scaled 3400x2200 Blocking transform.
	var blocked_cell := Vector2i(-1, -1)
	for cell in ground.get_used_cells():
		if grid.is_point_solid(cell):
			blocked_cell = cell
			break
	assert_bool(blocked_cell != Vector2i(-1, -1)).is_true()
	var target_world := grid.cell_to_world(blocked_cell)

	# Dictionaries are reference types, so mutating one from inside a lambda
	# is visible here afterward — reassigning a captured local var would not
	# be (GDScript lambdas capture outer locals by value).
	var captured := {"controller_refusal": {}, "player_refusal": {}}
	controller.move_refused.connect(func(r: Dictionary) -> void: captured["controller_refusal"] = r)
	player.move_refused.connect(func(r: Dictionary) -> void: captured["player_refusal"] = r)

	# HONEST LIMITATION. This dispatches a real InputEventMouseButton straight
	# into the controller's own `_unhandled_input`, rather than pushing it
	# through the viewport with simulate_mouse_button_pressed().
	#
	# The simulated-viewport version was tried first and abandoned: gdUnit4 boots
	# the whole project, so `run/main_scene` shares one root with the scene under
	# test, and simulated pointer input does not reliably reach a second scene in
	# a headless run. It passed alone and failed in a full suite, which is worse
	# than a weaker test that is honest about its scope.
	#
	# What this DOES still prove is the thing that actually broke elsewhere in
	# this project: a refusal that is produced but never reaches its consumer.
	# The husked-casting refusal passed ten unit tests and would never have fired
	# in a real cast, because a separate eligibility list did not know about it.
	# So: handler -> request_move_to -> refusal -> Player re-emit, end to end
	# across the seam. What it does NOT prove is that a viewport click reaches
	# the handler; #191 tracks that.
	var button := InputEventMouseButton.new()
	button.button_index = MOUSE_BUTTON_LEFT
	button.pressed = true
	button.position = player.get_canvas_transform() * target_world
	controller._unhandled_input(button)
	await runner.simulate_frames(2)

	var controller_refusal: Dictionary = captured["controller_refusal"]
	var player_refusal: Dictionary = captured["player_refusal"]

	assert_dict(controller_refusal).is_not_empty()
	assert_bool(controller_refusal.get("allowed")).is_false()
	assert_that(controller_refusal.get("blocked_by")).is_equal(&"blocked_by_obstacle")
	assert_str(String(controller_refusal.get("message", ""))).is_not_empty()

	# Player.move_refused re-emits the same shape — this is the seam a future
	# HUD/UI listener hooks. It must not be silent either.
	assert_dict(player_refusal).is_not_empty()
	assert_bool(player_refusal.get("allowed")).is_false()
	assert_that(player_refusal.get("blocked_by")).is_equal(&"blocked_by_obstacle")


func test_unreachable_click_refusal_has_a_distinct_blocked_by_from_a_solid_target() -> void:
	# Two different causes must produce two different blocked_by tags —
	# collapsing them into one generic "invalid move" loses the property the
	# amendment's §2.2 refusal taxonomy exists to preserve.
	var runner := scene_runner(TOWN_SCENE_PATH)
	await runner.simulate_frames(10)

	var player: CharacterBody2D = runner.find_child("Player", true, false)
	var controller: ClickMoveController = player.find_child("ClickMoveController", true, false)

	# Far outside the painted map region: not solid, but unreachable/out of bounds.
	var far_away_world := Vector2(1000000.0, 1000000.0)
	var refusal := controller.request_move_to(far_away_world)

	assert_bool(refusal.get("allowed")).is_false()
	assert_that(refusal.get("blocked_by")).is_not_equal(&"blocked_by_obstacle")
	assert_str(String(refusal.get("message", ""))).is_not_empty()


func test_wasd_still_moves_the_player_and_cancels_an_active_click_path() -> void:
	var fixture := await _isolated_town_fixture()
	var runner: GdUnitSceneRunner = fixture["runner"]
	var player: CharacterBody2D = fixture["player"]
	var controller: ClickMoveController = fixture["controller"]
	var grid: IsoGrid = fixture["grid"]

	var start_cell := Vector2i(20, 25)
	player.global_position = grid.cell_to_world(start_cell)
	await runner.simulate_frames(2)

	var destination_world := grid.cell_to_world(Vector2i(24, 38))
	var result := controller.request_move_to(destination_world)
	assert_bool(result.get("allowed")).is_true()
	assert_bool(controller.has_path()).is_true()

	var start_x: float = player.global_position.x
	runner.simulate_action_press("move_left")
	await runner.simulate_frames(30)
	runner.simulate_action_release("move_left")

	# WASD wins: the click path is cancelled and the player actually moved
	# under keyboard control (FR-607 — debug/accessibility path).
	assert_bool(controller.has_path()).is_false()
	assert_float(player.global_position.x).is_less(start_x)


func test_facing_direction_updates_while_following_a_click_path() -> void:
	var fixture := await _isolated_town_fixture()
	var runner: GdUnitSceneRunner = fixture["runner"]
	var player: CharacterBody2D = fixture["player"]
	var controller: ClickMoveController = fixture["controller"]
	var grid: IsoGrid = fixture["grid"]

	# The old (20,25) eastward target became obstructed by Dom's scaled Blocking layout.
	var start_cell := Vector2i(0, 0)
	player.global_position = grid.cell_to_world(start_cell)
	await runner.simulate_frames(2)

	# Along an open isometric row — a simple direction with a positive screen-space X.
	var destination_world := grid.cell_to_world(Vector2i(5, 0))
	var result := controller.request_move_to(destination_world)
	assert_bool(result.get("allowed")).is_true()

	await runner.simulate_frames(15)

	assert_float(player.facing_direction.x).is_greater(0.0)


func test_footstep_spacing_constant_is_unchanged() -> void:
	# Regression guard: click-to-move must not have touched FOOTSTEP_SPACING
	# or the footstep mechanism (it consumes get_last_motion() the same way
	# regardless of whether motion came from WASD or a click path).
	var player_script := load("res://actors/player/player.gd")
	assert_float(player_script.FOOTSTEP_SPACING).is_equal_approx(78.0, 0.001)


## Make every root-level Control transparent to the simulated click.
##
## gdUnit4 boots the whole project, so `run/main_scene` and anything a previous
## suite parented to the root share one viewport with the scene under test. A
## Control there eats input regardless of what it is called, which made this
## test pass alone and fail in a full run.
func _silence_root_controls(scene_under_test: Node) -> void:
	var root := scene_under_test.get_tree().root
	for child in root.get_children():
		if child == scene_under_test or not child is Control:
			continue
		var control := child as Control
		control.visible = false
		control.mouse_filter = Control.MOUSE_FILTER_IGNORE


func test_click_path_routes_around_a_standing_npc_rather_than_into_it() -> void:
	# GH #190. The building test above deliberately excludes the town's actors; this one adds
	# exactly one back, because an NPC is the case that was broken: AStarGrid2D saw open ground,
	# move_and_slide() hit a body, and the player ground into a shopkeeper.
	var fixture := await _isolated_town_fixture()
	var runner: GdUnitSceneRunner = fixture["runner"]
	var player: CharacterBody2D = fixture["player"]
	var controller: ClickMoveController = fixture["controller"]
	var grid: IsoGrid = fixture["grid"]
	var root: Node = player.get_parent()

	# An open east-west run between ItemShop and BellHouse. Asserted, not assumed — if someone
	# paints a building here the failure should say so rather than pass vacuously.
	var start_cell := Vector2i(18, 25)
	var blocked_cell := Vector2i(22, 25)
	var destination_cell := Vector2i(26, 25)
	for x in range(start_cell.x, destination_cell.x + 1):
		assert_bool(grid.is_point_solid(Vector2i(x, start_cell.y))) \
			.override_failure_message(
				"test fixture regression: cell (%d, %d) is no longer open ground" % [x, start_cell.y]
			) \
			.is_false()

	player.global_position = grid.cell_to_world(start_cell)
	var npc := (load("res://actors/npc/npc.tscn") as PackedScene).instantiate() as NPC
	npc.name = "BlockingTownsperson"
	root.add_child(npc)
	npc.global_position = grid.cell_to_world(blocked_cell)
	await runner.simulate_frames(3)

	assert_bool(npc.is_in_group(NavOccupancy.GROUP)) \
		.override_failure_message("an NPC must register itself as a nav blocker") \
		.is_true()

	var destination_world := grid.cell_to_world(destination_cell)
	var result := controller.request_move_to(destination_world)
	assert_bool(result.get("allowed")).is_true()

	# The load-bearing assertion: not one waypoint lands on the NPC's cell.
	var waypoints: Array = result.get("path", [])
	assert_int(waypoints.size()).is_greater(0)
	var npc_cell_world := grid.cell_to_world(blocked_cell)
	for point in waypoints:
		assert_vector(Vector2(point)) \
			.override_failure_message(
				"path waypoint %s lands on the NPC's cell %s" % [point, npc_cell_world]
			) \
			.is_not_equal(npc_cell_world)

	# And the detour actually works: the player reaches the far side, it does not wedge and
	# rely on #162's stuck-recovery to bail it out.
	await runner.simulate_frames(400)
	assert_float(player.global_position.distance_to(destination_world)).is_less(24.0)


func test_the_player_is_never_an_obstacle_to_their_own_path() -> void:
	# Trivially true to state, easy to break: if the player registered as an occupant, their own
	# starting cell would be solid and every click would refuse.
	var fixture := await _isolated_town_fixture()
	var runner: GdUnitSceneRunner = fixture["runner"]
	var player: CharacterBody2D = fixture["player"]
	var controller: ClickMoveController = fixture["controller"]
	var grid: IsoGrid = fixture["grid"]

	var start_cell := Vector2i(18, 25)
	player.global_position = grid.cell_to_world(start_cell)
	await runner.simulate_frames(3)

	var result := controller.request_move_to(grid.cell_to_world(Vector2i(24, 25)))
	assert_bool(result.get("allowed")) \
		.override_failure_message("the player blocked their own path: %s" % result) \
		.is_true()
	assert_bool(controller.has_path()).is_true()
