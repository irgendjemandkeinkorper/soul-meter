extends GdUnitTestSuite

const Release := preload("res://test/helpers/weftlumin_tool_release.gd")


func test_every_dev_resource_is_excluded_from_both_exports() -> void:
	var config := ConfigFile.new()
	assert_int(config.load("res://export_presets.cfg")).is_equal(OK)
	var count := 0
	for section: String in config.get_sections():
		if not section.begins_with("preset.") or section.ends_with(".options"):
			continue
		count += 1
		assert_str(str(config.get_value(section, "exclude_filter", ""))).contains("dev/*")
	assert_int(count).is_equal(2)
	_scan("res://dev", true)


func test_only_flow_wiring_references_dev_resources_in_shipped_code() -> void:
	_scan("res://", false)
	var menu := FileAccess.get_file_as_string("res://ui/screens/main_menu.gd")
	assert_str(menu).contains('if OS.is_debug_build():\n\t\tvar dev_button')
	assert_str(menu).not_contains("res://dev/")
	var flow := FileAccess.get_file_as_string("res://ui/flow/game_flow.gd")
	assert_str(flow).contains('if not OS.is_debug_build():\n\t\tsend_event("dev_room_failed")')
	assert_str(flow).not_contains('preload("res://dev/')
	var chart: Node = auto_free(load("res://ui/flow/game_flow.tscn").instantiate())
	var state_chart := chart.get_node("StateChart") as StateChart
	assert_bool(state_chart.initial_expression_properties["dev_room_available"]).is_false()
	var transition := chart.get_node("StateChart/Root/Menus/Title/ToDevRoom") as Transition
	assert_str((transition.guard as ExpressionGuard).expression).is_equal("dev_room_available")
	assert_str(String(transition.event)).is_equal("dev_room")


func _scan(directory: String, check_excluded: bool) -> void:
	for file: String in DirAccess.get_files_at(directory):
		var path := directory.path_join(file)
		if file.get_extension() not in ["gd", "tscn", "tres", "godot"]:
			continue
		if check_excluded:
			assert_bool(Release.excluded_from_every_preset(path)).is_true()
			assert_str(FileAccess.get_file_as_string(path)).not_contains("class_name ")
		elif path != "res://ui/flow/game_flow.gd":
			assert_str(FileAccess.get_file_as_string(path)) \
				.override_failure_message("Shipped resource depends on dev/: " + path) \
				.not_contains("res://dev/")
	for child: String in DirAccess.get_directories_at(directory):
		if child.begins_with(".") or child in ["dev", "test", "reports", "build", "docs"]:
			continue
		_scan(directory.path_join(child), check_excluded)
