extends GdUnitTestSuite

## #284 field verbs read the Hush/Waning pressure under them (owner ruling 2026-09-08: the
## zone IS the AccordZone). A lock or a pocket inside a Waning zone resolves with the Loom
## penalty subtracted from its situational modifier; on open ground, or off any field, it
## pays nothing. `SkillCheck` logs the modifier it was handed, which is what these read.

const GROUND_TILES := preload("res://assets/generated/sprites/ground/ground_tileset.tres")
const ZONE_SCENE := preload("res://actors/accord_zone/accord_zone.tscn")
const INTERACTABLE_SCENE := preload("res://actors/interactable/interactable.tscn")
const NPC_SCENE := preload("res://actors/npc/npc.tscn")
const ZONE_CELL := Vector2i(4, 4)
const OPEN_CELL := Vector2i(9, 9)
const ZONE_DELTA := -15
## A FULL Loom-sensitivity skill, so the penalty is the whole zone strength.
const SKILL := "undertone"
const MODIFIER := 5.0

var _state_before: Dictionary = {}
var _checks_before: Dictionary = {}


func before_test() -> void:
	_state_before = GameState.to_dict()
	_checks_before = SkillCheck.to_dict()


func after_test() -> void:
	SkillCheck.from_dict(_checks_before)
	GameState.from_dict(_state_before)


func test_a_lock_inside_a_waning_zone_pays_the_loom_penalty() -> void:
	var root := _field()
	var lock := _lock(root, ZONE_CELL, "gdunit-loom-zone")
	var penalty := SkillCheck.loom_penalty(SKILL, float(ZONE_DELTA))
	assert_int(penalty).override_failure_message("precondition: %s is Loom-sensitive" % SKILL) \
		.is_greater(0)

	var result: Dictionary = lock.attempt_skill_lock()

	assert_bool(bool(result["attempted"])).is_true()
	assert_float(_last_modifier()).is_equal(MODIFIER - float(penalty))


func test_the_same_lock_on_open_ground_pays_nothing() -> void:
	var root := _field()
	var lock := _lock(root, OPEN_CELL, "gdunit-loom-open")

	lock.attempt_skill_lock()

	assert_float(_last_modifier()).is_equal(MODIFIER)


func test_a_lock_off_any_field_pays_nothing() -> void:
	var lock := auto_free(INTERACTABLE_SCENE.instantiate()) as SMInteractable
	lock.lock_skill = SKILL
	lock.lock_id = "gdunit-loom-nofield"
	lock.lock_modifier = MODIFIER
	get_tree().root.add_child(lock)

	lock.attempt_skill_lock()

	assert_float(_last_modifier()).is_equal(MODIFIER)


func test_a_pocket_inside_a_waning_zone_pays_the_loom_penalty() -> void:
	var root := _field()
	var npc := NPC_SCENE.instantiate() as NPC
	npc.pocket_id = "gdunit-loom-pocket"
	npc.pocket_skill = SKILL
	npc.pocket_modifier = MODIFIER
	root.add_child(npc)
	npc.position = _ground(root).map_to_local(ZONE_CELL)
	var penalty := SkillCheck.loom_penalty(SKILL, float(ZONE_DELTA))

	# A forced success grants the (empty) pocket and writes no ledger.
	var result: Dictionary = npc.attempt_pickpocket([1])

	assert_bool(bool(result["attempted"])).is_true()
	assert_float(_last_modifier()).is_equal(MODIFIER - float(penalty))


func _last_modifier() -> float:
	var checks := SkillCheck.recent_checks()
	assert_array(checks).override_failure_message("the verb must commit a check").is_not_empty()
	return float(checks.back()["modifiers"])


func _lock(root: Node2D, cell: Vector2i, lock_id: String) -> SMInteractable:
	var lock := INTERACTABLE_SCENE.instantiate() as SMInteractable
	lock.lock_skill = SKILL
	lock.lock_id = lock_id
	lock.lock_modifier = MODIFIER
	root.add_child(lock)
	lock.position = _ground(root).map_to_local(cell)
	return lock


func _ground(root: Node2D) -> TileMapLayer:
	return root.get_node("IsometricGround") as TileMapLayer


## A root with a filled ground lattice, a `FieldMap`, and one Waning `AccordZone` covering
## exactly ZONE_CELL. The root needs a scene path: `FieldMap._field_root()` looks for one.
func _field() -> Node2D:
	var root := auto_free(Node2D.new()) as Node2D
	root.scene_file_path = "res://world/gdunit_loom_verbs.tscn"
	var ground := TileMapLayer.new()
	ground.name = "IsometricGround"
	ground.tile_set = GROUND_TILES
	root.add_child(ground)
	for y: int in 12:
		for x: int in 12:
			ground.set_cell(Vector2i(x, y), 0, Vector2i.ZERO)
	var field := FieldMap.new()
	field.name = "FieldMap"
	root.add_child(field)
	var zone := ZONE_SCENE.instantiate() as AccordZone
	zone.name = "WaningZone"
	zone.accord_delta = ZONE_DELTA
	zone.half_width_cells = 0
	zone.half_height_cells = 0
	root.add_child(zone)
	zone.position = ground.map_to_local(ZONE_CELL)
	get_tree().root.add_child(root)
	assert_float(field.zone_delta(ZONE_CELL)) \
		.override_failure_message("precondition: the zone covers ZONE_CELL") \
		.is_equal(float(ZONE_DELTA))
	assert_float(field.zone_delta(OPEN_CELL)).is_equal(0.0)
	return root
