extends GdUnitTestSuite

const Document := preload("res://addons/weftlumin/core/tscn_document.gd")
const SOURCE_PATH := "res://world/starting_town.tscn"
const OP_LOG: Array[Dictionary] = [
	{"node_path": ".", "key": "y_sort_enabled", "value_text": "false"},
	{"node_path": "TavernDoor", "key": "position", "value_text": "Vector2(1712, 1700)"},
]

var _candidate_path: String = ""


func after_test() -> void:
	if not _candidate_path.is_empty() and FileAccess.file_exists(_candidate_path):
		DirAccess.remove_absolute(ProjectSettings.globalize_path(_candidate_path))
	_candidate_path = ""


func test_property_patch_preserves_dom_editable_instances_and_facade_override() -> void:
	var original: String = FileAccess.get_file_as_string(SOURCE_PATH)
	var document: RefCounted = Document.parse(original)
	var editable_blocks: Array[String] = _editable_blocks(document)
	assert_int(editable_blocks.size()).is_equal(21)
	assert_bool(document.set_property(".", "y_sort_enabled", "false")).is_true()
	var expected: String = original.replace(
		'y_sort_enabled = true\nscript = ExtResource("39_town")',
		'y_sort_enabled = false\nscript = ExtResource("39_town")'
	)
	assert_str(document.serialise()).is_equal(expected)
	assert_str(document.serialise()).is_not_equal(original)
	assert_array(_editable_blocks(document)).contains_exactly(editable_blocks)

	_candidate_path = "user://tscn_dom_survival_%d_%d.tscn" % [get_instance_id(), Time.get_ticks_usec()]
	var file: FileAccess = FileAccess.open(_candidate_path, FileAccess.WRITE)
	assert_object(file).is_not_null()
	if file == null:
		return
	file.store_string(document.serialise())
	file.close()
	var scene: PackedScene = ResourceLoader.load(
		_candidate_path, "PackedScene", ResourceLoader.CACHE_MODE_IGNORE
	)
	assert_object(scene).is_not_null()
	if scene == null:
		return
	# Keep the candidate outside the tree: deserialisation is the assertion, not town gameplay.
	var town: Node2D = auto_free(scene.instantiate()) as Node2D
	assert_object(town).is_not_null()
	if town == null:
		return
	assert_bool(town.y_sort_enabled).is_false()
	var facade: Polygon2D = town.get_node_or_null("TavernDoor/Facade") as Polygon2D
	assert_object(facade).is_not_null()
	if facade != null:
		assert_bool(facade.visible).is_false()
	assert_str(FileAccess.get_file_as_string(SOURCE_PATH)).is_equal(original)


func test_reapplying_same_dom_operation_log_is_byte_identical() -> void:
	var original: String = FileAccess.get_file_as_string(SOURCE_PATH)
	var document: RefCounted = Document.parse(original)
	_apply_log(document)
	var once: String = document.serialise()
	assert_str(once).is_not_equal(original)
	assert_bool(once.contains("position = Vector2(1712, 1700)")).is_true()
	# Replay against the saved output, not only the already-mutated in-memory model.
	var reopened: RefCounted = Document.parse(once)
	_apply_log(reopened)
	assert_str(reopened.serialise()).is_equal(once)
	assert_int(_editable_blocks(reopened).size()).is_equal(21)
	assert_str(FileAccess.get_file_as_string(SOURCE_PATH)).is_equal(original)


func _apply_log(document: RefCounted) -> void:
	for operation: Dictionary in OP_LOG:
		assert_bool(document.set_property(
			operation["node_path"], operation["key"], operation["value_text"]
		)).is_true()


func _editable_blocks(document: RefCounted) -> Array[String]:
	var result: Array[String] = []
	for node: Dictionary in document.nodes:
		if "editable_children = true" in node["property_lines"]:
			result.append(node["raw_text"])
	return result
