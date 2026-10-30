extends GdUnitTestSuite
## #520 places re-Agreed (owner rulings 2026-10-29, `docs/places-reagreed-packet.md`): an
## `AccordZone` with an `agreement_id` stops thinning the Loom once a quest outcome restores it,
## and that outcome is an act of Agreement that pays the Soul.

const GROUND_TILES := preload("res://assets/generated/sprites/ground/ground_tileset.tres")
const ZONE_SCENE := preload("res://actors/accord_zone/accord_zone.tscn")
const AGREEMENT_ID := &"gdunit-mere-shrine"

var _soul_before: float
var _flags_before: Dictionary
var _restores_before: Array[PackedStringArray]
var _tags_before: Array[PackedStringArray]
var _souls_before: PackedFloat32Array


func before_test() -> void:
	_soul_before = GameState.soul_meter
	_flags_before = GameState.flags.duplicate(true)
	var quest: DomSideQuest = QuestRegistry.DOM_SIDE_QUESTS[0]
	_restores_before = quest.outcome_restores_agreement.duplicate(true)
	_tags_before = quest.outcome_tags.duplicate(true)
	_souls_before = quest.outcome_soul_deltas.duplicate()


func after_test() -> void:
	var quest: DomSideQuest = QuestRegistry.DOM_SIDE_QUESTS[0]
	quest.outcome_restores_agreement = _restores_before
	quest.outcome_tags = _tags_before
	quest.outcome_soul_deltas = _souls_before
	GameState.flags = _flags_before
	GameState.soul_meter = _soul_before


func test_a_reagreed_zone_lifts_only_its_negative_delta() -> void:
	var plain := _zone(-20, &"")
	var named := _zone(-20, AGREEMENT_ID)
	var kind := _zone(15, AGREEMENT_ID)
	assert_int(named.effective_delta()).is_equal(-20)
	GameState.set_flag(AccordMath.agreement_flag(AGREEMENT_ID), true)
	assert_bool(named.is_reagreed()).is_true()
	assert_int(named.effective_delta()).is_equal(0)
	assert_int(named.accord_delta).override_failure_message("authored data is not rewritten").is_equal(-20)
	assert_int(plain.effective_delta()).is_equal(-20)
	assert_int(kind.effective_delta()).is_equal(15)


func test_field_accord_and_loom_penalty_follow_the_restoration() -> void:
	var root := _field([[Vector2i(4, 4), -30, AGREEMENT_ID], [Vector2i(4, 4), -5, &""]])
	var field := root.get_node("FieldMap") as FieldMap
	var zone := root.get_node("Zone0") as AccordZone
	assert_float(field.zone_delta(Vector2i(4, 4))).is_equal(-35.0)
	var penalty_before := SkillCheck.loom_penalty("varlore", zone)
	GameState.set_flag(AccordMath.agreement_flag(AGREEMENT_ID), true)
	assert_float(field.zone_delta(Vector2i(4, 4))).is_equal(-5.0)
	assert_int(SkillCheck.loom_penalty("varlore", zone)).is_equal(0)
	assert_int(penalty_before).is_greater(0)


func test_the_outcome_restores_the_place_and_pays_eight_soul_once() -> void:
	var quest := _restoring_quest()
	assert_bool(quest.has_complete_outcome_schema()).is_true()
	GameState.soul_meter = 40.0
	assert_bool(QuestRegistry.offer_side_quest(quest)).is_true()
	for required_flag: String in quest.required_flags:
		GameState.set_flag(required_flag, true)
	assert_bool(QuestRegistry.resolve_side_quest(quest, quest.outcome_ids[0])).is_true()
	assert_bool(GameState.flag_is_true(AccordMath.agreement_flag(AGREEMENT_ID))).is_true()
	assert_float(GameState.soul_meter).is_equal(48.0)
	assert_bool(QuestRegistry.resolve_side_quest(quest, quest.outcome_ids[0])).is_false()
	assert_float(GameState.soul_meter).is_equal(48.0)
	assert_bool(QuestRegistry.restorable_agreement_ids().has(String(AGREEMENT_ID))).is_true()


func test_the_restoration_survives_a_save_round_trip() -> void:
	GameState.set_flag(AccordMath.agreement_flag(AGREEMENT_ID), true)
	var saved := GameState.to_dict()
	GameState.flags = {}
	assert_bool(_zone(-20, AGREEMENT_ID).is_reagreed()).is_false()
	GameState.from_dict(saved)
	assert_int(_zone(-20, AGREEMENT_ID).effective_delta()).is_equal(0)


func test_the_schema_refuses_a_restoration_that_is_not_an_act_of_agreement() -> void:
	var quest := _restoring_quest()
	quest.outcome_tags[0] = PackedStringArray()
	quest.outcome_soul_deltas[0] = 0.0
	assert_bool(quest.has_valid_agreement_schema()).is_false()
	quest = _restoring_quest()
	quest.outcome_restores_agreement[0] = PackedStringArray([String(AGREEMENT_ID), String(AGREEMENT_ID)])
	assert_bool(quest.has_valid_agreement_schema()).is_false()
	quest = _restoring_quest()
	quest.outcome_restores_agreement.resize(1)
	assert_bool(quest.has_valid_agreement_schema()).is_false()


func test_the_bake_lint_warns_about_dead_duplicate_and_inert_ids() -> void:
	var kind := WeftluminScenesKind.new()
	var root := _field([
		[Vector2i(2, 2), -20, &"gdunit-nobody-restores"],
		[Vector2i(8, 8), -20, &"gdunit-nobody-restores"],
		[Vector2i(5, 5), 10, &""],
	])
	(root.get_node("Zone2") as AccordZone).agreement_id = &"gdunit-inert"
	var messages: Array[String] = []
	for warning: Dictionary in kind.agreement_zones({"scene": "res://world/gdunit_reagreed.tscn", "instance": root}):
		assert_str(str(warning["severity"])).is_equal("warning")
		messages.append(str(warning["message"]))
	assert_int(messages.filter(func(m: String) -> bool: return m.contains("no quest outcome")).size()).is_equal(3)
	assert_int(messages.filter(func(m: String) -> bool: return m.contains("more than one zone")).size()).is_equal(1)
	assert_int(messages.filter(func(m: String) -> bool: return m.contains("no negative delta")).size()).is_equal(1)
	var names: Array[String] = []
	for validator: Callable in kind.contract_validators():
		names.append(validator.get_method())
	assert_array(names).contains(["agreement_zones"])


func _restoring_quest() -> DomSideQuest:
	var quest: DomSideQuest = QuestRegistry.DOM_SIDE_QUESTS[0]
	quest.outcome_tags = []
	quest.outcome_soul_deltas = PackedFloat32Array()
	quest.outcome_restores_agreement = []
	for index in quest.outcome_count():
		quest.outcome_tags.append(PackedStringArray([DomSideQuest.ACT_OF_AGREEMENT_TAG]) if index == 0 else PackedStringArray())
		quest.outcome_soul_deltas.append(8.0 if index == 0 else 0.0)
		quest.outcome_restores_agreement.append(PackedStringArray([String(AGREEMENT_ID)]) if index == 0 else PackedStringArray())
	return quest


func _zone(delta: int, agreement_id: StringName) -> AccordZone:
	var zone := auto_free(ZONE_SCENE.instantiate()) as AccordZone
	zone.accord_delta = delta
	zone.agreement_id = agreement_id
	return zone


## A root with a filled ground lattice, a `FieldMap`, and one `AccordZone` (`Zone<n>`) per
## `[anchor cell, accord_delta, agreement_id]`, each covering one cell around its anchor.
func _field(zones: Array) -> Node2D:
	var root := auto_free(Node2D.new()) as Node2D
	root.scene_file_path = "res://world/gdunit_reagreed.tscn"
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
	for index in zones.size():
		var spec: Array = zones[index]
		var zone := ZONE_SCENE.instantiate() as AccordZone
		zone.name = "Zone%d" % index
		zone.accord_delta = int(spec[1])
		zone.agreement_id = spec[2]
		zone.half_width_cells = 0
		zone.half_height_cells = 0
		root.add_child(zone)
		zone.position = ground.map_to_local(spec[0] as Vector2i)
	return root
