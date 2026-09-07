extends GdUnitTestSuite

const TscnDocumentScript := preload("res://addons/weftlumin/core/tscn_document.gd")


func test_parse_exposes_supported_sections_without_normalising_text() -> void:
	var source: String = (
		"[gd_scene load_steps=3 format=3 uid=\"uid://fixture\"]\r\n"
		+ "\r\n"
		+ "[ext_resource type=\"PackedScene\" path=\"res://child.tscn\" id=\"1_child\"]\r\n"
		+ "\r\n"
		+ "[sub_resource type=\"Gradient\" id=\"Gradient_fixture\"]\r\n"
		+ "offsets = PackedFloat32Array(0, 1)\r\n"
		+ "\r\n"
		+ "[node name=\"Root\" type=\"Node2D\" groups=[\"fixture\", \"root\"]]\r\n"
		+ "position = Vector2(4, 8)\r\n"
		+ "\r\n"
		+ "[node name=\"Child\" parent=\".\" instance=ExtResource(\"1_child\")]\r\n"
		+ "editable_children = true\r\n"
		+ "\r\n"
		+ "[connection signal=\"ready\" from=\".\" to=\"Child\" method=\"_on_ready\"]\r\n"
		+ "\r\n"
		+ "[editable path=\"Child\"]"
	)

	var document: RefCounted = TscnDocumentScript.parse(source)

	assert_str(str(document.header["attributes"]["format"])).is_equal("3")
	assert_int(document.ext_resources.size()).is_equal(1)
	assert_int(document.sub_resources.size()).is_equal(1)
	assert_int(document.nodes.size()).is_equal(2)
	assert_int(document.connections.size()).is_equal(1)
	assert_int(document.editable_paths.size()).is_equal(1)
	assert_str(str(document.nodes[0]["attributes"]["name"])).is_equal("Root")
	assert_str(str(document.nodes[0]["attributes"]["groups"])).is_equal(
		"[\"fixture\", \"root\"]"
	)
	assert_array(document.nodes[0]["property_lines"]).contains_exactly([
		"position = Vector2(4, 8)",
	])
	assert_str(document.serialise()).is_equal(source)


func test_every_project_scene_round_trips_byte_identically() -> void:
	var scene_paths: PackedStringArray = []
	_collect_scene_paths(ProjectSettings.globalize_path("res://"), scene_paths)
	scene_paths.sort()
	assert_int(scene_paths.size()).is_greater(0)

	var saw_starting_town: bool = false
	for absolute_path: String in scene_paths:
		var original_bytes: PackedByteArray = FileAccess.get_file_as_bytes(absolute_path)
		var original_text: String = original_bytes.get_string_from_utf8()
		var document: RefCounted = TscnDocumentScript.parse(original_text)
		var round_trip_bytes: PackedByteArray = document.serialise().to_utf8_buffer()
		assert_array(round_trip_bytes) \
			.override_failure_message("TSCN round trip changed bytes: %s" % absolute_path) \
			.is_equal(original_bytes)
		if absolute_path.ends_with("/world/starting_town.tscn"):
			saw_starting_town = true
			assert_str(str(document.header["attributes"]["format"])).is_equal("3")
			var editable_children_count: int = 0
			for node: Dictionary in document.nodes:
				if node["property_lines"].has("editable_children = true"):
					editable_children_count += 1
			assert_int(editable_children_count).is_equal(21)
	assert_bool(saw_starting_town).is_true()


func test_multiline_text_does_not_create_scene_sections() -> void:
	var text_lines: Array[String] = [
		'text = "Before',
		'[node name=\\"Phantom\\" type=\\"Node\\"]',
		'[ext_resource type=\\"Texture2D\\" id=\\"fake\\"]',
		'[sub_resource type=\\"Resource\\" id=\\"fake\\"]',
		'[connection signal=\\"ready\\" from=\\".\\" to=\\".\\" method=\\"fake\\"]',
		'[editable path=\\"Phantom\\"]',
		'[gd_scene format=3]',
		'After"',
	]
	var source: String = (
		'[gd_scene format=3]\r\n[node name="Root" type="Label"]\r\n'
		+ "\r\n".join(text_lines)
		+ '\r\n\r\n[node name="RealChild" type="Node" parent="."]'
	)
	var document: RefCounted = TscnDocumentScript.parse(source)
	assert_int(document.sections.size()).is_equal(3)
	assert_int(document.nodes.size()).is_equal(2)
	assert_str(document.nodes[1]["attributes"]["name"]).is_equal("RealChild")
	assert_array(document.nodes[0]["property_lines"]).contains_exactly(text_lines)
	assert_str(document.serialise()).is_equal(source)


func test_quotes_in_comments_do_not_hide_following_nodes() -> void:
	var source: String = (
		'[gd_scene format=3]\n; An unmatched " in a comment\n'
		+ '[node name="Root" type="Label"]\n'
		+ 'text = "A semicolon ; and an escaped quote \\" remain text" ; "\n'
		+ '[node name="Child" type="Node" parent="."]\n'
	)
	var document: RefCounted = TscnDocumentScript.parse(source)
	assert_int(document.nodes.size()).is_equal(2)
	assert_str(document.nodes[1]["attributes"]["name"]).is_equal("Child")
	assert_str(document.serialise()).is_equal(source)


func _collect_scene_paths(directory_path: String, scene_paths: PackedStringArray) -> void:
	var directory: DirAccess = DirAccess.open(directory_path)
	assert_object(directory) \
		.override_failure_message("Could not open directory: %s" % directory_path) \
		.is_not_null()
	if directory == null:
		return
	directory.list_dir_begin()
	var entry: String = directory.get_next()
	while not entry.is_empty():
		var child_path: String = directory_path.path_join(entry)
		if directory.current_is_dir():
			if entry == "addons":
				var first_party_addon: String = child_path.path_join("weftlumin")
				if DirAccess.dir_exists_absolute(first_party_addon):
					_collect_scene_paths(first_party_addon, scene_paths)
			elif entry not in [".git", ".godot"]:
				_collect_scene_paths(child_path, scene_paths)
		elif entry.get_extension() == "tscn":
			scene_paths.append(child_path)
		entry = directory.get_next()
	directory.list_dir_end()


func test_header_attributes_allow_spaces_around_equals() -> void:
	var source: String = (
		"[gd_scene format = 3]\r\n"
		+ "\r\n"
		+ "[node name = \"Root\" type = \"Node\" groups = [\"one\", \"two\"]]\r\n"
	)
	var document: RefCounted = TscnDocumentScript.parse(source)

	assert_str(str(document.header["attributes"]["format"])).is_equal("3")
	assert_int(document.nodes.size()).is_equal(1)
	assert_str(str(document.nodes[0]["attributes"]["name"])).is_equal("Root")
	assert_str(str(document.nodes[0]["attributes"]["type"])).is_equal("Node")
	assert_str(str(document.nodes[0]["attributes"]["groups"])).is_equal(
		"[\"one\", \"two\"]"
	)
	assert_array(document.serialise().to_utf8_buffer()).is_equal(source.to_utf8_buffer())


func test_header_attributes_allow_tabs_around_equals() -> void:
	var source: String = (
		"[gd_scene format\t=\t3]\n"
		+ "[node name\t=\t\"Root\"\ttype\t=\t\"Node\"]\n"
		+ "[node name\t=\t\"Child\"\tparent\t=\t\".\"\tinstance\t=\tExtResource(\"1_child\")]"
	)
	var document: RefCounted = TscnDocumentScript.parse(source)

	assert_str(str(document.header["attributes"]["format"])).is_equal("3")
	assert_int(document.nodes.size()).is_equal(2)
	assert_str(str(document.nodes[0]["attributes"]["name"])).is_equal("Root")
	assert_str(str(document.nodes[0]["attributes"]["type"])).is_equal("Node")
	assert_str(str(document.nodes[1]["attributes"]["name"])).is_equal("Child")
	assert_str(str(document.nodes[1]["attributes"]["parent"])).is_equal(".")
	assert_str(str(document.nodes[1]["attributes"]["instance"])).is_equal(
		"ExtResource(\"1_child\")"
	)
	assert_array(document.serialise().to_utf8_buffer()).is_equal(source.to_utf8_buffer())
