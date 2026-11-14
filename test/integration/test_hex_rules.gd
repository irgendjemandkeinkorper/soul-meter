extends GdUnitTestSuite
## Hex slice H3b (owner item 34; docs/design/hex-grid-plan-2026-11-03.md, "How the rules carry
## over"): class rules that the square-cell suites pin to squares, played on hexes through the
## real controller. A reach doubles (Kindle 4 cells → 8 hexes, Thrust 2 → 4), a pull needs a foe
## exactly four hexes out on a hex axis and lands it touching, a fire line runs along any of the
## three hex axes, and the refusals name hexes.

const GridMode := preload("res://test/helpers/grid_mode.gd")
const NO_FIZZLE := {"fizzle": {"harmonic_accord": 100.0, "pitch": 10}}
const EAST := Vector2i(1, 0)
const NORTH_EAST := Vector2i(1, -1)

var _grid_before: Variant


func before_test() -> void:
	_grid_before = GridMode.use_hexes()


func after_test() -> void:
	GridMode.restore(_grid_before)


func test_a_ranged_card_reaches_twice_its_authored_cells_in_hexes() -> void:
	var battle := _battle(9)
	var controller: CombatController = battle["controller"]
	var kindle := controller.action_by_id(&"kindle")
	assert_int(kindle.reach_steps()).is_equal(8)
	var far := controller.query_action(kindle, battle["enemy"], NO_FIZZLE)
	assert_str(String(far["blocked_by"])).is_equal("blocked_by_range")
	_place(battle, 8)
	assert_bool(controller.query_action(kindle, battle["enemy"], NO_FIZZLE)["allowed"]).is_true()
	var thrust := controller.action_by_id(&"thrust")
	_place(battle, 5)
	var refused := controller.query_action(thrust, battle["enemy"])
	assert_str(String(refused["blocked_by"])).is_equal("blocked_by_range")
	assert_str(String(refused["message"])).override_failure_message(str(refused)).contains("4 hexes")
	_place(battle, 4)
	assert_bool(controller.query_action(thrust, battle["enemy"])["allowed"]).is_true()


func test_a_pull_needs_a_foe_four_hexes_out_on_an_axis_and_lands_it_touching() -> void:
	var battle := _battle(3)
	var controller: CombatController = battle["controller"]
	var enemy: BattleActor = battle["enemy"]
	var hook := controller.action_by_id(&"hook-and-draw")
	var near := controller.query_action(hook, enemy)
	assert_str(String(near["blocked_by"])).is_equal("pull_geometry")
	assert_str(String(near["message"])).is_equal(
		"%s needs an enemy exactly four hexes away on a straight line." % hook.display_name
	)
	# Four hexes out but off every hex axis.
	battle["grid"].displace(enemy, battle["centre"] + Vector2i(3, 1))
	assert_int(GridMetric.distance(battle["centre"], battle["centre"] + Vector2i(3, 1))).is_equal(4)
	assert_str(String(controller.query_action(hook, enemy)["blocked_by"])).is_equal("pull_geometry")
	_place(battle, 4)
	var hp_before := enemy.hp
	var outcome := controller.submit_action(&"hook-and-draw", enemy)
	assert_bool(outcome["allowed"]).override_failure_message(str(outcome)).is_true()
	assert_bool(bool(outcome["pulled"])).is_true()
	assert_int(enemy.hp).is_equal(hp_before)
	assert_object(battle["grid"].cell_of(enemy)).is_equal(battle["centre"] + EAST)


func test_a_fire_line_runs_along_any_hex_axis_and_its_refusals_name_hexes() -> void:
	var battle := _battle(6)
	var controller: CombatController = battle["controller"]
	var firebreak := controller.action_by_id(&"firebreak")
	var start: Vector2i = battle["centre"] + EAST * 2
	# The north-east axis: the square shape check took only two of the three hex axes.
	var line: Array[Vector2i] = [start, start + NORTH_EAST, start + NORTH_EAST * 2]
	var bent: Array[Vector2i] = [start, start + EAST, start + EAST + Vector2i(0, 1)]
	var refused := controller.query_action(firebreak, null, _with_cells(bent))
	assert_str(String(refused["blocked_by"])).is_equal("line_shape")
	assert_str(String(refused["message"])).is_equal(
		"%s burns three hexes in a straight, touching line." % firebreak.display_name
	)
	var short := controller.query_action(firebreak, null, _with_cells(line.slice(0, 2)))
	assert_str(String(short["message"])).is_equal("%s marks exactly 3 distinct hexes." % firebreak.display_name)
	var far_start: Vector2i = battle["centre"] + EAST * 9
	var far := controller.query_action(
		firebreak, null, _with_cells([far_start, far_start + NORTH_EAST, far_start + NORTH_EAST * 2])
	)
	assert_str(String(far["blocked_by"])).is_equal("blocked_by_range")
	assert_str(String(far["message"])).is_equal("%s reaches 8 hexes." % firebreak.display_name)
	var outcome := controller.submit_action(&"firebreak", null, _with_cells(line))
	assert_bool(outcome["allowed"]).override_failure_message(str(outcome)).is_true()
	for cell: Vector2i in line:
		assert_bool(controller.fire.is_burning_cell(cell)).override_failure_message(str(cell)).is_true()


func test_a_walk_reads_in_hexes() -> void:
	var battle := _battle(6)
	var controller: CombatController = battle["controller"]
	var model: GridBattlefieldModel = battle["grid"]
	var destination := model._handle_for_cell((battle["centre"] as Vector2i) + EAST * 2)
	var outcome := controller.submit_action(&"move", null, {"destination": destination})
	assert_bool(outcome["allowed"]).override_failure_message(str(outcome)).is_true()
	assert_str(String(outcome.get("message", ""))).is_equal("Magistrate moves 2 hexes.")


# --- helpers -----------------------------------------------------------------------------------


## A Pazzah Ash Magistrate and a dummy on a flat twelve-by-twelve-cell board, the dummy `steps`
## hexes east of the magistrate. Both stand on hexes near the board's middle.
func _battle(steps: int) -> Dictionary:
	var rules := (load("res://data/combat/combat_rules.tres") as CombatRules).duplicate(true) as CombatRules
	rules.use_charge_time = false
	rules.base_action_points = 8
	var grid := GridBattlefieldModel.new()
	grid.configure(rules)
	grid.build_grid(_grid_ground())
	var centre: Vector2i = grid._grid.cell_at_square(Vector2i(6, 6))
	var ally := _actor("Magistrate", 60, 12, 0)
	ally.breath = 60
	ally.attributes = {"harmony": 0, "alacrity": 4}
	ally.defining_effects = {"hit": true}
	ally.source_member = PartyMember.new()
	ally.source_member.id = "hex-rules-test"
	ally.source_member.patron = "Pazzah"
	var enemy := _actor("Dummy", 60, 1, 0)
	assert_bool(grid.configure_initial_cells({ally: centre, enemy: centre + EAST * steps})["allowed"]).is_true()
	var controller := CombatController.new()
	controller.configure(CombatActionCatalog.all(), grid, rules)
	controller.start([ally], [enemy], &"hex-rules-test")
	return {"controller": controller, "ally": ally, "enemy": enemy, "grid": grid, "centre": centre}


func _place(battle: Dictionary, steps: int) -> void:
	battle["grid"].displace(battle["enemy"], (battle["centre"] as Vector2i) + EAST * steps)


func _with_cells(cells: Array) -> Dictionary:
	var data: Array[Dictionary] = []
	for cell: Vector2i in cells:
		data.append({"x": cell.x, "y": cell.y})
	return {"cells": data}


func _actor(name: String, hp: int, attack: int, defense: int) -> BattleActor:
	var actor := BattleActor.new()
	actor.display_name = name
	actor.hp = hp
	actor.max_hp = hp
	actor.attack = attack
	actor.defense = defense
	return actor


func _grid_ground() -> TileMapLayer:
	var tile_set := TileSet.new()
	tile_set.tile_shape = TileSet.TILE_SHAPE_ISOMETRIC
	tile_set.tile_layout = TileSet.TILE_LAYOUT_DIAMOND_DOWN
	tile_set.tile_size = Vector2i(64, 32)
	var image := Image.create(64, 32, false, Image.FORMAT_RGBA8)
	var source := TileSetAtlasSource.new()
	source.texture = ImageTexture.create_from_image(image)
	source.texture_region_size = Vector2i(64, 32)
	source.create_tile(Vector2i.ZERO)
	tile_set.add_source(source, 0)
	var layer := auto_free(TileMapLayer.new()) as TileMapLayer
	layer.tile_set = tile_set
	for x: int in 12:
		for y: int in 12:
			layer.set_cell(Vector2i(x, y), 0, Vector2i.ZERO)
	return layer
