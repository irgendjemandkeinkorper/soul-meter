extends GdUnitTestSuite

const Document := preload("res://addons/weftlumin/core/tscn_document.gd")


func test_set_property_preserves_surrounding_bytes_and_reparses() -> void:
	var original: String = FileAccess.get_file_as_string("res://test/fixtures/tscn/properties.tscn")
	var document: RefCounted = Document.parse(original)
	assert_bool(document.set_property(".", "position", "Vector2(3, 4)")).is_true()
	assert_str(document.serialise()).is_equal(original.replace("Vector2(1, 2)", "Vector2(3, 4)"))
	assert_int(document.nodes.size()).is_equal(2)
	var once: String = document.serialise()
	assert_bool(document.set_property(".", "position", "Vector2(3, 4)")).is_true()
	assert_str(document.serialise()).is_equal(once)


func test_set_property_replaces_complete_multiline_values() -> void:
	var original: String = FileAccess.get_file_as_string("res://test/fixtures/tscn/properties.tscn")
	var document: RefCounted = Document.parse(original.replace("\n", "\r\n"))
	assert_bool(document.set_property(".", "metadata/array", "[3, 4]")).is_true()
	assert_str(document.serialise()).is_equal(original.replace("[\n1,\n2\n]", "[3, 4]").replace("\n", "\r\n"))
	assert_bool(document.set_property(".", "text", '"Replacement"')).is_true()
	assert_int(document.nodes.size()).is_equal(2)
	assert_bool(document.serialise().contains("After")).is_false()


func test_set_property_inserts_and_refuses_invalid_targets_without_changes() -> void:
	var document: RefCounted = Document.parse('[gd_scene format=3]\n[node name="Root" type="Node"]')
	assert_bool(document.set_property(".", "process_mode", "1")).is_true()
	assert_bool(document.serialise().contains("\nprocess_mode = 1\n")).is_true()
	var before: String = document.serialise()
	assert_bool(document.set_property("Missing", "visible", "true")).is_false()
	assert_str(document.last_error["code"]).is_equal("node_not_found")
	assert_bool(document.set_property(".", "visible", "true\n[node name=\"Injected\"]")).is_false()
	assert_str(document.serialise()).is_equal(before)


func test_set_property_refuses_mismatched_delimiters_without_changes() -> void:
	var original: String = '[gd_scene format=3]\n[node name="Root" type="Node"]\n'
	var document: RefCounted = Document.parse(original)
	document.source_path = "res://test/fixtures/tscn/nodes.tscn"
	for value: String in ['Vector2[1, 2)', '{"nested": [1, 2})', ')(1', ']\n[node name="Injected" type="Node"]\n[']:
		assert_bool(document.set_property(".", "metadata/value", value)).is_false()
		assert_str(document.last_error.get("code", "")).is_equal("invalid_value")
		assert_str(document.last_error.get("field", "")).is_equal(".:metadata/value")
		assert_str(document.last_error.get("file", "")).is_equal(document.source_path)
		assert_str(document.serialise()).is_equal(original)


func test_mismatched_source_and_node_fragment_are_refused_without_changes() -> void:
	var original: String = '[gd_scene format=3]\n[node name="Root" type="Node"]\nmetadata/value = [1, 2)\n'
	var document: RefCounted = Document.parse(original)
	assert_bool(document.set_property(".", "metadata/other", "true")).is_false()
	assert_str(document.last_error.get("code", "")).is_equal("invalid_value")
	assert_str(document.serialise()).is_equal(original)
	var valid: String = '[gd_scene format=3]\n[node name="Root" type="Node"]\n'
	document = Document.parse(valid)
	assert_bool(document.add_node('[node name="Child" type="Node"]\nmetadata/value = [1, 2)\n', ".")).is_false()
	assert_str(document.last_error.get("code", "")).is_equal("invalid_node_block")
	assert_str(document.serialise()).is_equal(valid)


func test_add_node_inserts_at_sibling_index_and_preserves_existing_blocks() -> void:
	var original: String = FileAccess.get_file_as_string("res://test/fixtures/tscn/nodes.tscn")
	var document: RefCounted = Document.parse(original)
	var block: String = '[node name="New" type="Node"]\nmetadata/value = 2\n'
	assert_bool(document.add_node(block, ".", 1)).is_true()
	assert_array(document.nodes.map(func(node: Dictionary) -> String: return node["attributes"]["name"])) \
		.contains_exactly(["Root", "Keep", "New", "Remove", "Grandchild", "RemoveOther"])
	var inserted: String = '[node name="New" type="Node" parent="."]\nmetadata/value = 2\n\n'
	assert_str(document.serialise()).is_equal(original.replace('[node name="Remove"', inserted + '[node name="Remove"'))
	var once: String = document.serialise()
	assert_bool(document.add_node(block, ".", 1)).is_false()
	assert_str(document.last_error["code"]).is_equal("duplicate_node")
	assert_str(document.serialise()).is_equal(once)


func test_add_node_refuses_names_godot_would_rename() -> void:
	var original: String = '[gd_scene format=3]\n[node name="Root" type="Node"]\n'
	var document: RefCounted = Document.parse(original)
	for name: String in ['Floor:Stone', 'Chest@2', '20%', 'Crate.001', 'A/B', 'Quoted"Name']:
		var block: String = '[node name=%s type="Node"]' % var_to_str(name)
		assert_bool(document.add_node(block, ".")).is_false()
		assert_str(document.last_error.get("code", "")).is_equal("invalid_node_name")
		assert_str(document.serialise()).is_equal(original)


func test_remove_node_removes_descendants_connections_and_editable_paths() -> void:
	var original: String = FileAccess.get_file_as_string("res://test/fixtures/tscn/nodes.tscn")
	var document: RefCounted = Document.parse(original)
	var expected: String = original
	for section: Dictionary in document.sections:
		if str(section["attributes"].get("name", "")) in ["Remove", "Grandchild"] \
				or str(section["attributes"].get("from", "")).begins_with("Remove/") \
				or section["attributes"].get("to", "") == "Remove" \
				or str(section["attributes"].get("path", "")) in ["Remove", "Remove/Grandchild"]:
			expected = expected.replace(section["raw_text"], "")
	assert_bool(document.remove_node("Remove")).is_true()
	assert_str(document.serialise()).is_equal(expected)
	assert_int(document.nodes.size()).is_equal(3)
	assert_int(document.connections.size()).is_equal(1)
	assert_int(document.editable_paths.size()).is_equal(1)
	assert_bool(document.remove_node(".")).is_false()
	assert_str(document.serialise()).is_equal(expected)


func test_packed_bytes_preserve_decimal_and_base64_styles() -> void:
	var original: String = FileAccess.get_file_as_string("res://test/fixtures/tscn/packed_bytes.tscn")
	var document: RefCounted = Document.parse(original)
	var bytes: PackedByteArray = [4, 5, 255]
	assert_bool(document.set_packed_bytes(".", "metadata/decimal", bytes)).is_true()
	assert_bool(document.set_packed_bytes(".", "metadata/base64", bytes)).is_true()
	var expected: String = original.replace("PackedByteArray(1, 2, 3)", "PackedByteArray(4, 5, 255)") \
		.replace('PackedByteArray("AQID")', 'PackedByteArray("BAX/")')
	assert_str(document.serialise()).is_equal(expected)
	assert_bool(document.set_packed_bytes(".", "metadata/base64", bytes)).is_true()
	assert_str(document.serialise()).is_equal(expected)


func _resource_tests_anchor() -> void:
	pass


func test_malformed_node_block_is_refused_without_hiding_existing_nodes() -> void:
	var original: String = FileAccess.get_file_as_string("res://test/fixtures/tscn/nodes.tscn")
	var document: RefCounted = Document.parse(original)
	for block: String in ['[node name="Bad" type="Label"]\ntext = "unterminated', '[node name="Child]']:
		assert_bool(document.add_node(block, ".", 0)).is_false()
		assert_str(document.last_error["code"]).is_equal("invalid_node_block")
		assert_str(document.serialise()).is_equal(original)


func test_indented_property_is_replaced_without_duplicate_assignment() -> void:
	var original: String = '[gd_scene format=3]\n[node name="Root" type="Node"]\n\t metadata/value = 1\n'
	var document: RefCounted = Document.parse(original)
	assert_bool(document.set_property(".", "metadata/value", "2")).is_true()
	assert_str(document.serialise()).is_equal(original.replace("= 1", "= 2"))


func test_patched_scene_loads_with_expected_nodes_and_values() -> void:
	var original: String = FileAccess.get_file_as_string("res://test/fixtures/tscn/packed_bytes.tscn")
	var document: RefCounted = Document.parse(original)
	assert_bool(document.add_node('[node name="Child" type="Node"]', ".", 0)).is_true()
	assert_bool(document.set_property("Child", "metadata/value", "Vector2(7, 9)")).is_true()
	var bytes: PackedByteArray = [7, 8, 255]
	assert_bool(document.set_packed_bytes("Child", "metadata/new_bytes", bytes)).is_true()
	assert_bool(document.serialise().contains('metadata/new_bytes = PackedByteArray("Bwj/")')).is_true()
	var path: String = "user://tscn_document_ops_%d.tscn" % get_instance_id()
	var file: FileAccess = FileAccess.open(path, FileAccess.WRITE)
	file.store_string(document.serialise())
	file.close()
	var scene: PackedScene = ResourceLoader.load(path, "PackedScene", ResourceLoader.CACHE_MODE_IGNORE)
	DirAccess.remove_absolute(ProjectSettings.globalize_path(path))
	assert_object(scene).is_not_null()
	if scene == null:
		return
	var root: Node = auto_free(scene.instantiate())
	assert_int(root.get_child_count()).is_equal(1)
	assert_vector(root.get_node("Child").get_meta("value")).is_equal(Vector2(7, 9))
	assert_array(root.get_node("Child").get_meta("new_bytes")).is_equal(bytes)


func test_add_ext_resource_reuses_ids_without_rewriting_existing_bytes() -> void:
	var original: String = FileAccess.get_file_as_string("res://test/fixtures/tscn/resources.tscn")
	var document: RefCounted = Document.parse(original)
	assert_str(document.add_ext_resource(
		"res://addons/weftlumin/core/tscn_document.gd", "Script"
	)).is_equal("1_weftlumin")
	assert_str(document.serialise()).is_equal(original)
	assert_str(document.add_ext_resource(
		"res://addons/weftlumin/core/tscn_document.gd", "Texture2D"
	)).is_empty()
	assert_bool(document.last_error.is_empty()).is_false()
	assert_str(document.serialise()).is_equal(original)


func test_add_ext_resource_preserves_format_uid_and_crlf_with_stable_new_id() -> void:
	var original: String = FileAccess.get_file_as_string("res://test/fixtures/tscn/resources.tscn")
	original = original.replace("\n", "\r\n")
	var document: RefCounted = Document.parse(original)
	var resource_id: String = document.add_ext_resource(
		"res://globals/location_definition.gd", "Script", "uid://c123456"
	)
	assert_str(resource_id).is_equal("2_weftlumin")
	var added_line: String = (
		'[ext_resource type="Script" uid="uid://c123456" '
		+ 'path="res://globals/location_definition.gd" id="2_weftlumin"]\r\n\r\n'
	)
	var expected: String = original.replace("load_steps = 3", "load_steps = 4")
	expected = expected.replace("[sub_resource", added_line + "[sub_resource")
	assert_str(document.serialise()).is_equal(expected)
	assert_int(document.ext_resources.size()).is_equal(2)
	assert_str(document.add_ext_resource(
		"res://globals/location_definition.gd", "Script", "uid://different"
	)).is_equal(resource_id)
	assert_str(document.serialise()).is_equal(expected)


func test_add_ext_resource_handles_header_only_scene_without_final_newline() -> void:
	var document: RefCounted = Document.parse("[gd_scene format=3]")
	assert_str(document.add_ext_resource("res://globals/location_definition.gd", "Script")).is_equal(
		"1_weftlumin"
	)
	assert_int(document.ext_resources.size()).is_equal(1)
	assert_str(document.header["attributes"]["format"]).is_equal("3")
	assert_bool(document.header["attributes"].has("load_steps")).is_false()


func test_encode_value_preserves_supported_value_semantics() -> void:
	var document: RefCounted = Document.parse("[gd_scene format=3]\n")
	var values: Array = [
		null, true, 42, 1.25, "Quote: \" and slash: \\ and newline:\n", &"named",
		NodePath("Root/Child:position"), Vector2(1, 2), Color(0.25, 0.5, 0.75, 1),
		PackedByteArray([0, 128, 255]), [1, "two", Vector2(3, 4)], {"nested": [false, 3]},
	]
	for value: Variant in values:
		var encoded: String = document.encode_value(value, ".", "metadata/value")
		assert_str(encoded).is_not_empty()
		assert_bool(str_to_var(encoded) == value).is_true()
		assert_bool(document.last_error.is_empty()).is_true()


func test_encode_value_uses_existing_external_and_local_subresource_references() -> void:
	var original: String = FileAccess.get_file_as_string("res://test/fixtures/tscn/resources.tscn")
	var document: RefCounted = Document.parse(original)
	document.source_path = "res://test/fixtures/tscn/resources.tscn"
	assert_str(document.encode_value(Document, ".", "script")).is_equal('ExtResource("1_weftlumin")')
	var local_gradient: Gradient = Gradient.new()
	local_gradient.resource_path = document.source_path + "::Gradient_local"
	assert_str(document.encode_value(local_gradient, ".", "gradient")).is_equal(
		'SubResource("Gradient_local")'
	)
	assert_str(document.serialise()).is_equal(original)


func test_encode_value_refuses_unsupported_values_with_attribution_and_no_edits() -> void:
	var original: String = FileAccess.get_file_as_string("res://test/fixtures/tscn/resources.tscn")
	var document: RefCounted = Document.parse(original)
	document.source_path = "res://test/fixtures/tscn/resources.tscn"
	var foreign_gradient: Gradient = Gradient.new()
	foreign_gradient.resource_path = "res://foreign.tscn::Gradient_local"
	var unsupported: Array = [Resource.new(), RefCounted.new(), foreign_gradient, [Document], {"x": Document}]
	for value: Variant in unsupported:
		assert_str(document.encode_value(value, "Root/Child", "texture")).is_empty()
		assert_str(document.last_error["field"]).is_equal("Root/Child:texture")
		assert_bool(String(document.last_error["code"]).is_empty()).is_false()
		assert_str(document.serialise()).is_equal(original)


func test_encode_value_declares_external_script_and_reuses_it() -> void:
	var document: RefCounted = Document.parse("[gd_scene load_steps=1 format=3]\n")
	var encoded: String = document.encode_value(Document, ".", "script")
	assert_str(encoded).is_equal('ExtResource("1_weftlumin")')
	assert_int(document.ext_resources.size()).is_equal(1)
	assert_str(document.ext_resources[0]["attributes"]["type"]).is_equal("Script")
	assert_str(document.header["attributes"]["load_steps"]).is_equal("2")
	var once: String = document.serialise()
	assert_str(document.encode_value(Document, ".", "script")).is_equal(encoded)
	assert_str(document.serialise()).is_equal(once)
