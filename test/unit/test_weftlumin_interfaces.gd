extends GdUnitTestSuite


func test_primary_interfaces_exist_and_declare_the_ratified_classes() -> void:
	var interfaces: Dictionary = {
		"res://addons/weftlumin/core/adapter.gd": "WeftluminGameAdapter",
		"res://addons/weftlumin/core/kind.gd": "WeftluminKind",
		"res://addons/weftlumin/shell/panel.gd": "WeftluminPanel",
	}
	for path: String in interfaces:
		assert_bool(FileAccess.file_exists(path)).override_failure_message(
			"Missing ratified interface: %s" % path
		).is_true()
		if not FileAccess.file_exists(path):
			continue
		var script: GDScript = load(path)
		assert_object(script).is_not_null()
		if script != null:
			assert_str(script.get_global_name()).is_equal(interfaces[path])


func test_adapter_signature_matches_the_frozen_contract() -> void:
	var script: GDScript = load("res://addons/weftlumin/core/adapter.gd")
	assert_str(script.get_instance_base_type()).is_equal("RefCounted")
	_assert_method(script, "env_flag", TYPE_STRING, [])
	_assert_method(script, "theme", TYPE_OBJECT, [], "Theme")
	_assert_method(script, "set_editor_open", TYPE_NIL, [["open", TYPE_BOOL]])
	_assert_method(script, "gameplay_scene_root", TYPE_OBJECT, [], "Node")
	_assert_method(script, "editable_roots", TYPE_ARRAY, [["scene_root", TYPE_OBJECT, "Node"]], "Node")
	_assert_method(script, "grid", TYPE_OBJECT, [], "WeftluminGridAdapter")
	_assert_method(script, "placeables", TYPE_ARRAY, [], "WeftluminPlaceable")
	_assert_method(script, "kinds", TYPE_ARRAY, [], "WeftluminKind")
	_assert_method(script, "panels", TYPE_ARRAY, [], "PackedScene")
	_assert_method(script, "capture_runtime_state", TYPE_DICTIONARY, [])
	_assert_method(script, "restore_runtime_state", TYPE_BOOL, [["s", TYPE_DICTIONARY]])
	_assert_method(script, "production_owner_live", TYPE_BOOL, [])
	_assert_method(script, "pickers", TYPE_DICTIONARY, [])
	_assert_method(script, "canon_root", TYPE_STRING, [])
	_assert_method(script, "recorder", TYPE_OBJECT, [], "Node")


func test_kind_signature_matches_the_frozen_contract() -> void:
	var script: GDScript = load("res://addons/weftlumin/core/kind.gd")
	assert_str(script.get_instance_base_type()).is_equal("RefCounted")
	_assert_fields(script, {"id": TYPE_STRING_NAME, "subdir": TYPE_STRING,
		"ext": TYPE_STRING, "stable_id_kind": TYPE_STRING_NAME})
	_assert_method(script, "validate", TYPE_ARRAY,
		[["documents", TYPE_ARRAY, "Dictionary"], ["errors", TYPE_ARRAY, "Dictionary"]], "Dictionary")
	_assert_method(script, "register", TYPE_BOOL, [["normalised", TYPE_ARRAY, "Dictionary"]])
	_assert_method(script, "clear", TYPE_NIL, [])
	_assert_method(script, "diff", TYPE_DICTIONARY,
		[["previous", TYPE_ARRAY, "Dictionary"], ["next", TYPE_ARRAY, "Dictionary"]])
	_assert_method(script, "bake", TYPE_DICTIONARY,
		[["normalised", TYPE_ARRAY, "Dictionary"], ["target_root", TYPE_STRING],
		["write", TYPE_BOOL], ["force", TYPE_BOOL]])


func test_panel_signature_matches_the_frozen_contract() -> void:
	var script: GDScript = load("res://addons/weftlumin/shell/panel.gd")
	assert_str(script.get_instance_base_type()).is_equal("Control")
	_assert_fields(script, {"title": TYPE_STRING, "needs_sandbox": TYPE_BOOL, "hotkey_hint": TYPE_STRING})
	_assert_method(script, "configure", TYPE_NIL, [["host", TYPE_OBJECT, "WeftluminShell"]])
	_assert_method(script, "refresh", TYPE_NIL, [["payload", TYPE_DICTIONARY]])
	_assert_method(script, "commands", TYPE_ARRAY, [], "Callable")


func test_instantiated_contracts_are_inert_and_never_report_success() -> void:
	var children_before: int = get_tree().root.get_child_count()
	var paused_before: bool = get_tree().paused
	var scratch_before: bool = DirAccess.dir_exists_absolute("user://weftlumin")
	var adapter: WeftluminGameAdapter = WeftluminGameAdapter.new()
	var kind: WeftluminKind = WeftluminKind.new()
	var panel: WeftluminPanel = auto_free(WeftluminPanel.new())
	var host: WeftluminShell = auto_free(WeftluminShell.new())
	var documents: Array[Dictionary] = [{"id": "unchanged"}]
	var errors: Array[Dictionary] = []
	adapter.set_editor_open(true)
	assert_bool(adapter.restore_runtime_state({"active": true})).is_false()
	assert_dict(adapter.capture_runtime_state()).is_empty()
	assert_array(kind.validate(documents, errors)).is_empty()
	assert_bool(kind.register(documents)).is_false()
	kind.clear()
	assert_dict(kind.bake(documents, "res://canon", true, true)).is_empty()
	assert_array(documents).contains_exactly([{"id": "unchanged"}])
	assert_array(errors).is_empty()
	panel.configure(host)
	panel.refresh({"selection": ["unchanged"]})
	assert_array(panel.commands()).is_empty()
	assert_int(panel.get_child_count()).is_equal(0)
	assert_int(host.get_child_count()).is_equal(0)
	assert_int(get_tree().root.get_child_count()).is_equal(children_before)
	assert_bool(get_tree().paused).is_equal(paused_before)
	assert_bool(DirAccess.dir_exists_absolute("user://weftlumin")).is_equal(scratch_before)
	assert_bool(InputMap.has_action("weftlumin_toggle")).is_false()
	# E2.1 (#332) registers WeftluminBootstrap as an autoload, so its absence is no longer the
	# evidence of inertness — its DISABLED state is. The point this line makes is unchanged:
	# instantiating the contracts activates nothing.
	assert_bool(ProjectSettings.has_setting("autoload/WeftluminBootstrap")).is_true()
	var bootstrap: Node = get_tree().root.get_node_or_null("WeftluminBootstrap")
	assert_object(bootstrap).override_failure_message(
		"the bootstrap autoload must be resident in every build"
	).is_not_null()
	assert_bool(bool(bootstrap.call("is_enabled"))).override_failure_message(
		"merely instantiating the Weftlumin contracts must not enable the editor"
	).is_false()


func test_support_types_and_plugin_compile_without_activation() -> void:
	var grid: WeftluminGridAdapter = WeftluminGridAdapter.new()
	var placeable: WeftluminPlaceable = WeftluminPlaceable.new()
	assert_object(grid).is_instanceof(RefCounted)
	assert_object(placeable).is_instanceof(RefCounted)
	assert_bool(grid.has_method("world_to_cell")).is_false()
	var config: ConfigFile = ConfigFile.new()
	assert_int(config.load("res://addons/weftlumin/plugin.cfg")).is_equal(OK)
	var plugin_path: String = "res://addons/weftlumin/" + str(config.get_value("plugin", "script"))
	var plugin_script: GDScript = load(plugin_path)
	assert_str(plugin_script.get_instance_base_type()).is_equal("EditorPlugin")
	assert_bool(plugin_script.is_tool()).is_true()
	var enabled: PackedStringArray = ProjectSettings.get_setting("editor_plugins/enabled", PackedStringArray())
	assert_bool(enabled.has("res://addons/weftlumin/plugin.cfg")).is_false()


func _assert_method(script: GDScript, method_name: String, return_type: int, arguments: Array,
		return_hint: String = "") -> void:
	var methods: Array[Dictionary] = script.get_script_method_list()
	var found: Dictionary = {}
	for method: Dictionary in methods:
		if method["name"] == method_name:
			found = method
			break
	assert_dict(found).override_failure_message("Missing method: %s" % method_name).is_not_empty()
	if found.is_empty():
		return
	_assert_type(found["return"], return_type, return_hint)
	var actual: Array = found["args"]
	assert_int(actual.size()).is_equal(arguments.size())
	assert_array(found["default_args"]).is_empty()
	for index: int in mini(actual.size(), arguments.size()):
		assert_str(actual[index]["name"]).is_equal(arguments[index][0])
		_assert_type(actual[index], arguments[index][1],
			arguments[index][2] if arguments[index].size() > 2 else "")


func _assert_fields(script: GDScript, expected: Dictionary) -> void:
	var fields: Dictionary = {}
	for property: Dictionary in script.get_script_property_list():
		fields[str(property["name"])] = property
	for field: String in expected:
		assert_bool(fields.has(field)).is_true()
		if fields.has(field):
			_assert_type(fields[field], expected[field])


func _assert_type(property: Dictionary, expected: int, hint: String = "") -> void:
	assert_int(property["type"]).is_equal(expected)
	if not hint.is_empty():
		var actual: String = str(property.get("class_name", "")) + str(property.get("hint_string", ""))
		assert_str(actual).contains(hint)
