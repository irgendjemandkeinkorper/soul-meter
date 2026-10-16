extends GdUnitTestSuite
## E6.2 (#350, architecture §4.11): the Harmonic Accord saturation lint as a `scenes` bake
## validator. It warns when `base_adjusted + max(zone_delta) + 10 > 100` or
## `base_adjusted + min(zone_delta) - 10 < 0`, and a warning never blocks the bake.

const GROUND_TILES := preload("res://assets/generated/sprites/ground/ground_tileset.tres")
const ZONE_SCENE := preload("res://actors/accord_zone/accord_zone.tscn")
## A scene path no committed location owns; the crafted location registers it for the session.
const CRAFTED_SCENE := "res://world/gdunit_accord_saturation_fixture.tscn"
const LATTICE := Vector2i(12, 12)

var _kind: WeftluminScenesKind


func before_test() -> void:
	_kind = WeftluminScenesKind.new()


func after_test() -> void:
	LocationRegistry._clear_runtime()


func test_lint_fires_high_on_a_crafted_over_range_location() -> void:
	_register(92.0)
	var root := _field_scene([[Vector2i(4, 4), 6, 1]])
	var warnings: Array[Dictionary] = _kind.accord_saturation({"scene": CRAFTED_SCENE, "instance": root})
	assert_int(warnings.size()).is_equal(1)
	var warning: Dictionary = warnings[0]
	assert_str(str(warning["severity"])).is_equal("warning")
	assert_str(str(warning["code"])).is_equal("accord_saturation")
	assert_str(str(warning["file"])).is_equal(CRAFTED_SCENE)
	# 92 + 6 + 10 = 108 > 100.
	assert_str(str(warning["message"])).contains("gdunit_crafted_accord saturates high")
	assert_str(str(warning["message"])).contains("108.0")


func test_lint_fires_low_and_high_together_on_an_impossible_band() -> void:
	_register(50.0)
	var root := _field_scene([[Vector2i(3, 3), 45, 0], [Vector2i(8, 8), -45, 0]])
	var warnings: Array[Dictionary] = _kind.accord_saturation({"scene": CRAFTED_SCENE, "instance": root})
	assert_int(warnings.size()).is_equal(2)
	assert_str(str(warnings[0]["message"])).contains("saturates high")
	assert_str(str(warnings[1]["message"])).contains("saturates low")


func test_an_in_range_location_is_silent() -> void:
	_register(60.0)
	var root := _field_scene([[Vector2i(3, 3), 20, 1], [Vector2i(8, 8), -30, 1]])
	assert_array(_kind.accord_saturation({"scene": CRAFTED_SCENE, "instance": root})).is_empty()


func test_thinning_is_applied_once_before_the_lint() -> void:
	# 95 at tier 0 saturates (95 + 0 + 10); the same 95 at a thinned tier must be judged on the
	# thinned base exactly as FieldMap.accord_base() computes it.
	_register(95.0, 0)
	var root := _field_scene([])
	assert_int(_kind.accord_saturation({"scene": CRAFTED_SCENE, "instance": root}).size()).is_equal(1)
	LocationRegistry._clear_runtime()
	_register(95.0, 3)
	var thinned: float = SkillCheck.location_fizzle_integrity(95.0, CRAFTED_SCENE)
	assert_float(thinned).is_less(90.0)
	assert_array(_kind.accord_saturation({"scene": CRAFTED_SCENE, "instance": root})).is_empty()


func test_no_field_or_no_location_has_nothing_to_lint() -> void:
	var root := _field_scene([[Vector2i(4, 4), 50, 1]])
	assert_array(_kind.accord_saturation({"scene": CRAFTED_SCENE, "instance": root})).is_empty()
	_register(99.0)
	var bare := auto_free(Node2D.new()) as Node2D
	assert_array(_kind.accord_saturation({"scene": CRAFTED_SCENE, "instance": bare})).is_empty()


func test_zone_delta_range_sums_overlaps_and_counts_uncovered_ground_as_zero() -> void:
	var root := _field_scene([[Vector2i(4, 4), 10, 1], [Vector2i(5, 4), 15, 1], [Vector2i(9, 9), -20, 0]])
	var field: FieldMap = WeftluminScenesKind.field_map_in(root)
	var span: Vector2 = WeftluminScenesKind.zone_delta_range(field)
	assert_float(span.x).is_equal(-20.0)
	assert_float(span.y).is_equal(25.0)
	var deltas: Dictionary = WeftluminScenesKind.covered_zone_deltas(field)
	assert_float(float(deltas[Vector2i(4, 4)])).is_equal(25.0)
	assert_float(float(deltas[Vector2i(3, 4)])).is_equal(10.0)
	assert_bool(deltas.has(Vector2i(0, 0))).is_false()


func test_a_zone_covering_all_ground_drops_the_uncovered_zero() -> void:
	var root := _field_scene([[LATTICE / 2, 30, 32]])
	var span: Vector2 = WeftluminScenesKind.zone_delta_range(WeftluminScenesKind.field_map_in(root))
	assert_vector(span).is_equal(Vector2(30, 30))


func test_cells_off_the_ground_are_ignored() -> void:
	var root := _field_scene([[Vector2i(-6, -6), -80, 1]])
	assert_vector(WeftluminScenesKind.zone_delta_range(WeftluminScenesKind.field_map_in(root))).is_equal(Vector2.ZERO)


func test_the_lint_is_registered_as_a_scenes_contract_validator() -> void:
	var names: Array[String] = []
	for validator: Callable in _kind.contract_validators():
		names.append(validator.get_method())
	assert_array(names).contains(["accord_saturation"])


# --- helpers -----------------------------------------------------------------------------------


func _register(accord: float, tier: int = 0) -> void:
	var definition := LocationDefinition.new()
	definition.id = &"gdunit_crafted_accord"
	definition.scene_path = CRAFTED_SCENE
	definition.harmonic_accord = accord
	definition.thinning_tier = tier
	assert_bool(LocationRegistry.register_runtime(definition)).is_true()


## An out-of-tree field like the bake's instance: a root with a `FieldMap`, a filled ground
## lattice and one `AccordZone` per `[anchor cell, accord_delta, half extent]`.
func _field_scene(zones: Array) -> Node2D:
	var root := auto_free(Node2D.new()) as Node2D
	root.name = "CraftedField"
	root.scene_file_path = CRAFTED_SCENE
	var ground := TileMapLayer.new()
	ground.name = "IsometricGround"
	ground.tile_set = GROUND_TILES
	ground.position = Vector2(40, 24)
	root.add_child(ground)
	for y: int in LATTICE.y:
		for x: int in LATTICE.x:
			ground.set_cell(Vector2i(x, y), 0, Vector2i.ZERO)
	var field := FieldMap.new()
	field.name = "FieldMap"
	root.add_child(field)
	for spec: Array in zones:
		var zone := ZONE_SCENE.instantiate() as AccordZone
		zone.accord_delta = int(spec[1])
		zone.half_width_cells = int(spec[2])
		zone.half_height_cells = int(spec[2])
		root.add_child(zone)
		zone.position = ground.position + ground.map_to_local(spec[0] as Vector2i)
	return root
